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
///
/// Nested procedures are handled with **static links**. Every procedure gets an
/// activation record — a struct alloca'd in its entry block — whose first field
/// points at the activation record of the block that lexically encloses it.
/// Reading a variable declared `n` levels out means following `n` links and
/// then indexing; calling a procedure means passing the right frame as its
/// hidden first argument. That is the classic Algol/Pascal implementation, and
/// it is what makes a variable of an enclosing procedure visible without
/// passing it explicitly.
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
  llvm::Type *slotType(const Symbol *v);

  llvm::FunctionCallee rt(const char *name, llvm::Type *ret,
                          llvm::ArrayRef<llvm::Type *> params);

  // --- procedures ---------------------------------------------------------
  /// Build the activation-record struct type for a procedure.
  llvm::StructType *buildFrameType(Symbol *proc);
  /// Create the llvm::Function for every procedure in a block, recursively.
  void declareProcs(Block &block);
  /// Emit the body of every procedure in a block, recursively.
  void emitProcs(Block &block);
  void emitProcBody(ProcDecl &decl);
  /// Prologue shared by main and every procedure: alloca the frame, store the
  /// static link, copy the incoming arguments into their slots.
  void enterFrame(Symbol *proc, llvm::Function *fn);

  /// The activation record `levels` deep in the static chain from here.
  llvm::Value *frameAt(int level);
  /// The address of a variable, wherever in the chain it lives.
  llvm::Value *addressOf(Symbol *v);
  /// The frame to pass as a callee's static link.
  llvm::Value *staticLinkFor(Symbol *callee);
  llvm::Value *emitUserCall(Symbol *callee, std::vector<ExprPtr> &args);

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

  void emitTrapIf(llvm::Value *condition, const char *message);
  llvm::Value *checkedArith(unsigned intrinsicId, llvm::Value *l,
                            llvm::Value *r, const char *message);
  llvm::Value *checkedFPToInt(llvm::Value *x, const char *message);
  llvm::Value *guardNonZero(llvm::Value *divisor, const char *message);
  llvm::Value *intrinsicCall(unsigned id, llvm::ArrayRef<llvm::Value *> args);

  llvm::LLVMContext &ctx_;
  const Sema &sema_;
  std::unique_ptr<llvm::Module> mod_;
  llvm::IRBuilder<> b_;

  std::unordered_map<const Symbol *, llvm::StructType *> frameTypes_;
  std::unordered_map<const Symbol *, llvm::Function *> functions_;

  // State for the procedure currently being emitted.
  llvm::Function *curFn_ = nullptr;
  llvm::Value *curFrame_ = nullptr;
  Symbol *curProc_ = nullptr;
  unsigned nextId_ = 0;
  /// Stands in for the argument list of a parameterless call written as a bare
  /// name, which the parser never gave an argument vector.
  std::vector<ExprPtr> noArgs_;
};

} // namespace ap
