#pragma once
#include <memory>
#include <string>
#include <unordered_map>
#include <vector>

#include "ast.h"
#include "diag.h"
#include "type.h"

namespace ap {

enum class SymKind {
  Const,
  Type,     // a name introduced by the type part
  Var,      // a local or global variable
  Param,    // a value parameter — a local initialised from the argument
  VarParam, // a `var` parameter — the frame slot holds a pointer
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

  bool isCallable() const {
    return kind == SymKind::Proc || kind == SymKind::Func;
  }
  bool isVariable() const {
    return kind == SymKind::Var || kind == SymKind::Param ||
           kind == SymKind::VarParam;
  }
};

/// Name resolution and type checking. Every VarRef comes out pointing at a
/// Symbol and every Expr comes out with a non-null type, so codegen never has
/// to ask questions about the source program.
class Sema {
public:
  explicit Sema(Diagnostics &diags) : diags_(diags) {}

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
  Type *resolveArray(TypeExpr &denoter, size_t dim);
  Type *resolveRecord(TypeExpr &denoter);
  Type *resolveEnum(TypeExpr &denoter);
  Type *resolveSubrange(TypeExpr &denoter);
  Type *resolvePointer(TypeExpr &denoter);
  Type *resolveFile(TypeExpr &denoter);
  /// Fill in the domains of pointers that named a type not yet defined, and
  /// report any that never were. Run at the end of each type part.
  void resolvePendingPointers();
  /// Resolve the variant part of a record that has one.
  void resolveVariants(TypeExpr &denoter, Type *record);
  /// Add a field to `into`, reporting a name already used anywhere in `record`.
  void addField(Type *record, std::vector<Field> &into, const DeclName &name,
                Type *type, int variant);
  /// The `packed array [1..n] of char` that ISO 7185 §6.4.3.2 gives a string
  /// literal. Cached by length so two literals of a length share one type.
  Type *stringType(long long length);
  /// Evaluate a constant that must be ordinal — a subrange bound, a case
  /// label, a variant's tag value. Reports the type it was written as, so a
  /// mismatch can be named rather than silently coerced.
  bool evalOrdinal(Expr *e, Type *&type, long long &value);

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
  void checkCall(Call *c);
  void checkWith(WithStmt *w);
  void checkCase(CaseStmt *c);
  /// `new` and `dispose`, which are procedures rather than functions and so
  /// never reach checkCall.
  void checkStdProc(ProcCallStmt *p);
  void checkArguments(Symbol *callee, std::vector<ExprPtr> &args, int line,
                      int col);
  bool evalConst(Expr *e, Symbol &out);

  /// True if `e` denotes a variable — a name, or one with subscripts and
  /// fields applied. Assignment targets and `var` arguments must be one.
  bool isDesignator(Expr *e) const;
  /// The variable a designator ultimately reaches into, or null.
  Symbol *baseSymbol(Expr *e) const;

  /// True if a value of `from` may be assigned to / compared with `to`.
  bool assignable(Type *to, Type *from) const;

  /// The field of an enclosing `with` this name refers to, if any.
  Symbol *lookupWithField(const std::string &name, const Field *&field) const;

  /// A pointer type whose domain named a type not yet defined. ISO 7185
  /// §6.4.4 allows exactly this, and it is the only forward reference in the
  /// language — without it no type could contain a pointer to itself.
  struct PendingPointer {
    Type *pointer;
    std::string domain;
    int line = 0, col = 0;
  };

  Diagnostics &diags_;
  std::vector<std::unique_ptr<Symbol>> owned_;
  std::vector<std::unique_ptr<Type>> types_;
  std::vector<PendingPointer> pendingPointers_;
  std::unordered_map<long long, Type *> stringTypes_;
  std::vector<std::unordered_map<std::string, Symbol *>> scopes_;
  /// The bindings of the `with` statements currently open, innermost last.
  std::vector<Symbol *> withStack_;
  Symbol *program_ = nullptr;
  Symbol *current_ = nullptr; // the procedure whose body is being checked
  Program *prog_ = nullptr;   // for the parameter list, while the program is checked
  /// The standard files, when the program parameters name them.
  Symbol *stdInput_ = nullptr;
  Symbol *stdOutput_ = nullptr;
};

} // namespace ap
