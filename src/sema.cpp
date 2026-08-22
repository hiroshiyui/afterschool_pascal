#include "sema.h"

#include <climits>
#include <unordered_map>

namespace ap {

namespace {

const char *opName(BinOp op) {
  switch (op) {
  case BinOp::Add: return "+";
  case BinOp::Sub: return "-";
  case BinOp::Mul: return "*";
  case BinOp::RealDiv: return "/";
  case BinOp::IntDiv: return "div";
  case BinOp::Mod: return "mod";
  case BinOp::And: return "and";
  case BinOp::Or: return "or";
  case BinOp::Exp: return "**";
  case BinOp::Pow: return "pow";
  case BinOp::AndThen: return "and then";
  case BinOp::OrElse: return "or else";
  case BinOp::SymDiff: return "><";
  case BinOp::Eq: return "=";
  case BinOp::Ne: return "<>";
  case BinOp::Lt: return "<";
  case BinOp::Le: return "<=";
  case BinOp::Gt: return ">";
  case BinOp::Ge: return ">=";
  case BinOp::In: return "in";
  }
  return "?";
}

bool isRelational(BinOp op) {
  switch (op) {
  case BinOp::Eq: case BinOp::Ne: case BinOp::Lt:
  case BinOp::Le: case BinOp::Gt: case BinOp::Ge:
    return true;
  default:
    return false;
  }
}

const std::unordered_map<std::string, Builtin> &builtins() {
  static const std::unordered_map<std::string, Builtin> m = {
      {"abs", Builtin::Abs},     {"sqr", Builtin::Sqr},
      {"odd", Builtin::Odd},     {"ord", Builtin::Ord},
      {"chr", Builtin::Chr},     {"succ", Builtin::Succ},
      {"pred", Builtin::Pred},   {"sqrt", Builtin::Sqrt},
      {"sin", Builtin::Sin},     {"cos", Builtin::Cos},
      {"ln", Builtin::Ln},       {"exp", Builtin::Exp},
      {"arctan", Builtin::ArcTan}, {"trunc", Builtin::Trunc},
      {"round", Builtin::Round}, {"eof", Builtin::Eof},
      {"eoln", Builtin::Eoln},
      // ISO/IEC 10206:1991 §6.7.6.2 and §6.7.6.3. Looked up under both
      // standards and refused under ISO 7185, the same way `**` is: a valid
      // ISO 7185 program may declare a function called `re`, so the *name* is
      // not reserved — the refusal happens where the call is checked, and only
      // when no declaration of that name was found.
      {"card", Builtin::Card},
      {"cmplx", Builtin::Cmplx}, {"polar", Builtin::Polar},
      {"re", Builtin::Re},       {"im", Builtin::Im},
      {"arg", Builtin::Arg},
      // §6.7.6.6 and §6.7.6.5. Required identifiers like the complex ones, so
      // a declaration of the same name wins and ISO 7185 refuses them.
      {"position", Builtin::Position},
      {"lastposition", Builtin::LastPosition},
      {"empty", Builtin::Empty}, {"binding", Builtin::Binding},
      // §6.7.6.7. Required identifiers, so a program may declare its own.
      {"length", Builtin::Length}, {"index", Builtin::Index},
      {"substr", Builtin::Substr}, {"trim", Builtin::Trim},
      {"eq", Builtin::StrEq},      {"ne", Builtin::StrNe},
      {"lt", Builtin::StrLt},      {"gt", Builtin::StrGt},
      {"le", Builtin::StrLe},      {"ge", Builtin::StrGe},
      // §6.7.6.9. Required identifiers too, and the two here most likely to
      // collide with a program's own —
      // `tests/extended/timestamp_redeclared.pas` is a program that declares
      // all four.
      {"date", Builtin::Date},     {"time", Builtin::Time},
  };
  return m;
}

// There was a `builtinType(name, std)` here, resolving a required
// type-identifier by *spelling* before the scope was consulted. §6.2.2.10 puts
// those defining-points in a region enclosing the program, so they belong in
// the outermost scope and nowhere else: while the type-denoters asked this
// function first, `type integer = char` was accepted and then ignored
// (ADR-0097). `installPredefined` is where the six names live now.

} // namespace

// ------------------------------------------------------------------- scopes

Symbol *Sema::newSymbol() {
  owned_.push_back(std::make_unique<Symbol>());
  return owned_.back().get();
}

Symbol *Sema::declare(const std::string &name, SymKind kind, int line,
                      int col) {
  auto &scope = scopes_.back();
  auto it = scope.find(name);
  if (it != scope.end()) {
    diags_.error(line, col, "'" + name + "' is already declared in this block");
    return it->second;
  }
  // ISO 7185 §6.2.2.9: "The defining-point of an identifier or label shall
  // precede all applied occurrences of that identifier or label contained by
  // the program-block". So a name already used in this block may not now be
  // declared in it, even where the earlier use resolved and its defining-point
  // is in an enclosing region.
  //
  // Enforced until now only where the name resolved to nothing (ADR-0069's
  // `var v: t` before `type t`), because that is the only case anything
  // noticed. Where it resolved to an outer declaration the earlier uses kept
  // the outer meaning and this one silently took effect from here down.
  //
  // The comparison is with the block being declared into, not with a depth: a
  // sibling procedure's body is at the same depth and is not in this block,
  // and shadowing there is exactly what the rule permits (ADR-0088).
  if (Symbol *outer = lookupRaw(name))
    if (outer->usedSeq > scopeMark_.back())
      diags_.error(line, col,
                   "'" + name + "' is already used in this block, so "
                   "declaring it here would give one name two meanings");
  Symbol *s = newSymbol();
  s->name = name;
  s->kind = kind;
  scope[name] = s;
  return s;
}

void Sema::bindName(const std::string &name, Symbol *sym, int line, int col) {
  auto &scope = scopes_.back();
  auto it = scope.find(name);
  if (it != scope.end()) {
    diags_.error(line, col, "'" + name + "' is already declared in this block");
    return;
  }
  scope[name] = sym;
}

/// Innermost-first lookup, which is what makes an inner declaration shadow an
/// outer one of the same name.
Symbol *Sema::lookupRaw(const std::string &name) const {
  for (auto scope = scopes_.rbegin(); scope != scopes_.rend(); ++scope) {
    auto it = scope->find(name);
    if (it != scope->end())
      return it->second;
  }
  return nullptr;
}

Symbol *Sema::lookup(const std::string &name) {
  Symbol *found = lookupRaw(name);
  if (found)
    found->usedSeq = ++applySeq_;
  return found;
}

Symbol *Sema::lookupUser(const std::string &name) {
  Symbol *s = lookup(name);
  return (s && s->kind == SymKind::Required) ? nullptr : s;
}

/// Declare a variable, parameter, or function result and give it a slot in the
/// activation record of `owner`.
Symbol *Sema::addFrameVar(const std::string &name, SymKind kind, Type *type,
                          Symbol *owner, int line, int col) {
  Symbol *s = declare(name, kind, line, col);
  if (s->type) // a duplicate: keep the first declaration
    return s;
  s->type = type;
  s->level = owner->level;
  s->owner = owner;
  s->frameIndex = static_cast<int>(owner->frameVars.size());
  owner->frameVars.push_back(s);
  return s;
}

/// A frame slot with no name: nothing can refer to it by spelling, but it is
/// an ordinary frame variable in every other respect, so it is per-invocation.
Symbol *Sema::addHiddenVar(const std::string &name, SymKind kind, Type *type,
                           Symbol *owner) {
  Symbol *s = newSymbol();
  s->name = name;
  s->kind = kind;
  s->type = type;
  s->level = owner->level;
  s->owner = owner;
  s->frameIndex = static_cast<int>(owner->frameVars.size());
  owner->frameVars.push_back(s);
  return s;
}

// -------------------------------------------------------------------- types

Type *Sema::newType(TypeKind kind) {
  types_.push_back(std::make_unique<Type>(kind));
  return types_.back().get();
}

Type *Sema::stringType(long long length) {
  auto it = stringTypes_.find(length);
  if (it != stringTypes_.end())
    return it->second;
  Type *t = newType(TypeKind::Array);
  t->elem = ty::Char();
  t->indexType = ty::Int();
  t->lo = 1;
  t->hi = length;
  t->packed = true;
  stringTypes_[length] = t;
  return t;
}

/// The ordinal of a folded value, whichever field its type selected.
long long Sema::ordinalOf(const Symbol &v) {
  if (v.type->isChar())
    return static_cast<unsigned char>(v.charVal);
  if (v.type->base()->kind == TypeKind::Boolean)
    return v.boolVal ? 1 : 0;
  return v.intVal; // integer, and the ordinal of an enumeration constant
}

bool Sema::evalOrdinal(Expr *e, Type *&type, long long &value) {
  // Cleared *before* the expression is checked and not after it, so a reason
  // given by the checker counts as one the caller need not repeat. The only
  // one that does so is §6.4.3.3's region (ADR-0134): `array [1..fred]` beside
  // a field `fred` names no constant, and "the bounds of a subrange must be
  // ordinal constants" after that is the same mistake said again and vaguely.
  constReported_ = false;
  checkExpr(e);
  Symbol out;
  if (!evalConst(e, out) || !out.type || !out.type->isOrdinal())
    return false;
  type = out.type;
  value = ordinalOf(out);
  return true;
}

/// An enumerated type also *declares* its constants, into whatever scope the
/// type itself appears in (ISO 7185 §6.4.2.3) — which is why this is done here
/// rather than by the declaration part that happens to contain it.
Type *Sema::resolveEnum(TypeExpr &denoter) {
  // §6.4.2.3 puts the defining-point of an enumerated-type's constants in "the
  // block, module-heading, or module-block closest-containing the
  // enumerated-type" — the block, not the production. So an enumerated type in
  // a schema's body is resolved once, at the schema-definition, into the
  // block's own scope, and every production reuses it (ADR-0107). That is what
  // `checkSchemaBodyNames` does, and what keeps `forgetResolved` from clearing
  // an Enum's `resolved`: a second resolution would declare the constants
  // again, into a scope that lives only as long as the production.
  //
  // This was refused outright, on the argument that the constants would be
  // declared once per tuple. They are declared once per *block*, which is the
  // clause's own answer to that.
  Type *t = newType(TypeKind::Enum);
  for (DeclName &n : denoter.constants) {
    Symbol *s = declare(n.name, SymKind::Const, n.line, n.col);
    if (s->type)
      continue; // already declared: keep the first
    s->type = t;
    s->intVal = static_cast<long long>(t->enumNames.size());
    t->enumNames.push_back(n.name);
  }
  return t;
}

/// Whether `name` is a field-identifier of this record type-denoter — a field
/// of the fixed part, a tag-field, or either inside any variant arm. Asked of
/// the *denoter* rather than of the `Type`, because the field does not exist
/// on the type yet: this runs while the record is being resolved (ADR-0098).
static bool fieldNameInDenoter(const TypeExpr *d, const std::string &name) {
  for (const FieldGroup &g : d->fields)
    for (const DeclName &n : g.names)
      if (n.name == name)
        return true;
  if (!d->tagName.empty() && d->tagName == name)
    return true;
  std::vector<const VariantArm *> arms;
  for (const VariantArm &v : d->variants)
    arms.push_back(&v);
  for (size_t i = 0; i < arms.size(); ++i) {
    for (const FieldGroup &g : arms[i]->fields)
      for (const DeclName &n : g.names)
        if (n.name == name)
          return true;
    if (!arms[i]->tagName.empty() && arms[i]->tagName == name)
      return true;
    for (const VariantArm &v : arms[i]->variants)
      arms.push_back(&v);
  }
  return false;
}

// §6.4.3.3 gives a field-identifier its defining-point in the record-type
// closest-containing the field-list, and §6.2.2.4 makes its scope the whole of
// that region — so a spelling written anywhere inside a record type-denoter is
// an applied occurrence of the *field*, whatever else the program declared
// under that name outside, and a field is not a type. Every enclosing record is
// asked and not only the closest, because §6.2.2.4's scope includes "all
// regions enclosed by that region".
//
// Asked of the *denoter*, because the field does not exist on the type yet:
// this runs while the record is being resolved, which is also why the whole
// denoter is scanned rather than the part already seen. `record a: fred; fred:
// integer end` is refused for the field declared *after* the occurrence — the
// region is the record and not the text before the point (ADR-0098).
//
// A qualified name is nobody's field: §6.11.3's qualifier reaches an interface,
// and an interface has no fields.
bool Sema::fieldOfOpenRecord(const std::string &qualifier,
                             const std::string &name) const {
  if (!qualifier.empty())
    return false;
  for (const TypeExpr *r : openRecords_)
    if (fieldNameInDenoter(r, name))
      return true;
  return false;
}

void Sema::errorFieldNotA(int line, int col, const std::string &name,
                          bool wantType) {
  diags_.error(line, col,
               "'" + name + "' is a field of this record type, " +
                   (wantType ? "so it does not name a type here"
                             : "so it does not name a constant here"));
}

void Sema::errorFieldNotAType(int line, int col, const std::string &name) {
  errorFieldNotA(line, col, name, true);
}

/// A pointer's domain is a type identifier, and it may be one defined later in
/// the same type part — the language's only forward reference, and the reason
/// a record can contain a pointer to itself.
Type *Sema::resolvePointer(TypeExpr &denoter) {
  Type *t = newType(TypeKind::Pointer);

  // §6.4.4's domain-type wants a type-identifier, and this is a question about
  // regions rather than §6.2.2.9's order rule — whose pointer-domain exception
  // below stands untouched.
  if (fieldOfOpenRecord(denoter.qualifier, denoter.name)) {
    errorFieldNotAType(denoter.line, denoter.col, denoter.name);
    t->elem = ty::Int(); // keep the tree checkable
    return t;
  }

  // §6.4.4's domain-type is a `type-name` or a `schema-name`, and both carry
  // §6.11.3's optional interface qualifier — so an imported type may be a
  // pointer's domain, as it may be anything else a type-name reaches.
  //
  // `lookupRaw`, because §6.2.2.9 a) excepts "the domain-type of any
  // new-pointer-types contained by the type-definition-part containing the
  // defining-point of the type-identifier": this occurrence is the one that
  // does *not* have to be preceded by its defining-point. Recording it as an
  // applied occurrence would make `p = ^node; node = boolean` — the shape the
  // exception exists for — refuse itself, which is how this line came to be
  // written: tests/pointer_domain_shadow.pas failed (ADR-0088).
  Symbol *sym = denoter.qualifier.empty()
                    ? lookupRaw(denoter.name)
                    : lookupQuiet(denoter.qualifier, denoter.name);
  // §6.2.2.9: the domain binds to a type-identifier of *this* type-definition-
  // part when there is one, and an outer type of the same spelling does not
  // settle the question — the inner one may still be defined further down. So
  // a name found outside this scope waits with the names found nowhere at all,
  // and `resolvePendingPointers` looks it up again once the part is complete,
  // where the inner definition wins by ordinary shadowing. The suite's CONF027
  // is the program: `p = ^node` beside `node = boolean`, inside a procedure
  // whose program declares `node = integer`.
  if (sym && sym->kind == SymKind::Type && inTypePart_ &&
      denoter.qualifier.empty() && !scopes_.back().count(denoter.name)) {
    pendingPointers_.push_back({t, denoter.name, denoter.line, denoter.col});
    return t;
  }
  if (sym && sym->kind == SymKind::Type) {
    t->elem = sym->type;
    return t;
  }
  // §6.4.4: a domain-type may be a schema-name. It is resolved here rather
  // than deferred, because a pointer written in the *variable* part is past
  // the point where deferred domains are completed — unless the schema is the
  // one being produced, which is the recursion §6.4.7 permits in a pointer
  // domain and nowhere else. That one waits, and by the time it is completed
  // the schema's own type is in the memo.
  if (sym && sym->kind == SymKind::Schema) {
    bool busy = false;
    for (Symbol *s : producing_)
      busy = busy || s == sym;
    if (!busy) {
      t->elem = heapFromSchema(sym, denoter);
      return t;
    }
    pendingPointers_.push_back(
        {t, denoter.name, denoter.line, denoter.col, sym});
    return t;
  }
  // Not yet — it may arrive before the type part ends.
  pendingPointers_.push_back({t, denoter.name, denoter.line, denoter.col});
  return t;
}

/// ISO 7185 §6.4.3.4: a set type is `set of T` for an ordinal T, and the set of
/// values is the powerset of T's. The standard leaves the size to the
/// implementation, and this one fixes it at 256 bits — so T's values must lie
/// in 0..255. That admits `char` exactly, and every enumeration and small
/// subrange; it refuses `set of integer` rather than quietly keeping a prefix
/// of it, because a set that silently forgets members is worse than one that
/// does not compile.
Type *Sema::resolveSet(TypeExpr &denoter) {
  Type *t = newType(TypeKind::Set);
  Type *base = denoter.elem ? resolveType(*denoter.elem) : ty::Int();
  if (!base->isOrdinal()) {
    diags_.error(denoter.line, denoter.col,
                 "the base type of a set must be an ordinal type, found " +
                     base->name());
    base = ty::Char();
  } else if (base->ordinalLo() < 0 || base->ordinalHi() > kSetLimit) {
    diags_.error(denoter.line, denoter.col,
                 "a set base type must lie within 0.." +
                     std::to_string(kSetLimit) + ", but " + base->name() +
                     " spans " + Type::ordinalName(base, base->ordinalLo()) +
                     ".." + Type::ordinalName(base, base->ordinalHi()));
    base = ty::Char();
  }
  t->elem = base;
  t->packed = denoter.packed;
  return t;
}

/// The missing half of a message that names two types. §6.4.1 of both
/// standards makes each occurrence of a new-type denote a type distinct from
/// every other, so two type-denoters written alike denote two types — and
/// `Type::name()` then prints one spelling twice and the message says nothing
/// a reader can act on. "cannot assign array [1..3] of integer to a variable
/// of type array [1..3] of integer" is accurate and useless, which is the same
/// fault the file case beside the assignment check was given its own message
/// for.
///
/// It is empty whenever the spellings differ, so no message grows where it was
/// already saying something, and the caller needs no condition of its own.
///
/// The question asked is "do these two print alike", and
/// `selfhost/compiler.pas` has to ask it by rendering both through the `msgBuf`
/// sink, whose capacity is `strMax` — so a spelling that long cannot be
/// compared there. Neither compiler says anything about one, because a
/// diagnostic the two disagree about is worse than a diagnostic neither gives.
/// That is the coupling `fileSize` has with `PAS_FILE_SIZE`, and `difftest.sh`
/// is what reports a drift in it.
static const size_t kTypeNameCompareLimit = 255; // = selfhost's `strMax`

static std::string distinctTypeNote(const Type *a, const Type *b) {
  if (!a || !b || a == b)
    return "";
  std::string an = a->name();
  if (an.size() >= kTypeNameCompareLimit || an != b->name())
    return "";
  // Two anonymous denoters are the shape a reader can act on: the fix is one
  // named type used twice. Two type-*names* that print alike are distinct for
  // the very same reason — each type-definition contains its own new-type —
  // but naming them again is no advice, so that half is left off.
  if (a->alias.empty() && b->alias.empty())
    return "; the two are written alike, but 6.4.1 makes each type-denoter "
           "that is not a type name denote a type of its own, so declare one "
           "named type and give it to both";
  return "; the two are written alike, but each was defined separately and "
         "6.4.1 makes the definitions distinct types";
}

/// ISO 7185 §6.4.3.5 bars a file from having a file as a component, at any
/// depth: `file of file of char` and `file of record f: text end` are both out.
/// The reason is that a file has no value to copy — which is the same fact
/// that keeps it out of `isStructured()` — so a file inside one could not be
/// read, written, or positioned. Nothing else about a component is restricted.
static bool containsFile(Type *t) {
  if (!t)
    return false;
  if (t->isFile())
    return true;
  if (t->isArray())
    return containsFile(t->elem);
  if (t->isRecord()) {
    for (const Field &f : t->fields)
      if (containsFile(f.type))
        return true;
    // A variant's fields are components of the record just as the fixed part's
    // are; only one arm exists at a time, but any of them may be the one.
    std::vector<const std::vector<Variant> *> pending{&t->variants};
    while (!pending.empty()) {
      const std::vector<Variant> *arms = pending.back();
      pending.pop_back();
      for (const Variant &v : *arms) {
        for (const Field &f : v.fields)
          if (containsFile(f.type))
            return true;
        pending.push_back(&v.variants);
      }
    }
  }
  return false;
}

/// ISO/IEC 10206:1991 §6.4.3.4: "A variant-denoter shall not contain a
/// type-denoter denoting either a restricted-type or the bindability that is
/// bindable or denoting a structured-type having any component whose
/// type-denoter is not permissible as a type-denoter contained by a
/// variant-denoter." This answers the first limb and the third; the second is
/// asked of the denoter by `bindableOf` at the same call site, because
/// bindability belongs to the *type-denoter* and a resolved field keeps no
/// record of it.
///
/// Not an error and not a dynamic-violation — Annex D's D.3 for this clause is
/// the discriminant-selector rule — so clause 5.1 e) requires the report and
/// refuses the activation. ISO 7185 needs no mode test: `restricted` and
/// `bindable` are word-symbols of Extended Pascal alone, so neither spelling
/// reaches a variant-denoter under the other standard.
static bool containsRestricted(Type *t) {
  if (!t)
    return false;
  if (t->isRestricted())
    return true;
  if (t->isArray())
    return containsRestricted(t->elem);
  if (t->isRecord()) {
    for (const Field &f : t->fields)
      if (containsRestricted(f.type))
        return true;
    std::vector<const std::vector<Variant> *> pending{&t->variants};
    while (!pending.empty()) {
      const std::vector<Variant> *arms = pending.back();
      pending.pop_back();
      for (const Variant &v : *arms) {
        for (const Field &f : v.fields)
          if (containsRestricted(f.type))
            return true;
        pending.push_back(&v.variants);
      }
    }
  }
  return false;
}

/// `file of T`. The component may be any type that is not, and does not
/// contain, a file. A `text` is *not* what this produces even when T is char:
/// §6.4.3.5 makes `text` a required type of its own with a line structure, and
/// `file of char` a plain sequence of characters with none.
Type *Sema::resolveFile(TypeExpr &denoter) {
  Type *t = newType(TypeKind::File);
  Type *component = denoter.elem ? resolveType(*denoter.elem) : ty::Char();
  if (containsFile(component)) {
    diags_.error(denoter.line, denoter.col,
                 "the component type of a file must not be, or contain, a "
                 "file, found " + component->name());
    component = ty::Char();
  }
  // §6.2.3.8 b)'s offer reaches inside a file's denoter since ADR-0134, and a
  // subrange component is what it is for — its storage is its host's whatever
  // its bounds are. A component whose *size* the bound decides is a different
  // thing: the runtime is told one component size when the file is prepared,
  // and that number is written where the file is.
  else if (dynBoundsFor_ && !genericFor_ && !schemaBody_ &&
           component->dynamicExtent()) {
    diags_.error(denoter.line, denoter.col,
                 "the bounds of a file's component type must be constants, "
                 "because every component of a file is the same size");
    component = ty::Char();
  }
  t->elem = component;
  t->packed = denoter.packed;
  // §6.4.3.6: the index-type is what makes a file direct-access. It is an
  // ordinal type, because §6.7.6.6 makes `position` return a value of it and
  // §6.7.5.2 makes `SeekRead`'s argument assignment-compatible with it.
  if (denoter.index) {
    t->indexType = resolveType(*denoter.index);
    if (!t->indexType->isOrdinal()) {
      diags_.error(denoter.index->line, denoter.index->col,
                   "the index type of a direct-access file must be an "
                   "ordinal type, found " + t->indexType->name());
      t->indexType = ty::Int();
    }
  }
  return t;
}

/// ISO/IEC 10206:1991 §6.4.4 makes a domain-type a type-name *or* a
/// schema-name, and a bare schema-name leaves the tuple to `new` (§6.7.5.3).
/// The variable that creates has no activation record to keep a descriptor in,
/// so its tuple lives in a header immediately before it and its discriminants
/// are read from the object's own address — which is the whole of what
/// `heapDisc` marks (ADR-0043).
///
/// One type per schema, memoised: `^vector` written twice denotes one type, the
/// way `vector(3)` written twice does. That is also what stops the recursion,
/// since a schema may name itself in a pointer domain and nowhere else.
Type *Sema::heapFromSchema(Symbol *schema, TypeExpr &denoter) {
  auto found = heapSchemaTypes_.find(schema);
  if (found != heapSchemaTypes_.end())
    return found->second;

  Symbol *owner = newSymbol();
  owner->name = schema->name;
  owner->kind = SymKind::Var;
  Type *t = genericFromSchema(schema, owner, denoter, "pointer domain");
  if (t->isGeneric()) {
    owner->descSchema = schema;
    for (Symbol *d : owner->discSyms)
      d->heapDisc = true;
    t->heapTuple = true;
    t->descOwner = owner;
  }
  heapSchemaTypes_[schema] = t;
  // The body may have named this very schema in a pointer domain, and that
  // pointer could not be completed while the production was running. It can
  // be now, and it has to be here rather than at the end of the type part:
  // this production may have been asked for from the variable part, which is
  // past that point.
  std::vector<PendingPointer> rest;
  for (PendingPointer &p : pendingPointers_) {
    if (p.schema == schema)
      p.pointer->elem = t;
    else
      rest.push_back(p);
  }
  pendingPointers_ = rest;
  return t;
}

/// A pointer domain is resolved after the type part, so it may name a type —
/// or a schema — declared later than the pointer. That is the language's only
/// forward reference (ADR-0019), and a schema reaches it by the same route: a
/// name that is not a type when the pointer is written simply waits here.
void Sema::resolvePendingPointers() {
  // Not a range-for: resolving a schema domain resolves that schema's body,
  // which may itself contain a pointer and append to this vector.
  for (size_t i = 0; i < pendingPointers_.size(); ++i) {
    PendingPointer p = pendingPointers_[i];
    Symbol *sym = lookup(p.domain);
    if (sym && sym->kind == SymKind::Type) {
      p.pointer->elem = sym->type;
      continue;
    }
    if (sym && sym->kind == SymKind::Schema) {
      TypeExpr at;
      at.line = p.line;
      at.col = p.col;
      p.pointer->elem = heapFromSchema(sym, at);
      continue;
    }
    diags_.error(p.line, p.col,
                 "unknown type '" + p.domain + "' as the domain of a pointer");
    p.pointer->elem = ty::Int(); // keep the tree checkable
  }
  pendingPointers_.clear();
}

/// How a bound is written in a diagnostic. A dynamic one has no value to
/// print, so it prints the discriminant it names — which is what the source
/// wrote, and the only thing that distinguishes two dimensions of one
/// schematic array.
std::string Type::boundName(const Type *t, const Symbol *disc,
                            long long value) {
  return disc ? disc->name : ordinalName(t, value);
}

/// A bound of a schema body being resolved for a schematic formal parameter.
/// It is a constant, or one of the discriminants the descriptor holds. There
/// is deliberately no third form: ISO 7185 has no constant-expression — a
/// bound is a sign and a number or an identifier, everywhere in the language —
/// so `n - 1` is not something a bound may be here or anywhere else. When
/// §6.3's constant-expression lands it will land for every bound at once, and
/// the descriptor already holds what such an expression would be computed from.
/// A subrange-bound of a variable's own type-denoter that is not a constant
/// (ADR-0113). §6.2.3.8 b) evaluates it at the block's commencement, so the
/// value is not known here and the bound becomes a discriminant like any
/// other: a slot in this variable's descriptor, read wherever the bound is
/// wanted.
///
/// The difference from `genericFromSchema`'s discriminants is where they come
/// from. There a schema-definition wrote the formals and they are *bound by
/// name* so the body can find them; here there is no schema and no name — the
/// bound expression is the only thing that exists, so the symbol is made on
/// sight and carries that expression itself. Nothing ever looks one up, which
/// is why it is left unnamed.
Symbol *Sema::dynBoundDisc(Expr *e) {
  Symbol *disc = newSymbol();
  disc->kind = SymKind::Disc;
  // The host, so a bound written with a subrange type stores as the type its
  // values are of — the same reduction `base()` makes everywhere else.
  disc->type = e->type->base();
  disc->discBinding = true;
  // The descriptor lives in the variable's own frame slot, in front of the
  // address, and is reached exactly as the variable is — so a recursive
  // procedure reads the descriptor of the invocation it is running in
  // (ADR-0016, ADR-0041).
  disc->owner = dynBoundsFor_->owner;
  disc->level = dynBoundsFor_->level;
  disc->frameIndex = dynBoundsFor_->frameIndex;
  disc->discIndex = static_cast<int>(dynBoundsFor_->discSyms.size());
  disc->discExpr = e;
  dynBoundsFor_->discSyms.push_back(disc);
  return disc;
}

bool Sema::evalBound(Expr *e, Type *&type, long long &value, Symbol *&disc) {
  disc = nullptr;
  if (evalOrdinal(e, type, value))
    return true;
  // evalOrdinal has checked the expression already, so the name is resolved
  // whether or not it folded to a value.
  if (auto *v = as<VarRef>(e))
    if (v->sym && v->sym->kind == SymKind::Disc) {
      disc = v->sym;
      type = v->sym->type;
      value = 0;
      return true;
    }
  // A bound of a *variable's own* denoter that did not fold. §6.2.3.8 b) puts
  // it in the block's commencement, so it becomes a discriminant of that
  // variable and the descriptor holds what it evaluated to (ADR-0113). Any
  // ordinal expression will do, where a schema body's bound must *name* a
  // discriminant: there the tuple is the caller's and only a name can reach
  // it, here the expression is evaluated on the spot and nothing else needs to
  // know how it was written.
  if (dynBoundsFor_ && e->type && e->type->isOrdinal()) {
    disc = dynBoundDisc(e);
    type = disc->type;
    value = 0;
    return true;
  }
  return false;
}

Type *Sema::resolveSubrange(TypeExpr &denoter) {
  Type *loType = nullptr;
  Type *hiType = nullptr;
  long long lo = 0, hi = 0;
  Symbol *loDisc = nullptr, *hiDisc = nullptr;
  bool ok = true;

  // A schematic formal parameter's bounds arrive with the actual, so inside
  // one — and nowhere else — a bound may name a discriminant. Everything the
  // subrange means is otherwise unchanged, which is why this is one call
  // swapped for another rather than a second resolver.
  //
  // A variable's own denoter takes the same path (ADR-0113): there a bound that
  // is not a constant becomes a discriminant of the variable instead of naming
  // one, which is a difference `evalBound` absorbs. Everything after it — the
  // dynamic flag, the skipped emptiness check, loDisc and hiDisc on the type —
  // is the same for both, and that is the point of joining them here rather
  // than writing a third resolver.
  if (genericFor_ || dynBoundsFor_) {
    if (!evalBound(denoter.lo.get(), loType, lo, loDisc) ||
        !evalBound(denoter.hi.get(), hiType, hi, hiDisc)) {
      diags_.error(denoter.line, denoter.col,
                   genericFor_
                       ? "the bounds of a subrange in a schematic formal "
                         "parameter must be ordinal constants or discriminants"
                       : "the bounds of a subrange must be ordinal");
      ok = false;
    } else if (loType->base() != hiType->base()) {
      diags_.error(denoter.line, denoter.col,
                   "the bounds of a subrange must have the same type, found " +
                       loType->name() + " and " + hiType->name());
      ok = false;
    }
    bool dynamic = ok && (loDisc || hiDisc);
    // An empty subrange is still an error, but only where both ends are known.
    // Where one is not, the tuple that produced the *actual's* type was
    // checked when it was produced — so a dynamic range cannot be empty, and
    // there is nothing left for a run-time check to catch.
    if (ok && !dynamic && hi < lo) {
      diags_.error(denoter.line, denoter.col,
                   "a subrange cannot be empty: " +
                       Type::ordinalName(loType, hi) + " is below " +
                       Type::ordinalName(loType, lo));
      ok = false;
    }
    Type *t = newType(TypeKind::Subrange);
    t->host = ok ? loType->base() : ty::Int();
    t->lo = ok ? lo : 0;
    t->hi = ok ? hi : 0;
    if (ok) {
      t->loDisc = loDisc;
      t->hiDisc = hiDisc;
    }
    return t;
  }

  if (!evalOrdinal(denoter.lo.get(), loType, lo) ||
      !evalOrdinal(denoter.hi.get(), hiType, hi)) {
    // Silent when the folder was specific: an overflow in a bound is one
    // mistake and deserves one message, not that one and "not a constant".
    if (!constReported_)
      diags_.error(denoter.line, denoter.col,
                   "the bounds of a subrange must be ordinal constants");
    ok = false;
  } else if (loType->base() != hiType->base()) {
    diags_.error(denoter.line, denoter.col,
                 "the bounds of a subrange must have the same type, found " +
                     loType->name() + " and " + hiType->name());
    ok = false;
  } else if (hi < lo) {
    diags_.error(denoter.line, denoter.col,
                 "a subrange cannot be empty: " + Type::ordinalName(loType, hi) +
                     " is below " + Type::ordinalName(loType, lo));
    ok = false;
  }

  Type *t = newType(TypeKind::Subrange);
  t->host = ok ? loType->base() : ty::Int();
  t->lo = ok ? lo : 0;
  t->hi = ok ? hi : 0;
  return t;
}

/// `array [a, b] of T` abbreviates `array [a] of array [b] of T`
/// (ISO 7185 §6.4.3.2), so dimension `dim` wraps everything after it.
Type *Sema::resolveArray(TypeExpr &denoter, size_t dim) {
  TypeExpr &indexDenoter = *denoter.dims[dim];
  Type *index = resolveType(indexDenoter);

  if (!index->isOrdinal()) {
    diags_.error(indexDenoter.line, indexDenoter.col,
                 "an array index must be an ordinal type, found " +
                     index->name());
    index = newType(TypeKind::Subrange);
    index->host = ty::Int();
  }
  // A subscript is lowered to `i - lo` in the integer type, which is sound
  // only while that difference is a value of the type. Rejecting the array is
  // what makes the rule `accepted-index-selects-the-right-element` true, so
  // this bound is load-bearing rather than arbitrary — see verify/rules.py.
  // A dynamic index type has no span to measure here. It does not need one:
  // the array the actual brings was produced from constants and checked when
  // it was produced, so the difference `i - lo` is a value of the type for
  // every array that can reach a schematic formal parameter.
  else if (!index->dynamicBounds() &&
           index->ordinalHi() - index->ordinalLo() >= kMaxInt) {
    diags_.error(indexDenoter.line, indexDenoter.col,
                 "this array has too many elements: an index type may span "
                 "at most maxint values");
    index = newType(TypeKind::Subrange);
    index->host = ty::Int();
  }

  Type *t = newType(TypeKind::Array);
  t->indexType = index;
  t->lo = index->ordinalLo();
  t->hi = index->ordinalHi();
  // An array is bounded by its index type, dynamically or not, so a dynamic
  // bound travels one step outwards here and codegen never looks at the index
  // type again.
  t->loDisc = index->loDisc;
  t->hiDisc = index->hiDisc;
  t->packed = denoter.packed;
  // An inner dimension is an array, and §6.4.3.5 makes an array's own
  // bindability the one its type-denoter denotes — which for a dimension the
  // grammar folded out of `array [a, b] of T` is no denoter at all. Only the
  // component carries one.
  if (dim + 1 < denoter.dims.size()) {
    t->elem = resolveArray(denoter, dim + 1);
  } else {
    t->elem = resolveType(*denoter.elem);
    t->elemBindable = bindableOf(*denoter.elem);
  }
  return t;
}

/// One entry of a case-constant-list, folded to the closed interval it denotes.
/// A single constant is [v, v], so a case statement and a variant part read
/// their labels the same way whether or not Extended Pascal ranges are in play;
/// `constantMsg` is the one diagnostic the two constructs spell differently.
///
/// A range is never expanded into its members — `1..maxint` is four bytes here
/// and two billion switch cases if expanded, and codegen tests it rather than
/// enumerating it for exactly that reason.
bool Sema::evalLabelRange(CaseLabel &label, const char *constantMsg,
                          Type *&type, LabelRange &r) {
  type = nullptr;
  if (!evalOrdinal(label.lo.get(), type, r.lo)) {
    if (!constReported_)
      diags_.error(label.lo->line, label.lo->col, constantMsg);
    return false;
  }
  r.hi = r.lo;
  if (!label.hi)
    return true;

  Type *hiType = nullptr;
  if (!evalOrdinal(label.hi.get(), hiType, r.hi)) {
    if (!constReported_)
      diags_.error(label.hi->line, label.hi->col, constantMsg);
    return false;
  }
  if (type && hiType && type->base() != hiType->base()) {
    diags_.error(label.hi->line, label.hi->col,
                 "the two ends of a range must be of one type, found " +
                     type->name() + " and " + hiType->name());
    return false;
  }
  // A backwards range denotes no values at all. ISO 7185 §6.7.1 says so for a
  // set constructor and this compiler honours it there, but a label selecting
  // nothing can only be a mistake — nothing would ever run.
  if (r.hi < r.lo) {
    diags_.error(label.lo->line, label.lo->col,
                 "this range runs backwards: " + Type::ordinalName(type, r.lo) +
                     " is greater than " + Type::ordinalName(type, r.hi));
    return false;
  }
  return true;
}

/// The lowest value two label lists share, if they share one. "This label
/// appears twice" is the single-constant case of exactly this question, so
/// both constructs ask it in the general form.
bool Sema::overlaps(const std::vector<LabelRange> &seen, LabelRange r,
                    long long &at) {
  for (const LabelRange &s : seen)
    if (s.lo <= r.hi && r.lo <= s.hi) {
      at = s.lo > r.lo ? s.lo : r.lo;
      return true;
    }
  return false;
}

/// ISO 7185 §6.4.3.3 requires every field name in a record to be distinct,
/// across the fixed part and every variant alike — which is what lets one flat
/// lookup answer where a name lives.
void Sema::addField(Type *record, std::vector<Field> &into,
                    const DeclName &name, Type *type,
                    const std::vector<int> &variant, Expr *init,
                    bool bindable) {
  // §6.2.3.8 b) reaches a bound written inside a record's denoter — a record
  // is not a block, so such a bound is still closest-contained by the one the
  // declaration is in — and ADR-0134 admits it. What it must not admit is a
  // field whose *size* the bound decides: a field's storage is laid out where
  // the record is, and a field after a dynamically sized one sits at an offset
  // nothing can compute (ADR-0045). A subrange is the case that works, for the
  // reason ADR-0133 gives: its storage is its host's whatever its bounds are.
  //
  // The field is still added afterwards, so a later `u.f` is a field selection
  // and not a second complaint about a name that went missing.
  if (dynBoundsFor_ && !genericFor_ && !schemaBody_ && type &&
      type->dynamicExtent())
    diags_.error(name.line, name.col,
                 "the bounds of the field '" + name.name +
                     "' must be constants, because a field's storage is sized "
                     "where the record is");
  if (record->findField(name.name)) {
    diags_.error(name.line, name.col,
                 "'" + name.name + "' is already a field of this record");
    return;
  }
  Field f;
  f.name = name.name;
  f.type = type;
  f.index = static_cast<int>(into.size());
  f.variant = variant;
  f.line = name.line;
  f.col = name.col;
  f.initValue = init;
  f.isBindable = bindable;
  into.push_back(std::move(f));
}

/// ISO/IEC 10206:1991 §6.4.3.4: the discriminant-identifier a variant-selector
/// names, or null when the selector is a tag-type. A discriminant is only ever
/// in scope while a schema body is being resolved, so this answers null
/// everywhere else without needing to ask where it is — which is what keeps
/// the form out of an ordinary record with no rule saying so.
Symbol *Sema::discSelectorFor(TypeExpr *denoter) {
  if (denoter->kind != TEK::Named)
    return nullptr;
  Symbol *s = lookup(denoter->name);
  return s && s->discBinding ? s : nullptr;
}

Type *Sema::resolveRecord(TypeExpr &denoter) {
  Type *t = newType(TypeKind::Record);
  t->packed = denoter.packed;
  // The region §6.4.3.3 gives this record's field-identifiers is open from
  // here until the last variant arm is resolved, so a domain-type written
  // anywhere inside it can see them (ADR-0098).
  openRecords_.push_back(&denoter);
  for (FieldGroup &group : denoter.fields) {
    // §6.6: a field's own type-denoter may carry an initial-state-specifier,
    // and then the record's initial state has that field bearing that value.
    // The offer is made here and nowhere else inside a type-denoter.
    Type *fieldType = resolveType(*group.type);
    Expr *init = initialStateOf(*group.type);
    for (DeclName &n : group.names)
      addField(t, t->fields, n, fieldType, {}, init, bindableOf(*group.type));
  }
  if (denoter.tagType) {
    std::vector<int> path;
    resolveVariantPart(denoter.tagName, denoter.tagType.get(),
                       denoter.variants, denoter.tagLine,
                       denoter.tagCol, t, t->fields, t->variants,
                       t->tagField, t->tagType, t->discSelector, path);
  }
  openRecords_.pop_back();
  return t;
}

void Sema::resolveVariantPart(const std::string &tagName, TypeExpr *tagDenoter,
                              std::vector<VariantArm> &arms, int tagLine,
                              int tagCol, Type *record,
                              std::vector<Field> &fields,
                              std::vector<Variant> &variants, int &tagField,
                              Type *&tagTypeOut, bool &discSelOut,
                              std::vector<int> &path) {
  // ISO/IEC 10206:1991 §6.4.3.4's third form of variant-selector: a bare name
  // that is one of the discriminants the body is being resolved with. It is
  // asked *before* the denoter is resolved, because as a type-denoter the name
  // is unknown and would report so. The two forms are told apart by the symbol
  // and not by the syntax — `case k of` is a tag-type when `k` names a type
  // and a discriminant-identifier when it names a discriminant, and no third
  // reading of it exists.
  Symbol *selector = discSelectorFor(tagDenoter);
  Type *tag = selector ? selector->type : resolveType(*tagDenoter);
  if (selector) {
    discSelOut = true;
    // The dump prints the denoter's resolved type, and this one *is* resolved
    // — to the discriminant's type — even though resolveType never saw it.
    tagDenoter->resolved = tag;
  }
  if (!tag->isOrdinal()) {
    diags_.error(tagLine, tagCol,
                 "the tag of a variant part must be an ordinal type, found " +
                     tag->name());
    return;
  }
  tagTypeOut = tag;

  // §6.4.3.4 offers the tag-field to the tag-type form only: the selector of a
  // discriminant-selected variant part *is* the discriminant, and a field
  // would be a second place to keep it — one the program could then assign,
  // which is the very thing the section calls a dynamic-violation.
  if (selector && !tagName.empty()) {
    diags_.error(tagLine, tagCol,
                 "'" + selector->name +
                     "' is a discriminant, so it is the tag of this variant "
                     "part and cannot also name a field");
    return;
  }

  // A named tag is an ordinary field of the field-list it heads; a tagless
  // variant part has the type but no storage for it (ISO 7185 §6.4.3.3).
  if (!tagName.empty()) {
    tagField = static_cast<int>(fields.size());
    addField(record, fields, {tagName, tagLine, tagCol}, tag, path);
  }

  std::vector<LabelRange> claimed; // the tag values earlier arms have taken
  // A label that failed to evaluate, or that named a value the tag-type does
  // not have, leaves `claimed` incomplete — so the coverage question below
  // would report values that *are* named, in a program already reported on.
  bool labelsOk = true;
  bool hasOther = false;
  for (VariantArm &arm : arms) {
    Variant v;
    v.line = arm.line;
    v.col = arm.col;
    // An otherwise-arm carries no labels, so nothing below runs for it. It is
    // still an arm in every other respect — one struct laid over the shared
    // block, numbered like the rest — which is why the layout is unchanged.
    v.isOtherwise = arm.isOtherwise;
    hasOther = hasOther || arm.isOtherwise;
    int index = static_cast<int>(variants.size());

    for (CaseLabel &label : arm.labels) {
      Type *labelType = nullptr;
      LabelRange r;
      if (!evalLabelRange(label, "a variant's label must be an ordinal constant",
                          labelType, r)) {
        labelsOk = false;
        continue;
      }
      if (labelType->base() != tag->base()) {
        diags_.error(label.lo->line, label.lo->col,
                     "this variant's tag is " + tag->name() +
                         ", but the label is " + labelType->name());
        labelsOk = false;
        continue;
      }
      // ISO 7185 §6.4.3.3 requires the case-constants to be *equal to* the
      // set of values of the tag-type, and ISO/IEC 10206:1991 §6.4.3.4 states
      // this half on its own: "the value denoted by each such case-constant
      // shall be a member of the set of values determined by that type". A
      // variant-part-completer does not excuse it — an otherwise-arm claims
      // the values nothing names, not values the tag-type does not have.
      if (r.lo < tag->ordinalLo() || r.hi > tag->ordinalHi()) {
        diags_.error(label.lo->line, label.lo->col,
                     "the tag value " +
                         Type::ordinalName(tag->base(), r.lo < tag->ordinalLo()
                                                            ? r.lo
                                                            : r.hi) +
                         " is not a value of " + tag->name());
        labelsOk = false;
        continue;
      }
      long long at = 0;
      if (overlaps(claimed, r, at)) {
        diags_.error(label.lo->line, label.lo->col,
                     "the tag value " + Type::ordinalName(tag, at) +
                         " already selects an earlier variant");
        // A rejected range is not recorded, so its non-overlapping tail would
        // read as a gap below and earn a second complaint about a fault
        // already reported.
        labelsOk = false;
        continue;
      }
      claimed.push_back(r);
      v.labels.push_back(r);
    }

    // The fields are pushed into the arm, so each variant is numbered from
    // zero and codegen can index it as a struct of its own.
    variants.push_back(std::move(v));
    path.push_back(index);
    for (FieldGroup &group : arm.fields) {
      // A field-list is a field-list (§6.4.3.3), so an arm's fields may carry
      // an initial-state-specifier syntactically — and are told why they may
      // not have one here rather than being told it is the wrong position.
      variantField_ = true;
      Type *fieldType = resolveType(*group.type);
      variantField_ = false;
      // The arms share one block of storage, and a file's storage is not just
      // bytes: `pas_file_init` gives it a heap buffer sized by the component
      // type, and the block's prologue has to do that for every file the
      // variable contains before the program can name one. Two arms holding
      // files would need two buffers at one address — the second init leaks
      // the first, and the file that is read is not the file that was set up.
      // ISO 7185 §6.4.3.3 and ISO/IEC 10206:1991 §6.4.3.4 — one clause under
      // two numbers — do not forbid this; this compiler does, because there is
      // no answer to "which arm's file is this storage" at block entry
      // (ADR-0070).
      // Where a complaint about this group is attributed: its first name, or
      // the arm itself where the parser recovered without one. Three rules
      // below ask the same question.
      int fieldLine = group.names.empty() ? arm.line : group.names[0].line;
      int fieldCol = group.names.empty() ? arm.col : group.names[0].col;
      if (fieldType->isFile() || containsFile(fieldType))
        diags_.error(fieldLine, fieldCol,
                     "a file cannot be a field of a variant part, because the "
                     "arms share storage and a file's storage is its own");
      // §6.4.3.4's own sentence about a variant-denoter, which is a
      // conformance rule and not this compiler's deviation above. Two
      // spellings and two questions: `containsRestricted` reaches through a
      // container as the clause's third limb requires, while bindability has
      // to be asked of the *denoter* — §6.4.1 makes a type-name hand on the
      // bindability of its definition, so `bindable` need not appear in the
      // arm for the arm to denote it.
      if (containsRestricted(fieldType))
        diags_.error(fieldLine, fieldCol,
                     "a restricted type cannot be a field of a variant part");
      if (bindableOf(*group.type))
        diags_.error(fieldLine, fieldCol,
                     "a bindable type cannot be a field of a variant part");
      for (DeclName &n : group.names)
        addField(record, variants[index].fields, n, fieldType, path);
    }
    // An arm's field-list may end with a variant part of its own, and this is
    // the only recursion in a type-denoter that does not go back through
    // resolveType.
    if (arm.tagType)
      resolveVariantPart(arm.tagName, arm.tagType.get(), arm.variants,
                         arm.tagLine, arm.tagCol, record,
                         variants[index].fields, variants[index].variants,
                         variants[index].tagField, variants[index].tagType,
                         variants[index].discSelector, path);
    path.pop_back();
  }

  // ISO 7185 §6.4.3.3: "the case-constants ... shall denote a set of values
  // equal to the set of values specified by the tag-type" — so every value of
  // the tag-type must be named by some arm, and `case tag: integer of 1: …`
  // is refused because `integer` has other values. That looks over-strict and
  // is not: BSI's own DEV073 header records that test as reclassified *from
  // CONFORMANCE to DEVIANCE by DP7185*. The conforming spellings are a
  // covering tag-type (`type sel = 1..2`) or Extended Pascal's `otherwise`,
  // which discharges coverage and never membership (ADR-0096).
  if (labelsOk && !hasOther) {
    long long need = tag->ordinalLo();
    for (;;) {
      const LabelRange *found = nullptr;
      for (const Variant &w : variants)
        for (const LabelRange &rg : w.labels)
          if (rg.lo <= need && need <= rg.hi)
            found = &rg;
      if (!found) {
        diags_.error(tagLine, tagCol,
                     "the tag value " + Type::ordinalName(tag->base(), need) +
                         " selects no variant of " + tag->name());
        break;
      }
      if (found->hi >= tag->ordinalHi())
        break;
      need = found->hi + 1;
    }
  }
}

/// ISO/IEC 10206:1991 §6.4.9: "The type denoted by a type-inquiry shall be the
/// type possessed by the variable-identifier or parameter-identifier contained
/// by the type-inquiry."
///
/// It is the only type-denoter that names a *variable*, so its name is looked
/// up in the ordinary scope rather than among the types — and the whole
/// feature is that one sentence. A type-inquiry yields a `Type *` that some
/// other declaration already owns, so nothing downstream can tell that the
/// type arrived this way, which is exactly what §6.4.9 asks for: `var b: type
/// of a` makes `b` the *same* type as `a` under §6.4.5's name equivalence,
/// not a second type that looks like it.
/// ISO/IEC 10206:1991 §6.4.2.5: `restricted type-name`. The result is a new
/// type of its own kind whose `elem` is the underlying-type — a *new* type, so
/// ADR-0017's name equivalence already makes it distinct from the type it
/// restricts, and no rule about identity had to be touched.
///
/// A restricted-type is what the standard's own example uses to hide a
/// record's structure across a module interface (§6.11): export the restricted
/// name and not the underlying one, and a user of the interface can pass values
/// around and do nothing else with them.
Type *Sema::resolveRestricted(TypeExpr &denoter) {
  // A required type-identifier is an ordinary symbol in the outermost scope
  // (ADR-0097), so one lookup answers for it as for any other name. Returning
  // the placeholder off a path that is *not* an error matters here: the caller
  // writes the new name's alias onto whatever comes back, so `restricted
  // integer` would rename the shared `integer` singleton and every later
  // `integer` would print as the restricted name.
  Type *named = nullptr;
  {
    Symbol *sym =
        lookupName(denoter.qualifier, denoter.name, denoter.line, denoter.col);
    if (sym && (sym->kind != SymKind::Type || !sym->type)) {
      diags_.error(denoter.line, denoter.col,
                   "'restricted' must name a type, and '" + denoter.name +
                       "' is not one");
      return ty::Int();
    }
    if (!sym)
      return ty::Int();
    named = sym->type;
  }
  // §6.4.2.5 gives every type an underlying-type — its own, when it is not
  // restricted — so restricting a restricted type would make a second wrapper
  // over one underlying-type with nothing to tell the two apart. Refused
  // rather than silently flattened, because a program that writes it means
  // something by it.
  if (named->isRestricted()) {
    diags_.error(denoter.line, denoter.col,
                 "'" + denoter.name + "' is already a restricted type");
    return named;
  }
  // §6.4.2.5: "The bindability denoted by a restricted-type shall be
  // nonbindable." A file has no operation left that §6.4.2.5's NOTE permits —
  // it is never assigned, never a value parameter and never a result — so a
  // restricted file would be a variable nothing could do anything with.
  if (named->isFile()) {
    diags_.error(denoter.line, denoter.col,
                 "a file cannot be restricted; there is no operation on one "
                 "that a restricted type would still allow");
    return ty::Int();
  }
  // §6.4.2.5: "The bindability denoted by a restricted-type shall be
  // nonbindable." `bindable` precedes the denoter (ADR-0052) so the two can be
  // written together, and this is the one place that can say they may not be.
  if (denoter.bindable)
    diags_.error(denoter.line, denoter.col,
                 "a restricted type is nonbindable, so 'bindable' cannot "
                 "precede 'restricted'");
  Type *t = newType(TypeKind::Restricted);
  t->elem = named;
  return t;
}

/// Whether this symbol is one of that procedure's formal parameters, rather
/// than something else its frame owns. A function's result variable is a
/// VarParam of the function when the result lives in memory (§6.7.2), and it
/// is not a parameter-identifier — so the parameter list is walked rather than
/// the kind being trusted.
static bool parameterOf(Symbol *owner, Symbol *s) {
  for (Symbol *p : owner->params)
    if (p == s)
      return true;
  return false;
}

Type *Sema::resolveInquiry(TypeExpr &denoter) {
  // §6.4.9 also allows the object to be a parameter of the closest-containing
  // formal-parameter-list, and that needs nothing added: `declareProcHeading`
  // pushes a scope before building the formals, so a parameter declared
  // earlier in the same list is already an ordinary lookup by the time a later
  // one's type-denoter asks.
  // §6.4.9's type-inquiry-object is a `variable-name` or a
  // `parameter-identifier`, and a variable-name carries the qualifier too.
  Symbol *sym = lookupQuiet(denoter.qualifier, denoter.name);
  // §6.4.9: "A parameter-identifier in a type-inquiry-object shall have its
  // defining-point in a value-parameter-specification or
  // variable-parameter-specification in the formal-parameter-list
  // closest-containing the type-inquiry-object."
  //
  // What makes that a rule about *where the inquiry is written* rather than a
  // ban on naming an outer parameter is §6.7.3.1: an identifier in a value- or
  // variable-parameter-specification gets **two** defining-points, one as a
  // parameter-identifier for the formal-parameter-list and one as the
  // associated variable-identifier for the block. So inside a
  // formal-parameter-list the name is a parameter-identifier and this applies;
  // inside the block it is a variable-identifier and §6.4.9's other
  // alternative, `variable-name`, is what it matches — which is why the
  // clause's own example, `procedure p(var a: VVector); var b: type of a;`, is
  // legal (ADR-0134).
  if (sym && formalsFor_ && !schemaBody_ &&
      (sym->kind == SymKind::Param || sym->kind == SymKind::VarParam) &&
      sym->owner && sym->owner != formalsFor_ && parameterOf(sym->owner, sym)) {
    diags_.error(denoter.line, denoter.col,
                 "'" + denoter.name +
                     "' is a parameter of another formal-parameter-list, so "
                     "'type of' cannot name it here");
    return ty::Int();
  }
  if (!sym) {
    diags_.error(denoter.line, denoter.col,
                 "unknown variable '" + denoter.name + "' in 'type of'");
    return ty::Int();
  }
  if (!sym->isVariable()) {
    diags_.error(denoter.line, denoter.col,
                 "'type of' names a variable or a parameter, and '" +
                     denoter.name + "' is not one");
    return ty::Int();
  }
  if (!sym->type)
    return ty::Int();
  // A schematic formal's type has no tuple: its bounds are in a descriptor
  // belonging to *that* parameter, and a second name reading them would need
  // to share the descriptor rather than the type. §6.7.3.3 says what that
  // means and this compiler does not do it yet — so it is refused rather than
  // silently given a type whose bounds it cannot read.
  if (sym->type->isGeneric()) {
    diags_.error(denoter.line, denoter.col,
                 "'type of " + denoter.name +
                     "' would need the discriminants that arrive with '" +
                     denoter.name + "', which is not supported");
    return ty::Int();
  }
  return sym->type;
}

/// ISO/IEC 10206:1991 §6.6: "The initial state specified by an
/// initial-state-specifier shall be the state bearing the value denoted by the
/// component-value", and "An expression contained by the component-value of an
/// initial-state-specifier shall be nonvarying."
///
/// Nonvarying is what makes the whole feature cheap: the value is a constant,
/// so the prologue stores it and nothing is evaluated at entry that could
/// depend on the order the entry happens in.
/// ISO/IEC 10206:1991 §6.8.2: an expression is *nonvarying* when its value
/// cannot change — literals, constants, and operations on those. That is not
/// the same as "the compiler can fold it": §6.6's own examples include
/// `ord(red)` and `polar(exp(1.0), pi)`, neither of which this compiler folds,
/// and both of which are perfectly good things for a block prologue to
/// compute. So the test is over what the expression *reads*, and what survives
/// it is emitted as an ordinary expression at block entry.
///
/// A required function is nonvarying with nonvarying arguments; a
/// user-declared one is not, because §6.8.2 does not make it so and its body
/// may read anything at all.
bool Sema::nonvarying(Expr *e) const {
  if (!e)
    return false;
  if (is<IntLit>(e) || is<RealLit>(e) || is<CharLit>(e) || is<StrLit>(e) ||
      is<NilLit>(e))
    return true;
  if (auto *v = as<VarRef>(e))
    return v->sym && v->sym->kind == SymKind::Const;
  if (auto *u = as<Unary>(e))
    return nonvarying(u->operand.get());
  if (auto *b = as<Binary>(e))
    return nonvarying(b->lhs.get()) && nonvarying(b->rhs.get());
  if (auto *st = as<SetExpr>(e)) {
    for (const SetMember &m : st->members)
      if (!nonvarying(m.lo.get()) || (m.hi && !nonvarying(m.hi.get())))
        return false;
    return true;
  }
  // §6.8.7.4's set-value is that same constructor reached through a type name,
  // so it answers the same way (ADR-0066). Asked of the spine the parser built
  // and not of the members directly, because the spine is what the tree holds;
  // a spine that is *not* a set-value has no answer here and falls through to
  // `false`, which is what a subscripted variable should say.
  if (auto *i = as<IndexExpr>(e))
    return i->setValue && nonvarying(i->setValue.get());
  if (auto *sub = as<SubstringExpr>(e))
    return sub->setValue && nonvarying(sub->setValue.get());
  // §6.8.7's structured-value-constructor is nonvarying when everything it is
  // built out of is — which is what makes §6.6 NOTE 3's
  // `array [1..8] of char value [1..8: '*']` an initial state rather than an
  // error. A field-value's selectors are field *names* and never expressions,
  // so only the labels of an array-value and the component-values are asked.
  if (auto *sv = as<StructValueExpr>(e)) {
    for (const ValueElem &el : sv->elems) {
      if (!el.fieldIndex.empty()) {
        if (!nonvarying(el.value.get()))
          return false;
        continue;
      }
      for (const CaseLabel &lab : el.labels)
        if (!nonvarying(lab.lo.get()) || (lab.hi && !nonvarying(lab.hi.get())))
          return false;
      if (!nonvarying(el.value.get()))
        return false;
    }
    return (!sv->tagValue || nonvarying(sv->tagValue.get())) &&
           (!sv->variant || nonvarying(sv->variant.get()));
  }
  if (auto *c = as<Call>(e)) {
    // `eof` and `eoln` read a file, which is what varying means.
    if (c->builtin == Builtin::None || c->builtin == Builtin::Eof ||
        c->builtin == Builtin::Eoln)
      return false;
    for (const ExprPtr &a : c->args)
      if (!nonvarying(a.get()))
        return false;
    return true;
  }
  return false;
}

/// There is deliberately no check here that the *position* admits a specifier.
/// The parser is the whole of that rule: only the three positions that may
/// carry one call `parseTypeExpr`, and every nested denoter stops before the
/// word — so a denoter reaching here with a value is by construction in a
/// position that allows it. A version of this function carrying a
/// "not here" message was written, and deleted when nothing could reach it.
void Sema::checkInitialState(TypeExpr &denoter, Type *t) {
  Expr *v = denoter.initValue.get();
  if (!v)
    return;
  // §6.4.7 makes a schema body a type-denoter, so the word parses there —
  // and it is spelled as a type definition, which is why this needs a reason
  // of its own rather than the position message below.
  if (schemaBody_) {
    diags_.error(v->line, v->col,
                 "a schema's body cannot carry an initial-state specifier: "
                 "every discriminant tuple produces its own type, and the "
                 "value would have to be attributed once for each");
    return;
  }
  // §6.5.1 makes the initial state of a *variant* conditional on the selector's
  // own initial state selecting it. Nothing here tracks that, so a field of a
  // variant part is refused rather than initialised into a variant that may
  // not be the live one.
  if (variantField_) {
    diags_.error(v->line, v->col,
                 "a field of a variant part cannot have an initial value, "
                 "because which variant exists is not settled here");
    return;
  }
  // §6.6 NOTE 4 makes this a *component-value*, so an array-value or a
  // record-value written here takes its type from the denoter it hangs off
  // rather than from a type-name it does not have (ADR-0061).
  if (auto *sv = as<StructValueExpr>(v))
    checkStructValue(sv, t);
  else
    checkExpr(v);
  if (!nonvarying(v)) {
    diags_.error(v->line, v->col,
                 "the value of an initial-state specifier must not depend on "
                 "a variable");
    return;
  }
  // §6.4.3.6 gives a file the initial state totally-undefined, and a file has
  // no value to bear in any case. Asked before compatibility, or the message
  // would be about the type of the value rather than about the file.
  if (t && t->isFile()) {
    diags_.error(v->line, v->col, "a file variable has no initial value");
    return;
  }
  if (!assignable(t, v->type)) {
    diags_.error(v->line, v->col,
                 "cannot give " + (t ? t->name() : std::string("this")) +
                     " an initial value of type " +
                     (v->type ? v->type->name() : std::string("nothing")));
    return;
  }
  denoter.initOk = true;
}

Type *Sema::resolveType(TypeExpr &denoter) {
  if (denoter.resolved)
    return denoter.resolved;

  // §6.2.3.2 allows a discriminant that is not a constant in a variable's own
  // type-denoter, and there only. A denoter of any other kind is on the way to
  // somewhere else — a component, a field, a domain — so the offer is
  // withdrawn before it recurses, and `array [1..3] of vector(n)` is refused
  // exactly as it was.
  Symbol *savedDynamic = dynamicVarFor_;
  if (denoter.kind != TEK::Schema)
    dynamicVarFor_ = nullptr;
  // The same withdrawal for a non-constant *bound* (ADR-0113), and it reaches
  // one denoter further: an array's index-type is a subrange and its
  // component-type may be another array, so `array [1..m] of array [1..k] of
  // real` is one variable with two discriminants. Everything else — a record
  // field, a file component, a set base, a pointer domain — is on the way to a
  // type of its own, whose storage is not this variable's to size, so the offer
  // stops there and the bound must be constant exactly as before.
  Symbol *savedBounds = dynBoundsFor_;
  // A subrange joins it (ADR-0133), and the two together are the whole of what
  // §6.2.3.8 b) reaches: a bound written in a variable-declaration or a
  // type-definition of this block, at any depth of arrays and subranges. A
  // subrange needs no clause of its own about *sizing* — its storage is its
  // host's whatever its bounds are — so what admits it is that the range check
  // at a store can read the descriptor, which is the half ADR-0127 left. Every
  // other kind still withdraws the offer at the container, so `set of 1..m`,
  // `record f: 1..m end`, a file component and a pointer domain each need a
  // constant bound exactly as before.
  //
  // A record and a file join them (ADR-0134), because a record is not a block
  // and a bound written inside one is still closest-contained by the block the
  // declaration is in. What the offer must not reach through them is a field
  // or a component whose *size* the bound decides, and `addField` and
  // `resolveFile` are where that is refused — by asking dynamicExtent(), which
  // a subrange answers no to and an array yes.
  if (denoter.kind != TEK::Array && denoter.kind != TEK::Subrange &&
      denoter.kind != TEK::Record && denoter.kind != TEK::File)
    dynBoundsFor_ = nullptr;

  Type *t = nullptr;
  switch (denoter.kind) {
  case TEK::ConfArray:
    // ISO 7185 §6.6.3.7's schema is a type-denoter the parser produces in one
    // position only — a formal parameter's — and `buildFormals` takes that case
    // before `resolveType` is called, exactly as it does for a bare
    // schema-name one clause earlier (ADR-0153). Its own children are resolved
    // by `confArrayType`, which tests the kind first. So nothing reaches here
    // with one, and the case exists to say so rather than to do anything: the
    // Pascal compiler's counterpart is an arm its `kind-exhaustive` catalogue
    // argues away, and a `switch` cannot argue.
    t = ty::Int();
    break;
  case TEK::Named:
    // A required type-identifier is a symbol in the outermost scope, so this
    // is one lookup and not two (ADR-0097) — and a qualified name reaches only
    // what an import brought, which that scope is not: `i.integer` is still
    // not `integer`, now because the qualifier is honoured rather than because
    // a spelling test was skipped.
    //
    // §6.4.3.3's region is asked first and outranks every one of those: inside
    // a record, a spelling that is one of its fields denotes the field and so
    // names nothing here — including where the spelling is a required
    // type-identifier, since a field's defining-point is nearer than the region
    // enclosing the program (ADR-0112).
    if (fieldOfOpenRecord(denoter.qualifier, denoter.name)) {
      errorFieldNotAType(denoter.line, denoter.col, denoter.name);
      t = ty::Int();
      break;
    }
    {
      Symbol *sym = lookupName(denoter.qualifier, denoter.name, denoter.line,
                               denoter.col);
      if (!sym && !denoter.qualifier.empty()) {
        t = ty::Int();
      } else if (sym && sym->kind == SymKind::Type) {
        t = sym->type;
      } else if (sym && sym->kind == SymKind::Schema) {
        // §6.4.8: a schema denotes a type only once its discriminants are
        // given. The bare name is legal in a parameter-form and nowhere else,
        // and a parameter-form never reaches here — `buildFormals` takes that
        // case before `resolveType` is called (ADR-0040). So a bare schema
        // name arriving here is in a position the standard does not allow, and
        // the message says what is missing rather than that the name is
        // unknown.
        diags_.error(denoter.line, denoter.col,
                     "schema '" + denoter.name +
                         "' needs its discriminants here, as " + denoter.name +
                         "(...)");
        t = ty::Int();
      } else {
        diags_.error(denoter.line, denoter.col,
                     "unknown type '" + denoter.name + "'");
        t = ty::Int();
      }
    }
    break;
  case TEK::Enum:
    t = resolveEnum(denoter);
    break;
  case TEK::Subrange:
    t = resolveSubrange(denoter);
    break;
  case TEK::Array:
    t = resolveArray(denoter, 0);
    break;
  case TEK::Record:
    t = resolveRecord(denoter);
    break;
  case TEK::Pointer:
    t = resolvePointer(denoter);
    break;
  case TEK::File:
    t = resolveFile(denoter);
    break;
  case TEK::Set:
    t = resolveSet(denoter);
    break;
  case TEK::Inquiry:
    t = resolveInquiry(denoter);
    break;
  case TEK::Restricted:
    t = resolveRestricted(denoter);
    break;
  case TEK::Schema: {
    // The region rule again, and for the same reason: §6.4.3.3 does not care
    // which production the occurrence sits in, only that it is inside the
    // record (ADR-0112). The discriminants are still checked, so a mistake in
    // one of them is reported in the same run.
    if (fieldOfOpenRecord(denoter.qualifier, denoter.name)) {
      errorFieldNotAType(denoter.line, denoter.col, denoter.name);
      for (auto &a : denoter.args)
        checkExpr(a.get());
      t = ty::Int();
      break;
    }
    Symbol *sym =
        lookupName(denoter.qualifier, denoter.name, denoter.line, denoter.col);
    if (!denoter.qualifier.empty() && !sym) {
      for (auto &a : denoter.args)
        checkExpr(a.get());
      t = ty::Int();
    } else if (!sym || sym->kind != SymKind::Schema) {
      diags_.error(denoter.line, denoter.col,
                   "unknown schema '" + denoter.name + "'");
      // The discriminants are still checked, so a mistake in one of them is
      // reported in the same run as the name that could not be found.
      for (auto &a : denoter.args)
        checkExpr(a.get());
      t = ty::Int();
    } else {
      t = produceFromSchema(sym, denoter);
    }
    break;
  }
  }

  dynamicVarFor_ = savedDynamic;
  dynBoundsFor_ = savedBounds;
  checkInitialState(denoter, t);
  denoter.resolved = t;
  return t;
}

/// The initial value a declaration of this denoter gives its variables. §6.4.1
/// makes the *type-denoter* carry the initial state, so a type-name hands on
/// the one its definition wrote — which is what makes `type count = integer
/// value 1; var c: count` initialise `c`.
/// ISO/IEC 10206:1991 §6.4.1 makes bindability a property the *type-denoter*
/// denotes, and a type-name denotes "the type, bindability and initial state"
/// of its definition — so `type btext = bindable text` hands it on, and a
/// parameter whose form is that name is bindable. Exactly `initialStateOf`'s
/// shape, for exactly the clause's reason.
bool Sema::bindableOf(TypeExpr &denoter) {
  if (denoter.bindable)
    return true;
  if (denoter.kind == TEK::Named) {
    Symbol *s = lookup(denoter.name);
    if (s && s->kind == SymKind::Type)
      return s->isBindable;
  }
  return false;
}

Expr *Sema::initialStateOf(TypeExpr &denoter) {
  if (denoter.initOk)
    return denoter.initValue.get();
  // §6.4.2.5: "The initial state denoted by a restricted-type shall be the
  // state associated with the initial state denoted by the type-name of the
  // restricted-type." So `restricted count` hands on `count`'s, which is the
  // same hand-on a type-name makes — and the states are one-to-one, so the
  // *expression* needs no adjusting on the way through.
  if (denoter.kind == TEK::Named || denoter.kind == TEK::Restricted) {
    Symbol *s = lookup(denoter.name);
    if (s && s->kind == SymKind::Type)
      return s->initValue;
  }
  return nullptr;
}

/// Forget every type this denoter and its sub-denoters resolved to, so the
/// next production of the same schema resolves them again against a different
/// tuple. Without this a schema would produce one type and hand it out for
/// every tuple, which is precisely the bug §6.4.8 exists to rule out.
static void forgetResolved(TypeExpr *denoter) {
  if (!denoter)
    return;
  // §6.4.2.3's defining-point is the block's, so an enumerated-type in a
  // schema body denotes one type however many tuples the schema has — and its
  // constants were declared, once, when the schema was defined. Clearing this
  // would resolve it again into the production's temporary scope and lose
  // them, which is the shape the old refusal was guarding against (ADR-0107).
  if (denoter->kind != TEK::Enum)
    denoter->resolved = nullptr;
  for (auto &d : denoter->dims)
    forgetResolved(d.get());
  forgetResolved(denoter->elem.get());
  forgetResolved(denoter->tagType.get());
  for (auto &g : denoter->fields)
    forgetResolved(g.type.get());
  // A variant arm's field-list is a field-list, so its groups and its own
  // variant part are walked exactly as the record's are (ADR-0026).
  std::vector<VariantArm *> arms;
  for (auto &v : denoter->variants)
    arms.push_back(&v);
  for (size_t i = 0; i < arms.size(); ++i) {
    for (auto &g : arms[i]->fields)
      forgetResolved(g.type.get());
    forgetResolved(arms[i]->tagType.get());
    for (auto &v : arms[i]->variants)
      arms.push_back(&v);
  }
}

/// A discriminant is a symbol that lives outside every scope (see
/// `declareSchema`), so no lookup finds one — and §6.4.3.4's third form of a
/// variant-selector is a discriminant-identifier, which puts one exactly where
/// the walk below looks for a type-name. Asking the schema's own list is the
/// only way to tell that name from an undeclared one.
static bool isOwnDiscriminant(Symbol *self, const std::string &name) {
  if (!self)
    return false;
  for (Symbol *d : self->discriminants)
    if (d->name == name)
      return true;
  return false;
}

/// §6.2.2.9 and §6.4.7, asked of the schema-*definition* rather than of a
/// production. Both are rules about the text of the definition, and both were
/// invisible because the body is resolved lazily: the first production is what
/// looks a name up, and by then a definition written *after* this one exists,
/// so the forward reference resolves cleanly and a schema that never produces
/// a type is never examined at all (ADR-0107).
///
/// The pointer domain is the exception each rule states — §6.2.2.9 a) and
/// §6.4.7's "except for applied occurrences in the domain-type of a
/// new-pointer-type" — and it is honoured by not descending into a Pointer,
/// the same omission `forgetResolved` makes and for a related reason.
///
/// This asks only whether a defining-point exists *yet*; what the name means
/// is still decided at production. So the lookup is `lookupRaw`, which does
/// not record an applied occurrence (ADR-0088) — recording one here would make
/// the production's own lookup the second use of a name whose first use was
/// this question.
void Sema::checkSchemaBodyNames(TypeExpr *d, Symbol *self) {
  if (!d)
    return;
  // §6.4.2.5's `restricted T` names its underlying type rather than holding a
  // denoter, so the name to ask about is its own.
  bool names = d->kind == TEK::Named || d->kind == TEK::Schema ||
               d->kind == TEK::Restricted;
  // A qualified name reaches an interface, whose defining-points are the
  // importing block's by §6.11.3, so §6.2.2.9's ordering says nothing here.
  if (names && !d->name.empty() && d->qualifier.empty() &&
      !isOwnDiscriminant(self, d->name)) {
    Symbol *found = lookupRaw(d->name);
    if (found == self)
      diags_.error(d->line, d->col,
                   "schema '" + d->name + "' is defined in terms of itself; "
                   "only the domain of a pointer may name a schema being "
                   "defined");
    else if (!found)
      diags_.error(d->line, d->col,
                   "'" + d->name + "' is not declared yet; a schema's body "
                   "may name only what is already declared, except in a "
                   "pointer's domain");
  }

  switch (d->kind) {
  case TEK::Array:
    checkSchemaBodyNames(d->elem.get(), self);
    break;
  case TEK::File:
    checkSchemaBodyNames(d->elem.get(), self);
    checkSchemaBodyNames(d->index.get(), self);
    break;
  case TEK::Set:
    checkSchemaBodyNames(d->elem.get(), self);
    break;
  case TEK::Record: {
    for (FieldGroup &g : d->fields)
      checkSchemaBodyNames(g.type.get(), self);
    checkSchemaBodyNames(d->tagType.get(), self);
    // An arm's field-list is a field-list, walked exactly as the record's is
    // (ADR-0026), which is the same shape `forgetResolved` has.
    std::vector<VariantArm *> arms;
    for (auto &v : d->variants)
      arms.push_back(&v);
    for (size_t i = 0; i < arms.size(); ++i) {
      for (FieldGroup &g : arms[i]->fields)
        checkSchemaBodyNames(g.type.get(), self);
      checkSchemaBodyNames(arms[i]->tagType.get(), self);
      for (auto &v : arms[i]->variants)
        arms.push_back(&v);
    }
    break;
  }
  case TEK::Enum:
    // §6.4.2.3: the constants belong to the block, so they are declared here,
    // once, rather than once per production into a scope that does not outlive
    // it. `resolveType` memoises on the node and `forgetResolved` leaves an
    // Enum alone, so every production of this schema gets this type.
    resolveType(*d);
    break;
  default:
    // An array's dimensions and a subrange's bounds are expressions, not
    // denoters, and a schema's arguments likewise — §6.2.2.9 reaches those
    // through the ordinary expression path when they are checked. Pointer is
    // the exception both clauses state, and is deliberately not walked.
    break;
  }
}

/// §6.4.7's schema-definition. The formal discriminants are given names and
/// ordinal types here and values only when a type is produced, so they are
/// symbols that live outside every scope — a discriminant is not in scope in
/// the block, only inside the schema's own body and after a `.` on a variable
/// that possesses one of the schema's types.
void Sema::declareSchema(TypeDecl &decl) {
  Symbol *s = declare(decl.name, SymKind::Schema, decl.line, decl.col);
  if (s->schemaBody)
    return; // a duplicate: keep the first definition
  s->schemaBody = decl.type.get();

  for (DiscriminantGroup &g : decl.discriminants) {
    Type *t = nullptr;
    if (Symbol *named = lookup(g.typeName))
      if (named->kind == SymKind::Type)
        t = named->type;
    if (!t) {
      diags_.error(g.line, g.col, "unknown type '" + g.typeName + "'");
      t = ty::Int();
    } else if (!t->isOrdinal()) {
      // §6.4.7 requires an ordinal-type-name: a discriminant tuple has to be
      // something two types can be compared on, which a real or a record is
      // not.
      diags_.error(g.line, g.col,
                   "the type of a discriminant must be ordinal, found " +
                       t->name());
      t = ty::Int();
    }
    for (DeclName &n : g.names) {
      for (Symbol *seen : s->discriminants)
        if (seen->name == n.name) {
          diags_.error(n.line, n.col, "'" + n.name +
                                          "' is already a discriminant of "
                                          "schema '" +
                                          decl.name + "'");
          break;
        }
      Symbol *d = newSymbol();
      d->name = n.name;
      d->kind = SymKind::Const;
      d->type = t;
      s->discriminants.push_back(d);
    }
  }
  if (s->discriminants.empty())
    diags_.error(decl.line, decl.col,
                 "schema '" + decl.name + "' has no discriminants");
  // Last, so that the discriminants are declared first: a body naming one of
  // them is naming something whose defining-point precedes it.
  checkSchemaBodyNames(decl.type.get(), s);
}

Type *Sema::produceFromSchema(Symbol *schema, TypeExpr &denoter) {
  const std::vector<Symbol *> &formals = schema->discriminants;

  // §6.4.8: the tuple consists of the discriminant-values in textual order,
  // and each is compatible with the corresponding formal discriminant. A
  // wrong count is reported once and the type is not produced, because a
  // partial tuple would name a type the program never asked for.
  if (denoter.args.size() != formals.size()) {
    diags_.error(denoter.line, denoter.col,
                 "schema '" + schema->name + "' has " +
                     std::to_string(formals.size()) + " discriminant" +
                     (formals.size() == 1 ? "" : "s") + ", found " +
                     std::to_string(denoter.args.size()));
    for (auto &a : denoter.args)
      checkExpr(a.get());
    return ty::Int();
  }

  // §6.4.7: outside the domain of a pointer, a schema-definition may not name
  // itself. Silent, and that is the whole of what is left here:
  // `checkSchemaBodyNames` has already reported this at the same position,
  // because it walks the same applied occurrence at the definition rather than
  // waiting for a production (ADR-0107). What remains is the recursion guard —
  // Sema accumulates errors and goes on, so a production may still be
  // attempted after the report, and without this it would recurse until the
  // stack ran out.
  for (Symbol *busy : producing_)
    if (busy == schema)
      return ty::Int();

  std::vector<long long> tuple;
  bool ok = true;
  // §6.2.3.2 evaluates an actual-discriminant-part when the block is entered,
  // so a *variable* may have a discriminant that is not a constant — and then
  // no tuple is known here and the whole denoter goes the dynamic way. One
  // argument that is not constant is enough: a tuple is chosen as a whole.
  bool dynamic = false;
  for (size_t i = 0; i < denoter.args.size(); ++i) {
    Type *given = nullptr;
    long long value = 0;
    if (!evalOrdinal(denoter.args[i].get(), given, value)) {
      given = denoter.args[i]->type;
      if (dynamicVarFor_ && given && given->isOrdinal()) {
        dynamic = true;
      } else {
        // The message says which of the two it is, because "not a constant"
        // and "not ordinal" are different mistakes — and where a variable
        // would have been allowed, only the second one is left.
        diags_.error(denoter.args[i]->line, denoter.args[i]->col,
                     dynamicVarFor_
                         ? "the discriminants of a schema must be ordinal; '" +
                               formals[i]->name + "' is not"
                         : "the discriminants of a schema must be ordinal "
                           "constants here; '" +
                               formals[i]->name + "' is not one");
        ok = false;
        continue;
      }
    }
    if (!assignable(formals[i]->type, given)) {
      diags_.error(denoter.args[i]->line, denoter.args[i]->col,
                   "discriminant '" + formals[i]->name + "' of schema '" +
                       schema->name + "' is " + formals[i]->type->name() +
                       ", found " + given->name());
      ok = false;
      continue;
    }
    // §6.4.7's domain is the tuples *allowed* by the formal-discriminant-part,
    // so a value outside the discriminant's own type is not in the domain and
    // never reaches a production. A value not known until entry is checked
    // there instead, by the store into the descriptor — the same check, made
    // where the value finally is.
    if (dynamic) {
      continue;
    } else if (value < formals[i]->type->ordinalLo() ||
        value > formals[i]->type->ordinalHi()) {
      diags_.error(denoter.args[i]->line, denoter.args[i]->col,
                   "discriminant '" + formals[i]->name + "' is outside " +
                       formals[i]->type->name());
      ok = false;
      continue;
    }
    tuple.push_back(value);
  }
  if (!ok)
    return ty::Int();

  if (dynamic) {
    // Every position but a variable declaration has already been refused, so
    // the tuple is this variable's own and so is the type it produces.
    Symbol *v = dynamicVarFor_;
    dynamicVarFor_ = nullptr; // the body is not a variable declaration
    Type *t = genericFromSchema(schema, v, denoter, "variable's type");
    dynamicVarFor_ = v;
    if (t->isGeneric()) {
      v->descSchema = schema;
      for (auto &a : denoter.args)
        v->discExprs.push_back(a.get());
    }
    return t;
  }

  auto key = std::make_pair(schema, tuple);
  auto it = produced_.find(key);
  if (it != produced_.end())
    return it->second;

  // §6.4.3.3.3: the required schema has no body to resolve. What it produces
  // is a variable-string-type whose capacity is the tuple's one component —
  // "each tuple in the domain of the schema shall have one component that is a
  // value of integer-type greater than zero". A capacity of zero or less is
  // therefore outside the *domain*, which is why the message is the one every
  // other tuple outside a domain gets.
  if (schema->isStringSchema) {
    if (tuple[0] <= 0) {
      diags_.error(denoter.line, denoter.col,
                   "the capacity of a string must be greater than zero, "
                   "found " + std::to_string(tuple[0]));
      return ty::Int();
    }
    return stringOfCapacity(tuple[0]);
  }

  // Produce it: the discriminants become ordinary constants for as long as the
  // body is being resolved, which is what lets `array [1..n] of real` reach
  // the existing subrange and array code with nothing added to either.
  pushScope();
  for (size_t i = 0; i < formals.size(); ++i) {
    // A discriminant named twice was already reported at the schema; binding
    // it again here would report it once more at every *use*, and point at
    // the tuple rather than at the definition that is wrong.
    bool repeated = false;
    for (size_t j = 0; j < i; ++j)
      repeated = repeated || formals[j]->name == formals[i]->name;
    if (repeated)
      continue;
    Symbol *d = declare(formals[i]->name, SymKind::Const, denoter.line,
                        denoter.col);
    d->type = formals[i]->type;
    d->discBinding = true;
    d->discIndex = static_cast<int>(i);
    d->intVal = tuple[i];
    d->charVal = static_cast<char>(tuple[i]);
    d->boolVal = tuple[i] != 0;
  }
  forgetResolved(schema->schemaBody);
  producing_.push_back(schema);
  size_t before = diags_.all().size();
  bool savedSchemaBody = schemaBody_;
  schemaBody_ = true;
  Type *t = resolveType(*schema->schemaBody);
  schemaBody_ = savedSchemaBody;
  producing_.pop_back();
  popScope();
  // §6.4.7's domain is the tuples for which the body denotes a type at all —
  // NOTE 2 lists an empty subrange among the ways one can fail. Whatever the
  // body reported, it reported it against the *schema's* text, which is not
  // where the reader chose the tuple; this says which choice it was.
  if (diags_.all().size() != before)
    diags_.error(denoter.line, denoter.col,
                 "no type is produced from schema '" + schema->name +
                     "' with these discriminants");

  // The body is *not* cleared again afterwards, so `--dump-sema` shows the
  // last type the schema produced rather than a row of `?`. A schema body has
  // no one type, so either is a half-truth; this one at least says what the
  // resolution of it looks like, and the next production clears it first.


  // A produced type is a type of its own even when the body is a name or a
  // simple type, so the provenance goes on a copy rather than on the shared
  // singleton `integer` would hand back.
  if (t->schema || t == ty::Int() || t == ty::Real() || t == ty::Bool() ||
      t == ty::Char() || t == ty::Text()) {
    Type *copy = newType(t->kind);
    *copy = *t;
    t = copy;
  }
  t->schema = schema;
  t->tuple = tuple;
  // A produced type names itself after the schema and the tuple that produced
  // it. Without this, two productions of one schema print identically — and
  // §6.4.8's whole point is that they are different types, so a diagnostic
  // that spelled `paint(red)` and `paint(green)` the same way would be
  // reporting the rule while hiding the reason.
  std::string spelled = schema->name + "(";
  for (size_t i = 0; i < tuple.size(); ++i)
    spelled += (i ? ", " : "") + Type::ordinalName(formals[i]->type, tuple[i]);
  t->alias = spelled + ")";
  produced_[key] = t;
  return t;
}

/// True when no bound anywhere inside this type depends on a discriminant.
/// A pointer stops the walk: ISO 7185 §6.4.4 makes its domain a type
/// *identifier*, which is a type of the enclosing block and never generic.
bool Sema::staticThroughout(Type *t) const {
  if (!t)
    return true;
  if (t->dynamicBounds())
    return false;
  switch (t->kind) {
  case TypeKind::Array:
    return staticThroughout(t->indexType) && staticThroughout(t->elem);
  case TypeKind::Set:
  case TypeKind::File:
    return staticThroughout(t->elem);
  case TypeKind::Record:
    for (const Field &f : t->fields)
      if (!staticThroughout(f.type))
        return false;
    return staticVariants(t->variants);
  default:
    return true;
  }
}

/// What a descriptor can describe: a type whose *size* may depend on the
/// discriminants while every offset *inside* it stays a constant. That is the
/// whole of the restriction, and both halves of it are here.
///
/// An array qualifies whatever its bounds, because a component's address is
/// computed from the bounds rather than looked up. A record qualifies when the
/// dynamic part is its **last** field and it has no variant part — a field
/// after a dynamically-sized one, and the shared block of a variant part, both
/// sit at an offset nothing can compute. Everything else is refused: a set and
/// a file each have a size the runtime is told once.
bool Sema::dynamicTail(Type *t) const {
  if (!t || !t->dynamicExtent())
    return staticThroughout(t);
  if (t->isArray())
    return dynamicTail(t->elem);
  if (!t->isRecord() || !t->variants.empty() || t->fields.empty())
    return false;
  for (size_t i = 0; i + 1 < t->fields.size(); ++i)
    if (!staticThroughout(t->fields[i].type))
      return false;
  return dynamicTail(t->fields.back().type);
}

/// The same question through every arm of a variant part, at every depth.
bool Sema::staticVariants(const std::vector<Variant> &arms) const {
  for (const Variant &v : arms) {
    for (const Field &f : v.fields)
      if (!staticThroughout(f.type))
        return false;
    if (!staticVariants(v.variants))
      return false;
  }
  return true;
}

/// §6.7.3.2 and §6.7.3.3's parameter-form written as a bare schema-name. The
/// body is resolved once, with each discriminant bound to a `Disc` symbol that
/// reads this parameter's descriptor rather than to a value — so `1..n` comes
/// out as "the value of n", and one compiled body serves every tuple.
///
/// The result belongs to this one parameter and is deliberately not interned:
/// two parameters of one schema read two descriptors, so they cannot share a
/// type however alike they look.
Type *Sema::schematicFormal(Symbol *schema, Symbol *param, TypeExpr &denoter) {
  Type *t = genericFromSchema(schema, param, denoter, "parameter form");
  if (t->isGeneric())
    param->descSchema = schema;
  return t;
}

/// The body resolved once with each discriminant bound to a `Disc` symbol that
/// reads `owner`'s descriptor rather than to a value — so `1..n` comes out as
/// "the value of n", and one resolution serves every tuple.
///
/// The result belongs to that one symbol and is deliberately not interned: two
/// of them read two descriptors, so they cannot share a type however alike
/// they look.
Type *Sema::genericFromSchema(Symbol *schema, Symbol *owner, TypeExpr &denoter,
                              const char *noun) {
  Symbol *param = owner;
  const std::vector<Symbol *> &formals = schema->discriminants;
  if (formals.empty())
    return ty::Int(); // already reported at the schema-definition

  // No self-reference guard here. §6.4.7's rule is enforced where the
  // recursion would happen — in the production the body reaches — and a
  // parameter-form is never resolved inside one, so a second copy of the
  // check would be unreachable. Mutation testing is what said so.
  pushScope();
  param->discSyms.clear();
  for (size_t i = 0; i < formals.size(); ++i) {
    Symbol *d = newSymbol();
    d->name = formals[i]->name;
    d->kind = SymKind::Disc;
    d->type = formals[i]->type;
    d->discBinding = true;
    // The discriminant lives in the parameter's own frame slot, after the
    // address, so it is reached exactly as the parameter is and a recursive
    // procedure sees the descriptor of the invocation it is running in.
    d->owner = param->owner;
    d->level = param->level;
    d->frameIndex = param->frameIndex;
    d->discIndex = static_cast<int>(i);
    param->discSyms.push_back(d);
    // A discriminant named twice was reported at the schema; binding it again
    // here would report it once more at every parameter that names the schema.
    bool repeated = false;
    for (size_t j = 0; j < i; ++j)
      repeated = repeated || formals[j]->name == formals[i]->name;
    if (!repeated)
      scopes_.back()[d->name] = d;
  }

  // §6.4.3.3.3 again: a schematic formal `var s: string` is a string whose
  // capacity arrives with the actual, so the bound is the `Disc` symbol rather
  // than a number — exactly as `array [1..n]` reaches ADR-0040's descriptor.
  if (schema->isStringSchema) {
    popScope();
    Type *t = newType(TypeKind::String);
    t->lo = 1;
    t->hi = 0;
    t->hiDisc = param->discSyms[0];
    t->schema = schema;
    param->descSchema = schema;
    return t;
  }

  forgetResolved(schema->schemaBody);
  producing_.push_back(schema);
  Symbol *savedGeneric = genericFor_;
  genericFor_ = param;
  size_t before = diags_.all().size();
  bool savedSchemaBody = schemaBody_;
  schemaBody_ = true;
  Type *t = resolveType(*schema->schemaBody);
  schemaBody_ = savedSchemaBody;
  genericFor_ = savedGeneric;
  producing_.pop_back();
  popScope();
  if (diags_.all().size() != before) {
    diags_.error(denoter.line, denoter.col,
                 "no type is produced from schema '" + schema->name +
                     "' for this " + noun);  // "parameter form" / "variable's type"
    return ty::Int();
  }

  // What a descriptor can describe (ADR-0045).
  if (!dynamicTail(t)) {
    diags_.error(denoter.line, denoter.col,
                 "schema '" + schema->name + "' cannot be a " + noun +
                     ": a discriminant has to bound an array, and a record "
                     "holding one has to hold it last, because a field after "
                     "it would sit at an offset nothing can compute");
    return ty::Int();
  }

  // A produced type is a type of its own, so a body that resolved to a shared
  // singleton is copied before its provenance is written on it.
  if (t->schema || t == ty::Int() || t == ty::Real() || t == ty::Bool() ||
      t == ty::Char() || t == ty::Text()) {
    Type *copy = newType(t->kind);
    *copy = *t;
    t = copy;
  }
  t->schema = schema;
  t->alias = schema->name; // no tuple to name it by; the descriptor holds it
  return t;
}

/// §6.4.3.3.3's `string(cap)`, interned.
///
/// §6.4.8 makes one schema with one tuple **one type** however often it is
/// written, so this has to be the only way such a type is made. It is a
/// separate function because there are two callers and only one of them has a
/// type-denoter to resolve: §6.4.3.4's `BindingType` gives its `name` field
/// "an implementation-defined variable-string-type", and building that field a
/// second `string(255)` of its own made `binding(f).name` a type no program
/// could name — it printed as `string(255)`, compared unequal to the
/// `string(255)` a program wrote, and so could not be passed to
/// `procedure p(var s: string)`. Two types that print alike and are not the
/// same type is ADR-0074's diagnostic problem arriving as a real one.
Type *Sema::stringOfCapacity(int cap) {
  Symbol *schema = stringSchema_;
  std::vector<long long> tuple{cap};
  auto key = std::make_pair(schema, tuple);
  auto it = produced_.find(key);
  if (it != produced_.end())
    return it->second;
  Type *t = newType(TypeKind::String);
  t->lo = 1;
  t->hi = cap;
  t->schema = schema;
  t->tuple = tuple;
  produced_[key] = t;
  return t;
}

void Sema::installPredefined() {
  // §6.2.2.10: "Required identifiers that denote required values, types,
  // procedures, and functions shall be used as if their defining-points have a
  // region enclosing the program." A required *type* is therefore an ordinary
  // type symbol in the outermost scope, and `type integer = char` hides it for
  // the whole program.
  auto requiredType = [&](const char *name, Type *t) {
    declare(name, SymKind::Type, 0, 0)->type = t;
    // And the type takes the name too. These are shared singletons, so without
    // this the first `type foo = char` in any program claims the one `char`
    // object's alias and every later `char` variable is *reported* as `foo` —
    // §6.4.1 makes them the same type, so nothing is mis-compiled, but the
    // diagnostic names something the program never wrote. `text` has carried
    // its own name since it was created, for the same reason.
    if (t->alias.empty())
      t->alias = name;
  };

  // ...and a required function is a marker of that same region — see
  // SymKind::Required. The required *procedures* are deliberately not here:
  // each already yields to a program's own declaration through the "lookup
  // answered null" path (ADR-0087), so a symbol would buy no verdict.
  auto requiredFunc = [&](const char *name) {
    declare(name, SymKind::Required, 0, 0);
  };

  // §6.4.1's required type-identifiers. `complex` is 10206's alone, and a
  // valid ISO 7185 program may define a type of that name — which is why it is
  // asked of the standard here rather than of the lexer.
  requiredType("integer", ty::Int());
  requiredType("real", ty::Real());
  requiredType("boolean", ty::Bool());
  requiredType("char", ty::Char());
  requiredType("text", ty::Text());
  if (std_ == Std::Extended)
    requiredType("complex", ty::Complex());

  // §6.6.6's required functions. The 10206-only ones are declared only under
  // that standard, so an ISO 7185 program may still declare a function called
  // `re` and checkCall may still say that `re` is an Extended Pascal function
  // rather than that the name is unknown.
  for (const char *n : {"abs", "sqr", "odd", "ord", "chr", "succ", "pred",
                        "sqrt", "sin", "cos", "ln", "exp", "arctan", "trunc",
                        "round", "eof", "eoln"})
    requiredFunc(n);
  if (std_ == Std::Extended)
    for (const char *n : {"card", "cmplx", "polar", "re", "im", "arg",
                          "position", "lastposition", "empty", "length",
                          "index", "substr", "trim", "eq", "ne", "lt", "gt",
                          "le", "ge", "binding", "date", "time"})
      requiredFunc(n);

  Symbol *t = declare("true", SymKind::Const, 0, 0);
  t->type = ty::Bool();
  t->boolVal = true;

  Symbol *f = declare("false", SymKind::Const, 0, 0);
  f->type = ty::Bool();
  f->boolVal = false;

  Symbol *m = declare("maxint", SymKind::Const, 0, 0);
  m->type = ty::Int();
  m->intVal = kMaxInt;

  // ISO/IEC 10206:1991 §6.4.2.2 d): "The value of maxchar shall be the largest
  // value of char-type." A char here is a byte (ADR-0021), so it is 255 — and
  // it is a required *identifier* declared in the outermost scope, which a
  // program may shadow, rather than a word-symbol. Under ISO 7185 the name is
  // an ordinary identifier and nothing declares it.
  if (std_ == Std::Extended) {
    Symbol *mc = declare("maxchar", SymKind::Const, 0, 0);
    mc->type = ty::Char();
    mc->charVal = static_cast<char>(kSetLimit);

    // ISO/IEC 10206:1991 §6.4.2.2 b): "Each of the required
    // constant-identifiers minreal, maxreal, and epsreal shall denote an
    // implementation-defined positive value of real-type", where maxreal and
    // minreal bound the magnitudes arithmetic can be expected to work over and
    // "the value of epsreal shall be the result of subtracting 1.0 from the
    // smallest value of real-type that is greater than 1.0."
    //
    // A real is an IEEE-754 binary64 here, so the three are its largest
    // finite value, its smallest positive *normal* one, and its epsilon —
    // §6.4.2.2's NOTE 2 leaves the representation unspecified and Annex E
    // makes each of these values implementation-defined, so naming the
    // representation is what fixes them.
    //
    // They are spelled as **decimal text, identical in both compilers**, and
    // that is the mechanism rather than a formatting choice: `selfhost` has no
    // floating-point type at all and carries a real literal as the characters
    // that were written, all the way into the IR (ADR-0025). Each of the three
    // spellings below is the shortest decimal that round-trips to the value it
    // names, so the two compilers reach the same double by two different
    // routes — one through strtod here, one through LLVM's assembler there.
    Symbol *mr = declare("maxreal", SymKind::Const, 0, 0);
    mr->type = ty::Real();
    mr->realVal = 1.7976931348623157e308;

    Symbol *nr = declare("minreal", SymKind::Const, 0, 0);
    nr->type = ty::Real();
    nr->realVal = 2.2250738585072014e-308;

    Symbol *er = declare("epsreal", SymKind::Const, 0, 0);
    er->type = ty::Real();
    er->realVal = 2.220446049250313e-16;
  }

  // ISO/IEC 10206:1991 §6.4.3.3.3: "There shall be a schema that is denoted by
  // the required schema-identifier `string`. The schema `string` shall have
  // one formal discriminant denoted by the required discriminant-identifier
  // `capacity`, which shall possess the integer-type."
  //
  // It is declared like any other required identifier — in the outermost
  // scope, where a program may shadow it — and not as a word-symbol, because
  // §6.4.3.3.3 makes it an identifier and a valid ISO 7185 program may define
  // a type of that name.
  if (std_ == Std::Extended) {
    // The schema is declared *first*, although §6.4.3.4 comes before
    // §6.4.3.3.3 in the standard, because `BindingType` has a field produced
    // from it and §6.4.8 makes that production the same type as the one a
    // program writes. Ordering the other way is what left the field with a
    // `string(255)` of its own.
    Symbol *str = declare("string", SymKind::Schema, 0, 0);
    str->isStringSchema = true;
    Symbol *cap = newSymbol();
    cap->name = "capacity";
    cap->kind = SymKind::Const;
    cap->type = ty::Int();
    str->discriminants.push_back(cap);
    stringSchema_ = str;

    // §6.4.3.4: "There shall be a record-type designated packed and denoted by
    // the required type-identifier `BindingType`. For each of the required
    // field-identifiers `name` and `bound`, there shall be an associated
    // required field ... an implementation-defined variable-string-type and a
    // type denoted by the type-denoter Boolean, respectively."
    //
    // The capacity of `name` is the implementation-defined part, and it is
    // what made this feature wait for ADR-0051: there was no
    // variable-string-type to give the field until the string type existed.
    Type *bt = newType(TypeKind::Record);
    bt->packed = true;
    bt->alias = "BindingType";
    Type *nameType = stringOfCapacity(kBindingNameCapacity);
    Field name;
    name.name = "name";
    name.type = nameType;
    name.index = 0;
    bt->fields.push_back(name);
    Field bound;
    bound.name = "bound";
    bound.type = ty::Bool();
    bound.index = 1;
    bt->fields.push_back(bound);
    Symbol *bts = declare("bindingtype", SymKind::Type, 0, 0);
    bts->type = bt;
    bindingType_ = bt;

    // §6.4.3.4: "There shall be a record-type designated packed and denoted by
    // the required type-identifier `TimeStamp`. For each of the required
    // field-identifiers DateValid, TimeValid, year, month, day, hour, minute,
    // and second, there shall be an associated required field ... and that
    // field shall have a type denoted by the type-denoter Boolean, Boolean,
    // integer, 1..12, 1..31, 0..23, 0..59, and 0..59, respectively."
    //
    // Written out here rather than parsed from NOTE 4's Pascal because the
    // field *order* is what CodeGen walks: `GetTimeStamp` fills the record by
    // index, so the standard's order is the interface, and this is where it is
    // decided. Two other places follow it and neither can be derived from this
    // one (ADR-0065) — the `date`/`time` arm's literal 2 and 5, and the
    // runtime's `pas_stamp` slots.
    //
    // The subranges are what make this record worth the words. A program that
    // stores 13 into `month` traps at the store like any other subrange
    // (ADR-0018), and `date(t)` is left with only the errors those bounds
    // cannot catch — February the 30th, and a year the calendar has not got.
    auto span = [&](int lo, int hi) {
      Type *t = newType(TypeKind::Subrange);
      t->host = ty::Int();
      t->lo = lo;
      t->hi = hi;
      return t;
    };
    Type *ts = newType(TypeKind::Record);
    ts->packed = true;
    ts->alias = "TimeStamp";
    struct {
      const char *name;
      Type *type;
    } stamp[] = {{"datevalid", ty::Bool()}, {"timevalid", ty::Bool()},
                 {"year", ty::Int()},       {"month", span(1, 12)},
                 {"day", span(1, 31)},      {"hour", span(0, 23)},
                 {"minute", span(0, 59)},   {"second", span(0, 59)}};
    for (const auto &f : stamp) {
      Field fld;
      fld.name = f.name;
      fld.type = f.type;
      fld.index = static_cast<int>(ts->fields.size());
      ts->fields.push_back(fld);
    }
    Symbol *tss = declare("timestamp", SymKind::Type, 0, 0);
    tss->type = ts;
    timeStampType_ = ts;
  }
}

/// ISO 7185 §6.4.5 makes two structured types the same only when one type
/// identifier denotes both, so they compare by identity here — two separately
/// written `array [1..3] of integer` denoters are different types.
///
/// String types are the documented exception (§6.4.5): packed char arrays of
/// equal length are compatible however they were written, which is what lets a
/// literal be assigned to one and two of them be compared.
bool Sema::assignable(Type *to, Type *from) const {
  if (!to || !from)
    return true; // an earlier error already reported
  // A file is never assignable, not even to itself, and neither is anything
  // holding one. §6.4.6 a) is two conditions and not one: "T1 and T2 are the
  // same type, **and that type is permissible as the component-type of a
  // file-type**" — which §6.4.3.5 (ISO/IEC 10206:1991 §6.4.3.6) defines as
  // neither a file nor a structured type with a component that is not one, and
  // which `containsFile` is exactly. §6.7.2.5 gives none of them a relational
  // operator either, and both questions arrive here.
  //
  // The second condition went unread and this asked `isFile()`, so `z := y`
  // between two records holding a text file was accepted by both front ends —
  // and the Pascal one lowered it to a memcpy of the file's own storage, so
  // closing the block closed one `struct pas_file` twice (ADR-0150). This is
  // also why `isStructured()` deliberately excludes files, that predicate
  // being what grants a whole-variable copy.
  if (containsFile(to) || containsFile(from))
    return false;
  // A procedural parameter is not a value either: ISO 7185 gives it no
  // assignment and no operators, and the only place one may travel is another
  // procedural parameter — which checkProcArgument handles without coming here.
  if (to->isProc() || from->isProc())
    return false;
  if (to == from)
    return true;
  // §6.4.2.5: "Attribution of a value of a type to a variable possessing the
  // underlying-type of the type shall constitute the attribution of the
  // associated value of the underlying-type", and the sentence after it says
  // the same in the other direction. So a restricted type and its
  // underlying-type assign to each other and to nothing else — which is one
  // line here, because `underlying()` answers for a type that is not
  // restricted with the type itself.
  // §6.4.2.5 permits attribution between a restricted type and *its*
  // underlying-type, in both directions, and says nothing about two restricted
  // types — so two restrictions of one underlying type stay as distinct as
  // ADR-0017 makes any two named types, and only one side may be restricted
  // here. `to == from` was answered above, which is what leaves this to say.
  if (to->isRestricted() || from->isRestricted())
    return to->isRestricted() != from->isRestricted() &&
           to->underlying() == from->underlying();
  // ISO/IEC 10206:1991 §6.4.6 a) is "T1 and T2 are the same type", and §6.4.8
  // makes one schema with one tuple one type — so wherever both tuples are
  // known the line above has already decided this, and two different tuples
  // are two different types. What that line cannot decide is a type produced
  // *within an activation*, whose tuple is not known until the block is
  // entered. §6.4.6 d) calls a mismatch there a dynamic-violation, and §6.1's
  // f) 2) is the permission to report it while the program runs — so the rule
  // is unchanged and only the moment of the comparison moves. CodeGen makes
  // it; all that is decided here is that both were produced from one schema.
  // ISO/IEC 10206:1991 §6.4.5 d): "T1 is either a string-type or the char-type
  // and T2 is either a string-type or the char-type." *All* of them are
  // compatible with each other, whatever their capacities — and §6.4.6 f) then
  // makes the assignment legal when the value's length fits, which is a
  // question about the value and so a run-time one. That is the whole of the
  // divergence from ISO 7185, where two strings had to have the same length.
  //
  // It comes before the schema rule below, and must: two capacities are two
  // types produced from one schema with different tuples, which §6.4.6 d)
  // would otherwise call a dynamic-violation. §6.4.6 f) is the more specific
  // rule and the required schema is what it is about.
  // Two chars are not this rule: they are the ordinary compatibility below,
  // and routing them here would answer a different question — an ISO 7185
  // program indexing a `'a'..'e'` array with a char is not a string at all.
  if (std_ == Std::Extended && (to->isStringType() || from->isStringType()) &&
      to->isStringOrChar() && from->isStringOrChar())
    return true;
  // A subrange is exempt, and has to be: since ADR-0133 one whose bounds are
  // discriminants carries the anonymous schema ADR-0113 hangs a descriptor on,
  // which is a compiler device and not §6.4.8's schema — no schema-definition
  // produced it and no tuple selects it. What the type *is* is a subrange, so
  // §6.4.6 asks about its host, which is what the ordinal rules below do. Left
  // here it would be compatible only with a subrange sharing its descriptor,
  // so `x := 3` into `var x: 1..m` would be refused.
  if ((to->isGeneric() || from->isGeneric()) &&
      to->kind != TypeKind::Subrange && from->kind != TypeKind::Subrange)
    return to->schema == from->schema;
  // ISO 7185 §6.4.6 makes set compatibility *structural*, not by name: two set
  // types are compatible when their base types are. This is the standard's own
  // departure from the name equivalence of §6.4.5, so it is not an exception
  // invented here — and it is what lets `[]` and `['a'..'z']`, which no type
  // definition ever named, be assigned to a variable at all.
  if (to->isSet() || from->isSet()) {
    if (!to->isSet() || !from->isSet())
      return false;
    if (to->isEmptySet() || from->isEmptySet())
      return true;
    // §6.4.5 c) has a second half: "and either both T1 and T2 are designated
    // packed or neither T1 nor T2 is designated packed". ISO/IEC 10206:1991
    // §6.4.5 c) is that sentence word for word, so this is gated on neither
    // standard. A set-constructor is exempt because §6.7.1 has not committed
    // it to a packing — it denotes the unpacked-canonical-set-of-T-type "or,
    // if the context so requires, the packed" one — so `p := [true]` into a
    // packed set is legal while `p := b` from an unpacked one is not. Every
    // set is one 256-bit word whatever was written (ADR-0028), so this is a
    // type rule with no lowering and CodeGen is untouched (ADR-0093).
    return to->elem->base() == from->elem->base() &&
           (to->setCanonical || from->setCanonical ||
            to->packed == from->packed);
  }
  // ISO/IEC 10206:1991 §6.4.5 d): "T1 is either a string-type or the char-type
  // and T2 is either a string-type or the char-type." *All* of them are
  // compatible with each other, whatever their capacities — and §6.4.6 f) then
  // makes the assignment legal when the value's length fits, which is a
  // question about the value and so a run-time one. That is the whole of the
  // divergence from ISO 7185, where two strings had to have the same length.
  if (to->isStructured() || from->isStructured())
    return to->isCharArray() && from->isCharArray() &&
           to->length() == from->length();

  // `nil` is a value of every pointer type; two named pointer types are
  // otherwise as distinct as any other named types (the `to == from` above).
  if (to->isPointer() || from->isPointer())
    return (to->isPointer() && from->isNil()) ||
           (from->isPointer() && to->isNil());

  // A subrange is compatible with its host type and with any other subrange of
  // it (ISO 7185 §6.4.5), so compatibility is decided on the base. Whether the
  // *value* fits is a run-time question, checked where it is stored.
  const Type *tb = to->base();
  const Type *fb = from->base();
  if (tb == fb)
    return true;
  // Two enumerated types are never compatible, however alike they look, so
  // they must not fall through to the kind comparison below.
  if (tb->isEnum() || fb->isEnum())
    return false;
  if (tb->kind == fb->kind)
    return true;
  // ISO/IEC 10206:1991 §6.4.6 c): a complex accepts an integer or a real, and
  // "an implicit integer-to-complex conversion or real-to-complex conversion,
  // respectively, shall be performed". Written the same way round as the
  // real-from-integer widening below it, and for the same reason — the
  // widening is exact and the narrowing does not exist.
  if (to->isComplex())
    return from->isNumeric();
  return to->isReal() && from->isInteger();
}

Symbol *Sema::lookupWithField(const std::string &name,
                              const Field *&field) const {
  // A `with` scope sits inside every enclosing one, so its fields are looked
  // at first and shadow declarations of the same name further out.
  for (auto it = withStack_.rbegin(); it != withStack_.rend(); ++it) {
    if (const Field *f = (*it)->type->findField(name)) {
      field = f;
      return *it;
    }
  }
  return nullptr;
}

/// ISO/IEC 10206:1991 §6.8.8's constant-access: a constant-name, or a
/// component selected from one. Structural — it asks what the *root* denotes
/// and not what the value is, so it neither folds nor diagnoses, which is what
/// lets it be asked as a question (ADR-0069).
///
/// It is the exact counterpart of `isDesignator`: §6.5.1's variable-accesses
/// and §6.8.8's constant-accesses have the same three selector forms and
/// differ only in what stands at the bottom.
bool Sema::isConstantAccess(Expr *e) const {
  if (auto *v = as<VarRef>(e))
    return !v->withField && v->sym && v->sym->kind == SymKind::Const;
  if (auto *f = as<FieldExpr>(e))
    return f->qualified
               ? f->qualified->kind == SymKind::Const
               : (!f->isDiscriminant && isConstantAccess(f->base.get()));
  if (auto *i = as<IndexExpr>(e))
    return !i->setValue && isConstantAccess(i->base.get());
  if (auto *s = as<SubstringExpr>(e))
    return !s->setValue && isConstantAccess(s->base.get());
  return false;
}

/// §6.8.8's constant-access belongs to ISO/IEC 10206:1991 alone. ISO 7185 §6.3
/// gives a constant no selectors at all — its `unsigned-constant` is a number,
/// a character-string, a constant-identifier or `nil` — and §6.7.1 admits a
/// `[`, a `.` or a `^` only after a variable-access, which a constant is not.
///
/// It has to be refused *here* rather than in the parser, because a selector
/// over a name is a designator until the symbol says otherwise, and the parser
/// has no scope (ADR-0072). Called from the subscript and the field selection
/// with its own base, so a nested one is reported once, at the outermost.
///
/// **Two of §6.8.8's three forms, not three.** §6.8.8.4's substring needs a
/// `..` inside a subscript, which the parser reads only under `--std=extended`
/// — so no `SubstringExpr` exists under ISO 7185, and a call from that arm
/// could never fire in either standard. It was written for symmetry and
/// deleted for being unreachable; `tests/substring_iso.pas` is where that
/// half is refused, a stage earlier.
void Sema::refuseConstAccess(Expr *base, int line, int col) {
  if (std_ == Std::Extended || !isConstantAccess(base))
    return;
  diags_.error(line, col,
               "selecting from a constant is an Extended Pascal feature; "
               "compile with --std=extended");
}

/// Whether the expression is a constant-access whose value lives in memory. It
/// is not a variable and never becomes one; what it has is *storage*, which is
/// what the places that copy a structured value need of an argument
/// (ADR-0068).
bool Sema::isMemoryConstant(Expr *e) const {
  return e->type && e->type->isMemory() && isConstantAccess(e);
}

/// ISO 7185 §6.6.3.3: an actual variable parameter shall not denote a field
/// that is the tag-field of a variant-part. Assigning through the reference
/// could select a different variant while the arm's own fields were live.
static bool variantSelector(Expr *e) {
  const Field *f = nullptr;
  Type *rec = nullptr;
  if (auto *v = as<VarRef>(e)) {
    // a field of an open `with`, whose base is the binding rather than a node
    if (v->withField && v->sym) {
      f = v->withField;
      rec = v->sym->type;
    }
  } else if (auto *fe = as<FieldExpr>(e)) {
    if (fe->resolved && !fe->qualified) {
      f = fe->resolved;
      rec = fe->base->type;
    }
  }
  return f && rec && rec->isRecord() &&
         rec->tagFieldAt(f->variant) == f->index;
}

/// The container of a component, or null: §6.6.3.3 asks what the variable a
/// component belongs to *possesses*, and that is one step, never a walk.
///
/// The *immediate* container and no further. §6.4.3.1: "if a component is
/// itself structured, the component's representation in data-storage shall be
/// packed only if the type of the component is designated packed" — so packing
/// does not reach a component's own components, and `a[1][2]` is a component
/// of `a[1]`, which the token `packed` in front of `a` did not designate. The
/// multi-dimensional abbreviation is not an exception: §6.4.3.2 designates
/// every array-type it constructs packed when the original is, which
/// `resolveArray` does, so `a[1][2]` over a `packed array [1..3, 1..3]` is
/// caught here (ADR-0099).
static Type *containerOf(Expr *e) {
  if (auto *v = as<VarRef>(e))
    return (v->withField && v->sym) ? v->sym->type : nullptr;
  if (auto *ix = as<IndexExpr>(e))
    return ix->base->type;
  if (auto *fe = as<FieldExpr>(e))
    return (!fe->qualified && !fe->isDiscriminant) ? fe->base->type : nullptr;
  return nullptr;
}

/// ISO/IEC 10206:1991 §6.7.3.3's third sentence: "An actual variable parameter
/// shall not denote a component of a string-type." ISO 7185 §6.6.3.3 has only
/// the first two, and needs no third — every string-type there is a packed
/// array of char, so the packed rule already reaches it. What this adds is the
/// *variable*-string, which is not packed.
static bool stringComponent(Expr *e) {
  Type *c = containerOf(e);
  return c && c->isStringType();
}

static bool packedComponent(Expr *e) {
  Type *c = containerOf(e);
  return c && c->packed;
}

/// The last two sentences of §6.6.3.3 / §6.7.3.3, asked of an actual that is
/// already known to be a variable. True means it was reported. Both branches
/// of `checkArguments` that bind a reference ask this one function, because
/// the two clauses are one clause and a schematic formal is a var parameter.
bool Sema::badVarActual(Expr *a, Symbol *callee, int i) {
  std::string where =
      "argument " + std::to_string(i) + " of '" + callee->name + "'";
  if (variantSelector(a)) {
    diags_.error(a->line, a->col, where + " cannot be the tag of a variant part");
    return true;
  }
  if (packedComponent(a)) {
    diags_.error(a->line, a->col,
                 where + " cannot be a component of a packed variable");
    return true;
  }
  // Asked after the packed one, so a fixed-string component keeps the message
  // that names the rule ISO 7185 also has.
  if (stringComponent(a)) {
    diags_.error(a->line, a->col, where + " cannot be a component of a string");
    return true;
  }
  return false;
}

bool Sema::isDesignator(Expr *e) const {
  if (auto *v = as<VarRef>(e)) {
    if (!v->sym)
      return false;
    // §6.9.3.10 makes a field of a `with` over a *constant*-access a
    // constant-field-identifier, which denotes a value. The binding is a
    // `VarParam` either way — it holds an address — so the kind cannot answer
    // and the binding has to say which of the two it is (ADR-0069).
    if (v->withField)
      return !v->sym->isConstBinding;
    return v->sym->isVariable();
  }
  if (auto *i = as<IndexExpr>(e))
    return isDesignator(i->base.get());
  // §6.5.6's substring-variable is a variable-access; §6.8.6.5's
  // substring-function-access is a value. The syntax is identical and the base
  // is the whole difference, which is why one node serves both.
  if (auto *s = as<SubstringExpr>(e))
    return isDesignator(s->base.get());
  if (auto *f = as<FieldExpr>(e)) {
    // A qualified name is the whole selection, so what it denotes is what
    // decides — there is no base variable underneath it.
    if (f->qualified)
      return f->qualified->isVariable();
    // §6.8.4 makes a schema-discriminant a *primary*, not a variable-access:
    // it is the value the type was produced with, and there is nowhere to
    // store into. `v.n := 3` would be asking a variable to change its type.
    return !f->isDiscriminant && isDesignator(f->base.get());
  }
  // What a pointer points at is a variable however the pointer was obtained,
  // so a dereference is a designator even when its base is not.
  if (is<DerefExpr>(e))
    return true;
  // §6.7.6.8's `binding(f)` is built in a hidden frame slot, so it denotes a
  // variable — which is what makes `binding(f).bound` an ordinary field
  // selection rather than a case of its own.
  if (auto *c = as<Call>(e))
    return c->builtin == Builtin::Binding;
  return false;
}

/// Whether the variable a designator denotes possesses the bindability that is
/// bindable — ISO/IEC 10206:1991 §6.7.5.6 and §6.7.6.8 both ask this of `bind`,
/// `unbind` and `binding`, and it is a property of the *variable-access* and
/// not of the entire-variable it selects from.
///
/// It used to be asked of the entire-variable, through `baseSymbol`, and that
/// was wrong in both directions at once. §6.4.3.4 gives a field "the type,
/// bindability, and initial state denoted by the type-denoter of the
/// record-section" and §6.4.3.5 says the same of an array's component, so
/// `bind(r.log, b)` and `bind(pool[i], b)` are legal for a bindable field and a
/// bindable element — and both were refused with a message naming the
/// *container*. Meanwhile a dereference has no VarRef under it, so the old walk
/// found nothing to ask and let every `p^` through.
///
/// A dereference still answers true, which is the under-strict half and is
/// deliberately unfinished; `doc/implementation-defined.md` §6.1 carries it.
/// A substring is nonbindable by §6.5.3.1 and a buffer-variable by §6.5.5, and
/// both fall to the closing `false`.
/// §6.7.5.6's and §6.7.6.8's refusal, in one place because the three
/// procedures and the one function all ask the same question. The name written
/// is the *thing that is not bindable*: a field where the designator ends in
/// one, the entire-variable otherwise — which for `pool[i]` is `pool`, and is
/// the right name now that the question is asked of the component rather than
/// of the container.
void Sema::notBindable(Expr *a) {
  std::string who;
  if (auto *f = as<FieldExpr>(a))
    who = f->qualified ? f->qualified->name
                       : (f->resolved ? f->resolved->name : std::string());
  else if (auto *v = as<VarRef>(a))
    who = v->withField ? v->withField->name
                       : (v->sym ? v->sym->name : std::string());
  else if (Symbol *root = baseSymbol(a))
    who = root->name;
  diags_.error(
      a->line, a->col,
      (who.empty() ? std::string("this variable ") : "'" + who + "' ") +
          "is not bindable; only a variable whose type-denoter says "
          "'bindable' can be bound to something outside the program");
}

bool Sema::designatorBindable(const Expr *ce) const {
  Expr *e = const_cast<Expr *>(ce);
  if (!e)
    return false;
  if (auto *v = as<VarRef>(e)) {
    // A name bound by a `with` is a field of the record the with opened, so it
    // answers for itself exactly as a written field selection does.
    if (v->withField)
      return v->withField->isBindable;
    return v->sym && v->sym->isBindable;
  }
  if (auto *f = as<FieldExpr>(e)) {
    // §6.11.3's qualified name denotes one symbol and has no base to select
    // from, so it answers as an entire-variable does.
    if (f->qualified)
      return f->qualified->isBindable;
    return f->resolved && f->resolved->isBindable;
  }
  if (auto *i = as<IndexExpr>(e))
    return i->base->type && i->base->type->elemBindable;
  if (as<DerefExpr>(e))
    return true;
  return false;
}

Symbol *Sema::baseSymbol(Expr *e) const {
  if (auto *v = as<VarRef>(e))
    return v->sym;
  if (auto *i = as<IndexExpr>(e))
    return baseSymbol(i->base.get());
  // §6.5.6: "A reference or an access to a substring of a variable shall
  // constitute a reference or access, respectively, to the variable." So a
  // substring stays inside the variable exactly as a subscript does, and a
  // protected string cannot be written through one.
  if (auto *sub = as<SubstringExpr>(e))
    return baseSymbol(sub->base.get());
  if (auto *f = as<FieldExpr>(e))
    return f->qualified ? f->qualified : baseSymbol(f->base.get());
  return nullptr;
}

/// The entire-variable a designator selects from. `baseSymbol` makes the same
/// walk and answers with the symbol; this answers with the node, which is what
/// a diagnostic needs when the symbol is a hidden one.
static Expr *rootDesignator(Expr *e) {
  if (auto *i = as<IndexExpr>(e))
    return rootDesignator(i->base.get());
  if (auto *sub = as<SubstringExpr>(e))
    return rootDesignator(sub->base.get());
  if (auto *f = as<FieldExpr>(e))
    return f->qualified ? e : rootDesignator(f->base.get());
  return e;
}

/// ISO/IEC 10206:1991 §6.5.1: "No statement shall threaten a variable-access
/// closest-containing a protected variable-identifier." §6.9.4 lists what
/// threatens one, and every entry on that list is a place this compiler
/// already had to decide the argument was a *variable* — so each call sits
/// beside an `isDesignator` test rather than in a walk of its own.
///
/// "Closest-containing" is the walk `baseSymbol` already makes: a subscript
/// and a field selection stay inside the same variable, and a dereference
/// leaves it. Nothing is lost there, because §6.4.1 makes a pointer type
/// unprotectable and so a protected parameter can never be one.
/// Is this the control variable of a for statement whose body we are inside?
/// Keyed on the symbol and never on the spelling: a procedure's own local `i`
/// is not the `i` an enclosing block loops over, and the BSI suite has twenty
/// programs that differ in exactly that way (ADR-0089).
bool Sema::activeControl(Symbol *sym) const {
  for (Symbol *s : forControls_)
    if (s == sym)
      return true;
  return false;
}

/// Does `inner` lie in the procedure-and-function-declaration-part of `outer`,
/// at any depth? §6.8.3.9 reaches through the whole of that part, a block in
/// it containing blocks of its own.
static bool nestedIn(Symbol *inner, Symbol *outer) {
  for (Symbol *p = inner; p; p = p->owner)
    if (p == outer)
      return true;
  return false;
}

// §6.9.4's list has ten entries and two consumers, and they do not need the
// same thing. §6.7.2 asks only *whether* a variable was threatened; §6.7.3.1
// and §6.8.3.9 ask whether this particular threat is allowed. For e)'s `new`
// the second question answers itself — the argument is a pointer, so it is
// never protectable under §6.4.1 and never a control-variable — so that entry
// wants the recording without the refusal, and calling checkNotThreatened
// there would add a diagnostic no program can reach. Every other entry calls
// checkNotThreatened, which calls this first.
void Sema::recordThreat(Expr *e) {
  Symbol *s = baseSymbol(e);

  // Unconditional: what is recorded is that the variable was threatened, not
  // whether the threat was allowed. §6.7.2 is the one rule that asks
  // (ADR-0134).
  if (s)
    s->wasThreatened = true;

  // §6.8.3.9 forbids the declaration part of the block containing a
  // for-statement to threaten its control-variable, and those bodies are
  // walked first — so a threat made from a nested block is remembered here and
  // the for-statement asks about it afterwards. The first one is kept: naming
  // one line is what the message can do, and a later one says no more. A
  // threat from the containing block's own statements is deliberately not
  // recorded, that block being neither the for-statement nor its declaration
  // part.
  if (s && s->kind == SymKind::Var && s->threatLine == 0 && current_ &&
      current_ != s->owner && nestedIn(current_, s->owner)) {
    s->threatLine = e->line;
    s->threatCol = e->col;
  }
}

void Sema::checkNotThreatened(Expr *e, const std::string &what) {
  recordThreat(e);
  Symbol *s = baseSymbol(e);

  // §6.8.3.9: "Neither a for-statement nor any procedure-and-function-
  // declaration-part ... shall contain a statement threatening the variable",
  // where §6.9.4's list of threats is the one §6.5.1 already walks for a
  // protected parameter. So this function gained a second reason to answer
  // yes, and its call sites needed nothing (ADR-0089).
  if (s && !s->isProtected && activeControl(s)) {
    diags_.error(e->line, e->col,
                 "'" + s->name +
                     "' is the control variable of a for statement, so " +
                     what);
    return;
  }
  if (!s || !s->isProtected)
    return;
  // A `with` binding is hidden and its name is a frame slot's, not the
  // program's — so naming it would name something the source never wrote.
  // The rule is the same one either way; only the wording differs.
  // §6.7.3.1 protects a formal parameter and §6.11.2 a constituent of an
  // interface, and §6.5.1's rule is the same for both — but the noun is not,
  // and an imported variable was never anybody's parameter.
  const char *noun =
      s->kind == SymKind::Var ? "protected variable" : "protected parameter";
  const VarRef *v = as<VarRef>(rootDesignator(e));
  std::string who = v && v->withField
                        ? std::string("the record of an enclosing with "
                                      "statement is a ") + noun
                        : "'" + s->name + "' is a " + noun;
  diags_.error(e->line, e->col, who + ", so " + what);
}

// ------------------------------------------------------------------- driver

/// ISO 7185 §6.10's `input` and `output`, and ISO/IEC 10206:1991 §6.11.4.2's.
/// There is one of each in a program however many blocks reach it, so it is
/// created once and lives in the *program's* frame — which a module can
/// address because a level-0 frame is a global (ADR-0053), and could not
/// otherwise, since a module's static chain says nothing about the program.
Symbol *Sema::ensureStdFile(bool input) {
  // §6.11.4.2's accessibility is per block, so whichever block asked is the
  // one that gets it.
  Symbol *root = curModule_ ? curModule_ : program_;
  (input ? root->stdInputOk : root->stdOutputOk) = true;
  Symbol *&slot = input ? stdInput_ : stdOutput_;
  if (slot)
    return slot;
  slot = addHiddenVar(input ? "input" : "output", SymKind::Var, ty::Text(),
                      program_);
  slot->fileBinding =
      input ? FileBinding::StandardInput : FileBinding::StandardOutput;
  // §6.13: in a component with no main-program-declaration there is no
  // program frame for the file to sit in — the component that *has* the
  // main-program-declaration owns the storage, and this one reaches it by
  // name. The name is fixed rather than derived from the program's, because
  // the two translations have no way to agree on anything else: §6.10 and
  // §6.11.4.2 make these files required, so there is exactly one of each in
  // a program however it was divided into components.
  // ISO 7185 has no modules, so nothing there can reach these from outside the
  // main-program-block and the name would be an export with no importer.
  if (std_ == Std::Extended) {
    slot->linkName = input ? "pas.input" : "pas.output";
    slot->storageElsewhere = !prog_->block;
  }
  return slot;
}

/// §6.11.4.2's two required interfaces. Each has one constituent, and the
/// constituent *is* the required text file — so importing `StandardOutput`
/// and listing `output` as a program parameter reach the same variable, which
/// is what makes them alternatives rather than two outputs.
void Sema::installRequiredInterfaces() {
  if (std_ != Std::Extended)
    return;
  Interface in;
  in.name = "standardinput";
  in.items.push_back({"input", nullptr, false});
  interfaces_["standardinput"] = in;
  Interface out;
  out.name = "standardoutput";
  out.items.push_back({"output", nullptr, false});
  interfaces_["standardoutput"] = out;
}

void Sema::run(Program &prog) {
  pushScope(); // the predefined identifiers live in their own outermost scope
  installPredefined();
  installRequiredInterfaces();

  program_ = newSymbol();
  program_->name = prog.name;
  program_->kind = SymKind::Proc;
  program_->level = 0;
  program_->defined = true;
  current_ = program_;
  prog_ = &prog;

  // §6.13's program-components, in the order they were written. A module
  // written *after* the main-program-declaration is legal and supplies
  // nothing, because nothing before it can name an interface it exports.
  for (size_t i = 0; i < prog.modules.size() && i < prog.mainIndex; ++i)
    checkModule(*prog.modules[i]);

  if (!prog.block) {
    // §6.13: this component carries no main-program-declaration, so there is
    // no main-program-block to check and no program parameter list to bind.
    // The modules before and after where it would have stood are one sequence
    // here, and `mainIndex` is past the end of it.
    for (size_t i = prog.mainIndex; i < prog.modules.size(); ++i)
      checkModule(*prog.modules[i]);
    checkPendingImplementations();
    computeActiveModules();
    checkMutualSupply();
    popScope();
    return;
  }

  pushScope();
  // `input` and `output` are declared by the program header rather than by the
  // block, so they exist before the declarations are seen. Declaring them only
  // when they are listed is what makes using `write` without `output` in the
  // header the error ISO 7185 §6.10 says it is.
  // A module may already have created the file — there is one `output` in a
  // program however many blocks reach it — so what is asked here is whether
  // *this* block has the name, not whether the file exists.
  for (DeclName &p : prog.params) {
    if (p.name != "input" && p.name != "output")
      continue;
    if (!scopes_.back().count(p.name))
      bindName(p.name, ensureStdFile(p.name == "input"), p.line, p.col);
  }
  checkBlock(*prog.block, program_);
  popScope();

  for (size_t i = prog.mainIndex; i < prog.modules.size(); ++i)
    checkModule(*prog.modules[i]);

  checkPendingImplementations();
  computeActiveModules();
  checkMutualSupply();
  popScope();
}

/// §6.2.2.13: "A module A shall be designated as supplying a ... block, B,
/// either if B contains an applied occurrence of an interface-identifier having
/// a defining occurrence contained by the module-heading of A, or if A supplies
/// a module that supplies B." So this is the transitive closure of the
/// interfaces `block` imports, and every module in it supplies `block`.
std::vector<Symbol *> Sema::suppliersOf(Symbol *block) const {
  std::vector<Symbol *> stack = block->importedFrom, reached;
  while (!stack.empty()) {
    Symbol *m = stack.back();
    stack.pop_back();
    bool seen = false;
    for (Symbol *r : reached)
      if (r == m)
        seen = true;
    if (seen)
      continue;
    reached.push_back(m);
    for (Symbol *s : m->importedFrom)
      stack.push_back(s);
  }
  return reached;
}

/// §6.2.3.6 activates the main-program-block and "each module supplying" it. A
/// module nothing reaches is therefore never activated — which matters, because
/// its initialization-part could write to output.
void Sema::computeActiveModules() {
  std::vector<Symbol *> reached = suppliersOf(program_);
  // Written order, not discovery order: it is the one §6.2.2.9 guarantees is
  // consistent with "a supplier commences first".
  for (Symbol *m : moduleOrder_)
    for (Symbol *r : reached)
      if (r == m)
        active_.push_back(m);
}

/// §6.11.1: "For any two distinct modules A and B such that A supplies B and B
/// supplies A, neither the module-block of A nor the module-block of B shall
/// contain an initialization-part; neither module-block shall contain a
/// finalization-part; and an expression contained by the module-heading of
/// either A or B shall be nonvarying."
///
/// Mutual supply is expressible at all only because a module may be *split*:
/// A's heading exports what B imports, and A's block — a later
/// program-component — imports what B exports. NOTE 2 describes exactly that
/// shape, and it is the one case §6.2.3.6 leaves no order for, which is why
/// the standard takes the ordered parts away rather than picking one.
///
/// The clause about nonvarying expressions needs nothing here: every
/// expression this compiler admits in a module-heading is already required to
/// be a constant.
void Sema::checkMutualSupply() {
  std::map<Symbol *, std::vector<Symbol *>> reach;
  for (Symbol *m : moduleOrder_)
    reach[m] = suppliersOf(m);
  auto has = [](const std::vector<Symbol *> &v, Symbol *s) {
    for (Symbol *e : v)
      if (e == s)
        return true;
    return false;
  };
  for (auto &entry : modules_) {
    ModuleInfo &info = entry.second;
    ModuleDecl *decl = info.blockDecl;
    if (!decl || (!decl->init && !decl->fini))
      continue;
    for (Symbol *other : moduleOrder_) {
      if (other == info.sym)
        continue;
      if (!has(reach[info.sym], other) || !has(reach[other], info.sym))
        continue;
      Stmt *at = decl->init ? decl->init.get() : decl->fini.get();
      diags_.error(at->line, at->col,
                   "modules '" + info.sym->name + "' and '" + other->name +
                       "' supply each other, so neither may have a 'to begin "
                       "do' or a 'to end do' part");
      break;
    }
  }
}

/// §6.11.1: a module-heading is a promise that a module-block will be written.
/// The one thing that discharges it without a block in this translation is
/// §6.13 — the block is a program-component that was accepted separately, and
/// asking where it is would be asking about another translation.
void Sema::checkPendingImplementations() {
  for (auto &entry : modules_) {
    ModuleInfo &info = entry.second;
    if (!info.headingSeen || info.blockSeen)
      continue;
    if (info.sym && info.sym->compiledElsewhere)
      continue;
    diags_.error(info.line, info.col,
                 "module '" + info.sym->name +
                     "' has an interface but no implementation");
  }
}

/// §6.11.2's export-part. The interface it names is a region of its own, so
/// building it adds nothing to the module's scope: an exported name stays
/// exactly as visible inside the module as it was, and becomes reachable
/// elsewhere only through an import-specification.
void Sema::checkExports(ModuleDecl &m, Symbol *module) {
  for (const ExportPart &part : m.exports) {
    if (interfaces_.count(part.name)) {
      diags_.error(part.line, part.col,
                   "interface '" + part.name + "' is already exported");
      continue;
    }
    Interface iface;
    iface.name = part.name;
    iface.module = module;
    for (const ExportItem &item : part.items)
      addExportItem(iface, item);
    nameForLinkage(iface);
    interfaces_[part.name] = std::move(iface);
  }
}

/// §6.13's separately accepted components have to agree on a symbol without
/// exchanging anything, so a linkage name is a function of the *module-heading
/// alone* — the interface's name and the constituent's spelling, both of which
/// every translation that imports the interface has read. Nothing else about
/// the module is available to both ends: the frame layout is decided by the
/// block, and the block is the half a separate translation does not have.
///
/// A constituent exported through two interfaces keeps the first name, which
/// is the same first for every translation because the export-parts are read
/// in written order.
void Sema::nameForLinkage(Interface &iface) {
  for (Constituent &c : iface.items) {
    if (!c.sym || !c.sym->linkName.empty())
      continue;
    if (c.sym->isVariable())
      c.sym->linkName = "v." + iface.name + "." + c.name;
    else if (c.sym->isCallable())
      c.sym->linkName = "p." + iface.name + "." + c.name;
    else
      continue;
    c.sym->storageElsewhere = iface.module && iface.module->compiledElsewhere;
  }
}

void Sema::addExportItem(Interface &iface, const ExportItem &item) {
  auto alreadyThere = [&](const std::string &spelling) {
    for (const Constituent &c : iface.items)
      if (c.name == spelling)
        return true;
    return false;
  };

  if (!item.last.empty()) {
    // An export-range. §6.11.2 NOTE 6: it is shorthand for listing the
    // *principal* identifier of every value in the range — the names the
    // enumerated type was defined with, not the two written here, which serve
    // only to say where the range starts and ends.
    Symbol *lo = lookupName(item.qualifier, item.name, item.line, item.col);
    Symbol *hi =
        lookupName(item.lastQualifier, item.last, item.line, item.col);
    if (!lo || lo->kind != SymKind::Const || !hi || hi->kind != SymKind::Const) {
      diags_.error(item.line, item.col,
                   "an export range is written between two constants");
      return;
    }
    if (!lo->type || !lo->type->isEnum() || lo->type->base() != hi->type->base()) {
      diags_.error(item.line, item.col,
                   "an export range runs between two values of one enumerated "
                   "type");
      return;
    }
    if (lo->intVal > hi->intVal) {
      diags_.error(item.line, item.col,
                   "the first constant of an export range comes after the "
                   "last");
      return;
    }
    Type *base = lo->type->base();
    for (long long v = lo->intVal; v <= hi->intVal; ++v) {
      const std::string &spelling = base->enumNames[size_t(v)];
      Symbol *s = lookup(spelling);
      if (!s || s->kind != SymKind::Const || s->intVal != v ||
          s->type->base() != base) {
        // §6.11.2 a): the range must be within the scope of a defining-point
        // of the value's principal identifier. Redeclaring the name in the
        // module is what takes it away.
        diags_.error(item.line, item.col,
                     "'" + spelling + "' does not name the value it names in "
                     "the type, so the export range cannot export it");
        continue;
      }
      if (!alreadyThere(spelling))
        iface.items.push_back({spelling, s, false});
    }
    return;
  }

  Symbol *s = lookupName(item.qualifier, item.name, item.line, item.col);
  if (!s) {
    // A qualified name that missed has already been reported by name.
    if (item.qualifier.empty())
      diags_.error(item.line, item.col,
                   "'" + item.name + "' is not declared, so it cannot be "
                   "exported");
    return;
  }
  if (s->kind == SymKind::Interface) {
    diags_.error(item.line, item.col,
                 "'" + item.name +
                     "' names an interface, and an interface is not a "
                     "constituent of one");
    return;
  }
  if (item.isProtected) {
    // §6.11.2: `protected` qualifies a variable-name, and the type possessed
    // by a protected constituent-identifier shall be protectable (§6.4.1).
    if (!s->isVariable()) {
      diags_.error(item.line, item.col,
                   "only a variable can be exported protected, and '" +
                       item.name + "' is not one");
      return;
    }
    if (s->type && !s->type->protectable()) {
      diags_.error(item.line, item.col,
                   "a protected variable cannot be " + s->type->name() +
                       ", because a file or a pointer in it would let the "
                       "importer change what it reaches");
      return;
    }
  }
  const std::string &spelling = item.renamed.empty() ? item.name : item.renamed;
  if (alreadyThere(spelling)) {
    diags_.error(item.line, item.col,
                 "interface '" + iface.name + "' already has a constituent "
                 "named '" + spelling + "'");
    return;
  }
  // A variable that was already protected — an imported protected constituent
  // re-exported — stays protected however this clause is written.
  iface.items.push_back({spelling, s, item.isProtected || s->isProtected});
}

/// §6.11.3's import-specification. The three modifiers decide only *which*
/// constituents arrive and under what spelling; what arrives is the module's
/// own symbol, so an imported procedure is the procedure and an imported
/// variable is the variable.
void Sema::checkImports(const std::vector<ImportSpec> &specs) {
  for (const ImportSpec &spec : specs) {
    auto found = interfaces_.find(spec.interfaceName);
    if (found == interfaces_.end()) {
      diags_.error(spec.line, spec.col,
                   "no interface named '" + spec.interfaceName +
                       "' has been exported");
      continue;
    }
    Interface &iface = found->second;
    // §6.11.4.2's two required interfaces have no module and one required
    // constituent each, and the constituent *is* the text file — so importing
    // one is what makes it implicitly accessible here.
    if (iface.name == "standardinput")
      iface.items[0].sym = ensureStdFile(true);
    else if (iface.name == "standardoutput")
      iface.items[0].sym = ensureStdFile(false);

    // §6.2.2.13 makes A supply B when B *contains* an applied occurrence of an
    // interface-identifier of A, and §6.2.1 puts an import-part at the head of
    // every block — so an import inside a procedure is contained by the
    // module-block or main-program-block around it, and it is that block the
    // supply is recorded against.
    //
    // Which is why this takes no `owner`, though all three call sites have one
    // to hand and passed it for a long time. Recording the supply against the
    // enclosing *procedure* puts it where §6.2.3.6's activation set never
    // looks: the module then compiles, resolves and is never commenced, so its
    // initialization-part does not run and its variables are read at zero. The
    // parameter went unread rather than wrong, which is the same defect one
    // step earlier — a caller cannot tell those apart.
    Symbol *supplied = curModule_ ? curModule_ : program_;
    if (iface.module && iface.module != supplied) {
      bool known = false;
      for (Symbol *s : supplied->importedFrom)
        if (s == iface.module)
          known = true;
      if (!known)
        supplied->importedFrom.push_back(iface.module);
    }

    Symbol *ifaceSym = newSymbol();
    ifaceSym->name = spec.interfaceName;
    ifaceSym->kind = SymKind::Interface;

    // Which constituents are named, and under what spelling. `only` makes the
    // list exhaustive; without it the list only renames, and everything else
    // arrives under its own name (§6.11.3 d).
    std::vector<bool> named(iface.items.size(), false);
    std::vector<std::pair<const Constituent *, std::string>> arriving;
    for (const ImportItem &item : spec.items) {
      size_t k = iface.items.size();
      for (size_t i = 0; i < iface.items.size(); ++i)
        if (iface.items[i].name == item.name)
          k = i;
      if (k == iface.items.size()) {
        diags_.error(item.line, item.col,
                     "interface '" + spec.interfaceName +
                         "' has no constituent named '" + item.name + "'");
        continue;
      }
      named[k] = true;
      arriving.push_back({&iface.items[k],
                          item.renamed.empty() ? item.name : item.renamed});
    }
    if (!spec.only)
      for (size_t i = 0; i < iface.items.size(); ++i)
        if (!named[i])
          arriving.push_back({&iface.items[i], iface.items[i].name});

    for (auto &entry : arriving) {
      Symbol *s =
          importedSymbol(*entry.first, entry.second, spec.line, spec.col);
      ifaceSym->constituents.push_back({entry.second, s, entry.first->isProtected});
      // §6.11.3's last paragraph: with an access-qualifier the defining-point
      // is for the import-specification alone, so the name is reachable only
      // as `i.x` and never bare.
      if (!spec.qualified)
        bindName(entry.second, s, spec.line, spec.col);
    }
    // The interface-identifier itself is introduced whether or not the import
    // was qualified, so `i.x` is always available.
    bindName(spec.interfaceName, ifaceSym, spec.line, spec.col);
  }
}

Symbol *Sema::importedSymbol(const Constituent &c, const std::string &spelling,
                             int line, int col) {
  if (!c.sym) {
    diags_.error(line, col, "'" + spelling + "' cannot be imported");
    return nullptr;
  }
  // A variable arrives as a *copy* of the symbol: the spelling and the
  // protection belong to the import and not to the module's own declaration,
  // and the copy names the same storage because owner, level and frame index
  // are what an address is computed from. Everything else — a constant, a
  // type, a schema, a procedure, a function — is shared, because nothing about
  // it can differ between the two ends.
  if (!c.sym->isVariable() || (spelling == c.sym->name && !c.isProtected))
    return c.sym;
  Symbol *alias = newSymbol();
  *alias = *c.sym;
  alias->name = spelling;
  alias->isProtected = c.isProtected || c.sym->isProtected;
  return alias;
}

/// The same lookup with nothing reported. Used where a name is being *probed*
/// rather than resolved, so that the one place that resolves it says whatever
/// has to be said exactly once.
Symbol *Sema::lookupQuiet(const std::string &qualifier,
                          const std::string &name) {
  if (qualifier.empty())
    return lookup(name);
  Symbol *iface = lookup(qualifier);
  if (!iface || iface->kind != SymKind::Interface)
    return nullptr;
  for (const Constituent &c : iface->constituents)
    if (c.name == name)
      return c.sym;
  return nullptr;
}

bool Sema::isInterfaceName(const std::string &name) {
  Symbol *s = lookup(name);
  return s && s->kind == SymKind::Interface;
}

/// A name that may be qualified. With no qualifier this is an ordinary lookup;
/// with one it is §6.11.3's `i.x`, which reaches only what that
/// import-specification brought and never what the module it came from also
/// declares.
Symbol *Sema::lookupName(const std::string &qualifier, const std::string &name,
                         int line, int col) {
  if (qualifier.empty())
    return lookup(name);
  Symbol *iface = lookup(qualifier);
  if (!iface) {
    diags_.error(line, col, "'" + qualifier + "' is not declared");
    return nullptr;
  }
  if (iface->kind != SymKind::Interface) {
    diags_.error(line, col,
                 "'" + qualifier + "' does not name an imported interface");
    return nullptr;
  }
  for (const Constituent &c : iface->constituents)
    if (c.name == name)
      return c.sym;
  diags_.error(line, col,
               "'" + name + "' was not imported through interface '" +
                   qualifier + "'");
  return nullptr;
}

void Sema::checkModule(ModuleDecl &m) {
  ModuleInfo &info = modules_[m.name];
  if (!info.sym) {
    info.sym = newSymbol();
    info.sym->name = m.name;
    info.sym->kind = SymKind::Proc;
    info.sym->isModuleSym = true;
    info.sym->level = 0;
    info.sym->defined = true;
    info.line = m.line;
    info.col = m.col;
    moduleOrder_.push_back(info.sym);
  }
  m.sym = info.sym;
  // §6.13. The flag is set rather than assigned, because a module may arrive
  // as two components and only one of them be the separately accepted one:
  // once any component of it is another translation's, this translation emits
  // none of it.
  if (m.compiledElsewhere)
    info.sym->compiledElsewhere = true;

  if (m.hasHeading) {
    if (info.headingSeen) {
      diags_.error(m.line, m.col,
                   "module '" + m.name + "' already has a heading");
      return;
    }
    info.headingSeen = true;
    info.headingDecl = &m;
    checkModuleHeading(m, info);
  }
  if (m.hasBlock) {
    if (!info.headingSeen) {
      diags_.error(m.line, m.col,
                   "there is no interface for module '" + m.name +
                       "' to implement");
      return;
    }
    if (info.blockSeen) {
      diags_.error(m.line, m.col,
                   "module '" + m.name + "' already has an implementation");
      return;
    }
    info.blockSeen = true;
    info.blockDecl = &m;
    checkModuleBlock(m, info);
  }
}

void Sema::checkModuleHeading(ModuleDecl &m, ModuleInfo &info) {
  Symbol *saveCurrent = current_;
  Symbol *saveModule = curModule_;
  current_ = info.sym;
  curModule_ = info.sym;
  pushScope();

  // §6.11.1: a module-parameter named `input` or `output` denotes the required
  // text file, and is what makes it implicitly accessible in the module
  // (§6.11.4.2 d). Any other spelling must be a variable the module declares,
  // and this compiler binds it to nothing — NOTE 6 permits that outright.
  for (DeclName &p : m.params)
    if (p.name == "input" || p.name == "output")
      bindName(p.name, ensureStdFile(p.name == "input"), p.line, p.col);

  checkImports(m.heading->imports);
  checkDeclarations(*m.heading, info.sym);
  for (auto &proc : m.heading->procs)
    declareProcHeading(*proc, info.sym);

  // §6.11.1: a module-parameter that is neither `input` nor `output` "either
  // shall be local to the module or shall be an imported variable-identifier
  // that is a module-parameter". Its binding to anything outside the program
  // is implementation-defined, and NOTE 6 says one need not be bound at all —
  // which is what this compiler does with it.
  for (DeclName &p : m.params) {
    if (p.name == "input" || p.name == "output")
      continue;
    Symbol *s = lookup(p.name);
    if (!s || !s->isVariable())
      diags_.error(p.line, p.col,
                   "the module parameter '" + p.name +
                       "' is not declared as a variable in this module");
    else
      // §6.5.1 names the module-parameter in the same breath as the
      // program-parameter, so it is bindable for the same reason — even
      // though this compiler binds it to nothing (NOTE 6).
      s->isBindable = true;
  }

  // The export parts are resolved last although they are written first: an
  // export-clause names something the module declares, and §6.11.2's example 2
  // exports a type defined below the `export` that names it.
  checkExports(m, info.sym);

  // Every name the heading defined is also a defining-point of the block
  // (§6.2.2.12), and the block may be a separate program-component — so the
  // scope is kept rather than discarded.
  info.scope = scopes_.back();
  popScope();
  current_ = saveCurrent;
  curModule_ = saveModule;
}

void Sema::checkModuleBlock(ModuleDecl &m, ModuleInfo &info) {
  Symbol *saveCurrent = current_;
  Symbol *saveModule = curModule_;
  current_ = info.sym;
  curModule_ = info.sym;
  scopes_.push_back(info.scope);

  checkImports(m.block->imports);
  checkDeclarations(*m.block, info.sym);

  for (auto &proc : m.block->procs) {
    declareProcHeading(*proc, info.sym);
    if (proc->body)
      checkProcBody(*proc);
  }
  for (auto &proc : m.block->procs)
    if (proc->sym && !proc->sym->defined)
      diags_.error(proc->line, proc->col,
                   "'" + proc->name +
                       "' was declared forward but never given a body");
  // A heading that promised a body and never got one. The heading may be a
  // different program-component from this block, so it is reached through the
  // module's record rather than through `m`. The message says `heading` rather
  // than `forward`, because nothing here was written forward.
  if (info.headingDecl)
    for (auto &proc : info.headingDecl->heading->procs)
      if (proc->sym && !proc->sym->defined)
        diags_.error(proc->line, proc->col,
                     "'" + proc->name +
                         "' is declared in the heading of module '" + m.name +
                         "' but has no body in its implementation");

  // §6.11.1 gives a module-block no label-declaration-part, so the scope these
  // two statements are checked against is deliberately empty: a `goto` in an
  // initialization-part has nowhere in the module to land, and says so.
  // `resolveGotos` pops both, as it does for every block.
  std::vector<PathEntry> outerPath;
  outerPath.swap(stmtPath_);
  labelScopes_.emplace_back();
  gotoScopes_.emplace_back();
  if (m.init)
    checkStmt(m.init.get());
  if (m.fini)
    checkStmt(m.fini.get());
  resolveGotos();
  stmtPath_.swap(outerPath);

  scopes_.pop_back();
  current_ = saveCurrent;
  curModule_ = saveModule;
}

void Sema::bindProgramParameters(bool report) {
  if (!prog_)
    return;
  // §6.10: "The identifiers contained by the program-parameter-list shall be
  // distinct." Each is a defining-point for the program-block, so a repeat is
  // a redeclaration — but they are *looked up* rather than declared here, the
  // variable-declaration-part having already made them, so `declare`'s own
  // check never sees them. Reported once per repeat, against the later one,
  // which is the occurrence a reader would delete.
  for (size_t i = 0; report && i < prog_->params.size(); ++i)
    for (size_t j = 0; j < i; ++j)
      if (prog_->params[j].name == prog_->params[i].name) {
        diags_.error(prog_->params[i].line, prog_->params[i].col,
                     "the program parameter '" + prog_->params[i].name +
                         "' is listed more than once");
        break;
      }
  // argv[0] is the program itself, so the first file parameter is argv[1].
  int argIndex = 1;
  for (DeclName &p : prog_->params) {
    // The pre-pass asks `lookupRaw`: a name it does not find yet may still be
    // declared further down, and recording an applied occurrence for it would
    // make §6.2.2.9 refuse that declaration.
    Symbol *s = report ? lookup(p.name) : lookupRaw(p.name);
    if (!s || !s->isVariable()) {
      if (report)
        diags_.error(p.line, p.col,
                     "the program parameter '" + p.name +
                         "' is not declared as a variable in the program block");
      continue;
    }
    // §6.5.1: "The variable-identifier shall possess the bindability denoted
    // by the type-denoter, unless the variable-identifier is a
    // program-parameter or a module-parameter, in which case the
    // variable-identifier shall possess the bindability that is bindable."
    // So the word `bindable` in the declaration is not how a program-parameter
    // becomes one — being a program-parameter is. Without this, §6.7.6.8's own
    // NOTE 2 use of `binding` cannot be written: the whole point of it there is
    // to inspect a binding the program did not make.
    if (std_ == Std::Extended)
      s->isBindable = true;
    if (s == stdInput_ || s == stdOutput_)
      continue; // bound by the header itself
    // Neither standard restricts a program-parameter to a file. ISO 7185
    // §6.10 makes the binding of one that does not possess a file-type
    // implementation-*dependent*, reserving implementation-defined for the
    // file case; ISO/IEC 10206:1991 §6.12 drops the distinction and makes
    // every program-parameter's binding implementation-defined. The binding
    // chosen here is to no external entity — the variable is an ordinary
    // variable of the program-block, undefined at activation — which
    // §6.12's NOTE 2 ("not necessarily bound when the program is activated")
    // is what makes a permitted answer rather than an omission. It therefore
    // consumes no command-line argument either, so writing one beside the
    // file parameters does not move their argument positions.
    if (!s->type || !s->type->isFile())
      continue;
    s->fileBinding = FileBinding::Argument;
    s->fileArg = argIndex++;
  }
}

/// The file a `read` or `write` acts on when it named none. The reference is
/// synthesised rather than left for codegen to work out: ADR-0008 has codegen
/// never resolving a name, so the defaulted file arrives as an ordinary
/// resolved VarRef like any other.
ExprPtr Sema::standardFileRef(bool input, int line, int col) {
  Symbol *root = curModule_ ? curModule_ : program_;
  Symbol *file =
      (input ? root->stdInputOk : root->stdOutputOk)
          ? (input ? stdInput_ : stdOutput_)
          : nullptr;
  const char *name = input ? "input" : "output";
  if (!file) {
    // §6.11.4.2 gives Extended Pascal three more ways to make the file
    // implicitly accessible than §6.10's one, so the message lists them —
    // otherwise it names the only remedy a module cannot use.
    diags_.error(line, col,
                 std::string("'") + name + "' must be listed as a program " +
                     (std_ == Std::Extended
                          ? "parameter or a module parameter, or imported "
                            "through " +
                                std::string(input ? "StandardInput"
                                                  : "StandardOutput") +
                                ", to use it"
                          : std::string("parameter to use it")));
    return nullptr;
  }
  auto ref = std::make_unique<VarRef>();
  ref->line = line;
  ref->col = col;
  ref->name = name;
  ref->sym = file;
  ref->type = file->type;
  return ref;
}

/// A block is the declaration part followed by the statement part, and is the
/// same shape for the program and for every procedure. The caller has already
/// pushed the scope the declarations go into.
/// The label declaration part. Every label a block declares must be labelling
/// a statement of that same block by the time it is finished — ISO 7185 §6.1.6
/// declares them, §6.8.1 requires each to be used, and a label declared and
/// never placed is the mistake that would otherwise leave a `goto` with
/// nowhere to land and no message about it.
void Sema::checkLabelPart(Block &block, Symbol *owner) {
  labelScopes_.emplace_back();
  gotoScopes_.emplace_back();
  for (const LabelDecl &d : block.labels) {
    bool duplicate = false;
    for (const LabelInfo &seen : labelScopes_.back())
      if (seen.number == d.number)
        duplicate = true;
    if (duplicate) {
      diags_.error(d.line, d.col,
                   "label " + std::to_string(d.number) +
                       " is declared twice in this block");
      continue;
    }
    LabelInfo info;
    info.number = d.number;
    info.id = nextLabelId_++;
    info.line = d.line;
    info.col = d.col;
    info.owner = owner;
    labelScopes_.back().push_back(info);
  }
}

/// A label is legal on a statement only where it was declared, so this is
/// checked against the innermost block's declarations alone.
void Sema::checkLabeled(LabeledStmt *l) {
  LabelInfo *found = nullptr;
  if (!labelScopes_.empty())
    for (LabelInfo &info : labelScopes_.back())
      if (info.number == l->label)
        found = &info;

  if (!found) {
    diags_.error(l->line, l->col,
                 "label " + std::to_string(l->label) +
                     " is not declared in this block");
  } else if (found->defined) {
    diags_.error(l->line, l->col,
                 "label " + std::to_string(l->label) +
                     " already labels a statement at line " +
                     std::to_string(found->defLine));
  } else {
    found->defined = true;
    found->defLine = l->line;
    found->defCol = l->col;
    found->path = stmtPath_;
    // §6.8.1 a) admits a goto the labelled statement *contains*, which the
    // path cannot answer: it says what contains the label, not what the label
    // contains.
    found->node = l;
    l->id = found->id;
  }

  stmtPath_.push_back({l, false});
  checkStmt(l->body.get());
  stmtPath_.pop_back();
}

/// The target is not looked for here: a label may be declared before the
/// statement it labels is written, so a forward jump can only be resolved once
/// the whole block has been walked.
void Sema::checkGoto(GotoStmt *g) {
  if (gotoScopes_.empty())
    return;
  gotoScopes_.back().push_back({g, stmtPath_});
}

/// ISO 7185 §6.8.1 restricts where a goto may land, and the restriction is
/// what makes the lowering possible as much as what the standard says: a jump
/// *into* a structured statement would arrive past the loop's initialisation
/// or the `with` binding it depends on.
///
///   - to a label of the same block, the statements containing the label must
///     all contain the goto — so a jump outward or sideways within one level
///     is allowed and a jump inward is not;
///   - to a label of an enclosing block, the label must be at the top level of
///     that block's statement part, which is the only place a frame that is
///     still alive can be re-entered.
void Sema::resolveGotos() {
  for (const PendingGoto &pending : gotoScopes_.back()) {
    GotoStmt *g = pending.node;
    LabelInfo *found = nullptr;
    size_t depth = labelScopes_.size();
    while (depth > 0 && !found) {
      --depth;
      for (LabelInfo &info : labelScopes_[depth])
        if (info.number == g->label)
          found = &info;
    }

    if (!found) {
      diags_.error(g->line, g->col,
                   "label " + std::to_string(g->label) +
                       " is not declared in this block or any enclosing one");
      continue;
    }
    // The label is somewhere outside: hand the goto to the block that declared
    // it, whose statements have not been walked yet.
    if (depth + 1 < labelScopes_.size()) {
      PendingGoto moved = pending;
      moved.fromInnerBlock = true;
      gotoScopes_[depth].push_back(moved);
      continue;
    }
    if (!found->defined) {
      diags_.error(g->line, g->col,
                   "label " + std::to_string(g->label) +
                       " is declared but labels no statement");
      continue;
    }

    if (!pending.fromInnerBlock) {
      // §6.8.1 admits a label three ways, and the prefix test alone is only
      // two of them: a) the labelled statement contains the goto; b) the
      // label is a statement of a statement-sequence containing the goto;
      // c) it is a statement of the block's statement-part. Only a
      // compound-statement and a repeat-statement hold a statement-*sequence*
      // — a branch of an if, a loop body, a with body and a case arm are each
      // a single statement — so a label inside one of those is reachable only
      // from within it, which is a). That is what makes DEV190's jump from one
      // branch of an if to a label in the other satisfy none of the three
      // (ADR-0094, ADR-0101).
      bool inside = false;
      for (const PathEntry &p : pending.path)
        inside = inside || p.stmt == found->node;
      bool sameChain = found->path.size() <= pending.path.size();
      for (size_t i = 0; sameChain && i < found->path.size(); ++i)
        sameChain = found->path[i] == pending.path[i];
      bool reachable;
      if (inside)
        reachable = true;
      else if (!sameChain)
        reachable = false;
      else if (found->path.empty())
        reachable = true; // c): the block's statement-part
      else
        reachable = found->path.back().seq;
      if (!reachable) {
        diags_.error(g->line, g->col,
                     sameChain
                         ? "label " + std::to_string(g->label) +
                               " prefixes a statement that is not one of a "
                               "statement-sequence, so only a goto inside that "
                               "statement may reach it"
                         : "label " + std::to_string(g->label) +
                               " is inside a statement this goto is not: a "
                               "goto may leave a structured statement but not "
                               "enter one");
        continue;
      }
    } else if (!found->path.empty()) {
      diags_.error(g->line, g->col,
                   "label " + std::to_string(g->label) + " is in an enclosing "
                   "block, so it must label a statement of that block's "
                   "statement part and not one inside a statement of it");
      continue;
    } else {
      // A legal non-local goto. The *target* block is what has work to do —
      // it carries the jump record and dispatches to the label on arrival —
      // and it learns of it here, from a goto in a block nested inside it
      // that has already been walked (ADR-0032).
      g->nonLocal = true;
      Symbol *target = found->owner;
      bool known = false;
      for (int id : target->nonLocalLabels)
        known = known || id == found->id;
      if (!known)
        target->nonLocalLabels.push_back(found->id);
    }

    g->id = found->id;
    g->owner = found->owner;
  }

  for (const LabelInfo &info : labelScopes_.back())
    if (!info.defined)
      diags_.error(info.line, info.col,
                   "label " + std::to_string(info.number) +
                       " is declared but labels no statement of this block");

  labelScopes_.pop_back();
  gotoScopes_.pop_back();
}

void Sema::checkBlock(Block &block, Symbol *owner) {
  // ISO/IEC 10206:1991 §6.2.1 puts the import-part at the head of every block.
  checkImports(block.imports);
  checkLabelPart(block, owner);
  // The procedures are merged into the walk by source position, so the
  // headings are declared and the bodies checked from inside it.
  checkDeclarations(block, owner, &block.procs);

  for (auto &proc : block.procs)
    if (proc->sym && !proc->sym->defined)
      diags_.error(proc->line, proc->col,
                   "'" + proc->name +
                       "' was declared forward but never given a body");

  // The statement path is per block: a goto in a nested procedure is not
  // inside the enclosing block's statements, whatever they are.
  std::vector<PathEntry> outerPath;
  outerPath.swap(stmtPath_);
  // The statement part *is* the block's outermost statement-sequence, so it is
  // walked without joining the path — a label at the top of it has no
  // containing statement, which is what ISO 7185 §6.8.1 requires of the target
  // of a goto from a nested block. A `begin ... end` written *inside* it is an
  // ordinary statement and does join.
  if (block.body)
    for (auto &sub : block.body->body)
      checkStmt(sub.get());
  stmtPath_.swap(outerPath);
  resolveGotos();
}

/// Whether one written position precedes another. Only ever asked of two
/// declarations of one block, which are all distinct.
static bool earlier(int l1, int c1, int l2, int c2) {
  return l1 != l2 ? l1 < l2 : c1 < c2;
}

/// The constant, type and variable definition parts, **in the order they were
/// written**. ISO 7185 §6.2.1 fixes that order — const, then type, then var —
/// but ISO/IEC 10206:1991 §6.2.1 makes the block a *repetition* of the five
/// parts in any order, and §6.2.2.9 then requires a defining-point to precede
/// every applied occurrence of it. So written order is the only order that
/// works, and it is what `const first = red` after a type part needs, and what
/// a constant naming a type needs — which is every structured constant
/// (ADR-0069).
///
/// The parts are merged by source position rather than recorded in one list at
/// parse time: the AST keeps a vector per part, and the positions reconstruct
/// the interleaving exactly, since one block's declarations are all distinct.
/// Under ISO 7185 there is at most one of each part in the fixed order, so the
/// merge is provably the order this always used.
///
/// The procedure-and-function-declaration-part is merged in the same way, and
/// that is what makes §6.2.2.9 reach a body: every variable used to be declared
/// before any body was checked, so `procedure p; begin writeln(zz) end; var zz:
/// integer` looked well formed. A heading is declared and its body checked
/// where the source puts them, so a variable written after the procedure is not
/// yet declared when the body is walked — the same consequence ADR-0069 already
/// produced for `var v: t` before `type t` (ADR-0100).
///
/// `procs` is null where the caller declares the headings itself: a
/// module-heading has no bodies, so nothing there can observe the interleaving.
///
/// Shared by a block and by both halves of a module, which have the same parts
/// and differ only in what may surround them.
void Sema::checkDeclarations(Block &block, Symbol *owner,
                             std::vector<std::unique_ptr<ProcDecl>> *procs) {
  size_t ci = 0, ti = 0, vi = 0, pi = 0;
  size_t np = procs ? procs->size() : 0;
  // Only the program has parameters to bind.
  bool bound = owner != program_;
  bool inTypes = false;
  // A nested block's declarations are checked from inside this walk, so the
  // flag has to be saved rather than simply cleared on the way out.
  bool savedInTypePart = inTypePart_;
  inTypePart_ = false;
  while (ci < block.consts.size() || ti < block.types.size() ||
         vi < block.vars.size() || pi < np) {
    // Which of the three heads was written first. A variable group is placed
    // by its first name, the only position it has.
    int which = -1, line = 0, col = 0;
    if (ci < block.consts.size()) {
      which = 0;
      line = block.consts[ci].line;
      col = block.consts[ci].col;
    }
    if (ti < block.types.size() &&
        (which < 0 ||
         earlier(block.types[ti].line, block.types[ti].col, line, col))) {
      which = 1;
      line = block.types[ti].line;
      col = block.types[ti].col;
    }
    if (vi < block.vars.size() && !block.vars[vi].names.empty() &&
        (which < 0 || earlier(block.vars[vi].names[0].line,
                              block.vars[vi].names[0].col, line, col))) {
      which = 2;
      line = block.vars[vi].names[0].line;
      col = block.vars[vi].names[0].col;
    }
    if (pi < np && (which < 0 || earlier((*procs)[pi]->line, (*procs)[pi]->col,
                                         line, col)))
      which = 3;

    // §6.4.4's forward-referenced domain is completed at the end of *its*
    // type-definition-part, so a run of type definitions ending is what
    // triggers it — not the end of the block, which may hold several.
    if (which != 1 && inTypes) {
      inTypePart_ = false;
      resolvePendingPointers();
      inTypes = false;
    }
    // A procedure-declaration ends the type-definition-part before it, and its
    // body is checked in a scope of its own — so anything still pending has to
    // be resolved in *this* block's scope now, or the nested block's own drain
    // would look the name up in the wrong one (ADR-0091).
    if (which == 3)
      resolvePendingPointers();
    if (which == 0)
      checkConstDecl(block.consts[ci++], owner);
    else if (which == 1) {
      inTypes = true;
      inTypePart_ = true;
      checkTypeDecl(block.types[ti++], owner);
    } else if (which == 2)
      checkVarDecl(block.vars[vi++], owner);
    else if (which == 3) {
      // §6.10's parameters are bound before the first body is checked: a body
      // may ask `binding(f)` of one, and §6.5.1 confers bindability on the
      // declaration rather than on a position. Only a parameter whose
      // defining-point is already here can be named in the body — that is
      // §6.2.2.9 — so what is declared by now is enough, and the diagnostics
      // wait for the rest.
      if (!bound) {
        if (ci == block.consts.size() && ti == block.types.size() &&
            vi == block.vars.size()) {
          bindProgramParameters(true);
          bound = true;
        } else
          // At *every* procedure-declaration with declarations still to come,
          // not once: a program-parameter written between two procedures is
          // not there to bind when the first is reached, and the body of the
          // second may still ask `binding()` of it. The call is idempotent
          // over the binding — it recomputes the same argument positions from
          // whatever is declared by now — so repeating it costs a walk and
          // settles the parameters that have appeared since.
          bindProgramParameters(false);
      }
      // Headings one at a time, in order, so that a procedure cannot call one
      // declared after it without `forward`.
      ProcDecl &proc = *(*procs)[pi++];
      declareProcHeading(proc, owner);
      if (proc.body)
        checkProcBody(proc);
    } else
      break; // a variable group with no names; the parser makes none
  }
  inTypePart_ = false;
  // §6.4.4's forward reference is completed where its own type-definition-part
  // ends, which is what the run above does. What can still be pending here is
  // a domain written *outside* one — a variable's, or a schema body's — and it
  // has nowhere later to be defined, so draining unconditionally is what
  // reports it. Draining only after a type part carried the list into the next
  // block that happened to have one, where the name was looked up in the wrong
  // scope: a program with no type part at all kept its unknown domain in
  // silence, and a legal self-referential schema in a var part was refused
  // until an unrelated type definition was added after it (ADR-0091).
  resolvePendingPointers();
  inTypePart_ = savedInTypePart;
  // Every declaration of the program-block has been seen now, which is what
  // §6.10's checks need: a parameter may be declared after the procedure that
  // made the pre-pass necessary.
  if (!bound)
    bindProgramParameters(true);
}

void Sema::checkConstDecl(ConstDecl &c, Symbol *owner) {
  checkExpr(c.value.get());
  Symbol value;
  constReported_ = false;
  if (!evalConst(c.value.get(), value)) {
    // The folder says why when it can — an overflow, a `chr` out of range —
    // and this generic message is for when it cannot: the expression was
    // never constant in the first place.
    if (!constReported_)
      diags_.error(c.line, c.col,
                   "the value of constant '" + c.name +
                       "' is not a compile-time constant");
    return;
  }
  Symbol *s = declare(c.name, SymKind::Const, c.line, c.col);
  s->type = value.type;
  s->intVal = value.intVal;
  s->realVal = value.realVal;
  s->charVal = value.charVal;
  s->boolVal = value.boolVal;
  s->constValue = value.constValue;
  // A §6.8.7 constructor needs its storage filled at run time, and the block
  // that *defined* it is the one whose prologue does that. The test is
  // whether this definition is where the node came from: `const b = a` hands
  // on `a`'s node, so `b` shares `a`'s storage and must not fill it a second
  // time (ADR-0069).
  if (s->constValue == c.value.get() && is<StructValueExpr>(s->constValue)) {
    owner->memoryConsts.push_back(s);
    // The hidden frame slot ADR-0061 gives a top-level constructor is not
    // used here — the value is built into the global instead — and a slot
    // nothing writes to would still appear in the frame layout.
    static_cast<StructValueExpr *>(s->constValue)->resultSlot = nullptr;
  }
}

/// One type-definition or schema-definition. A type name is visible to the
/// definitions after it, so each is declared as it is resolved.
/// The frame slot a type-definition's bounds descriptor turns out to need
/// (ADR-0127). It cannot be reserved before the denoter is resolved — most
/// type-definitions have no bound that fails to fold, and a slot claimed for
/// every one of them would move the layout of every frame in every Extended
/// Pascal program — so the symbol is made outside the frame and joins it here,
/// with every discriminant already built against it corrected to the index it
/// turned out to get.
void Sema::claimBoundsSlot(Symbol *hv, Symbol *owner) {
  hv->frameIndex = static_cast<int>(owner->frameVars.size());
  owner->frameVars.push_back(hv);
  for (Symbol *d : hv->discSyms)
    d->frameIndex = hv->frameIndex;
}

void Sema::checkTypeDecl(TypeDecl &t, Symbol *owner) {
  // §6.4.7: a schema-definition declares a schema, not a type. Its body is
  // *not* resolved here — it has no discriminant values yet, and resolving
  // it once would produce the one type every use then shared.
  if (!t.discriminants.empty()) {
    declareSchema(t);
    return;
  }
  // §6.4.7's *first* alternative, `identifier '=' schema-name`. It is the same
  // tokens as a type-definition naming a type, so the symbol decides and not
  // the syntax — the fourth time here, after ADR-0044's variant-selector,
  // ADR-0053's qualified name and ADR-0066's set-value.
  //
  // The clause says the new identifier denotes "the schema denoted by the
  // schema-name", so the two names share one symbol rather than one being a
  // copy of the other: §6.4.8 keys a produced type on (schema, tuple), and a
  // copy would make `vec2(3)` and `vector(3)` two types where the standard has
  // one.
  if (t.type->kind == TEK::Named) {
    Symbol *named = lookupQuiet(t.type->qualifier, t.type->name);
    if (named && named->kind == SymKind::Schema) {
      bindName(t.name, named, t.line, t.col);
      return;
    }
  }
  // ISO/IEC 10206:1991 §6.2.3.8 b) evaluates "each actual-discriminant-part or
  // subrange-bound not contained by a schema-definition and closest-contained
  // by the module-heading of the module, by the module-block of the module, or
  // by the block" at that activation's commencement. A type-definition is
  // contained by the block, so `type t = array [1..m] of integer` and
  // `type t = vec(m)` are as legal there as ADR-0113's variable is — and the
  // difference is who owns the descriptor. A variable's belongs to the
  // variable; a type's belongs to the *block*, because the clause evaluates the
  // bound once however many variables of t the block goes on to declare, and
  // §6.4.1 makes them one type with one extent (ADR-0127).
  //
  // So the offer is made to a hidden frame variable standing for the
  // type-definition rather than to any variable. If every bound folded it is
  // withdrawn and nothing was claimed.
  Type *resolved = nullptr;
  Symbol *hv = nullptr;
  if (std_ == Std::Extended) {
    hv = newSymbol();
    hv->name = "bnd$" + std::to_string(owner->frameVars.size());
    hv->kind = SymKind::Var;
    hv->type = ty::Int();
    hv->level = owner->level;
    hv->owner = owner;
    hv->frameIndex = -1;
    dynBoundsFor_ = hv;
    dynamicVarFor_ = hv;
    resolved = resolveType(*t.type);
    dynBoundsFor_ = nullptr;
    dynamicVarFor_ = nullptr;
    if (hv->discSyms.empty()) {
      hv = nullptr;
    } else {
      hv->type = resolved;
      // A written schema brought its own; a bare bound has none, so the
      // anonymous one ADR-0113 hangs the discriminants on is made here for the
      // same reason and by the same procedure.
      if (!hv->descSchema)
        boundSchemaFor(hv);
      claimBoundsSlot(hv, owner);
      // The type is what a later variable-declaration will have; this is how
      // it finds the descriptor its extent is in.
      resolved->boundsVar = hv;
      // §6.2.3.6 makes a module's activation last as long as the program, so
      // there is no stack for storage sized on entry — the same rule that
      // refuses it to a module's variable (ADR-0041, ADR-0113).
      if (owner->isModuleSym)
        diags_.error(t.line, t.col,
                     "the bounds of a module's type must be constants, "
                     "because a module's activation lasts as long as the "
                     "program");
    }
  } else {
    resolved = resolveType(*t.type);
  }
  Symbol *s = declare(t.name, SymKind::Type, t.line, t.col);
  if (s->type)
    return; // a duplicate: keep the first definition
  s->type = resolved;
  // §6.4.1: a type-name denotes "the type, bindability and initial state"
  // its definition denoted, so the initial state travels with the name and
  // every variable of it is initialised.
  s->initValue = initialStateOf(*t.type);
  s->isBindable = bindableOf(*t.type);
  if (resolved->alias.empty())
    resolved->alias = t.name;
}

/// One variable-declaration: a group of names sharing a type-denoter.
void Sema::checkVarDecl(VarDecl &group, Symbol *owner) {
  // §6.2.3.2: a discriminated schema is the one denoter whose discriminants
  // may be variables, and only here. The first name is resolved with itself
  // offered as the variable they would belong to; if they turned out to be
  // constants the type is an ordinary one and the group shares it, exactly
  // as before.
  Symbol *schema = nullptr;
  if (group.type->kind == TEK::Schema) {
    Symbol *named = lookupQuiet(group.type->qualifier, group.type->name);
    if (named && named->kind == SymKind::Schema)
      schema = named;
  }
  if (schema && !group.names.empty()) {
    const DeclName &n0 = group.names[0];
    Symbol *first =
        addFrameVar(n0.name, SymKind::Var, ty::Int(), owner, n0.line, n0.col);
    dynamicVarFor_ = first;
    first->type = resolveType(*group.type);
    dynamicVarFor_ = nullptr;
    // §6.4.1 writes the initial-state-specifier after *any* of the four bases
    // — "type-denoter = [ 'bindable' ] ( type-name | new-type | type-inquiry |
    // discriminated-schema ) [ initial-state-specifier ]" — and a
    // discriminated-schema is one of them, so `var t: string(4) value 'jk'` is
    // as much a variable with an initial state as `var t: s4 value 'jk'` is.
    // This branch resolved the denoter, which checks the value, and then never
    // asked for the state, so §6.2.3.5's "created in its initial state" did not
    // happen. The path below has always done it; only this branch forgot.
    Expr *schemaInit = initialStateOf(*group.type);
    first->initValue = schemaInit;
    // §6.2.3.2 evaluates the discriminants when the block is entered and the
    // storage they size lives as long as the activation (ADR-0041). A
    // module's activation outlives the function that commences it, so there
    // is nowhere on the stack to put that storage — the tuple has to be
    // constant here, as it is everywhere except a block's own variables.
    if (owner->isModuleSym && first->type->isGeneric())
      diags_.error(n0.line, n0.col,
                   "the discriminants of a module's variable must be "
                   "constants, because a module's activation lasts as long "
                   "as the program");
    for (size_t i = 1; i < group.names.size(); ++i) {
      const DeclName &n = group.names[i];
      Symbol *v =
          addFrameVar(n.name, SymKind::Var, first->type, owner, n.line, n.col);
      // One denoter, so one initial state for the whole group — the same
      // sharing the path below makes, for §6.2.3.5's same reason.
      v->initValue = schemaInit;
      if (!first->type->isGeneric())
        continue;
      // Each name has its own descriptor, so each needs its own type — but
      // one actual-discriminant-part, evaluated once per variable on entry
      // from the one tree the group shares.
      v->type = genericFromSchema(schema, v, *group.type, "variable's type");
      v->descSchema = first->descSchema;
      v->discExprs = first->discExprs;
    }
    return;
  }

  // ISO/IEC 10206:1991 §6.4.2.4 writes a subrange-bound as an expression, and
  // §6.2.3.8 b) evaluates one that is "closest-contained by … the block" at the
  // block's commencement, after the value parameters are attributed — so `var
  // a: array [1..m] of real` is legal inside a procedure and its storage is
  // sized on entry (ADR-0113). The first name is resolved with itself offered
  // as the variable the bounds would belong to, exactly as a schema's
  // discriminants are above; if every bound folded, nothing was created and the
  // group is an ordinary one that shares one type.
  //
  // ISO 7185 §6.4.2.4 writes `subrange-type = constant '..' constant`, so the
  // offer is not made in that language and a bound that is not a constant is
  // the error it has always been.
  Type *t = nullptr;
  Symbol *firstDyn = nullptr;
  bool dynamic = false;
  if (std_ == Std::Extended && !group.names.empty()) {
    const DeclName &n0 = group.names[0];
    firstDyn =
        addFrameVar(n0.name, SymKind::Var, ty::Int(), owner, n0.line, n0.col);
    dynBoundsFor_ = firstDyn;
    t = resolveType(*group.type);
    dynBoundsFor_ = nullptr;
    firstDyn->type = t;
    dynamic = !firstDyn->discSyms.empty();
    if (dynamic) {
      boundSchemaFor(firstDyn);
      // §6.2.3.2's storage lives as long as the activation, and a module's
      // outlives the function that commences it — the same reason a module's
      // variable may not have a non-constant discriminant (ADR-0041).
      if (owner->isModuleSym)
        diags_.error(n0.line, n0.col,
                     "the bounds of a module's variable must be constants, "
                     "because a module's activation lasts as long as the "
                     "program");
    }
  } else {
    t = resolveType(*group.type);
  }
  // One denoter for the whole group, so `a, b: array [1..3] of integer`
  // makes a and b the same type and lets `a := b` through — and where the
  // bounds are not constants it makes them two types, because each name needs
  // a descriptor of its own and a type that reads it.
  Expr *init = initialStateOf(*group.type);
  for (auto &n : group.names) {
    Symbol *v;
    if (firstDyn) {
      v = firstDyn;
      firstDyn = nullptr;
    } else if (dynamic) {
      v = addFrameVar(n.name, SymKind::Var, ty::Int(), owner, n.line, n.col);
      // The one denoter resolved again, with the bounds belonging to this
      // name. Same shape as the schema group above and for the same reason:
      // two descriptors cannot share a type however alike they look.
      forgetResolved(group.type.get());
      dynBoundsFor_ = v;
      v->type = resolveType(*group.type);
      dynBoundsFor_ = nullptr;
      boundSchemaFor(v);
    } else {
      v = addFrameVar(n.name, SymKind::Var, t, owner, n.line, n.col);
    }
    // A variable of a type whose bounds §6.2.3.8 b) evaluated at the
    // type-definition (ADR-0127). It has no discriminants of its own — the
    // clause evaluated them once, for the type — so what its slot holds is the
    // address alone, and the discriminants it reads are the type's, reached
    // through the block's own frame slot by the walk any enclosing variable
    // makes. Sharing the list rather than copying the values is what makes the
    // extent the type's: nothing here can disagree with the descriptor the
    // type filled.
    if (!dynamic && t && t->isGeneric() && t->boundsVar) {
      v->descSchema = t->boundsVar->descSchema;
      v->discSyms = t->boundsVar->discSyms;
      if (owner->isModuleSym)
        diags_.error(n.line, n.col,
                     "the bounds of a module's variable must be constants, "
                     "because a module's activation lasts as long as the "
                     "program");
    }
    // §6.2.3.5 creates each local "in its initial state" on entry, so the
    // whole group shares one value as it shares one type.
    v->initValue = init;
    // §6.4.1's `bindable` belongs to the type-denoter, like the initial
    // state — so the group shares it, and §6.5.1 makes such a variable
    // totally-undefined until something binds it.
    v->isBindable = bindableOf(*group.type);
  }
}

/// The anonymous schema a variable with non-constant bounds is given
/// (ADR-0113). Everything downstream of a dynamically sized variable is keyed
/// on a schema — `isGeneric()` is "a schema and no tuple", the descriptor is
/// laid out from `descSchema->discriminants`, the domain check and the size
/// walk are handed it — and a bare `array [1..m]` has none. Rather than teach a
/// dozen sites to work without one, the variable is given one.
///
/// It has **no body and no name**, and needs neither: nothing looks it up, the
/// program having never written it, and nothing produces a second type from it,
/// because the only type it describes is this variable's. What a schema is for
/// here is the list of discriminants — and the code generator reads the empty
/// spelling to know it must describe the array the program wrote rather than
/// name a schema that does not exist.
void Sema::boundSchemaFor(Symbol *v) {
  Symbol *synth = newSymbol();
  synth->kind = SymKind::Schema;
  // The same symbols, in a list of their own: a descriptor's fields are the
  // discriminants, and here they are one and the same rather than formals
  // matched against actuals.
  synth->discriminants = v->discSyms;
  v->descSchema = synth;
  // The extent is not known until the descriptor is filled, which is exactly
  // what isGeneric() asks.
  v->type->schema = synth;
  v->type->tuple.clear();
}

/// One bound-identifier of an index-type-specification (§6.6.3.7.1).
///
/// It is a `Disc` reading `param`'s descriptor, which is ADR-0040's object
/// exactly. NOTE 2 of §6.6.3.7 says the object a bound-identifier denotes "is
/// neither a constant nor a variable", and `Disc` is already that: it has a
/// value, no storage of its own, and is not assignable.
Symbol *Sema::confBound(Symbol *param, const DeclName &n, Type *host, int &k,
                        bool bind) {
  Symbol *d = newSymbol();
  d->name = n.name;
  d->kind = SymKind::Disc;
  d->type = host;
  d->discBinding = true;
  d->owner = param->owner;
  d->level = param->level;
  d->frameIndex = param->frameIndex;
  d->discIndex = k++;
  param->discSyms.push_back(d);
  // Bound once per *specification*: §6.6.3.7 requires every actual of one
  // conformant-array-parameter-specification to possess the same type, so one
  // pair of bounds describes all of them.
  if (bind)
    scopes_.back()[d->name] = d;
  return d;
}

/// The type a conformant-array-schema denotes (§6.6.3.7.1): "an array-type
/// which shall be distinct from any other type", whose component is the
/// fixed-component-type and whose index-type is the one the actual possesses.
///
/// The index-type is a *subrange* of the ordinal-type-identifier whose ends are
/// the bound symbols, which is the shape a schema body's `array [1..n]` already
/// produces. Its host is `base()`, not the identifier's own type: a subrange
/// never hosts a subrange anywhere else here, and `base()` is one level. T2 is
/// not lost — it is the type the bound identifiers possess.
Type *Sema::confArrayType(Symbol *param, TypeExpr &denoter, bool bind, int &k) {
  Type *host = resolveType(*denoter.index);
  if (host && !host->isOrdinal()) {
    diags_.error(denoter.index->line, denoter.index->col,
                 "the index type of a conformant array must be ordinal, not " +
                     host->name());
    host = ty::Int();
  }
  Symbol *lo = confBound(param, denoter.constants[0], host, k, bind);
  Symbol *hi = confBound(param, denoter.constants[1], host, k, bind);
  Type *idx = newType(TypeKind::Subrange);
  idx->host = host->base();
  idx->lo = 0;
  idx->hi = 0;
  idx->loDisc = lo;
  idx->hiDisc = hi;
  Type *comp = denoter.elem->kind == TEK::ConfArray
                   ? confArrayType(param, *denoter.elem, bind, k)
                   : resolveType(*denoter.elem);
  Type *t = newType(TypeKind::Array);
  t->indexType = idx;
  // An array is bounded by its index type, dynamically or not, so a dynamic
  // bound travels one step outwards here.
  t->loDisc = lo;
  t->hiDisc = hi;
  t->elem = comp;
  t->packed = denoter.packed;
  t->isConfSchema = true;
  t->lo = 0;
  t->hi = 0;
  return t;
}

/// §6.6.3.7.1's fixed-component-type: the component at the bottom of the nest.
Type *Sema::fixedComponent(Type *t) {
  while (t->elem && t->elem->isConfSchema)
    t = t->elem;
  return t->elem;
}

/// §6.6.3.8's conformability, as that clause's four statements.
bool Sema::conformable(Type *t1, Type *f) {
  if (!t1 || !f || !t1->isArray() || !f->isArray())
    return false;
  // d) packed with packed, unpacked with unpacked
  if (t1->packed != f->packed)
    return false;
  // a) the index-type of T1 is compatible with T2, which is the type the bound
  // identifiers possess (§6.6.3.7.1)
  Type *t2 = f->indexType->loDisc->type;
  if (t1->indexType->base() != t2->base())
    return false;
  // b) T1's bounds lie within the closed interval T2 specifies — where T1 has
  // bounds. Where T1 is itself a schema they arrive with its own actual, and
  // §6.6.3.8's closing sentence makes that an *error* rather than a violation.
  if (!t1->isConfSchema && (t1->lo < t2->ordinalLo() || t1->hi > t2->ordinalHi()))
    return false;
  // c) the component is the fixed-component-type, or conformable in turn
  if (f->elem->isConfSchema)
    return conformable(t1->elem, f->elem);
  return t1->elem == f->elem;
}

/// §6.6.3.6 e): when two conformant-array-schemas are **equivalent**.
///
/// Statement 1) — a single index-type-specification in each — is satisfied by
/// construction: the parser writes §6.6.3.7's full form always, so the
/// abbreviated and nested spellings arrive as one tree.
bool Sema::equivalentConf(Type *a, Type *b) {
  if (!a || !b || !a->isConfSchema || !b->isConfSchema)
    return false;
  // 4) both packed, or both unpacked
  if (a->packed != b->packed)
    return false;
  // 2) the ordinal-type-identifiers denote the same type — read from the bound
  // identifiers, the index-type's host having been flattened to its base
  if (a->indexType->loDisc->type != b->indexType->loDisc->type)
    return false;
  // 3) the component schemas are equivalent, or the type-identifiers denote
  // the same type
  if (a->elem->isConfSchema || b->elem->isConfSchema)
    return equivalentConf(a->elem, b->elem);
  return a->elem == b->elem;
}

/// The whole of a conformant array parameter's type, descriptor and all.
///
/// **One type for the whole section.** §6.6.3.7.1 says "the formal-parameters
/// shall possess an array-type" — one for the parameters of one specification,
/// not one apiece — and the clause before it makes that sound. It is also what
/// a program can see: `x := y` between two names of one section is conforming.
Type *Sema::conformantFormal(Symbol *param, TypeExpr &denoter, Type *share) {
  param->discSyms.clear();
  int k = 0;
  Type *t = confArrayType(param, denoter, share == nullptr, k);
  if (share)
    t = share;
  param->type = t;
  param->isConformant = true;
  param->confBinds = share == nullptr;
  boundSchemaFor(param);
  return t;
}

/// What a function may return. The two standards draw the line in opposite
/// directions, so this states each in its own words rather than deriving one
/// from the other.
///
/// ISO 7185 §6.6.2 lists what is *allowed* — a simple type or a pointer type —
/// and that is the way round it has to be read: a set lives in a register and
/// would pass any "not something in memory" test while still not being a
/// result type the language admits. ISO/IEC 10206:1991 §6.4.2.2 adds `complex`
/// to the simple types, so under both standards that list grew by a word
/// rather than by a rule.
///
/// §6.7.2 replaces the list with what is *refused*: a file-type, a structured
/// type having a component a file may not have, and a bindable one. The first
/// two are one predicate — `containsFile` is precisely "not permissible as a
/// component-type of a file-type" — and the third is there because a bindable
/// variable is one the program can point at something outside itself, which a
/// value with no name cannot be.
Type *Sema::checkedResultType(Type *t, bool bindable, int line, int col) {
  if (std_ == Std::Extended) {
    if (t->isFile() || containsFile(t)) {
      diags_.error(line, col,
                   "a function cannot return " + t->name() +
                       ": a result may not be, or contain, a file");
      return ty::Int();
    }
    if (bindable) {
      diags_.error(line, col,
                   "a function cannot return a bindable " + t->name() +
                       ": only a variable can be bound to something outside "
                       "the program");
      return ty::Int();
    }
    return t;
  }
  if (!t->isOrdinal() && !t->isReal() && !t->isComplex() && !t->isPointer()) {
    diags_.error(line, col,
                 "a function cannot return " + t->name() +
                     "; use a var parameter");
    return ty::Int();
  }
  return t;
}

void Sema::declareProcHeading(ProcDecl &decl, Symbol *owner) {
  Symbol *existing = nullptr;
  auto it = scopes_.back().find(decl.name);
  if (it != scopes_.back().end() && it->second->isCallable() &&
      !it->second->defined)
    existing = it->second; // completing an earlier `forward`

  if (existing) {
    // ISO 7185 §6.6.1: the full declaration of a forward-declared procedure
    // repeats the name only, so the parameters are already known.
    if (!decl.params.empty() || decl.returnType)
      diags_.error(decl.line, decl.col,
                   "the parameters of '" + decl.name +
                       "' were already given in its forward declaration");
    // §6.6.1: `forward` follows a procedure-*heading*. This is a
    // procedure-identification — the name alone, resuming a forward
    // declaration — and the clause gives such an identifier "exactly one of
    // its applied occurrences in a procedure-identification", followed by the
    // block. A second `forward` leaves two headings and no body.
    if (decl.isForward)
      diags_.error(decl.line, decl.col,
                   "'" + decl.name + "' was already declared forward, so this "
                   "declaration needs its body rather than 'forward' again");
    decl.sym = existing;
    existing->decl = &decl;
    return;
  }

  Symbol *sym = declare(decl.name,
                        decl.isFunction ? SymKind::Func : SymKind::Proc,
                        decl.line, decl.col);
  sym->level = owner->level + 1;
  sym->owner = owner;
  sym->decl = &decl;
  decl.sym = sym;

  if (decl.isFunction) {
    if (!decl.returnType) {
      diags_.error(decl.line, decl.col,
                   "function '" + decl.name + "' needs a result type");
      sym->type = ty::Int();
    } else {
      Type *want = resolveType(*decl.returnType);
      sym->type = checkedResultType(want, bindableOf(*decl.returnType),
                                    decl.line, decl.col);
      sym->resultTypeBad = sym->type != want;
    }
  }

  // Parameters belong to the procedure's own frame, so they are created here
  // but only made visible once its body is entered.
  pushScope();
  buildFormals(decl.params, sym, sym);
  if (sym->kind == SymKind::Func) {
    // The result lives in the frame like a local; assigning to the function
    // name writes here, and the epilogue returns it.
    //
    // Unless it lives in memory (§6.7.2), in which case the caller built the
    // storage and the frame slot holds its *address*. That is what a `var`
    // parameter already is, so saying so is the whole of the difference:
    // `addressOf` dereferences a `VarParam`, and assignment, whole-variable
    // copying and every designator over the result then need nothing new.
    sym->resultNamed = !decl.resultName.empty();
    if (sym->resultNamed) {
      // §6.2.2.7: "When an identifier or label has a defining-point for a
      // region, another identifier or label with the same spelling shall not
      // have a defining-point for that region." The region is the
      // formal-parameter-list, and §6.7.2 and §6.7.3.1 each put one in it —
      // the result-variable-specification's identifier is a
      // function-result-identifier for it, and a parameter is a
      // parameter-identifier for it. §6.7.3.7.1's bound-identifiers are in
      // that region too, so a conformant array's bounds are asked as well.
      //
      // Unconditional here, as ADR-0121's `external` refusal is: this front
      // end is never given `--std=afterschool`, and the rule is Extended
      // Pascal's own — a result-variable-specification does not parse under
      // ISO 7185, so the branch cannot be reached in that mode.
      auto clash = [&](const Symbol *other) {
        diags_.error(decl.line, decl.col,
                     "the result variable of '" + decl.name + "' is named '" +
                         other->name +
                         "', which is already a parameter of it: both name the "
                         "formal-parameter-list");
      };
      for (const Symbol *p : sym->params) {
        if (p->name == decl.resultName)
          clash(p);
        if (p->confBinds)
          for (const Symbol *d : p->discSyms)
            if (d->name == decl.resultName)
              clash(d);
      }
      sym->resultSourceName = decl.resultName;
    }
    sym->resultVar = addHiddenVar(
        (sym->resultNamed ? decl.resultName : decl.name) + "$result",
        sym->type->isMemory() ? SymKind::VarParam : SymKind::Var, sym->type,
        sym);
  }
  popScope();
}

/// One parameter of a formal parameter list. A top-level one is a variable of
/// the procedure's own frame; one belonging to a *procedural* parameter is a
/// descriptor only — it says how the argument travels and what type it has,
/// and the frame it will occupy is the frame of whatever procedure is
/// eventually passed. Hence `frame` being null for those.
static Symbol *formalSymbol(Symbol *s, const DeclName &n, SymKind kind,
                            Type *type) {
  s->name = n.name;
  s->kind = kind;
  s->type = type;
  return s;
}

void Sema::buildFormals(std::vector<ParamGroup> &groups, Symbol *into,
                        Symbol *frame) {
  // "The formal-parameter-list closest-containing" in §6.4.9's words — closest
  // because this recurses for a procedural parameter's own list and restores
  // the saved value afterwards, so inside `procedure q(x: type of k)` it names
  // q and not the procedure q is a parameter of (ADR-0134).
  Symbol *savedFormals = formalsFor_;
  formalsFor_ = into;
  struct Restore {
    Symbol *&slot;
    Symbol *old;
    ~Restore() { slot = old; }
  } restore{formalsFor_, savedFormals};
  int section = 0;
  for (auto &group : groups) {
    if (group.isProc) {
      ++section;
      // ISO 7185 §6.6.3.1 spells a procedural parameter as a heading, so it
      // declares exactly one name and the parser guarantees it is there.
      Type *t = newType(TypeKind::Proc);
      if (group.isFunction) {
        t->elem = group.returnType ? resolveType(*group.returnType) : ty::Int();
        // §6.6.2 restricts a function's result type, and a functional
        // parameter's heading is a function heading — the same rule, so the
        // same check.
        t->elem = checkedResultType(
            t->elem, group.returnType && bindableOf(*group.returnType),
            group.names[0].line, group.names[0].col);
      }
      const DeclName &n = group.names[0];
      Symbol *ps =
          frame ? addFrameVar(n.name, SymKind::ProcParam, t, frame, n.line,
                              n.col)
                : formalSymbol(newSymbol(), n, SymKind::ProcParam, t);
      // Its own parameters name no frame and are never looked up: the actual
      // procedure supplies the names its body uses, and these exist only to be
      // compared against that procedure's. Two of them sharing a spelling
      // therefore cannot be ambiguous, so no scope is pushed to catch it.
      buildFormals(group.params, ps, nullptr);
      into->params.push_back(ps);
      continue;
    }

    SymKind kind = group.byRef ? SymKind::VarParam : SymKind::Param;
    ++section;

    // §6.7.3.2/§6.7.3.3: a parameter-form may be a bare schema-name, and then
    // the type is not one type — the tuple arrives with the actual. Each name
    // needs its symbol *first*, because the discriminants are resolved against
    // the descriptor that symbol's frame slot holds.
    Symbol *schema = nullptr;
    if (group.type && group.type->kind == TEK::Named) {
      Symbol *named = lookup(group.type->name);
      if (named && named->kind == SymKind::Schema)
        schema = named;
    }
    // ISO 7185 §6.6.3.7's conformant array parameter takes the same route for
    // the same reason: the symbol has to exist before its type can be built,
    // because the bound-identifiers are fields of the descriptor that symbol's
    // frame slot holds. Only the *first* name of the section declares them.
    if (group.type && group.type->kind == TEK::ConfArray) {
      Symbol *first = nullptr;
      for (auto &n : group.names) {
        Symbol *ps = frame ? addFrameVar(n.name, kind, ty::Int(), frame, n.line,
                                         n.col)
                           : formalSymbol(newSymbol(), n, kind, ty::Int());
        ps->paramSection = section;
        ps->isProtected = group.isProtected;
        ps->type = conformantFormal(ps, *group.type,
                                    first ? first->type : nullptr);
        // §6.6.3.7.2: "The fixed-component-type of a value conformant array
        // shall be one that is permitted as the component-type of a
        // file-type." The variable form is unrestricted: nothing is copied.
        if (!group.byRef && containsFile(fixedComponent(ps->type)))
          diags_.error(n.line, n.col,
                       "a value conformant array cannot have component type " +
                           fixedComponent(ps->type)->name() +
                           ": it contains a file, and a file has no copy");
        if (!first)
          first = ps;
        group.type->resolved = ps->type;
        into->params.push_back(ps);
      }
      continue;
    }

    if (schema) {
      for (auto &n : group.names) {
        Symbol *ps = frame ? addFrameVar(n.name, kind, ty::Int(), frame, n.line,
                                         n.col)
                           : formalSymbol(newSymbol(), n, kind, ty::Int());
        ps->paramSection = section;
        ps->isProtected = group.isProtected;
        ps->type = schematicFormal(schema, ps, *group.type);
        // §6.7.3.1 asks the question of "every type possessed by" the name,
        // and a schematic formal possesses one per tuple — but they all come
        // from one body, so the produced type answers for every one of them.
        if (group.isProtected && ps->type && !ps->type->protectable())
          diags_.error(n.line, n.col,
                       "'" + n.name + "' cannot be protected: " +
                           ps->type->name() + " is not a protectable type");
        // The denoter keeps the last of them, the way a schema body keeps its
        // last production (ADR-0039): one parameter-form has as many types as
        // it has names, and showing one of them says more than showing none.
        group.type->resolved = ps->type;
        into->params.push_back(ps);
      }
      continue;
    }

    // §6.7.3.1: "The parameter-form ... shall not contain an applied
    // occurrence of the parameter-identifier", so `x: type of x` is refused —
    // and it has to be refused *before* the names are declared, or the name
    // would find itself.
    if (group.type && group.type->kind == TEK::Inquiry)
      for (auto &n : group.names)
        if (n.name == group.type->name)
          diags_.error(group.type->line, group.type->col,
                       "'type of " + n.name +
                           "' names the very parameter it is the type of");

    Type *t = resolveType(*group.type);
    // ISO 7185 §6.6.3.2 and ISO/IEC 10206:1991 §6.7.3.2: "The type possessed
    // by the formal-parameter shall be one that is permitted as the
    // component-type of a file-type." `containsFile` is precisely that
    // predicate — the same one `checkedResultType` asks of a result and
    // `resolveFile` of a component — so a record or an array holding a file is
    // refused as well, having no copy for the same reason the file has none:
    // the position, the buffer and the operating system's handle are one
    // object, not a value. The clause is §6.6.3.2 and not §6.6.3.3, which is
    // the variable-parameter clause and says nothing about files.
    if ((t->isFile() || containsFile(t)) && !group.byRef &&
        !group.names.empty()) {
      diags_.error(group.names[0].line, group.names[0].col,
                   t->isFile() ? "a file parameter must be a var parameter"
                               : "a value parameter cannot be " + t->name() +
                                     ": it contains a file, and a file has no "
                                     "copy");
    }
    // A variable-string value parameter is converted rather than copied —
    // §6.4.6 pads a shorter value with spaces and refuses a longer one — and
    // ADR-0052 refused it because "a conversion needs somewhere to build the
    // result that the caller can name". It has somewhere now, and it is not
    // the caller: the *callee's* slot for the parameter is an ordinary frame
    // field of the formal's type, so the prologue stores the pair the caller
    // passed exactly as `s := expr` does (ADR-0115).
    //
    // A restricted one is still refused, and no longer for that reason.
    // §6.4.2.5 makes a restricted string's states one-to-one with the
    // string's, so the conversion is available to it too; what is not settled
    // is whether a clause that forbids assigning a restricted value permits
    // copying one into a parameter, and a reading nobody has taken is not a
    // thing to decide inside a lowering. Asked of the *underlying* type,
    // because a restricted type does not launder a rule about how a value is
    // passed.
    if (t->isRestricted() && t->underlying()->isVarString() && !group.byRef &&
        !group.names.empty())
      diags_.error(group.names[0].line, group.names[0].col,
                   "a restricted string parameter must be a var parameter; "
                   "whether a restricted value may be copied into a value "
                   "parameter is not decided here");
    // §6.4.1: a file or a pointer is not protectable, and neither is anything
    // holding one. The standard's own reason is that protecting either would
    // protect nothing — a file is modified by nearly every operation on it,
    // and a pointer's *value* can be copied out of the protected variable and
    // disposed of through the copy.
    if (group.isProtected && !group.names.empty() && !t->protectable())
      diags_.error(group.names[0].line, group.names[0].col,
                   "'" + group.names[0].name + "' cannot be protected: " +
                       t->name() + " is not a protectable type");
    for (auto &n : group.names) {
      Symbol *ps =
          frame ? addFrameVar(n.name, kind, t, frame, n.line, n.col)
                : formalSymbol(newSymbol(), n, kind, t);
      ps->paramSection = section;
      ps->isProtected = group.isProtected;
      // §6.7.3.3: a var parameter's form is a type-name, and §6.4.1 makes a
      // type-name denote the bindability of its definition — so a parameter of
      // a bindable type is bindable and one of `text` is not.
      ps->isBindable = bindableOf(*group.type);
      into->params.push_back(ps);
    }
  }
}

bool Sema::congruous(Symbol *formal, Symbol *actual) const {
  if (formal->params.size() != actual->params.size())
    return false;
  Type *want = formal->resultType();
  Type *got = actual->resultType();
  // A procedure and a function are never congruous however alike their
  // parameters: one has a result and the other has nowhere to put one.
  if ((want == nullptr) != (got == nullptr))
    return false;
  if (want && want != got)
    return false;

  for (size_t i = 0; i < formal->params.size(); ++i) {
    Symbol *f = formal->params[i];
    Symbol *a = actual->params[i];
    // The passing mode is part of the congruity: a var parameter binds to a
    // variable and a value parameter copies one, and the caller emits
    // different code for each — so the two cannot stand in for one another.
    if (f->kind != a->kind)
      return false;
    // §6.6.3.6 is pairwise over formal-parameter-*sections*, not over
    // parameters: "Two formal-parameter-lists shall be congruous if they
    // contain the same number of formal-parameter-sections and if the
    // formal-parameter-sections in corresponding positions match", and b) adds
    // "containing the same number of parameters". So `(var a, b: integer)` is
    // one section of two names and `(var a: integer; var b: integer)` is two
    // sections of one, and the lists are not congruous however alike their
    // parameters are. Given the counts already agree, equal section numbers at
    // every position is exactly that — the boundaries can only line up one way.
    if (f->paramSection != a->paramSection)
      return false;
    // §6.7.3.6: "Either both contain protected or neither contains
    // protected." A body written against a protected parameter may not be
    // handed one it is allowed to write, and — the direction that is easier
    // to forget — a body that writes its parameter may not be passed where a
    // protected one was promised.
    if (f->isProtected != a->isProtected)
      return false;
    if (f->kind == SymKind::ProcParam) {
      if (!congruous(f, a))
        return false;
    } else if (f->isConformant || a->isConformant) {
      // §6.6.3.6 e): two conformant array parameters match when their schemas
      // are equivalent. Before the schematic-formal test below, because a
      // conformant array parameter carries a descriptor too and its
      // synthesised schema is a fresh object per parameter — so that test
      // would refuse every pair. Value against variable is already excluded by
      // the `kind` comparison at the top of this loop, which is the first half
      // of e)'s own sentence.
      if (!f->isConformant || !a->isConformant ||
          !equivalentConf(f->type, a->type))
        return false;
    } else if (f->descSchema || a->descSchema) {
      // A schematic formal's type belongs to that one parameter and is never
      // equal to another's, so congruity asks the question §6.7.3.3 asks: the
      // same schema, with the tuple left to the actual as it always is.
      if (f->descSchema != a->descSchema)
        return false;
    } else if (f->type != a->type) {
      return false;
    }
  }
  return true;
}

void Sema::checkProcBody(ProcDecl &decl) {
  Symbol *sym = decl.sym;
  if (!sym)
    return;
  if (sym->defined) {
    diags_.error(decl.line, decl.col,
                 "'" + decl.name + "' already has a body");
    return;
  }
  sym->defined = true;

  Symbol *outerProc = current_;
  current_ = sym;

  pushScope();
  for (Symbol *p : sym->params) {
    scopes_.back()[p->name] = p;
    // §6.6.3.7.1 makes a bound-identifier a defining-point for the
    // formal-parameter-list *and* for the block, and those are two scopes
    // here: the first is popped when buildFormals returns. So the block's is
    // made from the symbol, exactly as the parameters are and for the same
    // reason — a `forward` heading and its body are two declarations, and only
    // the symbol is common to both.
    if (p->confBinds)
      for (Symbol *d : p->discSyms)
        scopes_.back()[d->name] = d;
  }
  // §6.7.2: the result-variable-specification's identifier is a
  // variable-identifier for the region that is the block. It is the *same*
  // symbol the function name assigns to, so nothing else has to know which of
  // the two spellings a body used.
  // §6.7.2: read from the *symbol*, not from this declaration, which is what
  // makes the result variable reach a `forward`-declared body — the heading
  // carrying the specification and the block are then different declarations.
  // The clause's next paragraph says the same of the formal-parameter-list,
  // and the parameters have always been bound from the symbol for that reason.
  // §6.11.1 makes every exported function a forward, so this reached every
  // module.
  if (sym->resultNamed && sym->resultVar)
    scopes_.back()[sym->resultSourceName] = sym->resultVar;
  checkBlock(*decl.body, sym);
  popScope();

  // ISO 7185 §6.6.2 and ISO/IEC 10206:1991 §6.7.2 both require a function's
  // block to contain at least one assignment to the function-identifier; with
  // a result-variable-specification the requirement moves to the result
  // variable and the word changes with it — §6.7.2 asks for "at least one
  // statement threatening" it, and §6.9.4's *threatens* is weaker than
  // *assigns*, a `read` into the result or a var argument counting where no
  // assignment does.
  //
  // So the two halves ask two questions of two flags, which is what ADR-0134
  // added: assignedResult is the syntactic containment of an assignment to the
  // function identifier, wasThreatened is §6.9.4's own list recorded where that
  // list is already walked. A function returns whatever the storage happened to
  // hold if either goes unanswered.
  if (sym->kind == SymKind::Func && !sym->resultTypeBad) {
    if (!sym->resultNamed) {
      if (!sym->assignedResult)
        diags_.error(decl.line, decl.col,
                     "function '" + decl.name + "' never assigns its result");
    } else if (sym->resultVar && !sym->resultVar->wasThreatened)
      diags_.error(decl.line, decl.col,
                   "function '" + decl.name +
                       "' never writes to its result variable '" +
                       sym->resultSourceName + "'");
  }

  current_ = outerProc;
}

/// ISO/IEC 10206:1991 §6.8.8.2: the component-value an array-value maps an
/// index to. §6.8.7.2 b)'s completer covers whatever the labelled elements
/// leave, so it is the answer only when none of them claimed the index — which
/// is the same rule CodeGen implements by writing the completer first and the
/// elements over it, read the other way round.
static Expr *arrayComponentOf(StructValueExpr *sv, long long idx) {
  Expr *completer = nullptr;
  for (ValueElem &el : sv->elems) {
    if (el.completer) {
      completer = el.value.get();
      continue;
    }
    for (const LabelRange &r : el.values)
      if (idx >= r.lo && idx <= r.hi)
        return el.value.get();
  }
  return completer;
}

/// §6.8.8.3: the component-value a record-value gives a field. `Field::variant`
/// is the path to the field-list the field lives in (ADR-0026), so this walks
/// the same path `fieldAddress` walks — and stops where §6.8.8.3's error is:
/// an arm the value did not select has no component to denote, which is D.90
/// answered at compile time because a constant's tag is a constant.
static Expr *recordComponentOf(StructValueExpr *sv, const Field *f,
                               size_t depth, bool &inactive) {
  if (depth == f->variant.size()) {
    for (ValueElem &el : sv->elems)
      for (int k : el.fieldIndex)
        if (k == f->index)
          return el.value.get();
    return nullptr;
  }
  if (sv->armIndex < 0 || !sv->variant || sv->armIndex != f->variant[depth]) {
    inactive = true;
    return nullptr;
  }
  return recordComponentOf(as<StructValueExpr>(sv->variant.get()), f, depth + 1,
                           inactive);
}

/// §6.8.8's constant-access, folded. The value of a constant-access is the
/// value of the component it selects, and a constant keeps the *node* that
/// defines it — so selecting is a walk into that node and the answer is
/// another node, which the ordinary folder then evaluates. §6.8.2 guarantees
/// the index is itself constant here: a variable index is a variable-access,
/// which a constant-expression may not contain, so the two readings of `c[i]`
/// never collide (ADR-0069).
///
/// Null means "not a constant-access", which is not an error — the caller's
/// context says what it wanted.
Expr *Sema::constAccessNode(Expr *e) {
  if (auto *v = as<VarRef>(e))
    return (!v->withField && v->sym && v->sym->kind == SymKind::Const)
               ? v->sym->constValue
               : nullptr;
  if (auto *f = as<FieldExpr>(e)) {
    if (f->qualified)
      return f->qualified->kind == SymKind::Const ? f->qualified->constValue
                                                  : nullptr;
    if (!f->resolved)
      return nullptr;
    Expr *base = constAccessNode(f->base.get());
    auto *sv = as<StructValueExpr>(base);
    if (!sv)
      return nullptr;
    bool inactive = false;
    Expr *comp = recordComponentOf(sv, f->resolved, 0, inactive);
    if (inactive) {
      diags_.error(f->line, f->col,
                   "'" + f->field +
                       "' is a component of a variant the constant does not "
                       "select");
      constReported_ = true;
    }
    return comp;
  }
  if (auto *ix = as<IndexExpr>(e)) {
    if (ix->setValue)
      return nullptr; // ADR-0066's set-value: a value, not an access
    Expr *base = constAccessNode(ix->base.get());
    if (!base)
      return nullptr;
    // Folded rather than `evalOrdinal`'d: that would run `checkExpr` over an
    // index this pass has already checked, and report anything wrong twice.
    Type *bt = ix->base->type;
    Symbol iv;
    if (!bt || !bt->isArray() || !evalConst(ix->index.get(), iv) || !iv.type ||
        !iv.type->isOrdinal())
      return nullptr;
    long long idx = ordinalOf(iv);
    // §6.8.8.2 makes the index assignment-compatible with the index-type, and
    // outside it there is no component — an error whichever way it is written,
    // so it is reported here rather than left to say "not constant".
    if (idx < bt->lo || idx > bt->hi) {
      diags_.error(ix->line, ix->col,
                   "index " + std::to_string(idx) + " is outside " +
                       std::to_string(bt->lo) + ".." + std::to_string(bt->hi) +
                       ", so it selects no component");
      constReported_ = true;
      return nullptr;
    }
    if (auto *sv = as<StructValueExpr>(base))
      return arrayComponentOf(sv, idx);
    return nullptr; // a string constant: its component is a char, not a node
  }
  return nullptr;
}

bool Sema::evalConst(Expr *e, Symbol &out) {
  if (auto *i = as<IntLit>(e)) {
    out.type = ty::Int();
    out.intVal = i->value;
    return true;
  }
  if (auto *r = as<RealLit>(e)) {
    out.type = ty::Real();
    out.realVal = r->value;
    return true;
  }
  if (auto *c = as<CharLit>(e)) {
    out.type = ty::Char();
    out.charVal = c->value;
    return true;
  }
  // ISO 7185 §6.3: a `character-string` is a constant. It has no scalar form,
  // so what is folded is the literal itself — the constant *is* the literal,
  // named, and takes whichever type the literal has in the standard being
  // compiled for. A one-character literal never reaches here; the parser has
  // already made it a `CharLit`, which is why `const c = 'a'` is a char.
  if (auto *s = as<StrLit>(e)) {
    out.type = s->type;
    out.constValue = s;
    return true;
  }
  // ISO/IEC 10206:1991 §6.8.7's structured-value-constructor, named. §6.8.2
  // makes `nonvarying` the whole test of a constant-expression — not "the
  // compiler can fold it" — so an array, record or set value whose components
  // read nothing is a constant, and it keeps the node exactly as a string
  // constant keeps its literal. A set-value reaches here as the subscript
  // spine ADR-0066 left behind, which is why the shapes are asked for rather
  // than the node kinds (ADR-0069).
  if (is<StructValueExpr>(e) || is<SetExpr>(e) ||
      (as<IndexExpr>(e) && as<IndexExpr>(e)->setValue) ||
      (as<SubstringExpr>(e) && as<SubstringExpr>(e)->setValue)) {
    if (!e->type || !nonvarying(e))
      return false;
    out.type = e->type;
    out.constValue = e;
    return true;
  }
  if (auto *v = as<VarRef>(e)) {
    if (!v->sym || v->sym->kind != SymKind::Const)
      return false;
    out = *v->sym;
    return true;
  }
  // A constant reached through an interface. §6.11.3 makes the imported
  // identifier "a constant-identifier that denotes the value", so it is as
  // constant as the one the module wrote.
  if (auto *f = as<FieldExpr>(e)) {
    if (f->qualified && f->qualified->kind == SymKind::Const) {
      out = *f->qualified;
      return true;
    }
  }
  // §6.8.8's constant-access. The component a constant-access selects is
  // usually a node of the value — an array-value's element or a record-value's
  // field-value — and then the ordinary folder finishes the job. A component
  // of a *string* constant is not: the characters are the value, so the two
  // string forms are computed here (ADR-0069).
  if (is<IndexExpr>(e) || is<FieldExpr>(e) || is<SubstringExpr>(e)) {
    if (Expr *node = constAccessNode(e))
      return evalConst(node, out);
    if (auto *ix = as<IndexExpr>(e)) {
      // §6.8.8.2's string-constant form: one index-expression, and what it
      // selects is a character.
      auto *lit = as<StrLit>(constAccessNode(ix->base.get()));
      Symbol iv;
      if (!lit || !evalConst(ix->index.get(), iv) || !iv.type ||
          !iv.type->isInteger())
        return false;
      long long i = iv.intVal;
      if (i < 1 || i > static_cast<long long>(lit->value.size())) {
        diags_.error(ix->line, ix->col,
                     "index " + std::to_string(i) +
                         " is outside the string constant's 1.." +
                         std::to_string(lit->value.size()));
        constReported_ = true;
        return false;
      }
      out.type = ty::Char();
      out.charVal = lit->value[static_cast<size_t>(i - 1)];
      return true;
    }
    if (auto *ss = as<SubstringExpr>(e)) {
      // §6.8.8.4's substring-constant. Its value is characters that are in no
      // node, so a literal holding them is made — the one place this compiler
      // builds a piece of tree that the program did not write. Sema owns it,
      // beside the symbols it owns, because `Symbol::constValue` outlives the
      // fold and CodeGen reads it.
      auto *lit = as<StrLit>(constAccessNode(ss->base.get()));
      Symbol lo, hi;
      if (!lit || !evalConst(ss->lo.get(), lo) ||
          !evalConst(ss->hi.get(), hi) || !lo.type || !hi.type ||
          !lo.type->isInteger() || !hi.type->isInteger())
        return false;
      long long n = static_cast<long long>(lit->value.size());
      if (lo.intVal < 1 || hi.intVal > n || lo.intVal > hi.intVal) {
        diags_.error(ss->line, ss->col,
                     "the substring " + std::to_string(lo.intVal) + ".." +
                         std::to_string(hi.intVal) +
                         " is not within the string constant's 1.." +
                         std::to_string(n));
        constReported_ = true;
        return false;
      }
      auto made = std::make_unique<StrLit>();
      made->line = ss->line;
      made->col = ss->col;
      made->value =
          lit->value.substr(static_cast<size_t>(lo.intVal - 1),
                            static_cast<size_t>(hi.intVal - lo.intVal + 1));
      checkExpr(made.get()); // the literal's type is the literal's business
      out.type = made->type;
      out.constValue = made.get();
      constNodes_.push_back(std::move(made));
      return true;
    }
    return false;
  }
  if (auto *u = as<Unary>(e)) {
    Symbol inner;
    if (!evalConst(u->operand.get(), inner))
      return false;
    switch (u->op) {
    case UnOp::Pos:
      out = inner;
      return inner.type && inner.type->isNumeric();
    case UnOp::Neg:
      out = inner;
      if (inner.type && inner.type->isInteger()) { out.intVal = -inner.intVal; return true; }
      if (inner.type && inner.type->isReal()) { out.realVal = -inner.realVal; return true; }
      return false;
    case UnOp::Not:
      if (!inner.type || !inner.type->isBoolean())
        return false;
      out = inner;
      out.boolVal = !inner.boolVal;
      return true;
    }
  }
  // ISO/IEC 10206:1991 §6.8.2 opens every one of these positions from a
  // *constant* to a constant-expression. Everything above is ISO 7185's
  // `constant` — a signed literal or a name — and everything below is the
  // rest of an expression, so the standard decides which of the two languages
  // is being folded.
  if (std_ == Std::Extended) {
    if (auto *b = as<Binary>(e))
      return evalConstBinary(b, out);
    if (auto *c = as<Call>(e))
      return evalConstCall(c, out);
    // §6.7.1 makes `nil` an unsigned-constant, so it is a primary and §6.8.2
    // admits it: it names a value and reads nothing, which is the whole of
    // nonvarying. ISO 7185 §6.3's `constant` has no `nil` at all, which is why
    // this sits here rather than beside the literals above.
    //
    // The constant keeps the literal's own type. §6.4.4's NOTE 2 says the
    // token "does not have a single type, but assumes a suitable pointer-type
    // to satisfy the assignment-compatibility rules", which is ADR-0019's
    // nil-type — assignable to every pointer-type and nothing assignable to
    // it — so one `const q = nil` serves them all, and no rule anywhere else
    // had to learn that a constant can be a pointer.
    if (is<NilLit>(e)) {
      out.type = e->type;
      out.constValue = e;
      return true;
    }
  }
  return false;
}

/// §6.7.2.2 makes an integer overflow an error, and one the *compiler* can see
/// is a diagnostic rather than a trap: the value would otherwise reach a type
/// declaration as a wrapped number. The arithmetic is done in a wider type and
/// the result range-checked, which is the same set of accepted programs the
/// Pascal-hosted compiler reaches by checking before it multiplies — it has no
/// wider type to fall back on.
bool Sema::foldIntOp(long long a, long long b, BinOp op, int line, int col,
                     long long &out) {
  switch (op) {
  case BinOp::Add: out = a + b; break;
  case BinOp::Sub: out = a - b; break;
  case BinOp::Mul: out = a * b; break;
  case BinOp::IntDiv:
    if (b == 0) {
      diags_.error(line, col, "div by zero in a constant expression");
      constReported_ = true;
      return false;
    }
    out = a / b;
    break;
  case BinOp::Mod:
    // §6.7.2.2 defines `mod` only for a positive right operand, and gives a
    // non-negative result — the same rule the emitted code follows, so a
    // folded `mod` and a computed one cannot disagree.
    if (b <= 0) {
      diags_.error(line, col,
                   "the right operand of mod must be positive, and this one "
                   "is a constant that is not");
      constReported_ = true;
      return false;
    }
    out = ((a % b) + b) % b;
    break;
  default:
    return false;
  }
  if (out > kMaxInt || out < -kMaxInt) {
    diags_.error(line, col, "integer overflow in a constant expression");
    constReported_ = true;
    return false;
  }
  return true;
}

/// §6.8.2's expression, once both operands have folded. What it will not fold
/// is stated rather than silently refused: a real-valued operation, because a
/// real constant is carried here as its source text and never converted
/// (ADR-0025), and a set- or string-valued one, because a `Symbol` has nowhere
/// to keep the value.
bool Sema::evalConstBinary(Binary *b, Symbol &out) {
  Symbol l, r;
  if (!evalConst(b->lhs.get(), l) || !evalConst(b->rhs.get(), r))
    return false;
  if (!l.type || !r.type)
    return false;

  if (l.type->isReal() || r.type->isReal() || b->op == BinOp::RealDiv ||
      b->op == BinOp::Exp) {
    diags_.error(b->line, b->col,
                 "a real constant expression is not folded: a real constant "
                 "is carried as the text that was written and never "
                 "converted");
    constReported_ = true;
    return false;
  }

  auto ordinalOf = [](const Symbol &s) -> long long {
    if (s.type->isChar())
      return static_cast<unsigned char>(s.charVal);
    if (s.type->base()->kind == TypeKind::Boolean)
      return s.boolVal ? 1 : 0;
    return s.intVal;
  };

  switch (b->op) {
  case BinOp::Add:
  case BinOp::Sub:
  case BinOp::Mul:
  case BinOp::IntDiv:
  case BinOp::Mod:
  case BinOp::Pow: {
    if (!l.type->isInteger() || !r.type->isInteger())
      return false;
    if (b->op == BinOp::Pow) {
      // §6.8.3.2 table 3: `pow` yields the type of its *left* operand, so an
      // integer base gives an integer. It is repeated multiplication, and
      // every step is checked, exactly as the runtime's is.
      if (r.intVal < 0) {
        diags_.error(b->line, b->col,
                     "the right operand of pow must not be negative");
        constReported_ = true;
        return false;
      }
      long long acc = 1;
      for (long long k = 0; k < r.intVal; ++k)
        if (!foldIntOp(acc, l.intVal, BinOp::Mul, b->line, b->col, acc))
          return false;
      out.type = ty::Int();
      out.intVal = acc;
      return true;
    }
    long long v = 0;
    if (!foldIntOp(l.intVal, r.intVal, b->op, b->line, b->col, v))
      return false;
    out.type = ty::Int();
    out.intVal = v;
    return true;
  }
  case BinOp::And:
  case BinOp::AndThen:
  case BinOp::Or:
  case BinOp::OrElse:
    if (!l.type->isBoolean() || !r.type->isBoolean())
      return false;
    out.type = ty::Bool();
    out.boolVal = (b->op == BinOp::And || b->op == BinOp::AndThen)
                      ? (l.boolVal && r.boolVal)
                      : (l.boolVal || r.boolVal);
    return true;
  case BinOp::Eq:
  case BinOp::Ne:
  case BinOp::Lt:
  case BinOp::Le:
  case BinOp::Gt:
  case BinOp::Ge: {
    // §6.8.3.5 compares values of one type, and the ordinal is what a folded
    // comparison has of either.
    if (!l.type->isOrdinal() || !r.type->isOrdinal())
      return false;
    if (l.type->base() != r.type->base() && !(l.type->isInteger() &&
                                              r.type->isInteger()))
      return false;
    long long a = ordinalOf(l), c = ordinalOf(r);
    out.type = ty::Bool();
    switch (b->op) {
    case BinOp::Eq: out.boolVal = a == c; break;
    case BinOp::Ne: out.boolVal = a != c; break;
    case BinOp::Lt: out.boolVal = a < c; break;
    case BinOp::Le: out.boolVal = a <= c; break;
    case BinOp::Gt: out.boolVal = a > c; break;
    default:        out.boolVal = a >= c; break;
    }
    return true;
  }
  default:
    return false;
  }
}

/// §6.8.2 c) excludes a function declared by the program and the two required
/// functions `eof` and `eoln`; NOTE 1 excludes the ones that take a variable —
/// `empty`, `position`, `LastPosition` — and says why: they need a variable as
/// a parameter. Every other required function is nonvarying and belongs in a
/// constant-expression.
///
/// Eight are refused anyway, and for one reason between them: a real constant
/// is carried as the text that was written and is never converted to a number
/// here, so `trunc` and `round` would need a conversion and `sqrt` and the
/// five transcendentals a formatter besides. That is a restriction of this
/// processor rather than of the clause, so it says which rather than reporting
/// the expression as not constant. `substr` is refused for the neighbouring
/// reason: its result is a string, which has no scalar form to fold to.
bool Sema::evalConstCall(Call *c, Symbol &out) {
  if (c->args.empty() || c->args.size() > 2)
    return false;
  Symbol a;
  if (!evalConst(c->args[0].get(), a) || !a.type)
    return false;

  auto ordinal = [&](const Symbol &s) -> long long {
    if (s.type->isChar())
      return static_cast<unsigned char>(s.charVal);
    if (s.type->base()->kind == TypeKind::Boolean)
      return s.boolVal ? 1 : 0;
    return s.intVal;
  };

  // §6.7.6.4's succ(x,k) and pred(x,k), which the clause defines as
  // succ(x,-(k)). Nonvarying exactly as the one-argument forms are, and
  // refused only because this walked a single argument.
  if (c->args.size() == 2) {
    if (c->builtin != Builtin::Succ && c->builtin != Builtin::Pred)
      return false;
    Symbol b;
    if (!evalConst(c->args[1].get(), b) || !b.type)
      return false;
    if (!a.type->isOrdinal() || !b.type->isInteger())
      return false;
    long long v = ordinal(a);
    long long k = c->builtin == Builtin::Pred ? -b.intVal : b.intVal;
    long long lo = a.type->base()->ordinalLo();
    long long hi = a.type->base()->ordinalHi();
    if (v + k > hi || v + k < lo) {
      diags_.error(c->line, c->col,
                   std::string(c->builtin == Builtin::Succ ? "succ" : "pred") +
                       " runs past the end of " + a.type->name() +
                       " in a constant expression");
      constReported_ = true;
      return false;
    }
    v += k;
    out = a;
    if (a.type->isChar())
      out.charVal = static_cast<char>(v);
    else if (a.type->base()->kind == TypeKind::Boolean)
      out.boolVal = v != 0;
    else
      out.intVal = v;
    return true;
  }

  switch (c->builtin) {
  case Builtin::Abs:
  case Builtin::Sqr: {
    if (!a.type->isInteger())
      return false;
    long long v = 0;
    if (c->builtin == Builtin::Abs)
      v = a.intVal < 0 ? -a.intVal : a.intVal;
    else if (!foldIntOp(a.intVal, a.intVal, BinOp::Mul, c->line, c->col, v))
      return false;
    out.type = ty::Int();
    out.intVal = v;
    return true;
  }
  case Builtin::Odd:
    if (!a.type->isInteger())
      return false;
    out.type = ty::Bool();
    // The emitted code masks the low bit, which is what makes `odd(-3)` true;
    // C's `%` would answer -1 and compare false.
    out.boolVal = (a.intVal & 1) != 0;
    return true;
  case Builtin::Ord:
    if (!a.type->isOrdinal())
      return false;
    out.type = ty::Int();
    out.intVal = ordinal(a);
    return true;
  case Builtin::Chr: {
    if (!a.type->isInteger())
      return false;
    if (a.intVal < 0 || a.intVal > 255) {
      diags_.error(c->line, c->col,
                   "chr of a value outside 0..255 in a constant expression");
      constReported_ = true;
      return false;
    }
    out.type = ty::Char();
    out.charVal = static_cast<char>(a.intVal);
    return true;
  }
  case Builtin::Succ:
  case Builtin::Pred: {
    if (!a.type->isOrdinal())
      return false;
    long long v = ordinal(a);
    // The ends are the *host's* (§6.6.6.4 with §6.7.1), so a subrange does not
    // stop succ — only an enumeration does, having no host. The end is tested
    // *before* the step, because at maxint the step itself would overflow —
    // the same reason the emitted code checks first, and what lets the
    // Pascal-hosted folder reach the same answer without a wider type.
    bool up = c->builtin == Builtin::Succ;
    if ((up && v >= a.type->base()->ordinalHi()) ||
        (!up && v <= a.type->base()->ordinalLo())) {
      diags_.error(c->line, c->col,
                   std::string(c->builtin == Builtin::Succ ? "succ" : "pred") +
                       " runs past the end of " + a.type->name() +
                       " in a constant expression");
      constReported_ = true;
      return false;
    }
    v += up ? 1 : -1;
    out = a;
    if (a.type->isChar())
      out.charVal = static_cast<char>(v);
    else if (a.type->base()->kind == TypeKind::Boolean)
      out.boolVal = v != 0;
    else
      out.intVal = v;
    return true;
  }
  // §6.7.6.7's length. A string constant is its literal, named (ADR-0068), so
  // the length is the literal's — and §6.4.3.3.1 gives the char-type "length 1
  // and capacity 1", which is why a one-character literal, already a CharLit,
  // answers 1 rather than falling through.
  case Builtin::Length:
    if (a.type->isChar()) {
      out.type = ty::Int();
      out.intVal = 1;
      return true;
    }
    if (auto *lit = a.constValue ? as<StrLit>(a.constValue) : nullptr) {
      out.type = ty::Int();
      out.intVal = static_cast<long long>(lit->value.size());
      return true;
    }
    return false;
  // Nonvarying by §6.8.2 and not evaluable here: these say which, because "the
  // expression is not constant" would be a complaint about the program.
  case Builtin::Sqrt:
  case Builtin::Sin:
  case Builtin::Cos:
  case Builtin::Ln:
  case Builtin::Exp:
  case Builtin::ArcTan:
  case Builtin::Trunc:
  case Builtin::Round:
    diags_.error(c->line, c->col,
                 "a real constant expression is not folded: a real constant "
                 "is carried as the text that was written and never converted");
    constReported_ = true;
    return false;
  default:
    return false;
  }
}

// --------------------------------------------------------------- statements

void Sema::checkStmt(Stmt *s) {
  if (!s || as<EmptyStmt>(s))
    return;

  if (auto *c = as<Compound>(s)) {
    // A compound statement is a statement-sequence, and §6.8.1 is stated over
    // those — so it joins the path like any other statement that contains
    // one, and a goto into a `begin ... end` from outside it is refused. It is
    // one of the three places `seq` is true.
    stmtPath_.push_back({c, true});
    for (auto &sub : c->body)
      checkStmt(sub.get());
    stmtPath_.pop_back();
    return;
  }

  if (auto *g = as<GotoStmt>(s)) {
    checkGoto(g);
    return;
  }

  if (auto *l = as<LabeledStmt>(s)) {
    checkLabeled(l);
    return;
  }

  if (auto *a = as<Assign>(s)) {
    bool badFunc = false;
    // Assigning to a function's own name sets its result (ISO 7185 §6.8.2.2),
    // so it is redirected before the target is otherwise resolved. Reading the
    // name, by contrast, is a recursive call — see checkExpr. Only a bare
    // name can mean this.
    if (auto *ref = as<VarRef>(a->target.get())) {
      Symbol *named = lookup(ref->name);
      if (named && named->kind != SymKind::Func)
        named = nullptr;
      // §6.8.2.2: "The function-block associated with the function-identifier
      // of an assignment-statement shall *contain* the assignment-statement."
      // Contain, not be — a procedure nested inside f may write f's result,
      // reaching it through the static chain as it reaches any enclosing
      // variable — so the test is the owner chain and not `== current_`. A
      // sibling function's name, or a nested one's from outside it, is
      // refused. Clearing `named` then leaves the ordinary variable path to
      // run, and `assignedResult` is deliberately *not* set: a function whose
      // only assignment is a sibling's still never assigns its own.
      if (named) {
        Symbol *owning = current_;
        while (owning && owning != named)
          owning = owning->owner;
        if (!owning) {
          diags_.error(a->line, a->col,
                       "'" + ref->name + "' is not this block's function, so "
                       "its result cannot be assigned here");
          named = nullptr;
          badFunc = true;
        }
      }
      if (named) {
        ref->sym = named->resultVar;
        ref->type = named->type;
        named->assignedResult = true;
        checkExpr(a->value.get());
        if (named->resultNamed)
          // §6.7.2: with a result-variable-specification the block "shall
          // contain no assignment-statement" to the function-identifier. The
          // two spellings would mean the same storage, so this is not about
          // ambiguity — it is the standard keeping one name for one thing.
          diags_.error(a->line, a->col,
                       "'" + ref->name + "' names a result variable, so assign "
                       "to that instead of to the function");
        else if (!named->resultVar)
          diags_.error(a->line, a->col,
                       "'" + ref->name + "' is not a function with a result");
        else if (!assignable(ref->type, a->value->type))
          diags_.error(a->line, a->col,
                       "cannot assign " + a->value->type->name() +
                           " to a result of type " + ref->type->name() +
                           distinctTypeNote(ref->type, a->value->type));
        return;
      }
    }

    checkExpr(a->target.get());
    checkExpr(a->value.get());
    // §6.9.4 a): an assignment-statement threatens its target.
    checkNotThreatened(a->target.get(), "it cannot be assigned to");
    // `badFunc` means §6.8.2.2 has already reported this target, and what is
    // left to say about it — that a function identifier is not a variable — is
    // a consequence of that fault rather than a second one (ADR-0054).
    if (!isDesignator(a->target.get()) && !badFunc)
      diags_.error(a->target->line, a->target->col,
                   "the left side of an assignment must be a variable");
    // Without this the message would read "cannot assign text to a variable of
    // type text", which describes the rule accurately and explains nothing.
    else if (a->target->type && a->target->type->isFile())
      diags_.error(a->line, a->col,
                   "a file variable cannot be assigned to; use reset, rewrite "
                   "and the buffer variable");
    else if (!assignable(a->target->type, a->value->type)) {
      // The refusal is `assignable`'s; this only chooses the words, and it is
      // asked *inside* the failure rather than ahead of it so that the
      // predicate stays the thing being tested — a guard placed before the
      // call masks it at the only site that reaches it, which is how
      // ADR-0143's slice arm came to be removable with every case green.
      //
      // §6.4.6 a)'s second condition rendered through the general message
      // reads "cannot assign r to a variable of type r": accurate, and saying
      // nothing about the file inside r. The words are the ones a value
      // parameter of such a type is already refused with, because it is one
      // fact. Named on whichever side holds the file.
      if (containsFile(a->target->type) || containsFile(a->value->type))
        diags_.error(a->line, a->col,
                     "cannot assign " +
                         (containsFile(a->value->type) ? a->value->type
                                                       : a->target->type)
                             ->name() +
                         ": it contains a file, and a file has no copy");
      else
        diags_.error(a->line, a->col,
                     "cannot assign " + a->value->type->name() +
                         " to a variable of type " + a->target->type->name() +
                         distinctTypeNote(a->target->type, a->value->type));
    }
    return;
  }

  if (auto *w = as<WithStmt>(s)) {
    checkWith(w);
    return;
  }

  if (auto *c = as<CaseStmt>(s)) {
    checkCase(c);
    return;
  }

  if (auto *w = as<WriteStmt>(s)) {
    checkWrite(w);
    return;
  }

  if (auto *r = as<ReadStmt>(s)) {
    checkRead(r);
    return;
  }

  if (auto *p = as<ProcCallStmt>(s)) {
    if (!p->qualifier.empty()) {
      Symbol *sym = lookupName(p->qualifier, p->name, p->line, p->col);
      if (!sym)
        return;
      if (!sym->isInvocable() || sym->resultType()) {
        diags_.error(p->line, p->col,
                     "'" + p->qualifier + "." + p->name +
                         "' is not a procedure");
        return;
      }
      p->sym = sym;
      checkArguments(sym, p->args, p->line, p->col);
      return;
    }
    Symbol *sym = lookup(p->name);
    // A user-declared procedure of the same name wins, exactly as it does for
    // the required functions in checkCall.
    // `pack`, `unpack` and `page` are ISO 7185's own (§6.6.5.4, §6.9.5), so
    // they are recognised under both standards rather than behind the
    // Extended-only gate below — ISO/IEC 10206:1991 §6.7.5.4 and §6.9.5 keep
    // all three (ADR-0067).
    if (!sym &&
        (p->name == "new" || p->name == "dispose" || p->name == "reset" ||
         p->name == "rewrite" || p->name == "get" || p->name == "put" ||
         p->name == "pack" || p->name == "unpack" || p->name == "page" ||
         (std_ == Std::Extended && isRequiredProc(p->name)))) {
      checkStdProc(p);
      return;
    }
    if (!sym) {
      diags_.error(p->line, p->col, "unknown procedure '" + p->name + "'");
      return;
    }
    if (!sym->isInvocable() || sym->resultType()) {
      diags_.error(p->line, p->col,
                   "'" + p->name + "' is not a procedure");
      return;
    }
    p->sym = sym;
    checkArguments(sym, p->args, p->line, p->col);
    return;
  }

  if (auto *i = as<IfStmt>(s)) {
    checkExpr(i->cond.get());
    if (i->cond->type && !i->cond->type->isBoolean())
      diags_.error(i->cond->line, i->cond->col,
                   "the condition of an if statement must be boolean");
    stmtPath_.push_back({i, false});
    checkStmt(i->thenBranch.get());
    checkStmt(i->elseBranch.get());
    stmtPath_.pop_back();
    return;
  }

  if (auto *w = as<WhileStmt>(s)) {
    checkExpr(w->cond.get());
    if (w->cond->type && !w->cond->type->isBoolean())
      diags_.error(w->cond->line, w->cond->col,
                   "the condition of a while statement must be boolean");
    stmtPath_.push_back({w, false});
    checkStmt(w->body.get());
    stmtPath_.pop_back();
    return;
  }

  if (auto *r = as<RepeatStmt>(s)) {
    stmtPath_.push_back({r, true}); // a repeat-statement holds a sequence
    for (auto &sub : r->body)
      checkStmt(sub.get());
    stmtPath_.pop_back();
    checkExpr(r->cond.get());
    if (r->cond->type && !r->cond->type->isBoolean())
      diags_.error(r->cond->line, r->cond->col,
                   "the condition of a repeat statement must be boolean");
    return;
  }

  if (auto *f = as<ForStmt>(s)) {
    checkExpr(f->var.get());
    // ISO 7185 §6.8.3.9 requires an entire variable declared in this block, so
    // a field reached through an enclosing `with` will not do either.
    if (f->var->withField)
      diags_.error(f->var->line, f->var->col,
                   "the control variable of a for statement cannot be a field "
                   "of a with statement");
    // §6.8.3.9 does not merely say "a variable": "The control-variable shall
    // be an entire-variable whose identifier is declared in the
    // variable-declaration-part of the block closest-containing the
    // for-statement" — ISO/IEC 10206:1991 §6.9.3.9.2 word for word, but for
    // "a variable-declaration-part", that standard letting the parts repeat.
    // So a parameter is refused, and so is a variable of an enclosing block or
    // one reached through an interface, and the message has to say which rule
    // it is: a value parameter *is* a variable, so "must be a variable" would
    // be naming something that is not the complaint.
    //
    // `current_` is the block whose statements these are, which is what the
    // clause means by closest-containing: a nested procedure's body is walked
    // with `current_` set to that procedure.
    else if (f->var->sym && (f->var->sym->kind != SymKind::Var ||
                             f->var->sym->owner != current_))
      diags_.error(f->var->line, f->var->col,
                   "the control variable of a for statement must be a variable "
                   "declared in the block containing the statement");
    // §6.8.3.9's threats are about *the* control-variable, so they are only
    // asked once the name can be one. Anything refused above has been reported
    // already, and asking a second question of it would report a consequence
    // of the first — including, for a variable belonging to an enclosing
    // block, a threat this very statement had just recorded against it.
    if (!f->var->withField && f->var->sym &&
        f->var->sym->kind == SymKind::Var && f->var->sym->owner == current_) {
      // Threat d): the equivalent program fragment the clause gives a
      // for-statement assigns to the control-variable, so a nested
      // for-statement over the same variable threatens the one containing it.
      // The outer loop is pushed by the time this is reached and this one is
      // not — its own push is below — so no loop reports itself.
      if (activeControl(f->var->sym))
        checkNotThreatened(f->var.get(),
                           "it cannot be the control variable of another one");
      // The other half of the clause: "Neither a for-statement nor any
      // procedure-and-function-declaration-part of the block that
      // closest-contains a for-statement shall contain a statement threatening
      // the variable". That part is walked before the statements that loop, so
      // the threat is already recorded. The message names the threat's line
      // because the declaration is not where the reader will look — the
      // statement is legal until this loop makes it not.
      if (f->var->sym->threatLine > 0)
        diags_.error(f->var->line, f->var->col,
                     "'" + f->var->sym->name + "' is threatened by a statement "
                     "at line " + std::to_string(f->var->sym->threatLine) +
                     ", so it cannot be the control variable of a for "
                     "statement");
    }
    if (f->var->type && !f->var->type->isOrdinal())
      diags_.error(f->var->line, f->var->col,
                   "the control variable of a for statement must be an "
                   "ordinal type");
    if (f->set) {
      // ISO/IEC 10206:1991 §6.9.3.9.3: "The set-expression ... shall possess
      // an unpacked-canonical-set-of-T-type or a packed-canonical-set-of-T-
      // type. The type of the control-variable of the for-statement shall be
      // compatible with T."
      checkExpr(f->set.get());
      Type *st = f->set->type;
      if (st && !st->isSet())
        diags_.error(f->set->line, f->set->col,
                     "a for statement iterates over a set, not over " +
                         st->name());
      else if (st && st->elem && f->var->type &&
               !assignable(f->var->type, st->elem))
        diags_.error(f->set->line, f->set->col,
                     "the control variable of a for statement is " +
                         f->var->type->name() + ", so it cannot take the " +
                         "members of a " + st->name());
      // §6.9.3.9.3 makes the *members* assignment-compatible rather than the
      // set, so a control variable narrower than the base type is legal and
      // D.96 makes a member outside it an error — checked at the store, by
      // the code every other store already goes through.

      // The ordinal counter CodeGen walks the base type's values with. A frame
      // slot is Sema's to give, so it is given here; and it is given per
      // *statement*, so two for-in statements — nested or merely adjacent —
      // cannot share one (ADR-0102).
      if (current_)
        f->counter =
            addHiddenVar("for$" + std::to_string(current_->frameVars.size()),
                         SymKind::Var, ty::Int(), current_);
    } else {
      checkExpr(f->from.get());
      checkExpr(f->to.get());
      if (!assignable(f->var->type, f->from->type) ||
          !assignable(f->var->type, f->to->type))
        diags_.error(f->line, f->col,
                     "the bounds of a for statement must match the type of the "
                     "control variable");
    }
    stmtPath_.push_back({f, false});
    // §6.8.3.9 forbids a *statement* of the for-statement to threaten the
    // control-variable, and the bounds are expressions — so the binding covers
    // the body and nothing else.
    bool bound = f->var->sym != nullptr;
    if (bound)
      forControls_.push_back(f->var->sym);
    checkStmt(f->body.get());
    if (bound)
      forControls_.pop_back();
    stmtPath_.pop_back();
    return;
  }
}

// -------------------------------------------------------------- expressions

// ------------------------------------------- structured-value-constructors

/// ISO/IEC 10206:1991 §6.8.7. A structured-value-constructor is a primary that
/// denotes a value of a named structured type, and a component-value nested
/// inside one is the same node with no type-name — it takes the type of the
/// component it is for. `want` is that type, and is null at the top.
///
/// The whole feature is a completeness argument: §6.8.7.2 NOTE and §6.8.7.3
/// NOTE 2 both say every component must be specified, exactly once. So each of
/// the two forms below does the same three things — resolve each selector,
/// check each component-value against the type it lands in, and then ask
/// whether anything was left out.
void Sema::checkStructValue(StructValueExpr *e, Type *want) {
  Type *t = want;
  if (!e->typeName.empty()) {
    t = nullptr;
    {
      Symbol *s = lookup(e->typeName);
      if (!s)
        diags_.error(e->line, e->col,
                     "undeclared identifier '" + e->typeName + "'");
      else if (s->kind != SymKind::Type)
        diags_.error(e->line, e->col,
                     "'" + e->typeName +
                         "' is not a type, so it cannot name "
                         "a structured value");
      else
        t = s->type;
    }
  } else if (!t) {
    // A nested component-value whose parent could not be typed. The parent has
    // already reported why, so this one says nothing (ADR-0054's principle).
  }

  // Whatever happens, the node leaves here with a type: CodeGen may not see a
  // null one (ADR-0008), and a placeholder is what an error path gives it.
  e->type = t ? t : ty::Int();
  if (!t)
    return;

  // §6.8.7.1: "That type shall be a type that is permissible as the
  // component-type of a file-type" — which is `containsFile` exactly, the same
  // predicate §6.4.3.6's component check asks (ADR-0031).
  if (t->isFile() || containsFile(t)) {
    diags_.error(e->line, e->col,
                 "a structured value cannot be of type " + t->name() +
                     ", because it contains a file");
    return;
  }

  // §6.8.7.4's set-value, in the one spelling that reaches the parser as a
  // structured value: `digits[]`. An empty bracket cannot be a subscript list,
  // so it arrives here whatever the name turns out to denote — and for a set
  // type it is the null-set-value, which is the thing `[]` alone cannot spell,
  // having no type of its own (ADR-0066). Every other spelling was recognised
  // in `checkExpr` from the subscript spine the parser built instead.
  if (t->isSet()) {
    if (!e->elems.empty() || e->tagValue || e->variant)
      diags_.error(e->line, e->col,
                   "a value of type " + t->name() +
                       " holds members, not components");
    return;
  }

  if (t->isArray())
    checkArrayValue(e, t);
  else if (t->isRecord())
    checkRecordValue(e, t, {});
  else {
    diags_.error(e->line, e->col,
                 "a structured value needs an array, a record or a set type, "
                 "not " +
                     t->name());
    return;
  }

  // An array and a record have no register form (ADR-0017), so the value needs
  // storage — the hidden frame slot ADR-0055 gives a memory-living result. A
  // *nested* value has none: it is built directly into its parent's.
  if (!e->typeName.empty() || want == nullptr)
    e->resultSlot = newResultSlot(t);
}

/// One component-value: a nested array- or record-value takes the component
/// type, and anything else is an expression that must be assignment-compatible
/// with it (§6.8.7.1).
void Sema::checkComponentValue(Expr *v, Type *component, const char *what) {
  if (auto *nested = as<StructValueExpr>(v)) {
    checkStructValue(nested, component);
    return;
  }
  checkExpr(v);
  if (component && v->type && !assignable(component, v->type))
    diags_.error(v->line, v->col,
                 "a value of type " + v->type->name() + " cannot be " + what +
                     " of type " + component->name());
}

/// §6.8.7.2's array-value. The selector is a case-constant-list in the
/// standard's own words, so it is folded and overlap-checked by the very
/// functions the case statement and the variant part share (ADR-0035).
void Sema::checkArrayValue(StructValueExpr *e, Type *t) {
  // A dynamically bounded array has no compile-time extent, so "every
  // component is specified" is not a question this compiler can answer. It is
  // refused rather than half-checked (ADR-0061).
  if (t->dynamicBounds()) {
    diags_.error(e->line, e->col,
                 "a structured value cannot be of type " + t->name() +
                     ", because its bounds are not known until it is created");
    return;
  }
  Type *index = t->indexType;
  Type *component = t->elem;
  long long lo = index ? index->ordinalLo() : 0;
  long long hi = index ? index->ordinalHi() : -1;

  std::vector<LabelRange> seen;
  long long covered = 0;
  bool completer = false;
  for (size_t k = 0; k < e->elems.size(); ++k) {
    ValueElem &el = e->elems[k];
    if (el.completer) {
      // The grammar puts the completer last and lets nothing follow it, which
      // is a rule about this list rather than about any one element.
      if (k + 1 != e->elems.size())
        diags_.error(el.line, el.col,
                     "nothing may follow the 'otherwise' of an array value");
      completer = true;
      checkComponentValue(el.value.get(), component, "a component");
      continue;
    }
    for (CaseLabel &label : el.labels) {
      Type *lt = index;
      LabelRange r;
      long long clash = 0;
      if (!evalLabelRange(label,
                          "an array value's selector must be an ordinal "
                          "constant",
                          lt, r))
        continue;
      if (index && !assignable(index, lt)) {
        diags_.error(label.lo->line, label.lo->col,
                     "an array value's selector must be of the index type " +
                         index->name());
        continue;
      }
      if (r.lo < lo || r.hi > hi) {
        diags_.error(label.lo->line, label.lo->col,
                     "an array value's selector is outside the index type " +
                         (index ? index->name() : std::string("?")));
        continue;
      }
      if (overlaps(seen, r, clash)) {
        diags_.error(label.lo->line, label.lo->col,
                     "this component of the array value is given twice");
        continue;
      }
      seen.push_back(r);
      covered += r.hi - r.lo + 1;
      el.values.push_back(r);
    }
    checkComponentValue(el.value.get(), component, "a component");
  }

  // §6.8.7.2 b): "If there is at least one such component, there shall be an
  // array-value-completer." The count is exact because the ranges are known to
  // be disjoint by the time it is taken.
  if (!completer && hi >= lo && covered != hi - lo + 1)
    diags_.error(e->line, e->col,
                 "this array value leaves components unspecified, and has no "
                 "'otherwise' to give them a value");
}

/// §6.8.7.3's record-value, over the field-list at `path` — the record's own
/// when the path is empty, and an arm's when a variant-part-value has stepped
/// into one. §6.4.3.3 makes an arm's field-list a field-list like any other,
/// so this function is the one that walks both (ADR-0026).
void Sema::checkRecordValue(StructValueExpr *e, Type *t,
                            const std::vector<int> &path) {
  const std::vector<Field> &fields = t->fieldsAt(path);
  const std::vector<Variant> &arms = t->armsAt(path);
  int tagField = t->tagFieldAt(path);

  std::vector<bool> given(fields.size(), false);
  for (ValueElem &el : e->elems) {
    if (el.completer) {
      diags_.error(el.line, el.col,
                   "'otherwise' belongs to an array value, not a record value");
      continue;
    }
    // The parser read every selector as an expression, because `[a: 1]` is an
    // array value when `a` is a constant and a record value when it is a field
    // name. Here the type has answered, so a selector must be a bare name.
    Type *component = nullptr;
    for (CaseLabel &label : el.labels) {
      auto *name = as<VarRef>(label.lo.get());
      if (!name || label.hi) {
        diags_.error(label.lo->line, label.lo->col,
                     "a record value needs field names before the ':'");
        continue;
      }
      int at = -1;
      for (size_t i = 0; i < fields.size(); ++i)
        if (fields[i].name == name->name)
          at = static_cast<int>(i);
      if (at < 0) {
        // Naming a field of another field-list is worth its own words: the
        // record has the field, but not *here*, and §6.8.7.3 requires the
        // field-list-value to correspond to the field-list.
        if (t->findField(name->name))
          diags_.error(name->line, name->col,
                       "'" + name->name + "' is not a field of this part of " +
                           t->name() +
                           "; a variant's fields belong to its own "
                           "value");
        else
          diags_.error(name->line, name->col,
                       "'" + name->name + "' is not a field of " + t->name());
        continue;
      }
      if (at == tagField) {
        diags_.error(name->line, name->col,
                     "the tag field '" + name->name +
                         "' is given by the "
                         "'case' of the variant part, not as a field value");
        continue;
      }
      if (given[at]) {
        diags_.error(name->line, name->col,
                     "the field '" + name->name + "' is given twice");
        continue;
      }
      given[at] = true;
      el.fieldIndex.push_back(fields[at].index);
      // A field-identifier is not a variable-access, so nothing resolved it —
      // but ADR-0008 says every expression leaves Sema with a type, and the
      // field's is the only honest answer.
      name->type = fields[at].type;
      // §6.8.7.3 NOTE 1: one field-value's identifiers all denote components
      // of one type, because the component-value has a single type.
      if (component && component != fields[at].type)
        diags_.error(name->line, name->col,
                     "'" + name->name + "' has type " +
                         fields[at].type->name() +
                         ", but the fields before it in this value have type " +
                         component->name());
      else
        component = fields[at].type;
    }
    checkComponentValue(el.value.get(), component, "the value of a field");
  }

  for (size_t i = 0; i < fields.size(); ++i)
    if (!given[i] && static_cast<int>(i) != tagField)
      diags_.error(e->line, e->col,
                   "the field '" + fields[i].name + "' of " + t->name() +
                       " has no value in this record value");

  checkVariantPartValue(e, t, path, arms, fields, tagField);
}

/// §6.8.7.3's variant-part-value. The tag value chooses the arm, and the arm's
/// field-list-value is checked by `checkRecordValue` again — which is what
/// makes a variant part inside a variant part cost nothing (ADR-0026).
void Sema::checkVariantPartValue(StructValueExpr *e, Type *t,
                                 const std::vector<int> &path,
                                 const std::vector<Variant> &arms,
                                 const std::vector<Field> &fields,
                                 int tagField) {
  if (arms.empty()) {
    if (e->tagValue)
      diags_.error(e->tagValue->line, e->tagValue->col,
                   "this part of " + t->name() +
                       " has no variant part, so a "
                       "record value for it cannot select one");
    return;
  }
  if (!e->tagValue) {
    diags_.error(e->line, e->col,
                 "this record value must select a variant of " + t->name() +
                     ", with 'case'");
    return;
  }
  // §6.8.7.3: "A tag-field-identifier in a variant-part-value shall be the
  // field-identifier associated with the selector." A tagless variant part has
  // no such identifier, so writing one is an error rather than a redundancy.
  if (!e->tagField.empty()) {
    if (tagField < 0)
      diags_.error(e->line, e->col,
                   "this variant part has no tag field, so '" + e->tagField +
                       "' names nothing");
    else if (fields[tagField].name != e->tagField)
      diags_.error(e->line, e->col,
                   "the tag field of this variant part is '" +
                       fields[tagField].name + "', not '" + e->tagField + "'");
  }

  CaseLabel tag;
  tag.lo = std::move(e->tagValue);
  Type *tt = t->tagTypeAt(path);
  Type *lt = tt;
  LabelRange r;
  bool ok = evalLabelRange(
      tag, "a variant part's tag value must be an ordinal constant", lt, r);
  e->tagValue = std::move(tag.lo);
  if (!ok)
    return;
  if (tt && !assignable(tt, lt)) {
    diags_.error(e->tagValue->line, e->tagValue->col,
                 "a variant part's tag value must be of type " + tt->name());
    return;
  }

  int chosen = -1, completer = -1;
  for (size_t i = 0; i < arms.size(); ++i) {
    if (arms[i].isOtherwise) {
      completer = static_cast<int>(i);
      continue;
    }
    for (const LabelRange &label : arms[i].labels)
      if (r.lo >= label.lo && r.lo <= label.hi)
        chosen = static_cast<int>(i);
  }
  if (chosen < 0)
    chosen = completer;
  if (chosen < 0) {
    diags_.error(e->tagValue->line, e->tagValue->col,
                 "no variant of " + t->name() +
                     " is selected by this tag "
                     "value");
    return;
  }
  e->armIndex = chosen;
  e->tagOrdinal = r.lo;

  std::vector<int> sub = path;
  sub.push_back(chosen);
  // The arm's field-list-value is a value of the record's own type: it fills
  // in part of the same variable. Saying so keeps ADR-0008's invariant, and
  // `checkRecordValue` is entered directly because the arm is a field-list
  // rather than a type and has nothing else to decide.
  e->variant->type = t;
  checkRecordValue(as<StructValueExpr>(e->variant.get()), t, sub);
}

void Sema::checkExpr(Expr *e) {
  if (!e)
    return;

  if (as<IntLit>(e))  { e->type = ty::Int();  return; }
  if (as<RealLit>(e)) { e->type = ty::Real(); return; }
  if (as<CharLit>(e)) { e->type = ty::Char(); return; }

  if (auto *s = as<StrLit>(e)) {
    // ISO 7185 §6.4.3.2: a string literal *is* a packed array of char. Giving
    // it that type rather than a type of its own is what makes assignment,
    // comparison and parameter passing work with no special cases anywhere.
    // ISO/IEC 10206:1991 §6.1.9 writes `character-string = ''' { string-element
    // } '''` — braces, so *zero* elements are allowed and `''` denotes the
    // null-string §6.4.3.3.1 names. ISO 7185's grammar has one element and then
    // the braces, which is why the two languages differ over two apostrophes
    // and nothing else.
    if (s->value.empty()) {
      if (std_ == Std::Iso7185) {
        diags_.error(s->line, s->col, "a string literal cannot be empty");
        s->type = stringType(1);
        return;
      }
      s->type = ty::CanonicalString();
      return;
    }
    s->type = stringType(static_cast<long long>(s->value.size()));
    return;
  }

  if (auto *sv = as<StructValueExpr>(e)) {
    checkStructValue(sv, nullptr);
    return;
  }

  if (auto *idx = as<IndexExpr>(e)) {
    // §6.8.7.4's set-value shares its tokens with a subscript, so the question
    // is asked before the base is checked — `digits` is a type name, and
    // checking it as a value would report it as one (ADR-0066).
    if (Type *named = setValueTypeOf(idx)) {
      checkSetValue(idx, named);
      return;
    }
    checkExpr(idx->base.get());
    checkExpr(idx->index.get());
    refuseConstAccess(idx->base.get(), idx->line, idx->col);
    Type *base = idx->base->type;
    // §6.4.3.3.3 NOTE 1: a variable-string is indexed as an array, and every
    // component is a char. §6.5.3.2 makes the subscript an *integer* — not a
    // value of an index type, because a string's index-domain is 1..length
    // and no type names it.
    if (base && base->isVarString()) {
      if (idx->index->type && !idx->index->type->isInteger())
        diags_.error(idx->index->line, idx->index->col,
                     "a string is indexed by an integer, but the subscript is " +
                         idx->index->type->name());
      e->type = ty::Char();
      return;
    }
    if (!base || !base->isArray()) {
      if (base)
        diags_.error(idx->line, idx->col,
                     "cannot subscript a value of type " + base->name());
      e->type = ty::Int();
      return;
    }
    if (idx->index->type && !assignable(base->indexType, idx->index->type))
      diags_.error(idx->index->line, idx->index->col,
                   "this array is indexed by " + base->indexType->name() +
                       ", but the subscript is " + idx->index->type->name());
    e->type = base->elem;
    return;
  }

  // ISO/IEC 10206:1991 §6.5.6's substring-variable and §6.8.6.5's
  // substring-function-access, which are one node here because they differ
  // only in what the base is — and `isDesignator` already asks the base that.
  if (auto *sub = as<SubstringExpr>(e)) {
    // The same question, for the same reason: `digits[1..3]` is a set-value
    // whose one member is a range, and it reaches here rather than the arm
    // above because a `..` is what the parser saw first.
    if (Type *named = setValueTypeOf(sub)) {
      checkSetValue(sub, named);
      return;
    }
    // §6.5.6's substring-variable is one range and nothing else. The parser
    // admits a list after it because §6.8.7.4's set-value needs one, and this
    // is where that permission is taken back from everything that is not one.
    if (sub->listed)
      diags_.error(sub->line, sub->col,
                   "a substring takes one range and nothing after it");
    checkExpr(sub->base.get());
    checkExpr(sub->lo.get());
    checkExpr(sub->hi.get());
    Type *base = sub->base->type;
    // §6.5.6 takes a string-*variable* and §6.8.6.5 a string-function; a char
    // is a string of length 1 (§6.4.3.3.1) but is not either of those, and
    // neither is a literal — a substring of a value nothing denotes has
    // nowhere to be.
    if (base && !base->isStringType()) {
      diags_.error(sub->line, sub->col,
                   "only a string can have a substring taken of it, not " +
                       base->name());
      e->type = ty::CanonicalString();
      return;
    }
    for (Expr *ix : {sub->lo.get(), sub->hi.get()})
      if (ix->type && !ix->type->isInteger())
        diags_.error(ix->line, ix->col,
                     "a substring is bounded by integers, but this one is " +
                         ix->type->name());
    // §6.5.6 makes it "a new fixed-string-type" of capacity `hi - lo + 1`.
    // That capacity is not a compile-time number, and the canonical-string-type
    // is exactly a pointer and a length (ADR-0051) — so the type carries what
    // is known and the length travels with the value.
    e->type = ty::CanonicalString();
    return;
  }

  if (as<NilLit>(e)) {
    e->type = ty::Nil();
    return;
  }

  if (auto *s = as<SetExpr>(e)) {
    checkSetExpr(s);
    return;
  }

  if (auto *d = as<DerefExpr>(e)) {
    checkExpr(d->base.get());
    Type *base = d->base->type;
    // §6.5.4 makes the pointer-variable of an identified-variable a
    // *variable-access*, and §6.5.1's four are an entire variable, a
    // component, an identified variable and a buffer variable — a
    // function-designator is none of them, and §6.8.2.2 makes a bare
    // function-identifier a recursive activation, so `f^` would dereference a
    // value. §6.8.6.4's function-identified-variable is Extended Pascal's
    // (ADR-0056), where a call *written with arguments* never reaches here
    // under ISO 7185 because `afterCall` does not offer it the selectors. A
    // parameterless function is a bare name and the parser cannot tell, so
    // this is where it is told.
    if (std_ != Std::Extended) {
      auto *v = as<VarRef>(d->base.get());
      if (is<Call>(d->base.get()) ||
          (v && v->sym && v->sym->isInvocable()))
        diags_.error(d->line, d->col,
                     "dereferencing a function result is an Extended Pascal "
                     "feature; compile with --std=extended");
    }
    // `f^` on a file is the buffer variable (ISO 7185 §6.5.5), not a
    // dereference: one component of the file, which for a text file is the
    // character the file is positioned at. The syntax is shared, so this is
    // the one place the two meanings part.
    if (base && base->isFile()) {
      e->type = base->elem ? base->elem : ty::Char();
      return;
    }
    if (!base || !base->isPointer() || base->isNil()) {
      // §6.4.4 gives a pointer-type one nil-value and a set of
      // identifying-values, and its NOTE 1 draws the consequence: "Since the
      // nil-value is not an identifying-value, it does not identify a
      // variable." So `nil^` is not a dereference of something that is not a
      // pointer — it is a pointer with nothing on the other end, and the
      // general message would be naming the wrong rule. Only reachable as a
      // written program since a constant may be `nil`.
      if (base && base->isNil())
        diags_.error(
            d->line, d->col,
            "nil identifies no variable, so it cannot be dereferenced");
      else if (base)
        diags_.error(d->line, d->col,
                     "only a pointer can be dereferenced, found " +
                         base->name());
      e->type = ty::Int();
      return;
    }
    e->type = base->elem;
    return;
  }

  if (auto *fld = as<FieldExpr>(e)) {
    // §6.11.3's qualified name. The syntax is a field selection and only the
    // symbol the base resolves to tells the two apart — so this is asked
    // before the base is checked, since an interface-identifier has no type
    // and checking it would report that first.
    if (auto *b = as<VarRef>(fld->base.get()))
      if (isInterfaceName(b->name)) {
        Symbol *sym = lookupName(b->name, fld->field, fld->line, fld->col);
        fld->qualified = sym;
        e->type = ty::Int();
        if (!sym)
          return;
        if (sym->kind == SymKind::Const || sym->isVariable()) {
          e->type = sym->type;
        } else if (sym->isInvocable() && sym->resultType()) {
          // A parameterless function written without an argument list. There
          // is no `Call` node to make here, so the selection itself is the
          // call and codegen emits one.
          if (!sym->params.empty()) {
            diags_.error(fld->line, fld->col,
                         "'" + b->name + "." + fld->field +
                             "' needs its arguments");
            return;
          }
          e->type = sym->resultType();
          fld->resultSlot = newResultSlot(e->type);
        } else {
          diags_.error(fld->line, fld->col,
                       "'" + b->name + "." + fld->field +
                           "' is not a value");
        }
        return;
      }
    checkExpr(fld->base.get());
    refuseConstAccess(fld->base.get(), fld->line, fld->col);
    Type *base = fld->base->type;
    // §6.8.4: `v.d` where v possesses a type produced from a schema and d is
    // one of that schema's formal discriminants. It is looked for before the
    // fields, because a record produced from a schema has both and the
    // discriminant is not one of them — the name is not in any scope, and this
    // is the only place it can be written.
    if (base && base->isSchematic()) {
      const std::vector<Symbol *> &ds = base->schema->discriminants;
      // A schematic formal parameter has no tuple: its discriminants are in
      // the descriptor the actual brought, and the parameter is what says
      // which descriptor. Everything else has folded them already.
      // A heap variable's tuple travels with the variable, so the symbol
      // holding its discriminants is on the *type* — there is no name to ask,
      // since `p^` is not one.
      Symbol *param = base->heapTuple ? base->descOwner
                      : base->isGeneric() ? baseSymbol(fld->base.get())
                                          : nullptr;
      for (size_t i = 0; i < ds.size(); ++i)
        if (ds[i]->name == fld->field) {
          if (base->isGeneric() && (!param || i >= param->discSyms.size()))
            break;
          fld->isDiscriminant = true;
          if (base->isGeneric())
            fld->discSym = param->discSyms[i];
          else if (i < base->tuple.size())
            fld->discValue = base->tuple[i];
          e->type = ds[i]->type;
          return;
        }
    }
    if (!base || !base->isRecord()) {
      if (base && base->isSchematic())
        // The dot after a schematic variable may select a field or a
        // discriminant, so saying only that the type has no fields would
        // describe the wrong half of what was tried.
        diags_.error(fld->line, fld->col,
                     "'" + fld->field + "' is not a discriminant of schema '" +
                         base->schema->name + "'");
      else if (base)
        diags_.error(fld->line, fld->col,
                     "cannot select a field of a value of type " +
                         base->name());
      e->type = ty::Int();
      return;
    }
    const Field *f = base->findField(fld->field);
    if (!f) {
      diags_.error(fld->line, fld->col,
                   "'" + fld->field + "' is not a field of " + base->name());
      e->type = ty::Int();
      return;
    }
    fld->resolved = f;
    e->type = f->type;
    return;
  }

  if (auto *v = as<VarRef>(e)) {
    // §6.4.3.3's region at a *constant* occurrence, which is the one kind
    // ADR-0112 left and the last program this compiler accepted that ISO 7185
    // requires it to reject. Inside a record's denoter a spelling that is one
    // of its fields is an applied occurrence of the field (§6.2.2.4), and a
    // field is not a value here — so `array [1..fred]` beside a field `fred`
    // names no constant, however the program declared `fred` outside.
    //
    // Asked *before* the lookup, for the reason the three type occurrences ask
    // before theirs: a field's defining-point is nearer than anything outside
    // the record, including the required identifiers.
    //
    // `schemaBody_` is what keeps it exact rather than approximately right. A
    // production written inside a record — `a: vec(2)` — makes the schema's
    // *body* be resolved again, and that body is lexically outside the record,
    // so a constant name in it is in no region of this one. The
    // actual-discriminant-part is not in the body and is still asked, which is
    // the half that matters (ADR-0134).
    if (!schemaBody_ && fieldOfOpenRecord("", v->name)) {
      errorFieldNotA(v->line, v->col, v->name, false);
      // The reason is given, so the caller's vaguer one is not.
      constReported_ = true;
      v->type = ty::Int();
      return;
    }
    // A `with` scope is inside every enclosing one, so its fields win.
    if (Symbol *binding = lookupWithField(v->name, v->withField)) {
      v->sym = binding;
      v->type = v->withField->type;
      return;
    }
    // `lookupUser`, not `lookup`: a bare `abs` is not a designator and has no
    // type, and the marker symbol would leave `type` null — which breaks the
    // contract that Sema hands CodeGen a type on every node. Nulling it here
    // reproduces the "undeclared identifier" this always said.
    v->sym = lookupUser(v->name);
    if (!v->sym) {
      diags_.error(v->line, v->col, "undeclared identifier '" + v->name + "'");
      v->type = ty::Int();
      return;
    }
    // §6.2.3.2 evaluates a variable's actual-discriminant-part when the block
    // is entered, which is before that variable has a size or a value — so it
    // cannot be one of the discriminants that decide them. Its name is in
    // scope by then, which is exactly why this has to be said.
    if (dynamicVarFor_ && v->sym == dynamicVarFor_) {
      diags_.error(v->line, v->col,
                   "'" + v->name + "' cannot be one of its own discriminants");
      v->type = ty::Int();
      return;
    }
    if (v->sym->isInvocable() && !v->sym->resultType()) {
      diags_.error(v->line, v->col,
                   "'" + v->name + "' is a procedure and has no value");
      v->type = ty::Int();
      return;
    }
    if (v->sym->kind == SymKind::Type) {
      diags_.error(v->line, v->col,
                   "'" + v->name + "' is a type and has no value");
      v->type = ty::Int();
      return;
    }
    // A function name used as a value is a call with no arguments — Pascal has
    // no empty argument list, and inside the function's own body this is the
    // recursive call rather than a way to read the result (ISO 7185 §6.8.2.2).
    if (v->sym->isInvocable() && v->sym->params.empty()) {
      v->type = v->sym->resultType();
      // The bare name *is* the call, so it needs the storage a written-out
      // call site gets. Without this a result living in memory has nowhere to
      // be built and the call is never emitted at all — the address the
      // expression evaluates to is the slot's, so no slot means no call.
      v->resultSlot = newResultSlot(v->type);
    }
    else if (v->sym->isInvocable())
      diags_.error(v->line, v->col, "'" + v->name + "' needs arguments");
    else
      v->type = v->sym->type;
    return;
  }

  if (auto *u = as<Unary>(e)) {
    checkExpr(u->operand.get());
    Type *t = u->operand->type;
    if (u->op == UnOp::Not) {
      if (t && !t->isBoolean())
        diags_.error(u->line, u->col,
                     std::string("'not' needs a boolean operand, found ") +
                         t->name());
      e->type = ty::Bool();
    } else {
      if (t && !t->isNumeric())
        diags_.error(u->line, u->col,
                     std::string("unary sign needs a numeric operand, found ") +
                         t->name());
      e->type = (t && t->isReal()) ? ty::Real() : ty::Int();
    }
    return;
  }

  if (auto *b = as<Binary>(e)) {
    checkBinary(b);
    return;
  }

  if (auto *c = as<Call>(e)) {
    checkCall(c);
    return;
  }
}

/// ISO 7185 §6.7.1: the members of a set constructor are expressions of a
/// single ordinal type, and `a..b` abbreviates every value from a to b — an
/// empty range when b precedes a. The constructor's type is a set of that
/// ordinal type; `[]` has no members to say what it is a set of, so it gets the
/// one set type that is compatible with all of them.
///
/// The members need not be constants, so nothing is folded here: whether a
/// value lies in the base type of whatever this is finally assigned to is a
/// run-time question, and codegen asks it.
/// ISO/IEC 10206:1991 §6.8.7.4: "set-value = set-constructor", reached through
/// §6.8.7.1's `set-type-name set-value`. The tokens of `digits[1, 3, 5]` are
/// exactly those of a subscripted array, and §6.5.6's substring shares the
/// bracket too — so the parser builds whichever spine the punctuation suggests
/// and the question "was that a type name?" is asked here, where there are
/// symbols to ask it of. ADR-0053 parts a qualified name from a field
/// selection the same way, and for the same reason.
///
/// The walk is down the *base* links only. A member-designator may itself be
/// any expression, subscripts and all, and those hang off `index`, `lo` and
/// `hi` rather than off `base` — so `sets[a[i]]` asks about `sets` and never
/// about `a`.
Type *Sema::setValueTypeOf(Expr *e) {
  if (std_ != Std::Extended)
    return nullptr;
  const Expr *root = e;
  for (;;) {
    if (auto *i = as<const IndexExpr>(root)) {
      root = i->base.get();
      continue;
    }
    if (auto *s = as<const SubstringExpr>(root)) {
      root = s->base.get();
      continue;
    }
    break;
  }
  auto *v = as<const VarRef>(root);
  if (!v)
    return nullptr;
  // A silent lookup: a name that is not in scope is not a set-value, and the
  // ordinary path is about to report it far better than this could.
  Symbol *sym = lookup(v->name);
  if (!sym || sym->kind != SymKind::Type || !sym->type || !sym->type->isSet())
    return nullptr;
  return sym->type;
}

void Sema::checkSetValue(Expr *e, Type *named) {
  // The spine was built outermost-last, so walking it down yields the members
  // in reverse; they are moved out rather than copied, which leaves the spine
  // as the husk that carries the answer.
  std::vector<SetMember> members;
  Expr *node = e;
  for (;;) {
    if (auto *i = as<IndexExpr>(node)) {
      SetMember m;
      m.lo = std::move(i->index);
      members.push_back(std::move(m));
      node = i->base.get();
      continue;
    }
    if (auto *s = as<SubstringExpr>(node)) {
      SetMember m;
      m.lo = std::move(s->lo);
      m.hi = std::move(s->hi);
      members.push_back(std::move(m));
      node = s->base.get();
      continue;
    }
    break;
  }
  // `node` is now the root of the spine — the type name. A spine is built
  // outermost-last, so `e` sits at the *last* member; the construct begins at
  // the name, and that is where a complaint about it belongs.
  auto set = std::make_unique<SetExpr>();
  set->line = node->line;
  set->col = node->col;
  // Reversed by hand rather than with `std::reverse`, because the same walk
  // has to be written in Pascal and that language has neither the algorithm
  // nor the iterators (bootstrap constraint 3).
  for (size_t i = members.size(); i-- > 0;)
    set->members.push_back(std::move(members[i]));
  checkSetExpr(set.get());

  // §6.8.7.4: "The value of the set-constructor of a set-value shall be
  // assignment-compatible with the type of the set-value." Set compatibility
  // is structural and decided on the base type (ADR-0028), so `assignable` is
  // the whole of the rule and the empty set passes it for every set type.
  if (set->type && !assignable(named, set->type))
    diags_.error(set->line, set->col,
                 "this set value has members of type " + set->type->name() +
                     ", which " + named->name() + " cannot hold");
  // The type is the *named* one, not the one the members were inferred to
  // have: §6.8.7.1 says the type of a structured-value-constructor is the type
  // its type-name denotes. That is the whole point of writing one — `[]` alone
  // has no type of its own, and `digits[]` does.
  e->type = named;
  if (auto *i = as<IndexExpr>(e))
    i->setValue = std::move(set);
  else
    as<SubstringExpr>(e)->setValue = std::move(set);
}

void Sema::checkSetExpr(SetExpr *s) {
  Type *base = nullptr;
  for (SetMember &m : s->members) {
    checkExpr(m.lo.get());
    checkExpr(m.hi.get());
    for (Expr *end : {m.lo.get(), m.hi.get()}) {
      if (!end || !end->type)
        continue;
      if (!end->type->isOrdinal()) {
        diags_.error(end->line, end->col,
                     "a set member must have an ordinal type, found " +
                         end->type->name());
        continue;
      }
      if (!base) {
        // The base is the member's own base type, so `['a'..'z']` is a set of
        // char rather than a set of some anonymous subrange of it.
        base = end->type->base();
      } else if (!assignable(base, end->type) &&
                 !assignable(end->type, base)) {
        diags_.error(end->line, end->col,
                     "the members of a set must all have one type: this one "
                     "is " + end->type->name() + ", not " + base->name());
      }
    }
  }
  if (!base) {
    s->type = ty::EmptySet();
    return;
  }
  Type *t = newType(TypeKind::Set);
  t->elem = base;
  t->setCanonical = true; // §6.7.1 has not committed a constructor to a packing
  s->type = t;
}

void Sema::checkBinary(Binary *b) {
  checkExpr(b->lhs.get());
  checkExpr(b->rhs.get());
  Type *l = b->lhs->type;
  Type *r = b->rhs->type;
  if (!l || !r) {
    b->type = ty::Int();
    return;
  }

  // `distinct` asks for §6.4.1's explanation, and only the *compatible* cases
  // want it: two types written alike can be incompatible, and then their
  // distinctness is the whole reason. Every other word here — numeric, set,
  // boolean, comparable — names a property of the type's *kind*, which two
  // types written alike necessarily share, so the note would be answering a
  // question the reader did not ask. `if r = s` on two alike records is the
  // program that makes the difference visible: records have no relational
  // operators at all, and naming the type would not give them any.
  auto bad = [&](const char *want, bool distinct = false) {
    diags_.error(b->line, b->col,
                 std::string("operator '") + opName(b->op) + "' needs " + want +
                     " operands, found " + l->name() + " and " + r->name() +
                     (distinct ? distinctTypeNote(l, r) : std::string()));
  };

  // ISO 7185 §6.7.2.3 gives `+`, `-` and `*` a second meaning on sets — union,
  // difference and intersection — so the set case is taken before the numeric
  // one rather than after it, where "numeric operands" would already have been
  // reported.
  // §6.8.3.6 gives `+` a second meaning again — string concatenation — so it
  // is taken before the numeric case, exactly as the set case is. "a + b shall
  // denote a value of the canonical-string-type whose length shall be equal to
  // the sum of the length of a and the length of b."
  // Table 7's operands are "Char-type or the canonical-string-type" and the
  // clause says "a and b", so *both* may be char: `c + d` is a two-character
  // string. char has no arithmetic `+` of its own in table 3, so nothing is
  // taken away by reading the table as it is written.
  if (b->op == BinOp::Add && std_ == Std::Extended && l->isStringOrChar() &&
      r->isStringOrChar()) {
    b->type = ty::CanonicalString();
    return;
  }

  // §6.8.3.4 puts `><` among the adding-operators with `+` and `-`, and it
  // takes sets and nothing else — where the other three are also arithmetic.
  if (b->op == BinOp::SymDiff && !l->isSet() && !r->isSet()) {
    bad("set");
    b->type = ty::EmptySet();
    return;
  }
  if (b->op == BinOp::Add || b->op == BinOp::Sub || b->op == BinOp::Mul ||
      b->op == BinOp::SymDiff) {
    if (l->isSet() || r->isSet()) {
      if (!assignable(l, r) && !assignable(r, l)) {
        bad("compatible", true);
        b->type = l->isSet() ? l : r;
      } else if (l->isEmptySet())
        b->type = r;
      // Table 5 makes the result "the same as the operands", so where one has
      // committed to a packing and the other has not (§6.7.1), the committed
      // one is the faithful answer — otherwise `[1] + p` would launder a
      // packed operand into a canonical result that compares equal to
      // anything (ADR-0093).
      else if (l->setCanonical && !r->isEmptySet())
        b->type = r;
      else
        // The result is a set of the operands' common base type, which is
        // whichever of them has one: `s + []` is still a set of s's base.
        b->type = l;
      return;
    }
  }

  switch (b->op) {
  case BinOp::In:
    // §6.7.2.4: the left operand is a value of the right's base type, and the
    // result says whether it is a member. A value outside the base type is not
    // an error — it is simply not in the set.
    if (!r->isSet())
      diags_.error(b->line, b->col,
                   "the right operand of 'in' must be a set, found " +
                       r->name());
    else if (!l->isOrdinal())
      diags_.error(b->line, b->col,
                   "the left operand of 'in' must have an ordinal type, found " +
                       l->name());
    else if (!r->isEmptySet() && !assignable(r->elem, l) &&
             !assignable(l, r->elem))
      diags_.error(b->line, b->col,
                   "this set has base type " + r->elem->name() +
                       ", but the value tested is " + l->name());
    b->type = ty::Bool();
    return;

  // ISO/IEC 10206:1991 §6.8.3.2, table 3: `+ - * /` take an integer, a real or
  // a complex, and the result is complex if either operand is. The widening is
  // §6.4.6 c)'s implicit conversion, which is why the operand check is the
  // *same* assignability question asked everywhere else.
  case BinOp::Add:
  case BinOp::Sub:
  case BinOp::Mul:
    if (!l->isArith() || !r->isArith()) {
      bad("numeric");
      b->type = ty::Int();
    } else if (l->isComplex() || r->isComplex()) {
      b->type = ty::Complex();
    } else {
      b->type = (l->isReal() || r->isReal()) ? ty::Real() : ty::Int();
    }
    return;

  case BinOp::RealDiv:
    if (!l->isArith() || !r->isArith())
      bad("numeric");
    b->type = (l->isComplex() || r->isComplex()) ? ty::Complex() : ty::Real();
    return;

  case BinOp::IntDiv:
  case BinOp::Mod:
    if (!l->isInteger() || !r->isInteger())
      bad("integer");
    b->type = ty::Int();
    return;

  // §6.8.3.3 gives all four the same operands and the same result; they part
  // company only over whether the right one is *evaluated*.
  case BinOp::And:
  case BinOp::Or:
  case BinOp::AndThen:
  case BinOp::OrElse:
    if (!l->isBoolean() || !r->isBoolean())
      bad("boolean");
    b->type = ty::Bool();
    return;

  // ISO/IEC 10206:1991 §6.8.3.2, table 3. `**` is "exponentiation to a real
  // power": an integer operand stands for a real approximation to its value,
  // so the result is real however it was written. `pow` is "exponentiation to
  // an integer power", and its result has the type of its *left* operand —
  // which is the whole reason the standard has two operators rather than one.
  case BinOp::Exp:
    // Table 3 gives `**` a complex *left* operand and a numeric right one, and
    // the result is complex exactly when the left operand is — the same rule
    // `pow` has, which is why both ask one question about the left operand.
    if (!l->isArith() || !r->isNumeric())
      bad("numeric");
    b->type = l->isComplex() ? ty::Complex() : ty::Real();
    return;

  case BinOp::Pow:
    if (!l->isArith()) {
      bad("numeric");
      b->type = ty::Int();
    } else if (!r->isInteger()) {
      diags_.error(b->line, b->col,
                   "the right operand of 'pow' must be an integer, found " +
                       r->name() + " (use ** for a real exponent)");
      b->type = l->isComplex() ? ty::Complex()
                : l->isReal()  ? ty::Real()
                               : ty::Int();
    } else {
      b->type = l->isComplex() ? ty::Complex()
                : l->isReal()  ? ty::Real()
                               : ty::Int();
    }
    return;

  default: // relational
    // ISO 7185 §6.7.2.5 gives the string types the full set of relational
    // operators, comparing character by character; every other structured
    // type has none at all.
    // §6.8.3.5: the relational operators over compatible string-types, where
    // the shorter operand is padded with spaces. Under ISO 7185 the lengths
    // had to be equal and this compiler said so; that check now applies only
    // to the language that has the rule.
    if (std_ == Std::Extended && l->isStringOrChar() && r->isStringOrChar() &&
        !(l->isChar() && r->isChar())) {
      b->type = ty::Bool();
      return;
    }
    if (l->isCharArray() && r->isCharArray()) {
      // A length that is a discriminant is not known here, so the requirement
      // that the two agree is made where the values are (§6.4.6 d)'s shape,
      // for §6.7.2.5's rule). `length()` would answer with arithmetic on the
      // placeholder bounds, which is a number and so not visibly wrong.
      if (l->dynamicExtent() || r->dynamicExtent())
        ;
      else if (l->length() != r->length())
        diags_.error(b->line, b->col,
                     "strings of different lengths cannot be compared: " +
                         l->name() + " and " + r->name());
    } else if (l->isPointer() || r->isPointer()) {
      // ISO 7185 §6.7.2.5: pointers compare only for equality. There is no
      // ordering on them — a heap address is not a value the program may
      // reason about beyond identity.
      if (b->op != BinOp::Eq && b->op != BinOp::Ne)
        diags_.error(b->line, b->col,
                     std::string("pointers can only be compared with = and "
                                 "<>, not with '") + opName(b->op) + "'");
      else if (!assignable(l, r) && !assignable(r, l))
        bad("compatible", true);
    } else if (l->isSet() || r->isSet()) {
      // ISO 7185 §6.7.2.5: `<=` and `>=` on sets are inclusion, not order, and
      // there is no `<` or `>` at all — a proper subset is not a primitive.
      if (b->op == BinOp::Lt || b->op == BinOp::Gt)
        diags_.error(b->line, b->col,
                     std::string("sets have no '") + opName(b->op) +
                         "': use <= and >= for inclusion");
      else if (!assignable(l, r) && !assignable(r, l))
        bad("compatible", true);
    } else if (l->isRestricted() || r->isRestricted()) {
      // §6.4.2.5's NOTE lists what a restricted value may take part in —
      // assignment, a value parameter, a var parameter, a function result —
      // and ends "No other operations ... are possible." A comparison is one
      // of the others, and it needs saying here because `assignable` was just
      // taught that a restricted type and its underlying-type assign to each
      // other: without this, `n = 3` would ride in on that permission.
      diags_.error(b->line, b->col,
                   "a value of a restricted type cannot be compared; 6.4.2.5 "
                   "allows only assignment, parameter passing and a function "
                   "result");
    } else if (l->isFile() || r->isFile()) {
      // §6.7.2.5 gives a file no relational operators at all, and naming the
      // types would just repeat "text and text" back at the programmer.
      diags_.error(b->line, b->col, "file variables cannot be compared");
    } else if (l->isMemory() || r->isMemory()) {
      bad("comparable");
    } else if (l->isComplex() || r->isComplex()) {
      // §6.8.3.5, table 6: `=` and `<>` accept any simple type, and the four
      // ordering operators accept "any simple-type **except complex-type**".
      // There is no order on the complex numbers, so this is the standard
      // declining to invent one rather than an omission.
      if (b->op != BinOp::Eq && b->op != BinOp::Ne)
        diags_.error(b->line, b->col,
                     std::string("complex values can only be compared with = "
                                 "and <>, not with '") + opName(b->op) +
                         "': there is no order on the complex numbers");
      else if (!l->isArith() || !r->isArith())
        bad("compatible", true);
    } else if (!(l->isNumeric() && r->isNumeric()) &&
               !assignable(l, r) && !assignable(r, l)) {
      // Compatibility is decided the same way it is for assignment, so a
      // subrange compares with its host type and with its siblings.
      bad("compatible", true);
    }
    b->type = ty::Bool();
    return;
  }
  (void)isRelational;
}

/// `new(p)` and `dispose(p)` bind a pointer variable to fresh storage and give
/// it back. Both take the pointer itself — not what it points at — so the
/// argument has to be a variable, the same requirement a `var` parameter makes.
/// ISO 7185 §6.9.3. The first argument may be a file variable, which says
/// where to write rather than what to write; without one the file is `output`.
/// A width never follows a file, so the leading argument is a file exactly when
/// it has a file type and no width — and if a program does write `f:8`, the
/// file falls through to the value list and is rejected there as unwritable.
/// ISO 7185 §6.2.2.10 puts the required identifiers' defining-points in "a
/// region enclosing the program", and §6.6.4.1 is the procedures' half — so
/// `procedure write(var a: integer)` in the program-block is what `write(i)`
/// then activates, and `write` may name whatever the program says it names.
///
/// Every other required procedure has this for free: they are not symbols, and
/// `checkProcCall` reads a lookup that answers null as "the required one". The
/// read/write family could not, because the parser has to recognise the six
/// names to parse the field widths a write-parameter-list carries — so the
/// question was settled before there was a scope to ask (ADR-0087). This is
/// where it is settled instead: the same lookup, one pass later.
///
/// Returns the call the name really denotes, or null for the required
/// procedure. The node this was called for is then a husk, and every pass
/// after Sema reads the returned node first.
StmtPtr Sema::redefinedFamily(const std::string &name,
                              std::vector<ExprPtr> args, int line, int col) {
  Symbol *sym = lookupUser(name);
  if (!sym)
    return nullptr;
  auto p = std::make_unique<ProcCallStmt>();
  p->line = line;
  p->col = col;
  p->name = name;
  p->args = std::move(args);
  if (!sym->isInvocable() || sym->resultType())
    diags_.error(line, col, "'" + name + "' is not a procedure");
  else {
    p->sym = sym;
    checkArguments(sym, p->args, line, col);
  }
  return p;
}

void Sema::checkWrite(WriteStmt *w) {
  // ISO 7185 §6.6.4.1: the name may be the program's own, and then none of the
  // rest of this applies — what the parser recognised as a write-parameter-
  // list is an actual-parameter-list, and §6.8.2.3 gives one no field widths.
  if (lookupUser(w->name())) {
    std::vector<ExprPtr> args;
    for (WriteArg &a : w->args) {
      if (a.width)
        diags_.error(a.width->line, a.width->col,
                     "'" + std::string(w->name()) +
                         "' is declared by this program, so it takes no field "
                         "width");
      args.push_back(std::move(a.value));
    }
    w->args.clear();
    w->call = redefinedFamily(w->name(), std::move(args), w->line, w->col);
    return;
  }

  // §6.7.5.5's writestr writes its string-variable where a write-parameter
  // goes, so the parser left it in the list; moving it out is this pass's job,
  // because until the name was looked up there was no telling the statement
  // from a call (ADR-0087).
  if (w->isStr) {
    if (w->args.empty())
      diags_.error(w->line, w->col, "writestr needs a string variable to write to");
    else {
      if (w->args[0].width)
        diags_.error(w->args[0].width->line, w->args[0].width->col,
                     "the string writestr writes to takes no field width");
      w->str = std::move(w->args[0].value);
      w->args.erase(w->args.begin());
    }
  }

  for (auto &arg : w->args) {
    checkExpr(arg.value.get());
    if (arg.width)
      checkExpr(arg.width.get());
    if (arg.prec)
      checkExpr(arg.prec.get());
  }

  // ISO/IEC 10206:1991 §6.7.5.5's writestr: the destination is a string
  // variable rather than a file, and everything after it is a write-parameter
  // of the text form — so the file-detection below is skipped and `file` is
  // left null. What the values are written *into* is the auxiliary text
  // variable the clause defines the statement in terms of, which is the
  // runtime's; the string store at the end is the clause's `read(f, ss)`.
  if (w->str) {
    checkExpr(w->str.get());
    Type *st = w->str->type;
    if (!isDesignator(w->str.get()))
      diags_.error(w->str->line, w->str->col,
                   "writestr needs a string variable, not a value");
    else if (st && !st->isStringType())
      diags_.error(w->str->line, w->str->col,
                   "writestr needs a string variable, not " + st->name());
    else
      // §6.9.4 d): writestr threatens the string-variable it writes to.
      checkNotThreatened(w->str.get(), "it cannot be written to");
    // §6.7.5.5's writestr-parameter-list is the string-variable, a comma, and
    // then at least one write-parameter. The comma used to be the parser's
    // business, which made this case unreachable; it is reachable now.
    if (w->args.empty())
      diags_.error(w->line, w->col, "writestr needs something to write");
    checkWriteArgs(w);
    return;
  }

  if (!w->args.empty() && !w->args[0].width && w->args[0].value->type &&
      w->args[0].value->type->isFile()) {
    if (!isDesignator(w->args[0].value.get()))
      diags_.error(w->args[0].value->line, w->args[0].value->col,
                   "the file written to must be a variable");
    w->file = std::move(w->args[0].value);
    w->args.erase(w->args.begin());
  } else if (!w->isStr) {
    w->file = standardFileRef(false, w->line, w->col);
  }

  // Named rather than spelled: a `writestr` with no parameter list at all
  // reaches this line, having found no string to move out, and a message
  // saying `write` would name a procedure the program never wrote.
  // `writeln` may be written alone, so only the two spellings that may not
  // reach here — and a `writestr` whose string never arrived is one of them.
  if (w->args.empty() && !w->newline)
    diags_.error(w->line, w->col,
                 std::string(w->name()) + " needs something to write");

  // §6.9.3 is the *text* form of write, and everything it says — the field
  // width, the external representation of a number, the line `writeln`
  // finishes — belongs to a text file. On any other file §6.6.5.2's definition
  // applies instead: `write(f, e)` is `f^ := e; put(f)`, one component of the
  // file's own type and nothing to format.
  Type *wf = w->file ? w->file->type : nullptr;
  if (wf && !wf->isText()) {
    if (w->newline)
      diags_.error(w->line, w->col,
                   "writeln needs a text file, but " + wf->name() +
                       " has no lines");
    for (auto &arg : w->args) {
      if (arg.width)
        diags_.error(arg.width->line, arg.width->col,
                     "a field width is only for a text file");
      if (!assignable(wf->elem, arg.value->type))
        diags_.error(arg.value->line, arg.value->col,
                     "a value of type " +
                         (arg.value->type ? arg.value->type->name() : "?") +
                         " cannot be written to a " + wf->name());
    }
    return;
  }

  checkWriteArgs(w);
}

/// The write-parameters of the *text* form, which ISO/IEC 10206:1991 §6.10.3
/// gives to `write`, `writeln` and §6.7.5.5's `writestr` alike — the last one
/// writes to an auxiliary text variable, so its parameters are governed by the
/// same clause and checked by the same code.
void Sema::checkWriteArgs(WriteStmt *w) {
  for (auto &arg : w->args) {
    Type *t = arg.value->type;
    // ISO 7185 §6.9.3 lists exactly what write accepts: an integer, a real,
    // a boolean, a char, or a packed array of char. An enumeration is not on
    // the list — the standard gives no spelling for its constants at run
    // time — and neither is any other structured type.
    // ISO/IEC 10206:1991 §6.10.3.1 has the same list with "a string-type" in
    // place of the packed char array — so a variable-string and a canonical
    // value join it, and nothing else does.
    bool writable = t && (t->isInteger() || t->isReal() || t->isBoolean() ||
                          t->isChar() || t->isStringType());
    if (t && !writable)
      diags_.error(arg.value->line, arg.value->col,
                   "a value of type " + t->name() + " cannot be written");
    if (arg.width && arg.width->type && !arg.width->type->isInteger())
      diags_.error(arg.width->line, arg.width->col,
                   "a field width must be an integer");
    if (arg.prec) {
      if (arg.prec->type && !arg.prec->type->isInteger())
        diags_.error(arg.prec->line, arg.prec->col,
                     "a fraction length must be an integer");
      if (t && !t->isReal())
        diags_.error(arg.prec->line, arg.prec->col,
                     "only real values take a fraction length");
    }
  }
}

/// ISO 7185 §6.9.1. Like write, the first argument may be the file; every
/// other one is a *variable* to store into, so each has to be a designator.
/// `read` reads a char, an integer or a real — a text file has no other
/// external representation to read.
void Sema::checkRead(ReadStmt *r) {
  // §6.6.4.1 again, and read's arguments need no unwrapping: a
  // read-parameter-list and an actual-parameter-list have the same shape, so
  // the list the parser built is already the one a call takes.
  if (lookupUser(r->name())) {
    r->call = redefinedFamily(r->name(), std::move(r->args), r->line, r->col);
    r->args.clear();
    return;
  }

  // The mirror of write's split: the string a readstr reads from stands where
  // a variable-access would, and only the name says it is not one (ADR-0087).
  if (r->isStr) {
    if (r->args.empty())
      diags_.error(r->line, r->col, "readstr needs a string to read from");
    else {
      r->str = std::move(r->args[0]);
      r->args.erase(r->args.begin());
    }
  }

  for (auto &a : r->args)
    checkExpr(a.get());

  // §6.7.5.5's readstr, the mirror of writestr above: the source is a string
  // expression rather than a file, and every variable-access after it is read
  // exactly as it would be from a text file — which is why `file` is left null
  // and the loop below runs its text branch unchanged.
  if (r->str) {
    checkExpr(r->str.get());
    Type *st = r->str->type;
    // "The expression of a string-expression shall possess char-type or
    // canonical-string-type", and §6.4.6 makes every string type's value a
    // canonical one, so a fixed and a variable string both qualify.
    if (st && !st->isStringOrChar())
      diags_.error(r->str->line, r->str->col,
                   "readstr needs a string to read from, not " + st->name());
  } else if (!r->args.empty() && r->args[0]->type &&
             r->args[0]->type->isFile()) {
    if (!isDesignator(r->args[0].get()))
      diags_.error(r->args[0]->line, r->args[0]->col,
                   "the file read from must be a variable");
    r->file = std::move(r->args[0]);
    r->args.erase(r->args.begin());
  } else if (!r->isStr) {
    // A readstr reads from no file at all, so a broken one must not be given
    // `input`: the statement would then report that the program does not list
    // it, which is a rule it is not breaking.
    r->file = standardFileRef(true, r->line, r->col);
  }

  // `read` must be given somewhere to put what it reads; `readln` may be
  // written alone, and then it only finishes the line. Named, as write's is,
  // so a readstr given only the string it reads from says `readstr`.
  if (r->args.empty() && !r->newline)
    diags_.error(r->line, r->col,
                 std::string(r->name()) + " needs a variable to read into");

  // The counterpart of write's split: on a file that is not a text, §6.6.5.2
  // makes `read(f, v)` mean `v := f^; get(f)`, so the variable takes the
  // file's component type and there is no external representation to parse.
  Type *rf = r->file ? r->file->type : nullptr;
  bool text = !rf || rf->isText();
  if (rf && !text && r->newline)
    diags_.error(r->line, r->col,
                 "readln needs a text file, but " + rf->name() +
                     " has no lines");

  for (auto &a : r->args) {
    if (!isDesignator(a.get())) {
      diags_.error(a->line, a->col, "read needs a variable, not a value");
      continue;
    }
    // §6.9.4 c): read and readln threaten every variable they read into.
    checkNotThreatened(a.get(), "it cannot be read into");
    Type *t = a->type;
    if (!text) {
      if (!assignable(t, rf->elem))
        diags_.error(a->line, a->col,
                     "a variable of type " + (t ? t->name() : "?") +
                         " cannot be read from a " + rf->name());
      continue;
    }
    // ISO/IEC 10206:1991 §6.10.1 a) adds the string types to ISO 7185's list:
    // "each of which shall possess a type that is the real-type, is a
    // string-type, or is compatible with the char-type or with the
    // integer-type".
    if (t && !(t->isInteger() || t->isReal() || t->isChar() ||
               (std_ == Std::Extended && t->isStringType())))
      diags_.error(a->line, a->col,
                   "a value of type " + t->name() + " cannot be read");
  }
}

/// The required procedures ISO/IEC 10206:1991 adds: §6.7.5.2's five
/// direct-access ones, §6.7.5.6's two binding ones, §6.7.5.7's `halt` and
/// §6.7.5.8's `GetTimeStamp`. All
/// are required *identifiers* like the complex functions, not word-symbols, so
/// a valid ISO 7185 program may declare a procedure called `update` or `halt`
/// — which is why they are recognised only under the standard that has them,
/// and only when no declaration of the name was found.
bool Sema::isRequiredProc(const std::string &name) {
  return name == "seekread" || name == "seekwrite" || name == "seekupdate" ||
         name == "update" || name == "extend" || name == "bind" ||
         name == "unbind" || name == "halt" || name == "gettimestamp";
}

void Sema::checkStdProc(ProcCallStmt *p) {
  // §6.7.5.2: `SeekRead(f, n)`, `SeekWrite(f, n)` and `SeekUpdate(f, n)` take
  // a direct-access file and a position; `update(f)` and `extend(f)` take a
  // file alone. Only `extend` works on a sequential one.
  // §6.7.5.6: `bind(f, b)` takes a variable-access and a BindingType value;
  // `unbind(f)` takes the variable alone. Both are dynamic-violations on a
  // file variable that is not `bindable`, and this compiler restricts them to
  // file variables — the only external entity it has a meaning for.
  // §6.7.5.7: "Following execution of the control procedure halt ... no
  // further processing of the activation of the program shall occur." It takes
  // nothing, and everything about *how* it stops belongs to the runtime — the
  // files a block exit would have closed are closed there instead, because a
  // halt skips every epilogue on the way out exactly as a non-local goto skips
  // the ones it jumps past (ADR-0032).
  //
  // **The optional status is an extension** (ADR-0084): §6.7.5.7's halt takes
  // no parameters, so `halt(1)` is not a conforming program and no conforming
  // program's meaning changes. Neither standard models a process exit status
  // at all, which is why there is nothing in either to take a spelling from —
  // and why a Pascal program otherwise has no way to tell whatever invoked it
  // that it failed. `doc/implementation-defined.md` §5 is where it is stated.
  if (p->name == "halt") {
    p->standard = StdProc::Halt;
    if (p->args.size() > 1)
      diags_.error(p->line, p->col,
                   "'halt' takes at most one argument, the exit status");
    for (auto &a : p->args)
      checkExpr(a.get());
    if (p->args.size() == 1 && p->args[0]->type &&
        !p->args[0]->type->isInteger())
      diags_.error(p->args[0]->line, p->args[0]->col,
                   "the exit status of 'halt' must be an integer, found " +
                       p->args[0]->type->name());
    return;
  }
  // §6.7.5.8: `GetTimeStamp(t)` attributes to `t` either the current date and
  // time with both valid-flags true, or the standard's own fallbacks with the
  // corresponding flag false. What arrives here is only whether `t` is a
  // variable of the one type §6.4.3.4 built — every other question about the
  // value belongs to the runtime, which is where "current" is defined.
  if (p->name == "gettimestamp") {
    p->standard = StdProc::GetTimeStamp;
    for (auto &a : p->args)
      checkExpr(a.get());
    if (p->args.size() != 1) {
      diags_.error(p->line, p->col,
                   "'GetTimeStamp' takes one TimeStamp variable");
      return;
    }
    Expr *a = p->args[0].get();
    if (!isDesignator(a)) {
      diags_.error(a->line, a->col,
                   "'GetTimeStamp' needs a variable, not a value");
      return;
    }
    // §6.9.4 f): "S is a procedure-statement that specifies activation of the
    // required procedure GetTimeStamp, and V is the variable-access t." The
    // only entry on that list with no call site when ADR-0046 landed.
    checkNotThreatened(a, "it cannot be given a time stamp");
    if (a->type && a->type != timeStampType_)
      diags_.error(a->line, a->col,
                   "'GetTimeStamp' needs a TimeStamp variable, found " +
                       a->type->name());
    return;
  }

  // ISO 7185 §6.6.5.4: "a shall possess an array-type not designated packed;
  // z shall possess an array-type designated packed; the component-types of
  // the types of a and z shall be the same; and the value of the expression i
  // shall be assignment-compatible with the index-type of the type of a."
  //
  // The two statements differ in argument *order* and in which side is
  // written, and in nothing else — `pack(a, i, z)` fills z from a and
  // `unpack(z, a, i)` fills a from z — so one arm checks both and names the
  // roles rather than the positions.
  if (p->name == "pack" || p->name == "unpack") {
    bool packing = p->name == "pack";
    p->standard = packing ? StdProc::Pack : StdProc::Unpack;
    for (auto &a : p->args)
      checkExpr(a.get());
    if (p->args.size() != 3) {
      diags_.error(p->line, p->col,
                   "'" + p->name + "' takes " +
                       (packing ? "an unpacked array, an index and a packed "
                                  "array"
                                : "a packed array, an unpacked array and an "
                                  "index"));
      return;
    }
    Expr *unpacked = p->args[packing ? 0 : 1].get();
    Expr *packed = p->args[packing ? 2 : 0].get();
    Expr *index = p->args[packing ? 1 : 2].get();
    // Both arrays are variable-accesses whichever way the copy runs: the
    // source is read through a reference and the destination written, and
    // §6.6.5.4 asks for a variable-access of each.
    for (Expr *side : {unpacked, packed})
      if (!isDesignator(side)) {
        diags_.error(side->line, side->col,
                     "'" + p->name + "' needs a variable, not a value");
        return;
      }
    // §6.9.4's NOTE: pack and unpack are defined in §6.7.5.4 as "a series of
    // assignments of the components", and the note makes those equivalent
    // assignments subject to a) and i). It is the note and not e), which is
    // `new`. So the *destination* is threatened, and only that one — the
    // source is read. Which side that is, is the whole difference between the
    // two procedures (ADR-0046's list, a second call site after ADR-0065's).
    checkNotThreatened(packing ? packed : unpacked,
                       packing ? "it cannot be packed into"
                               : "it cannot be unpacked into");
    Type *ut = unpacked->type;
    Type *pt = packed->type;
    if (!ut || !pt)
      return;
    if (!ut->isArray() || ut->packed) {
      diags_.error(unpacked->line, unpacked->col,
                   "'" + p->name +
                       "' needs an array that is not packed, "
                       "found " +
                       ut->name());
      return;
    }
    if (!pt->isArray() || !pt->packed) {
      diags_.error(packed->line, packed->col,
                   "'" + p->name + "' needs a packed array, found " +
                       pt->name());
      return;
    }
    // "the component-types ... shall be the same" — ADR-0017's identity, not
    // assignability, so two separately written component types do not match
    // however alike they look.
    if (ut->elem != pt->elem) {
      diags_.error(p->line, p->col,
                   "'" + p->name + "' needs one component type, found " +
                       ut->elem->name() + " and " + pt->elem->name());
      return;
    }
    if (index->type && !assignable(ut->indexType, index->type))
      diags_.error(index->line, index->col,
                   "the index must be assignment-compatible with " +
                       ut->indexType->name() + ", found " +
                       index->type->name());
    return;
  }

  // §6.9.5: `page(f)`, or `page` for `output`. The pre-assertion is
  // `writeln(f)`'s, so what is checked here is what `writeln` checks — a text
  // file, and one the program has.
  if (p->name == "page") {
    p->standard = StdProc::Page;
    for (auto &a : p->args)
      checkExpr(a.get());
    if (p->args.size() > 1) {
      diags_.error(p->line, p->col, "'page' takes one text file, or none");
      return;
    }
    if (p->args.empty()) {
      // "the program shall contain a program-parameter-list containing an
      // identifier with the spelling output". The file is *supplied* here
      // rather than left for CodeGen to find, because CodeGen never inspects
      // names (ADR-0008) — the same `standardFileRef` a `write` with no file
      // gets, so `page` has one argument by the time anything downstream
      // looks.
      p->args.push_back(standardFileRef(false, p->line, p->col));
      checkExpr(p->args[0].get());
      return;
    }
    Expr *f = p->args[0].get();
    if (!isDesignator(f) || !f->type || !f->type->isText()) {
      diags_.error(f->line, f->col,
                   "'page' needs a text file variable" +
                       (f->type ? ", found " + f->type->name() : ""));
      return;
    }
    return;
  }

  if (p->name == "bind" || p->name == "unbind") {
    p->standard = p->name == "bind" ? StdProc::Bind : StdProc::Unbind;
    for (auto &a : p->args)
      checkExpr(a.get());
    size_t want = p->name == "bind" ? 2u : 1u;
    if (p->args.size() != want) {
      diags_.error(p->line, p->col,
                   "'" + p->name + "' takes a bindable variable" +
                       (want == 2 ? " and a BindingType value" : ""));
      return;
    }
    Expr *a = p->args[0].get();
    if (!isDesignator(a) || (a->type && !a->type->isFile())) {
      diags_.error(a->line, a->col,
                   "'" + p->name + "' needs a file variable" +
                       (a->type ? ", found " + a->type->name() : ""));
      return;
    }
    if (!designatorBindable(a))
      notBindable(a);
    if (p->name == "bind" && p->args[1]->type &&
        p->args[1]->type != bindingType_)
      diags_.error(p->args[1]->line, p->args[1]->col,
                   "the second argument of 'bind' is a BindingType, found " +
                       p->args[1]->type->name());
    return;
  }

  if (isRequiredProc(p->name)) {
    bool seeks = p->name != "update" && p->name != "extend";
    p->standard = p->name == "seekread"     ? StdProc::SeekRead
                  : p->name == "seekwrite"  ? StdProc::SeekWrite
                  : p->name == "seekupdate" ? StdProc::SeekUpdate
                  : p->name == "update"     ? StdProc::Update
                                            : StdProc::Extend;
    for (auto &a : p->args)
      checkExpr(a.get());
    size_t want = seeks ? 2u : 1u;
    if (p->args.size() != want) {
      diags_.error(p->line, p->col,
                   "'" + p->name + "' takes a file variable" +
                       (seeks ? " and a position" : ""));
      return;
    }
    Expr *a = p->args[0].get();
    if (!isDesignator(a) || (a->type && !a->type->isFile())) {
      diags_.error(a->line, a->col,
                   "'" + p->name + "' needs a file variable" +
                       (a->type ? ", found " + a->type->name() : ""));
      return;
    }
    // §6.4.3.6 gives only a file-type with an index-type any position at all,
    // and `text` never has one. `extend` is the exception: appending is a
    // sequential operation and §6.7.5.2 asks nothing of the file-type.
    if (p->name != "extend" && a->type && !a->type->isDirectAccess()) {
      diags_.error(a->line, a->col,
                   "'" + p->name + "' needs a direct-access file, and " +
                       a->type->name() + " has no index type");
      return;
    }
    // The buffer variable is what `update` writes back, so it threatens the
    // file the same way `put` does — but a file is not protectable, so there
    // is nothing to check (§6.4.1).
    if (seeks && p->args[1]->type &&
        !assignable(a->type->indexType, p->args[1]->type))
      diags_.error(p->args[1]->line, p->args[1]->col,
                   "the position must be a value of the index type " +
                       a->type->indexType->name() + ", found " +
                       p->args[1]->type->name());
    return;
  }

  // The file primitives. ISO 7185 §6.6.5.2 defines read and write in terms of
  // get, put and the buffer variable, and this compiler keeps them rather than
  // providing only the derived forms — one character of lookahead is what a
  // lexer, the first thing the self-hosted compiler needs, is written against.
  if (p->name == "reset" || p->name == "rewrite" || p->name == "get" ||
      p->name == "put") {
    p->standard = p->name == "reset"     ? StdProc::Reset
                  : p->name == "rewrite" ? StdProc::Rewrite
                  : p->name == "get"     ? StdProc::Get
                                         : StdProc::Put;
    for (auto &a : p->args)
      checkExpr(a.get());
    if (p->args.size() != 1) {
      diags_.error(p->line, p->col,
                   "'" + p->name + "' takes exactly one file variable");
      return;
    }
    Expr *a = p->args[0].get();
    if (!isDesignator(a) || (a->type && !a->type->isFile()))
      diags_.error(a->line, a->col,
                   "'" + p->name + "' needs a file variable" +
                       (a->type ? ", found " + a->type->name() : ""));
    return;
  }

  p->standard = p->name == "new" ? StdProc::New : StdProc::Dispose;

  for (auto &a : p->args)
    checkExpr(a.get());

  if (p->args.empty()) {
    diags_.error(p->line, p->col,
                 "'" + p->name + "' needs a pointer variable");
    return;
  }

  Expr *a = p->args[0].get();
  // §6.6.5.3 asks for different things of the two. `new(p)` "shall attribute
  // to p" the identifying-value, so p is somewhere to store and has to be a
  // variable; `dispose(q)` "shall remove the identifying-value denoted by the
  // *expression* q", which a function-designator is as much as a variable is.
  // Requiring a variable of both refused `dispose(alterptr(ptr1))`, which is
  // the suite's CONF129 — and there is nothing for the nil-back-store of
  // ADR-0019 to write into there, which is why CodeGen asks the same question
  // rather than assuming an answer.
  if (p->standard == StdProc::New && !isDesignator(a)) {
    diags_.error(a->line, a->col,
                 "'" + p->name + "' needs a pointer variable");
    return;
  }
  // §6.9.4 e) makes `new(p)` a threat to p, and there is nothing to *refuse*:
  // §6.4.1 makes a pointer type unprotectable, and a record or array holding
  // one unprotectable with it, so no designator that reaches here can have a
  // protected variable under it, and a control-variable is an ordinal. That
  // much this comment said before, and it stopped there — but a threat has a
  // second consumer. §6.7.2 requires a function-block to contain "at least one
  // statement threatening" its result variable, and reads §6.9.4's list to
  // decide, so a constructor whose result is *allocated* rather than assigned
  // was refused for never writing to it. The recording is the half that was
  // missing; the refusal is still enforced by construction.
  if (p->standard == StdProc::New && isDesignator(a))
    recordThreat(a);
  if (a->type && (!a->type->isPointer() || a->type->isNil())) {
    // A variable for `new`, which stores into it; any expression of a
    // pointer-type for `dispose`, which only reads one (§6.6.5.3).
    diags_.error(a->line, a->col,
                 "'" + p->name +
                     (p->standard == StdProc::New
                          ? "' needs a pointer variable, found "
                          : "' needs a pointer, found ") +
                     a->type->name());
    return;
  }
  if (p->args.size() == 1) {
    // §6.7.5.3's `new(p)` gives the created variable the domain type, and a
    // schema domain has no type until a tuple names one. `dispose(q)` is the
    // opposite: the variable it removes already has its tuple.
    if (p->standard == StdProc::New && a->type && a->type->elem &&
        a->type->elem->heapTuple)
      diags_.error(p->line, p->col,
                   "'new' needs the discriminants of schema '" +
                       a->type->elem->schema->name +
                       "' here, as new(p, ...): a schema denotes a type only "
                       "once its discriminants are given");
    return;
  }

  Type *domain = a->type ? a->type->elem : nullptr;

  // ISO/IEC 10206:1991 §6.7.5.3 gives `new(p, d1, ..., ds)` a second meaning:
  // where the domain-type is a schema-name, the arguments are the *tuple* the
  // created variable's type is produced with, not tag values selecting
  // variants. The two forms are told apart by the domain and by nothing else —
  // a record with a variant part takes the first, a schema domain the second.
  if (domain && domain->heapTuple) {
    if (p->standard == StdProc::Dispose) {
      diags_.error(p->args[1]->line, p->args[1]->col,
                   "'dispose' takes no discriminants: they belong to the "
                   "variable, which already has them");
      return;
    }
    const std::vector<Symbol *> &formals = domain->schema->discriminants;
    if (p->args.size() - 1 != formals.size()) {
      diags_.error(p->args[1]->line, p->args[1]->col,
                   "schema '" + domain->schema->name + "' has " +
                       std::to_string(formals.size()) + " discriminant" +
                       (formals.size() == 1 ? "" : "s") + ", found " +
                       std::to_string(p->args.size() - 1));
      return;
    }
    // §6.7.5.3: the type of each expression shall be compatible with the type
    // of the corresponding formal discriminant. Unlike §6.4.8's
    // actual-discriminant-part these need not be constants — the tuple is
    // chosen when `new` runs, which is the whole reason the header exists.
    for (size_t i = 0; i < formals.size(); ++i) {
      Expr *d = p->args[i + 1].get();
      if (!d->type || !assignable(formals[i]->type, d->type))
        diags_.error(d->line, d->col,
                     "discriminant '" + formals[i]->name + "' of schema '" +
                         domain->schema->name + "' is " +
                         formals[i]->type->name() + ", but the value is " +
                         (d->type ? d->type->name() : std::string("untyped")));
    }
    return;
  }

  // ISO 7185 §6.6.5.3: `new(p, c1, ..., cn)` creates a variable with the
  // variants those tag values select, one value per nested variant part,
  // outermost first. `dispose` takes the same list.
  if (!domain || !domain->isRecord()) {
    diags_.error(p->args[1]->line, p->args[1]->col,
                 "tag values are only for a pointer to a record with a "
                 "variant part");
    return;
  }

  const std::vector<Variant> *arms = &domain->variants;
  Type *tag = domain->tagType;
  bool discSel = domain->discSelector;
  for (size_t i = 1; i < p->args.size(); ++i) {
    Expr *value = p->args[i].get();
    // §6.7.5.3: every variant-part a tag value selects "shall closest-contain
    // a tag-type". A discriminant-selected one does not — its selector was
    // fixed by the tuple the type was produced with, and this list would be a
    // second, disagreeing answer.
    if (discSel) {
      diags_.error(value->line, value->col,
                   "this variant part is selected by a discriminant, so its "
                   "variant was chosen when the type was produced");
      return;
    }
    if (arms->empty()) {
      diags_.error(value->line, value->col,
                   i == 1 ? "this record has no variant part"
                          : "this record has no more nested variant parts to "
                            "select");
      return;
    }
    Type *valueType = nullptr;
    long long v = 0;
    if (!evalOrdinal(value, valueType, v)) {
      diags_.error(value->line, value->col,
                   "a tag value for '" + p->name +
                       "' must be an ordinal constant");
      return;
    }
    if (tag && valueType && valueType->base() != tag->base()) {
      diags_.error(value->line, value->col,
                   "this variant part's tag is " + tag->name() +
                       ", but the value is " + valueType->name());
      return;
    }
    int chosen = -1;
    for (size_t k = 0; k < arms->size() && chosen < 0; ++k)
      for (const LabelRange &label : (*arms)[k].labels)
        if (label.lo <= v && v <= label.hi) {
          chosen = static_cast<int>(k);
          break;
        }
    // An otherwise-arm is what every unclaimed value selects, so it answers
    // here too — the value is a value of the tag type, and that is all the
    // completer asks of it.
    for (size_t k = 0; k < arms->size() && chosen < 0; ++k)
      if ((*arms)[k].isOtherwise)
        chosen = static_cast<int>(k);
    if (chosen < 0) {
      diags_.error(value->line, value->col,
                   "no variant is selected by " + Type::ordinalName(tag, v));
      return;
    }
    p->variantSelection.push_back(chosen);
    tag = (*arms)[chosen].tagType;
    discSel = (*arms)[chosen].discSelector;
    arms = &(*arms)[chosen].variants;
  }
}

/// ISO 7185 §6.8.3.5: the selector is an ordinal expression, every label is a
/// constant of a compatible type, and no value may appear twice. There is no
/// `else` arm, so a value matching nothing is an error at run time — which is
/// exactly the shape of an LLVM switch with a trapping default.
void Sema::checkCase(CaseStmt *c) {
  checkExpr(c->selector.get());
  // The otherwise-part is a statement-sequence like any other; nothing about
  // it depends on the selector, because it is what runs when *no* label does.
  //
  // ISO/IEC 10206:1991 §6.9.3.5's case-statement-completer has no node of its
  // own, so it cannot be told from its case statement by kind — the flag is
  // what carries the fact that this entry holds a *sequence* where the arms
  // above hold single statements (ADR-0094).
  stmtPath_.push_back({c, true});
  for (StmtPtr &st : c->otherwise)
    checkStmt(st.get());
  stmtPath_.pop_back();
  Type *sel = c->selector->type;
  if (sel && !sel->isOrdinal()) {
    diags_.error(c->selector->line, c->selector->col,
                 "the selector of a case statement must be an ordinal type, "
                 "found " + sel->name());
    sel = nullptr;
  }

  std::vector<LabelRange> seen;
  for (CaseArm &arm : c->arms) {
    for (CaseLabel &label : arm.labels) {
      Type *labelType = nullptr;
      LabelRange r;
      if (!evalLabelRange(label, "a case label must be an ordinal constant",
                          labelType, r))
        continue;
      if (sel && !assignable(sel, labelType)) {
        diags_.error(label.lo->line, label.lo->col,
                     "this case selects on " + sel->name() +
                         ", but the label is " + labelType->name());
        continue;
      }
      long long at = 0;
      if (overlaps(seen, r, at)) {
        diags_.error(label.lo->line, label.lo->col,
                     "the label " +
                         Type::ordinalName(sel ? sel : labelType, at) +
                         " appears twice in this case statement");
        continue;
      }
      seen.push_back(r);
      arm.values.push_back(r);
    }
    stmtPath_.push_back({c, false});
    checkStmt(arm.body.get());
    stmtPath_.pop_back();
  }
}

/// Was this discriminant's name already written earlier in the same
/// formal-discriminant-part? A repeat was reported at the schema definition,
/// and naming it again here would report it once more at every `with` over a
/// type that schema produced — the guard `genericFromSchema` makes for the
/// same reason at every parameter naming the schema.
static bool repeatedDiscriminant(const std::vector<Symbol *> &ds, size_t i) {
  for (size_t j = 0; j < i; ++j)
    if (ds[j]->name == ds[i]->name)
      return true;
  return false;
}

/// `with r do S` makes the fields of r visible as bare names throughout S.
/// The record is designated once, so the binding holds its address and any
/// subscripts in the designator are evaluated a single time.
void Sema::checkWith(WithStmt *w) {
  checkExpr(w->record.get());
  Type *t = w->record->type;

  // §6.9.3.10: `with-element = variable-access | constant-access`. A constant
  // one binds the same way — the value has storage and the binding is its
  // address — and differs only in that the field-identifiers it introduces
  // are constant-field-identifiers, which denote values.
  // No `--std` test: the only structured constant ISO 7185 has is a string
  // (ADR-0068), which is not a record, so a constant-access reaching here is
  // already an Extended Pascal program. A gate would be unreachable.
  bool constAccess = isConstantAccess(w->record.get());
  if (!isDesignator(w->record.get()) && !constAccess) {
    diags_.error(w->record->line, w->record->col,
                 "'with' needs a record variable");
    stmtPath_.push_back({w, false});
    checkStmt(w->body.get());
    stmtPath_.pop_back();
    return;
  }
  // §6.9.3.10: the with-element "shall possess either a type produced from a
  // schema or a record-type" — so a `vector(4)` is one although it has no
  // fields at all, and what it introduces is its discriminants rather than
  // field-identifiers.
  if (!t || !(t->isRecord() || t->isSchematic())) {
    // ISO 7185 has no schemata, so naming one there would offer a remedy that
    // language does not have — the same reason `standardFileRef` words its
    // message by standard.
    diags_.error(
        w->record->line, w->record->col,
        std::string("'with' needs a record variable") +
            (std_ == Std::Extended ? " or one produced from a schema" : "") +
            ", found " + (t ? t->name() : std::string("nothing")));
    stmtPath_.push_back({w, false});
    checkStmt(w->body.get());
    stmtPath_.pop_back();
    return;
  }

  // The binding is a frame slot holding a pointer — the same shape as a `var`
  // parameter — so a `with` inside a recursive procedure binds the record of
  // the invocation it is running in.
  // Named by its slot rather than by its record's type. The spelling reaches
  // nothing but an IR label, and building it from a type name would be the one
  // string-valued function ADR-0012 measured as avoidable — the Pascal-hosted
  // Sema would need a whole second, string-building copy of Type::name() for
  // this line alone.
  w->binding = addHiddenVar("with$" + std::to_string(current_->frameVars.size()),
                            SymKind::VarParam, t, current_);
  // §6.9.4 i): a `with` is where a protected variable's name stops being
  // written down, so the protection has to travel onto the binding or
  // `with p do f := 1` would slip past a rule `p.f := 1` obeys.
  if (Symbol *root = baseSymbol(w->record.get()))
    w->binding->isProtected = root->isProtected;
  w->binding->isConstBinding = constAccess;

  // §6.9.3.10's other half: an element possessing a type produced from a
  // schema *with a tuple* makes each of the schema's formal discriminants a
  // schema-discriminant-identifier "for the region that is the statement" —
  // so they go in a scope, which is what a region is.
  //
  // Each one denotes what `v.d` denotes, and in two of the three shapes a
  // produced type has that is a symbol Sema already holds: the tuple's value,
  // or — where the tuple arrived with a schematic formal parameter — that
  // parameter's own `Disc` symbol, which reads the descriptor. The third is
  // the heap, where the tuple has no name at all; see below. No node kind
  // either way.
  bool scoped = t->isSchematic();
  if (scoped) {
    pushScope();
    const std::vector<Symbol *> &ds = t->schema->discriminants;
    // §6.9.3.10 makes the field-identifiers *and* the discriminant-identifiers
    // defining-points for one region — the statement — and §6.2.2.7 allows a
    // region only one defining-point per spelling. Outside a `with` the two
    // sit in nested regions and the field shadows the discriminant legally
    // (§6.2.2.5), so this is the with-statement's error and not the schema's.
    // Reported and then bound anyway: an error is accumulated, not bailed on,
    // and which of the two a later statement resolves to cannot matter once
    // the program has been refused. `findField` already searches every arm of
    // every variant part, which is what makes an arm's field-identifier count
    // — it is a field-identifier like any other.
    if (t->isRecord())
      for (size_t i = 0; i < ds.size(); ++i)
        if (!repeatedDiscriminant(ds, i) && t->findField(ds[i]->name))
          diags_.error(w->record->line, w->record->col,
                       "'" + ds[i]->name + "' is both a field of " + t->name() +
                           " and a discriminant of schema '" + t->schema->name +
                           "', so 'with' would give one name two meanings");
    if (t->heapTuple) {
      // A heap variable's tuple is a header in front of it (ADR-0043), and
      // `v.d` finds that header by walking *down* the designator to the whole
      // variable. A bare name has no designator to walk, so the binding
      // carries the tuple as well as the address: it becomes the descriptor
      // ADR-0040 gives a schematic formal, and the discriminants are its own,
      // reached by the walk every enclosing variable makes.
      w->binding->descSchema = t->schema;
      w->binding->discSyms.clear();
      for (size_t i = 0; i < ds.size(); ++i) {
        Symbol *d = newSymbol();
        d->name = ds[i]->name;
        d->kind = SymKind::Disc;
        d->type = ds[i]->type;
        d->discBinding = true;
        d->owner = w->binding->owner;
        d->level = w->binding->level;
        d->frameIndex = w->binding->frameIndex;
        d->discIndex = static_cast<int>(i);
        // Pushed whether or not it is bound: `discIndex` is the header's own
        // numbering, so a skipped name may not shift the ones after it.
        w->binding->discSyms.push_back(d);
        if (!repeatedDiscriminant(ds, i))
          bindName(d->name, d, w->line, w->col);
      }
    } else if (t->isGeneric()) {
      // A schematic formal parameter's discriminants are already symbols with
      // storage — the descriptor the actual brought — so the entry is that
      // very symbol and nothing is copied.
      Symbol *owner = baseSymbol(w->record.get());
      for (size_t i = 0; i < ds.size() && owner && i < owner->discSyms.size();
           ++i)
        if (!repeatedDiscriminant(ds, i))
          bindName(ds[i]->name, owner->discSyms[i], w->line, w->col);
    } else {
      // A tuple written as constants makes each discriminant a constant, which
      // is what §6.4.8 keys the produced type on.
      for (size_t i = 0; i < ds.size() && i < t->tuple.size(); ++i)
        if (!repeatedDiscriminant(ds, i)) {
          Symbol *k = declare(ds[i]->name, SymKind::Const, w->line, w->col);
          k->type = ds[i]->type;
          k->intVal = t->tuple[i];
        }
    }
  }

  withStack_.push_back(w->binding);
  stmtPath_.push_back({w, false});
  checkStmt(w->body.get());
  stmtPath_.pop_back();
  withStack_.pop_back();
  if (scoped)
    popScope();
}

/// Check an argument list against a callable's parameters. A `var` parameter
/// is bound to a variable, not to a value, so the argument has to be one.
/// A result that lives in memory has no register form (ADR-0017) and the
/// callee's activation record dies at the return, so the storage has to be the
/// caller's. Each call site gets a hidden frame slot for it — the mechanism
/// ADR-0052 built for `binding(f)` back when that was the only function
/// returning a record and this compiler returned none.
///
/// Per *site*, not per callee: `f(g(x))` and a call in a loop each want their
/// own, and a frame slot is somewhere both backends can name without an
/// `alloca` in the middle of a function. A recursive call needs nothing extra,
/// because each activation brings its own frame and so its own slots.
Symbol *Sema::newResultSlot(Type *t) {
  if (!current_ || !t || !t->isMemory())
    return nullptr;
  return addHiddenVar("result$" + std::to_string(current_->frameVars.size()),
                      SymKind::Var, t, current_);
}

void Sema::giveResultSlot(Call *c) { c->resultSlot = newResultSlot(c->type); }

void Sema::checkArguments(Symbol *callee, std::vector<ExprPtr> &args, int line,
                          int col) {
  // §6.6.3.7.1's "all possess the same type", which is a rule about a
  // *section* and so needs the first actual of the one being walked.
  Type *sectionType = nullptr;
  int sectionOf = 0;
  // Checked against the parameter rather than on its own, because an actual
  // procedural parameter is an identifier and not an expression: `f` there
  // denotes the function, where checkExpr would read it as a call of it. The
  // arity is only tested afterwards, so a wrong count still reports whatever
  // is wrong *inside* each argument as well.
  for (size_t i = 0; i < args.size(); ++i) {
    Symbol *p = i < callee->params.size() ? callee->params[i] : nullptr;
    if (p && p->kind == SymKind::ProcParam)
      checkProcArgument(p, args[i].get(), callee, i);
    else
      checkExpr(args[i].get());
  }

  if (args.size() != callee->params.size()) {
    diags_.error(line, col,
                 "'" + callee->name + "' takes " +
                     std::to_string(callee->params.size()) +
                     " argument(s), but " + std::to_string(args.size()) +
                     " were given");
    return;
  }

  for (size_t i = 0; i < args.size(); ++i) {
    Symbol *p = callee->params[i];
    Expr *a = args[i].get();

    if (p->kind == SymKind::ProcParam)
      continue; // already bound, above

    // §6.7.3.2 and §6.7.3.3: a schematic formal parameter's type is decided by
    // the actual, so the actual has only to be produced from the same schema —
    // whatever tuple it was produced with. It must be a variable either way,
    // because a value parameter of a size not known until now is copied out of
    // one rather than evaluated into one.
    // ISO 7185 §6.6.3.7's conformant array parameter. The formal carries a
    // descriptor exactly as a schematic formal does, so it arrives in the same
    // place — and what it wants of the actual is a different question: one
    // *conformable* with the schema (§6.6.3.8) rather than produced from it.
    if (p->isConformant) {
      // §6.6.3.7.3 for the variable form: "The actual-parameter shall be a
      // variable-access." §6.6.3.7.2 for the value form says the opposite in
      // as many words — "shall be an expression" — so a literal and a constant
      // are conforming actuals there, and everything a var parameter is
      // additionally under belongs to that half.
      if (p->kind == SymKind::VarParam && !isDesignator(a))
        diags_.error(a->line, a->col,
                     "argument " + std::to_string(i + 1) + " of '" +
                         callee->name +
                         "' is a conformant array parameter and needs a "
                         "variable");
      else if (p->kind == SymKind::VarParam && a->paren)
        diags_.error(a->line, a->col,
                     "argument " + std::to_string(i + 1) + " of '" +
                         callee->name +
                         "' is a conformant array parameter and needs a "
                         "variable; the brackets make this an expression");
      // §6.6.3.7.1: "The actual-parameters corresponding to formal-parameters
      // that occur in a single conformant-array-parameter-specification shall
      // all possess the same type." Not merely conformable and not merely
      // alike: §6.4.1 makes two identical declarations two types.
      else if (sectionType && a->type && p->paramSection == sectionOf &&
               a->type != sectionType)
        diags_.error(a->line, a->col,
                     "argument " + std::to_string(i + 1) + " of '" +
                         callee->name + "' is " + a->type->name() +
                         ", and the actuals of one conformant array section "
                         "must all possess the same type -- this one was " +
                         sectionType->name());
      // §6.6.3.7.2's last requirement, and its NOTE says what it is for: the
      // auxiliary variable's type has to be known where the copy is made. Both
      // shapes it admits yield a type that is not a schema, so the whole rule
      // is one test on the actual's type.
      else if (p->kind == SymKind::Param && a->type && a->type->isConfSchema)
        diags_.error(a->line, a->col,
                     "argument " + std::to_string(i + 1) + " of '" +
                         callee->name +
                         "' is a value conformant array, so its actual may not "
                         "be a conformant array parameter: the copy would have "
                         "no size known where it is made");
      else if (!conformable(a->type, p->type))
        diags_.error(a->line, a->col,
                     "argument " + std::to_string(i + 1) + " of '" +
                         callee->name +
                         "' is not conformable with the schema: " +
                         (a->type ? a->type->name() : std::string("untyped")) +
                         " against " + p->type->name());
      else if (p->kind == SymKind::VarParam) {
        // ISO/IEC 10206:1991 numbering here, the rule being one ISO 7185 does
        // not have: §6.9.4 b) reaches a conformant array's actual for the same
        // reason it reaches an ordinary one — §6.7.3.7.3 calls it "an
        // actual-parameter corresponding to a formal variable parameter" in
        // those words, and §6.5.1's own cross-reference names §6.7.3.7.1 as
        // one of the three places a protected variable-identifier comes from.
        // The value form is asked about deliberately and answers no:
        // §6.7.3.7.2 attributes the *expression's* value to a variable of the
        // activation, so nothing of the actual is written. And b)'s "that is
        // not protected" is what lets a protected conformant array be handed
        // on to another.
        if (!badVarActual(a, callee, i + 1) && !p->isProtected)
          checkNotThreatened(a, "it cannot be passed to the var parameter '" +
                                    p->name + "' of '" + callee->name + "'");
      }
      if (p->paramSection != sectionOf) {
        sectionOf = p->paramSection;
        sectionType = a->type;
      }
      continue;
    }

    if (p->descSchema) {
      // §6.7.3.2 gives the required schema `string` a paragraph of its own
      // when it names a *value* parameter: the actual is an expression "having
      // an underlying-type that is a string-type or the char-type", and the
      // formal possesses the type produced from the schema "with the tuple
      // having that length as its component" — the length of the value, not
      // the capacity of the variable it came out of. Every other schema-name
      // asks for a variable produced from it, which is the arm below.
      // §6.11.6's own Example 10, `record event('event-module
      // initialization')`, is a program the other arm refuses.
      if (isStringValueFormal(p)) {
        if (a->type && !a->type->isStringOrChar())
          diags_.error(a->line, a->col,
                       "argument " + std::to_string(i + 1) + " of '" +
                           callee->name +
                           "' is a string value parameter, so the argument "
                           "must be a string or a char, and this one is " +
                           a->type->name());
        continue;
      }
      if (!isDesignator(a))
        diags_.error(a->line, a->col,
                     "argument " + std::to_string(i + 1) + " of '" +
                         callee->name + "' needs a variable produced from "
                         "schema '" + p->descSchema->name + "'");
      else if (!a->type || a->type->schema != p->descSchema)
        diags_.error(a->line, a->col,
                     "argument " + std::to_string(i + 1) + " of '" +
                         callee->name + "' must be produced from schema '" +
                         p->descSchema->name + "', but the argument is " +
                         (a->type ? a->type->name() : std::string("untyped")));
      else
        badVarActual(a, callee, i + 1);
      continue;
    }

    if (p->kind == SymKind::VarParam) {
      if (!isDesignator(a)) {
        diags_.error(a->line, a->col,
                     "argument " + std::to_string(i + 1) + " of '" +
                         callee->name +
                         "' is a var parameter and needs a variable");
        continue;
      }
      // §6.6.3.3: the actual shall be a variable-access, and §6.5.1's are an
      // entire variable, a component, an identified variable and a buffer
      // variable — a parenthesised one is none of the four. `p((x))` is an
      // expression whose value happens to be x's, and a reference cannot be
      // established to it. Asked here rather than inside `isDesignator`, which
      // answers §6.5.1's question for a dozen constructs and would then be
      // answering it for reasons this clause does not give.
      if (a->paren) {
        diags_.error(a->line, a->col,
                     "argument " + std::to_string(i + 1) + " of '" +
                         callee->name +
                         "' is a var parameter and needs a variable; the "
                         "brackets make this an expression");
        continue;
      }
      // §6.7.3.3 NOTE 3: "An actual variable parameter cannot denote a
      // substring-variable because the type of a substring-variable is a new
      // fixed-string-type different from every named type." The rule below
      // would say so on its own — the canonical-string-type is not any named
      // type either — but the words it would use name a representation rather
      // than the reason.
      if (is<SubstringExpr>(a)) {
        diags_.error(a->line, a->col,
                     "argument " + std::to_string(i + 1) + " of '" +
                         callee->name +
                         "' cannot be a substring: a substring's type is a new "
                         "one, different from every named type, so no var "
                         "parameter can have it");
        continue;
      }
      if (badVarActual(a, callee, i + 1))
        continue;
      // §6.9.4 b) threatens an actual var parameter only when the *formal* is
      // not itself protected — which is what lets a protected parameter be
      // handed on, and is the base case that makes the rule usable at all.
      if (!p->isProtected)
        checkNotThreatened(a, "it cannot be passed to the var parameter '" +
                                  p->name + "' of '" + callee->name + "'");
      // §6.4.2.5's NOTE: "A variable of a restricted-type may be passed as a
      // variable parameter to a formal-parameter possessing the same type or
      // its underlying-type." The states are one-to-one and the representation
      // is the underlying-type's, so nothing is converted through the
      // reference — which is why this is a widening of the same-type rule and
      // not an exception to it. It goes one way only: a variable of the
      // *underlying*-type may not be passed where the restricted one is
      // expected, or the restriction would be escapable by declaring one
      // parameter.
      if (a->type && p->type && a->type != p->type &&
          a->type->isRestricted() && a->type->underlying() == p->type)
        continue;
      // No implicit conversion is possible through a reference, so the types
      // must be the same rather than merely assignment-compatible.
      if (a->type && p->type && a->type != p->type)
        diags_.error(a->line, a->col,
                     "var parameter '" + p->name + "' is " + p->type->name() +
                         ", but the argument is " + a->type->name() +
                         distinctTypeNote(p->type, a->type));
      continue;
    }

    // ISO/IEC 10206:1991 §6.4.5 d) made every string type compatible with
    // every other, and §6.4.6 pads the shorter — but a value parameter is
    // copied *bytewise*, so a shorter actual would be read past its end. The
    // padding needs somewhere to build the conversion, which is the same thing
    // a variable-string value parameter needs and does not have (ADR-0052), so
    // the lengths must agree until it does.
    if (p->type && p->type->isCharArray() && a->type &&
        a->type->isStringOrChar() && !p->type->dynamicBounds() &&
        (!a->type->isCharArray() || a->type->dynamicBounds() ||
         a->type->length() != p->type->length()))
      diags_.error(a->line, a->col,
                   "argument " + std::to_string(i + 1) + " of '" +
                       callee->name + "' is " + p->type->name() +
                       ", and a value parameter is copied rather than padded; "
                       "so the argument must have the same length");
    // A structured value parameter is a copy, so it needs something to copy
    // from: a designator, a string literal, a structured-value-constructor
    // (ADR-0061), a constant whose value lives in memory (ADR-0068), or a
    // *call* whose result is structured. None of the last four is a variable
    // and each has storage — a constructor because §6.8.7's value is *built*
    // rather than computed, a constant because it is its defining expression
    // named, and a call because ADR-0055 gives a structured result
    // caller-supplied storage.
    //
    // The call was missing and that was a defect, not a restriction. §6.6.3.2
    // makes a value parameter's actual an *expression* and §6.7.1 makes a
    // function-designator one, so `f(g)` is legal wherever `f(v)` is. What
    // kept it out was isDesignator answering false for a call — the right
    // answer to a different question, the one a *var* parameter asks, where
    // there is no variable to bind. Assignment had already settled it the
    // other way: `q := MakePoint` copies from exactly this address.
    else if (p->type && p->type->isStructured() && !isDesignator(a) &&
             !is<StrLit>(a) && !is<StructValueExpr>(a) && !is<Call>(a) &&
             !isMemoryConstant(a))
      diags_.error(a->line, a->col,
                   "argument " + std::to_string(i + 1) + " of '" +
                       callee->name + "' is " + p->type->name() +
                       " and needs a variable");
    else if (!assignable(p->type, a->type))
      diags_.error(a->line, a->col,
                   "argument " + std::to_string(i + 1) + " of '" +
                       callee->name + "' is " + p->type->name() +
                       ", but the value is " + a->type->name() +
                       distinctTypeNote(p->type, a->type));
  }

  // §6.7.3.3: one formal-parameter-section is one parameter-form, so every
  // actual corresponding to it brings the same tuple — `var a, b: vector`
  // takes two vectors of one length, not two vectors. The standard calls a
  // mismatch a dynamic-violation; every tuple this compiler can write is
  // already known here, so it is reported before the program runs.
  for (size_t i = 0; i < args.size(); ++i) {
    Symbol *p = callee->params[i];
    // §6.7.3.2 puts a different rule on `string` as a value parameter, and it
    // is not this one: "it shall be an error if the values ... do not all have
    // the same length". Lengths, not types, and an error rather than a
    // violation — so `pair(v3, 'xyz')` is legal with two actuals of one length
    // whose types differ, and holding them to one type would refuse it.
    if (!p->descSchema || isStringValueFormal(p) || !args[i]->type ||
        args[i]->type->isGeneric())
      continue;
    for (size_t j = 0; j < i; ++j) {
      Symbol *q = callee->params[j];
      if (q->descSchema != p->descSchema ||
          q->paramSection != p->paramSection || !args[j]->type ||
          args[j]->type->isGeneric() || args[j]->type == args[i]->type)
        continue;
      diags_.error(args[i]->line, args[i]->col,
                   "'" + q->name + "' and '" + p->name +
                       "' are one parameter form, so their arguments are one "
                       "type: found " + args[j]->type->name() + " and " +
                       args[i]->type->name());
    }
  }
}

/// The names ISO 7185 §6.6.5 and §6.6.6 reserve for the required procedures
/// and functions. Asked by name, because the answer a caller wants is null
/// either way: a required procedure is not a symbol at all, and a required
/// function is one that `lookupUser` turns back into null (§6.2.2.10). So a
/// program that tries to pass one gets "undeclared identifier" unless it is
/// recognised here, which would be a baffling way to report §6.6.3.7.
/// The five required functions ISO/IEC 10206:1991 adds for the complex type.
/// They are grouped because every question anyone asks about them is the same
/// one: does this standard have them?
static bool isRequiredName(const std::string &name) {
  static const char *procs[] = {"new",   "dispose", "reset",  "rewrite",
                                "get",   "put",     "read",   "readln",
                                "write", "writeln", "pack",   "unpack"};
  for (const char *p : procs)
    if (name == p)
      return true;
  return builtins().count(name) != 0;
}

void Sema::checkProcArgument(Symbol *formal, Expr *a, Symbol *callee,
                             size_t at) {
  const std::string where =
      "argument " + std::to_string(at + 1) + " of '" + callee->name + "'";
  // Whatever happens below, the argument leaves here with the formal's type:
  // codegen reads `sym`, and a null type would break the contract that every
  // expression has one.
  a->type = formal->type;

  // §6.7.3.4 and §6.7.3.5 ask for a *procedure-name* and a *function-name*,
  // and §6.7.1 and §6.7.2 spell both as an optional interface qualifier and an
  // identifier — so `i.p` is one of the two forms the clause admits. The
  // parser builds it as a field selection and only the symbol the base
  // resolves to tells them apart (ADR-0053), which is why it is asked here.
  //
  // Note that difftest cannot see this rule: it never passes `--import`, so
  // every case with a `.components` sidecar is compared as two identical
  // rejections about an interface neither front end has heard of. This is
  // carried here on its merits (doc/sop.md §7).
  auto *fld = as<FieldExpr>(a);
  const bool viaIface = fld && as<VarRef>(fld->base.get()) &&
                        isInterfaceName(as<VarRef>(fld->base.get())->name);
  auto *v = as<VarRef>(a);
  if (!v && !viaIface) {
    diags_.error(a->line, a->col,
                 where + " must be the name of a procedure or function");
    return;
  }

  const std::string name = viaIface ? fld->field : v->name;
  const int line = viaIface ? fld->line : v->line;
  const int col = viaIface ? fld->col : v->col;

  // `lookupUser`: §6.6.3.7's answer is the same whether the name is a required
  // procedure (not a symbol at all) or a required function (a marker symbol),
  // so both must arrive here as null for `isRequiredName` to speak for them.
  // A qualified name goes through `lookupName`, which reports an interface
  // nobody exported and a constituent one does not export, so a null from
  // there has already been complained about.
  Symbol *sym =
      viaIface ? lookupName(as<VarRef>(fld->base.get())->name, name, line, col)
               : lookupUser(name);
  if (!sym) {
    if (viaIface)
      return;
    // ISO 7185 §6.6.3.7: the actual parameter shall not denote a required
    // procedure or function. There is nothing to pass — `write` takes a
    // variable number of arguments of types no parameter list can spell, and
    // `abs` is an instruction rather than a body with an address.
    if (isRequiredName(name))
      diags_.error(line, col,
                   "'" + name +
                       "' is a required procedure or function and "
                       "cannot be passed as a parameter");
    else
      diags_.error(line, col, "undeclared identifier '" + name + "'");
    return;
  }
  if (!sym->isInvocable()) {
    diags_.error(line, col,
                 where + " must be the name of a procedure or function, but '" +
                     name + "' is not one");
    return;
  }
  // The husk rule (ADR-0044): the node the parser built is left as it is, and
  // the resolved symbol goes in the field that node kind already has for "the
  // symbol this denotes".
  if (viaIface)
    fld->qualified = sym;
  else
    v->sym = sym;

  // ISO 7185 §6.6.3.6. The lists are compared rather than the types, because a
  // procedural parameter has no type to write down: the heading *is* the type.
  if (!congruous(formal, sym))
    diags_.error(line, col,
                 "'" + name + "' does not match the parameter list of " +
                     (formal->resultType() ? "functional" : "procedural") +
                     " parameter '" + formal->name + "'");
}

/// ISO/IEC 10206:1991 §6.7.6.5's `empty` and §6.7.6.6's `position` and
/// `LastPosition`. All three take a file variable and nothing else — no
/// default, unlike `eof`, because there is no standard direct-access file to
/// default to.
void Sema::checkFileEnquiry(Call *c) {
  c->type = c->builtin == Builtin::Empty ? ty::Bool() : ty::Int();
  if (c->args.size() != 1) {
    diags_.error(c->line, c->col,
                 "'" + c->name + "' takes exactly one file variable");
    return;
  }
  Expr *a = c->args[0].get();
  if (!isDesignator(a) || (a->type && !a->type->isFile())) {
    diags_.error(a->line, a->col,
                 "'" + c->name + "' needs a file variable" +
                     (a->type ? ", found " + a->type->name() : ""));
    return;
  }
  if (a->type && !a->type->isDirectAccess()) {
    diags_.error(a->line, a->col,
                 "'" + c->name + "' needs a direct-access file, and " +
                     a->type->name() + " has no index type");
    return;
  }
  // §6.7.6.6: "shall return a result of type T" — the *index* type, not an
  // integer. That is the whole reason the index-type is kept on the Type.
  if (a->type && c->builtin != Builtin::Empty)
    c->type = a->type->indexType;
  return;
}

/// §6.7.6.7's ten string functions. They take one, two or three arguments, so
/// they are checked apart from the required functions whose arity is one.
void Sema::checkStringBuiltin(Call *c) {
  // The arguments were checked before the dispatch above; checking them again
  // is not merely wasted work, because `checkExpr` is not idempotent — a
  // parameterless function used as a value takes a hidden frame slot each
  // time, and a second one is a slot nothing ever writes to.
  auto stringy = [&](Expr *a) {
    if (a->type && !a->type->isStringOrChar())
      diags_.error(a->line, a->col,
                   "'" + c->name + "' needs a string or a char, found " +
                       a->type->name());
  };
  if (isStringCompare(c->builtin)) {
    c->type = ty::Bool();
    if (c->args.size() != 2) {
      diags_.error(c->line, c->col, "'" + c->name + "' takes two strings");
      return;
    }
    stringy(c->args[0].get());
    stringy(c->args[1].get());
    return;
  }
  if (c->builtin == Builtin::Index) {
    c->type = ty::Int();
    if (c->args.size() != 2) {
      diags_.error(c->line, c->col, "'index' takes two strings");
      return;
    }
    stringy(c->args[0].get());
    stringy(c->args[1].get());
    return;
  }
  if (c->builtin == Builtin::Length) {
    c->type = ty::Int();
    if (c->args.size() != 1) {
      diags_.error(c->line, c->col, "'length' takes one string");
      return;
    }
    stringy(c->args[0].get());
    return;
  }
  // §6.7.6.7: `trim` and `substr` "return a result of the
  // canonical-string-type" — a value with no capacity, because it has no
  // storage. What it may be assigned to is decided by its *length*, where
  // the value finally is.
  c->type = ty::CanonicalString();
  if (c->builtin == Builtin::Trim) {
    if (c->args.size() != 1) {
      diags_.error(c->line, c->col, "'trim' takes one string");
      return;
    }
    stringy(c->args[0].get());
    return;
  }
  if (c->args.size() != 2 && c->args.size() != 3) {
    diags_.error(c->line, c->col,
                 "'substr' takes a string and one or two positions");
    return;
  }
  stringy(c->args[0].get());
  for (size_t i = 1; i < c->args.size(); ++i)
    if (c->args[i]->type && !c->args[i]->type->isInteger())
      diags_.error(c->args[i]->line, c->args[i]->col,
                   "the positions of 'substr' are integers, found " +
                       c->args[i]->type->name());
  return;
}

void Sema::checkCall(Call *c) {
  // §6.11.3's qualified name. A required function is never one of the answers,
  // so this returns whatever the interface holds or nothing at all.
  if (!c->qualifier.empty()) {
    Symbol *sym = lookupName(c->qualifier, c->name, c->line, c->col);
    c->type = ty::Int();
    if (!sym)
      return;
    if (!sym->isInvocable() || !sym->resultType()) {
      diags_.error(c->line, c->col,
                   "'" + c->qualifier + "." + c->name +
                       "' is not a function");
      return;
    }
    c->sym = sym;
    c->type = sym->resultType();
    giveResultSlot(c);
    checkArguments(sym, c->args, c->line, c->col);
    return;
  }

  // A user-defined function shadows nothing built in: names are resolved in
  // the scope chain first, so a local `abs` would win.
  // The required one is a symbol too (§6.2.2.10), and `lookupUser` is what
  // turns it back into the null this branch reads as "not the program's own".
  if (Symbol *sym = lookupUser(c->name)) {
    if (sym->isInvocable() && sym->resultType()) {
      c->sym = sym;
      c->type = sym->resultType();
      giveResultSlot(c);
      checkArguments(sym, c->args, c->line, c->col);
      return;
    }
    if (sym->isInvocable()) {
      diags_.error(c->line, c->col,
                   "'" + c->name + "' is a procedure and returns no value");
      c->type = ty::Int();
      return;
    }
    // §6.2.2.11: "Whatever an identifier or label denotes at its
    // defining-point shall be denoted at all applied occurrences of that
    // identifier or label." So a program that declares `ord` a variable has no
    // `ord` function in that block — the builtin table below resolves by
    // *spelling* and cannot see that, which left `var ord: array [1..3] of
    // integer` and `ord('a')` meaning two things at once. The required
    // *procedures* never had this: their path has no fallback and reports
    // here, which is the asymmetry §6.2.2.10 does not license, both being
    // named in its one sentence.
    diags_.error(c->line, c->col, "'" + c->name + "' is not a function");
    c->type = ty::Int();
    return;
  }

  auto it = builtins().find(c->name);
  // The complex functions are ISO/IEC 10206:1991's, and their names are not
  // reserved in either language — a valid ISO 7185 program may declare a
  // function called `re`. So they are recognised only when nothing else of
  // that name was found, and only under the standard that has them; the
  // message then says the feature is missing rather than that the name is.
  if (it != builtins().end() && std_ == Std::Iso7185 &&
      (isComplexBuiltin(it->second) || isFileEnquiry(it->second) ||
       isStringBuiltin(it->second) || isBindingBuiltin(it->second) ||
       isTimeBuiltin(it->second) || it->second == Builtin::Card)) {
    diags_.error(c->line, c->col,
                 "'" + c->name + "' is an Extended Pascal function; compile "
                 "with --std=extended");
    c->type = ty::Int();
    return;
  }
  if (it == builtins().end()) {
    diags_.error(c->line, c->col, "unknown function '" + c->name + "'");
    c->type = ty::Int();
    return;
  }
  c->builtin = it->second;

  for (auto &a : c->args)
    checkExpr(a.get());

  // `eof` and `eoln` are the only required functions whose argument may be
  // left out, and the only ones taking a file (ISO 7185 §6.6.6.5). The default
  // is supplied here rather than in codegen, so that by the time the tree is
  // handed on, both forms look the same.
  // §6.7.6.5 and §6.7.6.6: `empty`, `position` and `LastPosition` take a file
  // variable and nothing else — no default, unlike `eof`, because there is no
  // standard direct-access file to default to.
  if (isFileEnquiry(c->builtin)) {
    checkFileEnquiry(c);
    return;
  }

  if (c->builtin == Builtin::Eof || c->builtin == Builtin::Eoln) {
    c->type = ty::Bool();
    if (c->args.empty()) {
      if (ExprPtr def = standardFileRef(true, c->line, c->col))
        c->args.push_back(std::move(def));
      return;
    }
    if (c->args.size() != 1) {
      diags_.error(c->line, c->col,
                   "'" + c->name + "' takes one file, or none at all");
      return;
    }
    Expr *a = c->args[0].get();
    if (!isDesignator(a) || (a->type && !a->type->isFile()))
      diags_.error(a->line, a->col,
                   "'" + c->name + "' needs a file variable" +
                       (a->type ? ", found " + a->type->name() : ""));
    // `eof` asks a question every file can answer; `eoln` asks about a line,
    // and only a text file has those (ISO 7185 §6.6.6.5).
    else if (c->builtin == Builtin::Eoln && a->type && !a->type->isText())
      diags_.error(a->line, a->col,
                   "'eoln' needs a text file, but " + a->type->name() +
                       " has no lines");
    return;
  }

  // §6.7.6.3: `cmplx(x, y)` and `polar(r, t)` are the two-argument required
  // functions, and the only way to write a complex value at all — the standard
  // gives the type no literal.
  // §6.7.6.8: `binding(f)` returns a BindingType — the only required function
  // whose result is a record. This compiler returns no records, so the value
  // is built in a hidden frame slot and the call *is* that designator, which
  // is what makes `binding(f).bound` and `b := binding(f)` need no cases.
  if (c->builtin == Builtin::Binding) {
    c->type = bindingType_ ? bindingType_ : ty::Int();
    // The arguments were checked by the loop above, once. A second loop here
    // reported every diagnostic in the argument twice — `binding(nosuch)`
    // said "undeclared identifier 'nosuch'" and then said it again — and no
    // corpus source had ever called `binding` on a name that failed to
    // resolve, so difftest had nothing to disagree about until one did.
    if (c->args.size() != 1) {
      diags_.error(c->line, c->col, "'binding' takes one bindable variable");
      return;
    }
    Expr *a = c->args[0].get();
    if (!isDesignator(a) || (a->type && !a->type->isFile())) {
      diags_.error(a->line, a->col,
                   "'binding' needs a file variable" +
                       (a->type ? ", found " + a->type->name() : ""));
      return;
    }
    if (!designatorBindable(a))
      notBindable(a);
    else if (current_ && bindingType_)
      c->resultSlot = addHiddenVar(
          "binding$" + std::to_string(current_->frameVars.size()),
          SymKind::Var, bindingType_, current_);
    return;
  }

  // §6.7.6.9: `date(t)` and `time(t)` "return a result of the
  // canonical-string-type with an implementation-defined length" from a
  // TimeStamp. They are the only required functions whose *argument* is a
  // record, and the type test is identity because §6.4.3.4's record is the one
  // built in `installPredefined` and ADR-0017 makes no other record that type.
  if (isTimeBuiltin(c->builtin)) {
    c->type = ty::CanonicalString();
    if (c->args.size() != 1) {
      diags_.error(c->line, c->col, "'" + c->name + "' takes one TimeStamp");
      return;
    }
    // "From the expression t" — an expression, not a variable-access, so
    // unlike `GetTimeStamp` this needs no designator and threatens nothing.
    Expr *a = c->args[0].get();
    if (a->type && a->type != timeStampType_)
      diags_.error(a->line, a->col,
                   "'" + c->name + "' needs a TimeStamp, found " +
                       a->type->name());
    return;
  }

  // §6.7.6.7's ten. They take one, two or three arguments, so they are
  // checked before the "exactly one" gate below.
  if (isStringBuiltin(c->builtin)) {
    checkStringBuiltin(c);
    return;
  }

  if (c->builtin == Builtin::Cmplx || c->builtin == Builtin::Polar) {
    if (c->args.size() != 2) {
      diags_.error(c->line, c->col,
                   "'" + c->name + "' takes two real arguments");
      c->type = ty::Complex();
      return;
    }
    for (ExprPtr &arg : c->args)
      if (arg->type && !arg->type->isNumeric())
        diags_.error(arg->line, arg->col,
                     "'" + c->name + "' needs real arguments, found " +
                         arg->type->name());
    c->type = ty::Complex();
    return;
  }

  // §6.7.6.4: `succ(x, k)` and `pred(x, k)` take a second, integer argument —
  // "a value whose ordinal number is ord(x) + k" — and the one-argument forms
  // are defined as `succ(x, 1)` and `succ(x, -1)`. They are the only required
  // functions here whose arity is not exactly one, so the gate says so rather
  // than being moved.
  bool stepped = std_ == Std::Extended && c->args.size() == 2 &&
                 (c->builtin == Builtin::Succ || c->builtin == Builtin::Pred);
  if (c->args.size() != 1 && !stepped) {
    diags_.error(c->line, c->col,
                 "'" + c->name + "' takes exactly one argument" +
                     (c->builtin == Builtin::Succ ||
                              c->builtin == Builtin::Pred
                          ? std::string(", or two under --std=extended")
                          : std::string()));
    c->type = ty::Int();
    return;
  }
  if (stepped && c->args[1]->type && !c->args[1]->type->isInteger())
    diags_.error(c->args[1]->line, c->args[1]->col,
                 "the second argument of '" + c->name +
                     "' is how far to step, and must be an integer, found " +
                     c->args[1]->type->name());

  Type *a = c->args[0]->type;
  auto require = [&](bool ok, const char *want) {
    if (!ok)
      diags_.error(c->line, c->col, "'" + c->name + "' needs " + want +
                                        " argument, found " + a->name());
  };

  switch (c->builtin) {
  // §6.7.6.2, table 2 footnote 5: `abs` of a complex is its *magnitude*, and
  // so a real — the one function in the table whose result kind changes rather
  // than following its operand.
  case Builtin::Abs:
    require(a->isArith(), "a numeric");
    c->type = a->isComplex() ? ty::Real() : a->isReal() ? ty::Real()
                                                        : ty::Int();
    return;
  // `sqr` keeps its operand's type, complex included.
  case Builtin::Sqr:
    require(a->isArith(), "a numeric");
    c->type = a->isComplex() ? ty::Complex()
              : a->isReal()  ? ty::Real()
                             : ty::Int();
    return;
  // §6.7.6.2: `re`, `im` and `arg` take a complex and yield a real.
  case Builtin::Re:
  case Builtin::Im:
  case Builtin::Arg:
    require(a->isComplex(), "a complex");
    c->type = ty::Real();
    return;
  case Builtin::Odd:
    require(a->isInteger(), "an integer");
    c->type = ty::Bool();
    return;
  case Builtin::Ord:
    require(a->isOrdinal(), "an ordinal");
    c->type = ty::Int();
    return;
  case Builtin::Chr:
    require(a->isInteger(), "an integer");
    c->type = ty::Char();
    return;
  // §6.7.6.3: "this function shall return a result of integer-type that shall
  // equal the number of members of the value of the expression x."
  case Builtin::Card:
    require(a->isSet(), "a set");
    c->type = ty::Int();
    return;
  case Builtin::Succ:
  case Builtin::Pred:
    // §6.6.6.4 gives the result "the same type as that of the expression (see
    // 6.7.1)", and that cross-reference is the whole rule: §6.7.1 says "any
    // factor whose type is S, where S is a subrange of T, shall be treated as
    // if it were of type T". So the result of succ on a `1..9` is an *integer*
    // and succ(9) is 10; what fails is storing it back. An enumeration has no
    // host to be promoted to, so it still ends at its last constant — the
    // asymmetry is the standard's, and BSI asserts both halves in one release
    // (CONF139 and ERR56T).
    require(a->isOrdinal(), "an ordinal");
    c->type = a->base();
    return;
  // §6.6.6.3 spells both the same way: "From the expression x that shall be of
  // real-type". An integer is *not* one — there is nothing for either function
  // to do to it, which is presumably why the standard did not extend the
  // offer. Accepting one was a permissive deviation with nothing in the corpus
  // to notice it; the suite's DEV158 is what did. ISO/IEC 10206:1991 §6.7.6.3
  // uses the same words.
  case Builtin::Trunc:
  case Builtin::Round:
    require(a->isReal(), "a real");
    c->type = ty::Int();
    return;
  default:
    // §6.7.6.2: `sin cos exp ln sqrt arctan` take an integer, a real or a
    // complex, and the result is "real if the operand is of integer-type,
    // otherwise the type of the operand" — so a complex operand gives a
    // complex result and everything else gives a real.
    require(a->isArith(), "a numeric");
    c->type = a->isComplex() ? ty::Complex() : ty::Real();
    return;
  }
}

} // namespace ap
