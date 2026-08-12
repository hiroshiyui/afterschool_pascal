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

/// ISO/IEC 10206:1991 §6.13: `program-block = program-component
/// { program-component }`, each terminated by `.`, exactly one of which is the
/// main-program-declaration. Under ISO 7185 `module` is not a word-symbol, so
/// this loop runs once and the whole production is the one that was here
/// before.
std::unique_ptr<Program> Parser::parseProgram() {
  auto prog = std::make_unique<Program>();
  bool sawMain = false;

  for (;;) {
    if (check(Tok::KwModule)) {
      prog->modules.push_back(parseModule());
      continue;
    }
    if (check(Tok::KwProgram)) {
      if (sawMain) {
        errorAtCur("a program has one 'program' declaration, and this is the "
                   "second");
        bail();
      }
      prog->mainIndex = prog->modules.size();
      parseMainProgram(*prog);
      sawMain = true;
      continue;
    }
    break;
  }

  if (!sawMain) {
    // The whole source was modules, or began with neither word. Either way the
    // message that was here before is the right one: something has to start a
    // program-component, and `program` is the only word that starts the one
    // every program must have.
    expect(Tok::KwProgram, "at the start of the program");
    bail();
  }
  if (!check(Tok::Eof))
    errorAtCur("trailing text after the end of the program");
  return prog;
}

/// §6.11.1's module-declaration. Which of its three forms this is comes down
/// to the word after the module's name: `interface` gives a heading with no
/// block, `implementation` gives a block with no heading, and neither gives
/// both in one component. Both words are *directives* (§6.1.5, §6.1.6) and so
/// ordinary identifiers here, exactly as `forward` is — which is why modules
/// reserve five words and not seven.
std::unique_ptr<ModuleDecl> Parser::parseModule() {
  auto m = std::make_unique<ModuleDecl>();
  m->line = cur().line;
  m->col = cur().col;
  ++pos_; // 'module'

  if (!check(Tok::Ident)) {
    errorAtCur("expected the module name");
    bail();
  }
  m->name = cur().text;
  ++pos_;

  bool implementation = false;
  if (check(Tok::Ident) && cur().text == "interface") {
    ++pos_;
    m->hasHeading = true;
  } else if (check(Tok::Ident) && cur().text == "implementation") {
    ++pos_;
    implementation = true;
    m->hasBlock = true;
  } else {
    m->hasHeading = true;
    m->hasBlock = true;
  }

  if (implementation) {
    // module-identification: the heading was given by an earlier component, so
    // there is no parameter list and no export part to write again.
    expect(Tok::Semi, "after 'implementation'");
    parseModuleBlock(*m);
    expect(Tok::Period, "after the 'end' of a module block");
    return m;
  }

  parseModuleHeading(*m);
  if (m->hasBlock) {
    expect(Tok::Semi, "after the 'end' of a module heading");
    parseModuleBlock(*m);
  }
  expect(Tok::Period, m->hasBlock ? "after the 'end' of a module block"
                                  : "after the 'end' of a module heading");
  return m;
}

/// module-heading = 'module' identifier [interface-directive]
///                  [ '(' module-parameter-list ')' ] ';'
///                  interface-specification-part import-part
///                  { const | type | var | procedure-and-function-heading } 'end'
///
/// The name and the directive have already been read.
void Parser::parseModuleHeading(ModuleDecl &m) {
  if (accept(Tok::LParen)) {
    m.params = parseNameList("a module parameter name");
    expect(Tok::RParen, "after the module parameters");
  }
  expect(Tok::Semi, "after the module heading");

  m.heading = std::make_unique<Block>();
  while (check(Tok::KwExport))
    parseExportPart(m);
  parseImportPart(m.heading->imports);

  for (;;) {
    if (check(Tok::KwConst)) {
      parseConstPart(*m.heading);
    } else if (check(Tok::KwType)) {
      parseTypePart(*m.heading);
    } else if (check(Tok::KwVar)) {
      parseVarPart(*m.heading);
    } else if (check(Tok::KwProcedure) || check(Tok::KwFunction)) {
      // procedure-and-function-heading-part: a heading and a semicolon, with
      // no body and no `forward` — the body belongs to the module-block.
      bool isFunction = check(Tok::KwFunction);
      auto decl = parseProcHeadingOnly(isFunction);
      m.heading->procs.push_back(std::move(decl));
    } else {
      break;
    }
  }
  expect(Tok::KwEnd, "at the end of a module heading");
}

/// module-block = import-part { const | type | var | procedure-and-function }
///                [ initialization-part ] [ finalization-part ] 'end'
///
/// It has no statement-part: §6.11.1 gives a module its two `to begin do` and
/// `to end do` parts instead, and each takes a single *statement*.
void Parser::parseModuleBlock(ModuleDecl &m) {
  m.block = std::make_unique<Block>();
  parseImportPart(m.block->imports);

  for (;;) {
    if (check(Tok::KwConst)) {
      parseConstPart(*m.block);
    } else if (check(Tok::KwType)) {
      parseTypePart(*m.block);
    } else if (check(Tok::KwVar)) {
      parseVarPart(*m.block);
    } else if (check(Tok::KwProcedure) || check(Tok::KwFunction)) {
      bool isFunction = check(Tok::KwFunction);
      m.block->procs.push_back(parseProcOrFunc(isFunction));
    } else {
      break;
    }
  }

  // `to begin do S;` and `to end do S;`, in that order and each at most once.
  if (check(Tok::KwTo) && check(Tok::KwBegin, 1)) {
    pos_ += 2;
    expect(Tok::KwDo, "after 'to begin'");
    m.init = parseStatement();
    expect(Tok::Semi, "after the initialization part of a module");
  }
  if (check(Tok::KwTo) && check(Tok::KwEnd, 1)) {
    pos_ += 2;
    expect(Tok::KwDo, "after 'to end'");
    m.fini = parseStatement();
    expect(Tok::Semi, "after the finalization part of a module");
  }
  if (check(Tok::KwTo)) {
    errorAtCur("a module has one 'to begin do' part and one 'to end do' part, "
               "in that order");
    bail();
  }
  expect(Tok::KwEnd, "at the end of a module block");
}

/// export-part = identifier '=' '(' export-list ')'
///
/// An export-clause names something the module declares; an export-range names
/// two constants of one enumerated type and stands for every principal
/// identifier between them (§6.11.2 NOTE 6). Which of the two an item is comes
/// down to whether `..` follows the first name.
void Parser::parseExportPart(ModuleDecl &m) {
  expect(Tok::KwExport, "");
  do {
    ExportPart part;
    part.line = cur().line;
    part.col = cur().col;
    if (!check(Tok::Ident)) {
      errorAtCur("expected the name of an interface after 'export'");
      bail();
    }
    part.name = cur().text;
    ++pos_;
    expect(Tok::Eq, "after the name of an interface");
    expect(Tok::LParen, "before an export list");
    do {
      ExportItem item;
      item.line = cur().line;
      item.col = cur().col;
      // §6.11.2: `protected` may precede a variable-name, and only a
      // variable-name — it is what makes the importer unable to write to it.
      item.isProtected = accept(Tok::KwProtected);
      if (!check(Tok::Ident)) {
        errorAtCur("expected a name in an export list");
        bail();
      }
      item.name = cur().text;
      ++pos_;
      // A qualified exportable-name. `..` cannot follow an interface name, so
      // one token of lookahead past the dot is what parts `i.x` from `lo..hi`.
      if (check(Tok::Period) && check(Tok::Ident, 1)) {
        item.qualifier = item.name;
        ++pos_;
        item.name = cur().text;
        ++pos_;
      }
      if (accept(Tok::DotDot)) {
        if (!check(Tok::Ident)) {
          errorAtCur("expected the last constant of an export range");
          bail();
        }
        item.last = cur().text;
        ++pos_;
        if (check(Tok::Period) && check(Tok::Ident, 1)) {
          item.lastQualifier = item.last;
          ++pos_;
          item.last = cur().text;
          ++pos_;
        }
      } else if (accept(Tok::Arrow)) {
        if (!check(Tok::Ident)) {
          errorAtCur("expected the new name after '=>'");
          bail();
        }
        item.renamed = cur().text;
        ++pos_;
      }
      part.items.push_back(std::move(item));
    } while (accept(Tok::Comma));
    expect(Tok::RParen, "after an export list");
    m.exports.push_back(std::move(part));
    expect(Tok::Semi, "after an export part");
  } while (check(Tok::Ident) && !check(Tok::KwEnd));
}

/// import-part = [ 'import' import-specification ';'
///                 { import-specification ';' } ]
///
/// §6.2.1 puts this at the head of every block. The word `import` is written
/// once and the specifications that follow it are separated by semicolons, so
/// the loop's exit is a token that cannot begin an interface name.
void Parser::parseImportPart(std::vector<ImportSpec> &into) {
  if (!accept(Tok::KwImport))
    return;
  do {
    ImportSpec spec;
    spec.line = cur().line;
    spec.col = cur().col;
    if (!check(Tok::Ident)) {
      errorAtCur("expected the name of an interface after 'import'");
      bail();
    }
    spec.interfaceName = cur().text;
    ++pos_;
    spec.qualified = accept(Tok::KwQualified);
    spec.only = accept(Tok::KwOnly);
    if (check(Tok::LParen)) {
      ++pos_;
      spec.hasList = true;
      do {
        ImportItem item;
        item.line = cur().line;
        item.col = cur().col;
        if (!check(Tok::Ident)) {
          errorAtCur("expected a name in an import list");
          bail();
        }
        item.name = cur().text;
        ++pos_;
        if (accept(Tok::Arrow)) {
          if (!check(Tok::Ident)) {
            errorAtCur("expected the new name after '=>'");
            bail();
          }
          item.renamed = cur().text;
          ++pos_;
        }
        spec.items.push_back(std::move(item));
      } while (accept(Tok::Comma));
      expect(Tok::RParen, "after an import list");
    } else if (spec.only) {
      errorAtCur("'only' introduces the list of what to import, so a list "
                 "must follow it");
      bail();
    }
    into.push_back(std::move(spec));
    expect(Tok::Semi, "after an import specification");
  } while (check(Tok::Ident));
}

void Parser::parseMainProgram(Program &prog) {
  expect(Tok::KwProgram, "at the start of the program");
  if (!check(Tok::Ident)) {
    errorAtCur("expected the program name");
    bail();
  }
  prog.name = cur().text;
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
      prog.params.push_back({cur().text, cur().line, cur().col});
      ++pos_;
    } while (accept(Tok::Comma));
    expect(Tok::RParen, "after the program parameters");
  }
  expect(Tok::Semi, "after the program header");

  prog.block = parseBlock();
  expect(Tok::Period, "after the final 'end'");
}

/// block = const-part? var-part? (procedure | function)* statement-part
///
/// The same production serves the program and every procedure, so nesting
/// needs no extra machinery here.
std::unique_ptr<Block> Parser::parseBlock() {
  auto block = std::make_unique<Block>();

  // §6.2.1 puts the import-part first, and there is at most one. Under ISO
  // 7185 `import` is an ordinary identifier and this returns at once.
  parseImportPart(block->imports);

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
      parseLabelPart(*block);
    } else {
      break;
    }
  }

  block->body = parseCompound();
  return block;
}

/// ISO 7185 §6.1.6: a label is an unsigned integer of at most four digits, so
/// `0001` and `1` are the same label and `10000` is not one at all. The value
/// is what identifies it — there is no name here to intern.
int Parser::parseLabel(const char *where) {
  if (!check(Tok::IntLit)) {
    errorAtCur(std::string("expected a label ") + where + ", found " +
               tokenName(cur().kind));
    bail();
  }
  long long v = cur().intVal;
  if (v < 0 || v > 9999) {
    errorAtCur("a label must be an unsigned integer of at most four digits");
    v = 0;
  }
  ++pos_;
  return static_cast<int>(v);
}

/// label-declaration-part = 'label' label (',' label)* ';'
void Parser::parseLabelPart(Block &block) {
  expect(Tok::KwLabel, "");
  do {
    LabelDecl d;
    d.line = cur().line;
    d.col = cur().col;
    d.number = parseLabel("in a label declaration");
    block.labels.push_back(d);
  } while (accept(Tok::Comma));
  expect(Tok::Semi, "after a label declaration");
}

/// A procedure- or function-*heading* in a module-heading (ISO/IEC 10206:1991
/// §6.11.1). It is a heading and a semicolon: no body, and no `forward` to
/// say so, because a module-heading is the one place where declaring without
/// defining is the whole point rather than a way to break a cycle.
std::unique_ptr<ProcDecl> Parser::parseProcHeadingOnly(bool isFunction) {
  auto decl = parseProcHeading(isFunction);
  decl->inModuleHeading = true;
  return decl;
}

std::unique_ptr<ProcDecl> Parser::parseProcOrFunc(bool isFunction) {
  auto decl = parseProcHeading(isFunction);

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

/// The heading alone, up to and including the semicolon that ends it. Shared
/// by a declaration, a `forward` one, and a module-heading's heading part.
std::unique_ptr<ProcDecl> Parser::parseProcHeading(bool isFunction) {
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
    parseFormalParameters(decl->params);

  // ISO/IEC 10206:1991 §6.7.2's result-variable-specification: `= identifier`
  // between the parameters and the result type gives the result a *name*.
  // Without one the only way to write the result is `f := e`, and §6.8.2.2
  // makes every *read* of `f` a recursive call — so a structured result could
  // be assigned whole and never built a field at a time. This is the
  // standard's own answer to that, which is why the two halves of §6.7.2
  // arrive together.
  if (isFunction && std_ == Std::Extended && accept(Tok::Eq)) {
    if (!check(Tok::Ident)) {
      errorAtCur("expected the name of the result variable after '='");
      bail();
    }
    decl->resultName = cur().text;
    decl->resultLine = cur().line;
    decl->resultCol = cur().col;
    ++pos_;
  }

  // The completion of a forward declaration repeats the name alone (ISO 7185
  // §6.6.1), so both the parameters and the result type may be absent here.
  if (isFunction && accept(Tok::Colon)) {
    if (!check(Tok::Ident)) {
      errorAtCur("expected the result type of the function");
      bail();
    }
    decl->returnType = parseTypeDenoter();
  }
  expect(Tok::Semi, "after the heading of a procedure or function");
  return decl;
}

/// formal-parameters = '(' group (';' group)* ')'
/// group            = 'var'? ident-list ':' type-denoter
///                  | 'procedure' ident formal-parameters?
///                  | 'function' ident formal-parameters? ':' type-denoter
///
/// ISO 7185 §6.6.3.1 restricts a parameter's type to a type *identifier*, so
/// an array parameter needs a named type. That is a real restriction, not an
/// omission here: it is what makes a formal and an actual parameter the same
/// type rather than two structurally identical ones.
///
/// The last two forms are a procedural and a functional parameter, and each is
/// spelled as a *heading* rather than as a type — which is why one group
/// declares one name there, and why this production has to recurse.
void Parser::parseFormalParameters(std::vector<ParamGroup> &into) {
  Depth guard(*this);
  expect(Tok::LParen, "");
  do {
    ParamGroup group;
    if (check(Tok::KwProcedure) || check(Tok::KwFunction)) {
      parseProcParam(group, check(Tok::KwFunction));
      into.push_back(std::move(group));
      continue;
    }
    // §6.7.3.1 puts `protected` before the whole specification, so it comes
    // before `var` rather than after it: a protected variable parameter is
    // `protected var d: integer`. Both orders read alike, and only one parses.
    group.isProtected = accept(Tok::KwProtected);
    group.byRef = accept(Tok::KwVar);
    group.names = parseNameList("a parameter name");
    expect(Tok::Colon, "in a parameter list");
    // §6.7.3.1: `parameter-form = type-name | schema-name | type-inquiry`, so
    // a parameter's type is still not a type-denoter — it is a name, or one of
    // those two other forms. `type` is the only word-symbol that may begin one.
    if (!check(Tok::Ident) && !check(Tok::KwType)) {
      errorAtCur("a parameter's type must be a type name");
      bail();
    }
    group.type = parseTypeDenoter();
    into.push_back(std::move(group));
  } while (accept(Tok::Semi));
  expect(Tok::RParen, "after the parameter list");
}

void Parser::parseProcParam(ParamGroup &group, bool isFunction) {
  group.isProc = true;
  group.isFunction = isFunction;
  ++pos_; // 'procedure' / 'function'

  if (!check(Tok::Ident)) {
    errorAtCur(isFunction ? "expected the name of the functional parameter"
                          : "expected the name of the procedural parameter");
    bail();
  }
  group.names.push_back({cur().text, cur().line, cur().col});
  ++pos_;

  if (check(Tok::LParen))
    parseFormalParameters(group.params);

  // A functional parameter's heading carries its result type, and there is no
  // `forward` here to make it optional the way §6.6.1 makes it optional in a
  // declaration — so unlike parseProcOrFunc this one insists on it.
  if (isFunction) {
    expect(Tok::Colon, "before the result type of a functional parameter");
    if (!check(Tok::Ident)) {
      errorAtCur("the result type of a functional parameter must be a type name");
      bail();
    }
    group.returnType = parseTypeDenoter();
  }
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
  // ISO/IEC 10206:1991 §6.4.2.4 makes a subrange-bound a constant-expression
  // (§6.8.2), so the `..` is no longer two tokens away — `base - 9 .. base + 1`
  // is a subrange and `base` alone is a type name. What still separates them is
  // a `..` before the denoter ends, so this scans for one at bracket depth
  // zero. Only the denoters that begin with a name, a literal or a sign reach
  // here: `array`, `record`, `set`, `file` and `^` are all decided by their
  // first token.
  if (std_ == Std::Extended) {
    int depth = 0;
    for (size_t i = pos_; i < toks_.size(); ++i) {
      switch (toks_[i].kind) {
      case Tok::LParen:
      case Tok::LBracket:
        ++depth;
        break;
      case Tok::RParen:
      case Tok::RBracket:
        if (depth == 0)
          return false; // the denoter ended
        --depth;
        break;
      case Tok::DotDot:
        if (depth == 0)
          return true;
        break;
      case Tok::Semi:
      case Tok::Comma:
      case Tok::Colon:
      case Tok::Eq:
      case Tok::Period:
      case Tok::KwOf:
      case Tok::KwEnd:
      case Tok::KwBegin:
      case Tok::Eof:
        if (depth == 0)
          return false;
        break;
      default:
        break;
      }
    }
    return false;
  }
  // ISO 7185 §6.4.2.4's bound is a `constant` — a signed literal or a name —
  // so the two forms diverge at the token after it and nowhere else.
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
/// type-denoter = ( type-name | new-type | type-inquiry | discriminated-schema )
///                 [ initial-state-specifier ]      (ISO/IEC 10206:1991 §6.4.1)
///
/// Only the three positions that may carry a specifier call this; every nested
/// denoter calls `parseTypeDenoter` and stops before the word. That is not a
/// shortcut — it is the only reading that parses. `set of 1..9 value [2]` has
/// one place the specifier can attach and the recursion would have taken it
/// for the base type, and `array [1..8] of char value '*'` is §6.6 NOTE 3's
/// own example of a violation *because* the value belongs to the array. So the
/// component stops at the word and the outer denoter takes it, which is what
/// turns that example into the type error the note says it is.
TypeExprPtr Parser::parseTypeExpr() {
  // §6.4.1 puts `bindable` *before* the denoter and the initial-state
  // specifier after it, so the two brackets of that production are parsed on
  // either side of one call. Like `value`, this word is one Extended Pascal
  // adds, so no `--std` test is possible: under ISO 7185 the lexer yields an
  // identifier and the token never appears.
  bool bindable = accept(Tok::KwBindable);
  TypeExprPtr t = parseTypeDenoter();
  t->bindable = bindable;
  // No `--std` test here, and there cannot be one: `value` is a word-symbol
  // Extended Pascal *adds*, so under ISO 7185 the lexer yields an identifier
  // and this token never appears. The lexer's decision is the whole of the
  // feature's language gating — unlike `type of`, whose words are reserved in
  // both languages and which therefore needs an explicit refusal.
  if (accept(Tok::KwValue))
    t->initValue = parseExpr();
  return t;
}

TypeExprPtr Parser::parseTypeDenoter() {
  Depth depth(*this); // array-of-array and record fields recurse through here
  bool packed = accept(Tok::KwPacked);

  if (check(Tok::KwFile)) {
    auto t = std::make_unique<TypeExpr>();
    t->kind = TEK::File;
    t->packed = packed;
    t->line = cur().line;
    t->col = cur().col;
    ++pos_;
    // ISO/IEC 10206:1991 §6.4.3.6: `file [ index-type ] of component-type`.
    // The brackets are what make a file direct-access, and nothing else does —
    // so this is the whole of the syntax the feature adds.
    if (check(Tok::LBracket)) {
      if (std_ == Std::Iso7185) {
        errorAtCur("a direct-access file is an Extended Pascal feature; "
                   "compile with --std=extended");
        bail();
      }
      ++pos_;
      t->index = parseTypeDenoter();
      expect(Tok::RBracket, "after the index type of a direct-access file");
    }
    expect(Tok::KwOf, "after 'file'");
    t->elem = parseTypeDenoter();
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
    t->elem = parseTypeDenoter();
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

  // restricted-type = 'restricted' type-name (§6.4.2.5). The syntax admits a
  // *name* and nothing else, so there is no nested denoter here — which is
  // also why a restricted-type cannot be built out of an anonymous one.
  if (check(Tok::KwRestricted)) {
    auto t = std::make_unique<TypeExpr>();
    t->kind = TEK::Restricted;
    t->line = cur().line;
    t->col = cur().col;
    ++pos_;
    if (!check(Tok::Ident)) {
      errorAtCur("'restricted' must be followed by a type name");
      bail();
    }
    t->name = cur().text;
    ++pos_;
    return t;
  }

  // type-inquiry = 'type' 'of' type-inquiry-object (§6.4.9). Both words are
  // already reserved in ISO 7185, so this feature reserves nothing — the
  // second such after `and then`. There is no ambiguity to resolve either:
  // `type` cannot begin a type-denoter in that language at all.
  if (check(Tok::KwType)) {
    auto t = std::make_unique<TypeExpr>();
    t->kind = TEK::Inquiry;
    t->line = cur().line;
    t->col = cur().col;
    if (std_ == Std::Iso7185) {
      errorAtCur("a type-inquiry is an Extended Pascal feature; compile with "
                 "--std=extended");
      bail();
    }
    ++pos_;
    expect(Tok::KwOf, "after 'type' in a type-inquiry");
    if (!check(Tok::Ident)) {
      errorAtCur("'type of' must name a variable or a parameter");
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

  // §6.11.3's qualified name. In a type-denoter there is nothing else `a.b`
  // could be — a type has no fields to select — so unlike an expression this
  // needs no help from Sema to decide.
  if (std_ == Std::Extended && check(Tok::Period) && check(Tok::Ident, 1)) {
    t->qualifier = t->name;
    ++pos_;
    t->name = cur().text;
    ++pos_;
  }

  // ISO/IEC 10206:1991 §6.4.8: a name followed by an actual-discriminant-part
  // is a discriminated-schema. Nothing else in a type-denoter position can
  // begin with '(' after a name, so no lookahead beyond this token is needed
  // — and the parser does not care whether the name turns out to denote a
  // schema, which is Sema's question.
  if (check(Tok::LParen)) {
    if (std_ == Std::Iso7185) {
      errorAtCur("a discriminated schema is an Extended Pascal feature; "
                 "compile with --std=extended");
      bail();
    }
    t->kind = TEK::Schema;
    ++pos_;
    do {
      t->args.push_back(parseExpr());
    } while (accept(Tok::Comma));
    expect(Tok::RParen, "after the discriminants of a schema");
  }
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
    t->dims.push_back(parseTypeDenoter());
  } while (accept(Tok::Comma));

  expect(Tok::RBracket, "after the index type of an array");
  expect(Tok::KwOf, "after the index type of an array");
  t->elem = parseTypeDenoter();
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

/// case-constant-list = case-range (',' case-range)*
/// case-range         = constant ('..' constant)?     -- '..' Extended Pascal
///
/// ISO/IEC 10206:1991 generalised the constant list once, and both the case
/// statement (§6.8.3.5) and a variant (§6.4.3.3) name it — so a range is legal
/// in either, and neither place gets a rule of its own.
CaseLabel Parser::parseCaseLabel() {
  CaseLabel label;
  label.lo = parseExpr();
  if (check(Tok::DotDot)) {
    if (std_ == Std::Iso7185) {
      errorAtCur("a range of case constants is an Extended Pascal feature; "
                 "compile with --std=extended");
      bail();
    }
    ++pos_;
    label.hi = parseExpr();
  }
  return label;
}

/// variant-part = 'case' (identifier ':')? type-identifier 'of' variant
///                (';' variant)* (';' completer)?
/// variant      = constant (',' constant)* ':' '(' field-list ')'
/// completer    = 'otherwise' '(' field-list ')'      -- Extended Pascal only
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
  tagType = parseTypeDenoter();
  expect(Tok::KwOf, "after the tag of a variant part");

  while (!check(Tok::KwEnd)) {
    VariantArm arm;
    arm.line = cur().line;
    arm.col = cur().col;
    // ISO/IEC 10206:1991 §6.4.3.3: the variant-list may end with a
    // variant-part-completer, `otherwise (field-list)` — no labels, and no
    // colon, because it names no constants.
    bool completer = accept(Tok::KwOtherwise);
    if (completer) {
      arm.isOtherwise = true;
    } else {
      // Under ISO 7185 `otherwise` is an ordinary identifier and may well name
      // the constant a variant is labelled with. What follows parts them: a
      // label list is followed by ',' or ':', the completer by '('.
      if (std_ == Std::Iso7185 && check(Tok::Ident) &&
          cur().text == "otherwise" && check(Tok::LParen, 1)) {
        errorAtCur("the 'otherwise' part of a variant part is an Extended "
                   "Pascal feature; compile with --std=extended");
        bail();
      }
      do {
        arm.labels.push_back(parseCaseLabel());
      } while (accept(Tok::Comma));
      expect(Tok::Colon, "after the labels of a variant");
    }
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

    // The completer ends the variant-list, so nothing may follow it — the same
    // shape as the otherwise-part of a case statement.
    if (completer || !accept(Tok::Semi))
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
    // §6.4.7's schema-definition is a type-definition with a
    // formal-discriminant-part wedged between the name and the '='. One token
    // tells them apart, and it is the same token in both languages: a type
    // definition has '=' there.
    if (check(Tok::LParen)) {
      if (std_ == Std::Iso7185) {
        errorAtCur("a schema is an Extended Pascal feature; compile with "
                   "--std=extended");
        bail();
      }
      parseFormalDiscriminants(d.discriminants);
    }
    expect(Tok::Eq, "in a type definition");
    d.type = parseTypeExpr();
    expect(Tok::Semi, "after a type definition");
    prog.types.push_back(std::move(d));
  } while (check(Tok::Ident));
}

/// formal-discriminant-part = '(' discriminant-specification
///                              (';' discriminant-specification)* ')'
/// discriminant-specification = identifier-list ':' ordinal-type-name
///
/// The separator is ';' as in a formal parameter list, not ',' as in the
/// actual-discriminant-part that later selects a type from the schema — which
/// is the standard's own asymmetry (§6.4.7 against §6.4.8), and the reason
/// these are two routines rather than one.
void Parser::parseFormalDiscriminants(std::vector<DiscriminantGroup> &out) {
  expect(Tok::LParen, "");
  do {
    DiscriminantGroup g;
    g.line = cur().line;
    g.col = cur().col;
    g.names = parseNameList("a discriminant name");
    expect(Tok::Colon, "in a formal discriminant");
    if (!check(Tok::Ident)) {
      errorAtCur("the type of a discriminant must be an ordinal type name");
      bail();
    }
    g.typeName = cur().text;
    ++pos_;
    out.push_back(std::move(g));
  } while (accept(Tok::Semi));
  expect(Tok::RParen, "after the discriminants of a schema");
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
  case Tok::KwGoto: {
    auto s = makeNode<GotoStmt>(cur());
    ++pos_;
    s->label = parseLabel("after 'goto'");
    return s;
  }
  // A statement beginning with an unsigned integer can only be a labelled one:
  // no expression starts a statement, so the ':' is not in doubt and needs no
  // lookahead to find.
  case Tok::IntLit: {
    auto s = makeNode<LabeledStmt>(cur());
    s->label = parseLabel("at the start of a labelled statement");
    expect(Tok::Colon, "after a statement label");
    s->body = parseStatement();
    return s;
  }
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
    // ISO/IEC 10206:1991's otherwise-part: what to do when no label matches,
    // in place of the trap ISO 7185 leaves. It is last, so nothing follows it
    // but `end`.
    if (accept(Tok::KwOtherwise)) {
      s->hasOtherwise = true;
      do {
        s->otherwise.push_back(parseStatement());
      } while (accept(Tok::Semi));
      break;
    }
    // Under ISO 7185 `otherwise` is an ordinary identifier, so this reads as
    // a case label and fails somewhere unhelpful. It is only the construct if
    // it is not being used as a constant — `otherwise: s` and `otherwise, 2:`
    // are a label list naming a constant, and stay one.
    if (std_ == Std::Iso7185 && check(Tok::Ident) &&
        cur().text == "otherwise" && !check(Tok::Colon, 1) &&
        !check(Tok::Comma, 1) && !check(Tok::DotDot, 1)) {
      errorAtCur("the 'otherwise' part of a case statement is an Extended "
                 "Pascal feature; compile with --std=extended");
      bail();
    }

    CaseArm arm;
    arm.line = cur().line;
    arm.col = cur().col;
    do {
      arm.labels.push_back(parseCaseLabel());
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

/// ISO/IEC 10206:1991 §6.8.6.4's function-identified-variable, `f(x)^`, is the
/// one function-access §6.5.1 admits as a *variable*-access — so it may be
/// assigned to, and a statement beginning with a name and an argument list is
/// no longer certainly a procedure-statement.
///
/// Every other function-access is refused by the grammar rather than by a
/// rule: an assignment-statement's target is a variable-access, and
/// `mk(1, 2).x` is not one, so nothing here needs to say so.
///
/// This scans to the matching `)` — the same bracket-depth walk
/// `looksLikeSubrange` makes, and for the same reason: the token that decides
/// is not a fixed distance away.
bool Parser::callTakesCaret(size_t from) const {
  if (std_ != Std::Extended || from >= toks_.size() ||
      toks_[from].kind != Tok::LParen)
    return false;
  int depth = 0;
  for (size_t i = from; i < toks_.size(); ++i) {
    if (toks_[i].kind == Tok::LParen || toks_[i].kind == Tok::LBracket)
      ++depth;
    else if (toks_[i].kind == Tok::RParen || toks_[i].kind == Tok::RBracket) {
      if (--depth == 0)
        return i + 1 < toks_.size() && toks_[i + 1].kind == Tok::Caret;
    } else if (toks_[i].kind == Tok::Eof)
      break;
  }
  return false;
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

  // §6.8.6.4, both spellings of it. `parsePrimary` builds the call and then
  // its selectors, so the target is assembled by the code that already knows
  // how — this branch only has to recognise that the statement is one.
  if ((peek().kind == Tok::LParen && callTakesCaret(pos_ + 1)) ||
      (peek().kind == Tok::Period && peek(2).kind == Tok::Ident &&
       peek(3).kind == Tok::LParen && callTakesCaret(pos_ + 3))) {
    auto s = makeNode<Assign>(id);
    s->target = parsePrimary();
    expect(Tok::Assign, "in an assignment");
    s->value = parseExpr();
    return s;
  }

  // ISO/IEC 10206:1991 §6.11.3's qualified name in a procedure-statement.
  // `a.b` is a field selection unless what follows it can neither continue a
  // designator nor assign to one — and those five tokens are the whole of what
  // can, so a sixth means the statement is a call of `b` through interface `a`.
  if (peek().kind == Tok::Period && peek(2).kind == Tok::Ident &&
      peek(3).kind != Tok::Assign && peek(3).kind != Tok::LBracket &&
      peek(3).kind != Tok::Period && peek(3).kind != Tok::Caret) {
    auto s = makeNode<ProcCallStmt>(id);
    s->qualifier = id.text;
    s->name = peek(2).text;
    pos_ += 3;
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
      bool substring = false;
      do {
        depth.bump();
        const Token &at = cur();
        ExprPtr index = parseExpr();
        // ISO/IEC 10206:1991 §6.5.6 and §6.8.6.5. A `..` inside a subscript can
        // only be this: an array's index-expression is a single expression, so
        // the parser decides without knowing any type. The grammar admits
        // exactly one, so no comma may follow.
        if (std_ == Std::Extended && check(Tok::DotDot)) {
          auto sub = makeNode<SubstringExpr>(at);
          ++pos_;
          sub->base = std::move(base);
          sub->lo = std::move(index);
          sub->hi = parseExpr();
          base = std::move(sub);
          substring = true;
          break;
        }
        auto idx = makeNode<IndexExpr>(at);
        idx->base = std::move(base);
        idx->index = std::move(index);
        base = std::move(idx);
      } while (accept(Tok::Comma)); // `a[i, j]` is `a[i][j]`
      expect(Tok::RBracket,
             substring ? "after a substring" : "after a subscript");
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

/// ISO/IEC 10206:1991 §6.8.6: a function-access may carry selectors, so
/// `mk(7, 8).y`, `scale(10)[2]` and `alloc(3)^` are expressions. Under
/// ISO 7185 §6.6.2 a function result is a simple type or a pointer, so only
/// the last of those could arise and the standard does not offer it either.
///
/// Nothing else in the parser distinguishes a call's selectors from a
/// variable's, and nothing in Sema or CodeGen is told which it walked. That is
/// the whole of the feature: §6.8.6's NOTE ("a function-access is not
/// equivalent to a variable-access") is already spelled by `Sema::isDesignator`
/// answering `false` for a call, and every restriction the NOTE names — an
/// actual var parameter, a `with`'s record, an assignment's target — is a call
/// site of that one predicate.
ExprPtr Parser::afterCall(ExprPtr call) {
  if (std_ != Std::Extended)
    return call;
  return parseSelectors(std::move(call));
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
    // and `or else` among the adding-operators, beside `or`
    case Tok::KwOrElse: op = BinOp::OrElse; break;
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
    // §6.8.3.1 puts `and then` among the multiplying-operators, beside `and`
    case Tok::KwAndThen: op = BinOp::AndThen; break;
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
  ExprPtr result = parsePrimary();
  BinOp op;
  switch (cur().kind) {
  case Tok::StarStar: op = BinOp::Exp; break;
  case Tok::KwPow:    op = BinOp::Pow; break;
  default:            return result;
  }
  auto bin = makeNode<Binary>(cur());
  ++pos_;
  bin->op = op;
  bin->lhs = std::move(result);
  bin->rhs = parsePrimary();
  // §6.8.1 makes operators of one precedence left associative, but the syntax
  // of a factor admits only one exponentiating-operator — so `a ** b ** c` has
  // no meaning to fall back on, and saying which parenthesisation is wanted is
  // the caller's business rather than this parser's.
  if (check(Tok::StarStar) || check(Tok::KwPow)) {
    errorAtCur("an exponentiating operator cannot follow another: write "
               "(a ** b) ** c or a ** (b ** c)");
    bail();
  }
  return bin;
}

ExprPtr Parser::parsePrimary() {
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
    // `not` is a primary, not a factor: it binds tighter than `**` (§6.8.1
    // gives it the highest precedence of all), so `not a ** b` exponentiates
    // the negation. Under ISO 7185 a factor *is* a primary and nothing moves.
    auto n = makeNode<Unary>(t);
    n->op = UnOp::Not;
    ++pos_;
    n->operand = parsePrimary();
    return n;
  }
  case Tok::Minus: {
    // A sign takes a whole factor, so `-3 ** 2` is -(3 ** 2) — the same rule
    // that already makes `-7 mod 3` be -(7 mod 3). It matters here beyond
    // taste: `**` is an error on a negative left operand, so the other reading
    // would turn a legal expression into a runtime error.
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
      return afterCall(std::move(call));
    }
    // §6.11.3's qualified name in call position. A record field is never
    // followed by `(` — there is no procedure type in the type part — so
    // `a.b(` has exactly one reading and the parser can take it.
    if (peek().kind == Tok::Period && peek(2).kind == Tok::Ident &&
        peek(3).kind == Tok::LParen) {
      auto call = makeNode<Call>(t);
      call->qualifier = t.text;
      call->name = peek(2).text;
      pos_ += 4;
      if (!check(Tok::RParen)) {
        do {
          call->args.push_back(parseExpr());
        } while (accept(Tok::Comma));
      }
      expect(Tok::RParen, "after the arguments of a function call");
      return afterCall(std::move(call));
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
      return afterCall(std::move(call));
    }
    auto ref = makeNode<VarRef>(t);
    ref->name = t.text;
    ++pos_;
    return parseSelectors(std::move(ref));
  }
  default:
    errorAtCur(std::string("expected an expression, found ") +
               tokenName(t.kind));
    bail();
  }
}

} // namespace ap
