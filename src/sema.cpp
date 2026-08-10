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
  };
  return m;
}

Type *builtinType(const std::string &name) {
  if (name == "integer") return ty::Int();
  if (name == "real")    return ty::Real();
  if (name == "boolean") return ty::Bool();
  if (name == "char")    return ty::Char();
  if (name == "text")    return ty::Text();
  return nullptr;
}

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
  Symbol *s = newSymbol();
  s->name = name;
  s->kind = kind;
  scope[name] = s;
  return s;
}

/// Innermost-first lookup, which is what makes an inner declaration shadow an
/// outer one of the same name.
Symbol *Sema::lookup(const std::string &name) const {
  for (auto scope = scopes_.rbegin(); scope != scopes_.rend(); ++scope) {
    auto it = scope->find(name);
    if (it != scope->end())
      return it->second;
  }
  return nullptr;
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

bool Sema::evalOrdinal(Expr *e, Type *&type, long long &value) {
  checkExpr(e);
  Symbol out;
  if (!evalConst(e, out) || !out.type || !out.type->isOrdinal())
    return false;
  type = out.type;
  if (out.type->isChar())
    value = static_cast<unsigned char>(out.charVal);
  else if (out.type->base()->kind == TypeKind::Boolean)
    value = out.boolVal ? 1 : 0;
  else
    value = out.intVal; // integer, and the ordinal of an enumeration constant
  return true;
}

/// An enumerated type also *declares* its constants, into whatever scope the
/// type itself appears in (ISO 7185 §6.4.2.3) — which is why this is done here
/// rather than by the declaration part that happens to contain it.
Type *Sema::resolveEnum(TypeExpr &denoter) {
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

/// A pointer's domain is a type identifier, and it may be one defined later in
/// the same type part — the language's only forward reference, and the reason
/// a record can contain a pointer to itself.
Type *Sema::resolvePointer(TypeExpr &denoter) {
  Type *t = newType(TypeKind::Pointer);
  if (Type *builtin = builtinType(denoter.name)) {
    t->elem = builtin;
    return t;
  }
  Symbol *sym = lookup(denoter.name);
  if (sym && sym->kind == SymKind::Type) {
    t->elem = sym->type;
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
  t->elem = component;
  t->packed = denoter.packed;
  return t;
}

void Sema::resolvePendingPointers() {
  for (PendingPointer &p : pendingPointers_) {
    Symbol *sym = lookup(p.domain);
    if (sym && sym->kind == SymKind::Type) {
      p.pointer->elem = sym->type;
      continue;
    }
    diags_.error(p.line, p.col,
                 "unknown type '" + p.domain + "' as the domain of a pointer");
    p.pointer->elem = ty::Int(); // keep the tree checkable
  }
  pendingPointers_.clear();
}

Type *Sema::resolveSubrange(TypeExpr &denoter) {
  Type *loType = nullptr;
  Type *hiType = nullptr;
  long long lo = 0, hi = 0;
  bool ok = true;

  if (!evalOrdinal(denoter.lo.get(), loType, lo) ||
      !evalOrdinal(denoter.hi.get(), hiType, hi)) {
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
  else if (index->ordinalHi() - index->ordinalLo() >= kMaxInt) {
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
  t->packed = denoter.packed;
  t->elem = dim + 1 < denoter.dims.size() ? resolveArray(denoter, dim + 1)
                                          : resolveType(*denoter.elem);
  return t;
}

/// ISO 7185 §6.4.3.3 requires every field name in a record to be distinct,
/// across the fixed part and every variant alike — which is what lets one flat
/// lookup answer where a name lives.
void Sema::addField(Type *record, std::vector<Field> &into,
                    const DeclName &name, Type *type,
                    const std::vector<int> &variant) {
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
  into.push_back(std::move(f));
}

Type *Sema::resolveRecord(TypeExpr &denoter) {
  Type *t = newType(TypeKind::Record);
  t->packed = denoter.packed;
  for (FieldGroup &group : denoter.fields) {
    Type *fieldType = resolveType(*group.type);
    for (DeclName &n : group.names)
      addField(t, t->fields, n, fieldType, {});
  }
  if (denoter.tagType) {
    std::vector<int> path;
    resolveVariantPart(denoter.tagName, denoter.tagType.get(),
                       denoter.variants, denoter.tagLine,
                       denoter.tagCol, t, t->fields, t->variants,
                       t->tagField, t->tagType, path);
  }
  return t;
}

void Sema::resolveVariantPart(const std::string &tagName, TypeExpr *tagDenoter,
                              std::vector<VariantArm> &arms, int tagLine,
                              int tagCol, Type *record,
                              std::vector<Field> &fields,
                              std::vector<Variant> &variants, int &tagField,
                              Type *&tagTypeOut, std::vector<int> &path) {
  Type *tag = resolveType(*tagDenoter);
  if (!tag->isOrdinal()) {
    diags_.error(tagLine, tagCol,
                 "the tag of a variant part must be an ordinal type, found " +
                     tag->name());
    return;
  }
  tagTypeOut = tag;

  // A named tag is an ordinary field of the field-list it heads; a tagless
  // variant part has the type but no storage for it (ISO 7185 §6.4.3.3).
  if (!tagName.empty()) {
    tagField = static_cast<int>(fields.size());
    addField(record, fields, {tagName, tagLine, tagCol}, tag, path);
  }

  std::unordered_map<long long, int> claimed; // tag value -> variant that owns it
  for (VariantArm &arm : arms) {
    Variant v;
    v.line = arm.line;
    v.col = arm.col;
    int index = static_cast<int>(variants.size());

    for (ExprPtr &label : arm.labels) {
      Type *labelType = nullptr;
      long long value = 0;
      if (!evalOrdinal(label.get(), labelType, value)) {
        diags_.error(label->line, label->col,
                     "a variant's label must be an ordinal constant");
        continue;
      }
      if (labelType->base() != tag->base()) {
        diags_.error(label->line, label->col,
                     "this variant's tag is " + tag->name() +
                         ", but the label is " + labelType->name());
        continue;
      }
      auto seen = claimed.find(value);
      if (seen != claimed.end()) {
        diags_.error(label->line, label->col,
                     "the tag value " + Type::ordinalName(tag, value) +
                         " already selects an earlier variant");
        continue;
      }
      claimed[value] = index;
      v.labels.push_back(value);
    }

    // The fields are pushed into the arm, so each variant is numbered from
    // zero and codegen can index it as a struct of its own.
    variants.push_back(std::move(v));
    path.push_back(index);
    for (FieldGroup &group : arm.fields) {
      Type *fieldType = resolveType(*group.type);
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
                         path);
    path.pop_back();
  }
}

Type *Sema::resolveType(TypeExpr &denoter) {
  if (denoter.resolved)
    return denoter.resolved;

  Type *t = nullptr;
  switch (denoter.kind) {
  case TEK::Named:
    if ((t = builtinType(denoter.name)) == nullptr) {
      Symbol *sym = lookup(denoter.name);
      if (sym && sym->kind == SymKind::Type) {
        t = sym->type;
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
  }

  denoter.resolved = t;
  return t;
}

void Sema::installPredefined() {
  Symbol *t = declare("true", SymKind::Const, 0, 0);
  t->type = ty::Bool();
  t->boolVal = true;

  Symbol *f = declare("false", SymKind::Const, 0, 0);
  f->type = ty::Bool();
  f->boolVal = false;

  Symbol *m = declare("maxint", SymKind::Const, 0, 0);
  m->type = ty::Int();
  m->intVal = kMaxInt;
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
  // A file is never assignable, not even to itself: ISO 7185 §6.8.2.2 excludes
  // a file type from assignment, and §6.7.2.5 gives it no relational operators
  // either. Both questions arrive here, so both are answered by this line —
  // which is also why `isStructured()` deliberately excludes files, since that
  // predicate is what grants a whole-variable copy.
  if (to->isFile() || from->isFile())
    return false;
  // A procedural parameter is not a value either: ISO 7185 gives it no
  // assignment and no operators, and the only place one may travel is another
  // procedural parameter — which checkProcArgument handles without coming here.
  if (to->isProc() || from->isProc())
    return false;
  if (to == from)
    return true;
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
    return to->elem->base() == from->elem->base();
  }
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

bool Sema::isDesignator(Expr *e) const {
  if (auto *v = as<VarRef>(e))
    return v->sym && (v->sym->isVariable() || v->withField);
  if (auto *i = as<IndexExpr>(e))
    return isDesignator(i->base.get());
  if (auto *f = as<FieldExpr>(e))
    return isDesignator(f->base.get());
  // What a pointer points at is a variable however the pointer was obtained,
  // so a dereference is a designator even when its base is not.
  if (is<DerefExpr>(e))
    return true;
  return false;
}

Symbol *Sema::baseSymbol(Expr *e) const {
  if (auto *v = as<VarRef>(e))
    return v->sym;
  if (auto *i = as<IndexExpr>(e))
    return baseSymbol(i->base.get());
  if (auto *f = as<FieldExpr>(e))
    return baseSymbol(f->base.get());
  return nullptr;
}

// ------------------------------------------------------------------- driver

void Sema::run(Program &prog) {
  pushScope(); // the predefined identifiers live in their own outermost scope
  installPredefined();

  program_ = newSymbol();
  program_->name = prog.name;
  program_->kind = SymKind::Proc;
  program_->level = 0;
  program_->defined = true;
  current_ = program_;
  prog_ = &prog;

  pushScope();
  // `input` and `output` are declared by the program header rather than by the
  // block, so they exist before the declarations are seen. Declaring them only
  // when they are listed is what makes using `write` without `output` in the
  // header the error ISO 7185 §6.10 says it is.
  for (DeclName &p : prog.params) {
    if (p.name == "input" && !stdInput_) {
      stdInput_ = addFrameVar(p.name, SymKind::Var, ty::Text(), program_,
                              p.line, p.col);
      stdInput_->fileBinding = FileBinding::StandardInput;
    } else if (p.name == "output" && !stdOutput_) {
      stdOutput_ = addFrameVar(p.name, SymKind::Var, ty::Text(), program_,
                               p.line, p.col);
      stdOutput_->fileBinding = FileBinding::StandardOutput;
    }
  }
  checkBlock(*prog.block, program_);
  popScope();
  popScope();
}

void Sema::bindProgramParameters() {
  if (!prog_)
    return;
  // argv[0] is the program itself, so the first file parameter is argv[1].
  int argIndex = 1;
  for (DeclName &p : prog_->params) {
    Symbol *s = lookup(p.name);
    if (!s || !s->isVariable()) {
      diags_.error(p.line, p.col,
                   "the program parameter '" + p.name +
                       "' is not declared as a variable in the program block");
      continue;
    }
    if (s == stdInput_ || s == stdOutput_)
      continue; // bound by the header itself
    if (!s->type || !s->type->isFile()) {
      diags_.error(p.line, p.col,
                   "a program parameter must be a file variable, but '" +
                       p.name + "' is " +
                       (s->type ? s->type->name() : std::string("untyped")));
      continue;
    }
    s->fileBinding = FileBinding::Argument;
    s->fileArg = argIndex++;
  }
}

/// The file a `read` or `write` acts on when it named none. The reference is
/// synthesised rather than left for codegen to work out: ADR-0008 has codegen
/// never resolving a name, so the defaulted file arrives as an ordinary
/// resolved VarRef like any other.
ExprPtr Sema::standardFileRef(bool input, int line, int col) {
  Symbol *file = input ? stdInput_ : stdOutput_;
  const char *name = input ? "input" : "output";
  if (!file) {
    diags_.error(line, col,
                 std::string("'") + name +
                     "' must be listed as a program parameter to use it");
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
    l->id = found->id;
  }

  stmtPath_.push_back(l);
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
      bool reachable = found->path.size() <= pending.path.size();
      for (size_t i = 0; reachable && i < found->path.size(); ++i)
        reachable = found->path[i] == pending.path[i];
      if (!reachable) {
        diags_.error(g->line, g->col,
                     "label " + std::to_string(g->label) + " is inside a "
                     "statement this goto is not: a goto may leave a "
                     "structured statement but not enter one");
        continue;
      }
    } else if (!found->path.empty()) {
      diags_.error(g->line, g->col,
                   "label " + std::to_string(g->label) + " is in an enclosing "
                   "block, so it must label a statement of that block's "
                   "statement part and not one inside a statement of it");
      continue;
    } else {
      // The placement is legal; the lowering is what is missing. A non-local
      // goto abandons the activations between here and the target, which
      // needs the frames unwound and their files closed — see ADR-0029.
      diags_.error(g->line, g->col,
                   "a goto to a label in an enclosing block is not "
                   "implemented; only a goto within one block is");
      continue;
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
  checkLabelPart(block, owner);
  for (auto &c : block.consts) {
    checkExpr(c.value.get());
    Symbol value;
    if (!evalConst(c.value.get(), value)) {
      diags_.error(c.line, c.col,
                   "the value of constant '" + c.name +
                       "' is not a compile-time constant");
      continue;
    }
    Symbol *s = declare(c.name, SymKind::Const, c.line, c.col);
    s->type = value.type;
    s->intVal = value.intVal;
    s->realVal = value.realVal;
    s->charVal = value.charVal;
    s->boolVal = value.boolVal;
  }

  // A type name is visible to the definitions after it, so each is declared as
  // it is resolved rather than all at the end.
  for (auto &t : block.types) {
    Type *resolved = resolveType(*t.type);
    Symbol *s = declare(t.name, SymKind::Type, t.line, t.col);
    if (s->type)
      continue; // a duplicate: keep the first definition
    s->type = resolved;
    if (resolved->alias.empty())
      resolved->alias = t.name;
  }
  // Every name in the type part is now visible, so the pointers that named one
  // before it existed can be completed.
  resolvePendingPointers();

  for (auto &group : block.vars) {
    // One denoter for the whole group, so `a, b: array [1..3] of integer`
    // makes a and b the same type and lets `a := b` through.
    Type *t = resolveType(*group.type);
    for (auto &n : group.names)
      addFrameVar(n.name, SymKind::Var, t, owner, n.line, n.col);
  }

  // The variables exist now, so the program header's parameters can be matched
  // against them — before the statements, so a use of an unbound file is
  // reported after the reason it is unbound rather than before it.
  if (owner == program_)
    bindProgramParameters();

  // Headings first, then bodies. Declaring every heading in this block before
  // checking any body would let a procedure call one declared after it without
  // `forward`, so headings are declared one at a time, in order, and each body
  // is checked as it is reached.
  for (auto &proc : block.procs) {
    declareProcHeading(*proc, owner);
    if (proc->body)
      checkProcBody(*proc);
  }

  for (auto &proc : block.procs) {
    if (proc->sym && !proc->sym->defined)
      diags_.error(proc->line, proc->col,
                   "'" + proc->name +
                       "' was declared forward but never given a body");
  }

  // The statement path is per block: a goto in a nested procedure is not
  // inside the enclosing block's statements, whatever they are.
  std::vector<Stmt *> outerPath;
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
      sym->type = resolveType(*decl.returnType);
      // ISO 7185 §6.6.2: a function's result type is a *simple* type or a
      // pointer type. Stated the standard's way round rather than as "not
      // something that lives in memory", because a set lives in a register and
      // would pass that test while still not being a result type the language
      // allows.
      if (!sym->type->isOrdinal() && !sym->type->isReal() &&
          !sym->type->isPointer()) {
        diags_.error(decl.line, decl.col,
                     "a function cannot return " + sym->type->name() +
                         "; use a var parameter");
        sym->type = ty::Int();
      }
    }
  }

  // Parameters belong to the procedure's own frame, so they are created here
  // but only made visible once its body is entered.
  pushScope();
  buildFormals(decl.params, sym, sym);
  if (sym->kind == SymKind::Func) {
    // The result lives in the frame like a local; assigning to the function
    // name writes here, and the epilogue returns it.
    sym->resultVar =
        addHiddenVar(decl.name + "$result", SymKind::Var, sym->type, sym);
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
  for (auto &group : groups) {
    if (group.isProc) {
      // ISO 7185 §6.6.3.1 spells a procedural parameter as a heading, so it
      // declares exactly one name and the parser guarantees it is there.
      Type *t = newType(TypeKind::Proc);
      if (group.isFunction) {
        t->elem = group.returnType ? resolveType(*group.returnType) : ty::Int();
        // §6.6.2 restricts a function's result type, and a functional
        // parameter's heading is a function heading — the same rule, so the
        // same message.
        if (!t->elem->isOrdinal() && !t->elem->isReal() &&
            !t->elem->isPointer()) {
          diags_.error(group.names[0].line, group.names[0].col,
                       "a function cannot return " + t->elem->name() +
                           "; use a var parameter");
          t->elem = ty::Int();
        }
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

    Type *t = resolveType(*group.type);
    // ISO 7185 §6.6.3.3: a file may only be passed by reference. A value
    // parameter is a copy, and a file has no copy — the position, the buffer
    // and the operating system's handle are one object, not a value.
    if (t->isFile() && !group.byRef && !group.names.empty())
      diags_.error(group.names[0].line, group.names[0].col,
                   "a file parameter must be a var parameter");
    SymKind kind = group.byRef ? SymKind::VarParam : SymKind::Param;
    for (auto &n : group.names) {
      Symbol *ps =
          frame ? addFrameVar(n.name, kind, t, frame, n.line, n.col)
                : formalSymbol(newSymbol(), n, kind, t);
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
    if (f->kind == SymKind::ProcParam) {
      if (!congruous(f, a))
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
  for (Symbol *p : sym->params)
    scopes_.back()[p->name] = p;
  checkBlock(*decl.body, sym);
  popScope();

  current_ = outerProc;
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
  if (auto *v = as<VarRef>(e)) {
    if (!v->sym || v->sym->kind != SymKind::Const)
      return false;
    out = *v->sym;
    return true;
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
  return false;
}

// --------------------------------------------------------------- statements

void Sema::checkStmt(Stmt *s) {
  if (!s || as<EmptyStmt>(s))
    return;

  if (auto *c = as<Compound>(s)) {
    // A compound statement is a statement-sequence, and §6.8.1 is stated over
    // those — so it joins the path like any other statement that contains
    // one, and a goto into a `begin ... end` from outside it is refused.
    stmtPath_.push_back(c);
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
    // Assigning to a function's own name sets its result (ISO 7185 §6.8.2.2),
    // so it is redirected before the target is otherwise resolved. Reading the
    // name, by contrast, is a recursive call — see checkExpr. Only a bare name
    // can mean this; a function result has no fields to select.
    if (auto *ref = as<VarRef>(a->target.get())) {
      Symbol *named = lookup(ref->name);
      if (named && named->kind == SymKind::Func) {
        ref->sym = named->resultVar;
        ref->type = named->type;
        checkExpr(a->value.get());
        if (!named->resultVar)
          diags_.error(a->line, a->col,
                       "'" + ref->name + "' is not a function with a result");
        else if (!assignable(ref->type, a->value->type))
          diags_.error(a->line, a->col,
                       "cannot assign " + a->value->type->name() +
                           " to a result of type " + ref->type->name());
        return;
      }
    }

    checkExpr(a->target.get());
    checkExpr(a->value.get());
    if (!isDesignator(a->target.get()))
      diags_.error(a->target->line, a->target->col,
                   "the left side of an assignment must be a variable");
    // Without this the message would read "cannot assign text to a variable of
    // type text", which describes the rule accurately and explains nothing.
    else if (a->target->type && a->target->type->isFile())
      diags_.error(a->line, a->col,
                   "a file variable cannot be assigned to; use reset, rewrite "
                   "and the buffer variable");
    else if (!assignable(a->target->type, a->value->type))
      diags_.error(a->line, a->col,
                   "cannot assign " + a->value->type->name() +
                       " to a variable of type " + a->target->type->name());
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
    Symbol *sym = lookup(p->name);
    // A user-declared procedure of the same name wins, exactly as it does for
    // the required functions in checkCall.
    if (!sym && (p->name == "new" || p->name == "dispose" ||
                 p->name == "reset" || p->name == "rewrite" ||
                 p->name == "get" || p->name == "put")) {
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
    stmtPath_.push_back(i);
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
    stmtPath_.push_back(w);
    checkStmt(w->body.get());
    stmtPath_.pop_back();
    return;
  }

  if (auto *r = as<RepeatStmt>(s)) {
    stmtPath_.push_back(r);
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
    else if (f->var->sym && f->var->sym->kind != SymKind::Var)
      diags_.error(f->var->line, f->var->col,
                   "the control variable of a for statement must be a variable");
    if (f->var->type && !f->var->type->isOrdinal())
      diags_.error(f->var->line, f->var->col,
                   "the control variable of a for statement must be an "
                   "ordinal type");
    checkExpr(f->from.get());
    checkExpr(f->to.get());
    if (!assignable(f->var->type, f->from->type) ||
        !assignable(f->var->type, f->to->type))
      diags_.error(f->line, f->col,
                   "the bounds of a for statement must match the type of the "
                   "control variable");
    stmtPath_.push_back(f);
    checkStmt(f->body.get());
    stmtPath_.pop_back();
    return;
  }
}

// -------------------------------------------------------------- expressions

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
    if (s->value.empty()) {
      diags_.error(s->line, s->col, "a string literal cannot be empty");
      s->type = stringType(1);
      return;
    }
    s->type = stringType(static_cast<long long>(s->value.size()));
    return;
  }

  if (auto *idx = as<IndexExpr>(e)) {
    checkExpr(idx->base.get());
    checkExpr(idx->index.get());
    Type *base = idx->base->type;
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
    // `f^` on a file is the buffer variable (ISO 7185 §6.5.5), not a
    // dereference: one component of the file, which for a text file is the
    // character the file is positioned at. The syntax is shared, so this is
    // the one place the two meanings part.
    if (base && base->isFile()) {
      e->type = base->elem ? base->elem : ty::Char();
      return;
    }
    if (!base || !base->isPointer() || base->isNil()) {
      if (base)
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
    checkExpr(fld->base.get());
    Type *base = fld->base->type;
    if (!base || !base->isRecord()) {
      if (base)
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
    // A `with` scope is inside every enclosing one, so its fields win.
    if (Symbol *binding = lookupWithField(v->name, v->withField)) {
      v->sym = binding;
      v->type = v->withField->type;
      return;
    }
    v->sym = lookup(v->name);
    if (!v->sym) {
      diags_.error(v->line, v->col, "undeclared identifier '" + v->name + "'");
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
    if (v->sym->isInvocable() && v->sym->params.empty())
      v->type = v->sym->resultType();
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

  auto bad = [&](const char *want) {
    diags_.error(b->line, b->col, std::string("operator '") + opName(b->op) +
                                      "' needs " + want + " operands, found " +
                                      l->name() + " and " + r->name());
  };

  // ISO 7185 §6.7.2.3 gives `+`, `-` and `*` a second meaning on sets — union,
  // difference and intersection — so the set case is taken before the numeric
  // one rather than after it, where "numeric operands" would already have been
  // reported.
  if (b->op == BinOp::Add || b->op == BinOp::Sub || b->op == BinOp::Mul) {
    if (l->isSet() || r->isSet()) {
      if (!assignable(l, r) && !assignable(r, l)) {
        bad("compatible");
        b->type = l->isSet() ? l : r;
      } else {
        // The result is a set of the operands' common base type, which is
        // whichever of them has one: `s + []` is still a set of s's base.
        b->type = l->isEmptySet() ? r : l;
      }
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

  case BinOp::Add:
  case BinOp::Sub:
  case BinOp::Mul:
    if (!l->isNumeric() || !r->isNumeric()) {
      bad("numeric");
      b->type = ty::Int();
    } else {
      b->type = (l->isReal() || r->isReal()) ? ty::Real() : ty::Int();
    }
    return;

  case BinOp::RealDiv:
    if (!l->isNumeric() || !r->isNumeric())
      bad("numeric");
    b->type = ty::Real();
    return;

  case BinOp::IntDiv:
  case BinOp::Mod:
    if (!l->isInteger() || !r->isInteger())
      bad("integer");
    b->type = ty::Int();
    return;

  case BinOp::And:
  case BinOp::Or:
    if (!l->isBoolean() || !r->isBoolean())
      bad("boolean");
    b->type = ty::Bool();
    return;

  default: // relational
    // ISO 7185 §6.7.2.5 gives the string types the full set of relational
    // operators, comparing character by character; every other structured
    // type has none at all.
    if (l->isCharArray() && r->isCharArray()) {
      if (l->length() != r->length())
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
        bad("compatible");
    } else if (l->isSet() || r->isSet()) {
      // ISO 7185 §6.7.2.5: `<=` and `>=` on sets are inclusion, not order, and
      // there is no `<` or `>` at all — a proper subset is not a primitive.
      if (b->op == BinOp::Lt || b->op == BinOp::Gt)
        diags_.error(b->line, b->col,
                     std::string("sets have no '") + opName(b->op) +
                         "': use <= and >= for inclusion");
      else if (!assignable(l, r) && !assignable(r, l))
        bad("compatible");
    } else if (l->isFile() || r->isFile()) {
      // §6.7.2.5 gives a file no relational operators at all, and naming the
      // types would just repeat "text and text" back at the programmer.
      diags_.error(b->line, b->col, "file variables cannot be compared");
    } else if (l->isMemory() || r->isMemory()) {
      bad("comparable");
    } else if (!(l->isNumeric() && r->isNumeric()) &&
               !assignable(l, r) && !assignable(r, l)) {
      // Compatibility is decided the same way it is for assignment, so a
      // subrange compares with its host type and with its siblings.
      bad("compatible");
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
void Sema::checkWrite(WriteStmt *w) {
  for (auto &arg : w->args) {
    checkExpr(arg.value.get());
    if (arg.width)
      checkExpr(arg.width.get());
    if (arg.prec)
      checkExpr(arg.prec.get());
  }

  if (!w->args.empty() && !w->args[0].width && w->args[0].value->type &&
      w->args[0].value->type->isFile()) {
    if (!isDesignator(w->args[0].value.get()))
      diags_.error(w->args[0].value->line, w->args[0].value->col,
                   "the file written to must be a variable");
    w->file = std::move(w->args[0].value);
    w->args.erase(w->args.begin());
  } else {
    w->file = standardFileRef(false, w->line, w->col);
  }

  if (w->args.empty() && !w->newline)
    diags_.error(w->line, w->col, "write needs something to write");

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

  for (auto &arg : w->args) {
    Type *t = arg.value->type;
    // ISO 7185 §6.9.3 lists exactly what write accepts: an integer, a real,
    // a boolean, a char, or a packed array of char. An enumeration is not on
    // the list — the standard gives no spelling for its constants at run
    // time — and neither is any other structured type.
    bool writable = t && (t->isInteger() || t->isReal() || t->isBoolean() ||
                          t->isChar() || t->isCharArray());
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
  for (auto &a : r->args)
    checkExpr(a.get());

  if (!r->args.empty() && r->args[0]->type && r->args[0]->type->isFile()) {
    if (!isDesignator(r->args[0].get()))
      diags_.error(r->args[0]->line, r->args[0]->col,
                   "the file read from must be a variable");
    r->file = std::move(r->args[0]);
    r->args.erase(r->args.begin());
  } else {
    r->file = standardFileRef(true, r->line, r->col);
  }

  // `read` must be given somewhere to put what it reads; `readln` may be
  // written alone, and then it only finishes the line.
  if (r->args.empty() && !r->newline)
    diags_.error(r->line, r->col, "read needs a variable to read into");

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
    Type *t = a->type;
    if (!text) {
      if (!assignable(t, rf->elem))
        diags_.error(a->line, a->col,
                     "a variable of type " + (t ? t->name() : "?") +
                         " cannot be read from a " + rf->name());
      continue;
    }
    if (t && !(t->isInteger() || t->isReal() || t->isChar()))
      diags_.error(a->line, a->col,
                   "a value of type " + t->name() + " cannot be read");
  }
}

void Sema::checkStdProc(ProcCallStmt *p) {
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
  if (!isDesignator(a)) {
    diags_.error(a->line, a->col,
                 "'" + p->name + "' needs a pointer variable");
    return;
  }
  if (a->type && (!a->type->isPointer() || a->type->isNil())) {
    diags_.error(a->line, a->col,
                 "'" + p->name + "' needs a pointer variable, found " +
                     a->type->name());
    return;
  }
  if (p->args.size() == 1)
    return;

  // ISO 7185 §6.6.5.3: `new(p, c1, ..., cn)` creates a variable with the
  // variants those tag values select, one value per nested variant part,
  // outermost first. `dispose` takes the same list.
  Type *domain = a->type ? a->type->elem : nullptr;
  if (!domain || !domain->isRecord()) {
    diags_.error(p->args[1]->line, p->args[1]->col,
                 "tag values are only for a pointer to a record with a "
                 "variant part");
    return;
  }

  const std::vector<Variant> *arms = &domain->variants;
  Type *tag = domain->tagType;
  for (size_t i = 1; i < p->args.size(); ++i) {
    Expr *value = p->args[i].get();
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
      for (long long label : (*arms)[k].labels)
        if (label == v) {
          chosen = static_cast<int>(k);
          break;
        }
    if (chosen < 0) {
      diags_.error(value->line, value->col,
                   "no variant is selected by " + Type::ordinalName(tag, v));
      return;
    }
    p->variantSelection.push_back(chosen);
    tag = (*arms)[chosen].tagType;
    arms = &(*arms)[chosen].variants;
  }
}

/// ISO 7185 §6.8.3.5: the selector is an ordinal expression, every label is a
/// constant of a compatible type, and no value may appear twice. There is no
/// `else` arm, so a value matching nothing is an error at run time — which is
/// exactly the shape of an LLVM switch with a trapping default.
void Sema::checkCase(CaseStmt *c) {
  checkExpr(c->selector.get());
  Type *sel = c->selector->type;
  if (sel && !sel->isOrdinal()) {
    diags_.error(c->selector->line, c->selector->col,
                 "the selector of a case statement must be an ordinal type, "
                 "found " + sel->name());
    sel = nullptr;
  }

  std::unordered_map<long long, bool> seen;
  for (CaseArm &arm : c->arms) {
    for (ExprPtr &label : arm.labels) {
      Type *labelType = nullptr;
      long long value = 0;
      if (!evalOrdinal(label.get(), labelType, value)) {
        diags_.error(label->line, label->col,
                     "a case label must be an ordinal constant");
        continue;
      }
      if (sel && !assignable(sel, labelType)) {
        diags_.error(label->line, label->col,
                     "this case selects on " + sel->name() +
                         ", but the label is " + labelType->name());
        continue;
      }
      if (seen.count(value)) {
        diags_.error(label->line, label->col,
                     "the label " + Type::ordinalName(sel ? sel : labelType,
                                                      value) +
                         " appears twice in this case statement");
        continue;
      }
      seen[value] = true;
      arm.values.push_back(value);
    }
    stmtPath_.push_back(c);
    checkStmt(arm.body.get());
    stmtPath_.pop_back();
  }
}

/// `with r do S` makes the fields of r visible as bare names throughout S.
/// The record is designated once, so the binding holds its address and any
/// subscripts in the designator are evaluated a single time.
void Sema::checkWith(WithStmt *w) {
  checkExpr(w->record.get());
  Type *t = w->record->type;

  if (!isDesignator(w->record.get())) {
    diags_.error(w->record->line, w->record->col,
                 "'with' needs a record variable");
    stmtPath_.push_back(w);
    checkStmt(w->body.get());
    stmtPath_.pop_back();
    return;
  }
  if (!t || !t->isRecord()) {
    diags_.error(w->record->line, w->record->col,
                 "'with' needs a record variable, found " +
                     (t ? t->name() : std::string("nothing")));
    stmtPath_.push_back(w);
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

  withStack_.push_back(w->binding);
  stmtPath_.push_back(w);
  checkStmt(w->body.get());
  stmtPath_.pop_back();
  withStack_.pop_back();
}

/// Check an argument list against a callable's parameters. A `var` parameter
/// is bound to a variable, not to a value, so the argument has to be one.
void Sema::checkArguments(Symbol *callee, std::vector<ExprPtr> &args, int line,
                          int col) {
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

    if (p->kind == SymKind::VarParam) {
      if (!isDesignator(a)) {
        diags_.error(a->line, a->col,
                     "argument " + std::to_string(i + 1) + " of '" +
                         callee->name +
                         "' is a var parameter and needs a variable");
        continue;
      }
      // No implicit conversion is possible through a reference, so the types
      // must be the same rather than merely assignment-compatible.
      if (a->type && p->type && a->type != p->type)
        diags_.error(a->line, a->col,
                     "var parameter '" + p->name + "' is " + p->type->name() +
                         ", but the argument is " + a->type->name());
      continue;
    }

    // A structured value parameter is a copy, so it needs something to copy
    // from: a designator, or a string literal.
    if (p->type && p->type->isStructured() && !isDesignator(a) &&
        !is<StrLit>(a))
      diags_.error(a->line, a->col,
                   "argument " + std::to_string(i + 1) + " of '" +
                       callee->name + "' is " + p->type->name() +
                       " and needs a variable");
    else if (!assignable(p->type, a->type))
      diags_.error(a->line, a->col,
                   "argument " + std::to_string(i + 1) + " of '" +
                       callee->name + "' is " + p->type->name() +
                       ", but the value is " + a->type->name());
  }
}

/// The names ISO 7185 §6.6.5 and §6.6.6 reserve for the required procedures
/// and functions. They are not symbols — the compiler knows them by name — so
/// a program that tries to pass one gets "undeclared identifier" unless it is
/// recognised here, which would be a baffling way to report §6.6.3.7.
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

  auto *v = as<VarRef>(a);
  if (!v) {
    diags_.error(a->line, a->col,
                 where + " must be the name of a procedure or function");
    return;
  }

  Symbol *sym = lookup(v->name);
  if (!sym) {
    // ISO 7185 §6.6.3.7: the actual parameter shall not denote a required
    // procedure or function. There is nothing to pass — `write` takes a
    // variable number of arguments of types no parameter list can spell, and
    // `abs` is an instruction rather than a body with an address.
    if (isRequiredName(v->name))
      diags_.error(v->line, v->col,
                   "'" + v->name + "' is a required procedure or function and "
                   "cannot be passed as a parameter");
    else
      diags_.error(v->line, v->col, "undeclared identifier '" + v->name + "'");
    return;
  }
  if (!sym->isInvocable()) {
    diags_.error(v->line, v->col,
                 where + " must be the name of a procedure or function, but '" +
                     v->name + "' is not one");
    return;
  }
  v->sym = sym;

  // ISO 7185 §6.6.3.6. The lists are compared rather than the types, because a
  // procedural parameter has no type to write down: the heading *is* the type.
  if (!congruous(formal, sym))
    diags_.error(v->line, v->col,
                 "'" + v->name + "' does not match the parameter list of " +
                     (formal->resultType() ? "functional" : "procedural") +
                     " parameter '" + formal->name + "'");
}

void Sema::checkCall(Call *c) {
  // A user-defined function shadows nothing built in: names are resolved in
  // the scope chain first, so a local `abs` would win.
  if (Symbol *sym = lookup(c->name)) {
    if (sym->isInvocable() && sym->resultType()) {
      c->sym = sym;
      c->type = sym->resultType();
      checkArguments(sym, c->args, c->line, c->col);
      return;
    }
    if (sym->isInvocable()) {
      diags_.error(c->line, c->col,
                   "'" + c->name + "' is a procedure and returns no value");
      c->type = ty::Int();
      return;
    }
  }

  auto it = builtins().find(c->name);
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

  if (c->args.size() != 1) {
    diags_.error(c->line, c->col,
                 "'" + c->name + "' takes exactly one argument");
    c->type = ty::Int();
    return;
  }

  Type *a = c->args[0]->type;
  auto require = [&](bool ok, const char *want) {
    if (!ok)
      diags_.error(c->line, c->col, "'" + c->name + "' needs " + want +
                                        " argument, found " + a->name());
  };

  switch (c->builtin) {
  case Builtin::Abs:
  case Builtin::Sqr:
    require(a->isNumeric(), "a numeric");
    c->type = a->isReal() ? ty::Real() : ty::Int();
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
  case Builtin::Succ:
  case Builtin::Pred:
    // ISO 7185 §6.6.6.4 defines succ over any ordinal type and gives the
    // result that same type, so succ runs out at the end of *this* type —
    // at `blue` for an enumeration, at 9 for a subrange 1..9.
    require(a->isOrdinal(), "an ordinal");
    c->type = a;
    return;
  case Builtin::Trunc:
  case Builtin::Round:
    require(a->isNumeric(), "a real");
    c->type = ty::Int();
    return;
  default: // the transcendental functions
    require(a->isNumeric(), "a numeric");
    c->type = ty::Real();
    return;
  }
}

} // namespace ap
