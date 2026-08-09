#pragma once
#include <memory>
#include <string>
#include <unordered_map>

#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Module.h"

#include "ast.h"
#include "diag.h"
#include "sema.h"

namespace ap {

/// Lowers a type-checked program to an LLVM module whose entry point is the
/// C `main`. The program body becomes main's body; Pascal's I/O turns into
/// calls into the runtime library (runtime/pasrt.c).
class CodeGen {
public:
  CodeGen(llvm::LLVMContext &ctx, const Sema &sema, const std::string &fileName)
      : ctx_(ctx), sema_(sema),
        mod_(std::make_unique<llvm::Module>(fileName, ctx)), b_(ctx) {}

  std::unique_ptr<llvm::Module> run(Program &prog);

private:
  // types
  llvm::Type *llvmType(Type *t);
  llvm::Type *i32() { return llvm::Type::getInt32Ty(ctx_); }
  llvm::Type *i64() { return llvm::Type::getInt64Ty(ctx_); }
  llvm::Type *i8() { return llvm::Type::getInt8Ty(ctx_); }
  llvm::Type *i1() { return llvm::Type::getInt1Ty(ctx_); }
  llvm::Type *f64() { return llvm::Type::getDoubleTy(ctx_); }
  llvm::Type *ptr() { return llvm::PointerType::getUnqual(ctx_); }

  llvm::FunctionCallee rt(const char *name, llvm::Type *ret,
                          llvm::ArrayRef<llvm::Type *> params);

  // statements
  void emitStmt(Stmt *s);
  void emitAssign(Assign *s);
  void emitWrite(WriteStmt *s);
  void emitIf(IfStmt *s);
  void emitWhile(WhileStmt *s);
  void emitRepeat(RepeatStmt *s);
  void emitFor(ForStmt *s);

  // expressions
  llvm::Value *emitExpr(Expr *e);
  llvm::Value *emitBinary(Binary *e);
  llvm::Value *emitUnary(Unary *e);
  llvm::Value *emitCall(Call *e);
  llvm::Value *emitConst(const Symbol &sym);

  /// Widen an integer value to double when Pascal's implicit conversion applies.
  llvm::Value *toReal(llvm::Value *v, Type *from);
  /// Convert a value of type `from` for storage in a slot of type `to`.
  llvm::Value *convertFor(llvm::Value *v, Type *from, Type *to);

  /// Branch to the runtime's error reporter when `condition` holds, and carry
  /// on in a fresh block when it does not.
  void emitTrapIf(llvm::Value *condition, const char *message);
  /// Integer arithmetic that reports overflow instead of wrapping or poisoning.
  llvm::Value *checkedArith(unsigned intrinsicId, llvm::Value *l,
                            llvm::Value *r, const char *message);
  /// Real-to-integer conversion that reports an out-of-range value or a NaN.
  llvm::Value *checkedFPToInt(llvm::Value *x, const char *message);
  llvm::Value *guardNonZero(llvm::Value *divisor, const char *message);
  llvm::Value *intrinsicCall(unsigned id, llvm::ArrayRef<llvm::Value *> args);

  llvm::LLVMContext &ctx_;
  const Sema &sema_;
  std::unique_ptr<llvm::Module> mod_;
  llvm::IRBuilder<> b_;
  llvm::Function *main_ = nullptr;
  std::unordered_map<const Symbol *, llvm::Value *> slots_;
};

} // namespace ap
