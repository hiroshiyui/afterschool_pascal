#include "lexer.h"

#include <cctype>
#include <cerrno>
#include <cstdlib>
#include <string>
#include <unordered_map>

#include "type.h"

namespace ap {

const char *tokenName(Tok t) {
  switch (t) {
  case Tok::Eof: return "end of file";
  case Tok::Ident: return "identifier";
  case Tok::IntLit: return "integer literal";
  case Tok::RealLit: return "real literal";
  case Tok::StrLit: return "string literal";
  case Tok::Plus: return "'+'";
  case Tok::Minus: return "'-'";
  case Tok::Star: return "'*'";
  case Tok::Slash: return "'/'";
  case Tok::Assign: return "':='";
  case Tok::Comma: return "','";
  case Tok::Semi: return "';'";
  case Tok::Colon: return "':'";
  case Tok::Period: return "'.'";
  case Tok::DotDot: return "'..'";
  case Tok::LParen: return "'('";
  case Tok::RParen: return "')'";
  case Tok::LBracket: return "'['";
  case Tok::RBracket: return "']'";
  case Tok::Caret: return "'^'";
  case Tok::Eq: return "'='";
  case Tok::NotEq: return "'<>'";
  case Tok::Lt: return "'<'";
  case Tok::Le: return "'<='";
  case Tok::Gt: return "'>'";
  case Tok::Ge: return "'>='";
  case Tok::KwAnd: return "'and'";
  case Tok::KwArray: return "'array'";
  case Tok::KwBegin: return "'begin'";
  case Tok::KwCase: return "'case'";
  case Tok::KwConst: return "'const'";
  case Tok::KwDiv: return "'div'";
  case Tok::KwDo: return "'do'";
  case Tok::KwDownto: return "'downto'";
  case Tok::KwElse: return "'else'";
  case Tok::KwEnd: return "'end'";
  case Tok::KwFile: return "'file'";
  case Tok::KwFor: return "'for'";
  case Tok::KwFunction: return "'function'";
  case Tok::KwGoto: return "'goto'";
  case Tok::KwIf: return "'if'";
  case Tok::KwIn: return "'in'";
  case Tok::KwLabel: return "'label'";
  case Tok::KwMod: return "'mod'";
  case Tok::KwNil: return "'nil'";
  case Tok::KwNot: return "'not'";
  case Tok::KwOf: return "'of'";
  case Tok::KwOr: return "'or'";
  case Tok::KwPacked: return "'packed'";
  case Tok::KwProcedure: return "'procedure'";
  case Tok::KwProgram: return "'program'";
  case Tok::KwRecord: return "'record'";
  case Tok::KwRepeat: return "'repeat'";
  case Tok::KwSet: return "'set'";
  case Tok::KwThen: return "'then'";
  case Tok::KwTo: return "'to'";
  case Tok::KwType: return "'type'";
  case Tok::KwUntil: return "'until'";
  case Tok::KwVar: return "'var'";
  case Tok::KwWhile: return "'while'";
  case Tok::KwWith: return "'with'";
  case Tok::KwOtherwise: return "'otherwise'";
  case Tok::KwPow: return "'pow'";
  case Tok::KwProtected: return "'protected'";
  case Tok::KwValue: return "'value'";
  case Tok::StarStar: return "'**'";
  case Tok::KwAndThen: return "'and then'";
  case Tok::KwOrElse: return "'or else'";
  }
  return "token";
}

namespace {
const std::unordered_map<std::string, Tok> &keywords() {
  static const std::unordered_map<std::string, Tok> kw = {
      {"and", Tok::KwAnd},         {"array", Tok::KwArray},
      {"begin", Tok::KwBegin},     {"case", Tok::KwCase},
      {"const", Tok::KwConst},     {"div", Tok::KwDiv},
      {"do", Tok::KwDo},           {"downto", Tok::KwDownto},
      {"else", Tok::KwElse},       {"end", Tok::KwEnd},
      {"file", Tok::KwFile},       {"for", Tok::KwFor},
      {"function", Tok::KwFunction}, {"goto", Tok::KwGoto},
      {"if", Tok::KwIf},           {"in", Tok::KwIn},
      {"label", Tok::KwLabel},     {"mod", Tok::KwMod},
      {"nil", Tok::KwNil},         {"not", Tok::KwNot},
      {"of", Tok::KwOf},           {"or", Tok::KwOr},
      {"packed", Tok::KwPacked},   {"procedure", Tok::KwProcedure},
      {"program", Tok::KwProgram}, {"record", Tok::KwRecord},
      {"repeat", Tok::KwRepeat},   {"set", Tok::KwSet},
      {"then", Tok::KwThen},       {"to", Tok::KwTo},
      {"type", Tok::KwType},       {"until", Tok::KwUntil},
      {"var", Tok::KwVar},         {"while", Tok::KwWhile},
      {"with", Tok::KwWith},
  };
  return kw;
}

/// The word-symbols ISO/IEC 10206:1991 adds. They are looked up only under
/// `--std=extended`, because reserving them unconditionally would reject valid
/// ISO 7185 programs — including this compiler's own stage-1 source.
const std::unordered_map<std::string, Tok> &extendedKeywords() {
  static const std::unordered_map<std::string, Tok> kw = {
      {"otherwise", Tok::KwOtherwise},
      {"pow", Tok::KwPow},
      {"protected", Tok::KwProtected},
      {"value", Tok::KwValue},
  };
  return kw;
}
} // namespace

char Lexer::peek(int ahead) const {
  size_t i = pos_ + static_cast<size_t>(ahead);
  return i < src_.size() ? src_[i] : '\0';
}

char Lexer::advance() {
  char c = src_[pos_++];
  if (c == '\n') {
    ++line_;
    col_ = 1;
  } else {
    ++col_;
  }
  return c;
}

Token Lexer::make(Tok kind, int line, int col) const {
  Token t;
  t.kind = kind;
  t.line = line;
  t.col = col;
  return t;
}

void Lexer::skipTriviaAndComments() {
  for (;;) {
    while (!eof() && std::isspace(static_cast<unsigned char>(peek())))
      advance();

    if (peek() == '{') {
      int sl = line_, sc = col_;
      advance();
      while (!eof() && peek() != '}')
        advance();
      if (eof()) {
        diags_.error(sl, sc, "unterminated comment");
        return;
      }
      advance(); // '}'
      continue;
    }

    if (peek() == '(' && peek(1) == '*') {
      int sl = line_, sc = col_;
      advance();
      advance();
      while (!eof() && !(peek() == '*' && peek(1) == ')'))
        advance();
      if (eof()) {
        diags_.error(sl, sc, "unterminated comment");
        return;
      }
      advance();
      advance();
      continue;
    }
    return;
  }
}

Token Lexer::lexIdentOrKeyword() {
  int sl = line_, sc = col_;
  std::string text;
  while (!eof() && (std::isalnum(static_cast<unsigned char>(peek())) ||
                    peek() == '_'))
    text += static_cast<char>(
        std::tolower(static_cast<unsigned char>(advance())));

  auto it = keywords().find(text);
  Tok kind = it != keywords().end() ? it->second : Tok::Ident;
  if (kind == Tok::Ident && std_ == Std::Extended) {
    auto ext = extendedKeywords().find(text);
    if (ext != extendedKeywords().end())
      kind = ext->second;
  }
  Token t = make(kind, sl, sc);
  t.text = std::move(text);
  return t;
}

Token Lexer::lexNumber() {
  int sl = line_, sc = col_;
  std::string text;
  while (!eof() && std::isdigit(static_cast<unsigned char>(peek())))
    text += advance();

  // ISO/IEC 10206:1991 §6.1.5: `base#extended-digits`. The digit sequence just
  // scanned was the base, and what follows is never real — only an
  // unsigned-integer has this form.
  if (peek() == '#')
    return lexExtendedNumber(text, sl, sc);

  bool isReal = false;
  // A '.' only starts a fraction if a digit follows; otherwise it is the
  // program-terminating period or a subrange '..'.
  if (peek() == '.' && std::isdigit(static_cast<unsigned char>(peek(1)))) {
    isReal = true;
    text += advance();
    while (!eof() && std::isdigit(static_cast<unsigned char>(peek())))
      text += advance();
  }
  if (peek() == 'e' || peek() == 'E') {
    char sign = peek(1);
    int digitAt = (sign == '+' || sign == '-') ? 2 : 1;
    if (std::isdigit(static_cast<unsigned char>(peek(digitAt)))) {
      isReal = true;
      text += advance();
      if (sign == '+' || sign == '-')
        text += advance();
      while (!eof() && std::isdigit(static_cast<unsigned char>(peek())))
        text += advance();
    }
  }

  Token t = make(isReal ? Tok::RealLit : Tok::IntLit, sl, sc);
  t.text = text;
  if (isReal) {
    t.realVal = std::strtod(text.c_str(), nullptr);
  } else {
    errno = 0;
    t.intVal = std::strtoll(text.c_str(), nullptr, 10);
    // The integer type is -maxint..maxint (ISO 7185 §6.4.2.2). A literal is
    // always unsigned here — a leading '-' is a separate operator — so the
    // bound is maxint, and -2147483648 is out of range even though it fits an
    // i32. Without this, the value silently truncated to INT_MIN.
    if (errno == ERANGE || t.intVal > kMaxInt)
      diags_.error(sl, sc, "integer literal out of range (maxint is " +
                               std::to_string(kMaxInt) + "): " + text);
  }
  return t;
}

/// The value of an extended digit: ISO/IEC 10206:1991 §6.1.5 makes a letter one,
/// and letter case is no more significant here than it is in an identifier.
static int extendedDigit(char c) {
  if (c >= '0' && c <= '9')
    return c - '0';
  if (c >= 'a' && c <= 'z')
    return c - 'a' + 10;
  if (c >= 'A' && c <= 'Z')
    return c - 'A' + 10;
  return -1;
}

Token Lexer::lexExtendedNumber(const std::string &baseText, int sl, int sc) {
  std::string text = baseText;
  text += advance(); // '#'

  if (std_ == Std::Iso7185)
    diags_.error(sl, sc, "a non-decimal literal is an Extended Pascal feature; "
                         "compile with --std=extended");

  // The digit sequence is maximal: `16#ffand` is one ill-formed number rather
  // than a number and a word-symbol, because an extended digit *is* a letter.
  std::string digits;
  while (!eof() && std::isalnum(static_cast<unsigned char>(peek())))
    digits += advance();
  text += digits;

  Token t = make(Tok::IntLit, sl, sc);
  t.text = text;

  errno = 0;
  long long base = std::strtoll(baseText.c_str(), nullptr, 10);
  if (errno == ERANGE || base < 2 || base > 36) {
    diags_.error(sl, sc, "the base of a non-decimal literal must be between 2 "
                         "and 36, found " + baseText);
    return t;
  }
  if (digits.empty()) {
    diags_.error(sl, sc, "expected at least one digit after '#'");
    return t;
  }

  // Accumulated rather than converted, because the bound to check is maxint
  // and not what a 64-bit conversion happens to survive — the Pascal lexer has
  // no wider type to overflow into, and both must agree on where a literal
  // stops being one.
  long long value = 0;
  bool overflowed = false;
  for (char c : digits) {
    int d = extendedDigit(c);
    if (d < 0 || d >= base) {
      diags_.error(sl, sc, std::string("'") + c + "' is not a digit of base " +
                               std::to_string(base));
      return t;
    }
    if (!overflowed) {
      value = value * base + d;
      overflowed = value > kMaxInt;
    }
  }
  // The overflowing value is kept rather than zeroed: the dump prints `int ?`
  // for anything above maxint, and that is what the Pascal lexer — which has
  // no wider type and stops accumulating — prints from its own flag.
  t.intVal = value;
  if (overflowed)
    diags_.error(sl, sc, "integer literal out of range (maxint is " +
                             std::to_string(kMaxInt) + "): " + text);
  return t;
}

Token Lexer::lexString() {
  int sl = line_, sc = col_;
  advance(); // opening quote
  std::string value;
  for (;;) {
    if (eof() || peek() == '\n') {
      diags_.error(sl, sc, "unterminated string literal");
      break;
    }
    char c = advance();
    if (c == '\'') {
      if (peek() == '\'') { // '' is an escaped quote
        value += advance();
        continue;
      }
      break;
    }
    value += c;
  }
  Token t = make(Tok::StrLit, sl, sc);
  t.text = std::move(value);
  return t;
}

std::vector<Token> Lexer::tokenize() {
  std::vector<Token> out;
  for (;;) {
    skipTriviaAndComments();
    if (eof()) {
      out.push_back(make(Tok::Eof, line_, col_));
      return out;
    }

    char c = peek();
    int sl = line_, sc = col_;

    if (std::isalpha(static_cast<unsigned char>(c)) || c == '_') {
      Token word = lexIdentOrKeyword();
      // ISO/IEC 10206:1991 §6.1.2's two two-word word-symbols. Nothing looks
      // them up: `and`, `or`, `then` and `else` are already reserved in both
      // standards, so this feature reserves no new spelling at all — the
      // operator is a *pair* of tokens the lexer joins.
      //
      // The join is at the token level, so separators between the words are
      // whatever separates any two tokens. §6.1.10's "no separators shall
      // occur within tokens" cannot be read literally against a token whose
      // own reference representation contains a space, and the strict reading
      // would forbid a line break in the middle of an operator. The leniency
      // is safe rather than merely convenient: `and` followed by `then` has no
      // other meaning in either language, because `then` cannot begin a factor
      // and `else` cannot begin a term.
      Tok joined = Tok::Eof;
      if (!out.empty() && out.back().kind == Tok::KwAnd &&
          word.kind == Tok::KwThen)
        joined = Tok::KwAndThen;
      else if (!out.empty() && out.back().kind == Tok::KwOr &&
               word.kind == Tok::KwElse)
        joined = Tok::KwOrElse;
      if (joined != Tok::Eof) {
        // The operator starts where its first word does.
        Token op = make(joined, out.back().line, out.back().col);
        op.text = joined == Tok::KwAndThen ? "and then" : "or else";
        if (std_ == Std::Iso7185)
          diags_.error(op.line, op.col,
                       std::string(tokenName(joined)) +
                           " is an Extended Pascal operator; compile with "
                           "--std=extended");
        out.back() = op;
        continue;
      }
      out.push_back(std::move(word));
      continue;
    }
    if (std::isdigit(static_cast<unsigned char>(c))) {
      out.push_back(lexNumber());
      continue;
    }
    if (c == '\'') {
      out.push_back(lexString());
      continue;
    }

    advance();
    switch (c) {
    case '+': out.push_back(make(Tok::Plus, sl, sc)); break;
    case '-': out.push_back(make(Tok::Minus, sl, sc)); break;
    case '*':
      // A comment has already been consumed by the time we get here, so the
      // only way two stars can be adjacent is the exponentiating-operator.
      if (peek() == '*') {
        advance();
        if (std_ == Std::Iso7185)
          diags_.error(sl, sc, "'**' is an Extended Pascal operator; compile "
                               "with --std=extended");
        out.push_back(make(Tok::StarStar, sl, sc));
      } else {
        out.push_back(make(Tok::Star, sl, sc));
      }
      break;
    case '/': out.push_back(make(Tok::Slash, sl, sc)); break;
    case ',': out.push_back(make(Tok::Comma, sl, sc)); break;
    case ';': out.push_back(make(Tok::Semi, sl, sc)); break;
    case '=': out.push_back(make(Tok::Eq, sl, sc)); break;
    case '(': out.push_back(make(Tok::LParen, sl, sc)); break;
    case ')': out.push_back(make(Tok::RParen, sl, sc)); break;
    case '[': out.push_back(make(Tok::LBracket, sl, sc)); break;
    case ']': out.push_back(make(Tok::RBracket, sl, sc)); break;
    case '^': out.push_back(make(Tok::Caret, sl, sc)); break;
    case ':':
      if (peek() == '=') { advance(); out.push_back(make(Tok::Assign, sl, sc)); }
      else out.push_back(make(Tok::Colon, sl, sc));
      break;
    case '.':
      if (peek() == '.') { advance(); out.push_back(make(Tok::DotDot, sl, sc)); }
      else out.push_back(make(Tok::Period, sl, sc));
      break;
    case '<':
      if (peek() == '=') { advance(); out.push_back(make(Tok::Le, sl, sc)); }
      else if (peek() == '>') { advance(); out.push_back(make(Tok::NotEq, sl, sc)); }
      else out.push_back(make(Tok::Lt, sl, sc));
      break;
    case '>':
      if (peek() == '=') { advance(); out.push_back(make(Tok::Ge, sl, sc)); }
      else out.push_back(make(Tok::Gt, sl, sc));
      break;
    default:
      diags_.error(sl, sc, std::string("unexpected character '") + c + "'");
      break;
    }
  }
}

} // namespace ap
