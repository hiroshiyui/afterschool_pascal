#pragma once
#include <memory>
#include <vector>

#include "ast.h"
#include "diag.h"
#include "token.h"

namespace ap {

/// Thrown when the parser cannot make useful progress; the driver turns it
/// into a plain "compilation failed" once diagnostics have been printed.
struct ParseAbort {};

/// Recursive-descent parser following the ISO 7185 grammar. Milestone 1
/// implements the program header, the constant and variable parts, and the
/// full statement/expression grammar minus sets, pointers and records.
class Parser {
public:
  Parser(std::vector<Token> tokens, Diagnostics &diags)
      : toks_(std::move(tokens)), diags_(diags) {}

  std::unique_ptr<Program> parseProgram();

private:
  const Token &cur() const { return toks_[pos_]; }
  const Token &peek(int ahead = 1) const;
  bool check(Tok k) const { return cur().kind == k; }
  bool accept(Tok k);
  bool expect(Tok k, const char *context);
  [[noreturn]] void bail();
  void errorAtCur(const std::string &msg);

  std::unique_ptr<Block> parseBlock();
  void parseConstPart(Block &block);
  void parseVarPart(Block &block);
  std::unique_ptr<ProcDecl> parseProcOrFunc(bool isFunction);
  void parseFormalParameters(ProcDecl &decl);

  StmtPtr parseStatement();
  std::unique_ptr<Compound> parseCompound();
  StmtPtr parseIf();
  StmtPtr parseWhile();
  StmtPtr parseRepeat();
  StmtPtr parseFor();
  StmtPtr parseIdentStatement();
  StmtPtr parseWrite(bool newline);

  ExprPtr parseExpr();
  ExprPtr parseSimpleExpr();
  ExprPtr parseTerm();
  ExprPtr parseFactor();

  template <typename T> std::unique_ptr<T> makeNode(const Token &at) {
    auto n = std::make_unique<T>();
    n->line = at.line;
    n->col = at.col;
    return n;
  }

  std::vector<Token> toks_;
  Diagnostics &diags_;
  size_t pos_ = 0;
};

} // namespace ap
