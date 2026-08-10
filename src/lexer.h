#pragma once
#include <string>
#include <vector>

#include "diag.h"
#include "token.h"

namespace ap {

/// Hand-written scanner. Identifiers and reserved words are case-insensitive,
/// so every spelling is folded to lower case.
///
/// It knows the word-symbols of both standards and the `Std` decides which are
/// reserved: ISO/IEC 10206:1991 reserves spellings — `otherwise`, `value`,
/// `only` — that a valid ISO 7185 program may use as identifiers, so this is
/// the one place the two languages actually differ in their lexis (ADR-0033).
class Lexer {
public:
  Lexer(std::string source, Diagnostics &diags, Std std = Std::Iso7185)
      : src_(std::move(source)), diags_(diags), std_(std) {}

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
  Std std_ = Std::Iso7185;
  size_t pos_ = 0;
  int line_ = 1;
  int col_ = 1;
};

} // namespace ap
