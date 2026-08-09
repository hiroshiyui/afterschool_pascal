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

Symbol *Sema::declare(const std::string &name, SymKind kind, int line,
                      int col) {
  if (scope_.count(name)) {
    diags_.error(line, col, "'" + name + "' is already declared");
    return scope_[name];
  }
  owned_.push_back(std::make_unique<Symbol>());
  Symbol *s = owned_.back().get();
  s->name = name;
  s->kind = kind;
  scope_[name] = s;
  return s;
}

Symbol *Sema::lookup(const std::string &name) const {
  auto it = scope_.find(name);
  return it == scope_.end() ? nullptr : it->second;
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
  for (auto &c : prog.consts) {
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

  for (auto &v : prog.vars) {
    Type *t = namedType(v.typeName);
    if (!t) {
      diags_.error(v.line, v.col, "unknown type '" + v.typeName + "'");
      t = ty::Int();
    }
    Symbol *s = declare(v.name, SymKind::Var, v.line, v.col);
    if (s->type) // duplicate name: keep the first declaration
      continue;
    s->type = t;
    varOrder_.push_back(s);
  }

  checkStmt(prog.body.get());
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
    checkExpr(a->target.get());
    checkExpr(a->value.get());
    if (a->target->sym && a->target->sym->kind != SymKind::Var)
      diags_.error(a->line, a->col,
                   "cannot assign to constant '" + a->target->name + "'");
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

void Sema::checkCall(Call *c) {
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
