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
  case TypeKind::String:  return ptr();
  case TypeKind::Void:    return llvm::Type::getVoidTy(ctx_);
  }
  return i32();
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

llvm::Value *CodeGen::guardNonZero(llvm::Value *divisor, const char *message) {
  llvm::Value *isZero =
      b_.CreateICmpEQ(divisor, ConstantInt::get(i32(), 0), "iszero");
  BasicBlock *trap = BasicBlock::Create(ctx_, "divzero", main_);
  BasicBlock *cont = BasicBlock::Create(ctx_, "divok", main_);
  b_.CreateCondBr(isZero, trap, cont);

  b_.SetInsertPoint(trap);
  llvm::Value *msg = b_.CreateGlobalString(message, "errmsg");
  b_.CreateCall(rt("pas_runtime_error", llvm::Type::getVoidTy(ctx_), {ptr()}),
                {msg});
  b_.CreateUnreachable();

  b_.SetInsertPoint(cont);
  return divisor;
}

// ------------------------------------------------------------------- driver

std::unique_ptr<Module> CodeGen::run(Program &prog) {
  FunctionType *mainTy = FunctionType::get(i32(), false);
  main_ = Function::Create(mainTy, Function::ExternalLinkage, "main",
                           mod_.get());
  BasicBlock *entry = BasicBlock::Create(ctx_, "entry", main_);
  b_.SetInsertPoint(entry);

  for (const Symbol *v : sema_.variables()) {
    llvm::Value *slot = b_.CreateAlloca(llvmType(v->type), nullptr, v->name);
    slots_[v] = slot;
  }

  emitStmt(prog.body.get());

  b_.CreateRet(ConstantInt::get(i32(), 0));

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
  default:
    return; // expression kinds never appear as statements
  }
}

void CodeGen::emitAssign(Assign *s) {
  llvm::Value *v = emitExpr(s->value.get());
  v = convertFor(v, s->value->type, s->target->type);
  b_.CreateStore(v, slots_[s->target->sym]);
}

void CodeGen::emitWrite(WriteStmt *s) {
  llvm::Type *voidTy = llvm::Type::getVoidTy(ctx_);
  llvm::Value *noWidth = ConstantInt::getSigned(i32(), -1);

  for (auto &arg : s->args) {
    llvm::Value *width = arg.width ? emitExpr(arg.width.get()) : noWidth;
    llvm::Value *prec = arg.prec ? emitExpr(arg.prec.get()) : noWidth;

    // A string literal is passed as its address plus its length; nothing else
    // in milestone 1 produces a string value.
    if (arg.value->type->isString()) {
      auto *lit = static_cast<StrLit *>(arg.value.get());
      llvm::Value *text = b_.CreateGlobalString(lit->value, "str");
      b_.CreateCall(rt("pas_write_str", voidTy, {ptr(), i32(), i32()}),
                    {text,
                     ConstantInt::get(i32(), lit->value.size()),
                     width});
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
  BasicBlock *thenBB = BasicBlock::Create(ctx_, "then", main_);
  BasicBlock *elseBB =
      s->elseBranch ? BasicBlock::Create(ctx_, "else", main_) : nullptr;
  BasicBlock *endBB = BasicBlock::Create(ctx_, "endif", main_);

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
  BasicBlock *condBB = BasicBlock::Create(ctx_, "while.cond", main_);
  BasicBlock *bodyBB = BasicBlock::Create(ctx_, "while.body", main_);
  BasicBlock *endBB = BasicBlock::Create(ctx_, "while.end", main_);

  b_.CreateBr(condBB);
  b_.SetInsertPoint(condBB);
  b_.CreateCondBr(emitExpr(s->cond.get()), bodyBB, endBB);

  b_.SetInsertPoint(bodyBB);
  emitStmt(s->body.get());
  b_.CreateBr(condBB);

  b_.SetInsertPoint(endBB);
}

void CodeGen::emitRepeat(RepeatStmt *s) {
  BasicBlock *bodyBB = BasicBlock::Create(ctx_, "repeat.body", main_);
  BasicBlock *endBB = BasicBlock::Create(ctx_, "repeat.end", main_);

  b_.CreateBr(bodyBB);
  b_.SetInsertPoint(bodyBB);
  for (auto &sub : s->body)
    emitStmt(sub.get());
  // repeat runs until the condition becomes true
  b_.CreateCondBr(emitExpr(s->cond.get()), endBB, bodyBB);

  b_.SetInsertPoint(endBB);
}

void CodeGen::emitFor(ForStmt *s) {
  llvm::Value *slot = slots_[s->var->sym];
  llvm::Type *varTy = llvmType(s->var->type);

  llvm::Value *from = convertFor(emitExpr(s->from.get()), s->from->type,
                                 s->var->type);
  llvm::Value *to = convertFor(emitExpr(s->to.get()), s->to->type,
                               s->var->type);
  // The limit is evaluated exactly once, as ISO 7185 requires.
  llvm::Value *limit = b_.CreateAlloca(varTy, nullptr, "for.limit");
  b_.CreateStore(to, limit);
  b_.CreateStore(from, slot);

  BasicBlock *condBB = BasicBlock::Create(ctx_, "for.cond", main_);
  BasicBlock *bodyBB = BasicBlock::Create(ctx_, "for.body", main_);
  BasicBlock *stepBB = BasicBlock::Create(ctx_, "for.step", main_);
  BasicBlock *endBB = BasicBlock::Create(ctx_, "for.end", main_);

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
    return b_.CreateGlobalString(static_cast<StrLit *>(e)->value, "str");
  case NK::VarRef: {
    auto *v = static_cast<VarRef *>(e);
    if (v->sym->kind == SymKind::Const)
      return emitConst(*v->sym);
    return b_.CreateLoad(llvmType(v->type), slots_[v->sym], v->name);
  }
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
    BasicBlock *rhsBB = BasicBlock::Create(ctx_, isAnd ? "and.rhs" : "or.rhs", main_);
    BasicBlock *endBB = BasicBlock::Create(ctx_, isAnd ? "and.end" : "or.end", main_);

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
    case BinOp::Add: return b_.CreateNSWAdd(l, r, "add");
    case BinOp::Sub: return b_.CreateNSWSub(l, r, "sub");
    default:         return b_.CreateNSWMul(l, r, "mul");
    }
  }

  case BinOp::RealDiv:
    return b_.CreateFDiv(toReal(l, lt), toReal(r, rt_), "div");

  case BinOp::IntDiv:
    r = guardNonZero(r, "division by zero");
    return b_.CreateSDiv(l, r, "idiv");

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
    return b_.CreateNSWMul(a, a, "sqr");
  case Builtin::Odd:
    return b_.CreateICmpNE(b_.CreateAnd(a, ConstantInt::get(i32(), 1)),
                           ConstantInt::get(i32(), 0), "odd");
  case Builtin::Ord:
    if (at->isInteger())
      return a;
    return b_.CreateZExt(a, i32(), "ord");
  case Builtin::Chr:
    return b_.CreateTrunc(a, i8(), "chr");
  case Builtin::Succ:
    return b_.CreateAdd(a, ConstantInt::get(a->getType(), 1), "succ");
  case Builtin::Pred:
    return b_.CreateSub(a, ConstantInt::get(a->getType(), 1), "pred");
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
    return b_.CreateFPToSI(toReal(a, at), i32(), "trunc");
  case Builtin::Round:
    return b_.CreateFPToSI(intrinsicCall(Intrinsic::round, {toReal(a, at)}),
                           i32(), "round");
  default:
    return ConstantInt::get(i32(), 0);
  }
}

} // namespace ap
