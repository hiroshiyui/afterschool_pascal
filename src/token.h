#pragma once
#include <string>

namespace ap {

/// Which standard the source is written in. ISO 7185 is the default, and the
/// whole test corpus, `verify/` and `selfhost/compiler.pas` are written in it —
/// so Extended Pascal is not simply switched on. ISO/IEC 10206:1991 adds
/// word-symbols (`otherwise`, `value`, `only`, …) that a valid ISO 7185
/// program may use as ordinary identifiers, and this one does: `compiler.pas`
/// has a record field named `value`. Selecting the language is therefore a
/// real choice and not a convenience (ADR-0033).
enum class Std { Iso7185, Extended };

enum class Tok {
  Eof, Ident, IntLit, RealLit, StrLit,

  // punctuation and operators
  Plus, Minus, Star, Slash, Assign, Comma, Semi, Colon, Period, DotDot,
  // ISO/IEC 10206:1991 §6.8.3.1's other exponentiating-operator. It is lexed
  // under both standards and refused under ISO 7185, where no valid program
  // can contain two adjacent stars outside a comment or a string anyway.
  StarStar,
  LParen, RParen, LBracket, RBracket, Caret,
  Eq, NotEq, Lt, Le, Gt, Ge,

  // all ISO 7185 reserved words; the parser rejects the ones it cannot handle
  // yet, but the lexer knows every one of them from the start.
  KwAnd, KwArray, KwBegin, KwCase, KwConst, KwDiv, KwDo, KwDownto, KwElse,
  KwEnd, KwFile, KwFor, KwFunction, KwGoto, KwIf, KwIn, KwLabel, KwMod,
  KwNil, KwNot, KwOf, KwOr, KwPacked, KwProcedure, KwProgram, KwRecord,
  KwRepeat, KwSet, KwThen, KwTo, KwType, KwUntil, KwVar, KwWhile, KwWith,

  // ISO/IEC 10206:1991 word-symbols, reserved only under `--std=extended`.
  // Under ISO 7185 the lexer yields these spellings as identifiers, which is
  // what they are in that language.
  KwOtherwise, KwPow, KwProtected, KwValue, KwBindable,

  // §6.1.2 spells the short-circuit operators as *two words with a separator
  // between them* — `and then` and `or else` are each one word-symbol, not a
  // pair. They therefore reserve nothing new: both halves are already reserved
  // in ISO 7185, and the lexer builds these by merging two tokens rather than
  // by looking a spelling up.
  KwAndThen, KwOrElse,
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
