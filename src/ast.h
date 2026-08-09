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
  IntLit, RealLit, CharLit, StrLit, VarRef, Index, Field, Binary, Unary, Call,
  // statements
  Empty, Assign, Write, Compound, If, While, Repeat, For, ProcCall, With, Case,
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
  /// When the name resolved to a field of an enclosing `with`, `sym` is the
  /// hidden variable holding that record's address and this is the field it
  /// selects. Null when the name is an ordinary variable.
  const Field *withField = nullptr;
};

/// `base[index]`. One subscript per node, so `a[i, j]` is two of them — which
/// is exactly what ISO 7185 §6.5.3.2 says that abbreviation means.
struct IndexExpr : Expr {
  static constexpr NK NodeKind = NK::Index;
  IndexExpr() : Expr(NodeKind) {}
  ExprPtr base;
  ExprPtr index;
};

/// `base.field`. Sema resolves the name to the field itself, so codegen
/// indexes by position and never looks at the spelling.
struct FieldExpr : Expr {
  static constexpr NK NodeKind = NK::Field;
  FieldExpr() : Expr(NodeKind) {}
  ExprPtr base;
  std::string field;
  const Field *resolved = nullptr; // filled in by Sema
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
  ExprPtr target; // a designator: a name, possibly with subscripts and fields
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

/// `with r do S` — inside S the fields of r are visible as bare names. The
/// record designator is evaluated once (ISO 7185 §6.8.3.10), so `binding` is a
/// hidden frame slot holding its address for the duration of the body.
/// `with a, b do S` is parsed as `with a do with b do S`.
struct WithStmt : Stmt {
  static constexpr NK NodeKind = NK::With;
  WithStmt() : Stmt(NodeKind) {}
  ExprPtr record;
  StmtPtr body;
  Symbol *binding = nullptr; // filled in by Sema
};

/// One arm of a case statement: the constants that select it, and what to do.
struct CaseArm {
  std::vector<ExprPtr> labels;
  std::vector<long long> values; // filled in by Sema
  StmtPtr body;
  int line = 0, col = 0;
};

/// ISO 7185 §6.8.3.5 has no `else`: if no label matches the selector, the
/// program is in error, so the default arm traps rather than falling through.
struct CaseStmt : Stmt {
  static constexpr NK NodeKind = NK::Case;
  CaseStmt() : Stmt(NodeKind) {}
  ExprPtr selector;
  std::vector<CaseArm> arms;
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

/// One name in a declaration, carrying where it was written so a duplicate or
/// a bad type can be reported against the name rather than the group.
struct DeclName {
  std::string name;
  int line = 0, col = 0;
};

struct TypeExpr;
using TypeExprPtr = std::unique_ptr<TypeExpr>;

/// A group of record fields sharing one type-denoter.
struct FieldGroup {
  std::vector<DeclName> names;
  TypeExprPtr type;
};

/// One arm of a record's variant part: `labels : (fields)`.
struct VariantArm {
  std::vector<ExprPtr> labels;
  std::vector<FieldGroup> fields;
  int line = 0, col = 0;
};

enum class TEK { Named, Enum, Subrange, Array, Record };

/// A type-denoter: what follows ':' in a declaration or '=' in the type part.
/// Deliberately not an Expr — a type is not a value, and keeping them apart is
/// what stops `a[i]` and `array[i]` from sharing a code path.
struct TypeExpr {
  TEK kind = TEK::Named;
  int line = 0, col = 0;

  std::string name;               // Named
  bool packed = false;            // Array, Record
  /// Array: one ordinal type per index. ISO 7185 §6.4.3.2 makes the index an
  /// ordinal *type*, which is why `array [1..3]` and `array [color]` are the
  /// same construct rather than two — and several of them is the `[a, b]`
  /// shorthand for an array of arrays.
  std::vector<TypeExprPtr> dims;
  TypeExprPtr elem;               // Array: the component type
  std::vector<FieldGroup> fields; // Record: the fixed part
  std::vector<DeclName> constants;// Enum
  ExprPtr lo, hi;                 // Subrange

  // Record: the variant part, if there is one. `tagName` is empty when the tag
  // has no field of its own (ISO 7185 §6.4.3.3 allows `case T of`).
  std::string tagName;
  TypeExprPtr tagType;
  std::vector<VariantArm> variants;
  int tagLine = 0, tagCol = 0;

  Type *resolved = nullptr; // filled in by Sema
};

struct TypeDecl {
  std::string name;
  TypeExprPtr type;
  int line = 0, col = 0;
};

/// A group of variables sharing one type-denoter. They share it in the AST as
/// well as in the source, which is what makes them the *same* type under
/// ISO 7185 §6.4.5 rather than two structurally identical ones.
struct VarDecl {
  std::vector<DeclName> names;
  TypeExprPtr type;
};

/// A group of parameters sharing one type-denoter and one passing mode.
struct ParamGroup {
  std::vector<DeclName> names;
  TypeExprPtr type;
  bool byRef = false; // a `var` parameter, passed by reference
};

struct Block;

/// A procedure or a function; `returnTypeName` is empty for a procedure.
/// A `forward` declaration has no body, and the later full declaration
/// re-uses the same Symbol.
struct ProcDecl {
  std::string name;
  bool isFunction = false;
  std::vector<ParamGroup> params;
  TypeExprPtr returnType; // null in the completion of a forward function
  std::unique_ptr<Block> body; // null for a forward declaration
  bool isForward = false;
  int line = 0, col = 0;
  Symbol *sym = nullptr; // filled in by Sema
};

/// The declaration part plus the statement part — the body of the program and
/// of every procedure alike, which is what makes nesting fall out for free.
struct Block {
  std::vector<ConstDecl> consts;
  std::vector<TypeDecl> types;
  std::vector<VarDecl> vars;
  std::vector<std::unique_ptr<ProcDecl>> procs;
  std::unique_ptr<Compound> body;
};

struct Program {
  std::string name;
  std::unique_ptr<Block> block;
};

} // namespace ap
