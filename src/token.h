#pragma once
#include <string>

namespace ap {

enum class Tok {
  Eof, Ident, IntLit, RealLit, StrLit,

  // punctuation and operators
  Plus, Minus, Star, Slash, Assign, Comma, Semi, Colon, Period, DotDot,
  LParen, RParen, LBracket, RBracket, Caret,
  Eq, NotEq, Lt, Le, Gt, Ge,

  // all ISO 7185 reserved words; the parser rejects the ones it cannot handle
  // yet, but the lexer knows every one of them from the start.
  KwAnd, KwArray, KwBegin, KwCase, KwConst, KwDiv, KwDo, KwDownto, KwElse,
  KwEnd, KwFile, KwFor, KwFunction, KwGoto, KwIf, KwIn, KwLabel, KwMod,
  KwNil, KwNot, KwOf, KwOr, KwPacked, KwProcedure, KwProgram, KwRecord,
  KwRepeat, KwSet, KwThen, KwTo, KwType, KwUntil, KwVar, KwWhile, KwWith,
};

const char *tokenName(Tok t);

struct Token {
  Tok kind = Tok::Eof;
  std::string text;      // identifier spelling (lower-cased) or string value
  long long intVal = 0;
  double realVal = 0;
  int line = 0;
  int col = 0;
};

} // namespace ap
