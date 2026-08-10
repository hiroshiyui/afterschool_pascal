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

void Parser::enterLevel() {
  if (++depth_ > kMaxDepth) {
    errorAtCur("nesting is too deep: this compiler accepts " +
               std::to_string(kMaxDepth) + " levels");
    bail();
  }
}

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

  // The program parameters. `input` and `output` name the standard files;
  // any other one must be a file variable the block declares, and is bound to
  // a command-line argument (ISO 7185 §6.10 leaves the binding to the
  // implementation).
  if (accept(Tok::LParen)) {
    do {
      if (!check(Tok::Ident)) {
        errorAtCur("expected a program parameter name");
        bail();
      }
      prog->params.push_back({cur().text, cur().line, cur().col});
      ++pos_;
    } while (accept(Tok::Comma));
    expect(Tok::RParen, "after the program parameters");
  }
  expect(Tok::Semi, "after the program header");

  prog->block = parseBlock();
  expect(Tok::Period, "after the final 'end'");
  if (!check(Tok::Eof))
    errorAtCur("trailing text after the end of the program");
  return prog;
}

/// block = const-part? var-part? (procedure | function)* statement-part
///
/// The same production serves the program and every procedure, so nesting
/// needs no extra machinery here.
std::unique_ptr<Block> Parser::parseBlock() {
  auto block = std::make_unique<Block>();

  for (;;) {
    if (check(Tok::KwConst)) {
      parseConstPart(*block);
    } else if (check(Tok::KwType)) {
      parseTypePart(*block);
    } else if (check(Tok::KwVar)) {
      parseVarPart(*block);
    } else if (check(Tok::KwProcedure) || check(Tok::KwFunction)) {
      bool isFunction = check(Tok::KwFunction);
      block->procs.push_back(parseProcOrFunc(isFunction));
    } else if (check(Tok::KwLabel)) {
      errorAtCur(std::string(tokenName(cur().kind)) +
                 " declarations are not supported yet");
      bail();
    } else {
      break;
    }
  }

  block->body = parseCompound();
  return block;
}

std::unique_ptr<ProcDecl> Parser::parseProcOrFunc(bool isFunction) {
  auto decl = std::make_unique<ProcDecl>();
  decl->isFunction = isFunction;
  decl->line = cur().line;
  decl->col = cur().col;
  ++pos_; // 'procedure' / 'function'

  if (!check(Tok::Ident)) {
    errorAtCur(isFunction ? "expected the function name"
                          : "expected the procedure name");
    bail();
  }
  decl->name = cur().text;
  ++pos_;

  if (check(Tok::LParen))
    parseFormalParameters(*decl);

  // The completion of a forward declaration repeats the name alone (ISO 7185
  // §6.6.1), so both the parameters and the result type may be absent here.
  if (isFunction && accept(Tok::Colon)) {
    if (!check(Tok::Ident)) {
      errorAtCur("expected the result type of the function");
      bail();
    }
    decl->returnType = parseTypeExpr();
  }
  expect(Tok::Semi, "after the heading of a procedure or function");

  // `forward` is not a reserved word; it is an identifier in this position.
  if (check(Tok::Ident) && cur().text == "forward") {
    ++pos_;
    decl->isForward = true;
  } else {
    decl->body = parseBlock();
  }
  expect(Tok::Semi, "after the body of a procedure or function");
  return decl;
}

/// formal-parameters = '(' group (';' group)* ')'
/// group            = 'var'? ident-list ':' type-denoter
///
/// ISO 7185 §6.6.3.1 restricts a parameter's type to a type *identifier*, so
/// an array parameter needs a named type. That is a real restriction, not an
/// omission here: it is what makes a formal and an actual parameter the same
/// type rather than two structurally identical ones.
void Parser::parseFormalParameters(ProcDecl &decl) {
  expect(Tok::LParen, "");
  do {
    ParamGroup group;
    group.byRef = accept(Tok::KwVar);
    group.names = parseNameList("a parameter name");
    expect(Tok::Colon, "in a parameter list");
    if (!check(Tok::Ident)) {
      errorAtCur("a parameter's type must be a type name");
      bail();
    }
    group.type = parseTypeExpr();
    decl.params.push_back(std::move(group));
  } while (accept(Tok::Semi));
  expect(Tok::RParen, "after the parameter list");
}

std::vector<DeclName> Parser::parseNameList(const char *what) {
  std::vector<DeclName> names;
  do {
    if (!check(Tok::Ident)) {
      errorAtCur(std::string("expected ") + what);
      bail();
    }
    names.push_back({cur().text, cur().line, cur().col});
    ++pos_;
  } while (accept(Tok::Comma));
  return names;
}

// -------------------------------------------------------------- type denoters

/// A constant followed by '..' is a subrange; a bare identifier is a type
/// name. The two only diverge at the '..', so this is the one place the type
/// grammar needs to look past the current token.
bool Parser::looksLikeSubrange() const {
  size_t i = pos_;
  if (toks_[i].kind == Tok::Plus || toks_[i].kind == Tok::Minus)
    ++i;
  switch (toks_[i].kind) {
  case Tok::Ident:
  case Tok::IntLit:
  case Tok::StrLit:
    break;
  default:
    return false;
  }
  ++i;
  return i < toks_.size() && toks_[i].kind == Tok::DotDot;
}

/// type-denoter  = 'packed'? structured-type | ordinal-type | type-identifier
/// ordinal-type  = enumerated-type | subrange-type
TypeExprPtr Parser::parseTypeExpr() {
  Depth depth(*this); // array-of-array and record fields recurse through here
  bool packed = accept(Tok::KwPacked);

  if (check(Tok::KwFile)) {
    auto t = std::make_unique<TypeExpr>();
    t->kind = TEK::File;
    t->packed = packed;
    t->line = cur().line;
    t->col = cur().col;
    ++pos_;
    expect(Tok::KwOf, "after 'file'");
    t->elem = parseTypeExpr();
    return t;
  }
  // set-type = 'set' 'of' base-type. The base type is an *ordinal* type, so
  // this is the same construct as an array's index type and is parsed by the
  // same routine (ISO 7185 §6.4.3.4).
  if (check(Tok::KwSet)) {
    auto t = std::make_unique<TypeExpr>();
    t->kind = TEK::Set;
    t->packed = packed;
    t->line = cur().line;
    t->col = cur().col;
    ++pos_;
    expect(Tok::KwOf, "after 'set'");
    t->elem = parseTypeExpr();
    return t;
  }
  if (check(Tok::KwArray))
    return parseArrayType(packed);
  if (check(Tok::KwRecord))
    return parseRecordType(packed);

  if (packed) {
    errorAtCur("'packed' applies only to an array, record, set or file type");
    bail();
  }

  // pointer-type = '^' type-identifier. ISO 7185 §6.4.4 requires a type
  // *identifier* rather than a type-denoter, and that restriction is what
  // makes a recursive type possible: the name may be one defined later in the
  // same type part, so `node = record next: ^node end` closes the loop.
  if (check(Tok::Caret)) {
    auto t = std::make_unique<TypeExpr>();
    t->kind = TEK::Pointer;
    t->line = cur().line;
    t->col = cur().col;
    ++pos_;
    if (!check(Tok::Ident)) {
      errorAtCur("the domain of a pointer type must be a type name");
      bail();
    }
    t->name = cur().text;
    ++pos_;
    return t;
  }

  if (check(Tok::LParen))
    return parseEnumType();

  if (looksLikeSubrange()) {
    auto t = std::make_unique<TypeExpr>();
    t->kind = TEK::Subrange;
    t->line = cur().line;
    t->col = cur().col;
    t->lo = parseExpr();
    expect(Tok::DotDot, "between the bounds of a subrange");
    t->hi = parseExpr();
    return t;
  }

  if (!check(Tok::Ident)) {
    errorAtCur(std::string("expected a type, found ") + tokenName(cur().kind));
    bail();
  }

  auto t = std::make_unique<TypeExpr>();
  t->kind = TEK::Named;
  t->line = cur().line;
  t->col = cur().col;
  t->name = cur().text;
  ++pos_;
  return t;
}

/// enumerated-type = '(' identifier-list ')'
TypeExprPtr Parser::parseEnumType() {
  auto t = std::make_unique<TypeExpr>();
  t->kind = TEK::Enum;
  t->line = cur().line;
  t->col = cur().col;
  expect(Tok::LParen, "");
  t->constants = parseNameList("an enumeration constant");
  expect(Tok::RParen, "after the constants of an enumerated type");
  return t;
}

/// array-type = 'array' '[' ordinal-type (',' ordinal-type)* ']' 'of' type
///
/// The index is a *type*, so `array [1..3]`, `array [color]` and
/// `array [char]` are one construct. Several indices are the abbreviation of
/// ISO 7185 §6.4.3.2 — `array [a, b] of T` means `array [a] of array [b] of T`
/// — so they are kept in one node here and nested by Sema.
TypeExprPtr Parser::parseArrayType(bool packed) {
  auto t = std::make_unique<TypeExpr>();
  t->kind = TEK::Array;
  t->packed = packed;
  t->line = cur().line;
  t->col = cur().col;
  expect(Tok::KwArray, "");
  expect(Tok::LBracket, "after 'array'");

  do {
    t->dims.push_back(parseTypeExpr());
  } while (accept(Tok::Comma));

  expect(Tok::RBracket, "after the index type of an array");
  expect(Tok::KwOf, "after the index type of an array");
  t->elem = parseTypeExpr();
  return t;
}

/// record-type = 'record' field-list 'end'
/// field-list  = group (';' group)* (';' variant-part)?
/// group       = ident-list ':' type-denoter
TypeExprPtr Parser::parseRecordType(bool packed) {
  auto t = std::make_unique<TypeExpr>();
  t->kind = TEK::Record;
  t->packed = packed;
  t->line = cur().line;
  t->col = cur().col;
  expect(Tok::KwRecord, "");

  while (!check(Tok::KwEnd)) {
    if (check(Tok::KwCase)) {
      parseVariantPart(t->tagName, t->tagType, t->variants,
                       t->tagLine, t->tagCol);
      break; // the variant part is last (ISO 7185 §6.4.3.3)
    }
    FieldGroup group;
    group.names = parseNameList("a field name");
    expect(Tok::Colon, "in a record field list");
    group.type = parseTypeExpr();
    t->fields.push_back(std::move(group));
    if (!accept(Tok::Semi))
      break;
  }

  expect(Tok::KwEnd, "at the end of a record type");
  return t;
}

/// variant-part = 'case' (identifier ':')? type-identifier 'of' variant
///                (';' variant)*
/// variant      = constant (',' constant)* ':' '(' field-list ')'
///
/// The tag may be a real field or exist only as a type (§6.4.3.3). The two are
/// told apart by the ':' — `case kind: nodekind of` names a field,
/// `case nodekind of` does not.
void Parser::parseVariantPart(std::string &tagName, TypeExprPtr &tagType,
                              std::vector<VariantArm> &arms, int &tagLine,
                              int &tagCol) {
  // A variant part may contain variant parts, so this recurses without going
  // back through parseTypeExpr — which is where the depth guard usually is.
  Depth depth(*this);
  expect(Tok::KwCase, "");
  tagLine = cur().line;
  tagCol = cur().col;

  if (check(Tok::Ident) && peek().kind == Tok::Colon) {
    tagName = cur().text;
    pos_ += 2; // the name and the ':'
  }
  if (!check(Tok::Ident)) {
    errorAtCur("the tag of a variant part must be a type name");
    bail();
  }
  tagType = parseTypeExpr();
  expect(Tok::KwOf, "after the tag of a variant part");

  while (!check(Tok::KwEnd)) {
    VariantArm arm;
    arm.line = cur().line;
    arm.col = cur().col;
    do {
      arm.labels.push_back(parseExpr());
    } while (accept(Tok::Comma));

    expect(Tok::Colon, "after the labels of a variant");
    expect(Tok::LParen, "before the fields of a variant");
    while (!check(Tok::RParen)) {
      // ISO 7185 §6.4.3.3: a field-list is record-sections followed by an
      // optional variant-part, and an arm's field-list is a field-list. So the
      // variant part, when there is one, is last and closes the arm.
      if (check(Tok::KwCase)) {
        parseVariantPart(arm.tagName, arm.tagType, arm.variants, arm.tagLine,
                         arm.tagCol);
        break;
      }
      FieldGroup group;
      group.names = parseNameList("a field name");
      expect(Tok::Colon, "in the fields of a variant");
      group.type = parseTypeExpr();
      arm.fields.push_back(std::move(group));
      if (!accept(Tok::Semi))
        break;
    }
    expect(Tok::RParen, "after the fields of a variant");
    arms.push_back(std::move(arm));

    if (!accept(Tok::Semi))
      break;
  }
}

void Parser::parseConstPart(Block &prog) {
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

void Parser::parseTypePart(Block &prog) {
  expect(Tok::KwType, "");
  do {
    if (!check(Tok::Ident)) {
      errorAtCur("expected a type name");
      bail();
    }
    TypeDecl d;
    d.name = cur().text;
    d.line = cur().line;
    d.col = cur().col;
    ++pos_;
    expect(Tok::Eq, "in a type definition");
    d.type = parseTypeExpr();
    expect(Tok::Semi, "after a type definition");
    prog.types.push_back(std::move(d));
  } while (check(Tok::Ident));
}

void Parser::parseVarPart(Block &prog) {
  expect(Tok::KwVar, "");
  do {
    VarDecl group;
    group.names = parseNameList("a variable name");
    expect(Tok::Colon, "in a variable declaration");
    group.type = parseTypeExpr();
    expect(Tok::Semi, "after a variable declaration");
    prog.vars.push_back(std::move(group));
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
  // Every statement-in-statement cycle — begin/end, if, while, for, with,
  // case — passes through here, so one guard covers them all.
  Depth depth(*this);
  switch (cur().kind) {
  case Tok::KwBegin:  return parseCompound();
  case Tok::KwIf:     return parseIf();
  case Tok::KwWhile:  return parseWhile();
  case Tok::KwRepeat: return parseRepeat();
  case Tok::KwFor:    return parseFor();
  case Tok::KwWith:   return parseWith();
  case Tok::KwCase:   return parseCase();
  case Tok::Ident:    return parseIdentStatement();
  // ISO 7185 §6.8.1 makes an empty statement a statement, so every token that
  // can *follow* one also starts one: `;` and `end` between statements, `else`
  // after a then-branch, `until` after a repeat body. Leaving `else` out made
  // `if c then ; else s` — legal Pascal — a syntax error, which was found by
  // having to write around it while porting Sema (ADR-0024).
  case Tok::KwEnd:
  case Tok::Semi:
  case Tok::KwElse:
  case Tok::KwUntil:
    return makeNode<EmptyStmt>(cur());
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

/// case-statement = 'case' expression 'of' arm (';' arm)* ';'? 'end'
/// arm            = constant (',' constant)* ':' statement
///
/// ISO 7185 §6.8.3.5 has no `else` or `otherwise` arm, and none is invented
/// here: a selector matching no label is an error the program stops on.
StmtPtr Parser::parseCase() {
  auto s = makeNode<CaseStmt>(cur());
  expect(Tok::KwCase, "");
  s->selector = parseExpr();
  expect(Tok::KwOf, "after the selector of a case statement");

  while (!check(Tok::KwEnd)) {
    CaseArm arm;
    arm.line = cur().line;
    arm.col = cur().col;
    do {
      arm.labels.push_back(parseExpr());
    } while (accept(Tok::Comma));

    expect(Tok::Colon, "after the labels of a case arm");
    arm.body = parseStatement();
    s->arms.push_back(std::move(arm));

    if (!accept(Tok::Semi))
      break;
  }

  expect(Tok::KwEnd, "at the end of a case statement");
  return s;
}

/// `with a, b do S` abbreviates `with a do with b do S` (ISO 7185 §6.8.3.10),
/// so the list is nested here and every later stage sees one record at a time.
StmtPtr Parser::parseWith() {
  const Token &at = cur();
  expect(Tok::KwWith, "");

  std::vector<ExprPtr> records;
  do {
    if (!check(Tok::Ident)) {
      errorAtCur("expected a record variable after 'with'");
      bail();
    }
    auto ref = makeNode<VarRef>(cur());
    ref->name = cur().text;
    ++pos_;
    records.push_back(parseSelectors(std::move(ref)));
  } while (accept(Tok::Comma));

  expect(Tok::KwDo, "in a with statement");
  StmtPtr body = parseStatement();

  for (size_t i = records.size(); i-- > 0;) {
    auto w = makeNode<WithStmt>(at);
    w->record = std::move(records[i]);
    w->body = std::move(body);
    body = std::move(w);
  }
  return body;
}

StmtPtr Parser::parseIdentStatement() {
  const Token &id = cur();
  if (id.text == "write")
    return parseWrite(false);
  if (id.text == "writeln")
    return parseWrite(true);
  if (id.text == "read")
    return parseRead(false);
  if (id.text == "readln")
    return parseRead(true);

  // A statement starting with a designator is an assignment; one starting with
  // a bare name or a name and arguments is a procedure call. The selectors are
  // what tell the two apart, because only a designator can carry them.
  if (peek().kind == Tok::Assign || peek().kind == Tok::LBracket ||
      peek().kind == Tok::Period || peek().kind == Tok::Caret) {
    auto s = makeNode<Assign>(id);
    auto ref = makeNode<VarRef>(id);
    ref->name = id.text;
    ++pos_;
    s->target = parseSelectors(std::move(ref));
    expect(Tok::Assign, "in an assignment");
    s->value = parseExpr();
    return s;
  }

  // Anything else beginning with an identifier is a procedure call. A
  // parameterless call is just the name — Pascal has no empty argument list.
  auto s = makeNode<ProcCallStmt>(id);
  s->name = id.text;
  ++pos_;
  if (accept(Tok::LParen)) {
    if (!check(Tok::RParen)) {
      do {
        s->args.push_back(parseExpr());
      } while (accept(Tok::Comma));
    }
    expect(Tok::RParen, "after the arguments of a procedure call");
  }
  return s;
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

/// read/readln. The arguments are variables to store into, and the first may
/// be a file instead — Sema sorts that out, because telling them apart needs
/// the types. `readln` alone, with no list at all, finishes the current line.
StmtPtr Parser::parseRead(bool newline) {
  auto s = makeNode<ReadStmt>(cur());
  s->newline = newline;
  ++pos_; // 'read' / 'readln'

  if (accept(Tok::LParen)) {
    if (!check(Tok::RParen)) {
      do {
        s->args.push_back(parseExpr());
      } while (accept(Tok::Comma));
    }
    expect(Tok::RParen, "after the arguments of read");
  }
  return s;
}

// --------------------------------------------------------------- expressions

/// designator = name selector*
/// selector   = '[' expression (',' expression)* ']' | '.' field-name
ExprPtr Parser::parseSelectors(ExprPtr base) {
  // A selector chain — `a[i][j]`, `p^.next^.next` — is a spine like an
  // operator chain, built by this loop rather than by recursion; each
  // selector wraps the designator one level deeper for the tree's walkers.
  Depth depth(*this, Depth::Spine::Loop);
  for (;;) {
    if (check(Tok::LBracket)) {
      ++pos_;
      do {
        depth.bump();
        auto idx = makeNode<IndexExpr>(cur());
        idx->base = std::move(base);
        idx->index = parseExpr();
        base = std::move(idx);
      } while (accept(Tok::Comma)); // `a[i, j]` is `a[i][j]`
      expect(Tok::RBracket, "after a subscript");
      continue;
    }
    if (check(Tok::Caret)) {
      depth.bump();
      auto deref = makeNode<DerefExpr>(cur());
      ++pos_;
      deref->base = std::move(base);
      base = std::move(deref);
      continue;
    }
    if (check(Tok::Period)) {
      depth.bump();
      auto fld = makeNode<FieldExpr>(cur());
      ++pos_;
      if (!check(Tok::Ident)) {
        errorAtCur("expected a field name after '.'");
        bail();
      }
      fld->base = std::move(base);
      fld->field = cur().text;
      ++pos_;
      base = std::move(fld);
      continue;
    }
    return base;
  }
}

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
  case Tok::KwIn:  op = BinOp::In; break;
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
  // The operator loops below build a left spine: `a+b+c+...` costs the
  // parser no recursion at all, but the tree it leaves is as deep as the
  // chain is long, and Sema, CodeGen and the destructor all recurse down it.
  // Counting each iteration as a level is what makes the depth limit a bound
  // on the *tree* rather than on this parser's own stack (ADR-0020).
  Depth depth(*this, Depth::Spine::Loop);
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
    depth.bump();
    auto bin = makeNode<Binary>(cur());
    ++pos_;
    bin->op = op;
    bin->lhs = std::move(result);
    bin->rhs = parseTerm();
    result = std::move(bin);
  }
}

ExprPtr Parser::parseTerm() {
  // see parseSimpleExpr: `a*b*c*...` is a spine too
  Depth depth(*this, Depth::Spine::Loop);
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
    depth.bump();
    auto bin = makeNode<Binary>(cur());
    ++pos_;
    bin->op = op;
    bin->lhs = std::move(result);
    bin->rhs = parseFactor();
    result = std::move(bin);
  }
}

ExprPtr Parser::parseFactor() {
  // Every way an expression nests inside an expression — parentheses, `not`,
  // a unary sign, a call's arguments — passes through here exactly once per
  // level, so this one guard bounds the whole expression grammar's recursion.
  Depth depth(*this);
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
    n->text = t.text;
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
  case Tok::KwNil: {
    auto n = makeNode<NilLit>(t);
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
  // set-constructor = '[' (member (',' member)*)? ']', member = expr ('..'
  // expr)?. `[]` is the empty set. A '[' can only start a constructor here:
  // a subscript follows a designator, which parseSelectors has already
  // consumed by the time control reaches a factor.
  case Tok::LBracket: {
    auto n = makeNode<SetExpr>(t);
    ++pos_;
    if (!check(Tok::RBracket)) {
      do {
        SetMember m;
        m.lo = parseExpr();
        if (accept(Tok::DotDot))
          m.hi = parseExpr();
        n->members.push_back(std::move(m));
      } while (accept(Tok::Comma));
    }
    expect(Tok::RBracket, "after the members of a set");
    return n;
  }
  case Tok::Ident: {
    // `eof` and `eoln` are the only functions ISO 7185 lets a program call
    // with no argument list at all — the file then defaults to `input`
    // (§6.6.6.5). A bare name is otherwise a variable or a parameterless call,
    // so this is decided here, where the absence of '(' is visible.
    if ((t.text == "eof" || t.text == "eoln") && peek().kind != Tok::LParen) {
      auto call = makeNode<Call>(t);
      call->name = t.text;
      ++pos_;
      return call;
    }
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
    // Only a variable takes selectors: a function result is a simple type in
    // ISO 7185 §6.6.2, so `f(x)[i]` cannot arise.
    return parseSelectors(std::move(ref));
  }
  default:
    errorAtCur(std::string("expected an expression, found ") +
               tokenName(t.kind));
    bail();
  }
}

} // namespace ap
