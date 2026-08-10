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
  File
};

struct Type;

/// One field of a record. `index` is the position in the LLVM struct it
/// belongs to, which is also the declaration order — codegen indexes by it and
/// never by name. `variant` says which struct that is: empty is the record's
/// fixed part, `[k]` is arm k of its variant part, `[k, j]` is arm j of the
/// variant part *inside* arm k, and so on. ISO 7185 §6.4.3.3 puts no limit on
/// the nesting, so a single index could not say where a field lives.
struct Field {
  std::string name;
  Type *type = nullptr;
  int index = 0;
  std::vector<int> variant;
  int line = 0, col = 0;
};

/// One arm of a variant part: the tag values that select it, and the fields
/// that exist while it is selected. An arm is shaped exactly like a record —
/// a fixed part and an optional variant part of its own — because that is what
/// §6.4.3.3 makes it: its field-list is a field-list like any other.
struct Variant {
  std::vector<long long> labels;
  std::vector<Field> fields;
  std::vector<Variant> variants;
  int tagField = -1;           // index into `fields`, or -1 when the nested
                               // tag has no field of its own
  Type *tagType = nullptr;
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
  /// component type, which is `char` for a text file. Sharing the field is how
  /// a variant record would do it, which is where this is going.
  Type *elem = nullptr;
  Type *indexType = nullptr; // the ordinal type of a subscript
  bool packed = false;

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

  /// The identifier a `type` definition gave this, purely for diagnostics.
  std::string alias;

  // These ask what a value *is*, so they look through a subrange to its host:
  // `1..9` is an integer that happens to be range-checked, and every rule
  // about integers applies to it unchanged.
  bool isInteger() const { return base()->kind == TypeKind::Integer; }
  bool isReal() const { return kind == TypeKind::Real; }
  bool isNumeric() const { return isInteger() || isReal(); }
  bool isBoolean() const { return base()->kind == TypeKind::Boolean; }
  bool isChar() const { return base()->kind == TypeKind::Char; }
  bool isEnum() const { return base()->kind == TypeKind::Enum; }
  bool isSubrange() const { return kind == TypeKind::Subrange; }
  bool isArray() const { return kind == TypeKind::Array; }
  bool isRecord() const { return kind == TypeKind::Record; }
  bool isPointer() const { return kind == TypeKind::Pointer; }
  bool isFile() const { return kind == TypeKind::File; }
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
  bool isStructured() const { return isArray() || isRecord(); }

  /// True for anything whose value never occupies a register: it is reached
  /// through its address, and a parameter of it arrives as one.
  bool isMemory() const { return isStructured() || isFile(); }

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

  /// A description for diagnostics. A named type reports its name; an
  /// anonymous one is spelled out the way the source would have written it.
  std::string name() const {
    if (!alias.empty())
      return alias;
    switch (kind) {
    case TypeKind::Integer: return "integer";
    case TypeKind::Real:    return "real";
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
      return ordinalName(host, lo) + ".." + ordinalName(host, hi);
    // ISO 7185 §6.4.4 makes a pointer's domain a type *identifier*, so the
    // recursion here always stops at a name — which is what lets a type point
    // at itself without this looping forever.
    case TypeKind::Pointer:
      return elem ? "^" + elem->name() : "nil";
    case TypeKind::File:
      return elem && elem->isChar() ? "text" : "file";
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
    s += ordinalName(indexType, lo) + ".." + ordinalName(indexType, hi);
    return s + "] of " + (elem ? elem->name() : "?");
  }

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
  switch (k) {
  case TypeKind::Integer: return &i;
  case TypeKind::Real:    return &r;
  case TypeKind::Boolean: return &b;
  case TypeKind::Char:    return &c;
  default:                break;
  }
  return &v;
}
inline Type *Int()  { return get(TypeKind::Integer); }
inline Type *Real() { return get(TypeKind::Real); }
inline Type *Bool() { return get(TypeKind::Boolean); }
inline Type *Char() { return get(TypeKind::Char); }
inline Type *Void() { return get(TypeKind::Void); }
/// The type of `nil`: a pointer with no domain, assignable to any pointer.
inline Type *Nil() {
  static Type n{TypeKind::Pointer};
  return &n;
}
/// `text`, the predefined file of char (ISO 7185 §6.4.3.5). A singleton like
/// the other predefined types, so every variable declared `text` has the same
/// type — a `file of char` written out longhand is a different one, exactly as
/// ADR-0017's name equivalence says it should be.
inline Type *Text() {
  static Type t = [] {
    Type f{TypeKind::File};
    f.elem = Char();
    f.alias = "text";
    return f;
  }();
  return &t;
}
} // namespace ty

} // namespace ap
