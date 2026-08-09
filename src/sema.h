#pragma once
#include <memory>
#include <string>
#include <unordered_map>
#include <vector>

#include "ast.h"
#include "diag.h"
#include "type.h"

namespace ap {

enum class SymKind { Const, Var };

struct Symbol {
  std::string name;
  SymKind kind = SymKind::Var;
  Type *type = nullptr;

  // Value of a constant, in whichever field its type selects.
  long long intVal = 0;
  double realVal = 0;
  char charVal = 0;
  bool boolVal = false;
};

/// Name resolution and type checking. Every VarRef comes out pointing at a
/// Symbol and every Expr comes out with a non-null type, so codegen never has
/// to ask questions about the source program.
class Sema {
public:
  explicit Sema(Diagnostics &diags) : diags_(diags) { installPredefined(); }

  void run(Program &prog);

  /// Variables in declaration order — what codegen allocates.
  const std::vector<Symbol *> &variables() const { return varOrder_; }

private:
  void installPredefined();
  Symbol *declare(const std::string &name, SymKind kind, int line, int col);
  Symbol *lookup(const std::string &name) const;

  void checkStmt(Stmt *s);
  void checkExpr(Expr *e);
  void checkBinary(Binary *b);
  void checkCall(Call *c);
  bool evalConst(Expr *e, Symbol &out);

  /// True if a value of `from` may be assigned to / compared with `to`.
  bool assignable(Type *to, Type *from) const;

  Diagnostics &diags_;
  std::vector<std::unique_ptr<Symbol>> owned_;
  std::unordered_map<std::string, Symbol *> scope_;
  std::vector<Symbol *> varOrder_;
};

} // namespace ap
