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

/// Recursive-descent parser shaped like the ISO 7185 grammar, so a production
/// and the function that reads it have the same name and the same nesting —
/// `expression` calls `simpleExpression` calls `term` calls `factor`.
///
/// It also reads the constructs ISO/IEC 10206:1991 adds, under `--std`. The
/// standard reaches the parser for one purpose only: to say that an Extended
/// Pascal construct *is* one, rather than reporting the syntax error its
/// spelling causes under ISO 7185 (ADR-0033).
class Parser {
public:
  Parser(std::vector<Token> tokens, Diagnostics &diags,
         Std std = Std::Iso7185)
      : toks_(std::move(tokens)), diags_(diags), std_(std) {}

  std::unique_ptr<Program> parseProgram();

private:
  const Token &cur() const { return toks_[pos_]; }
  const Token &peek(int ahead = 1) const;
  bool check(Tok k) const { return cur().kind == k; }
  bool check(Tok k, int ahead) const { return peek(ahead).kind == k; }
  bool accept(Tok k);
  bool expect(Tok k, const char *context);
  [[noreturn]] void bail();
  void errorAtCur(const std::string &msg);

  /// The deepest tree this parser will build. Every stage after the parser —
  /// Sema, CodeGen, and the AST's own destructor — recurses over the tree, so
  /// the parser is where depth is bounded once for all of them (ADR-0020).
  /// The measured crash points are above 19000 on an 8 MiB stack; 1000 leaves
  /// more than an order of magnitude of headroom for every walker.
  static constexpr int kMaxDepth = 1000;

  /// One level of nesting in the tree under construction. Recursive
  /// productions hold one of these per call; the iterative operator and
  /// selector loops call bump() per iteration, because a chain like
  /// `a+b+c+...` is built by a loop yet is as deep for the tree's walkers as
  /// parentheses would be — bounding call depth alone would miss it.
  class Depth {
  public:
    /// A recursive production: entering it is itself one level.
    explicit Depth(Parser &p) : p_(p), count_(1) { p_.enterLevel(); }
    /// A production that only *hosts* a spine-building loop: entering it is
    /// free — the recursion below it is already counted by parsePrimary — and
    /// only its bump()s are levels.
    enum class Spine { Loop };
    Depth(Parser &p, Spine) : p_(p), count_(0) {}
    ~Depth() { p_.depth_ -= count_; }
    void bump() {
      ++count_;
      p_.enterLevel();
    }

  private:
    Parser &p_;
    int count_;
  };
  void enterLevel();

  std::unique_ptr<Block> parseBlock();
  void parseLabelPart(Block &block);
  int parseLabel(const char *where);
  void parseConstPart(Block &block);
  void parseTypePart(Block &block);
  void parseVarPart(Block &block);
  std::unique_ptr<ProcDecl> parseProcOrFunc(bool isFunction);
  /// The formal parameter list of a procedure, or of a procedural parameter —
  /// the same production, which is why it takes the vector rather than the
  /// declaration (ISO 7185 §6.6.3.1).
  void parseFormalParameters(std::vector<ParamGroup> &into);
  /// One `procedure P(...)` or `function F(...): T` written *inside* a formal
  /// parameter list.
  void parseProcParam(ParamGroup &group, bool isFunction);

  TypeExprPtr parseTypeExpr();
  TypeExprPtr parseArrayType(bool packed);
  TypeExprPtr parseRecordType(bool packed);
  TypeExprPtr parseEnumType();
  /// The `case T of ...` of a record or of one arm of a variant part. The
  /// pieces are passed separately because both places hold them, and a variant
  /// record on the Pascal side cannot share a sub-struct between two arms.
  void parseVariantPart(std::string &tagName, TypeExprPtr &tagType,
                        std::vector<VariantArm> &arms, int &tagLine,
                        int &tagCol);
  /// One entry of a case-constant-list, in a case statement or in a variant:
  /// a constant, or `lo..hi` under Extended Pascal. Both places read the same
  /// production, so both get ranges from this one function.
  CaseLabel parseCaseLabel();
  /// True if what follows begins a subrange rather than a type name — that is,
  /// a constant followed by '..'.
  bool looksLikeSubrange() const;
  std::vector<DeclName> parseNameList(const char *what);

  StmtPtr parseStatement();
  std::unique_ptr<Compound> parseCompound();
  StmtPtr parseIf();
  StmtPtr parseWhile();
  StmtPtr parseRepeat();
  StmtPtr parseFor();
  StmtPtr parseCase();
  StmtPtr parseIdentStatement();
  StmtPtr parseWith();
  StmtPtr parseWrite(bool newline);
  StmtPtr parseRead(bool newline);

  /// Apply any `[...]` and `.field` selectors following a designator's base.
  ExprPtr parseSelectors(ExprPtr base);

  ExprPtr parseExpr();
  ExprPtr parseSimpleExpr();
  ExprPtr parseTerm();
  /// `factor = primary [ exponentiating-operator primary ]` — ISO/IEC
  /// 10206:1991 §6.8.1's extra precedence level, between `not` and the
  /// multiplying operators. The syntax admits *one* operator, so `a ** b ** c`
  /// is not a sentence of the language and is diagnosed rather than associated.
  /// Under ISO 7185 neither operator can reach here, and a factor is a primary.
  ExprPtr parseFactor();
  ExprPtr parsePrimary();

  template <typename T> std::unique_ptr<T> makeNode(const Token &at) {
    auto n = std::make_unique<T>();
    n->line = at.line;
    n->col = at.col;
    return n;
  }

  std::vector<Token> toks_;
  Diagnostics &diags_;
  /// Which standard is being parsed. Needed in exactly one place: to say
  /// that an Extended Pascal construct is one, rather than reporting the
  /// syntax error its spelling causes under ISO 7185.
  Std std_ = Std::Iso7185;
  size_t pos_ = 0;
  int depth_ = 0;
};

} // namespace ap
