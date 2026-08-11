#pragma once
#include <map>
#include <memory>
#include <string>
#include <unordered_map>
#include <vector>

#include "ast.h"
#include "diag.h"
#include "token.h"
#include "type.h"

namespace ap {

enum class SymKind {
  Const,
  Type,     // a name introduced by the type part
  /// ISO/IEC 10206:1991 §6.4.7's schema: a mapping from discriminant tuples to
  /// types. Not a type — it has no values and nothing possesses it — so it is
  /// a kind of its own rather than a `Type` with a flag, and naming one where
  /// a type-denoter is wanted is an error until its discriminants are given.
  Schema,
  Var,      // a local or global variable
  Param,    // a value parameter — a local initialised from the argument
  VarParam, // a `var` parameter — the frame slot holds a pointer
  /// A procedural or functional parameter (ISO 7185 §6.6.3.1). The frame slot
  /// holds a *pair*: the code to call and the static link to call it with — the
  /// link of the block the actual procedure was declared in, not of the caller.
  /// `type` is the procedural type and `type->elem` its result, null for a
  /// procedural parameter as against a functional one.
  ProcParam,
  /// One formal discriminant of a *schematic formal parameter*, as seen from
  /// inside the block (ISO/IEC 10206:1991 §6.7.3.2). It has storage — the slot
  /// of the parameter it belongs to holds the address and then the tuple — but
  /// it is not a variable: nothing may assign to it, and it is in scope only
  /// while the parameter's type is being resolved. Afterwards `v.n` is the
  /// only way to name it, which is what §6.8.4 makes a primary.
  Disc,
  Proc,
  Func,
};

/// How a file variable reaches something outside the program. ISO 7185 §6.10
/// makes only a *program parameter* external; every other file variable is a
/// scratch file with no name, which is what `Internal` means.
enum class FileBinding { Internal, StandardInput, StandardOutput, Argument };

struct Symbol {
  std::string name;
  SymKind kind = SymKind::Var;
  Type *type = nullptr;

  // --- file variables -------------------------------------------------------
  FileBinding fileBinding = FileBinding::Internal;
  int fileArg = 0; // which command-line argument, when Argument

  // Value of a constant, in whichever field its type selects.
  long long intVal = 0;
  double realVal = 0;
  char charVal = 0;
  bool boolVal = false;

  // --- lexical position -----------------------------------------------------
  // `level` is the nesting depth: 0 for the program, 1 for a procedure declared
  // in it, and so on. For a variable it is the depth of the block that declares
  // it, and `owner`/`frameIndex` say which activation record holds it and where.
  int level = 0;
  int frameIndex = -1;
  Symbol *owner = nullptr; // the procedure whose frame holds this variable

  // --- procedures and functions --------------------------------------------
  std::vector<Symbol *> params;
  std::vector<Symbol *> frameVars; // everything this procedure's frame holds
  Symbol *resultVar = nullptr;     // where a function's result is accumulated
  bool defined = false;            // a body has been seen (vs. only `forward`)
  ProcDecl *decl = nullptr;

  /// The ids of this block's labels that a `goto` in a *nested* block jumps
  /// to. Non-empty means the activation record carries a jump record after the
  /// frame variables, and the prologue arms it and dispatches on it — so this
  /// is the one thing about a block that its own statements do not decide
  /// (ADR-0032). The ids are in declaration order and never repeat.
  std::vector<int> nonLocalLabels;

  // --- schemata (ISO/IEC 10206:1991 §6.4.7) ---------------------------------
  /// The type-denoter a schema produces its types from. Re-resolved once per
  /// distinct discriminant tuple, with the discriminants bound to that
  /// tuple's values — which is why a schema keeps its *syntax* and not a type.
  TypeExpr *schemaBody = nullptr;
  /// The formal discriminants, in order. Each carries only a name and an
  /// ordinal type; they get their values when a type is produced.
  std::vector<Symbol *> discriminants;
  /// ISO/IEC 10206:1991 §6.4.3.3.3's *required* schema `string`. It has no
  /// body: what it produces is a variable-string-type, whose representation
  /// the compiler fixes rather than the program's text. The flag is what tells
  /// `produceFromSchema` to build one instead of resolving a denoter.
  bool isStringSchema = false;

  // --- schematic formal parameters (§6.7.3.2, §6.7.3.3) --------------------
  /// The schema a formal parameter was written as the bare name of. Its type
  /// is then produced *generically*: the discriminants become `Disc` symbols
  /// reading this parameter's descriptor rather than constants, so one body
  /// serves every tuple an actual may bring. Null for every ordinary
  /// parameter, and it is what decides the shape the parameter travels in.
  /// ...and, since ADR-0041, of a *variable* whose actual-discriminant-part is
  /// not constant: §6.2.3.2 evaluates one when the block is entered, so such a
  /// variable holds the same descriptor a parameter does and differs only in
  /// where the tuple comes from.
  Symbol *descSchema = nullptr;
  /// The `Disc` symbols of this parameter, in the schema's own order. Their
  /// storage is inside this parameter's frame slot, after the address.
  std::vector<Symbol *> discSyms;
  /// The actual-discriminant-part of a variable whose discriminants are not
  /// constants, in order — the expressions the prologue evaluates on entry.
  /// Empty for a schematic formal parameter, whose tuple the caller brings,
  /// which is what tells the two apart wherever it matters.
  std::vector<Expr *> discExprs;
  /// Which discriminant of `owner`'s parameter this is, for a `Disc`.
  int discIndex = -1;
  /// A `Disc` whose storage is not in any activation record: the tuple of a
  /// variable created by `new` lives in a header immediately before it, so
  /// this one is read from the object's own address rather than by walking
  /// the static chain. §6.4.4's domain-type may be a schema-name, and a heap
  /// variable has no frame to keep a descriptor in (ADR-0043).
  bool heapDisc = false;
  /// This symbol is a schema's discriminant, bound for as long as the body is
  /// being resolved — a `Const` in a production with a tuple and a `Disc` in a
  /// generic one. Both forms answer §6.4.3.4's question "is this name in the
  /// variant-selector a discriminant-identifier?", which the *kind* cannot,
  /// because an ordinary constant is also a `Const` and is not one.
  bool discBinding = false;
  /// Which formal-parameter-section declared this parameter. §6.7.3.3 requires
  /// every actual in one section to bring the same tuple, so the section has
  /// to be recoverable at the call.
  int paramSection = 0;
  /// ISO/IEC 10206:1991 §6.6: the value this variable bears when the block
  /// that declares it is entered. Borrowed from the AST, and read only by the
  /// prologue — every expression in one is nonvarying (§6.8.2), so CodeGen
  /// emits it as the constant it is rather than re-evaluating anything.
  Expr *initValue = nullptr;
  /// ISO/IEC 10206:1991 §6.7.3.1's `protected`: no statement of the body may
  /// *threaten* this parameter (§6.9.4). It says nothing about how the
  /// argument travels — a protected `var` parameter is still an address — so
  /// it is a Sema-only property and CodeGen never reads it. It also rides on
  /// the hidden binding a `with` makes, because §6.5.1 asks about the
  /// variable-access's *closest-containing* variable-identifier and a `with`
  /// is where that name stops being written down.
  bool isProtected = false;

  bool isCallable() const {
    return kind == SymKind::Proc || kind == SymKind::Func;
  }
  bool isVariable() const {
    return kind == SymKind::Var || kind == SymKind::Param ||
           kind == SymKind::VarParam;
  }
  /// Anything a call statement or a function call may name. A procedural
  /// parameter is not `isCallable()` — that asks whether this symbol *has* a
  /// body, which is what forward declarations and duplicate checks want.
  bool isInvocable() const {
    return isCallable() || kind == SymKind::ProcParam;
  }
  /// The result type of an invocable, null when it is a procedure. A function
  /// keeps its result in `type`; a functional parameter keeps the procedural
  /// type there and the result one level in.
  Type *resultType() const {
    if (kind == SymKind::ProcParam)
      return type ? type->elem : nullptr;
    return kind == SymKind::Func ? type : nullptr;
  }
};

/// Name resolution and type checking. Every VarRef comes out pointing at a
/// Symbol and every Expr comes out with a non-null type, so codegen never has
/// to ask questions about the source program.
class Sema {
public:
  /// The standard decides two things here, and both are about *identifiers*
  /// rather than word-symbols: whether `complex` denotes a type, and whether
  /// the five complex functions are required ones. Neither name is reserved in
  /// either language — a valid ISO 7185 program may declare a function called
  /// `re` — so this is not a lexical question and the lexer cannot answer it.
  explicit Sema(Diagnostics &diags, Std std = Std::Iso7185)
      : diags_(diags), std_(std) {}

  void run(Program &prog);

  /// The synthetic symbol standing for the program itself, whose frame holds
  /// the global variables. Codegen needs it to lay out `main`.
  Symbol *programSymbol() const { return program_; }

private:
  void installPredefined();
  Symbol *declare(const std::string &name, SymKind kind, int line, int col);
  Symbol *lookup(const std::string &name) const;
  Symbol *newSymbol();

  void pushScope() { scopes_.emplace_back(); }
  void popScope() { scopes_.pop_back(); }

  void checkBlock(Block &block, Symbol *owner);
  void declareProcHeading(ProcDecl &decl, Symbol *owner);
  void checkProcBody(ProcDecl &decl);
  Symbol *addFrameVar(const std::string &name, SymKind kind, Type *type,
                      Symbol *owner, int line, int col);
  /// A frame slot with no name in any scope — a function result or a `with`
  /// binding. It is still an ordinary frame variable, so recursion works.
  Symbol *addHiddenVar(const std::string &name, SymKind kind, Type *type,
                       Symbol *owner);

  // --- types ---------------------------------------------------------------
  Type *newType(TypeKind kind);
  /// Turn a type-denoter into a Type, reporting anything it cannot make sense
  /// of. Never returns null: on error it yields integer so checking continues.
  Type *resolveType(TypeExpr &denoter);
  /// §6.4.7's schema-definition: a name, its formal discriminants, and the
  /// body kept unresolved until a tuple arrives.
  void declareSchema(TypeDecl &decl);
  /// §6.4.8: the type this schema maps the given actual-discriminant-part to.
  /// Interned, because §6.4.8 makes one tuple denote one type however many
  /// times it is written.
  Type *produceFromSchema(Symbol *schema, TypeExpr &denoter);
  /// §6.7.3.2/§6.7.3.3's parameter-form written as a bare schema-name: the
  /// body resolved once, with the discriminants bound to `param`'s descriptor
  /// instead of to values. The result belongs to that one parameter, so it is
  /// deliberately *not* interned — two parameters read two descriptors.
  Type *schematicFormal(Symbol *schema, Symbol *param, TypeExpr &denoter);
  /// The schema body resolved with its discriminants bound to `owner`'s
  /// descriptor rather than to values: what a schematic formal parameter and a
  /// variable with non-constant discriminants both need, differing only in the
  /// noun a diagnostic calls them.
  Type *genericFromSchema(Symbol *schema, Symbol *owner, TypeExpr &denoter,
                          const char *noun);
  /// A bound inside a schema body being resolved generically: a constant, a
  /// discriminant, or a discriminant with a constant added to or taken from
  /// it. Anything else is refused, because a bound is re-evaluated on entry
  /// and this is the whole of what the descriptor can answer.
  bool evalBound(Expr *e, Type *&type, long long &value, Symbol *&disc);
  /// True when nothing inside this type depends on a discriminant. Arrays are
  /// where a dynamic bound is allowed; this asks about everywhere else.
  bool staticThroughout(Type *t) const;
  bool staticVariants(const std::vector<Variant> &arms) const;
  Type *resolveArray(TypeExpr &denoter, size_t dim);
  Type *resolveRecord(TypeExpr &denoter);
  Type *resolveEnum(TypeExpr &denoter);
  Type *resolveSubrange(TypeExpr &denoter);
  Type *resolvePointer(TypeExpr &denoter);
  /// §6.4.4's domain-type written as a schema-name. One type per schema, so a
  /// schema that names itself in a pointer domain terminates.
  Type *heapFromSchema(Symbol *schema, TypeExpr &denoter);
  Type *resolveFile(TypeExpr &denoter);
  Type *resolveSet(TypeExpr &denoter);
  /// Fill in the domains of pointers that named a type not yet defined, and
  /// report any that never were. Run at the end of each type part.
  void resolvePendingPointers();
  /// Resolve one variant part — a record's, or one nested inside an arm. The
  /// containers are passed explicitly because both a Type and a Variant have
  /// them, and `path` says where the container sits so a field can record how
  /// to reach it (ISO 7185 §6.4.3.3 allows any depth of nesting).
  void resolveVariantPart(const std::string &tagName, TypeExpr *tagDenoter,
                          std::vector<VariantArm> &arms, int tagLine,
                          int tagCol, Type *record, std::vector<Field> &fields,
                          std::vector<Variant> &variants, int &tagField,
                          Type *&tagTypeOut, bool &discSelOut,
                          std::vector<int> &path);
  /// Whether a schema body is a type a descriptor can describe: its size may
  /// depend on the discriminants, but every offset inside it must not.
  bool dynamicTail(Type *t) const;
  /// The discriminant a variant-selector names, or null when it names a type.
  Symbol *discSelectorFor(TypeExpr *denoter);
  /// Add a field to `into`, reporting a name already used anywhere in `record`.
  void addField(Type *record, std::vector<Field> &into, const DeclName &name,
                Type *type, const std::vector<int> &variant,
                Expr *init = nullptr);
  /// The `packed array [1..n] of char` that ISO 7185 §6.4.3.2 gives a string
  /// literal. Cached by length so two literals of a length share one type.
  Type *stringType(long long length);
  /// Evaluate a constant that must be ordinal — a subrange bound, a case
  /// label, a variant's tag value. Reports the type it was written as, so a
  /// mismatch can be named rather than silently coerced.
  bool evalOrdinal(Expr *e, Type *&type, long long &value);
  /// One entry of a case-constant-list, folded to the interval it denotes: a
  /// single constant is [v, v], and Extended Pascal's `lo..hi` is the general
  /// case. Both the case statement and a variant part read their labels
  /// through this, so a range is legal in either without a second rule.
  bool evalLabelRange(CaseLabel &label, const char *constantMsg, Type *&type,
                      LabelRange &r);
  /// The lowest value a new label shares with the ones already accepted, if
  /// any — the general form of "this label appears twice".
  static bool overlaps(const std::vector<LabelRange> &seen, LabelRange r,
                       long long &at);

  /// Give the program parameters their meaning: `input` and `output` are the
  /// standard files, and every other one must be a file variable the program
  /// block declares, bound to a command-line argument.
  void bindProgramParameters();
  /// A reference to `input` or `output` for a read or write that named no
  /// file. Reports if that parameter was not declared, because ISO 7185 §6.10
  /// makes using a standard file without listing it an error.
  ExprPtr standardFileRef(bool input, int line, int col);

  void checkStmt(Stmt *s);
  void checkWrite(WriteStmt *w);
  void checkRead(ReadStmt *r);
  void checkExpr(Expr *e);
  void checkBinary(Binary *b);
  void checkSetExpr(SetExpr *s);
  void checkCall(Call *c);
  void checkWith(WithStmt *w);
  void checkCase(CaseStmt *c);
  /// `new` and `dispose`, which are procedures rather than functions and so
  /// never reach checkCall.
  static bool isDirectAccessProc(const std::string &name);
  void checkStdProc(ProcCallStmt *p);
  void checkArguments(Symbol *callee, std::vector<ExprPtr> &args, int line,
                      int col);
  /// Build the parameter symbols of one formal parameter list. They are
  /// descriptors rather than variables — a procedural parameter's own
  /// parameters live in the frame of whatever procedure is eventually passed,
  /// not in any frame here — so they get no slot and `frame` is null for them.
  void buildFormals(std::vector<ParamGroup> &groups, Symbol *into,
                    Symbol *frame);
  /// ISO 7185 §6.6.3.6: two parameter lists are *congruous* when they have the
  /// same number of parameters and each corresponding pair is passed the same
  /// way and has the same type — recursively, for a procedural parameter of a
  /// procedural parameter. Note "the same type", not "assignment compatible":
  /// nothing is converted on the way through a procedural parameter.
  bool congruous(Symbol *formal, Symbol *actual) const;
  /// Bind the actual parameter of a procedural or functional parameter. It is
  /// a procedure *identifier* rather than an expression, so it is resolved
  /// here instead of through checkExpr — which would read `f` as a call.
  void checkProcArgument(Symbol *formal, Expr *a, Symbol *callee, size_t at);
  bool evalConst(Expr *e, Symbol &out);

  /// True if `e` denotes a variable — a name, or one with subscripts and
  /// fields applied. Assignment targets and `var` arguments must be one.
  bool isDesignator(Expr *e) const;
  /// The variable a designator ultimately reaches into, or null.
  Symbol *baseSymbol(Expr *e) const;
  Type *resolveInquiry(TypeExpr &denoter);
  /// ISO/IEC 10206:1991 §6.6's initial-state-specifier, checked and folded.
  bool nonvarying(Expr *e) const;
  void checkInitialState(TypeExpr &denoter, Type *t);
  Expr *initialStateOf(TypeExpr &denoter);
  /// True while a field of a *variant part* is being resolved, where §6.5.1
  /// makes the initial state conditional on the selector. There is no flag for
  /// "this position admits a specifier at all": the parser settles that, by
  /// stopping before the word everywhere but the three positions that do.
  bool variantField_ = false;
  /// ...and true while a *schema body* is being resolved. §6.4.7 makes one a
  /// type-denoter, so the word parses there, and it is spelled as a type
  /// definition — so refusing it needs a reason of its own.
  bool schemaBody_ = false;
  void checkNotThreatened(Expr *e, const std::string &what);

  /// True if a value of `from` may be assigned to / compared with `to`.
  bool assignable(Type *to, Type *from) const;

  /// The field of an enclosing `with` this name refers to, if any.
  Symbol *lookupWithField(const std::string &name, const Field *&field) const;

  /// One label of one block's label declaration part. ISO 7185 §6.1.6 makes a
  /// label a number rather than a name, so it is not a Symbol and does not go
  /// in a scope: two blocks may both declare label 1, and each means its own.
  ///
  /// `path` is the chain of statements that contain the labelled one, which is
  /// what §6.8.1's restriction is stated over — a goto may reach a label only
  /// when every statement containing the label also contains the goto. A label
  /// at the top of a block's statement part has an empty path, and that is
  /// also the only kind a goto from a *nested block* may reach.
  struct LabelInfo {
    int number = 0;
    int id = -1;
    bool defined = false;
    int line = 0, col = 0;
    int defLine = 0, defCol = 0;
    std::vector<Stmt *> path;
    Symbol *owner = nullptr;
  };
  /// A goto whose target is not resolved until the whole block has been
  /// walked: a label may be declared before the statement it labels appears,
  /// so a forward jump cannot be checked where it is written.
  struct PendingGoto {
    GotoStmt *node = nullptr;
    std::vector<Stmt *> path;
    /// True once the goto has been handed outwards because its label belongs
    /// to an enclosing block. The hand-off is what makes the diagnostic
    /// right: a nested procedure's body is checked *before* the statements of
    /// the block containing it, so at the time the goto is written the label
    /// it targets has not been seen yet and looks undeclared.
    bool fromInnerBlock = false;
  };

  void checkLabelPart(Block &block, Symbol *owner);
  void resolveGotos();
  void checkGoto(GotoStmt *g);
  void checkLabeled(LabeledStmt *l);

  /// A pointer type whose domain named a type not yet defined. ISO 7185
  /// §6.4.4 allows exactly this, and it is the only forward reference in the
  /// language — without it no type could contain a pointer to itself.
  struct PendingPointer {
    Type *pointer;
    std::string domain;
    int line = 0, col = 0;
    /// Set when the domain is a schema that was still being produced: the
    /// recursion §6.4.7 permits in a pointer domain, which cannot be resolved
    /// until that production has finished and can be memoised.
    Symbol *schema = nullptr;
  };
  /// §6.4.4's schema domains, one type per schema. Not the intern table of
  /// ADR-0039: that is keyed by (schema, tuple) and these have no tuple.
  std::map<Symbol *, Type *> heapSchemaTypes_;

  Diagnostics &diags_;
  Std std_;
  std::vector<std::unique_ptr<Symbol>> owned_;
  std::vector<std::unique_ptr<Type>> types_;
  std::vector<PendingPointer> pendingPointers_;
  std::unordered_map<long long, Type *> stringTypes_;
  std::vector<std::unordered_map<std::string, Symbol *>> scopes_;
  /// Every type produced from a schema, keyed by the schema and the tuple.
  /// §6.4.8 says a type produced with one tuple is distinct from one produced
  /// with any other and from every type of any other schema — so this map is
  /// the whole of that rule, and `assignable` needs no case for schemata.
  std::map<std::pair<Symbol *, std::vector<long long>>, Type *> produced_;
  /// The variable a discriminated schema is being resolved for, while it is.
  /// §6.2.3.2 allows a discriminant that is not a constant *there* and nowhere
  /// else, so this is what separates `var s: vector(n)` from every other
  /// position the same denoter could have been written in.
  Symbol *dynamicVarFor_ = nullptr;
  /// The schemata whose bodies are being resolved right now. §6.4.7 forbids a
  /// schema-definition from containing an applied occurrence of its own
  /// identifier anywhere but the domain of a pointer, and this is that rule:
  /// without it the production recurses until the stack runs out.
  std::vector<Symbol *> producing_;
  /// Non-null while a schema body is being resolved *generically*, for the
  /// schematic formal parameter it belongs to. It is what tells the subrange
  /// resolver that a bound naming a discriminant is a bound and not a mistake.
  Symbol *genericFor_ = nullptr;
  /// The bindings of the `with` statements currently open, innermost last.
  std::vector<Symbol *> withStack_;
  /// The label declaration parts of the blocks currently open, innermost last,
  /// and the gotos of the innermost one waiting for its statements to be
  /// walked. `stmtPath_` is the statements containing the one being checked.
  std::vector<std::vector<LabelInfo>> labelScopes_;
  std::vector<std::vector<PendingGoto>> gotoScopes_;
  std::vector<Stmt *> stmtPath_;
  int nextLabelId_ = 0;
  Symbol *program_ = nullptr;
  Symbol *current_ = nullptr; // the procedure whose body is being checked
  Program *prog_ = nullptr;   // for the parameter list, while the program is checked
  /// The standard files, when the program parameters name them.
  Symbol *stdInput_ = nullptr;
  Symbol *stdOutput_ = nullptr;
};

} // namespace ap
