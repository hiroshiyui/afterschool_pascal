#include "codegen.h"

#include "llvm/IR/Constants.h"
#include "llvm/IR/Intrinsics.h"
#include "llvm/IR/Verifier.h"
#include "llvm/Support/raw_ostream.h"

namespace ap {

using namespace llvm;

// ---------------------------------------------------------------- utilities

llvm::Type *CodeGen::llvmType(ap::Type *t) {
  switch (t->kind) {
  case TypeKind::Integer: return i32();
  case TypeKind::Real:    return f64();
  case TypeKind::Boolean: return i1();
  case TypeKind::Char:    return i8();
  case TypeKind::Void:    return llvm::Type::getVoidTy(ctx_);
  case TypeKind::Array:
  case TypeKind::Record:
    break;
  }

  auto cached = typeCache_.find(t);
  if (cached != typeCache_.end())
    return cached->second;

  llvm::Type *result;
  if (t->isArray()) {
    // The bounds are folded away here: an index is lowered to an offset from
    // the lower bound, so the LLVM type only needs the extent.
    result = ArrayType::get(llvmType(t->elem),
                            static_cast<uint64_t>(t->length()));
  } else {
    SmallVector<llvm::Type *, 8> fields;
    for (const Field &f : t->fields)
      fields.push_back(llvmType(f.type));
    // `packed` is left to the implementation by ISO 7185 §6.4.3.1, and the
    // natural layout is what the ABI and the optimiser both expect.
    result = StructType::create(ctx_, fields, "rec." + t->name());
  }
  typeCache_[t] = result;
  return result;
}

uint64_t CodeGen::sizeOf(ap::Type *t) {
  return mod_->getDataLayout().getTypeAllocSize(llvmType(t));
}

/// Arrays and records are passed as addresses whichever way they are declared:
/// a `var` parameter binds to the caller's variable, and a value parameter is
/// copied out of the caller's variable by the callee's prologue.
bool CodeGen::passedByAddress(const Symbol *v) {
  return v->kind == SymKind::VarParam || (v->type && v->type->isStructured());
}

FunctionCallee CodeGen::rt(const char *name, llvm::Type *ret,
                           ArrayRef<llvm::Type *> params) {
  return mod_->getOrInsertFunction(name, FunctionType::get(ret, params, false));
}

llvm::Value *CodeGen::toReal(llvm::Value *v, ap::Type *from) {
  if (from && from->isInteger())
    return b_.CreateSIToFP(v, f64(), "toreal");
  return v;
}

llvm::Value *CodeGen::convertFor(llvm::Value *v, ap::Type *from,
                                 ap::Type *to) {
  if (to && to->isReal())
    return toReal(v, from);
  return v;
}

llvm::Value *CodeGen::intrinsicCall(unsigned id,
                                    ArrayRef<llvm::Value *> args) {
  SmallVector<llvm::Type *, 2> overloads;
  overloads.push_back(args[0]->getType());
  Function *fn = Intrinsic::getOrInsertDeclaration(
      mod_.get(), static_cast<Intrinsic::ID>(id), overloads);
  return b_.CreateCall(fn, args);
}

void CodeGen::emitTrapIf(llvm::Value *condition, const std::string &message) {
  BasicBlock *trap = BasicBlock::Create(ctx_, "trap", curFn_);
  BasicBlock *cont = BasicBlock::Create(ctx_, "cont", curFn_);
  b_.CreateCondBr(condition, trap, cont);

  b_.SetInsertPoint(trap);
  llvm::Value *msg = b_.CreateGlobalString(message, "errmsg");
  b_.CreateCall(rt("pas_runtime_error", llvm::Type::getVoidTy(ctx_), {ptr()}),
                {msg});
  b_.CreateUnreachable();

  b_.SetInsertPoint(cont);
}

llvm::Value *CodeGen::checkedArith(unsigned intrinsicId, llvm::Value *l,
                                   llvm::Value *r, const char *message) {
  // ISO 7185 §6.7.2.2 makes arithmetic overflow an error, so the result is
  // computed with an overflow-reporting intrinsic and checked, rather than
  // emitted with `nsw` (which would make an overflowing result poison and let
  // the optimiser assume it never happens).
  Function *fn = Intrinsic::getOrInsertDeclaration(
      mod_.get(), static_cast<Intrinsic::ID>(intrinsicId), {i32()});
  llvm::Value *pair = b_.CreateCall(fn, {l, r}, "arith");
  llvm::Value *result = b_.CreateExtractValue(pair, 0, "arith.val");
  llvm::Value *overflowed = b_.CreateExtractValue(pair, 1, "arith.ovf");

  // The integer type is -maxint..maxint (§6.4.2.2), so a result of INT_MIN is
  // out of range even though it fits the machine word.
  llvm::Value *isIntMin = b_.CreateICmpEQ(
      result, ConstantInt::getSigned(i32(), INT32_MIN), "arith.min");
  emitTrapIf(b_.CreateOr(overflowed, isIntMin, "arith.bad"), message);
  return result;
}

llvm::Value *CodeGen::checkedFPToInt(llvm::Value *x, const char *message) {
  // ISO 7185 §6.6.6.2: trunc and round are errors unless the result is a value
  // of the integer type. The bounds are the exactly-representable powers of two
  // just outside the range, and the comparisons are *ordered*, so a NaN fails
  // both and traps rather than converting to something unspecified.
  llvm::Value *lo = ConstantFP::get(f64(), -2147483648.0);
  llvm::Value *hi = ConstantFP::get(f64(), 2147483648.0);
  llvm::Value *inRange = b_.CreateAnd(b_.CreateFCmpOGT(x, lo, "gt.lo"),
                                      b_.CreateFCmpOLT(x, hi, "lt.hi"));
  emitTrapIf(b_.CreateNot(inRange, "fp.bad"), message);
  return b_.CreateFPToSI(x, i32(), "toint");
}

llvm::Value *CodeGen::guardNonZero(llvm::Value *divisor, const char *message) {
  emitTrapIf(b_.CreateICmpEQ(divisor, ConstantInt::get(i32(), 0), "iszero"),
             message);
  return divisor;
}

// ------------------------------------------------------------------- driver

llvm::Type *CodeGen::slotType(const Symbol *v) {
  // A `var` parameter's slot holds the address of the caller's variable, not
  // a copy of its value. Everything else — including a structured value
  // parameter, which the prologue copies in — holds the value itself.
  return v->kind == SymKind::VarParam ? ptr() : llvmType(v->type);
}

llvm::Type *CodeGen::paramType(const Symbol *v) {
  return passedByAddress(v) ? ptr() : llvmType(v->type);
}

StructType *CodeGen::buildFrameType(Symbol *proc) {
  SmallVector<llvm::Type *, 8> fields;
  fields.push_back(ptr()); // field 0: the static link
  for (const Symbol *v : proc->frameVars)
    fields.push_back(slotType(v));
  StructType *ty = StructType::create(ctx_, fields, "frame." + proc->name);
  frameTypes_[proc] = ty;
  return ty;
}

void CodeGen::declareProcs(Block &block) {
  for (auto &decl : block.procs) {
    Symbol *sym = decl->sym;
    if (!sym || functions_.count(sym))
      continue; // a forward declaration already created it

    buildFrameType(sym);

    SmallVector<llvm::Type *, 8> params;
    params.push_back(ptr()); // the static link
    for (const Symbol *p : sym->params)
      params.push_back(paramType(p));

    llvm::Type *ret =
        sym->kind == SymKind::Func ? llvmType(sym->type)
                                   : llvm::Type::getVoidTy(ctx_);
    // Names are mangled with a counter because nesting allows two procedures
    // of the same name in different parents.
    std::string name = "p." + sym->name + "." + std::to_string(nextId_++);
    functions_[sym] = Function::Create(FunctionType::get(ret, params, false),
                                       Function::InternalLinkage, name,
                                       mod_.get());
  }
  for (auto &decl : block.procs)
    if (decl->body)
      declareProcs(*decl->body);
}

void CodeGen::enterFrame(Symbol *proc, Function *fn) {
  curFn_ = fn;
  curProc_ = proc;
  BasicBlock *entry = BasicBlock::Create(ctx_, "entry", fn);
  b_.SetInsertPoint(entry);

  StructType *frameTy = frameTypes_[proc];
  curFrame_ = b_.CreateAlloca(frameTy, nullptr, "frame");

  auto arg = fn->arg_begin();
  if (proc->level == 0) {
    // The program has no enclosing block, so its static link is never followed.
    b_.CreateStore(ConstantPointerNull::get(cast<PointerType>(ptr())),
                   b_.CreateStructGEP(frameTy, curFrame_, 0, "link"));
  } else {
    arg->setName("static.link");
    b_.CreateStore(&*arg, b_.CreateStructGEP(frameTy, curFrame_, 0, "link"));
    ++arg;
    for (const Symbol *p : proc->params) {
      arg->setName(p->name);
      llvm::Value *slot =
          b_.CreateStructGEP(frameTy, curFrame_, 1 + p->frameIndex, p->name);
      if (p->kind != SymKind::VarParam && p->type->isStructured()) {
        // A structured value parameter arrives as the caller's address; the
        // copy that makes it a *value* parameter is made here, once, so the
        // callee can write to it without the caller seeing the change.
        Align align = mod_->getDataLayout().getABITypeAlign(llvmType(p->type));
        b_.CreateMemCpy(slot, align, &*arg, align, sizeOf(p->type));
      } else {
        b_.CreateStore(&*arg, slot);
      }
      ++arg;
    }
  }
}

void CodeGen::emitProcBody(ProcDecl &decl) {
  Symbol *sym = decl.sym;
  Function *fn = functions_[sym];

  // Save the enclosing procedure's state: emission is recursive, because a
  // procedure's body contains the declarations of the ones nested in it.
  Function *savedFn = curFn_;
  llvm::Value *savedFrame = curFrame_;
  Symbol *savedProc = curProc_;
  auto savedIP = b_.saveIP();

  enterFrame(sym, fn);
  emitStmt(decl.body->body.get());

  if (sym->kind == SymKind::Func) {
    llvm::Value *slot = b_.CreateStructGEP(
        frameTypes_[sym], curFrame_, 1 + sym->resultVar->frameIndex, "result");
    b_.CreateRet(b_.CreateLoad(llvmType(sym->type), slot, "result.val"));
  } else {
    b_.CreateRetVoid();
  }

  curFn_ = savedFn;
  curFrame_ = savedFrame;
  curProc_ = savedProc;
  b_.restoreIP(savedIP);
}

void CodeGen::emitProcs(Block &block) {
  for (auto &decl : block.procs) {
    if (!decl->body)
      continue; // a forward heading; the real one comes later
    emitProcBody(*decl);
    emitProcs(*decl->body);
  }
}

llvm::Value *CodeGen::frameAt(int level) {
  llvm::Value *frame = curFrame_;
  // The static link is field 0 of every frame, so it sits at offset zero and
  // can be loaded straight from the frame pointer without knowing which
  // procedure's struct type this level has.
  for (int l = curProc_->level; l > level; --l)
    frame = b_.CreateLoad(ptr(), frame, "up");
  return frame;
}

llvm::Value *CodeGen::frameSlot(Symbol *v) {
  llvm::Value *frame = frameAt(v->level);
  StructType *frameTy = frameTypes_[v->owner];
  return b_.CreateStructGEP(frameTy, frame, 1 + v->frameIndex, v->name);
}

llvm::Value *CodeGen::addressOf(Symbol *v) {
  llvm::Value *slot = frameSlot(v);
  // A `var` parameter — and the binding of a `with` — holds an address, so the
  // variable it stands for is one load further on.
  if (v->kind == SymKind::VarParam)
    slot = b_.CreateLoad(ptr(), slot, v->name + ".ref");
  return slot;
}

/// Every read and every write goes through here, so a subscript is bounds
/// checked exactly once however it is used.
llvm::Value *CodeGen::emitAddress(Expr *e) {
  switch (e->kind) {
  case NK::VarRef: {
    auto *v = static_cast<VarRef *>(e);
    llvm::Value *base = addressOf(v->sym);
    if (v->withField < 0)
      return base;
    // The name was a field of an enclosing `with`, and `sym` is that
    // statement's binding — the record's address, taken once on entry.
    return b_.CreateStructGEP(llvmType(v->sym->type), base, v->withField,
                              v->name);
  }

  case NK::Field: {
    auto *f = static_cast<FieldExpr *>(e);
    return b_.CreateStructGEP(llvmType(f->base->type),
                              emitAddress(f->base.get()), f->index, f->field);
  }

  case NK::Index: {
    auto *ix = static_cast<IndexExpr *>(e);
    ap::Type *arr = ix->base->type;
    llvm::Value *base = emitAddress(ix->base.get());
    llvm::Value *idx = emitExpr(ix->index.get());

    // char and boolean subscripts are narrower than i32; widening is exact
    // because their ordinals are non-negative.
    if (idx->getType() != i32())
      idx = b_.CreateZExt(idx, i32(), "idx.wide");

    // ISO 7185 §6.5.3.2 makes an index outside the bounds an error. The check
    // comes first, so the subtraction below cannot overflow: afterwards
    // lo <= i <= hi, and both bounds are values of the index type.
    llvm::Value *lo = ConstantInt::getSigned(i32(), arr->lo);
    llvm::Value *hi = ConstantInt::getSigned(i32(), arr->hi);
    llvm::Value *outside =
        b_.CreateOr(b_.CreateICmpSLT(idx, lo, "idx.lt"),
                    b_.CreateICmpSGT(idx, hi, "idx.gt"), "idx.bad");
    emitTrapIf(outside, "array index out of bounds (" +
                            std::to_string(arr->lo) + ".." +
                            std::to_string(arr->hi) + ")");

    llvm::Value *offset = b_.CreateSub(idx, lo, "idx.off");
    return b_.CreateGEP(llvmType(arr), base,
                        {ConstantInt::get(i32(), 0), offset}, "elem");
  }

  case NK::StrLit:
    // A literal is a packed array of char, so it needs an address like any
    // other value of that type.
    return b_.CreateGlobalString(static_cast<StrLit *>(e)->value, "str");

  default:
    return nullptr; // Sema has already required a designator
  }
}

/// The value a designator holds. An array or a record has no register form, so
/// what it yields is its address; everything else is loaded from that address.
llvm::Value *CodeGen::emitLoad(Expr *e) {
  llvm::Value *addr = emitAddress(e);
  if (e->type->isStructured())
    return addr;
  return b_.CreateLoad(llvmType(e->type), addr, "val");
}

void CodeGen::emitCopy(llvm::Value *dst, ap::Type *type, Expr *src) {
  Align align = mod_->getDataLayout().getABITypeAlign(llvmType(type));
  b_.CreateMemCpy(dst, align, emitAddress(src), align, sizeOf(type));
}

llvm::Value *CodeGen::staticLinkFor(Symbol *callee) {
  // A callee declared at level L runs with the frame at level L-1 as its
  // enclosing scope — which for a recursive call is the caller's own parent,
  // not the caller.
  return frameAt(callee->level - 1);
}

llvm::Value *CodeGen::emitUserCall(Symbol *callee, std::vector<ExprPtr> &args) {
  SmallVector<llvm::Value *, 8> argv;
  argv.push_back(staticLinkFor(callee));

  for (size_t i = 0; i < args.size(); ++i) {
    const Symbol *p = callee->params[i];
    if (passedByAddress(p)) {
      // A `var` parameter binds to the variable itself; a structured value
      // parameter is copied from it by the callee. Either way what travels is
      // an address, and Sema has already required something that has one.
      argv.push_back(emitAddress(args[i].get()));
    } else {
      llvm::Value *v = emitExpr(args[i].get());
      argv.push_back(convertFor(v, args[i]->type, p->type));
    }
  }
  return b_.CreateCall(functions_[callee], argv,
                       callee->kind == SymKind::Func ? "call" : "");
}

std::unique_ptr<Module> CodeGen::run(Program &prog) {
  Symbol *programSym = sema_.programSymbol();
  buildFrameType(programSym);
  declareProcs(*prog.block);

  FunctionType *mainTy = FunctionType::get(i32(), false);
  Function *mainFn =
      Function::Create(mainTy, Function::ExternalLinkage, "main", mod_.get());

  enterFrame(programSym, mainFn);
  emitStmt(prog.block->body.get());
  b_.CreateRet(ConstantInt::get(i32(), 0));

  emitProcs(*prog.block);

  if (verifyModule(*mod_, &errs()))
    return nullptr;
  return std::move(mod_);
}

// ---------------------------------------------------------------- statements

void CodeGen::emitStmt(Stmt *s) {
  if (!s)
    return;
  switch (s->kind) {
  case NK::Empty:
    return;
  case NK::Compound:
    for (auto &sub : static_cast<Compound *>(s)->body)
      emitStmt(sub.get());
    return;
  case NK::Assign:  emitAssign(static_cast<Assign *>(s)); return;
  case NK::Write:   emitWrite(static_cast<WriteStmt *>(s)); return;
  case NK::If:      emitIf(static_cast<IfStmt *>(s)); return;
  case NK::While:   emitWhile(static_cast<WhileStmt *>(s)); return;
  case NK::Repeat:  emitRepeat(static_cast<RepeatStmt *>(s)); return;
  case NK::For:     emitFor(static_cast<ForStmt *>(s)); return;
  case NK::With:    emitWith(static_cast<WithStmt *>(s)); return;
  case NK::ProcCall: {
    auto *call = static_cast<ProcCallStmt *>(s);
    emitUserCall(call->sym, call->args);
    return;
  }
  default:
    return; // expression kinds never appear as statements
  }
}

void CodeGen::emitAssign(Assign *s) {
  llvm::Value *dst = emitAddress(s->target.get());
  // A whole array or record is copied; ISO 7185 §6.8.2.2 makes assignment of a
  // structured value a copy of every component, not a sharing of storage.
  if (s->target->type->isStructured()) {
    emitCopy(dst, s->target->type, s->value.get());
    return;
  }
  llvm::Value *v = emitExpr(s->value.get());
  b_.CreateStore(convertFor(v, s->value->type, s->target->type), dst);
}

/// The record is designated once and its address kept for the body, so a
/// subscript in the designator is evaluated a single time (ISO 7185 §6.8.3.10)
/// and cannot see a change the body makes to the subscript's variable.
void CodeGen::emitWith(WithStmt *s) {
  b_.CreateStore(emitAddress(s->record.get()), frameSlot(s->binding));
  emitStmt(s->body.get());
}

void CodeGen::emitWrite(WriteStmt *s) {
  llvm::Type *voidTy = llvm::Type::getVoidTy(ctx_);
  llvm::Value *noWidth = ConstantInt::getSigned(i32(), -1);

  for (auto &arg : s->args) {
    llvm::Value *width = arg.width ? emitExpr(arg.width.get()) : noWidth;
    llvm::Value *prec = arg.prec ? emitExpr(arg.prec.get()) : noWidth;

    // A packed array of char is written as its address plus its length —
    // which covers a string literal, since that is what a literal's type is.
    if (arg.value->type->isCharArray()) {
      b_.CreateCall(
          rt("pas_write_str", voidTy, {ptr(), i32(), i32()}),
          {emitAddress(arg.value.get()),
           ConstantInt::get(i32(), arg.value->type->length()), width});
      continue;
    }

    llvm::Value *v = emitExpr(arg.value.get());
    switch (arg.value->type->kind) {
    case TypeKind::Integer:
      b_.CreateCall(rt("pas_write_int", voidTy, {i64(), i32()}),
                    {b_.CreateSExt(v, i64()), width});
      break;
    case TypeKind::Real:
      b_.CreateCall(rt("pas_write_real", voidTy, {f64(), i32(), i32()}),
                    {v, width, prec});
      break;
    case TypeKind::Boolean:
      b_.CreateCall(rt("pas_write_bool", voidTy, {i32(), i32()}),
                    {b_.CreateZExt(v, i32()), width});
      break;
    case TypeKind::Char:
      b_.CreateCall(rt("pas_write_char", voidTy, {i8(), i32()}), {v, width});
      break;
    default:
      break;
    }
  }

  if (s->newline)
    b_.CreateCall(rt("pas_writeln", voidTy, {}), {});
}

void CodeGen::emitIf(IfStmt *s) {
  llvm::Value *cond = emitExpr(s->cond.get());
  BasicBlock *thenBB = BasicBlock::Create(ctx_, "then", curFn_);
  BasicBlock *elseBB =
      s->elseBranch ? BasicBlock::Create(ctx_, "else", curFn_) : nullptr;
  BasicBlock *endBB = BasicBlock::Create(ctx_, "endif", curFn_);

  b_.CreateCondBr(cond, thenBB, elseBB ? elseBB : endBB);

  b_.SetInsertPoint(thenBB);
  emitStmt(s->thenBranch.get());
  b_.CreateBr(endBB);

  if (elseBB) {
    b_.SetInsertPoint(elseBB);
    emitStmt(s->elseBranch.get());
    b_.CreateBr(endBB);
  }

  b_.SetInsertPoint(endBB);
}

void CodeGen::emitWhile(WhileStmt *s) {
  BasicBlock *condBB = BasicBlock::Create(ctx_, "while.cond", curFn_);
  BasicBlock *bodyBB = BasicBlock::Create(ctx_, "while.body", curFn_);
  BasicBlock *endBB = BasicBlock::Create(ctx_, "while.end", curFn_);

  b_.CreateBr(condBB);
  b_.SetInsertPoint(condBB);
  b_.CreateCondBr(emitExpr(s->cond.get()), bodyBB, endBB);

  b_.SetInsertPoint(bodyBB);
  emitStmt(s->body.get());
  b_.CreateBr(condBB);

  b_.SetInsertPoint(endBB);
}

void CodeGen::emitRepeat(RepeatStmt *s) {
  BasicBlock *bodyBB = BasicBlock::Create(ctx_, "repeat.body", curFn_);
  BasicBlock *endBB = BasicBlock::Create(ctx_, "repeat.end", curFn_);

  b_.CreateBr(bodyBB);
  b_.SetInsertPoint(bodyBB);
  for (auto &sub : s->body)
    emitStmt(sub.get());
  // repeat runs until the condition becomes true
  b_.CreateCondBr(emitExpr(s->cond.get()), endBB, bodyBB);

  b_.SetInsertPoint(endBB);
}

void CodeGen::emitFor(ForStmt *s) {
  llvm::Value *slot = emitAddress(s->var.get());
  llvm::Type *varTy = llvmType(s->var->type);

  llvm::Value *from = convertFor(emitExpr(s->from.get()), s->from->type,
                                 s->var->type);
  llvm::Value *to = convertFor(emitExpr(s->to.get()), s->to->type,
                               s->var->type);
  // The limit is evaluated exactly once, as ISO 7185 requires.
  llvm::Value *limit = b_.CreateAlloca(varTy, nullptr, "for.limit");
  b_.CreateStore(to, limit);
  b_.CreateStore(from, slot);

  BasicBlock *condBB = BasicBlock::Create(ctx_, "for.cond", curFn_);
  BasicBlock *bodyBB = BasicBlock::Create(ctx_, "for.body", curFn_);
  BasicBlock *stepBB = BasicBlock::Create(ctx_, "for.step", curFn_);
  BasicBlock *endBB = BasicBlock::Create(ctx_, "for.end", curFn_);

  b_.CreateBr(condBB);
  b_.SetInsertPoint(condBB);
  llvm::Value *cur = b_.CreateLoad(varTy, slot, "for.cur");
  llvm::Value *lim = b_.CreateLoad(varTy, limit, "for.lim");
  bool isChar = s->var->type->isChar();
  llvm::Value *test =
      s->downto ? (isChar ? b_.CreateICmpUGE(cur, lim) : b_.CreateICmpSGE(cur, lim))
                : (isChar ? b_.CreateICmpULE(cur, lim) : b_.CreateICmpSLE(cur, lim));
  b_.CreateCondBr(test, bodyBB, endBB);

  b_.SetInsertPoint(bodyBB);
  emitStmt(s->body.get());
  // Stop before stepping past the limit so the last iteration cannot overflow.
  llvm::Value *now = b_.CreateLoad(varTy, slot, "for.now");
  llvm::Value *lim2 = b_.CreateLoad(varTy, limit, "for.lim2");
  b_.CreateCondBr(b_.CreateICmpEQ(now, lim2), endBB, stepBB);

  b_.SetInsertPoint(stepBB);
  llvm::Value *one = ConstantInt::get(varTy, 1);
  llvm::Value *next = s->downto ? b_.CreateSub(now, one, "for.dec")
                                : b_.CreateAdd(now, one, "for.inc");
  b_.CreateStore(next, slot);
  b_.CreateBr(condBB);

  b_.SetInsertPoint(endBB);
}

// --------------------------------------------------------------- expressions

llvm::Value *CodeGen::emitConst(const Symbol &sym) {
  switch (sym.type->kind) {
  case TypeKind::Integer: return ConstantInt::getSigned(i32(), sym.intVal);
  case TypeKind::Real:    return ConstantFP::get(f64(), sym.realVal);
  case TypeKind::Boolean: return ConstantInt::get(i1(), sym.boolVal);
  case TypeKind::Char:    return ConstantInt::get(i8(), sym.charVal);
  default:                return ConstantInt::get(i32(), 0);
  }
}

llvm::Value *CodeGen::emitExpr(Expr *e) {
  switch (e->kind) {
  case NK::IntLit:
    return ConstantInt::getSigned(i32(), static_cast<IntLit *>(e)->value);
  case NK::RealLit:
    return ConstantFP::get(f64(), static_cast<RealLit *>(e)->value);
  case NK::CharLit:
    return ConstantInt::get(i8(), static_cast<CharLit *>(e)->value);
  case NK::StrLit:
    return emitAddress(e);
  case NK::VarRef: {
    auto *v = static_cast<VarRef *>(e);
    if (v->withField < 0 && v->sym->kind == SymKind::Const)
      return emitConst(*v->sym);
    if (v->withField < 0 && v->sym->kind == SymKind::Func)
      return emitUserCall(v->sym, noArgs_); // a parameterless call by name
    return emitLoad(e);
  }
  case NK::Index:
  case NK::Field:
    return emitLoad(e);
  case NK::Binary: return emitBinary(static_cast<Binary *>(e));
  case NK::Unary:  return emitUnary(static_cast<Unary *>(e));
  case NK::Call:   return emitCall(static_cast<Call *>(e));
  default:
    return ConstantInt::get(i32(), 0);
  }
}

llvm::Value *CodeGen::emitBinary(Binary *e) {
  // `and` and `or` short-circuit, which is what makes guarded tests such as
  // `while (i <= n) and (a[i] <> x)` safe to write.
  if (e->op == BinOp::And || e->op == BinOp::Or) {
    bool isAnd = e->op == BinOp::And;
    llvm::Value *lhs = emitExpr(e->lhs.get());
    BasicBlock *lhsBB = b_.GetInsertBlock();
    BasicBlock *rhsBB = BasicBlock::Create(ctx_, isAnd ? "and.rhs" : "or.rhs", curFn_);
    BasicBlock *endBB = BasicBlock::Create(ctx_, isAnd ? "and.end" : "or.end", curFn_);

    if (isAnd)
      b_.CreateCondBr(lhs, rhsBB, endBB);
    else
      b_.CreateCondBr(lhs, endBB, rhsBB);

    b_.SetInsertPoint(rhsBB);
    llvm::Value *rhs = emitExpr(e->rhs.get());
    BasicBlock *rhsEnd = b_.GetInsertBlock();
    b_.CreateBr(endBB);

    b_.SetInsertPoint(endBB);
    PHINode *phi = b_.CreatePHI(i1(), 2, isAnd ? "and" : "or");
    phi->addIncoming(ConstantInt::get(i1(), isAnd ? 0 : 1), lhsBB);
    phi->addIncoming(rhs, rhsEnd);
    return phi;
  }

  // Strings compare through the runtime rather than in registers, and must be
  // caught before the operands are evaluated: an array has no register form.
  if (e->lhs->type->isCharArray() && e->rhs->type->isCharArray())
    return emitStringCompare(e);

  llvm::Value *l = emitExpr(e->lhs.get());
  llvm::Value *r = emitExpr(e->rhs.get());
  ap::Type *lt = e->lhs->type;
  ap::Type *rt_ = e->rhs->type;

  switch (e->op) {
  case BinOp::Add:
  case BinOp::Sub:
  case BinOp::Mul: {
    if (e->type->isReal()) {
      l = toReal(l, lt);
      r = toReal(r, rt_);
      switch (e->op) {
      case BinOp::Add: return b_.CreateFAdd(l, r, "add");
      case BinOp::Sub: return b_.CreateFSub(l, r, "sub");
      default:         return b_.CreateFMul(l, r, "mul");
      }
    }
    switch (e->op) {
    case BinOp::Add:
      return checkedArith(Intrinsic::sadd_with_overflow, l, r,
                          "integer overflow in +");
    case BinOp::Sub:
      return checkedArith(Intrinsic::ssub_with_overflow, l, r,
                          "integer overflow in -");
    default:
      return checkedArith(Intrinsic::smul_with_overflow, l, r,
                          "integer overflow in *");
    }
  }

  case BinOp::RealDiv:
    return b_.CreateFDiv(toReal(l, lt), toReal(r, rt_), "div");

  case BinOp::IntDiv: {
    r = guardNonZero(r, "division by zero");
    // maxint div -1 is representable, but INT_MIN div -1 is not; LLVM calls it
    // undefined rather than wrapping, so it has to be excluded explicitly.
    llvm::Value *badPair = b_.CreateAnd(
        b_.CreateICmpEQ(l, ConstantInt::getSigned(i32(), INT32_MIN)),
        b_.CreateICmpEQ(r, ConstantInt::getSigned(i32(), -1)), "div.ovf");
    emitTrapIf(badPair, "integer overflow in div");
    return b_.CreateSDiv(l, r, "idiv");
  }

  case BinOp::Mod: {
    r = guardNonZero(r, "mod by zero");
    // ISO 7185 defines i mod j (for j > 0) as a non-negative result, unlike
    // the truncating remainder LLVM gives us.
    llvm::Value *rem = b_.CreateSRem(l, r, "rem");
    llvm::Value *neg = b_.CreateICmpSLT(rem, ConstantInt::get(i32(), 0));
    llvm::Value *adjusted = b_.CreateAdd(rem, r, "rem.adj");
    return b_.CreateSelect(neg, adjusted, rem, "mod");
  }

  default: { // relational
    bool useFloat = (lt->isReal() || rt_->isReal());
    if (useFloat) {
      l = toReal(l, lt);
      r = toReal(r, rt_);
      switch (e->op) {
      case BinOp::Eq: return b_.CreateFCmpOEQ(l, r, "cmp");
      case BinOp::Ne: return b_.CreateFCmpONE(l, r, "cmp");
      case BinOp::Lt: return b_.CreateFCmpOLT(l, r, "cmp");
      case BinOp::Le: return b_.CreateFCmpOLE(l, r, "cmp");
      case BinOp::Gt: return b_.CreateFCmpOGT(l, r, "cmp");
      default:        return b_.CreateFCmpOGE(l, r, "cmp");
      }
    }
    // char and boolean compare as unsigned ordinals, integer as signed
    bool sign = lt->isInteger();
    switch (e->op) {
    case BinOp::Eq: return b_.CreateICmpEQ(l, r, "cmp");
    case BinOp::Ne: return b_.CreateICmpNE(l, r, "cmp");
    case BinOp::Lt: return sign ? b_.CreateICmpSLT(l, r, "cmp") : b_.CreateICmpULT(l, r, "cmp");
    case BinOp::Le: return sign ? b_.CreateICmpSLE(l, r, "cmp") : b_.CreateICmpULE(l, r, "cmp");
    case BinOp::Gt: return sign ? b_.CreateICmpSGT(l, r, "cmp") : b_.CreateICmpUGT(l, r, "cmp");
    default:        return sign ? b_.CreateICmpSGE(l, r, "cmp") : b_.CreateICmpUGE(l, r, "cmp");
    }
  }
  }
}

/// ISO 7185 §6.7.2.5 orders equal-length strings by their first differing
/// character, which is what the runtime helper reports; the operator then only
/// has to say what it wants of the sign.
llvm::Value *CodeGen::emitStringCompare(Binary *e) {
  llvm::Value *lhs = emitAddress(e->lhs.get());
  llvm::Value *rhs = emitAddress(e->rhs.get());
  llvm::Value *len = ConstantInt::get(i32(), e->lhs->type->length());
  llvm::Value *cmp =
      b_.CreateCall(rt("pas_str_compare", i32(), {ptr(), ptr(), i32()}),
                    {lhs, rhs, len}, "strcmp");
  llvm::Value *zero = ConstantInt::get(i32(), 0);

  switch (e->op) {
  case BinOp::Eq: return b_.CreateICmpEQ(cmp, zero, "streq");
  case BinOp::Ne: return b_.CreateICmpNE(cmp, zero, "strne");
  case BinOp::Lt: return b_.CreateICmpSLT(cmp, zero, "strlt");
  case BinOp::Le: return b_.CreateICmpSLE(cmp, zero, "strle");
  case BinOp::Gt: return b_.CreateICmpSGT(cmp, zero, "strgt");
  default:        return b_.CreateICmpSGE(cmp, zero, "strge");
  }
}

llvm::Value *CodeGen::emitUnary(Unary *e) {
  llvm::Value *v = emitExpr(e->operand.get());
  switch (e->op) {
  case UnOp::Pos:
    return convertFor(v, e->operand->type, e->type);
  case UnOp::Neg:
    if (e->type->isReal())
      return b_.CreateFNeg(toReal(v, e->operand->type), "neg");
    return b_.CreateNSWNeg(v, "neg");
  case UnOp::Not:
    return b_.CreateNot(v, "not");
  }
  return v;
}

llvm::Value *CodeGen::emitCall(Call *e) {
  if (e->sym)
    return emitUserCall(e->sym, e->args);

  llvm::Value *a = emitExpr(e->args[0].get());
  ap::Type *at = e->args[0]->type;

  auto libm = [&](const char *name) {
    return b_.CreateCall(rt(name, f64(), {f64()}), {toReal(a, at)}, "call");
  };

  switch (e->builtin) {
  case Builtin::Abs:
    if (at->isReal())
      return intrinsicCall(Intrinsic::fabs, {a});
    return intrinsicCall(Intrinsic::abs, {a, ConstantInt::get(i1(), 0)});
  case Builtin::Sqr:
    if (at->isReal())
      return b_.CreateFMul(a, a, "sqr");
    return checkedArith(Intrinsic::smul_with_overflow, a, a,
                        "integer overflow in sqr");
  case Builtin::Odd:
    return b_.CreateICmpNE(b_.CreateAnd(a, ConstantInt::get(i32(), 1)),
                           ConstantInt::get(i32(), 0), "odd");
  case Builtin::Ord:
    if (at->isInteger())
      return a;
    return b_.CreateZExt(a, i32(), "ord");
  case Builtin::Chr: {
    // ISO 7185 §6.6.6.4: chr(i) is an error unless i is the ordinal of some
    // char, so the truncation must be guarded rather than allowed to alias.
    llvm::Value *tooSmall = b_.CreateICmpSLT(a, ConstantInt::get(i32(), 0));
    llvm::Value *tooLarge = b_.CreateICmpSGT(a, ConstantInt::get(i32(), 255));
    emitTrapIf(b_.CreateOr(tooSmall, tooLarge, "chr.bad"),
               "chr: argument is not a character ordinal");
    return b_.CreateTrunc(a, i8(), "chr");
  }
  case Builtin::Succ:
  case Builtin::Pred: {
    // succ and pred are errors at the ends of the ordinal type (§6.6.6.4).
    bool up = e->builtin == Builtin::Succ;
    llvm::Value *limit;
    if (at->isChar())
      limit = ConstantInt::get(i8(), up ? 255 : 0);
    else
      limit = ConstantInt::getSigned(i32(), up ? kMaxInt : -kMaxInt);
    emitTrapIf(b_.CreateICmpEQ(a, limit, "ordinal.end"),
               up ? "succ: no successor exists"
                  : "pred: no predecessor exists");
    llvm::Value *one = ConstantInt::get(a->getType(), 1);
    return up ? b_.CreateAdd(a, one, "succ") : b_.CreateSub(a, one, "pred");
  }
  case Builtin::Sqrt:
    return intrinsicCall(Intrinsic::sqrt, {toReal(a, at)});
  case Builtin::Sin:
    return intrinsicCall(Intrinsic::sin, {toReal(a, at)});
  case Builtin::Cos:
    return intrinsicCall(Intrinsic::cos, {toReal(a, at)});
  case Builtin::Ln:
    return intrinsicCall(Intrinsic::log, {toReal(a, at)});
  case Builtin::Exp:
    return intrinsicCall(Intrinsic::exp, {toReal(a, at)});
  case Builtin::ArcTan:
    return libm("atan");
  case Builtin::Trunc:
    return checkedFPToInt(toReal(a, at), "trunc: value out of integer range");
  case Builtin::Round:
    // llvm.round rounds halfway cases away from zero, which is what ISO 7185
    // §6.6.6.3 asks for; the range check then applies to the rounded value.
    return checkedFPToInt(intrinsicCall(Intrinsic::round, {toReal(a, at)}),
                          "round: value out of integer range");
  default:
    return ConstantInt::get(i32(), 0);
  }
}

} // namespace ap
