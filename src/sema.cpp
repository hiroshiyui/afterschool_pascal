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

Type *namedType(const std::string &name) {
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

bool Sema::assignable(Type *to, Type *from) const {
  if (!to || !from)
    return true; // an earlier error already reported
  if (to->kind == from->kind)
    return true;
  return to->isReal() && from->isInteger();
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

  for (auto &v : block.vars) {
    Type *t = namedType(v.typeName);
    if (!t) {
      diags_.error(v.line, v.col, "unknown type '" + v.typeName + "'");
      t = ty::Int();
    }
    addFrameVar(v.name, SymKind::Var, t, owner, v.line, v.col);
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
    if (!decl.params.empty() || !decl.returnTypeName.empty())
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
    if (decl.returnTypeName.empty()) {
      diags_.error(decl.line, decl.col,
                   "function '" + decl.name + "' needs a result type");
      sym->type = ty::Int();
    } else if ((sym->type = namedType(decl.returnTypeName)) == nullptr) {
      diags_.error(decl.line, decl.col,
                   "unknown result type '" + decl.returnTypeName + "'");
      sym->type = ty::Int();
    }
  }

  // Parameters belong to the procedure's own frame, so they are created here
  // but only made visible once its body is entered.
  pushScope();
  for (auto &p : decl.params) {
    Type *t = namedType(p.typeName);
    if (!t) {
      diags_.error(p.line, p.col, "unknown parameter type '" + p.typeName + "'");
      t = ty::Int();
    }
    Symbol *ps = addFrameVar(p.name, p.byRef ? SymKind::VarParam
                                             : SymKind::Param,
                             t, sym, p.line, p.col);
    sym->params.push_back(ps);
  }
  if (sym->kind == SymKind::Func) {
    // The result lives in the frame like a local; assigning to the function
    // name writes here, and the epilogue returns it.
    sym->resultVar = newSymbol();
    sym->resultVar->name = decl.name + "$result";
    sym->resultVar->kind = SymKind::Var;
    sym->resultVar->type = sym->type;
    sym->resultVar->level = sym->level;
    sym->resultVar->owner = sym;
    sym->resultVar->frameIndex = static_cast<int>(sym->frameVars.size());
    sym->frameVars.push_back(sym->resultVar);
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
    // name, by contrast, is a recursive call — see checkExpr.
    Symbol *named = lookup(a->target->name);
    if (named && named->kind == SymKind::Func) {
      a->target->sym = named->resultVar;
      a->target->type = named->type;
      checkExpr(a->value.get());
      if (!named->resultVar)
        diags_.error(a->line, a->col, "'" + a->target->name +
                                          "' is not a function with a result");
      else if (!assignable(a->target->type, a->value->type))
        diags_.error(a->line, a->col,
                     std::string("cannot assign ") + a->value->type->name() +
                         " to a result of type " + a->target->type->name());
      return;
    }

    checkExpr(a->target.get());
    checkExpr(a->value.get());
    if (a->target->sym && !a->target->sym->isVariable())
      diags_.error(a->line, a->col,
                   "cannot assign to '" + a->target->name + "'");
    else if (!assignable(a->target->type, a->value->type))
      diags_.error(a->line, a->col,
                   std::string("cannot assign ") + a->value->type->name() +
                       " to a variable of type " + a->target->type->name());
    return;
  }

  if (auto *w = as<WriteStmt>(s)) {
    for (auto &arg : w->args) {
      checkExpr(arg.value.get());
      Type *t = arg.value->type;
      if (t && t->kind == TypeKind::Void)
        diags_.error(arg.value->line, arg.value->col,
                     "this expression has no value to write");
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
    if (f->var->sym && f->var->sym->kind != SymKind::Var)
      diags_.error(f->var->line, f->var->col,
                   "the control variable of a for statement must be a variable");
    if (f->var->type && !(f->var->type->isInteger() || f->var->type->isChar()))
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
  if (as<StrLit>(e))  { e->type = ty::Str();  return; }

  if (auto *v = as<VarRef>(e)) {
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
    if (l->isString() || r->isString())
      diags_.error(b->line, b->col,
                   "string comparison is not supported yet");
    else if (!(l->isNumeric() && r->isNumeric()) && l->kind != r->kind)
      bad("compatible");
    b->type = ty::Bool();
    return;
  }
  (void)isRelational;
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
      auto *ref = as<VarRef>(a);
      if (!ref || !ref->sym || !ref->sym->isVariable()) {
        diags_.error(a->line, a->col,
                     "argument " + std::to_string(i + 1) + " of '" +
                         callee->name +
                         "' is a var parameter and needs a variable");
        continue;
      }
      // No implicit conversion is possible through a reference.
      if (ref->type && p->type && ref->type->kind != p->type->kind)
        diags_.error(a->line, a->col,
                     std::string("var parameter '") + p->name + "' is " +
                         p->type->name() + ", but the argument is " +
                         ref->type->name());
      continue;
    }

    if (!assignable(p->type, a->type))
      diags_.error(a->line, a->col,
                   std::string("argument ") + std::to_string(i + 1) + " of '" +
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
    require(a->isInteger() || a->isChar() || a->isBoolean(), "an ordinal");
    c->type = ty::Int();
    return;
  case Builtin::Chr:
    require(a->isInteger(), "an integer");
    c->type = ty::Char();
    return;
  case Builtin::Succ:
  case Builtin::Pred:
    require(a->isInteger() || a->isChar(), "an ordinal");
    c->type = a->isChar() ? ty::Char() : ty::Int();
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
