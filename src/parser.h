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
    /// free — the recursion below it is already counted by parseFactor — and
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
  void parseConstPart(Block &block);
  void parseTypePart(Block &block);
  void parseVarPart(Block &block);
  std::unique_ptr<ProcDecl> parseProcOrFunc(bool isFunction);
  void parseFormalParameters(ProcDecl &decl);

  TypeExprPtr parseTypeExpr();
  TypeExprPtr parseArrayType(bool packed);
  TypeExprPtr parseRecordType(bool packed);
  TypeExprPtr parseEnumType();
  void parseVariantPart(TypeExpr &record);
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

  /// Apply any `[...]` and `.field` selectors following a designator's base.
  ExprPtr parseSelectors(ExprPtr base);

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
  int depth_ = 0;
};

} // namespace ap
