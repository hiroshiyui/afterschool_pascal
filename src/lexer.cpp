#include "lexer.h"

#include <cctype>
#include <cerrno>
#include <cstdlib>
#include <unordered_map>

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
  Token t = make(it != keywords().end() ? it->second : Tok::Ident, sl, sc);
  t.text = std::move(text);
  return t;
}

Token Lexer::lexNumber() {
  int sl = line_, sc = col_;
  std::string text;
  while (!eof() && std::isdigit(static_cast<unsigned char>(peek())))
    text += advance();

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
    if (errno == ERANGE)
      diags_.error(sl, sc, "integer literal out of range: " + text);
  }
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
      out.push_back(lexIdentOrKeyword());
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
    case '*': out.push_back(make(Tok::Star, sl, sc)); break;
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
