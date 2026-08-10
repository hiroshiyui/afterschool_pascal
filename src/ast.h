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
  IntLit, RealLit, CharLit, StrLit, NilLit, SetLit, VarRef, Index, Field,
  Deref, Binary, Unary, Call,
  // statements
  Empty, Assign, Write, Read, Compound, If, While, Repeat, For, ProcCall, With,
  Case, Goto, Labeled,
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
  // ISO/IEC 10206:1991 §6.8.3.2's exponentiating operators. They differ in
  // more than spelling: `**` converts both operands to real and yields a real,
  // while `pow` takes an integer right operand and yields the type of its
  // left one — so `2 pow 3` is the integer 8 and `2 ** 3` is 8.0.
  Exp, Pow,
  // `in` is a relational operator in ISO 7185 §6.7.2.4 and sits at the same
  // precedence as `=` and `<`, which is why it belongs here and not with the
  // adding operators despite taking a set on only one side.
  Eq, Ne, Lt, Le, Gt, Ge, In,
};
enum class UnOp { Pos, Neg, Not };

/// Required functions of ISO 7185 that the compiler knows intrinsically.
enum class Builtin {
  None, Abs, Sqr, Odd, Ord, Chr, Succ, Pred,
  Sqrt, Sin, Cos, Ln, Exp, ArcTan, Trunc, Round,
  // The file enquiries. Both take a file, and both default to `input` when
  // written without one (ISO 7185 §6.6.6.5), so they are the only builtins
  // that may appear with no argument list at all.
  Eof, Eoln,
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
  /// The literal as it was written. Kept beside the value because `--dump-ast`
  /// compares the two parsers on it: comparing converted doubles would compare
  /// two languages' float formatting rather than their parsing (ADR-0022).
  std::string text;
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

/// `nil` — a value of every pointer type, which is why it has no domain.
struct NilLit : Expr {
  static constexpr NK NodeKind = NK::NilLit;
  NilLit() : Expr(NodeKind) {}
};

/// One element of a set constructor: a single value, or the range `lo..hi`
/// that ISO 7185 §6.7.1 abbreviates. `hi` is null for a single value, which is
/// what tells the two apart — a range is not rewritten into its members,
/// because the bounds need not be constant.
struct SetMember {
  ExprPtr lo, hi;
};

/// `[a, b..c]` — a set constructor. Its type is decided by its members, and
/// `[]` by whatever it is compared or assigned to, so this is the one
/// expression whose type is not determined by its own subtree alone.
struct SetExpr : Expr {
  static constexpr NK NodeKind = NK::SetLit;
  SetExpr() : Expr(NodeKind) {}
  std::vector<SetMember> members;
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

/// `base^` — the variable a pointer points at. A designator like any other,
/// so it takes subscripts and fields after it: `p^.next^.value`.
struct DerefExpr : Expr {
  static constexpr NK NodeKind = NK::Deref;
  DerefExpr() : Expr(NodeKind) {}
  ExprPtr base;
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

/// `goto L`. ISO 7185 §6.8.2.4. Sema resolves the number to the labelled
/// statement's `id`, which is what codegen branches to — the number itself is
/// never used after that, since two blocks may both declare label 1.
struct GotoStmt : Stmt {
  static constexpr NK NodeKind = NK::Goto;
  GotoStmt() : Stmt(NodeKind) {}
  int label = 0;
  int id = -1;            // filled in by Sema: the target's unique id
  Symbol *owner = nullptr; // the procedure whose block declared the label
  /// The label belongs to an *enclosing* block, so reaching it abandons every
  /// activation between here and that one. A different lowering, not a longer
  /// one: a branch cannot leave a function (ADR-0032).
  bool nonLocal = false;
};

/// `L: statement`. A labelled statement is a statement, so it may appear
/// anywhere one may — which is exactly why §6.8.1 has to say which of those
/// places a `goto` is allowed to reach.
struct LabeledStmt : Stmt {
  static constexpr NK NodeKind = NK::Labeled;
  LabeledStmt() : Stmt(NodeKind) {}
  int label = 0;
  int id = -1;            // filled in by Sema
  StmtPtr body;
};

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
  /// The file written to. ISO 7185 §6.9.3 lets the first argument be a file
  /// variable, in which case it is not written but written *to*; Sema moves it
  /// here and leaves `args` holding only the values. Null means `output`,
  /// which Sema then resolves to the program parameter of that name.
  ExprPtr file;
};

/// `read` and `readln`. Kept apart from ProcCallStmt for the same reason
/// WriteStmt is: the first argument may be a file rather than a value, and
/// every remaining argument is a variable to store into, not an expression to
/// evaluate.
struct ReadStmt : Stmt {
  static constexpr NK NodeKind = NK::Read;
  ReadStmt() : Stmt(NodeKind) {}
  std::vector<ExprPtr> args;
  bool newline = false; // readln: finish the line after the last variable
  ExprPtr file;         // null means `input`
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
/// One entry of a case-constant-list: a single constant, or the range `lo..hi`
/// that ISO/IEC 10206:1991 §6.8.3.5 adds. `hi` is null for a single constant —
/// the same pair, and the same way of telling the two apart, as SetMember.
struct CaseLabel {
  ExprPtr lo, hi;
};

struct CaseArm {
  std::vector<CaseLabel> labels;
  std::vector<LabelRange> values; // filled in by Sema
  StmtPtr body;
  int line = 0, col = 0;
};

/// ISO 7185 §6.8.3.5 has no `else`: if no label matches the selector, the
/// program is in error, so the default arm traps rather than falling through.
/// ISO/IEC 10206:1991 adds `otherwise`, which gives that case something to do
/// — so the trap is what a case statement *without* one still does, and the
/// two forms differ only in what the default arm holds (ADR-0033).
struct CaseStmt : Stmt {
  static constexpr NK NodeKind = NK::Case;
  CaseStmt() : Stmt(NodeKind) {}
  ExprPtr selector;
  std::vector<CaseArm> arms;
  /// The statement-sequence after `otherwise`. `hasOtherwise` and not
  /// `!otherwise.empty()`, because `otherwise` followed by nothing is an empty
  /// statement — a legal way to say "and do nothing", which is exactly the
  /// case that must not trap.
  bool hasOtherwise = false;
  std::vector<StmtPtr> otherwise;
};

/// The standard procedures the compiler knows intrinsically, as `Builtin` does
/// for the required functions.
/// The standard procedures that are not statements of their own. `read` and
/// `readln` are ReadStmt, and `write`/`writeln` are WriteStmt, because their
/// argument lists are not ordinary expression lists.
enum class StdProc { None, New, Dispose, Reset, Rewrite, Get, Put };

struct ProcCallStmt : Stmt {
  static constexpr NK NodeKind = NK::ProcCall;
  ProcCallStmt() : Stmt(NodeKind) {}
  std::string name;
  Symbol *sym = nullptr;          // filled in by Sema, for a user procedure
  StdProc standard = StdProc::None; // set instead, for new/dispose
  std::vector<ExprPtr> args;
  /// `new(p, c1, ..., cn)`: the arms the tag values select, outermost first,
  /// as indices into the variant part at each level (ISO 7185 §6.6.5.3). Empty
  /// for the one-argument form, which allocates the whole record.
  std::vector<int> variantSelection;
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

/// One arm of a record's variant part: `labels : (fields)`. The fields are a
/// field-list like any other, so an arm may carry a variant part of its own —
/// which is the only place the type-denoter grammar is recursive without going
/// back through TypeExpr. The four tag members repeat TypeExpr's rather than
/// being factored out, because the Pascal AST is a variant record and cannot
/// share a sub-struct between two arms of it (ADR-0023).
struct VariantArm {
  std::vector<CaseLabel> labels;
  /// Extended Pascal's variant-part-completer, `otherwise (fields)`: an arm
  /// with no labels, selected by every tag value the others leave. Empty
  /// `labels` would say the same thing only in a program with no errors.
  bool isOtherwise = false;
  std::vector<FieldGroup> fields;
  std::string tagName;
  TypeExprPtr tagType;            // null when this arm has no variant part
  std::vector<VariantArm> variants;
  int tagLine = 0, tagCol = 0;
  int line = 0, col = 0;
};

enum class TEK { Named, Enum, Subrange, Array, Record, Pointer, File, Set };

/// A type-denoter: what follows ':' in a declaration or '=' in the type part.
/// Deliberately not an Expr — a type is not a value, and keeping them apart is
/// what stops `a[i]` and `array[i]` from sharing a code path.
struct TypeExpr {
  TEK kind = TEK::Named;
  int line = 0, col = 0;

  std::string name;               // Named, and the domain of a Pointer
  bool packed = false;            // Array, Record
  /// Array: one ordinal type per index. ISO 7185 §6.4.3.2 makes the index an
  /// ordinal *type*, which is why `array [1..3]` and `array [color]` are the
  /// same construct rather than two — and several of them is the `[a, b]`
  /// shorthand for an array of arrays.
  std::vector<TypeExprPtr> dims;
  TypeExprPtr elem;               // Array, File or Set: the component type
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

/// A group of parameters sharing one type-denoter and one passing mode — or,
/// when `isProc`, a single procedural or functional parameter written as a
/// heading of its own (ISO 7185 §6.6.3.1). A heading names one identifier, so
/// that form always has exactly one entry in `names` and uses `params` and
/// `returnType` in place of `type`.
struct ParamGroup {
  std::vector<DeclName> names;
  TypeExprPtr type;
  bool byRef = false; // a `var` parameter, passed by reference
  bool isProc = false;
  bool isFunction = false; // meaningful only when isProc
  std::vector<ParamGroup> params;
  TypeExprPtr returnType;
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
/// One entry of the label declaration part. ISO 7185 §6.1.6 makes a label an
/// unsigned integer of at most four digits, so the number is what identifies
/// it and there is no name to intern.
struct LabelDecl {
  int number = 0;
  int line = 0, col = 0;
};

struct Block {
  std::vector<LabelDecl> labels;
  std::vector<ConstDecl> consts;
  std::vector<TypeDecl> types;
  std::vector<VarDecl> vars;
  std::vector<std::unique_ptr<ProcDecl>> procs;
  std::unique_ptr<Compound> body;
};

struct Program {
  std::string name;
  /// The program parameters. ISO 7185 §6.10 makes these the program's only
  /// connection to the world outside it: `input` and `output` are the standard
  /// files, and every other one names a file variable the block must declare.
  /// They were accepted and ignored until text files existed to give them a
  /// meaning.
  std::vector<DeclName> params;
  std::unique_ptr<Block> block;
};

} // namespace ap
