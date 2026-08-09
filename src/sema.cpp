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
      {"round", Builtin::Round},
  };
  return m;
}

Type *builtinType(const std::string &name) {
  if (name == "integer") return ty::Int();
  if (name == "real")    return ty::Real();
  if (name == "boolean") return ty::Bool();
  if (name == "char")    return ty::Char();
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
                    const DeclName &name, Type *type, int variant) {
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
      addField(t, t->fields, n, fieldType, -1);
  }
  if (denoter.tagType)
    resolveVariants(denoter, t);
  return t;
}

void Sema::resolveVariants(TypeExpr &denoter, Type *record) {
  Type *tag = resolveType(*denoter.tagType);
  if (!tag->isOrdinal()) {
    diags_.error(denoter.tagLine, denoter.tagCol,
                 "the tag of a variant part must be an ordinal type, found " +
                     tag->name());
    return;
  }
  record->tagType = tag;

  // A named tag is an ordinary field of the fixed part; a tagless variant part
  // has the type but no storage for it (ISO 7185 §6.4.3.3).
  if (!denoter.tagName.empty()) {
    record->tagField = static_cast<int>(record->fields.size());
    addField(record, record->fields,
             {denoter.tagName, denoter.tagLine, denoter.tagCol}, tag, -1);
  }

  std::unordered_map<long long, int> claimed; // tag value -> variant that owns it
  for (VariantArm &arm : denoter.variants) {
    Variant v;
    v.line = arm.line;
    v.col = arm.col;
    int index = static_cast<int>(record->variants.size());

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
    record->variants.push_back(std::move(v));
    for (FieldGroup &group : arm.fields) {
      Type *fieldType = resolveType(*group.type);
      for (DeclName &n : group.names)
        addField(record, record->variants[index].fields, n, fieldType, index);
    }
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
  if (to == from)
    return true;
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

  pushScope();
  checkBlock(*prog.block, program_);
  popScope();
  popScope();
}

/// A block is the declaration part followed by the statement part, and is the
/// same shape for the program and for every procedure. The caller has already
/// pushed the scope the declarations go into.
void Sema::checkBlock(Block &block, Symbol *owner) {
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

  checkStmt(block.body.get());
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
      // ISO 7185 §6.6.2: a function returns a simple type, which is what lets
      // the result travel in a register and be read back with a plain load.
      if (sym->type->isStructured()) {
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
  for (auto &group : decl.params) {
    Type *t = resolveType(*group.type);
    for (auto &n : group.names) {
      Symbol *ps = addFrameVar(n.name,
                               group.byRef ? SymKind::VarParam : SymKind::Param,
                               t, sym, n.line, n.col);
      sym->params.push_back(ps);
    }
  }
  if (sym->kind == SymKind::Func) {
    // The result lives in the frame like a local; assigning to the function
    // name writes here, and the epilogue returns it.
    sym->resultVar =
        addHiddenVar(decl.name + "$result", SymKind::Var, sym->type, sym);
  }
  popScope();
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
    for (auto &sub : c->body)
      checkStmt(sub.get());
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
    for (auto &arg : w->args) {
      checkExpr(arg.value.get());
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
      if (arg.width) {
        checkExpr(arg.width.get());
        if (arg.width->type && !arg.width->type->isInteger())
          diags_.error(arg.width->line, arg.width->col,
                       "a field width must be an integer");
      }
      if (arg.prec) {
        checkExpr(arg.prec.get());
        if (arg.prec->type && !arg.prec->type->isInteger())
          diags_.error(arg.prec->line, arg.prec->col,
                       "a fraction length must be an integer");
        if (t && !t->isReal())
          diags_.error(arg.prec->line, arg.prec->col,
                       "only real values take a fraction length");
      }
    }
    return;
  }

  if (auto *p = as<ProcCallStmt>(s)) {
    Symbol *sym = lookup(p->name);
    // A user-declared procedure of the same name wins, exactly as it does for
    // the required functions in checkCall.
    if (!sym && (p->name == "new" || p->name == "dispose")) {
      checkStdProc(p);
      return;
    }
    if (!sym) {
      diags_.error(p->line, p->col, "unknown procedure '" + p->name + "'");
      return;
    }
    if (sym->kind != SymKind::Proc) {
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
    checkStmt(i->thenBranch.get());
    checkStmt(i->elseBranch.get());
    return;
  }

  if (auto *w = as<WhileStmt>(s)) {
    checkExpr(w->cond.get());
    if (w->cond->type && !w->cond->type->isBoolean())
      diags_.error(w->cond->line, w->cond->col,
                   "the condition of a while statement must be boolean");
    checkStmt(w->body.get());
    return;
  }

  if (auto *r = as<RepeatStmt>(s)) {
    for (auto &sub : r->body)
      checkStmt(sub.get());
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
    checkStmt(f->body.get());
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

  if (auto *d = as<DerefExpr>(e)) {
    checkExpr(d->base.get());
    Type *base = d->base->type;
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
    if (v->sym->kind == SymKind::Proc) {
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
    if (v->sym->kind == SymKind::Func && v->sym->params.empty())
      v->type = v->sym->type;
    else if (v->sym->kind == SymKind::Func)
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

  switch (b->op) {
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
    } else if (l->isStructured() || r->isStructured()) {
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
void Sema::checkStdProc(ProcCallStmt *p) {
  p->standard = p->name == "new" ? StdProc::New : StdProc::Dispose;

  for (auto &a : p->args)
    checkExpr(a.get());

  if (p->args.size() != 1) {
    // ISO 7185 §6.6.5.3 also allows `new(p, c1, ...)` to allocate only the
    // storage some variants need. Rejecting it is honest: this compiler always
    // allocates the whole record, which is safe but is not that feature.
    diags_.error(p->line, p->col,
                 "'" + p->name + "' takes exactly one argument in this "
                 "compiler; the variant-selecting form is not supported");
    return;
  }

  Expr *a = p->args[0].get();
  if (!isDesignator(a)) {
    diags_.error(a->line, a->col,
                 "'" + p->name + "' needs a pointer variable");
    return;
  }
  if (a->type && (!a->type->isPointer() || a->type->isNil()))
    diags_.error(a->line, a->col,
                 "'" + p->name + "' needs a pointer variable, found " +
                     a->type->name());
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
    checkStmt(arm.body.get());
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
    checkStmt(w->body.get());
    return;
  }
  if (!t || !t->isRecord()) {
    diags_.error(w->record->line, w->record->col,
                 "'with' needs a record variable, found " +
                     (t ? t->name() : std::string("nothing")));
    checkStmt(w->body.get());
    return;
  }

  // The binding is a frame slot holding a pointer — the same shape as a `var`
  // parameter — so a `with` inside a recursive procedure binds the record of
  // the invocation it is running in.
  w->binding = addHiddenVar("with$" + t->name(), SymKind::VarParam, t, current_);

  withStack_.push_back(w->binding);
  checkStmt(w->body.get());
  withStack_.pop_back();
}

/// Check an argument list against a callable's parameters. A `var` parameter
/// is bound to a variable, not to a value, so the argument has to be one.
void Sema::checkArguments(Symbol *callee, std::vector<ExprPtr> &args, int line,
                          int col) {
  for (auto &a : args)
    checkExpr(a.get());

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

void Sema::checkCall(Call *c) {
  // A user-defined function shadows nothing built in: names are resolved in
  // the scope chain first, so a local `abs` would win.
  if (Symbol *sym = lookup(c->name)) {
    if (sym->kind == SymKind::Func) {
      c->sym = sym;
      c->type = sym->type;
      checkArguments(sym, c->args, c->line, c->col);
      return;
    }
    if (sym->kind == SymKind::Proc) {
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
