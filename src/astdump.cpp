// The tree dumps behind --dump-ast and --dump-sema.
//
// This file is a *specification*, not a debugging aid: `selfhost/compiler.pas`
// writes the same three sections, and `selfhost/difftest.sh` diffs the two
// over every Pascal source in the tree. Change the format here and the Pascal
// side changes in the same commit, or the differential test goes red — which
// is the point of it (ADR-0022, ADR-0024).
//
// One walk serves both flags. `--dump-ast` runs before Sema and shows only
// what the parser decided; `--dump-sema` walks the same tree with `annotate`
// set, adding types, resolutions and layouts. Sharing the walker is deliberate:
// the shape is then the same question asked twice.

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
  case BinOp::In: return "in";
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

const char *symKindName(SymKind k) {
  switch (k) {
  case SymKind::Const:    return "const";
  case SymKind::Type:     return "type";
  case SymKind::Var:      return "var";
  case SymKind::Param:    return "param";
  case SymKind::VarParam: return "varparam";
  case SymKind::Proc:     return "proc";
  case SymKind::Func:     return "func";
  }
  return "?";
}

const char *bindingName(FileBinding b) {
  switch (b) {
  case FileBinding::Internal:       return "internal";
  case FileBinding::StandardInput:  return "stdin";
  case FileBinding::StandardOutput: return "stdout";
  case FileBinding::Argument:       return "arg";
  }
  return "?";
}

/// What a name resolved to. A variable is named by the frame that holds it and
/// its slot in it, because that pair is what codegen actually uses — printing
/// the spelling again would compare nothing Sema decided.
///
/// A constant prints its value, which is how constant folding is compared: a
/// real one prints only its type, for the reason ADR-0022 gives about
/// comparing two languages' float formatting.
std::string symRef(const Symbol *s) {
  if (!s)
    return "?";
  switch (s->kind) {
  case SymKind::Const:
    if (!s->type)
      return "const ?";
    if (s->type->isReal())
      return "const real";
    if (s->type->isChar())
      return "const " + std::to_string(static_cast<unsigned char>(s->charVal));
    if (s->type->base()->kind == TypeKind::Boolean)
      return std::string("const ") + (s->boolVal ? "true" : "false");
    return "const " + std::to_string(s->intVal);
  case SymKind::Type:
    return "type";
  case SymKind::Proc:
  case SymKind::Func:
    return std::string(symKindName(s->kind)) + " " + s->name;
  default:
    return (s->owner ? s->owner->name : std::string("?")) + "/" +
           std::to_string(s->frameIndex);
  }
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
/// Where a field lives: `-` is the record's fixed part, `0` is arm 0 of its
/// variant part, `0.1` is arm 1 of the variant part inside arm 0.
static std::string variantRef(const std::vector<int> &path) {
  if (path.empty())
    return "-";
  std::string s;
  for (size_t i = 0; i < path.size(); ++i) {
    if (i)
      s += ".";
    s += std::to_string(path[i]);
  }
  return s;
}

struct Dumper {
  int level = 0;
  /// False for `--dump-ast`, true for `--dump-sema`. The walk is identical
  /// either way; only the annotations appear.
  bool annotate = false;

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
  /// A child that Sema may or may not have supplied — the file of a read or a
  /// write. The marker says which, so "absent" and "present" cannot be
  /// confused for one another.
  void optionalChild(const char *tag, Expr *e) {
    if (!e) {
      pad();
      std::printf("no-%s\n", tag);
      return;
    }
    mark(tag);
    ++level;
    expr(e);
    --level;
  }
  /// An expression, which after Sema carries a type and possibly a resolution.
  void headExpr(const std::string &tag, Expr *e, const std::string &to = "") {
    pad();
    std::printf("%s @%d:%d", tag.c_str(), e->line, e->col);
    if (annotate) {
      if (!to.empty())
        std::printf(" -> %s", to.c_str());
      std::printf(" : %s", e->type ? e->type->name().c_str() : "?");
    }
    std::printf("\n");
  }
  /// A type-denoter, which after Sema names the type it produced.
  void headType(const std::string &tag, TypeExpr *t) {
    pad();
    std::printf("%s @%d:%d", tag.c_str(), t->line, t->col);
    if (annotate)
      std::printf(" = %s", t->resolved ? t->resolved->name().c_str() : "?");
    std::printf("\n");
  }

  // ------------------------------------------------------------ expressions

  void expr(Expr *e) {
    switch (e->kind) {
    case NK::IntLit:
      headExpr("int " + std::to_string(as<IntLit>(e)->value), e);
      break;
    case NK::RealLit:
      // The literal as written, not its value. Comparing converted doubles
      // would be comparing two languages' float formatting, which is the same
      // reason --dump-tokens prints the text (ADR-0022).
      headExpr("real " + as<RealLit>(e)->text, e);
      break;
    case NK::CharLit:
      // As an ordinal: a char literal may be a quote, a bracket, or a byte
      // with no printable form, and a number has none of those problems.
      headExpr("char " + std::to_string(static_cast<unsigned char>(
                             as<CharLit>(e)->value)),
               e);
      break;
    case NK::StrLit:
      headExpr("str [" + as<StrLit>(e)->value + "]", e);
      break;
    case NK::NilLit:
      headExpr("nil", e);
      break;
    case NK::SetLit: {
      SetExpr *n = as<SetExpr>(e);
      headExpr("set", e);
      ++level;
      // A member with a second child is a range and a member with one is a
      // single value, so the two tags are what keeps `[a, b]` and `[a..b]`
      // from dumping identically.
      for (SetMember &m : n->members) {
        mark(m.hi ? "range" : "member");
        ++level;
        expr(m.lo.get());
        if (m.hi)
          expr(m.hi.get());
        --level;
      }
      --level;
      break;
    }
    case NK::VarRef: {
      VarRef *n = as<VarRef>(e);
      // A name reached through an open `with` resolves to the hidden binding
      // *plus* the field it selects, so both halves are printed.
      std::string to = symRef(n->sym);
      if (n->withField)
        to += " field #" + std::to_string(n->withField->index) + "/" +
              variantRef(n->withField->variant);
      headExpr("var " + n->name, e, to);
      break;
    }
    case NK::Index: {
      IndexExpr *n = as<IndexExpr>(e);
      headExpr("index", e);
      ++level;
      expr(n->base.get());
      expr(n->index.get());
      --level;
      break;
    }
    case NK::Field: {
      FieldExpr *n = as<FieldExpr>(e);
      headExpr("field " + n->field, e,
               n->resolved ? "#" + std::to_string(n->resolved->index) + "/" +
                                 variantRef(n->resolved->variant)
                           : "?");
      ++level;
      expr(n->base.get());
      --level;
      break;
    }
    case NK::Deref:
      headExpr("deref", e);
      ++level;
      expr(as<DerefExpr>(e)->base.get());
      --level;
      break;
    case NK::Binary: {
      Binary *n = as<Binary>(e);
      headExpr(std::string("binary ") + binOpName(n->op), e);
      ++level;
      expr(n->lhs.get());
      expr(n->rhs.get());
      --level;
      break;
    }
    case NK::Unary: {
      Unary *n = as<Unary>(e);
      headExpr(std::string("unary ") + unOpName(n->op), e);
      ++level;
      expr(n->operand.get());
      --level;
      break;
    }
    case NK::Call: {
      Call *n = as<Call>(e);
      // Sema decides whether a call is a required function or a user one; the
      // two are told apart here because nothing else in the tree says which.
      std::string to = n->builtin != Builtin::None
                           ? "builtin " + std::to_string(
                                              static_cast<int>(n->builtin))
                           : symRef(n->sym);
      headExpr("call " + n->name, e, to);
      ++level;
      mark("args");
      ++level;
      for (ExprPtr &a : n->args)
        expr(a.get());
      level -= 2;
      break;
    }
    default:
      headExpr("?expr", e);
      break;
    }
  }

  // ------------------------------------------------------------- statements

  void stmt(Stmt *s) {
    switch (s->kind) {
    case NK::Empty:
      head("empty", s->line, s->col);
      break;
    // A goto prints the id Sema resolved it to as well as the number: the
    // number alone does not say which label, since two blocks may each
    // declare label 1.
    case NK::Goto: {
      GotoStmt *n = as<GotoStmt>(s);
      pad();
      std::printf("goto %d @%d:%d", n->label, n->line, n->col);
      if (annotate)
        std::printf(" -> #%d", n->id);
      std::printf("\n");
      break;
    }
    case NK::Labeled: {
      LabeledStmt *n = as<LabeledStmt>(s);
      pad();
      std::printf("label %d @%d:%d", n->label, n->line, n->col);
      if (annotate)
        std::printf(" -> #%d", n->id);
      std::printf("\n");
      ++level;
      stmt(n->body.get());
      --level;
      break;
    }
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
      // Sema moves a leading file argument out of the list and supplies
      // `output` when there was none, so after it the tree has a shape the
      // parser never built. That change is the thing worth comparing.
      if (annotate)
        optionalChild("file", n->file.get());
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
      if (annotate)
        optionalChild("file", n->file.get());
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
        // The folded label values: this is where constant folding of an
        // ordinal is compared, and a label the checker rejected leaves a gap.
        if (annotate) {
          pad();
          std::printf("values");
          for (long long v : arm.values)
            std::printf(" %lld", v);
          std::printf("\n");
        }
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
      std::string tag = "proccall " + n->name;
      if (annotate) {
        tag += n->standard != StdProc::None
                   ? " -> standard " +
                         std::to_string(static_cast<int>(n->standard))
                   : " -> " + symRef(n->sym);
        // The arms `new(p, c1, ...)` selects, which is what Sema folded the
        // tag values down to and what decides how much is allocated.
        if (!n->variantSelection.empty())
          tag += " variants " + variantRef(n->variantSelection);
      }
      head(tag, s->line, s->col);
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

  /// The layout Sema gave a record: which struct each field lives in and at
  /// what position, and which tag values select each variant. Codegen indexes
  /// by exactly these numbers, so they are what a record type *is*.
  void fieldList(const std::vector<Field> &fs) {
    for (const Field &f : fs) {
      pad();
      std::printf("field %s #%d/%s : %s\n", f.name.c_str(), f.index,
                  variantRef(f.variant).c_str(),
                  f.type ? f.type->name().c_str() : "?");
    }
  }

  /// One level of arms and everything nested in them. The name of an arm is
  /// its path, which is also what a field of it prints as its variant.
  void armList(const std::vector<Variant> &arms, const std::string &prefix) {
    for (size_t i = 0; i < arms.size(); ++i) {
      const Variant &v = arms[i];
      std::string here = prefix + std::to_string(i);
      pad();
      std::printf("variant %s labels", here.c_str());
      for (long long value : v.labels)
        std::printf(" %lld", value);
      std::printf("\n");
      ++level;
      fieldList(v.fields);
      if (v.tagField >= 0) {
        pad();
        std::printf("tagfield #%d\n", v.tagField);
      }
      armList(v.variants, here + ".");
      --level;
    }
  }

  void recordLayout(Type *r) {
    mark("layout");
    ++level;
    fieldList(r->fields);
    if (r->tagField >= 0) {
      pad();
      std::printf("tagfield #%d\n", r->tagField);
    }
    armList(r->variants, "");
    --level;
  }

  /// A variant part as the parser built it: the tag, and one `arm` per
  /// variant. An arm's field-list is a field-list like any other, so it may
  /// end with a variant part of its own and this recurses into it.
  void variantPart(const std::string &tagName, TypeExpr *tagType,
                   std::vector<VariantArm> &arms, int tagLine, int tagCol) {
    // An empty tag name is the `case T of` form, where the tag exists as a
    // type but not as a field (ISO 7185 §6.4.3.3); '-' says so, and no field
    // could be spelled that.
    head("tag " + (tagName.empty() ? std::string("-") : tagName), tagLine,
         tagCol);
    ++level;
    typeExpr(tagType);
    for (VariantArm &arm : arms) {
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
      --level;
      if (arm.tagType)
        variantPart(arm.tagName, arm.tagType.get(), arm.variants, arm.tagLine,
                    arm.tagCol);
      --level;
    }
    --level;
  }

  void typeExpr(TypeExpr *t) {
    const char *pk = t->packed ? " packed" : "";
    switch (t->kind) {
    case TEK::Named:
      headType("named " + t->name, t);
      break;
    case TEK::Pointer:
      headType("pointer " + t->name, t);
      break;
    case TEK::Enum:
      headType("enum", t);
      ++level;
      names(t->constants);
      --level;
      break;
    case TEK::Subrange:
      headType("subrange", t);
      ++level;
      expr(t->lo.get());
      expr(t->hi.get());
      --level;
      break;
    case TEK::File:
      headType(std::string("file") + pk, t);
      ++level;
      typeExpr(t->elem.get());
      --level;
      break;
    case TEK::Set:
      headType(std::string("set") + pk, t);
      ++level;
      typeExpr(t->elem.get());
      --level;
      break;
    case TEK::Array:
      headType(std::string("array") + pk, t);
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
      headType(std::string("record") + pk, t);
      ++level;
      if (annotate && t->resolved && t->resolved->isRecord())
        recordLayout(t->resolved);
      mark("fields");
      ++level;
      for (FieldGroup &f : t->fields)
        group(f.names, f.type.get(), "group");
      --level;
      if (t->tagType)
        variantPart(t->tagName, t->tagType.get(), t->variants, t->tagLine,
                    t->tagCol);
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

  /// One activation record: what ADR-0016 says codegen lays out, in the order
  /// it lays it out. The slot numbers are the whole point — a name resolving
  /// to the right symbol but the wrong slot is a bug this catches.
  void frame(Symbol *s) {
    pad();
    if (!s) {
      std::printf("frame ?\n");
      return;
    }
    std::printf("frame %s level %d\n", s->name.c_str(), s->level);
    ++level;
    for (Symbol *v : s->frameVars) {
      pad();
      std::printf("%s %s #%d : %s", symKindName(v->kind), v->name.c_str(),
                  v->frameIndex, v->type ? v->type->name().c_str() : "?");
      // How a file reaches the world outside the program (ISO 7185 §6.10).
      if (v->type && v->type->isFile())
        std::printf(" (%s %d)", bindingName(v->fileBinding), v->fileArg);
      std::printf("\n");
    }
    --level;
  }

  void frames(Block &b) {
    for (std::unique_ptr<ProcDecl> &p : b.procs) {
      frame(p->sym);
      if (p->body)
        frames(*p->body);
    }
  }

  void block(Block &b) {
    mark("block");
    ++level;
    mark("labels");
    ++level;
    for (LabelDecl &d : b.labels)
      head("label " + std::to_string(d.number), d.line, d.col);
    --level;
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

void dumpSema(Program &program, Sema &sema) {
  Dumper d;
  d.annotate = true;
  std::printf("program %s\n", program.name.c_str());
  d.level = 1;
  d.mark("params");
  d.level = 2;
  for (const DeclName &p : program.params)
    d.head("name " + p.name, p.line, p.col);
  d.level = 1;
  d.mark("frames");
  d.level = 2;
  // The program's own frame first: at level 0 it holds what another language
  // would call the globals, which is ADR-0016's point.
  d.frame(sema.programSymbol());
  d.frames(*program.block);
  d.level = 1;
  d.block(*program.block);
}

} // namespace ap
