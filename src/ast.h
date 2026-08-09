#pragma once
#include <memory>
#include <string>
#include <vector>

#include "type.h"

namespace ap {

struct Symbol;

/// Node kinds are explicit tags rather than C++ RTTI. Two reasons: we link
/// against an LLVM built without RTTI, and the eventual self-hosted compiler
/// is written in Pascal, which has no dynamic_cast to lean on. A tag plus a
/// variant record is exactly what that version will use.
enum class NK {
  // expressions
  IntLit, RealLit, CharLit, StrLit, VarRef, Binary, Unary, Call,
  // statements
  Empty, Assign, Write, Compound, If, While, Repeat, For, ProcCall,
};

struct Node {
  NK kind;
  int line = 0;
  int col = 0;
  explicit Node(NK k) : kind(k) {}
  virtual ~Node() = default;
};

/// Checked down-cast: `as<Binary>(e)` yields null unless the tag matches.
template <typename T, typename N> T *as(N *n) {
  return (n && n->kind == T::NodeKind) ? static_cast<T *>(n) : nullptr;
}
template <typename T, typename N> bool is(N *n) {
  return n && n->kind == T::NodeKind;
}

// ---------------------------------------------------------------- expressions

enum class BinOp {
  Add, Sub, Mul, RealDiv, IntDiv, Mod, And, Or,
  Eq, Ne, Lt, Le, Gt, Ge,
};
enum class UnOp { Pos, Neg, Not };

/// Required functions of ISO 7185 that the compiler knows intrinsically.
enum class Builtin {
  None, Abs, Sqr, Odd, Ord, Chr, Succ, Pred,
  Sqrt, Sin, Cos, Ln, Exp, ArcTan, Trunc, Round,
};

struct Expr : Node {
  Type *type = nullptr; // filled in by Sema
  using Node::Node;
};
using ExprPtr = std::unique_ptr<Expr>;

struct IntLit : Expr {
  static constexpr NK NodeKind = NK::IntLit;
  IntLit() : Expr(NodeKind) {}
  long long value = 0;
};

struct RealLit : Expr {
  static constexpr NK NodeKind = NK::RealLit;
  RealLit() : Expr(NodeKind) {}
  double value = 0;
};

struct CharLit : Expr {
  static constexpr NK NodeKind = NK::CharLit;
  CharLit() : Expr(NodeKind) {}
  char value = 0;
};

struct StrLit : Expr {
  static constexpr NK NodeKind = NK::StrLit;
  StrLit() : Expr(NodeKind) {}
  std::string value;
};

struct VarRef : Expr {
  static constexpr NK NodeKind = NK::VarRef;
  VarRef() : Expr(NodeKind) {}
  std::string name;
  Symbol *sym = nullptr; // filled in by Sema
};

struct Binary : Expr {
  static constexpr NK NodeKind = NK::Binary;
  Binary() : Expr(NodeKind) {}
  BinOp op = BinOp::Add;
  ExprPtr lhs, rhs;
};

struct Unary : Expr {
  static constexpr NK NodeKind = NK::Unary;
  Unary() : Expr(NodeKind) {}
  UnOp op = UnOp::Pos;
  ExprPtr operand;
};

struct Call : Expr {
  static constexpr NK NodeKind = NK::Call;
  Call() : Expr(NodeKind) {}
  std::string name;
  Builtin builtin = Builtin::None; // filled in by Sema
  Symbol *sym = nullptr;           // set instead, for a user-defined function
  std::vector<ExprPtr> args;
};

// ---------------------------------------------------------------- statements

struct Stmt : Node {
  using Node::Node;
};
using StmtPtr = std::unique_ptr<Stmt>;

struct EmptyStmt : Stmt {
  static constexpr NK NodeKind = NK::Empty;
  EmptyStmt() : Stmt(NodeKind) {}
};

struct Assign : Stmt {
  static constexpr NK NodeKind = NK::Assign;
  Assign() : Stmt(NodeKind) {}
  std::unique_ptr<VarRef> target;
  ExprPtr value;
};

/// One argument of write/writeln, including its optional `:width:precision`.
struct WriteArg {
  ExprPtr value;
  ExprPtr width; // may be null
  ExprPtr prec;  // may be null
};

struct WriteStmt : Stmt {
  static constexpr NK NodeKind = NK::Write;
  WriteStmt() : Stmt(NodeKind) {}
  std::vector<WriteArg> args;
  bool newline = false;
};

struct Compound : Stmt {
  static constexpr NK NodeKind = NK::Compound;
  Compound() : Stmt(NodeKind) {}
  std::vector<StmtPtr> body;
};

struct IfStmt : Stmt {
  static constexpr NK NodeKind = NK::If;
  IfStmt() : Stmt(NodeKind) {}
  ExprPtr cond;
  StmtPtr thenBranch;
  StmtPtr elseBranch; // may be null
};

struct WhileStmt : Stmt {
  static constexpr NK NodeKind = NK::While;
  WhileStmt() : Stmt(NodeKind) {}
  ExprPtr cond;
  StmtPtr body;
};

struct RepeatStmt : Stmt {
  static constexpr NK NodeKind = NK::Repeat;
  RepeatStmt() : Stmt(NodeKind) {}
  std::vector<StmtPtr> body;
  ExprPtr cond;
};

struct ForStmt : Stmt {
  static constexpr NK NodeKind = NK::For;
  ForStmt() : Stmt(NodeKind) {}
  std::unique_ptr<VarRef> var;
  ExprPtr from, to;
  bool downto = false;
  StmtPtr body;
};

struct ProcCallStmt : Stmt {
  static constexpr NK NodeKind = NK::ProcCall;
  ProcCallStmt() : Stmt(NodeKind) {}
  std::string name;
  Symbol *sym = nullptr; // filled in by Sema
  std::vector<ExprPtr> args;
};

// --------------------------------------------------------------- declarations

struct ConstDecl {
  std::string name;
  ExprPtr value;
  int line = 0, col = 0;
};

struct VarDecl {
  std::string name;
  std::string typeName;
  int line = 0, col = 0;
};

struct ParamDecl {
  std::string name;
  std::string typeName;
  bool byRef = false; // a `var` parameter, passed by reference
  int line = 0, col = 0;
};

struct Block;

/// A procedure or a function; `returnTypeName` is empty for a procedure.
/// A `forward` declaration has no body, and the later full declaration
/// re-uses the same Symbol.
struct ProcDecl {
  std::string name;
  bool isFunction = false;
  std::vector<ParamDecl> params;
  std::string returnTypeName; // empty in the completion of a forward function
  std::unique_ptr<Block> body; // null for a forward declaration
  bool isForward = false;
  int line = 0, col = 0;
  Symbol *sym = nullptr; // filled in by Sema
};

/// The declaration part plus the statement part — the body of the program and
/// of every procedure alike, which is what makes nesting fall out for free.
struct Block {
  std::vector<ConstDecl> consts;
  std::vector<VarDecl> vars;
  std::vector<std::unique_ptr<ProcDecl>> procs;
  std::unique_ptr<Compound> body;
};

struct Program {
  std::string name;
  std::unique_ptr<Block> block;
};

} // namespace ap
