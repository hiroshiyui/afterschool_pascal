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

// The sizes the compiler and the runtime cannot disagree about: a file
// variable's storage, and the jump record a non-local `goto` lands in.
#include "../runtime/pasrt.h"

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
  /// ISO/IEC 10206:1991's `complex`, as a two-element vector of doubles:
  /// element 0 is the real part and element 1 the imaginary one.
  llvm::Type *cplx() {
    return llvm::FixedVectorType::get(llvm::Type::getDoubleTy(ctx_), 2);
  }
  /// Every set is one 256-bit integer: a bit per possible member, so union is
  /// `or`, intersection is `and`, and membership is one shift (ADR-0028).
  llvm::Type *i256() { return llvm::Type::getIntNTy(ctx_, 256); }
  llvm::Type *ptr() { return llvm::PointerType::getUnqual(ctx_); }
  /// The value of a procedural or functional parameter: `{code, static link}`.
  /// It is never formed as an LLVM value — the two halves are stored and loaded
  /// through their own GEPs, and travel as two separate arguments — so nothing
  /// here depends on how a struct is passed.
  llvm::StructType *procPairType() {
    return llvm::StructType::get(ctx_, {ptr(), ptr()});
  }
  /// The descriptor a schematic formal parameter travels as: the address of
  /// the actual, and then its tuple, one discriminant per field in the
  /// schema's own order. Like the procedural pair it never exists as an LLVM
  /// value — the parts are stored and loaded through their own GEPs and travel
  /// as separate arguments — so a caller and a callee agree by both coming
  /// through here (ADR-0030's shape, and for the same reason).
  llvm::StructType *descriptorType(const Symbol *param);
  /// The bytes a value of this type occupies, as a *value* rather than a
  /// constant: an array whose bounds arrive with the actual has a size only
  /// the descriptor can answer.
  llvm::Value *dynSize(Type *t, llvm::Value *header = nullptr);
  /// The two bounds of an array, either of which may come from a descriptor —
  /// or, for a variable created by `new` from a schema domain, from the header
  /// in front of it, which is what `header` points at.
  llvm::Value *boundValue(Type *t, bool high, llvm::Value *header = nullptr);
  /// How many components an array has, as a value: `Type::length()` answers
  /// only where the bounds are numbers, and returns a plausible one where they
  /// are not.
  llvm::Value *dynLength(Type *t, llvm::Value *header = nullptr);
  /// The bytes a heap variable's tuple occupies in front of it, and where it
  /// sits given the variable's own address. Zero and null for every other
  /// type (ADR-0043).
  static unsigned headerSize(const Type *t);
  llvm::Value *headerOf(Type *t, llvm::Value *base);
  /// The header governing a designator: the one in front of the whole variable
  /// it selects from, which an inner subscript cannot reach from its own base.
  llvm::Value *heapHeader(Expr *e);
  /// The tuple `new` is building, for as long as it has nowhere to live: the
  /// block it will sit in front of is what the tuple is being used to size.
  /// Null everywhere else, and that is what makes it safe for `boundValue` to
  /// consult — outside `new` a heap variable's bounds are only ever in its
  /// header.
  std::vector<llvm::Value *> *newTuple_ = nullptr;
  /// The k'th discriminant of the tuple an expression's type was produced
  /// with: a constant, or a read of the variable's own descriptor.
  llvm::Value *discValue(Expr *e, size_t k, llvm::Type *want);
  /// §6.4.6 d): a mismatched tuple makes two types produced from one schema
  /// different types, and where that is not known until the program runs it is
  /// a dynamic-violation rather than a diagnostic.
  void emitTupleCheck(Expr *dst, Expr *src);
  /// A variable whose actual-discriminant-part is not constant: §6.2.3.2
  /// evaluates it when the block is entered, which is here. The tuple is
  /// stored, checked, and the storage it sizes is claimed.
  void initDynamicVars(Symbol *proc);
  /// §6.4.7 NOTE 2: a tuple that leaves an index range empty selects no type
  /// from the schema at all. Where the tuple is a constant Sema says so; where
  /// it is not, this does.
  void checkSchemaDomain(Type *t, const std::string &schema,
                         llvm::Value *header = nullptr);

  /// The storage a block that a non-local `goto` can reach carries in its
  /// activation record. Opaque, like a file variable, and i64-element for the
  /// same reason: the alignment has to be a machine word's whatever the
  /// platform puts in a `jmp_buf`.
  llvm::Type *jumpRecordType() {
    return llvm::ArrayType::get(i64(), PAS_JUMP_SIZE / 8);
  }
  /// The address of that record within a frame, which is the field after the
  /// last variable. Only called for a proc whose `nonLocalLabels` is non-empty.
  llvm::Value *jumpRecord(Symbol *proc, llvm::Value *frame);
  /// Arm the jump record, call `_setjmp`, and dispatch to the label the jump
  /// carried — the whole of what a non-local goto's *target* has to do.
  void emitJumpDispatch(Symbol *proc);
  /// The signature an indirect call through a procedural parameter uses:
  /// the static link, then the parameters, exactly as declareProcs builds it
  /// for a procedure with a body.
  llvm::FunctionType *procFnType(const Symbol *p);
  void appendParamTypes(const std::vector<Symbol *> &params,
                        llvm::SmallVectorImpl<llvm::Type *> &into);
  /// The type of a variable's field in its activation record.
  llvm::Type *slotType(const Symbol *v);
  /// The type of a parameter in the LLVM function signature. It differs from
  /// the slot type for anything passed by address rather than by value.
  llvm::Type *paramType(const Symbol *v);
  /// True if this parameter arrives as an address the callee copies from.
  static bool passedByAddress(const Symbol *v);
  uint64_t sizeOf(Type *t);
  /// The bytes a record needs when only the arms `selection` names can be
  /// stored in it — `new(p, c1, ..., cn)`. The offsets are the full type's, so
  /// every selected field still lies where the full layout puts it; only the
  /// tail, which the unselected (possibly larger) arms would have needed, is
  /// trimmed off.
  uint64_t selectedSize(Type *record, const std::vector<int> &path,
                        const std::vector<int> &selection, size_t at);
  /// The arms of the variant part at `path` — the record's own when the path
  /// is empty, otherwise the one nested inside the arm the path names.
  static const std::vector<Variant> &armsAt(Type *record,
                                            const std::vector<int> &path);
  /// The fields of the field-list at `path`, which is what `index` indexes.
  static const std::vector<Field> &fieldsAt(Type *record,
                                            const std::vector<int> &path);
  /// The shared storage the arms at `path` are laid over.
  llvm::Type *variantStorageType(Type *record, const std::vector<int> &path);
  /// The struct the arm at `path` lays over the storage that holds it.
  llvm::StructType *variantType(Type *record, const std::vector<int> &path);
  /// The struct the field-list at `path` is: the record itself when empty.
  llvm::Type *structAt(Type *record, const std::vector<int> &path);

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
  void emitCopy(llvm::Value *dst, Type *type, llvm::Value *srcAddr);
  /// Give the variable at `dst`, of type `type`, the value of `src`. This is
  /// the whole of what assignment does — the conversion, the range check, and
  /// the whole-variable copy — and `write` to a file that is not a text needs
  /// exactly it, because §6.6.5.2 defines that write as `f^ := e`.
  void emitStore(llvm::Value *dst, Type *type, Expr *src,
                 llvm::Value *header = nullptr);
  void initInitialStates(Symbol *proc);
  void initialStateInto(llvm::Value *addr, Type *t, Expr *init);
  /// The frame to pass as a callee's static link.
  llvm::Value *staticLinkFor(Symbol *callee);
  llvm::Value *emitUserCall(Symbol *callee, std::vector<ExprPtr> &args);
  /// Push the `{code, link}` pair an actual procedural parameter travels as.
  void emitProcArgument(Symbol *actual,
                        llvm::SmallVectorImpl<llvm::Value *> &argv);

  // statements
  void emitStmt(Stmt *s);
  void emitAssign(Assign *s);
  void emitWrite(WriteStmt *s);
  void emitRead(ReadStmt *s);
  /// Open the file variables a frame declares, and close them when it exits.
  /// ISO 7185 ties a file's lifetime to the block that declares it, so this is
  /// the block's own prologue and epilogue rather than anything global.
  void initFiles(Symbol *proc);
  void closeFiles(Symbol *proc);
  void emitIf(IfStmt *s);
  void emitWhile(WhileStmt *s);
  void emitRepeat(RepeatStmt *s);
  void emitFor(ForStmt *s);
  void emitWith(WithStmt *s);
  void emitCase(CaseStmt *s);
  void emitStdProc(ProcCallStmt *s);
  /// Trap unless the value is in `target`'s subrange. A no-op for every other
  /// type, so it can be applied wherever a value is stored.
  llvm::Value *checkedForSubrange(llvm::Value *v, Type *target);
  llvm::Value *checkedForSetBase(llvm::Value *v, Type *target);
  /// A value entering a variable of `target`: the subrange check and the set
  /// check are the same idea for two kinds of type, so call sites ask once.
  llvm::Value *checkedForStore(llvm::Value *v, Type *target) {
    return checkedForSetBase(checkedForSubrange(v, target), target);
  }
  /// The 256-bit constant with a bit set for every value of `base`.
  llvm::Value *setUniverse(Type *base);
  /// A member's bit position, checked against 0..255 and widened.
  llvm::Value *setIndex(Expr *e, const char *what);

  // expressions
  llvm::Value *emitExpr(Expr *e);
  llvm::Value *emitBinary(Binary *e);
  void emitGoto(GotoStmt *g);
  void emitLabeled(LabeledStmt *l);
  /// The basic block each label denotes, by the id Sema gave it. Cleared for
  /// each function, since a label belongs to exactly one block.
  std::map<int, llvm::BasicBlock *> labelBlocks_;
  llvm::BasicBlock *labelBlock(int id);
  llvm::Value *emitSet(SetExpr *e);
  llvm::Value *emitSetBinary(Binary *e, llvm::Value *l, llvm::Value *r);
  llvm::Value *emitUnary(Unary *e);
  llvm::Value *emitCall(Call *e);
  llvm::Value *emitConst(const Symbol &sym);

  /// Widen an integer value to double when Pascal's implicit conversion applies.
  llvm::Value *toReal(llvm::Value *v, Type *from);
  /// Convert a value of type `from` for storage in a slot of type `to`.
  llvm::Value *convertFor(llvm::Value *v, Type *from, Type *to);
  llvm::Value *reOf(llvm::Value *z);
  llvm::Value *imOf(llvm::Value *z);
  llvm::Value *makeComplex(llvm::Value *re, llvm::Value *im);
  llvm::Value *toComplex(llvm::Value *v, Type *from);
  llvm::Value *emitComplexBinary(Binary *e, llvm::Value *l,
                                 llvm::Value *r);
  /// ISO/IEC 10206:1991 §6.4.3.3: a string *value* is a pointer and a length,
  /// two scalars that travel separately — ADR-0030's shape, for ADR-0030's
  /// reason. Every string-valued expression is emitted through this.
  void emitString(Expr *e, llvm::Value *&data, llvm::Value *&len);
  /// The capacity a string variable can hold, as a value: `hi` for a written
  /// one and the descriptor's discriminant for a schematic formal.
  llvm::Value *stringCapacity(Type *t, llvm::Value *addr);
  void emitStringStore(llvm::Value *dst, Type *type, Expr *src,
                       llvm::Value *header);
  llvm::Value *emitStringCompare2(Binary *e);

  /// Compare two equal-length strings through the runtime helper.
  llvm::Value *emitStringCompare(Binary *e);

  void emitTrapIf(llvm::Value *condition, const std::string &message);
  void emitTrapCall(llvm::Value *condition, llvm::FunctionCallee fn,
                    llvm::ArrayRef<llvm::Value *> args);
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
  /// One struct per (record, path to an arm), keyed the same way a field names
  /// the arm it belongs to.
  std::map<std::pair<const Type *, std::vector<int>>, llvm::StructType *>
      variantTypes_;

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
