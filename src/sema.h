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
  /// An *imported-interface-identifier* (ISO/IEC 10206:1991 §6.11.3). It is
  /// not a value, a type or anything callable — its whole job is to be the
  /// left half of `i.x`, which is the only way to reach a constituent of an
  /// interface imported `qualified`.
  Interface,
  /// A required *function*. ISO 7185 §6.2.2.10 puts its defining-point in "a
  /// region enclosing the program", so it is a symbol in the outermost scope
  /// and a program declaring one of the same name hides it. It is a *marker*
  /// and nothing else: `isInvocable` is false for it, `resultType` answers
  /// null, and `lookupUser` turns it back into the null every caller here
  /// reads as "the required one". A real `Func` would send `abs` through
  /// `checkArguments`, which has no parameter list to check it against. What
  /// the symbol buys is a place for §6.2.2.9's applied occurrence to be
  /// recorded (ADR-0097).
  ///
  /// Appended rather than placed where it reads best, for the reason ADR-0059
  /// gives a builtin's enumerator: where a name sits in this list is an
  /// interface between the two compilers' dumps.
  Required,
};

/// How a file variable reaches something outside the program. ISO 7185 §6.10
/// makes only a *program parameter* external; every other file variable is a
/// scratch file with no name, which is what `Internal` means.
enum class FileBinding { Internal, StandardInput, StandardOutput, Argument };

struct Symbol;

/// One name an interface makes available (ISO/IEC 10206:1991 §6.11.2). The
/// spelling is what an importer writes and is not the symbol's own name, since
/// either end may rename it.
struct Constituent {
  std::string name;
  Symbol *sym = nullptr;
  /// §6.11.2: `protected` in the export-clause, or a variable-name that was
  /// already protected. It travels with the *constituent* rather than with the
  /// symbol, because the module that exported it may still write to it.
  bool isProtected = false;
};

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
  /// ...unless the value does not fit in a field. ISO 7185 §6.3 makes a
  /// `character-string` a constant, and a string has no scalar form — so such
  /// a constant is *its defining expression, named*, and this is that node.
  /// The same shape `Symbol::initValue` gives §6.6's initial state: Sema holds
  /// the tree and CodeGen emits it where the value is needed (ADR-0068).
  Expr *constValue = nullptr;
  /// This symbol is a `with` binding over a §6.8.8 constant-access, so the
  /// field-identifiers it introduces are §6.9.3.10's constant-field-
  /// identifiers: they denote values, and nothing may threaten one.
  bool isConstBinding = false;

  // --- lexical position -----------------------------------------------------
  // `level` is the nesting depth: 0 for the program, 1 for a procedure declared
  // in it, and so on. For a variable it is the depth of the block that declares
  // it, and `owner`/`frameIndex` say which activation record holds it and where.
  int level = 0;
  int frameIndex = -1;
  Symbol *owner = nullptr; // the procedure whose frame holds this variable
  /// ...unless the storage belongs to another program-component (§6.13). An
  /// activation record's layout is a private fact of the translation that
  /// built it, so a frame index cannot cross a component boundary and a *name*
  /// must: this is the linkage name of the storage, and `owner`/`frameIndex`
  /// say nothing when it is set. Sema decides it — CodeGen only emits it, as
  /// with `activeModules()` (ADR-0008).
  std::string linkName;
  /// ...and whether the storage that name denotes is defined by *another*
  /// component. Both ends compute the same `linkName`; this is which end this
  /// is. Where it is false the name is exported beside the frame slot, where
  /// it is true nothing but the name is known.
  bool storageElsewhere = false;

  // --- procedures and functions --------------------------------------------
  std::vector<Symbol *> params;
  std::vector<Symbol *> frameVars; // everything this procedure's frame holds
  /// The constants this block defined whose value is a §6.8.7 constructor,
  /// in definition order. They have storage rather than a frame slot, and
  /// the prologue fills it (ADR-0069).
  std::vector<Symbol *> memoryConsts;
  Symbol *resultVar = nullptr;     // where a function's result is accumulated
  /// ISO/IEC 10206:1991 §6.7.2: a result-variable-specification was written,
  /// so the body names the result and must *not* assign to the function
  /// identifier. Without one the body must assign to it at least once — the
  /// two rules are exclusive, which is why one flag answers both.
  bool resultNamed = false;
  /// The result type was refused, so `never assigns its result` is suppressed:
  /// the body cannot assign a type the heading does not have, and one mistake
  /// deserves one message.
  bool resultTypeBad = false;
  /// The body contains an assignment whose target is the function identifier.
  /// Syntactic containment, as the standard states it: an assignment inside an
  /// `if` counts, because §6.6.2 asks what the block *contains*.
  bool assignedResult = false;
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
  /// ISO/IEC 10206:1991 §6.4.1's `bindable`. §6.7.5.6 makes it a
  /// dynamic-violation to `bind` a file variable that is not one, and §6.5.1
  /// makes such a variable totally-undefined until it is bound — so this is
  /// the one property of a variable that says something about the world
  /// outside the program.
  bool isBindable = false;
  /// ISO/IEC 10206:1991 §6.7.3.1's `protected`: no statement of the body may
  /// *threaten* this parameter (§6.9.4). It says nothing about how the
  /// argument travels — a protected `var` parameter is still an address — so
  /// it is a Sema-only property and CodeGen never reads it. It also rides on
  /// the hidden binding a `with` makes, because §6.5.1 asks about the
  /// variable-access's *closest-containing* variable-identifier and a `with`
  /// is where that name stops being written down.
  bool isProtected = false;

  /// ISO 7185 §6.2.2.9: "The defining-point of an identifier or label shall
  /// precede all applied occurrences of that identifier or label contained by
  /// the program-block". This is when the symbol was last *applied*, on a
  /// counter that only goes up, and `Sema::scopeMark_[d]` is that counter when
  /// the block at depth d was entered — so "applied inside the block being
  /// declared into" is one comparison. The *latest* application is enough: the
  /// check runs at a defining-point, so nothing later has happened yet, and if
  /// the newest application is not inside this block then none is (ADR-0088).
  int usedSeq = 0;

  /// §6.11.1's module. It is a `Proc` because it owns an activation record and
  /// procedures nest inside it exactly as they nest inside the program — but
  /// it is never called, and it has exactly one activation, which is what lets
  /// its frame be a global (ADR-0053).
  bool isModuleSym = false;
  /// ISO/IEC 10206:1991 §6.11.4.2: whether the required text file is
  /// *implicitly accessible* in this level-0 block. It is a property of the
  /// block and not of the program — a module that neither lists `output` as a
  /// module-parameter nor imports `StandardOutput` may not write, however many
  /// other blocks do.
  bool stdInputOk = false;
  bool stdOutputOk = false;
  /// The constituents an imported-interface-identifier makes reachable as
  /// `i.x`. Only a symbol of kind `Interface` has any.
  std::vector<Constituent> constituents;
  /// The modules whose interfaces this block imports, directly. §6.2.2.13's
  /// "supplies" is the transitive closure of this, and the program's copy is
  /// what decides which modules are activated at all.
  std::vector<Symbol *> importedFrom;
  /// This module's own program-component was translated separately (§6.13), so
  /// this translation has its heading and not its block: no body of its is
  /// emitted, its activation record is declared rather than defined, and every
  /// name of its that is reached from here is reached by `linkName`.
  bool compiledElsewhere = false;

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

  /// §6.2.3.6: the modules that supply the main-program-block, in the order
  /// their activations must commence. That order is the order they were
  /// written in, and no sort produced it — §6.2.2.9 already requires a
  /// module-heading to precede everything importing its interface, so a
  /// supplier is always textually earlier than what it supplies.
  const std::vector<Symbol *> &activeModules() const { return active_; }

  /// Which standard the source was compiled for — the second whole-program
  /// answer Sema hands over, after `activeModules`. CodeGen needs it for one
  /// thing only: §6.9.3.1 and §6.10.3.1 give a write-parameter's field width
  /// different least values, and the check is emitted rather than made in the
  /// runtime, which is never told which language it was compiled for.
  Std std() const { return std_; }

private:
  void installPredefined();
  Symbol *declare(const std::string &name, SymKind kind, int line, int col);
  /// Innermost-first lookup, recording nothing. This is the one to ask when
  /// the question is whether a name is *taken* — `declare` itself, and the two
  /// places that resolve a name before its meaning is settled.
  Symbol *lookupRaw(const std::string &name) const;
  /// The same search, recording that the name was *applied* here — which is
  /// ISO 7185 §6.2.2.8's word for an occurrence that is not the defining one.
  ///
  /// Split from `lookupRaw` rather than given a flag because the two callers
  /// want different things and neither should have to say so: every resolution
  /// of a name written in the program goes through here, and the places that
  /// ask whether a name is taken go through the other. Asking the second
  /// question through the first would record an applied occurrence for a
  /// defining one and refuse every redeclaration in the language (ADR-0088).
  Symbol *lookup(const std::string &name);
  /// `lookup`, with a required *function* answering null — the convention
  /// every caller that asks "did the program declare one of its own?" was
  /// written against, back when a required identifier was not a symbol at all
  /// (ADR-0097). The occurrence is still recorded by `lookup`, which is what
  /// §6.2.2.9 needs and what the marker symbol exists for.
  Symbol *lookupUser(const std::string &name);
  Symbol *newSymbol();

  void pushScope() {
    scopes_.emplace_back();
    scopeMark_.push_back(applySeq_);
  }
  void popScope() {
    scopes_.pop_back();
    scopeMark_.pop_back();
  }

  // --- modules (ISO/IEC 10206:1991 §6.11) -----------------------------------
  /// §6.2.2.2 makes an interface a region that "shall not be a part of the
  /// program text and shall be disjoint from every other interface" — so it is
  /// not a scope of the module that wrote it, and one table serves the whole
  /// program-block.
  struct Interface {
    std::string name;
    Symbol *module = nullptr;
    std::vector<Constituent> items;
  };
  /// A module's heading and its block may be two separate program-components,
  /// so the scope the heading built has to survive until the block arrives —
  /// §6.2.2.12 makes every defining-point of the heading one of the block's.
  struct ModuleInfo {
    Symbol *sym = nullptr;
    std::unordered_map<std::string, Symbol *> scope;
    bool headingSeen = false;
    bool blockSeen = false;
    /// The components that carried each half, so a later check can name the
    /// headings still waiting for a body and the two `to` parts, even when the
    /// two halves were written apart.
    ModuleDecl *headingDecl = nullptr;
    ModuleDecl *blockDecl = nullptr;
    int line = 0, col = 0;
  };
  void checkModule(ModuleDecl &m);
  void checkModuleHeading(ModuleDecl &m, ModuleInfo &info);
  void checkModuleBlock(ModuleDecl &m, ModuleInfo &info);
  void checkExports(ModuleDecl &m, Symbol *module);
  /// The linkage name of every constituent of one interface (§6.13).
  void nameForLinkage(Interface &iface);
  /// §6.11.1's headings still waiting for a block, less the ones §6.13 excuses.
  void checkPendingImplementations();
  void addExportItem(Interface &iface, const ExportItem &item);
  /// The import-part of a block, a module-heading or a module-block. `owner`
  /// is the block the names arrive in, and is what records who supplies it.
  void checkImports(const std::vector<ImportSpec> &specs, Symbol *owner);
  /// The imported form of a constituent. A variable is *copied* — same owner,
  /// level and frame index, so it names the same storage — because the
  /// importer's spelling and its protection are properties of the import and
  /// not of the module's own declaration. Everything else is shared.
  Symbol *importedSymbol(const Constituent &c, const std::string &spelling,
                         int line, int col);
  void installRequiredInterfaces();
  /// Which modules supply the main-program-block, in the order their
  /// activations must commence (§6.2.3.6). Only those are activated, and that
  /// matters rather than being a nicety: an unactivated module's
  /// initialization-part could otherwise write to `output`. Written order is
  /// already a legal activation order, because §6.2.2.9 requires a supplier to
  /// come first — so no sort produced this. Run once, after the whole program
  /// is walked; `activeModules()` is what CodeGen reads (ADR-0053).
  void computeActiveModules();
  /// The modules a block's imports reach, directly or through another module —
  /// §6.2.2.13's "supplies", read backwards.
  std::vector<Symbol *> suppliersOf(Symbol *block) const;
  /// §6.11.1: two modules may supply each other only through a **split**
  /// module, and neither part may then carry an initialization- or
  /// finalization-part — there being no order in which both could commence.
  /// The one rule here enforced by a reachability check rather than by the
  /// order the text is written in (ADR-0053).
  void checkMutualSupply();
  /// Whether a name denotes an imported interface. It is what tells a
  /// qualified name from an ordinary field selection, and it is a question
  /// about the *symbol* — the syntax of the two is identical.
  bool isInterfaceName(const std::string &name);
  Symbol *lookupQuiet(const std::string &qualifier, const std::string &name);
  Symbol *lookupName(const std::string &qualifier, const std::string &name,
                     int line, int col);

  void checkBlock(Block &block, Symbol *owner);
  void checkDeclarations(Block &block, Symbol *owner);
  void checkConstDecl(ConstDecl &c, Symbol *owner);
  void checkTypeDecl(TypeDecl &t);
  void checkVarDecl(VarDecl &group, Symbol *owner);
  void declareProcHeading(ProcDecl &decl, Symbol *owner);
  void checkProcBody(ProcDecl &decl);
  Symbol *addFrameVar(const std::string &name, SymKind kind, Type *type,
                      Symbol *owner, int line, int col);
  /// A frame slot with no name in any scope — a function result or a `with`
  /// binding. It is still an ordinary frame variable, so recursion works.
  Symbol *addHiddenVar(const std::string &name, SymKind kind, Type *type,
                       Symbol *owner);
  /// Put an existing symbol into the current scope under a spelling. An
  /// import does this, and so does a program or module parameter naming a
  /// required text file — in each case the symbol was made elsewhere.
  void bindName(const std::string &name, Symbol *sym, int line = 0,
                int col = 0);
  Symbol *ensureStdFile(bool input);

  // --- types ---------------------------------------------------------------
  Type *newType(TypeKind kind);
  /// Turn a type-denoter into a Type, reporting anything it cannot make sense
  /// of. Never returns null: on error it yields integer so checking continues.
  Type *resolveType(TypeExpr &denoter);
  /// What §6.6.2 / §6.7.2 let a function return; `ty::Int()` on refusal, so a
  /// half-checked heading still hands codegen a type.
  Type *checkedResultType(Type *t, bool bindable, int line, int col);
  /// Hidden caller-side storage for a result that lives in memory.
  void giveResultSlot(Call *c);
  Symbol *newResultSlot(Type *t);
  /// §6.4.7's schema-definition: a name, its formal discriminants, and the
  /// body kept unresolved until a tuple arrives.
  void declareSchema(TypeDecl &decl);
  void checkSchemaBodyNames(TypeExpr *d, Symbol *self);
  StmtPtr redefinedFamily(const std::string &name, std::vector<ExprPtr> args,
                          int line, int col);
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
  /// §6.4.3.3.3's `string(cap)`, interned by (schema, tuple) as §6.4.8
  /// requires. The one way such a type is made, so that the field
  /// `BindingType` gives a variable-string-type is the *same* type as the one
  /// a program writes.
  Type *stringOfCapacity(int cap);
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
  static long long ordinalOf(const Symbol &v);
  bool evalOrdinal(Expr *e, Type *&type, long long &value);
  Expr *constAccessNode(Expr *e);
  /// §6.8.7's structured-value-constructor. One node covers the array-value
  /// and the record-value alike, because which one a bracketed value is
  /// cannot be known until the type-name is resolved.
  void checkStructValue(StructValueExpr *e, Type *want);
  void checkComponentValue(Expr *v, Type *component, const char *what);
  void checkArrayValue(StructValueExpr *e, Type *t);
  void checkRecordValue(StructValueExpr *e, Type *t,
                        const std::vector<int> &path);
  void checkVariantPartValue(StructValueExpr *e, Type *t,
                             const std::vector<int> &path,
                             const std::vector<Variant> &arms,
                             const std::vector<Field> &fields, int tagField);
  /// One entry of a case-constant-list, folded to the interval it denotes: a
  /// single constant is [v, v], and Extended Pascal's `lo..hi` is the general
  /// case. The case statement, a variant part and §6.8.7.2's array-value all
  /// read their labels through this, so a range is legal in each without a
  /// second rule.
  bool evalLabelRange(CaseLabel &label, const char *constantMsg, Type *&type,
                      LabelRange &r);
  /// The lowest value a new label shares with the ones already accepted, if
  /// any — the general form of "this label appears twice".
  static bool overlaps(const std::vector<LabelRange> &seen, LabelRange r,
                       long long &at);

  /// Give the program parameters their meaning. Each must be a variable the
  /// program block declares (§6.10); `input` and `output` are the standard
  /// files, one possessing a file-type is bound to a command-line argument in
  /// the order written, and one that does not is bound to nothing.
  void bindProgramParameters();
  /// A reference to `input` or `output` for a read or write that named no
  /// file. Reports if that parameter was not declared, because ISO 7185 §6.10
  /// makes using a standard file without listing it an error.
  ExprPtr standardFileRef(bool input, int line, int col);

  void checkStmt(Stmt *s);
  void checkWrite(WriteStmt *w);
  void checkWriteArgs(WriteStmt *w);
  void checkRead(ReadStmt *r);
  void checkExpr(Expr *e);
  void checkBinary(Binary *b);
  void checkSetExpr(SetExpr *s);
  /// ISO/IEC 10206:1991 §6.8.7.4's set-value. `digits[1, 3, 5]` is a
  /// subscript spine to the parser, so this asks the symbol at the root of one
  /// whether it names a set type — the question ADR-0066 says only Sema can
  /// answer. Null when the spine is an ordinary designator, which is every
  /// spine under ISO 7185.
  Type *setValueTypeOf(Expr *e);
  /// Move the member-designators out of a spine `setValueTypeOf` accepted and
  /// check them against the named type. The resulting `SetExpr` is hung on the
  /// outermost node of the spine, which is what every later pass reads.
  void checkSetValue(Expr *e, Type *named);
  void checkCall(Call *c);
  /// Two families of required function lifted out of `checkCall`, which had
  /// grown past three hundred lines as each Extended Pascal feature added its
  /// own. Each is independently readable, and independently testable.
  void checkFileEnquiry(Call *c);
  void checkStringBuiltin(Call *c);
  void checkWith(WithStmt *w);
  void checkCase(CaseStmt *c);
  /// `new` and `dispose`, which are procedures rather than functions and so
  /// never reach checkCall.
  static bool isRequiredProc(const std::string &name);
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
  /// ISO/IEC 10206:1991 §6.8.2's constant-expression, which is everything an
  /// expression can be once it is nonvarying. Only reached under
  /// `--std=extended`: ISO 7185 §6.3 admits a signed literal or a name and
  /// nothing else.
  bool evalConstBinary(Binary *b, Symbol &out);
  bool evalConstCall(Call *c, Symbol &out);
  bool foldIntOp(long long a, long long b, BinOp op, int line, int col,
                 long long &out);
  /// Set when the folder has said *why* a constant expression failed. Failing
  /// to fold has two unrelated causes — the expression is not constant, which
  /// the caller describes in its own words, and the expression is constant and
  /// wrong, which only the folder can describe — and without this the second
  /// would be reported twice, once precisely and once vaguely.
  bool constReported_ = false;

  /// True if `e` denotes a variable — a name, or one with subscripts and
  /// fields applied. Assignment targets and `var` arguments must be one.
  bool isDesignator(Expr *e) const;
  bool isConstantAccess(Expr *e) const;
  void refuseConstAccess(Expr *base, int line, int col);
  bool isMemoryConstant(Expr *e) const;
  /// The variable a designator ultimately reaches into, or null.
  Symbol *baseSymbol(Expr *e) const;
  Type *resolveInquiry(TypeExpr &denoter);
  Type *resolveRestricted(TypeExpr &denoter);
  /// ISO/IEC 10206:1991 §6.6's initial-state-specifier, checked and folded.
  bool nonvarying(Expr *e) const;
  void checkInitialState(TypeExpr &denoter, Type *t);
  Expr *initialStateOf(TypeExpr &denoter);
  bool bindableOf(TypeExpr &denoter);
  /// True while a field of a *variant part* is being resolved, where §6.5.1
  /// makes the initial state conditional on the selector. There is no flag for
  /// "this position admits a specifier at all": the parser settles that, by
  /// stopping before the word everywhere but the three positions that do.
  bool variantField_ = false;
  /// ...and true while a *schema body* is being resolved. §6.4.7 makes one a
  /// type-denoter, so the word parses there, and it is spelled as a type
  /// definition — so refusing it needs a reason of its own.
  bool schemaBody_ = false;
  /// ISO/IEC 10206:1991 §6.4.3.3.3's required schema `string`. Kept because a
  /// type produced from it has to be interned by (schema, tuple) — §6.4.8 —
  /// and `BindingType`'s `name` field is such a production made where there is
  /// no denoter to resolve. See `stringOfCapacity`.
  Symbol *stringSchema_ = nullptr;
  /// ISO/IEC 10206:1991 §6.4.3.4's required `BindingType`, built once when the
  /// standard has it. Null under ISO 7185, which is what makes every rule
  /// about binding answer "no such type" there rather than needing a flag.
  Type *bindingType_ = nullptr;
  /// §6.4.3.4's other required record-type, built in `installPredefined` for
  /// the same reason `BindingType` is: a program cannot write one, because
  /// two records are the same type only when one identifier denotes both
  /// (ADR-0017), so the *only* value `GetTimeStamp` will accept is one of the
  /// type built here.
  Type *timeStampType_ = nullptr;
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
  /// The expression nodes Sema itself built: §6.8.8.4's substring-constant
  /// has a value that is in no node the program wrote, so a literal for it
  /// is made here and kept as long as `Symbol::constValue` points at it.
  std::vector<ExprPtr> constNodes_;
  std::vector<std::unique_ptr<Type>> types_;
  std::vector<PendingPointer> pendingPointers_;
  std::unordered_map<long long, Type *> stringTypes_;
  std::vector<std::unordered_map<std::string, Symbol *>> scopes_;
  /// ISO 7185 §6.2.2.9's bookkeeping — see `Symbol::usedSeq`. `applySeq_`
  /// counts applied occurrences and only goes up; `scopeMark_[d]` is its value
  /// when the scope at depth d was entered.
  int applySeq_ = 0;
  std::vector<int> scopeMark_;
  /// Whether a type-definition-part is being checked. §6.2.2.9's exception for
  /// a pointer's domain-type is bounded by that part, so a domain written in
  /// the *variable* part has no later definition to wait for (ADR-0091).
  bool inTypePart_ = false;
  /// The record type-denoters whose region is currently open (§6.4.3.3), from
  /// outermost to innermost. A record type *is* a region, so a name spelled
  /// like one of its fields denotes the field and names no type (ADR-0098).
  std::vector<const TypeExpr *> openRecords_;
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
  /// Every interface of the program-block, and every module, by name.
  std::map<std::string, Interface> interfaces_;
  std::map<std::string, ModuleInfo> modules_;
  std::vector<Symbol *> moduleOrder_; // as written
  std::vector<Symbol *> active_;
  /// The module whose heading or block is being checked, null in the program.
  /// It is what makes `input` and `output` reach §6.11.4.2's implicit
  /// accessibility rather than §6.10's program-parameter one.
  Symbol *curModule_ = nullptr;
};

} // namespace ap
