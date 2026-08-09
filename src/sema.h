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
  Var,      // a local or global variable
  Param,    // a value parameter — a local initialised from the argument
  VarParam, // a `var` parameter — the frame slot holds a pointer
  Proc,
  Func,
};

struct Symbol {
  std::string name;
  SymKind kind = SymKind::Var;
  Type *type = nullptr;

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

  void checkStmt(Stmt *s);
  void checkExpr(Expr *e);
  void checkBinary(Binary *b);
  void checkCall(Call *c);
  void checkArguments(Symbol *callee, std::vector<ExprPtr> &args, int line,
                      int col);
  bool evalConst(Expr *e, Symbol &out);

  /// True if a value of `from` may be assigned to / compared with `to`.
  bool assignable(Type *to, Type *from) const;

  Diagnostics &diags_;
  std::vector<std::unique_ptr<Symbol>> owned_;
  std::vector<std::unordered_map<std::string, Symbol *>> scopes_;
  Symbol *program_ = nullptr;
  Symbol *current_ = nullptr; // the procedure whose body is being checked
};

} // namespace ap
