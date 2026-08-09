#pragma once
#include <map>
#include <memory>
#include <string>
#include <unordered_map>
#include <utility>

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
  /// The data layout is needed during emission, not just after it: the size of
  /// a record or an array decides how much a whole-variable assignment copies.
  CodeGen(llvm::LLVMContext &ctx, const Sema &sema, const std::string &fileName,
          const llvm::DataLayout &layout, const llvm::Triple &triple)
      : ctx_(ctx), sema_(sema),
        mod_(std::make_unique<llvm::Module>(fileName, ctx)), b_(ctx) {
    mod_->setDataLayout(layout);
    mod_->setTargetTriple(triple);
  }

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
  /// The type of a variable's field in its activation record.
  llvm::Type *slotType(const Symbol *v);
  /// The type of a parameter in the LLVM function signature. It differs from
  /// the slot type for anything passed by address rather than by value.
  llvm::Type *paramType(const Symbol *v);
  /// True if this parameter arrives as an address the callee copies from.
  static bool passedByAddress(const Symbol *v);
  uint64_t sizeOf(Type *t);
  /// The shared storage a record's variant arms are laid over.
  llvm::Type *variantStorageType(Type *record);
  /// The struct one arm of a variant part lays over that storage.
  llvm::StructType *variantType(Type *record, int variant);

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
  /// The variable's field in its activation record, without following it.
  llvm::Value *frameSlot(Symbol *v);
  /// The address of a variable, wherever in the chain it lives.
  llvm::Value *addressOf(Symbol *v);
  /// The address of one field of a record, fixed part or variant alike.
  llvm::Value *fieldAddress(llvm::Value *record, Type *type,
                            const Field *field);
  /// The address a designator denotes — a name, a subscript, or a field.
  /// This is the one path by which anything is read or written.
  llvm::Value *emitAddress(Expr *e);
  /// The value a designator holds, loaded from the address it denotes.
  llvm::Value *emitLoad(Expr *e);
  /// Copy a whole array or record from the value expression into `dst`.
  void emitCopy(llvm::Value *dst, Type *type, Expr *src);
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
  void emitWith(WithStmt *s);
  void emitCase(CaseStmt *s);
  /// Trap unless the value is in `target`'s subrange. A no-op for every other
  /// type, so it can be applied wherever a value is stored.
  llvm::Value *checkedForSubrange(llvm::Value *v, Type *target);

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

  /// Compare two equal-length strings through the runtime helper.
  llvm::Value *emitStringCompare(Binary *e);

  void emitTrapIf(llvm::Value *condition, const std::string &message);
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
  /// One LLVM type per Pascal type, so a record keeps a single struct type
  /// however many variables have it.
  std::unordered_map<const Type *, llvm::Type *> typeCache_;
  /// One struct per (record, variant arm), keyed the same way a field names
  /// the arm it belongs to.
  std::map<std::pair<const Type *, int>, llvm::StructType *> variantTypes_;

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
