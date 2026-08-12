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
  // ISO/IEC 10206:1991 §6.8.3.3's short-circuit operators. This compiler
  // already evaluates `and` and `or` that way (ADR-0010), so they lower
  // identically — but the standard only *permits* that for `and` and `or`
  // while *requiring* it here, and a tree that spelled both as `And` would
  // have thrown away the one fact that says which.
  AndThen, OrElse,
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
  /// ISO/IEC 10206:1991 §6.7.6.3's complex constructors and §6.7.6.2's
  /// accessors. `cmplx` and `polar` are the only way to *write* a complex
  /// value — the standard gives the type no literal — and `re`, `im` and `arg`
  /// are the only way back out to a real.
  Cmplx, Polar, Re, Im, Arg,
  /// ISO/IEC 10206:1991 §6.7.6.6's direct-access position functions and
  /// §6.7.6.5's `empty`. All three take a file variable, so they join `eof`
  /// and `eoln` in taking an *address* rather than a value.
  Position, LastPosition, Empty,
  /// ISO/IEC 10206:1991 §6.7.6.7's string functions. `Length`, `Index`,
  /// `Substr` and `Trim` are the four that answer about a string; `StrEq`
  /// through `StrGe` are the six that compare one, and are deliberately *not*
  /// the operators — §6.7.6.7's NOTE 3 points out that `LT(a,b)` may be false
  /// where `a<b` is true, because these compare lengths as well as characters
  /// and the operators pad with spaces instead.
  Length, Index, Substr, Trim,
  StrEq, StrNe, StrLt, StrGt, StrLe, StrGe,
  /// ISO/IEC 10206:1991 §6.7.6.8's `binding`, the only required function whose
  /// result is a *record*. It is given a hidden frame slot to be built in —
  /// the same mechanism a `with` binding uses — so that `binding(f).bound` and
  /// `b := binding(f)` are both ordinary designators and need no case of their
  /// own anywhere.
  Binding,
};

/// Which family a required function belongs to. These live beside the enum
/// rather than inside one pass because both Sema and CodeGen ask, and two
/// copies of the same list is exactly the duplicated dispatch this codebase
/// keeps out of its tree walks. The only question asked of a family as a whole
/// is whether the selected standard has it.
inline bool isComplexBuiltin(Builtin b) {
  return b == Builtin::Cmplx || b == Builtin::Polar || b == Builtin::Re ||
         b == Builtin::Im || b == Builtin::Arg;
}

/// §6.7.6.6's two and §6.7.6.5's one. Grouped for the same reason the complex
/// ones are: the only question anyone asks is whether this standard has them.
inline bool isFileEnquiry(Builtin b) {
  return b == Builtin::Position || b == Builtin::LastPosition ||
         b == Builtin::Empty;
}

/// §6.7.6.8's one. Grouped with the rest for the same reason: the only
/// question asked of it alone is whether this standard has it.
inline bool isBindingBuiltin(Builtin b) { return b == Builtin::Binding; }

/// §6.7.6.7's ten, grouped for the same reason as the rest: the only question
/// asked of them together is whether this standard has them.
inline bool isStringBuiltin(Builtin b) {
  return b == Builtin::Length || b == Builtin::Index || b == Builtin::Substr ||
         b == Builtin::Trim || b == Builtin::StrEq || b == Builtin::StrNe ||
         b == Builtin::StrLt || b == Builtin::StrGt || b == Builtin::StrLe ||
         b == Builtin::StrGe;
}

/// The six comparison functions of §6.7.6.7, which take two operands where
/// the other four take one or three.
inline bool isStringCompare(Builtin b) {
  return b == Builtin::StrEq || b == Builtin::StrNe || b == Builtin::StrLt ||
         b == Builtin::StrGt || b == Builtin::StrLe || b == Builtin::StrGe;
}


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
  /// ISO/IEC 10206:1991 §6.8.4's schema-discriminant, `v.n`: the base
  /// possesses a type produced from a schema and the name is one of that
  /// schema's formal discriminants. It shares its syntax with a field
  /// selection and nothing else — there is no field, and `resolved` stays
  /// null. Sema folds it to the tuple's value, which is what a discriminated
  /// type knows about itself.
  bool isDiscriminant = false;
  long long discValue = 0;
  /// ...unless the base is a *schematic formal parameter*, whose type was
  /// produced with no tuple at all: then the value arrives with the actual and
  /// this is the `Disc` symbol that reads it out of the descriptor. Exactly
  /// one of the two is how a discriminant answers.
  Symbol *discSym = nullptr;
  /// ISO/IEC 10206:1991 §6.11.3's qualified name, `i.x`: the base names an
  /// imported interface rather than a record, so the whole selection denotes
  /// one symbol and there is no base to evaluate. Sema decides which reading
  /// this is — the syntax is the same and only the *symbol* the base resolves
  /// to can tell them apart, exactly as ADR-0044's variant-selector is told
  /// from a tag-type.
  Symbol *qualified = nullptr;
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
  /// §6.11.3's qualified name in call position, `i.f(x)`. The parser can
  /// decide this one on its own: a record field is never followed by `(`, so
  /// `a.b(` has exactly one reading.
  std::string qualifier;
  Builtin builtin = Builtin::None; // filled in by Sema
  Symbol *sym = nullptr;           // set instead, for a user-defined function
  /// Where `binding(f)`'s result is built: a hidden frame variable of type
  /// `BindingType`, one per call site. §6.7.6.8 makes the result a record and
  /// this compiler returns no records, so the value needs somewhere to live —
  /// and a frame slot is somewhere both backends can name without an alloca
  /// in the middle of a function.
  Symbol *resultSlot = nullptr;
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
enum class StdProc {
  None, New, Dispose, Reset, Rewrite, Get, Put,
  /// ISO/IEC 10206:1991 §6.7.5.2's direct-access procedures. The three seeks
  /// differ only in the mode they leave the file in; `update` writes the
  /// buffer variable back without advancing; `extend` opens for writing at the
  /// end, and is the one of the five that needs no direct-access file.
  SeekRead, SeekWrite, SeekUpdate, Update, Extend,
  /// ISO/IEC 10206:1991 §6.7.5.6's binding procedures. `bind` attaches a
  /// variable to an entity outside the program and `unbind` detaches it.
  Bind, Unbind
};

struct ProcCallStmt : Stmt {
  static constexpr NK NodeKind = NK::ProcCall;
  ProcCallStmt() : Stmt(NodeKind) {}
  std::string name;
  /// §6.11.3's qualified name in a procedure-statement, `i.p`.
  std::string qualifier;
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

enum class TEK { Named, Enum, Subrange, Array, Record, Pointer, File, Set,
                 /// ISO/IEC 10206:1991 §6.4.8's discriminated-schema:
                 /// `schema-name '(' discriminant-value, ... ')'`. It is a
                 /// type-denoter like any other, and the only one whose
                 /// spelling contains expressions that are not bounds.
                 Schema,
                 /// ISO/IEC 10206:1991 §6.4.9's type-inquiry, `type of x`. It
                 /// is the only type-denoter that names a *variable*: what it
                 /// denotes is the type that variable possesses, which is why
                 /// `name` here is resolved in the ordinary scope rather than
                 /// among the types.
                 Inquiry };

/// A type-denoter: what follows ':' in a declaration or '=' in the type part.
/// Deliberately not an Expr — a type is not a value, and keeping them apart is
/// what stops `a[i]` and `array[i]` from sharing a code path.
struct TypeExpr {
  TEK kind = TEK::Named;
  int line = 0, col = 0;

  /// ISO/IEC 10206:1991 §6.6's initial-state-specifier, `value <expression>`.
  /// It belongs to the *type-denoter* (§6.4.1) rather than to the declaration,
  /// which is why it lives here and why `type count = integer value 1` gives
  /// the initial state to every variable of `count`. Null when none was
  /// written. §6.4.3.2 forbids one on a component-type and this compiler
  /// refuses it in every other nested position too, so Sema checks *where* it
  /// was written and the parser only records that it was.
  /// ISO/IEC 10206:1991 §6.4.1's `bindable`, which precedes the denoter where
  /// the initial-state-specifier follows it. A variable of a bindable type may
  /// be bound to an entity outside the program (§6.7.5.6), and §6.5.1 makes it
  /// totally-undefined until it is.
  bool bindable = false;
  ExprPtr initValue;
  /// Set by Sema when that specifier passed its checks — a value the block
  /// prologue may store. A declaration reads this rather than `initValue`, so
  /// a rejected specifier cannot reach CodeGen.
  bool initOk = false;
  /// ISO/IEC 10206:1991 §6.4.3.6: `file-type = 'file' [ '[' index-type ']' ]
  /// 'of' component-type`. "If there is an index-type in a file-type, then
  /// that file-type shall be designated a **direct-access file-type**." Null
  /// for an ordinary sequential file, which is what ISO 7185 has.
  TypeExprPtr index;

  std::string name;               // Named, and the domain of a Pointer
  /// ISO/IEC 10206:1991 §6.11.3's qualified name: the interface a type-name or
  /// schema-name arrived through, when it is written `i.t`. Empty otherwise —
  /// and there is no ambiguity to resolve here, unlike in an expression, since
  /// a type-denoter has no record to select a field of.
  std::string qualifier;
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
  /// Schema: the actual-discriminant-part. Empty for every other kind, and
  /// never empty for this one — §6.4.8's list has at least one value.
  std::vector<ExprPtr> args;

  // Record: the variant part, if there is one. `tagName` is empty when the tag
  // has no field of its own (ISO 7185 §6.4.3.3 allows `case T of`).
  std::string tagName;
  TypeExprPtr tagType;
  std::vector<VariantArm> variants;
  int tagLine = 0, tagCol = 0;

  Type *resolved = nullptr; // filled in by Sema
};

/// One `identifier-list ':' ordinal-type-name` of a formal-discriminant-part.
/// The type is a *name*, not a denoter (§6.4.7), so a discriminant cannot be
/// declared with an anonymous type — which is what keeps a schema's domain
/// something a reader can see at a glance.
struct DiscriminantGroup {
  std::vector<DeclName> names;
  std::string typeName;
  int line = 0, col = 0;
};

/// A type-definition, or — when `discriminants` is non-empty — ISO/IEC
/// 10206:1991 §6.4.7's schema-definition. The two share a node because they
/// share their whole syntax but for the formal-discriminant-part: a schema is
/// a type-definition that has not been told everything yet.
struct TypeDecl {
  std::string name;
  TypeExprPtr type;
  std::vector<DiscriminantGroup> discriminants;
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
  /// ISO/IEC 10206:1991 §6.7.3.1's `protected`. It is written before the
  /// names — and before `var` when there is one — and says that no statement
  /// of the body may *threaten* the parameter (§6.9.4). It is a rule about
  /// the body rather than about the calling convention, so nothing downstream
  /// of Sema knows it is here.
  bool isProtected = false;
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
  /// ISO/IEC 10206:1991 §6.7.2's result-variable-specification: the name the
  /// block calls its result by. Empty where none was written, which is what
  /// decides whether `f := e` is required or forbidden in the body.
  std::string resultName;
  int resultLine = 0, resultCol = 0;
  std::unique_ptr<Block> body; // null for a forward declaration
  bool isForward = false;
  /// True for a heading in a module-heading's procedure-and-function-heading-part
  /// (ISO/IEC 10206:1991 §6.11.1). It behaves exactly as `forward` does — the
  /// name and parameters are declared here and the body comes later, repeating
  /// the name alone — so only the diagnostic tells the two apart.
  bool inModuleHeading = false;
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

/// One entry of an export-list (ISO/IEC 10206:1991 §6.11.2). An export-clause
/// and an export-range share this shape: a range is the one with `last`
/// non-empty, and it may not also be renamed, because what it exports is
/// whatever *principal* identifiers the values in it already have.
struct ExportItem {
  std::string name;    // exportable-name, or the first-constant-name of a range
  /// §6.11.3's qualified name in an export-list: a module may re-export what
  /// it imported `qualified`, and then the only name it has for it is `i.x`.
  /// The standard's own example 3 (§6.11.6) does exactly this.
  std::string qualifier;
  std::string lastQualifier;
  std::string last;    // last-constant-name; empty unless this is a range
  std::string renamed; // the identifier after `=>`; empty when not renamed
  bool isProtected = false;
  int line = 0, col = 0;
};

/// `export i = (a, b => c, lo..hi)`. The identifier names an *interface*, which
/// §6.2.2.2 makes a region that "shall not be a part of the program text" —
/// so an interface is not a scope of the block that wrote it, and the only way
/// into one is an import-specification.
struct ExportPart {
  std::string name;
  std::vector<ExportItem> items;
  int line = 0, col = 0;
};

struct ImportItem {
  std::string name;    // constituent-identifier
  std::string renamed; // the identifier after `=>`; empty when not renamed
  int line = 0, col = 0;
};

/// `import i qualified only (t => u);`. The three modifiers are independent:
/// `only` says the list is exhaustive rather than a set of exceptions to
/// rename, and `qualified` says the imported names arrive *only* under
/// `i.name` and not bare (§6.11.3 NOTE 2).
struct ImportSpec {
  std::string interfaceName;
  bool qualified = false;
  bool only = false;
  bool hasList = false;
  std::vector<ImportItem> items;
  int line = 0, col = 0;
};

struct Block {
  /// §6.2.1: `block = import-part { ... } statement-part` — the import-part is
  /// first and there is at most one, in every block, not only in a module's.
  std::vector<ImportSpec> imports;
  std::vector<LabelDecl> labels;
  std::vector<ConstDecl> consts;
  std::vector<TypeDecl> types;
  std::vector<VarDecl> vars;
  std::vector<std::unique_ptr<ProcDecl>> procs;
  std::unique_ptr<Compound> body;
};

/// §6.11.1's module-declaration, in whichever of its three forms was written:
///
///   module m;              heading... end ; block... end .   both parts
///   module m interface;    heading... end .                  the heading alone
///   module m implementation;      block... end .             the block alone
///
/// The heading and the block are one module however they were split, and
/// §6.2.2.12 makes every defining-point of the heading a defining-point of the
/// block as well — so the two share one scope and one activation record.
struct ModuleDecl {
  std::string name;
  bool hasHeading = false;
  bool hasBlock = false;
  /// §6.11.1's module-parameter-list. `input` and `output` here are what make
  /// the standard files implicitly accessible in the module (§6.11.4.2 d).
  std::vector<DeclName> params;
  std::vector<ExportPart> exports;
  std::unique_ptr<Block> heading;
  std::unique_ptr<Block> block;
  /// `to begin do S;` and `to end do S;` — each one *statement*, not a
  /// compound, so the `begin` a reader expects is part of the word-symbol
  /// rather than the start of a statement.
  StmtPtr init;
  StmtPtr fini;
  int line = 0, col = 0;
  Symbol *sym = nullptr;
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
  /// §6.13's other program-components, in the order they were written. That
  /// order is also a legal *activation* order and no sort is needed to find
  /// one: §6.2.2.9 already requires a module-heading to precede everything
  /// that imports its interface, so a supplier always precedes what it
  /// supplies. Modules written after the main-program-declaration are legal
  /// and can supply nothing, since nothing before them can name their
  /// interfaces.
  std::vector<std::unique_ptr<ModuleDecl>> modules;
  /// How many of them were written before the main-program-declaration, so
  /// that the components can be checked in the order they appear.
  size_t mainIndex = 0;
};

} // namespace ap
