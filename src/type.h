#pragma once
#include <string>
#include <vector>

namespace ap {

/// ISO 7185 §6.4.2.2 — the integer type is the range -maxint..maxint. Note
/// this is narrower than the i32 the compiler represents it with: INT_MIN fits
/// the machine word but is not a value of the Pascal type, and arithmetic that
/// would produce it is an error.
inline constexpr int kMaxInt = 2147483647;

enum class TypeKind {
  Void, Integer, Real, Boolean, Char, Enum, Subrange, Array, Record, Pointer,
  File, Set, Proc,
  /// ISO/IEC 10206:1991 §6.4.3.3.3's variable-string-type: a type produced
  /// from the required schema `string`. Its value is a length and that many
  /// characters, and the length may be anything from zero up to the
  /// **capacity** — the schema's one discriminant. `hi` holds the capacity,
  /// `hiDisc` the discriminant it came from when an actual brought it, and
  /// `lo` is 1 because §6.4.3.3.1 makes every string's index-domain start
  /// there.
  ///
  /// The *canonical*-string-type of §6.4.3.3.1 — the type of `+`, `substr`
  /// and `trim` — is this kind with `hi` negative: a value with no storage
  /// and so no capacity to exceed.
  String,
  /// ISO/IEC 10206:1991 §6.4.2.2 e): "The required type-identifier `complex`
  /// shall denote the complex-type. The complex-type shall be a
  /// **simple-type**." Simple is the operative word — a complex value is
  /// assigned, passed and returned as a value, so none of the by-address
  /// machinery of ADR-0017 touches it, exactly as for a set (ADR-0028).
  Complex,
  /// ISO/IEC 10206:1991 §6.4.2.5's restricted-type. "A restricted-type shall
  /// denote a type whose set of states is associated one-to-one with the
  /// states determined by another type, designated the underlying-type", and
  /// the NOTE says what may be done with one: assigned to or from the
  /// underlying-type, passed as a value parameter to a formal of the
  /// underlying-type, passed as a var parameter to a formal of the same type
  /// or the underlying-type, and returned as a function result. "No other
  /// operations, such as accessing a component of a restricted-type value or
  /// performing arithmetic, are possible."
  ///
  /// Making it a *kind* is what enforces that sentence. Every predicate —
  /// `isArray`, `isInteger`, `isStringType`, `isOrdinal` — answers `false`,
  /// so indexing, field selection, arithmetic, comparison, `write`, `case`,
  /// `for` and the rest each refuse it through the diagnostic they already
  /// had, naming the type. Only the four permitted operations are written
  /// down anywhere, which is the same shape ADR-0044's variant-selector and
  /// ADR-0046's `new(p)` have: refused by construction rather than by a list.
  ///
  /// `elem` is the underlying-type. How the value *travels* is still the
  /// underlying-type's business, so `isMemory` and `isStructured` are the two
  /// predicates that see through — a restricted record must be copied and
  /// passed by address exactly as the record is.
  Restricted
};

/// ISO 7185 §6.4.3.4 leaves the size of a set to the implementation. This one
/// gives every set the same 256-bit representation, so the base type's values
/// must be ordinals in 0..255 — which is exactly `char`, and every enumeration
/// and small subrange a compiler wants to build a character class or a follow
/// set out of. `set of integer` is refused rather than silently truncated.
inline constexpr int kSetLimit = 255;

/// The capacity of `BindingType.name`. ISO/IEC 10206:1991 §6.4.3.4 makes the
/// field "an implementation-defined variable-string-type" and says nothing
/// more, so the number is this compiler's; it is a file name's worth.
inline constexpr int kBindingNameCapacity = 255;

struct Type;
struct Symbol;

/// A folded case-constant: the closed interval [lo, hi]. ISO 7185's single
/// constant is `lo = hi`, so every user of a label list works one way and a
/// range never has to be expanded into its members — which matters, because a
/// range may span every value of its type.
struct LabelRange {
  long long lo = 0, hi = 0;
};

/// One field of a record. `index` is the position in the LLVM struct it
/// belongs to, which is also the declaration order — codegen indexes by it and
/// never by name. `variant` says which struct that is: empty is the record's
/// fixed part, `[k]` is arm k of its variant part, `[k, j]` is arm j of the
/// variant part *inside* arm k, and so on. ISO 7185 §6.4.3.3 puts no limit on
/// the nesting, so a single index could not say where a field lives.
struct Expr; // an initial-state-specifier's value, owned by the AST

struct Field {
  std::string name;
  Type *type = nullptr;
  int index = 0;
  std::vector<int> variant;
  int line = 0, col = 0;
  /// ISO/IEC 10206:1991 §6.6: a field's own type-denoter may carry an
  /// initial-state-specifier, and then the record's initial state has that
  /// field bearing that value. Borrowed from the AST — Sema owns the tree —
  /// and read only by the block prologue.
  Expr *initValue = nullptr;
};

/// One arm of a variant part: the tag values that select it, and the fields
/// that exist while it is selected. An arm is shaped exactly like a record —
/// a fixed part and an optional variant part of its own — because that is what
/// §6.4.3.3 makes it: its field-list is a field-list like any other.
struct Variant {
  std::vector<LabelRange> labels;
  bool isOtherwise = false;    // selected by whatever the other arms leave
                               // (Extended Pascal's variant-part-completer)
  std::vector<Field> fields;
  std::vector<Variant> variants;
  int tagField = -1;           // index into `fields`, or -1 when the nested
                               // tag has no field of its own
  Type *tagType = nullptr;
  /// The nested variant-selector was a discriminant-identifier rather than a
  /// tag-type (ISO/IEC 10206:1991 §6.4.3.4). See `Type::discSelector`.
  bool discSelector = false;
  int line = 0, col = 0;
};

/// A Pascal type. Simple types are shared singletons; every array or record
/// *type-denoter* in the source produces one of these, and a type identifier
/// names the one its definition produced. Identity is therefore what ISO 7185
/// §6.4.5 calls "the same type", so structured types compare by pointer —
/// see ADR-0017.
struct Type {
  TypeKind kind;

  explicit Type(TypeKind k) : kind(k) {}

  // --- array, pointer, file ------------------------------------------------
  /// Array: the component type. Pointer: the domain — what it points at, null
  /// only for `nil` itself, which belongs to every pointer type. File: the
  /// component type, which is `char` for a text file. Proc: the result type,
  /// null for a procedural parameter as against a functional one. Sharing the
  /// field is how a variant record would do it, which is where this is going.
  Type *elem = nullptr;
  /// The ordinal type of a subscript — and, for a direct-access file
  /// (ISO/IEC 10206:1991 §6.4.3.6), of a position. The two never collide: a
  /// file is not an array.
  Type *indexType = nullptr;
  bool packed = false;
  bool textFile = false; // File: this is `text`, not a `file of char`

  /// Array: the index bounds. Subrange: the bounds themselves. Both inclusive.
  long long lo = 0, hi = -1;

  // --- subrange ------------------------------------------------------------
  Type *host = nullptr; // the ordinal type this is a subrange of

  // --- enumeration ---------------------------------------------------------
  std::vector<std::string> enumNames;

  // --- record --------------------------------------------------------------
  std::vector<Field> fields;   // the fixed part, including the tag field
  std::vector<Variant> variants;
  int tagField = -1;           // index into `fields`, or -1 when the tag has
                               // no name of its own (ISO 7185 §6.4.3.3)
  Type *tagType = nullptr;
  /// ISO/IEC 10206:1991 §6.4.3.4 spells a variant-selector `[tag-field ':']
  /// tag-type | discriminant-identifier`, and this says it was the third form.
  /// The selector is then not a field — the tuple holds it — so the *layout*
  /// is a tagless `case T of` and codegen never asks. What it changes is that
  /// §6.7.5.3 requires a tag-type of every variant-part `new(p, c1, ..., cn)`
  /// selects, so this variant part is not one a tag value may choose.
  bool discSelector = false;

  /// The identifier a `type` definition gave this, purely for diagnostics.
  std::string alias;

  // --- schemata (ISO/IEC 10206:1991 §6.4.7, §6.4.8) ------------------------
  /// The schema this type was produced from, and the discriminant tuple it
  /// was produced with. Null for every type written out in full. Sema interns
  /// by the pair, so §6.4.8's "one tuple, one type" needs no rule in
  /// `assignable`: two productions with equal tuples *are* the same object,
  /// and ADR-0017's identity comparison then says what the standard says.
  Symbol *schema = nullptr;
  std::vector<long long> tuple;
  bool isSchematic() const { return schema != nullptr; }

  // --- schematic formal parameters (§6.7.3.2, §6.7.3.3) --------------------
  /// A bound that is not known until the block is entered: the discriminant
  /// the source wrote there, whose value arrives with the actual. `lo`/`hi`
  /// are then not the bound and nothing reads them. Null for every bound
  /// written as a constant, which is every bound outside a schematic formal.
  Symbol *loDisc = nullptr, *hiDisc = nullptr;

  /// This type's tuple is in a header immediately before the variable rather
  /// than in an activation record: it is the domain of a pointer, written as a
  /// bare schema-name (§6.4.4), and `new` supplied the tuple (ADR-0043). The
  /// bounds are then read from the object's own address, so a designator of
  /// this type carries its tuple with it wherever it is passed.
  bool heapTuple = false;
  /// The symbol whose `discSyms` are this heap type's discriminants. It is in
  /// no scope and has no storage of its own — it exists because a heap
  /// variable is reached through `p^` rather than by a name, so there is no
  /// other symbol to hang them on.
  Symbol *descOwner = nullptr;

  /// The type of a schematic formal parameter: produced from a schema, but
  /// with no tuple — the tuple arrives with the actual, in the descriptor that
  /// travels beside its address. A schema with no discriminants is refused, so
  /// an empty tuple cannot mean anything else.
  bool isGeneric() const { return schema && tuple.empty(); }

  /// This type's own bounds are not known until run time.
  bool dynamicBounds() const { return loDisc || hiDisc; }

  /// ...and neither is its size: an array of dynamically-bounded arrays has a
  /// dynamic extent at every level, and so does a record whose **last** field
  /// has one. Only the last, because a field after it would sit at an offset
  /// nothing could compute — which is why this reads `fields.back()` and not
  /// "any field". A record with a dynamic field anywhere else is not a type
  /// with a dynamic extent; it is a type that is refused (ADR-0045).
  bool dynamicExtent() const {
    if (dynamicBounds())
      return true;
    if (isArray())
      return elem && elem->dynamicExtent();
    return kind == TypeKind::Record && !fields.empty() &&
           fields.back().type && fields.back().type->dynamicExtent();
  }

  // These ask what a value *is*, so they look through a subrange to its host:
  // `1..9` is an integer that happens to be range-checked, and every rule
  // about integers applies to it unchanged.
  bool isInteger() const { return base()->kind == TypeKind::Integer; }
  bool isReal() const { return kind == TypeKind::Real; }
  /// A type produced from the required schema `string` (§6.4.3.3.3), or the
  /// canonical-string-type that `+` yields.
  bool isVarString() const { return kind == TypeKind::String; }
  /// §6.4.3.3.1: "A string-type shall be a fixed-string-type or a
  /// variable-string-type or the required type designated
  /// canonical-string-type." A fixed-string-type is §6.4.3.3.2's `packed
  /// array [1..n] of char`, which ISO 7185 already had and already gave the
  /// relational operators.
  bool isStringType() const { return isVarString() || isCharArray(); }
  /// §6.4.3.3.1 gives the char-type "length 1 and capacity 1", so it stands
  /// wherever a string does — in a comparison, a concatenation, an assignment
  /// — without being one.
  bool isStringOrChar() const { return isStringType() || isChar(); }
  /// The canonical-string-type: a string *value* with no storage behind it.
  /// It has no capacity, which is exactly what makes it assignable to any
  /// string type whose capacity the value's length happens to fit.
  bool isCanonicalString() const { return isVarString() && hi < 0; }
  bool isComplex() const { return kind == TypeKind::Complex; }
  bool isNumeric() const { return isInteger() || isReal(); }
  /// Everything the arithmetic operators accept (§6.8.3.2, table 3). Kept
  /// apart from `isNumeric` because the *ordering* operators take a numeric
  /// type and refuse a complex one — §6.8.3.5 admits only `=` and `<>` there,
  /// there being no order on the complex numbers.
  bool isArith() const { return isNumeric() || isComplex(); }
  bool isBoolean() const { return base()->kind == TypeKind::Boolean; }
  bool isChar() const { return base()->kind == TypeKind::Char; }
  bool isEnum() const { return base()->kind == TypeKind::Enum; }
  bool isSubrange() const { return kind == TypeKind::Subrange; }
  bool isArray() const { return kind == TypeKind::Array; }
  bool isRecord() const { return kind == TypeKind::Record; }
  bool isPointer() const { return kind == TypeKind::Pointer; }
  bool isFile() const { return kind == TypeKind::File; }
  /// `text` as against `file of char`. ISO 7185 §6.4.3.5 makes them different
  /// types and gives only the first one lines: `readln`, `writeln`, `eoln` and
  /// reading a number all belong to a text file and to nothing else. The two
  /// are otherwise identical, right down to the component size, so nothing but
  /// this flag distinguishes them.
  bool isText() const { return isFile() && textFile; }
  /// ISO/IEC 10206:1991 §6.4.3.6: a file-type with an index-type. It is the
  /// index-type's presence and nothing else that makes a file direct-access —
  /// `text` never has one, and §6.4.3.6 says so explicitly.
  /// ISO/IEC 10206:1991 §6.4.3.6: a file-type with an index-type. It is the
  /// index-type's presence and nothing else that makes a file direct-access —
  /// `text` never has one, and §6.4.3.6 says so explicitly. The type is kept
  /// in `indexType`, which an array already used for the same idea and which
  /// a file has no other use for.
  bool isDirectAccess() const { return isFile() && indexType != nullptr; }
  bool isSet() const { return kind == TypeKind::Set; }
  /// The type of a procedural or functional parameter (ISO 7185 §6.6.3.1).
  /// There is no way to *write* one outside a formal parameter list — the type
  /// part has no procedure type — so no variable ever has this type, and it
  /// takes part in no operation but being passed on and being called.
  bool isProc() const { return kind == TypeKind::Proc; }
  /// `[]`, which belongs to every set type — the set-valued counterpart of
  /// `nil`, and null for the same reason: it has no base type of its own.
  bool isEmptySet() const { return isSet() && elem == nullptr; }
  /// `nil`, which is a value of every pointer type and of no other.
  bool isNil() const { return isPointer() && elem == nullptr; }

  /// Arrays and records live in memory and are copied wholesale; simple types
  /// live in registers. The distinction drives assignment, parameter passing,
  /// and whether an expression may be loaded at all.
  ///
  /// A file is *not* structured. It also lives in memory, but it may never be
  /// copied — ISO 7185 §6.6.3.3 bars it from being a value parameter and there
  /// is no assignment between file variables — so grouping it here would grant
  /// it exactly the operations it must not have. `isFile()` is asked for
  /// separately wherever an address is what travels.
  ///
  /// A set is not structured either, and for the opposite reason to a file: it
  /// *is* a value. Every set is one 256-bit integer, so it is assigned,
  /// compared and passed exactly as an integer is, and none of the machinery
  /// that exists to move structured values around by address applies to it.
  /// A variable-string is *not* structured, and the exclusion is the same
  /// shape as a file's: `isStructured()` grants a whole-variable copy, and a
  /// string assignment is not one — §6.4.6 pads a short value with spaces or
  /// refuses a long one, so it is a runtime operation and not a memcpy.
  bool isStructured() const {
    // §6.4.2.5 associates a restricted-type's states one-to-one with the
    // underlying-type's, so *how a value travels* is the underlying-type's
    // question — a restricted record is copied and passed by address exactly
    // as the record is. This and `isMemory` are the only two predicates that
    // see through, and that is what confines the feature: everything else
    // answers `false` and refuses the operation where it stood.
    if (isRestricted())
      return elem->isStructured();
    return isArray() || isRecord();
  }

  /// ISO/IEC 10206:1991 §6.4.2.5's restricted-type. `elem` is the
  /// underlying-type.
  bool isRestricted() const { return kind == TypeKind::Restricted; }

  /// The type a restricted-type restricts, and the type itself otherwise —
  /// §6.4.2.5: "The underlying-type of a type that is not restricted shall be
  /// the type." Written so a caller need not ask which it has.
  const Type *underlying() const { return isRestricted() ? elem : this; }
  Type *underlying() { return isRestricted() ? elem : this; }

  /// True for anything whose value never occupies a register: it is reached
  /// through its address, and a parameter of it arrives as one.
  bool isMemory() const {
    if (isRestricted())
      return elem->isMemory();
    return isStructured() || isFile() || isVarString();
  }

  /// ISO/IEC 10206:1991 §6.4.1: a type is protectable unless it is a file or a
  /// pointer, or is structured and holds one. The standard's own NOTE gives
  /// both reasons: nearly every operation on a file modifies it, and a pointer
  /// *value* can be copied out and disposed of — so protecting the variable
  /// would protect nothing. Only §6.7.3.1 asks this today.
  bool protectable() const {
    if (isFile() || isPointer())
      return false;
    if (isArray())
      return elem && elem->protectable();
    if (isRecord()) {
      for (const Field &f : fields)
        if (f.type && !f.type->protectable())
          return false;
    }
    return true;
  }

  /// The type a subrange is a subrange of; every other type is its own base.
  /// Assignment compatibility, arithmetic, and the machine representation are
  /// all decided on the base, which is what makes `1..9` an integer that
  /// happens to be checked (ISO 7185 §6.4.2.4).
  Type *base() { return isSubrange() && host ? host : this; }
  const Type *base() const { return isSubrange() && host ? host : this; }

  bool isOrdinal() const {
    switch (base()->kind) {
    case TypeKind::Integer:
    case TypeKind::Boolean:
    case TypeKind::Char:
    case TypeKind::Enum:
      return true;
    default:
      return false;
    }
  }

  /// The first and last values of an ordinal type — what `succ` and `pred` run
  /// out at, and what a subrange assignment is checked against.
  long long ordinalLo() const {
    if (isSubrange()) return lo;
    switch (kind) {
    case TypeKind::Integer: return -static_cast<long long>(kMaxInt);
    default:                return 0;
    }
  }
  long long ordinalHi() const {
    if (isSubrange()) return hi;
    switch (kind) {
    case TypeKind::Integer: return kMaxInt;
    case TypeKind::Char:    return 255;
    case TypeKind::Boolean: return 1;
    case TypeKind::Enum:    return static_cast<long long>(enumNames.size()) - 1;
    default:                return 0;
    }
  }

  /// Integers are the only ordinal with negative values, so every other one
  /// compares and widens as unsigned.
  bool isSignedOrdinal() const { return base()->isInteger(); }

  long long length() const { return hi - lo + 1; }

  /// A `packed array [m..n] of char` — the type ISO 7185 §6.4.3.2 gives a
  /// string literal, and the only structured type with its own operators.
  bool isCharArray() const {
    return isArray() && packed && elem && elem->isChar();
  }

  /// ISO 7185 §6.4.3.3 requires every field name in a record to be distinct,
  /// variants included, so one flat search over all of them is unambiguous.
  /// Whether the field is currently *selected* is a run-time question the
  /// standard leaves to the program.
  const Field *findField(const std::string &n) const {
    for (const Field &f : fields)
      if (f.name == n)
        return &f;
    return findFieldIn(variants, n);
  }

  /// The same search through one level of arms and everything nested in them.
  static const Field *findFieldIn(const std::vector<Variant> &arms,
                                  const std::string &n) {
    for (const Variant &v : arms) {
      for (const Field &f : v.fields)
        if (f.name == n)
          return &f;
      if (const Field *f = findFieldIn(v.variants, n))
        return f;
    }
    return nullptr;
  }

  /// The field-list at a variant path: the record's own for an empty path,
  /// and one arm's for each further index. §6.4.3.3 makes an arm's field-list
  /// a field-list like any other (ADR-0026), so everything that walks a record
  /// walks arms with the same three functions — which is why they live on the
  /// type rather than in one pass. CodeGen had them first; Sema needs the same
  /// answers to decide whether a §6.8.7 record-value is complete.
  const std::vector<Variant> &armsAt(const std::vector<int> &path) const {
    const std::vector<Variant> *arms = &variants;
    for (int k : path)
      arms = &(*arms)[k].variants;
    return *arms;
  }

  const std::vector<Field> &fieldsAt(const std::vector<int> &path) const {
    if (path.empty())
      return fields;
    const std::vector<Variant> *arms = &variants;
    for (size_t i = 0; i + 1 < path.size(); ++i)
      arms = &(*arms)[path[i]].variants;
    return (*arms)[path.back()].fields;
  }

  /// The index into `fieldsAt(path)` of the selector's own field, or -1 for a
  /// tagless variant part and for a discriminant-selected one (§6.4.3.4,
  /// ADR-0044) — neither has a field anywhere.
  int tagFieldAt(const std::vector<int> &path) const {
    if (path.empty())
      return tagField;
    const std::vector<Variant> *arms = &variants;
    for (size_t i = 0; i + 1 < path.size(); ++i)
      arms = &(*arms)[path[i]].variants;
    return (*arms)[path.back()].tagField;
  }

  Type *tagTypeAt(const std::vector<int> &path) const {
    if (path.empty())
      return tagType;
    const std::vector<Variant> *arms = &variants;
    for (size_t i = 0; i + 1 < path.size(); ++i)
      arms = &(*arms)[path[i]].variants;
    return (*arms)[path.back()].tagType;
  }

  /// A description for diagnostics. A named type reports its name; an
  /// anonymous one is spelled out the way the source would have written it.
  std::string name() const {
    if (!alias.empty())
      return alias;
    switch (kind) {
    case TypeKind::Integer: return "integer";
    case TypeKind::Real:    return "real";
    case TypeKind::String:
      return hi < 0 ? "string" : "string(" + std::to_string(hi) + ")";
    case TypeKind::Complex: return "complex";
    // §6.4.2.5's own spelling. A restricted-type is nearly always named — the
    // whole point of one is a type-name whose structure is hidden — so this is
    // reached mostly by the anonymous form in a diagnostic about a parameter.
    case TypeKind::Restricted:
      return "restricted " + (elem ? elem->name() : std::string("?"));
    case TypeKind::Boolean: return "boolean";
    case TypeKind::Char:    return "char";
    case TypeKind::Void:    return "void";
    case TypeKind::Enum: {
      std::string s = "(";
      for (size_t i = 0; i < enumNames.size(); ++i)
        s += (i ? ", " : "") + enumNames[i];
      return s + ")";
    }
    case TypeKind::Subrange:
      return boundName(host, loDisc, lo) + ".." + boundName(host, hiDisc, hi);
    // ISO 7185 §6.4.4 makes a pointer's domain a type *identifier*, so the
    // recursion here always stops at a name — which is what lets a type point
    // at itself without this looping forever.
    case TypeKind::Pointer:
      return elem ? "^" + elem->name() : "nil";
    // `text` names itself; every other file names its component, because a
    // `file of char` is a different type from a text and a diagnostic that
    // called them both "text" would be describing the wrong one.
    case TypeKind::File:
      // A direct-access file names its index type too (§6.4.3.6): it is what
      // makes the type direct-access, so a diagnostic that left it out would
      // be describing a different type.
      return textFile ? "text"
             : indexType
                 ? "file [" + indexType->name() + "] of " +
                       (elem ? elem->name() : "?")
                 : "file of " + (elem ? elem->name() : "?");
    // The type of `[]` names no base type because it has none; it is written
    // the way the source writes it.
    case TypeKind::Set:
      return elem ? "set of " + elem->name() : "[]";
    // Two procedural parameters differ by their *parameter lists*, and ISO
    // 7185 §6.6.3.6 compares those pairwise rather than as a whole; the
    // congruity diagnostic names the parameter that failed, so spelling a
    // signature out here would say less at more cost.
    case TypeKind::Proc:
      return elem ? "function returning " + elem->name() : "procedure";
    case TypeKind::Record: {
      // An anonymous record is named by its fields, which is the only thing
      // that distinguishes it from any other anonymous record.
      std::string s = "record ";
      for (size_t i = 0; i < fields.size(); ++i)
        s += (i ? ", " : "") + fields[i].name;
      return s + " end";
    }
    case TypeKind::Array:
      break;
    }
    std::string s = packed ? "packed array [" : "array [";
    s += boundName(indexType, loDisc, lo) + ".." + boundName(indexType, hiDisc, hi);
    return s + "] of " + (elem ? elem->name() : "?");
  }

  /// How a bound is written when it may be dynamic: a constant as itself, and
  /// a discriminant as its own name. Defined out of line because a `Symbol` is
  /// incomplete here.
  static std::string boundName(const Type *t, const Symbol *disc,
                               long long value);

  /// How a value of an ordinal type is written in source: `7`, `'a'`, `true`,
  /// or an enumeration constant's own name.
  static std::string ordinalName(const Type *t, long long value) {
    const Type *b = t ? t->base() : nullptr;
    if (!b)
      return std::to_string(value);
    // A printable character is written as itself; anything else is written as
    // chr(n). Not cosmetic: a diagnostic is printed with %s, so a char of
    // value 0 written literally would truncate the message at that point —
    // `array [` and nothing more.
    if (b->kind == TypeKind::Char) {
      if (value >= 32 && value < 127)
        return "'" + std::string(1, static_cast<char>(value)) + "'";
      return "chr(" + std::to_string(value) + ")";
    }
    if (b->kind == TypeKind::Boolean)
      return value ? "true" : "false";
    if (b->kind == TypeKind::Enum && value >= 0 &&
        value < static_cast<long long>(b->enumNames.size()))
      return b->enumNames[static_cast<size_t>(value)];
    return std::to_string(value);
  }
};

namespace ty {
inline Type *get(TypeKind k) {
  static Type v{TypeKind::Void};
  static Type i{TypeKind::Integer};
  static Type r{TypeKind::Real};
  static Type b{TypeKind::Boolean};
  static Type c{TypeKind::Char};
  static Type z{TypeKind::Complex};
  switch (k) {
  case TypeKind::Integer: return &i;
  case TypeKind::Real:    return &r;
  case TypeKind::Boolean: return &b;
  case TypeKind::Char:    return &c;
  case TypeKind::Complex: return &z;
  default:                break;
  }
  return &v;
}
inline Type *Int()  { return get(TypeKind::Integer); }
inline Type *Real() { return get(TypeKind::Real); }
inline Type *Complex() { return get(TypeKind::Complex); }
/// ISO/IEC 10206:1991 §6.4.3.3.1's canonical-string-type: the type of every
/// string *value* — a literal's, `+`'s, `substr`'s and `trim`'s. It has no
/// capacity (`hi` is negative) because it has no storage: a value is only
/// ever on its way into something that does, and §6.4.6 checks it against
/// *that* capacity. No type-denoter produces one, so no variable has it.
inline Type *CanonicalString() {
  static Type s = [] {
    Type t{TypeKind::String};
    t.lo = 1;
    t.hi = -1;
    return t;
  }();
  return &s;
}
inline Type *Bool() { return get(TypeKind::Boolean); }
inline Type *Char() { return get(TypeKind::Char); }
inline Type *Void() { return get(TypeKind::Void); }
/// The type of `nil`: a pointer with no domain, assignable to any pointer.
inline Type *Nil() {
  static Type n{TypeKind::Pointer};
  return &n;
}
/// The type of `[]`: a set with no base type, and a value of every set type.
/// ISO 7185 §6.4.6 makes set compatibility structural — two sets are
/// compatible when their base types are — so unlike `nil` this is not an
/// exception to name equivalence but the ordinary rule with nothing to compare.
inline Type *EmptySet() {
  static Type s{TypeKind::Set};
  return &s;
}
/// `text`, the predefined file of char (ISO 7185 §6.4.3.5). A singleton like
/// the other predefined types, so every variable declared `text` has the same
/// type — a `file of char` written out longhand is a different one, exactly as
/// ADR-0017's name equivalence says it should be.
inline Type *Text() {
  static Type t = [] {
    Type f{TypeKind::File};
    f.elem = Char();
    f.textFile = true;
    f.alias = "text";
    return f;
  }();
  return &t;
}
} // namespace ty

} // namespace ap
