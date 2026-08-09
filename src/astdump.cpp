#include "astdump.h"

#include <cstdio>
#include <string>

namespace ap {
namespace {

const char *binOpName(BinOp op) {
  switch (op) {
  case BinOp::Add: return "add";
  case BinOp::Sub: return "sub";
  case BinOp::Mul: return "mul";
  case BinOp::RealDiv: return "rdiv";
  case BinOp::IntDiv: return "idiv";
  case BinOp::Mod: return "mod";
  case BinOp::And: return "and";
  case BinOp::Or: return "or";
  case BinOp::Eq: return "eq";
  case BinOp::Ne: return "ne";
  case BinOp::Lt: return "lt";
  case BinOp::Le: return "le";
  case BinOp::Gt: return "gt";
  case BinOp::Ge: return "ge";
  }
  return "?";
}

const char *unOpName(UnOp op) {
  switch (op) {
  case UnOp::Pos: return "pos";
  case UnOp::Neg: return "neg";
  case UnOp::Not: return "not";
  }
  return "?";
}

/// The format, written once here so both parsers can be held to it:
///
///   * one node per line, two spaces of indentation per level;
///   * the tag first, then whatever the parser kept of the source;
///   * ` @line:col` last, and *only* where the tree actually records a
///     position — a construct that has none must not be given an invented one,
///     or the dump would be comparing a fiction;
///   * a bare marker line (`args`, `body`, `names`) wherever a list or an
///     optional child would otherwise be ambiguous.
///
/// Every routine prints its own node at the current level and its children one
/// level deeper. Nothing here prints a type or a symbol: the dump is taken
/// before Sema, so there is nothing to print but what the parser built.
struct Dumper {
  int level = 0;

  void pad() {
    for (int i = 0; i < level; ++i)
      std::fputs("  ", stdout);
  }
  void mark(const char *tag) {
    pad();
    std::printf("%s\n", tag);
  }
  void head(const std::string &tag, int line, int col) {
    pad();
    std::printf("%s @%d:%d\n", tag.c_str(), line, col);
  }

  // ------------------------------------------------------------ expressions

  void expr(Expr *e) {
    switch (e->kind) {
    case NK::IntLit:
      head("int " + std::to_string(as<IntLit>(e)->value), e->line, e->col);
      break;
    case NK::RealLit:
      // The literal as written, not its value. Comparing converted doubles
      // would be comparing two languages' float formatting, which is the same
      // reason --dump-tokens prints the text (ADR-0022).
      head("real " + as<RealLit>(e)->text, e->line, e->col);
      break;
    case NK::CharLit:
      // As an ordinal: a char literal may be a quote, a bracket, or a byte
      // with no printable form, and a number has none of those problems.
      head("char " + std::to_string(static_cast<unsigned char>(
                         as<CharLit>(e)->value)),
           e->line, e->col);
      break;
    case NK::StrLit:
      head("str [" + as<StrLit>(e)->value + "]", e->line, e->col);
      break;
    case NK::NilLit:
      head("nil", e->line, e->col);
      break;
    case NK::VarRef:
      head("var " + as<VarRef>(e)->name, e->line, e->col);
      break;
    case NK::Index: {
      IndexExpr *n = as<IndexExpr>(e);
      head("index", e->line, e->col);
      ++level;
      expr(n->base.get());
      expr(n->index.get());
      --level;
      break;
    }
    case NK::Field: {
      FieldExpr *n = as<FieldExpr>(e);
      head("field " + n->field, e->line, e->col);
      ++level;
      expr(n->base.get());
      --level;
      break;
    }
    case NK::Deref:
      head("deref", e->line, e->col);
      ++level;
      expr(as<DerefExpr>(e)->base.get());
      --level;
      break;
    case NK::Binary: {
      Binary *n = as<Binary>(e);
      head(std::string("binary ") + binOpName(n->op), e->line, e->col);
      ++level;
      expr(n->lhs.get());
      expr(n->rhs.get());
      --level;
      break;
    }
    case NK::Unary: {
      Unary *n = as<Unary>(e);
      head(std::string("unary ") + unOpName(n->op), e->line, e->col);
      ++level;
      expr(n->operand.get());
      --level;
      break;
    }
    case NK::Call: {
      Call *n = as<Call>(e);
      head("call " + n->name, e->line, e->col);
      ++level;
      mark("args");
      ++level;
      for (ExprPtr &a : n->args)
        expr(a.get());
      level -= 2;
      break;
    }
    default:
      head("?expr", e->line, e->col);
      break;
    }
  }

  // ------------------------------------------------------------- statements

  void stmt(Stmt *s) {
    switch (s->kind) {
    case NK::Empty:
      head("empty", s->line, s->col);
      break;
    case NK::Assign: {
      Assign *n = as<Assign>(s);
      head("assign", s->line, s->col);
      ++level;
      expr(n->target.get());
      expr(n->value.get());
      --level;
      break;
    }
    case NK::Write: {
      WriteStmt *n = as<WriteStmt>(s);
      head(n->newline ? "writeln" : "write", s->line, s->col);
      ++level;
      for (WriteArg &a : n->args) {
        // The flags say which optional parts follow, so a missing width and a
        // missing precision cannot be confused for each other.
        pad();
        std::printf("arg %s %s\n", a.width ? "w" : "-", a.prec ? "p" : "-");
        ++level;
        expr(a.value.get());
        if (a.width)
          expr(a.width.get());
        if (a.prec)
          expr(a.prec.get());
        --level;
      }
      --level;
      break;
    }
    case NK::Read: {
      ReadStmt *n = as<ReadStmt>(s);
      head(n->newline ? "readln" : "read", s->line, s->col);
      ++level;
      mark("args");
      ++level;
      for (ExprPtr &a : n->args)
        expr(a.get());
      level -= 2;
      break;
    }
    case NK::Compound: {
      Compound *n = as<Compound>(s);
      head("compound", s->line, s->col);
      ++level;
      for (StmtPtr &b : n->body)
        stmt(b.get());
      --level;
      break;
    }
    case NK::If: {
      IfStmt *n = as<IfStmt>(s);
      head("if", s->line, s->col);
      ++level;
      expr(n->cond.get());
      stmt(n->thenBranch.get());
      if (n->elseBranch) {
        mark("else");
        stmt(n->elseBranch.get());
      }
      --level;
      break;
    }
    case NK::While: {
      WhileStmt *n = as<WhileStmt>(s);
      head("while", s->line, s->col);
      ++level;
      expr(n->cond.get());
      stmt(n->body.get());
      --level;
      break;
    }
    case NK::Repeat: {
      RepeatStmt *n = as<RepeatStmt>(s);
      head("repeat", s->line, s->col);
      ++level;
      mark("body");
      ++level;
      for (StmtPtr &b : n->body)
        stmt(b.get());
      --level;
      mark("until");
      ++level;
      expr(n->cond.get());
      level -= 2;
      break;
    }
    case NK::For: {
      ForStmt *n = as<ForStmt>(s);
      head(n->downto ? "for downto" : "for to", s->line, s->col);
      ++level;
      expr(n->var.get());
      expr(n->from.get());
      expr(n->to.get());
      stmt(n->body.get());
      --level;
      break;
    }
    case NK::With: {
      WithStmt *n = as<WithStmt>(s);
      head("with", s->line, s->col);
      ++level;
      expr(n->record.get());
      stmt(n->body.get());
      --level;
      break;
    }
    case NK::Case: {
      CaseStmt *n = as<CaseStmt>(s);
      head("case", s->line, s->col);
      ++level;
      expr(n->selector.get());
      for (CaseArm &arm : n->arms) {
        head("arm", arm.line, arm.col);
        ++level;
        mark("labels");
        ++level;
        for (ExprPtr &l : arm.labels)
          expr(l.get());
        --level;
        mark("body");
        ++level;
        stmt(arm.body.get());
        level -= 2;
      }
      --level;
      break;
    }
    case NK::ProcCall: {
      ProcCallStmt *n = as<ProcCallStmt>(s);
      head("proccall " + n->name, s->line, s->col);
      ++level;
      mark("args");
      ++level;
      for (ExprPtr &a : n->args)
        expr(a.get());
      level -= 2;
      break;
    }
    default:
      head("?stmt", s->line, s->col);
      break;
    }
  }

  // ---------------------------------------------------------- type denoters

  void names(const std::vector<DeclName> &list) {
    mark("names");
    ++level;
    for (const DeclName &n : list)
      head("name " + n.name, n.line, n.col);
    --level;
  }

  /// A group of names sharing one type-denoter — record fields, variables and
  /// parameters are all this shape, and they share it in the AST because they
  /// share it in the source (ISO 7185 §6.4.5).
  void group(const std::vector<DeclName> &list, TypeExpr *type,
             const char *tag) {
    mark(tag);
    ++level;
    names(list);
    mark("type");
    ++level;
    typeExpr(type);
    level -= 2;
  }

  void typeExpr(TypeExpr *t) {
    const char *pk = t->packed ? " packed" : "";
    switch (t->kind) {
    case TEK::Named:
      head("named " + t->name, t->line, t->col);
      break;
    case TEK::Pointer:
      head("pointer " + t->name, t->line, t->col);
      break;
    case TEK::Enum:
      head("enum", t->line, t->col);
      ++level;
      names(t->constants);
      --level;
      break;
    case TEK::Subrange:
      head("subrange", t->line, t->col);
      ++level;
      expr(t->lo.get());
      expr(t->hi.get());
      --level;
      break;
    case TEK::File:
      head(std::string("file") + pk, t->line, t->col);
      ++level;
      typeExpr(t->elem.get());
      --level;
      break;
    case TEK::Array:
      head(std::string("array") + pk, t->line, t->col);
      ++level;
      mark("dims");
      ++level;
      for (TypeExprPtr &d : t->dims)
        typeExpr(d.get());
      --level;
      mark("elem");
      ++level;
      typeExpr(t->elem.get());
      level -= 2;
      break;
    case TEK::Record:
      head(std::string("record") + pk, t->line, t->col);
      ++level;
      mark("fields");
      ++level;
      for (FieldGroup &f : t->fields)
        group(f.names, f.type.get(), "group");
      --level;
      if (t->tagType) {
        // An empty tag name is the `case T of` form, where the tag exists as a
        // type but not as a field (ISO 7185 §6.4.3.3); '-' says so, and no
        // field could be spelled that.
        head("tag " + (t->tagName.empty() ? std::string("-") : t->tagName),
             t->tagLine, t->tagCol);
        ++level;
        typeExpr(t->tagType.get());
        for (VariantArm &arm : t->variants) {
          head("arm", arm.line, arm.col);
          ++level;
          mark("labels");
          ++level;
          for (ExprPtr &l : arm.labels)
            expr(l.get());
          --level;
          mark("fields");
          ++level;
          for (FieldGroup &f : arm.fields)
            group(f.names, f.type.get(), "group");
          level -= 2;
        }
        --level;
      }
      --level;
      break;
    }
  }

  // ----------------------------------------------------------- declarations

  void proc(ProcDecl &d) {
    head((d.isFunction ? "func " : "proc ") + d.name, d.line, d.col);
    ++level;
    mark("params");
    ++level;
    for (ParamGroup &p : d.params)
      group(p.names, p.type.get(), p.byRef ? "group var" : "group");
    --level;
    if (d.returnType) {
      mark("result");
      ++level;
      typeExpr(d.returnType.get());
      --level;
    }
    // A forward declaration has no body, and the completion that follows it
    // repeats neither the parameters nor the result type (ISO 7185 §6.6.1).
    if (d.isForward)
      mark("forward");
    else
      block(*d.body);
    --level;
  }

  void block(Block &b) {
    mark("block");
    ++level;
    mark("consts");
    ++level;
    for (ConstDecl &c : b.consts) {
      head("const " + c.name, c.line, c.col);
      ++level;
      expr(c.value.get());
      --level;
    }
    --level;
    mark("types");
    ++level;
    for (TypeDecl &t : b.types) {
      head("type " + t.name, t.line, t.col);
      ++level;
      typeExpr(t.type.get());
      --level;
    }
    --level;
    mark("vars");
    ++level;
    for (VarDecl &v : b.vars)
      group(v.names, v.type.get(), "var");
    --level;
    mark("procs");
    ++level;
    for (std::unique_ptr<ProcDecl> &p : b.procs)
      proc(*p);
    --level;
    mark("body");
    ++level;
    stmt(b.body.get());
    level -= 2;
  }
};

} // namespace

void dumpAst(Program &program) {
  Dumper d;
  std::printf("program %s\n", program.name.c_str());
  d.level = 1;
  d.mark("params");
  d.level = 2;
  for (const DeclName &p : program.params)
    d.head("name " + p.name, p.line, p.col);
  d.level = 1;
  d.block(*program.block);
}

} // namespace ap
