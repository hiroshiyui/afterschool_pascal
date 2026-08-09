#include "parser.h"

namespace ap {

const Token &Parser::peek(int ahead) const {
  size_t i = pos_ + static_cast<size_t>(ahead);
  return toks_[i < toks_.size() ? i : toks_.size() - 1];
}

bool Parser::accept(Tok k) {
  if (!check(k))
    return false;
  ++pos_;
  return true;
}

void Parser::errorAtCur(const std::string &msg) {
  diags_.error(cur().line, cur().col, msg);
}

void Parser::bail() { throw ParseAbort{}; }

bool Parser::expect(Tok k, const char *context) {
  if (accept(k))
    return true;
  errorAtCur(std::string("expected ") + tokenName(k) + " " + context +
             ", found " + tokenName(cur().kind));
  bail();
}

// ------------------------------------------------------------------- program

std::unique_ptr<Program> Parser::parseProgram() {
  auto prog = std::make_unique<Program>();

  expect(Tok::KwProgram, "at the start of the program");
  if (!check(Tok::Ident)) {
    errorAtCur("expected the program name");
    bail();
  }
  prog->name = cur().text;
  ++pos_;

  // The program parameter list (input, output) is accepted and ignored:
  // standard output is always available.
  if (accept(Tok::LParen)) {
    do {
      if (!check(Tok::Ident)) {
        errorAtCur("expected a program parameter name");
        bail();
      }
      ++pos_;
    } while (accept(Tok::Comma));
    expect(Tok::RParen, "after the program parameters");
  }
  expect(Tok::Semi, "after the program header");

  for (;;) {
    if (check(Tok::KwConst))
      parseConstPart(*prog);
    else if (check(Tok::KwVar))
      parseVarPart(*prog);
    else
      break;
  }

  if (check(Tok::KwType) || check(Tok::KwLabel) || check(Tok::KwProcedure) ||
      check(Tok::KwFunction)) {
    errorAtCur(std::string(tokenName(cur().kind)) +
               " declarations are not supported yet");
    bail();
  }

  prog->body = parseCompound();
  expect(Tok::Period, "after the final 'end'");
  if (!check(Tok::Eof))
    errorAtCur("trailing text after the end of the program");
  return prog;
}

void Parser::parseConstPart(Program &prog) {
  expect(Tok::KwConst, "");
  do {
    if (!check(Tok::Ident)) {
      errorAtCur("expected a constant name");
      bail();
    }
    ConstDecl d;
    d.name = cur().text;
    d.line = cur().line;
    d.col = cur().col;
    ++pos_;
    expect(Tok::Eq, "in a constant definition");
    d.value = parseExpr();
    expect(Tok::Semi, "after a constant definition");
    prog.consts.push_back(std::move(d));
  } while (check(Tok::Ident));
}

void Parser::parseVarPart(Program &prog) {
  expect(Tok::KwVar, "");
  do {
    std::vector<VarDecl> group;
    do {
      if (!check(Tok::Ident)) {
        errorAtCur("expected a variable name");
        bail();
      }
      VarDecl d;
      d.name = cur().text;
      d.line = cur().line;
      d.col = cur().col;
      ++pos_;
      group.push_back(std::move(d));
    } while (accept(Tok::Comma));

    expect(Tok::Colon, "in a variable declaration");
    if (!check(Tok::Ident)) {
      errorAtCur("expected a type name");
      bail();
    }
    std::string typeName = cur().text;
    ++pos_;
    expect(Tok::Semi, "after a variable declaration");

    for (auto &d : group) {
      d.typeName = typeName;
      prog.vars.push_back(std::move(d));
    }
  } while (check(Tok::Ident));
}

// ---------------------------------------------------------------- statements

std::unique_ptr<Compound> Parser::parseCompound() {
  auto c = makeNode<Compound>(cur());
  expect(Tok::KwBegin, "at the start of a compound statement");
  if (!check(Tok::KwEnd)) {
    for (;;) {
      c->body.push_back(parseStatement());
      if (!accept(Tok::Semi))
        break;
      if (check(Tok::KwEnd)) // trailing semicolon before 'end'
        break;
    }
  }
  expect(Tok::KwEnd, "at the end of a compound statement");
  return c;
}

StmtPtr Parser::parseStatement() {
  switch (cur().kind) {
  case Tok::KwBegin:  return parseCompound();
  case Tok::KwIf:     return parseIf();
  case Tok::KwWhile:  return parseWhile();
  case Tok::KwRepeat: return parseRepeat();
  case Tok::KwFor:    return parseFor();
  case Tok::Ident:    return parseIdentStatement();
  case Tok::KwEnd:
  case Tok::Semi:
    return makeNode<EmptyStmt>(cur());
  case Tok::KwCase:
  case Tok::KwWith:
  case Tok::KwGoto:
    errorAtCur(std::string(tokenName(cur().kind)) +
               " statements are not supported yet");
    bail();
  default:
    errorAtCur(std::string("expected a statement, found ") +
               tokenName(cur().kind));
    bail();
  }
}

StmtPtr Parser::parseIf() {
  auto s = makeNode<IfStmt>(cur());
  expect(Tok::KwIf, "");
  s->cond = parseExpr();
  expect(Tok::KwThen, "in an if statement");
  s->thenBranch = parseStatement();
  if (accept(Tok::KwElse))
    s->elseBranch = parseStatement();
  return s;
}

StmtPtr Parser::parseWhile() {
  auto s = makeNode<WhileStmt>(cur());
  expect(Tok::KwWhile, "");
  s->cond = parseExpr();
  expect(Tok::KwDo, "in a while statement");
  s->body = parseStatement();
  return s;
}

StmtPtr Parser::parseRepeat() {
  auto s = makeNode<RepeatStmt>(cur());
  expect(Tok::KwRepeat, "");
  if (!check(Tok::KwUntil)) {
    for (;;) {
      s->body.push_back(parseStatement());
      if (!accept(Tok::Semi))
        break;
      if (check(Tok::KwUntil))
        break;
    }
  }
  expect(Tok::KwUntil, "at the end of a repeat statement");
  s->cond = parseExpr();
  return s;
}

StmtPtr Parser::parseFor() {
  auto s = makeNode<ForStmt>(cur());
  expect(Tok::KwFor, "");
  if (!check(Tok::Ident)) {
    errorAtCur("expected the control variable of the for statement");
    bail();
  }
  s->var = makeNode<VarRef>(cur());
  s->var->name = cur().text;
  ++pos_;
  expect(Tok::Assign, "in a for statement");
  s->from = parseExpr();
  if (accept(Tok::KwDownto))
    s->downto = true;
  else
    expect(Tok::KwTo, "in a for statement");
  s->to = parseExpr();
  expect(Tok::KwDo, "in a for statement");
  s->body = parseStatement();
  return s;
}

StmtPtr Parser::parseIdentStatement() {
  const Token &id = cur();
  if (id.text == "write")
    return parseWrite(false);
  if (id.text == "writeln")
    return parseWrite(true);

  if (peek().kind == Tok::Assign) {
    auto s = makeNode<Assign>(id);
    s->target = makeNode<VarRef>(id);
    s->target->name = id.text;
    pos_ += 2; // identifier and ':='
    s->value = parseExpr();
    return s;
  }

  errorAtCur("unknown procedure '" + id.text + "'");
  bail();
}

StmtPtr Parser::parseWrite(bool newline) {
  auto s = makeNode<WriteStmt>(cur());
  s->newline = newline;
  ++pos_; // 'write' / 'writeln'

  if (accept(Tok::LParen)) {
    if (!check(Tok::RParen)) {
      do {
        WriteArg arg;
        arg.value = parseExpr();
        if (accept(Tok::Colon)) {
          arg.width = parseExpr();
          if (accept(Tok::Colon))
            arg.prec = parseExpr();
        }
        s->args.push_back(std::move(arg));
      } while (accept(Tok::Comma));
    }
    expect(Tok::RParen, "after the arguments of write");
  }
  return s;
}

// --------------------------------------------------------------- expressions

ExprPtr Parser::parseExpr() {
  ExprPtr lhs = parseSimpleExpr();
  BinOp op;
  switch (cur().kind) {
  case Tok::Eq:    op = BinOp::Eq; break;
  case Tok::NotEq: op = BinOp::Ne; break;
  case Tok::Lt:    op = BinOp::Lt; break;
  case Tok::Le:    op = BinOp::Le; break;
  case Tok::Gt:    op = BinOp::Gt; break;
  case Tok::Ge:    op = BinOp::Ge; break;
  default:         return lhs;
  }
  auto bin = makeNode<Binary>(cur());
  ++pos_;
  bin->op = op;
  bin->lhs = std::move(lhs);
  bin->rhs = parseSimpleExpr();
  return bin;
}

ExprPtr Parser::parseSimpleExpr() {
  ExprPtr result;
  if (check(Tok::Plus) || check(Tok::Minus)) {
    auto un = makeNode<Unary>(cur());
    un->op = check(Tok::Minus) ? UnOp::Neg : UnOp::Pos;
    ++pos_;
    un->operand = parseTerm();
    result = std::move(un);
  } else {
    result = parseTerm();
  }

  for (;;) {
    BinOp op;
    switch (cur().kind) {
    case Tok::Plus:  op = BinOp::Add; break;
    case Tok::Minus: op = BinOp::Sub; break;
    case Tok::KwOr:  op = BinOp::Or; break;
    default:         return result;
    }
    auto bin = makeNode<Binary>(cur());
    ++pos_;
    bin->op = op;
    bin->lhs = std::move(result);
    bin->rhs = parseTerm();
    result = std::move(bin);
  }
}

ExprPtr Parser::parseTerm() {
  ExprPtr result = parseFactor();
  for (;;) {
    BinOp op;
    switch (cur().kind) {
    case Tok::Star:  op = BinOp::Mul; break;
    case Tok::Slash: op = BinOp::RealDiv; break;
    case Tok::KwDiv: op = BinOp::IntDiv; break;
    case Tok::KwMod: op = BinOp::Mod; break;
    case Tok::KwAnd: op = BinOp::And; break;
    default:         return result;
    }
    auto bin = makeNode<Binary>(cur());
    ++pos_;
    bin->op = op;
    bin->lhs = std::move(result);
    bin->rhs = parseFactor();
    result = std::move(bin);
  }
}

ExprPtr Parser::parseFactor() {
  const Token &t = cur();
  switch (t.kind) {
  case Tok::IntLit: {
    auto n = makeNode<IntLit>(t);
    n->value = t.intVal;
    ++pos_;
    return n;
  }
  case Tok::RealLit: {
    auto n = makeNode<RealLit>(t);
    n->value = t.realVal;
    ++pos_;
    return n;
  }
  case Tok::StrLit: {
    // A one-character literal is a char constant in ISO Pascal.
    if (t.text.size() == 1) {
      auto n = makeNode<CharLit>(t);
      n->value = t.text[0];
      ++pos_;
      return n;
    }
    auto n = makeNode<StrLit>(t);
    n->value = t.text;
    ++pos_;
    return n;
  }
  case Tok::KwNot: {
    auto n = makeNode<Unary>(t);
    n->op = UnOp::Not;
    ++pos_;
    n->operand = parseFactor();
    return n;
  }
  case Tok::Minus: {
    auto n = makeNode<Unary>(t);
    n->op = UnOp::Neg;
    ++pos_;
    n->operand = parseFactor();
    return n;
  }
  case Tok::Plus: {
    ++pos_;
    return parseFactor();
  }
  case Tok::LParen: {
    ++pos_;
    ExprPtr e = parseExpr();
    expect(Tok::RParen, "after a parenthesised expression");
    return e;
  }
  case Tok::Ident: {
    if (peek().kind == Tok::LParen) {
      auto call = makeNode<Call>(t);
      call->name = t.text;
      pos_ += 2;
      if (!check(Tok::RParen)) {
        do {
          call->args.push_back(parseExpr());
        } while (accept(Tok::Comma));
      }
      expect(Tok::RParen, "after the arguments of a function call");
      return call;
    }
    auto ref = makeNode<VarRef>(t);
    ref->name = t.text;
    ++pos_;
    return ref;
  }
  default:
    errorAtCur(std::string("expected an expression, found ") +
               tokenName(t.kind));
    bail();
  }
}

} // namespace ap
