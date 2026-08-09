#pragma once
#include <string>
#include <vector>

#include "diag.h"
#include "token.h"

namespace ap {

/// Hand-written scanner for ISO 7185 Pascal. Identifiers and reserved words
/// are case-insensitive, so every spelling is folded to lower case.
class Lexer {
public:
  Lexer(std::string source, Diagnostics &diags)
      : src_(std::move(source)), diags_(diags) {}

  std::vector<Token> tokenize();

private:
  char peek(int ahead = 0) const;
  char advance();
  bool eof() const { return pos_ >= src_.size(); }
  void skipTriviaAndComments();
  Token lexIdentOrKeyword();
  Token lexNumber();
  Token lexString();
  Token make(Tok kind, int line, int col) const;

  std::string src_;
  Diagnostics &diags_;
  size_t pos_ = 0;
  int line_ = 1;
  int col_ = 1;
};

} // namespace ap
