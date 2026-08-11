#include "codegen.h"

#include "llvm/IR/Constants.h"
#include "llvm/IR/Intrinsics.h"
#include "llvm/IR/Verifier.h"
#include "llvm/Support/raw_ostream.h"

// The size of a file variable's storage, so the compiler and the runtime
// cannot disagree about it.
#include "../runtime/pasrt.h"

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
  // An enumeration is its ordinal number; a subrange is represented exactly as
  // the type it is a subrange of, and differs only in what it accepts.
  case TypeKind::Enum:     return i32();
  case TypeKind::Subrange: return llvmType(t->host);
  // Opaque pointers make every pointer type the same LLVM type, so a
  // recursive Pascal type needs no forward declaration here.
  case TypeKind::Pointer:  return ptr();
  // A file variable is an opaque block of storage the runtime owns. Its
  // contents are private to runtime/pasrt.c — the compiler only ever passes
  // its address — so all that is needed here is the size, which comes from the
  // header both sides share. The element type is i64 so the block carries the
  // alignment a struct full of pointers needs.
  case TypeKind::File:
    return ArrayType::get(i64(), PAS_FILE_SIZE / 8);
  // Every set is the same 256-bit integer whatever its base type: one bit per
  // possible member, which is what makes the operators single instructions and
  // keeps a set a *value* rather than something reached through its address.
  case TypeKind::Set:
    return i256();
  // A procedural parameter is a pair: the code to call, and the static link to
  // call it with. Both halves are needed because a procedure passed as an
  // argument carries the scope it was *declared* in, not the one it is called
  // from — which is the whole difficulty of the feature.
  case TypeKind::Proc:
    return procPairType();
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
    // the lower bound, so the LLVM type only needs the extent. An array whose
    // extent arrives with the actual has none to state, and nothing asks: its
    // addresses are computed in bytes and its size comes from `dynSize`, so
    // this stands only where a type is needed to name the component.
    result = ArrayType::get(
        llvmType(t->elem),
        t->dynamicExtent() ? 0 : static_cast<uint64_t>(t->length()));
  } else {
    SmallVector<llvm::Type *, 8> fields;
    for (const Field &f : t->fields)
      fields.push_back(llvmType(f.type));
    // A named struct is created before the variant part is measured, because
    // measuring needs a module with a data layout and this one is it.
    StructType *rec = StructType::create(ctx_, "rec." + t->name());
    typeCache_[t] = rec;
    if (!t->variants.empty())
      fields.push_back(variantStorageType(t, {}));
    // `packed` is left to the implementation by ISO 7185 §6.4.3.1, and the
    // natural layout is what the ABI and the optimiser both expect.
    rec->setBody(fields);
    return rec;
  }
  typeCache_[t] = result;
  return result;
}

/// LLVM has no union, so the variant part is one block of storage big enough
/// and aligned well enough for every arm, and each arm is a struct laid over
/// it. The element type carries the alignment: `[k x i64]` is 8-aligned where
/// `[n x i8]` would be 1-aligned and would misalign a real inside a variant.
llvm::Type *CodeGen::variantStorageType(ap::Type *record,
                                        const std::vector<int> &path) {
  const std::vector<Variant> &arms = armsAt(record, path);
  uint64_t size = 0;
  uint64_t align = 1;
  std::vector<int> armPath = path;
  for (size_t i = 0; i < arms.size(); ++i) {
    armPath.push_back(static_cast<int>(i));
    llvm::Type *arm = variantType(record, armPath);
    armPath.pop_back();
    size = std::max(size, mod_->getDataLayout().getTypeAllocSize(arm).getFixedValue());
    align = std::max(align,
                     mod_->getDataLayout().getABITypeAlign(arm).value());
  }
  if (size == 0)
    return ArrayType::get(i8(), 0); // every arm is empty
  llvm::Type *unit = llvm::IntegerType::get(ctx_, align * 8);
  return ArrayType::get(unit, (size + align - 1) / align);
}

/// The arms of the variant part at `path`, and the fields of the field-list
/// there. An empty path is the record itself; each further index steps into an
/// arm, whose field-list is a field-list like any other (§6.4.3.3).
const std::vector<Variant> &CodeGen::armsAt(ap::Type *record,
                                            const std::vector<int> &path) {
  const std::vector<Variant> *arms = &record->variants;
  for (int k : path)
    arms = &(*arms)[k].variants;
  return *arms;
}

const std::vector<Field> &CodeGen::fieldsAt(ap::Type *record,
                                            const std::vector<int> &path) {
  if (path.empty())
    return record->fields;
  const std::vector<Variant> *arms = &record->variants;
  for (size_t i = 0; i + 1 < path.size(); ++i)
    arms = &(*arms)[path[i]].variants;
  return (*arms)[path.back()].fields;
}

/// The struct one arm of a variant part lays over the shared storage. An arm
/// that has a variant part of its own carries the storage for it as a last
/// member, exactly as the record does.
llvm::StructType *CodeGen::variantType(ap::Type *record,
                                       const std::vector<int> &path) {
  auto key = std::make_pair(static_cast<const ap::Type *>(record), path);
  auto cached = variantTypes_.find(key);
  if (cached != variantTypes_.end())
    return cached->second;

  std::string name = "var." + record->name();
  for (int k : path)
    name += "." + std::to_string(k);
  // Created empty and cached first, so measuring the nested storage below can
  // ask for this same arm without recursing forever.
  StructType *ty = StructType::create(ctx_, name);
  variantTypes_[key] = ty;

  SmallVector<llvm::Type *, 8> fields;
  for (const Field &f : fieldsAt(record, path))
    fields.push_back(llvmType(f.type));
  if (!armsAt(record, path).empty())
    fields.push_back(variantStorageType(record, path));
  ty->setBody(fields);
  return ty;
}

llvm::Type *CodeGen::structAt(ap::Type *record, const std::vector<int> &path) {
  return path.empty() ? llvmType(record) : variantType(record, path);
}

uint64_t CodeGen::sizeOf(ap::Type *t) {
  return mod_->getDataLayout().getTypeAllocSize(llvmType(t));
}

uint64_t CodeGen::selectedSize(ap::Type *record, const std::vector<int> &path,
                               const std::vector<int> &selection, size_t at) {
  StructType *self = cast<StructType>(structAt(record, path));
  const StructLayout *layout = mod_->getDataLayout().getStructLayout(self);
  // Nothing left to select, or nothing to select from: the whole struct,
  // shared storage and all.
  if (at >= selection.size() || armsAt(record, path).empty())
    return layout->getSizeInBytes();
  uint64_t storage =
      layout->getElementOffset(fieldsAt(record, path).size());
  std::vector<int> sub = path;
  sub.push_back(selection[at]);
  return storage + selectedSize(record, sub, selection, at + 1);
}

/// Arrays and records are passed as addresses whichever way they are declared:
/// a `var` parameter binds to the caller's variable, and a value parameter is
/// copied out of the caller's variable by the callee's prologue. A file is
/// always a `var` parameter (Sema rejects any other kind), so it arrives as an
/// address too — but it is never copied.
bool CodeGen::passedByAddress(const Symbol *v) {
  return v->kind == SymKind::VarParam || (v->type && v->type->isMemory());
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
  emitTrapCall(condition,
               rt("pas_runtime_error", llvm::Type::getVoidTy(ctx_), {ptr()}),
               {b_.CreateGlobalString(message, "errmsg")});
}

/// The same shape, for a trap whose message cannot be written here: the
/// runtime formats it out of values only the running program has. Note the
/// arguments are computed *before* the branch, because they are the bounds
/// that were compared and they are in scope there.
void CodeGen::emitTrapCall(llvm::Value *condition, FunctionCallee fn,
                           ArrayRef<llvm::Value *> args) {
  SmallVector<llvm::Value *, 4> saved(args.begin(), args.end());
  BasicBlock *trap = BasicBlock::Create(ctx_, "trap", curFn_);
  BasicBlock *cont = BasicBlock::Create(ctx_, "cont", curFn_);
  b_.CreateCondBr(condition, trap, cont);

  b_.SetInsertPoint(trap);
  b_.CreateCall(fn, saved);
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

/// ISO 7185 §6.4.6 makes it an error to store a value outside a subrange's
/// bounds, so every place a value enters a subrange variable goes through
/// here. A subrange covering its whole host type needs no check at all, which
/// is what keeps `1..maxint` from paying for one.
llvm::Value *CodeGen::checkedForSubrange(llvm::Value *v, ap::Type *target) {
  if (!target || !target->isSubrange())
    return v;
  const ap::Type *host = target->base();
  if (target->lo <= host->ordinalLo() && target->hi >= host->ordinalHi())
    return v;

  llvm::Type *ty = v->getType();
  bool sign = target->isSignedOrdinal();
  auto constant = [&](long long value) -> llvm::Value * {
    return sign ? ConstantInt::getSigned(ty, value)
                : ConstantInt::get(ty, static_cast<uint64_t>(value));
  };
  llvm::Value *below = sign ? b_.CreateICmpSLT(v, constant(target->lo))
                            : b_.CreateICmpULT(v, constant(target->lo));
  llvm::Value *above = sign ? b_.CreateICmpSGT(v, constant(target->hi))
                            : b_.CreateICmpUGT(v, constant(target->hi));
  emitTrapIf(b_.CreateOr(below, above, "range.bad"),
             "value out of range (" + target->name() + ")");
  return v;
}

/// The 256-bit constant whose set bits are exactly the values of `base`: the
/// bits from its first ordinal to its last. Built by shifting rather than
/// written as a literal, because a 256-bit literal is a number neither this
/// compiler's own source language nor its reader can spell — and LLVM folds
/// the shifts before they ever reach the target.
llvm::Value *CodeGen::setUniverse(ap::Type *base) {
  llvm::Value *ones = ConstantInt::getSigned(i256(), -1);
  uint64_t lo = static_cast<uint64_t>(base->ordinalLo());
  uint64_t hi = static_cast<uint64_t>(base->ordinalHi());
  // Clear the bits above hi, then the bits below lo. Sema has already refused
  // a base type outside 0..255, so neither shift can reach 256.
  llvm::Value *v = b_.CreateLShr(ones, ConstantInt::get(i256(), kSetLimit - hi));
  return b_.CreateAnd(v, b_.CreateShl(ones, ConstantInt::get(i256(), lo)),
                      "universe");
}

/// ISO 7185 §6.4.6 makes it an error to store a value that is not of the
/// variable's type, and a set carrying a member outside its base type is
/// exactly that. It is one `and` against the base type's universe: the check a
/// set constructor cannot make for itself, because a constructor does not know
/// what it is being assigned to.
llvm::Value *CodeGen::checkedForSetBase(llvm::Value *v, ap::Type *target) {
  if (!target || !target->isSet() || !target->elem)
    return v;
  ap::Type *base = target->elem;
  // A base type covering the whole 0..255 universe can hold anything a set
  // value can carry, so `set of char` pays nothing.
  if (base->ordinalLo() == 0 && base->ordinalHi() == kSetLimit)
    return v;
  llvm::Value *stray = b_.CreateAnd(v, b_.CreateNot(setUniverse(base)));
  emitTrapIf(b_.CreateICmpNE(stray, ConstantInt::get(i256(), 0), "set.stray"),
             "set member out of range (" + target->name() + ")");
  return v;
}

/// A member's position in the bit vector. Every set shares one 256-bit
/// representation, so the position must lie in 0..255 whatever the base type
/// is — a shift by more than that is poison in LLVM, and would be a silently
/// wrong answer here.
llvm::Value *CodeGen::setIndex(Expr *e, const char *what) {
  llvm::Value *v = emitExpr(e);
  bool sign = e->type->isSignedOrdinal();
  llvm::Type *ty = v->getType();
  if (sign) {
    llvm::Value *below =
        b_.CreateICmpSLT(v, ConstantInt::getSigned(ty, 0), "set.below");
    llvm::Value *above = b_.CreateICmpSGT(
        v, ConstantInt::getSigned(ty, kSetLimit), "set.above");
    emitTrapIf(b_.CreateOr(below, above), what);
  } else if (ty->getIntegerBitWidth() > 8) {
    emitTrapIf(b_.CreateICmpUGT(v, ConstantInt::get(ty, kSetLimit)), what);
  }
  return b_.CreateZExt(v, i256(), "bit");
}

llvm::Value *CodeGen::guardNonZero(llvm::Value *divisor, const char *message) {
  emitTrapIf(b_.CreateICmpEQ(divisor, ConstantInt::get(i32(), 0), "iszero"),
             message);
  return divisor;
}

// ------------------------------------------------------------------- driver

StructType *CodeGen::descriptorType(const Symbol *param) {
  SmallVector<llvm::Type *, 4> fields;
  fields.push_back(ptr()); // the actual's address
  for (const Symbol *d : param->descSchema->discriminants)
    fields.push_back(llvmType(d->type));
  return StructType::get(ctx_, fields);
}

/// A bound of an array: a constant where the source wrote one, and otherwise
/// the discriminant it names, read out of the descriptor.
/// How many bytes the tuple of a heap variable occupies in front of it. Every
/// discriminant is stored as an `i32` whatever its own type, so the header is
/// one number wide per discriminant — and it is rounded up to 16 so that the
/// variable itself keeps the alignment `malloc` gave the block. 16 rather than
/// 8 because a set is 256 bits and the target aligns one to 16 (ADR-0028).
unsigned CodeGen::headerSize(const ap::Type *t) {
  if (!t || !t->heapTuple || !t->schema)
    return 0;
  unsigned bytes = 4 * unsigned(t->schema->discriminants.size());
  return (bytes + 15) / 16 * 16;
}

/// The address of a heap variable's tuple, given the variable's own address.
/// Null for every type whose tuple is somewhere a symbol can name.
llvm::Value *CodeGen::headerOf(ap::Type *t, llvm::Value *base) {
  if (!base || !t || !t->heapTuple)
    return nullptr;
  return b_.CreateGEP(i8(), base,
                      {ConstantInt::getSigned(i32(), -int(headerSize(t)))},
                      "header");
}

/// The tuple governing a designator, found by walking to the whole variable it
/// selects from. One header serves every dimension — `g^[i][j]` reads `r` and
/// `c` out of the same one — and only the outermost designator has the address
/// it sits in front of, so an inner subscript cannot compute it from its own
/// base. Walking down is what stands in for threading it through.
llvm::Value *CodeGen::heapHeader(Expr *e) {
  while (true) {
    if (auto *ix = as<IndexExpr>(e)) { e = ix->base.get(); continue; }
    if (auto *f = as<FieldExpr>(e)) { e = f->base.get(); continue; }
    break;
  }
  if (!e->type || !e->type->heapTuple)
    return nullptr;
  return headerOf(e->type, emitAddress(e));
}

/// `header` is the tuple of the heap variable this type belongs to, and is
/// null for every other type — a schematic formal and a variable with
/// non-constant discriminants both keep theirs where a symbol can name it, and
/// `addressOf` reaches those by the walk every enclosing variable makes.
llvm::Value *CodeGen::boundValue(ap::Type *t, bool high, llvm::Value *header) {
  Symbol *disc = high ? t->hiDisc : t->loDisc;
  if (!disc)
    return ConstantInt::getSigned(i32(), high ? t->hi : t->lo);
  // Inside `new` the tuple has no home yet — the block it will live in front
  // of is the thing being sized — so the values are answered from the
  // arguments themselves. That is what keeps the size, the domain check and
  // every later read of the same bounds one piece of code.
  if (disc->heapDisc && newTuple_ &&
      size_t(disc->discIndex) < newTuple_->size())
    return (*newTuple_)[disc->discIndex];
  llvm::Value *at = disc->heapDisc
                        ? b_.CreateGEP(i32(), header,
                                       {ConstantInt::get(i32(), disc->discIndex)},
                                       disc->name)
                        : addressOf(disc);
  llvm::Value *v =
      b_.CreateLoad(disc->heapDisc ? i32() : llvmType(disc->type), at,
                    disc->name);
  // A discriminant may be of any ordinal type, and the index arithmetic is
  // done in the integer type as it always is.
  if (v->getType() != i32())
    v = b_.CreateZExt(v, i32(), "disc.wide");
  return v;
}

/// The k'th discriminant of the tuple this expression's type was produced
/// with. A generic type belongs to one variable — nothing else can be given
/// it, and a subscript of one would already have yielded the component — so an
/// expression possessing one *is* that variable, and its tuple is in the
/// descriptor. Every other type produced from a schema was produced from
/// constants, and they are on the Type.
llvm::Value *CodeGen::discValue(Expr *e, size_t k, llvm::Type *want) {
  ap::Type *t = e->type;
  // A heap variable carries its tuple in front of it, so any designator of one
  // answers — not only a name, since `p^` is not a name and `q^.next^` is not
  // even a pointer variable.
  if (t->heapTuple) {
    llvm::Value *hdr = headerOf(t, emitAddress(e));
    llvm::Value *v = b_.CreateLoad(
        i32(), b_.CreateGEP(i32(), hdr, {ConstantInt::get(i32(), k)}), "disc");
    return want == i32() ? v : b_.CreateTrunc(v, want);
  }
  if (t->isGeneric())
    if (auto *v = as<VarRef>(e))
      if (v->sym && k < v->sym->discSyms.size())
        return b_.CreateLoad(want, addressOf(v->sym->discSyms[k]),
                             v->sym->discSyms[k]->name);
  return ConstantInt::getSigned(want,
                                k < t->tuple.size() ? t->tuple[k] : 0);
}

/// How many components an array has, as a *value*. `Type::length()` is
/// `hi - lo + 1` and answers only for an array whose bounds are numbers; where
/// they are discriminants it returns arithmetic on the placeholders, which is
/// a number and therefore not obviously wrong. Everything that needs a length
/// rather than a size comes through here instead.
llvm::Value *CodeGen::dynLength(ap::Type *t, llvm::Value *header) {
  if (!t->dynamicBounds())
    return ConstantInt::get(i32(), t->length());
  return b_.CreateAdd(b_.CreateSub(boundValue(t, true, header),
                                   boundValue(t, false, header), "extent"),
                      ConstantInt::get(i32(), 1), "length");
}

llvm::Value *CodeGen::dynSize(ap::Type *t, llvm::Value *header) {
  if (!t->dynamicExtent())
    return ConstantInt::get(i32(), sizeOf(t));
  // A record's dynamic part is its last field and nothing else (ADR-0045), so
  // every offset in it is a constant and the size is the last field's offset
  // plus whatever the tail costs. The offset comes from the struct's own
  // layout, which is right because the dynamic field is `[0 x T]` there.
  if (t->isRecord()) {
    auto *st = cast<StructType>(llvmType(t));
    unsigned last = static_cast<unsigned>(t->fields.size()) - 1;
    llvm::Value *size = b_.CreateAdd(
        ConstantInt::get(
            i32(), mod_->getDataLayout().getStructLayout(st)->getElementOffset(
                       last)),
        dynSize(t->fields[last].type, header), "recsize");
    // An array of these strides by the size, so it is rounded up to the
    // record's alignment exactly as a static record's allocation size is.
    uint64_t align = mod_->getDataLayout().getABITypeAlign(st).value();
    return b_.CreateAnd(
        b_.CreateAdd(size, ConstantInt::get(i32(), align - 1)),
        ConstantInt::getSigned(i32(), -static_cast<int64_t>(align)), "aligned");
  }
  // (hi - lo + 1) components, each of whatever one component costs. The count
  // cannot be negative: the tuple that produced the actual's type was checked
  // when it was produced, so an empty range never reaches here.
  llvm::Value *count = b_.CreateAdd(boundValue(t, true, header), ConstantInt::get(i32(), 1));
  count = b_.CreateSub(count, boundValue(t, false, header), "count");
  // One header serves every level: an array of dynamically-bounded arrays has
  // one tuple, and the inner bounds are other discriminants of it.
  return b_.CreateMul(count, dynSize(t->elem, header), "size");
}

llvm::Type *CodeGen::slotType(const Symbol *v) {
  // A schematic formal parameter's slot holds the whole descriptor: the
  // address, and the tuple that says how far the thing at it reaches.
  if (v->descSchema)
    return descriptorType(v);
  // A `var` parameter's slot holds the address of the caller's variable, not
  // a copy of its value. Everything else — including a structured value
  // parameter, which the prologue copies in — holds the value itself.
  return v->kind == SymKind::VarParam ? ptr() : llvmType(v->type);
}

llvm::Type *CodeGen::paramType(const Symbol *v) {
  return passedByAddress(v) ? ptr() : llvmType(v->type);
}

/// The LLVM parameters one Pascal parameter list contributes, after the static
/// link. Every parameter is one argument except a procedural one, which is two
/// — the code and the link it needs — so a caller and a callee agree on the
/// shape only by both coming through here.
void CodeGen::appendParamTypes(const std::vector<Symbol *> &params,
                               SmallVectorImpl<llvm::Type *> &into) {
  for (const Symbol *p : params) {
    if (p->kind == SymKind::ProcParam) {
      into.push_back(ptr()); // the code
      into.push_back(ptr()); // the static link to call it with
    } else if (p->descSchema) {
      // The address, and then the tuple: one argument per discriminant, so
      // the descriptor is assembled by the callee and never passed as a
      // struct.
      into.push_back(ptr());
      for (const Symbol *d : p->descSchema->discriminants)
        into.push_back(llvmType(d->type));
    } else {
      into.push_back(paramType(p));
    }
  }
}

llvm::FunctionType *CodeGen::procFnType(const Symbol *p) {
  SmallVector<llvm::Type *, 8> params;
  params.push_back(ptr()); // the static link
  appendParamTypes(p->params, params);
  ap::Type *result = p->type ? p->type->elem : nullptr;
  return FunctionType::get(result ? llvmType(result)
                                  : llvm::Type::getVoidTy(ctx_),
                           params, false);
}

StructType *CodeGen::buildFrameType(Symbol *proc) {
  SmallVector<llvm::Type *, 8> fields;
  fields.push_back(ptr()); // field 0: the static link
  for (const Symbol *v : proc->frameVars)
    fields.push_back(slotType(v));
  // A block reachable by a non-local `goto` carries the jump record after its
  // variables. It is last so that no frame index moves, and it is not a
  // frameVar because nothing in the source can name it: the prologue arms it,
  // the epilogue disarms it, and a goto in a nested block reaches it by
  // walking the static chain (ADR-0032).
  if (!proc->nonLocalLabels.empty())
    fields.push_back(jumpRecordType());
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
    appendParamTypes(sym->params, params);

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
  // A label belongs to exactly one block, so the map is emptied per function.
  // Sema numbers labels across the whole program, so a stale entry would never
  // be *matched* — this bounds what is kept, and is not what makes the block
  // numbers right.
  labelBlocks_.clear();
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
    // Hand the command line to the runtime before any file is opened: it is
    // where `reset` looks for the name of an external file.
    b_.CreateCall(rt("pas_args", llvm::Type::getVoidTy(ctx_), {i32(), ptr()}),
                  {fn->getArg(0), fn->getArg(1)});
  } else {
    arg->setName("static.link");
    b_.CreateStore(&*arg, b_.CreateStructGEP(frameTy, curFrame_, 0, "link"));
    ++arg;
    for (const Symbol *p : proc->params) {
      arg->setName(p->name);
      llvm::Value *slot =
          b_.CreateStructGEP(frameTy, curFrame_, 1 + p->frameIndex, p->name);
      if (p->descSchema) {
        // The tuple is stored first, because everything about the size of
        // what the address points at is asked of it — including, for a value
        // parameter, how much to copy.
        StructType *desc = descriptorType(p);
        llvm::Value *actual = &*arg;
        for (size_t k = 0; k < p->discSyms.size(); ++k) {
          ++arg;
          arg->setName(p->name + "." + p->discSyms[k]->name);
          b_.CreateStore(&*arg, b_.CreateStructGEP(desc, slot, 1 + unsigned(k),
                                                   p->discSyms[k]->name));
        }
        b_.CreateStore(actual, b_.CreateStructGEP(desc, slot, 0, "actual"));
        if (p->kind != SymKind::VarParam) {
          // A value parameter is a copy, and this one's size is not known
          // until the tuple is in place — so the storage is claimed here
          // rather than in the frame, and dies with the activation as the
          // frame does.
          ap::Type *comp = p->type;
          while (comp->isArray())
            comp = comp->elem;
          Align align = mod_->getDataLayout().getABITypeAlign(llvmType(comp));
          llvm::Value *size = dynSize(p->type);
          AllocaInst *copy = b_.CreateAlloca(i8(), size, p->name + ".copy");
          copy->setAlignment(align);
          b_.CreateMemCpy(copy, align, actual, align, size);
          b_.CreateStore(copy, b_.CreateStructGEP(desc, slot, 0, "actual"));
        }
      } else if (p->kind == SymKind::ProcParam) {
        // Two arguments, one slot: the pair is assembled here and never exists
        // as an LLVM value.
        StructType *pair = procPairType();
        b_.CreateStore(&*arg, b_.CreateStructGEP(pair, slot, 0, "code"));
        ++arg;
        arg->setName(p->name + ".link");
        b_.CreateStore(&*arg, b_.CreateStructGEP(pair, slot, 1, "link"));
      } else if (p->kind != SymKind::VarParam && p->type->isStructured()) {
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

  // After the parameters, because a discriminant may be one of them, and
  // before anything that could jump: the storage a dynamically sized variable
  // stands for has to exist for the whole activation.
  initDynamicVars(proc);
  initFiles(proc);
  emitJumpDispatch(proc);
}

void CodeGen::checkSchemaDomain(ap::Type *t, const std::string &schema,
                                llvm::Value *header) {
  if (!t || !t->dynamicExtent())
    return;
  // A record reaches here only with its dynamic part last (ADR-0045), so the
  // walk into it is the same walk: one dimension per level, wherever the level
  // came from.
  if (t->isRecord()) {
    checkSchemaDomain(t->fields.back().type, schema, header);
    return;
  }
  if (t->dynamicBounds())
    emitTrapIf(b_.CreateICmpSLT(boundValue(t, true, header),
                                boundValue(t, false, header), "empty"),
               "no type is produced from schema '" + schema +
                   "' with these discriminants");
  checkSchemaDomain(t->elem, schema, header);
}

/// §6.2.3.2: the actual-discriminant-part of a variable is evaluated when the
/// block is entered. The tuple goes into the descriptor first, because
/// everything after it — the domain check, the size, the storage — is asked of
/// the descriptor and not of the expressions that filled it.
void CodeGen::initDynamicVars(Symbol *proc) {
  for (Symbol *v : proc->frameVars) {
    if (!v->descSchema || v->discExprs.empty())
      continue;
    StructType *desc = descriptorType(v);
    llvm::Value *slot = b_.CreateStructGEP(frameTypes_[proc], curFrame_,
                                           1 + v->frameIndex, v->name);
    for (size_t k = 0; k < v->discExprs.size() && k < v->discSyms.size(); ++k) {
      Symbol *d = v->discSyms[k];
      llvm::Value *value = emitExpr(v->discExprs[k]);
      value = convertFor(value, v->discExprs[k]->type, d->type);
      // A discriminant outside its own type is outside §6.4.7's domain. The
      // store is where a value enters a variable, so the check that guards
      // every other such store is the one that says so here too.
      value = checkedForStore(value, d->type);
      b_.CreateStore(value, b_.CreateStructGEP(desc, slot, 1 + unsigned(k),
                                               d->name));
    }
    checkSchemaDomain(v->type, v->descSchema->name);
    ap::Type *comp = v->type;
    while (comp->isArray())
      comp = comp->elem;
    Align align = mod_->getDataLayout().getABITypeAlign(llvmType(comp));
    AllocaInst *storage =
        b_.CreateAlloca(i8(), dynSize(v->type), v->name + ".storage");
    storage->setAlignment(align);
    b_.CreateStore(storage, b_.CreateStructGEP(desc, slot, 0, "storage"));
  }
}

llvm::Value *CodeGen::jumpRecord(Symbol *proc, llvm::Value *frame) {
  return b_.CreateStructGEP(frameTypes_[proc], frame,
                            1 + proc->frameVars.size(), "jump");
}

/// The target's half of a non-local `goto`. The record is armed first — which
/// notes the files the block already has open, so a later jump knows which
/// ones it abandons — and then `_setjmp` is called *here*, in the function
/// that owns the frame. It cannot be called through a runtime wrapper: the
/// wrapper would have returned by the time the jump arrived, and its frame is
/// what `_setjmp` recorded.
///
/// A label arrives as its own id plus one, because `_longjmp` with zero would
/// come back looking like the ordinary entry to the block.
void CodeGen::emitJumpDispatch(Symbol *proc) {
  if (proc->nonLocalLabels.empty())
    return;

  llvm::Value *record = jumpRecord(proc, curFrame_);
  llvm::Value *env =
      b_.CreateCall(rt("pas_jump_env", ptr(), {ptr()}), {record}, "env");

  FunctionCallee sj = rt("_setjmp", i32(), {ptr()});
  // LLVM does *not* infer this from the name. Without it the call looks like
  // an ordinary one: a value may be kept in a register across it that the jump
  // will not restore, and the function containing it may be inlined into one
  // whose frame `_setjmp` never recorded.
  if (auto *fn = dyn_cast<Function>(sj.getCallee()))
    fn->addFnAttr(Attribute::ReturnsTwice);
  CallInst *arrived = b_.CreateCall(sj, {env}, "arrived");
  arrived->addFnAttr(Attribute::ReturnsTwice);

  BasicBlock *body = BasicBlock::Create(ctx_, "entry.body", curFn_);
  SwitchInst *sw = b_.CreateSwitch(arrived, body,
                                   proc->nonLocalLabels.size());
  for (int id : proc->nonLocalLabels)
    sw->addCase(cast<ConstantInt>(ConstantInt::get(i32(), id + 1)),
                labelBlock(id));
  b_.SetInsertPoint(body);
}

/// Every file variable the frame holds starts closed, and knows how `reset`
/// and `rewrite` will find the external file it stands for. The standard
/// files are opened here — ISO 7185 §6.10 has `input` reset and `output`
/// rewritten before the program body runs — but no character is read until
/// the program asks for one, or a program that never reads would hang waiting
/// for a terminal.
void CodeGen::initFiles(Symbol *proc) {
  llvm::Type *voidTy = llvm::Type::getVoidTy(ctx_);
  for (Symbol *v : proc->frameVars) {
    if (!v->type || !v->type->isFile() || v->kind == SymKind::VarParam)
      continue; // a var parameter is someone else's file
    int binding = PAS_BIND_INTERNAL;
    switch (v->fileBinding) {
    case FileBinding::StandardInput:  binding = PAS_BIND_INPUT; break;
    case FileBinding::StandardOutput: binding = PAS_BIND_OUTPUT; break;
    case FileBinding::Argument:       binding = PAS_BIND_ARG; break;
    case FileBinding::Internal:       binding = PAS_BIND_INTERNAL; break;
    }
    // The component type is the whole of what the runtime needs to know about
    // a `file of T`: how many bytes one component is, and whether the file has
    // the line structure only a `text` has.
    uint64_t comp = v->type->elem ? sizeOf(v->type->elem) : 1;
    b_.CreateCall(
        rt("pas_file_init", voidTy,
           {ptr(), i32(), i32(), ptr(), i32(), i32()}),
        {addressOf(v), ConstantInt::get(i32(), binding),
         ConstantInt::get(i32(), v->fileArg),
         b_.CreateGlobalString(v->name, "file.name"),
         ConstantInt::get(i32(), comp),
         ConstantInt::get(i32(), v->type->isText() ? 1 : 0)});
  }
}

/// A block exit closes the files the block declared, which is ISO 7185's rule
/// and also the only thing that flushes a file written to inside a procedure.
/// Pascal has no early return, so the single exit point each body ends with is
/// the whole of the epilogue — and a `goto` does not change that: a local one
/// cannot leave the block, and a non-local one runs this same work for every
/// block it abandons, from the runtime rather than from here (ADR-0032).
///
/// Disarming the jump record is part of the same exit. Nothing the compiler
/// accepts can reach a dead frame — the static chain only names live ones —
/// so it buys a diagnosable error rather than a jump into reclaimed stack.
void CodeGen::closeFiles(Symbol *proc) {
  llvm::Type *voidTy = llvm::Type::getVoidTy(ctx_);
  for (Symbol *v : proc->frameVars) {
    if (!v->type || !v->type->isFile() || v->kind == SymKind::VarParam)
      continue;
    b_.CreateCall(rt("pas_file_done", voidTy, {ptr()}), {addressOf(v)});
  }
  if (!proc->nonLocalLabels.empty())
    b_.CreateCall(rt("pas_jump_done", voidTy, {ptr()}),
                  {jumpRecord(proc, curFrame_)});
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
  closeFiles(sym);

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
  // A discriminant lives inside the descriptor of the parameter it belongs
  // to, so it is reached through that parameter's slot — which means the
  // walk up the static chain is the same one every enclosing variable makes,
  // and a recursive procedure sees the tuple of the invocation it is running.
  if (v->kind == SymKind::Disc) {
    Symbol *param = v->owner->frameVars[v->frameIndex];
    return b_.CreateStructGEP(descriptorType(param), frameSlot(v),
                              1 + unsigned(v->discIndex), v->name);
  }
  llvm::Value *slot = frameSlot(v);
  // A schematic formal parameter's slot is its descriptor, and the variable
  // is at the address the descriptor's first field holds — for a `var`
  // parameter the actual, and for a value parameter the prologue's copy of it.
  if (v->descSchema)
    return b_.CreateLoad(ptr(), b_.CreateStructGEP(descriptorType(v), slot, 0),
                         v->name + ".ref");
  // A `var` parameter — and the binding of a `with` — holds an address, so the
  // variable it stands for is one load further on.
  if (v->kind == SymKind::VarParam)
    slot = b_.CreateLoad(ptr(), slot, v->name + ".ref");
  return slot;
}

/// A field of the fixed part is one index into the record. A field of a
/// variant is two: to the shared storage, then into the arm laid over it.
llvm::Value *CodeGen::fieldAddress(llvm::Value *record, ap::Type *type,
                                   const Field *field) {
  // Walk down the field's path. At each step the shared storage is the last
  // member of the struct we are in, and the arm laid over it starts at the
  // same address — so stepping in is one GEP, not two.
  llvm::Value *p = record;
  std::vector<int> prefix;
  for (int k : field->variant) {
    unsigned storage = static_cast<unsigned>(fieldsAt(type, prefix).size());
    p = b_.CreateStructGEP(cast<StructType>(structAt(type, prefix)), p, storage,
                           "variant");
    prefix.push_back(k);
  }
  return b_.CreateStructGEP(cast<StructType>(structAt(type, prefix)), p,
                            field->index, field->name);
}

/// Every read and every write goes through here, so a subscript is bounds
/// checked exactly once however it is used.
llvm::Value *CodeGen::emitAddress(Expr *e) {
  switch (e->kind) {
  case NK::VarRef: {
    auto *v = static_cast<VarRef *>(e);
    llvm::Value *base = addressOf(v->sym);
    if (!v->withField)
      return base;
    // The name was a field of an enclosing `with`, and `sym` is that
    // statement's binding — the record's address, taken once on entry.
    return fieldAddress(base, v->sym->type, v->withField);
  }

  case NK::Field: {
    auto *f = static_cast<FieldExpr *>(e);
    return fieldAddress(emitAddress(f->base.get()), f->base->type, f->resolved);
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
    // A heap variable's tuple sits in front of the *variable*, so the bounds
    // come from there rather than from any activation record — and for an
    // inner dimension that is not the address just computed.
    llvm::Value *hdr = heapHeader(ix->base.get());
    llvm::Value *lo = boundValue(arr, false, hdr);
    llvm::Value *hi = boundValue(arr, true, hdr);
    llvm::Value *outside =
        b_.CreateOr(b_.CreateICmpSLT(idx, lo, "idx.lt"),
                    b_.CreateICmpSGT(idx, hi, "idx.gt"), "idx.bad");
    // The message names the bounds, so a schematic array's has to be built
    // where the bounds are known — which is at run time, in the runtime.
    if (arr->dynamicBounds())
      emitTrapCall(outside, rt("pas_index_error",
                               llvm::Type::getVoidTy(ctx_), {i32(), i32()}),
                   {lo, hi});
    else
      emitTrapIf(outside, "array index out of bounds (" +
                              std::to_string(arr->lo) + ".." +
                              std::to_string(arr->hi) + ")");

    llvm::Value *offset = b_.CreateSub(idx, lo, "idx.off");
    // An array whose extent is not known until the block is entered has no
    // LLVM array type to index: the component's size is what the descriptor
    // answers, so the address is computed in bytes. The arithmetic is the
    // same `(i - lo) * stride` the two-index GEP stands for.
    if (arr->dynamicExtent())
      return b_.CreateGEP(
          i8(), base, {b_.CreateMul(offset, dynSize(arr->elem, hdr), "byte")},
          "elem");
    return b_.CreateGEP(llvmType(arr), base,
                        {ConstantInt::get(i32(), 0), offset}, "elem");
  }

  case NK::Deref: {
    auto *d = static_cast<DerefExpr *>(e);
    // `f^` on a file is the buffer variable, not a dereference: the runtime
    // owns it, so it hands back its address — and fetches the character it
    // holds first, which is where the lookahead actually happens.
    if (d->base->type && d->base->type->isFile())
      return b_.CreateCall(rt("pas_buffer", ptr(), {ptr()}),
                           {emitAddress(d->base.get())}, "buf");
    // The pointer's *value* is the address of the variable it denotes.
    llvm::Value *target = emitExpr(d->base.get());
    // ISO 7185 §6.5.4 makes it an error to dereference nil. Nothing can
    // detect a pointer to storage already disposed of, but this much is
    // cheap and catches the common mistake.
    emitTrapIf(b_.CreateIsNull(target, "isnil"),
               "dereference of nil");
    return target;
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
  if (e->type->isMemory())
    return addr;
  return b_.CreateLoad(llvmType(e->type), addr, "val");
}

void CodeGen::emitCopy(llvm::Value *dst, ap::Type *type, Expr *src) {
  emitCopy(dst, type, emitAddress(src));
}

void CodeGen::emitCopy(llvm::Value *dst, ap::Type *type,
                       llvm::Value *srcAddr) {
  Align align = mod_->getDataLayout().getABITypeAlign(llvmType(type));
  b_.CreateMemCpy(dst, align, srcAddr, align, sizeOf(type));
}

llvm::Value *CodeGen::staticLinkFor(Symbol *callee) {
  // A callee declared at level L runs with the frame at level L-1 as its
  // enclosing scope — which for a recursive call is the caller's own parent,
  // not the caller.
  return frameAt(callee->level - 1);
}

/// The pair a procedural argument travels as. Naming a procedure with a body
/// takes its address and the frame it was *declared* under; naming a
/// procedural parameter forwards the pair that parameter already holds, so a
/// procedure handed on through three levels still runs in its own scope.
void CodeGen::emitProcArgument(Symbol *actual,
                               SmallVectorImpl<llvm::Value *> &argv) {
  if (actual->kind == SymKind::ProcParam) {
    llvm::Value *slot = frameSlot(actual);
    StructType *pair = procPairType();
    argv.push_back(b_.CreateLoad(ptr(), b_.CreateStructGEP(pair, slot, 0),
                                 actual->name + ".code"));
    argv.push_back(b_.CreateLoad(ptr(), b_.CreateStructGEP(pair, slot, 1),
                                 actual->name + ".link"));
    return;
  }
  argv.push_back(functions_[actual]);
  argv.push_back(staticLinkFor(actual));
}

llvm::Value *CodeGen::emitUserCall(Symbol *callee, std::vector<ExprPtr> &args) {
  SmallVector<llvm::Value *, 8> argv;
  llvm::Value *target = nullptr;
  llvm::FunctionType *fnTy = nullptr;

  if (callee->kind == SymKind::ProcParam) {
    // The link to run under comes out of the pair, not from the static chain:
    // the caller's chain says nothing about where the passed procedure was
    // declared, which is the reason the link had to be carried at all.
    llvm::Value *slot = frameSlot(callee);
    StructType *pair = procPairType();
    target = b_.CreateLoad(ptr(), b_.CreateStructGEP(pair, slot, 0),
                           callee->name + ".code");
    argv.push_back(b_.CreateLoad(ptr(), b_.CreateStructGEP(pair, slot, 1),
                                 callee->name + ".link"));
    fnTy = procFnType(callee);
  } else {
    target = functions_[callee];
    fnTy = functions_[callee]->getFunctionType();
    argv.push_back(staticLinkFor(callee));
  }

  for (size_t i = 0; i < args.size(); ++i) {
    const Symbol *p = callee->params[i];
    if (p->kind == SymKind::ProcParam) {
      emitProcArgument(static_cast<VarRef *>(args[i].get())->sym, argv);
    } else if (p->descSchema) {
      // The address, then the tuple the actual was produced with — constants
      // where the actual is an ordinary variable, and the caller's own
      // descriptor where it is itself a schematic formal, which is how a
      // schematic array is handed on through any number of blocks.
      argv.push_back(emitAddress(args[i].get()));
      for (size_t k = 0; k < p->descSchema->discriminants.size(); ++k)
        argv.push_back(discValue(args[i].get(), k,
                                 llvmType(p->descSchema->discriminants[k]->type)));
    } else if (passedByAddress(p)) {
      // A `var` parameter binds to the variable itself; a structured value
      // parameter is copied from it by the callee. Either way what travels is
      // an address, and Sema has already required something that has one.
      argv.push_back(emitAddress(args[i].get()));
    } else {
      llvm::Value *v = emitExpr(args[i].get());
      v = convertFor(v, args[i]->type, p->type);
      argv.push_back(checkedForStore(v, p->type));
    }
  }
  return b_.CreateCall(fnTy, target, argv,
                       fnTy->getReturnType()->isVoidTy() ? "" : "call");
}

std::unique_ptr<Module> CodeGen::run(Program &prog) {
  Symbol *programSym = sema_.programSymbol();
  buildFrameType(programSym);
  declareProcs(*prog.block);

  // main takes the command line, because ISO 7185 §6.10 leaves it to the
  // implementation to say how a program parameter names an external file and
  // this one binds them to the arguments, in the order they are written.
  FunctionType *mainTy = FunctionType::get(i32(), {i32(), ptr()}, false);
  Function *mainFn =
      Function::Create(mainTy, Function::ExternalLinkage, "main", mod_.get());
  mainFn->getArg(0)->setName("argc");
  mainFn->getArg(1)->setName("argv");

  enterFrame(programSym, mainFn);
  emitStmt(prog.block->body.get());
  closeFiles(programSym);
  b_.CreateRet(ConstantInt::get(i32(), 0));

  emitProcs(*prog.block);

  if (verifyModule(*mod_, &errs()))
    return nullptr;
  return std::move(mod_);
}

// ---------------------------------------------------------------- statements

/// The block a label denotes. Created on first mention, which may be either
/// the labelled statement or a goto to it — a forward jump reaches here before
/// the statement it targets exists.
llvm::BasicBlock *CodeGen::labelBlock(int id) {
  auto found = labelBlocks_.find(id);
  if (found != labelBlocks_.end())
    return found->second;
  BasicBlock *bb =
      BasicBlock::Create(ctx_, "L" + std::to_string(id), curFn_);
  labelBlocks_[id] = bb;
  return bb;
}

/// A labelled statement is its own basic block, entered by falling into it as
/// well as by jumping to it — so the preceding code branches there rather than
/// running on, which is what makes the label a join point rather than a second
/// entry to the same block.
void CodeGen::emitLabeled(LabeledStmt *l) {
  if (l->id < 0) { // Sema reported an undeclared label; emit the body anyway
    emitStmt(l->body.get());
    return;
  }
  BasicBlock *bb = labelBlock(l->id);
  b_.CreateBr(bb);
  b_.SetInsertPoint(bb);
  emitStmt(l->body.get());
}

/// Anything written after a goto is unreachable, but it is still *code*: a
/// statement may follow it in the same sequence, and LLVM requires it to live
/// in a block of its own rather than after a terminator.
void CodeGen::emitGoto(GotoStmt *g) {
  if (g->id < 0)
    return; // Sema has already reported it
  if (g->nonLocal && g->owner) {
    // Out of this block altogether. The target's activation is the one on this
    // procedure's static chain, which for a recursive enclosing procedure is
    // the invocation this one was called from — the same rule every other
    // access to an enclosing frame follows (ADR-0016). The runtime closes the
    // abandoned blocks' files before cutting the stack back.
    llvm::Value *record = jumpRecord(g->owner, frameAt(g->owner->level));
    b_.CreateCall(rt("pas_jump_go", llvm::Type::getVoidTy(ctx_),
                     {ptr(), i32()}),
                  {record, ConstantInt::get(i32(), g->id + 1)});
    b_.CreateUnreachable();
    b_.SetInsertPoint(BasicBlock::Create(ctx_, "after.goto", curFn_));
    return;
  }
  b_.CreateBr(labelBlock(g->id));
  b_.SetInsertPoint(BasicBlock::Create(ctx_, "after.goto", curFn_));
}

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
  case NK::Read:    emitRead(static_cast<ReadStmt *>(s)); return;
  case NK::If:      emitIf(static_cast<IfStmt *>(s)); return;
  case NK::While:   emitWhile(static_cast<WhileStmt *>(s)); return;
  case NK::Repeat:  emitRepeat(static_cast<RepeatStmt *>(s)); return;
  case NK::For:     emitFor(static_cast<ForStmt *>(s)); return;
  case NK::With:    emitWith(static_cast<WithStmt *>(s)); return;
  case NK::Case:    emitCase(static_cast<CaseStmt *>(s)); return;
  case NK::Goto:    emitGoto(static_cast<GotoStmt *>(s)); return;
  case NK::Labeled: emitLabeled(static_cast<LabeledStmt *>(s)); return;
  case NK::ProcCall: {
    auto *call = static_cast<ProcCallStmt *>(s);
    if (call->standard != StdProc::None)
      emitStdProc(call);
    else
      emitUserCall(call->sym, call->args);
    return;
  }
  default:
    return; // expression kinds never appear as statements
  }
}

void CodeGen::emitStore(llvm::Value *dst, ap::Type *type, Expr *src) {
  // A whole array or record is copied; ISO 7185 §6.8.2.2 makes assignment of a
  // structured value a copy of every component, not a sharing of storage.
  if (type->isStructured()) {
    emitCopy(dst, type, src);
    return;
  }
  llvm::Value *v = emitExpr(src);
  v = convertFor(v, src->type, type);
  b_.CreateStore(checkedForStore(v, type), dst);
}

/// §6.4.6 d): where both types were produced from one schema but the tuples
/// are not both known, whether they are the same type is a question only the
/// running program can answer. Sema let the assignment through on the schema
/// alone, so this is where the tuples meet — and once they agree the copy is
/// the ordinary whole-variable one with a length that is computed rather than
/// written.
void CodeGen::emitAssign(Assign *s) {
  llvm::Value *dst = emitAddress(s->target.get());
  ap::Type *type = s->target->type;
  if (type->schema && (type->isGeneric() || s->value->type->isGeneric())) {
    emitTupleCheck(s->target.get(), s->value.get());
    llvm::Value *src = emitAddress(s->value.get());
    // The alignment is the component's, for the same reason a schematic value
    // parameter's copy takes it from there: the array type LLVM would be asked
    // about has no extent to give.
    ap::Type *comp = type;
    while (comp->isArray())
      comp = comp->elem;
    Align align = mod_->getDataLayout().getABITypeAlign(llvmType(comp));
    // The length is the *destination's*, which the tuple check has just shown
    // to be the source's too — and for a variable created by `new` it is read
    // from the header in front of it rather than from a descriptor.
    b_.CreateMemCpy(dst, align, src, align,
                    dynSize(type, headerOf(type, dst)));
    return;
  }
  emitStore(dst, type, s->value.get());
}

/// Two types produced from one schema are the same type exactly when they were
/// produced with the same tuple (§6.4.8), so that is the comparison — one per
/// discriminant, whatever the body did with them. The message is built by the
/// runtime because the values are known only there, while the names are known
/// only here.
void CodeGen::emitTupleCheck(Expr *dst, Expr *src) {
  const Symbol *schema = dst->type->schema;
  llvm::Value *name = b_.CreateGlobalString(schema->name, "schema");
  for (size_t k = 0; k < schema->discriminants.size(); ++k) {
    const Symbol *d = schema->discriminants[k];
    llvm::Type *want = llvmType(d->type);
    llvm::Value *l = discValue(dst, k, want);
    llvm::Value *r = discValue(src, k, want);
    // A discriminant may be of any ordinal type; the message reports it as a
    // number, which is what its ordinal is.
    llvm::Value *lw = l->getType() == i32() ? l : b_.CreateZExt(l, i32());
    llvm::Value *rw = r->getType() == i32() ? r : b_.CreateZExt(r, i32());
    emitTrapCall(b_.CreateICmpNE(l, r, "tuple.bad"),
                 rt("pas_disc_error", llvm::Type::getVoidTy(ctx_),
                    {ptr(), ptr(), i32(), i32()}),
                 {name, b_.CreateGlobalString(d->name, "disc"), lw, rw});
  }
}

/// `new(p)` gives p the address of fresh storage for one variable of its
/// domain; `dispose(p)` gives that storage back. The size is a compile-time
/// constant because the domain type is.
void CodeGen::emitStdProc(ProcCallStmt *s) {
  Expr *arg = s->args[0].get();
  llvm::Value *slot = emitAddress(arg);
  llvm::Type *voidTy = llvm::Type::getVoidTy(ctx_);

  // The file primitives are one runtime call each on the file's address.
  const char *fileOp = nullptr;
  switch (s->standard) {
  case StdProc::Reset:   fileOp = "pas_reset"; break;
  case StdProc::Rewrite: fileOp = "pas_rewrite"; break;
  case StdProc::Get:     fileOp = "pas_get"; break;
  case StdProc::Put:     fileOp = "pas_put"; break;
  default: break;
  }
  if (fileOp) {
    b_.CreateCall(rt(fileOp, voidTy, {ptr()}), {slot});
    return;
  }

  ap::Type *domain = arg->type ? arg->type->elem : nullptr;

  // §6.7.5.3's other form of `new`: the arguments are the tuple the created
  // variable's type is produced with. The tuple has to exist before the size
  // can be asked of it, so it is built in a local header first, the size and
  // the domain check are made against *that*, and it is copied in front of the
  // variable once there is a block to copy it into.
  if (s->standard == StdProc::New && domain && domain->heapTuple) {
    const std::vector<Symbol *> &formals = domain->schema->discriminants;
    unsigned n = unsigned(formals.size());
    std::vector<llvm::Value *> tuple;
    for (unsigned k = 0; k < n && k + 1 < s->args.size(); ++k) {
      llvm::Value *v = emitExpr(s->args[k + 1].get());
      v = convertFor(v, s->args[k + 1]->type, formals[k]->type);
      // A discriminant outside its own type is outside §6.4.7's domain, and
      // this is where the value enters the variable that holds it — so the
      // check that guards every other such store makes this one too.
      v = checkedForStore(v, formals[k]->type);
      if (v->getType() != i32())
        v = b_.CreateZExt(v, i32(), "disc.wide");
      tuple.push_back(v);
    }

    // The size is asked of the tuple before there is anywhere to put the
    // tuple, so for the length of these two calls the bounds are answered
    // from the values rather than from a header. No scratch storage exists —
    // which is what lets a sequential emitter do this at all, since it could
    // not go back and put an alloca in the entry block.
    newTuple_ = &tuple;
    // §6.7.5.3: it shall be a dynamic-violation if the tuple is not in the
    // domain of the schema — the same check a variable's tuple gets on entry.
    checkSchemaDomain(domain, domain->schema->name);
    unsigned head = headerSize(domain);
    llvm::Value *size = b_.CreateAdd(dynSize(domain),
                                     ConstantInt::get(i32(), head), "blocksize");
    newTuple_ = nullptr;

    llvm::Value *block = b_.CreateCall(
        rt("pas_new", ptr(), {i64()}),
        {b_.CreateZExt(size, i64(), "blocksize.wide")}, "new");
    for (unsigned k = 0; k < tuple.size(); ++k)
      b_.CreateStore(tuple[k], b_.CreateGEP(i32(), block,
                                            {ConstantInt::get(i32(), k)},
                                            formals[k]->name));
    // The pointer denotes the *variable*, not the block, so everything else
    // about a pointer — assignment, comparison with nil, dereference — is
    // unchanged, and only `new` and `dispose` know the header is there.
    b_.CreateStore(
        b_.CreateGEP(i8(), block, {ConstantInt::get(i32(), head)}, "var"),
        slot);
    return;
  }

  if (s->standard == StdProc::New) {
    // ISO 7185 §6.6.5.3: with tag values, only the selected variants have to
    // fit. Without them the whole record does.
    llvm::Value *size = ConstantInt::get(
        i64(), s->variantSelection.empty()
                   ? sizeOf(arg->type->elem)
                   : selectedSize(arg->type->elem, {}, s->variantSelection, 0));
    llvm::Value *block =
        b_.CreateCall(rt("pas_new", ptr(), {i64()}), {size}, "new");
    b_.CreateStore(block, slot);
    return;
  }

  llvm::Value *block = b_.CreateLoad(ptr(), slot, "old");
  // What was allocated is the header and the variable together, so what is
  // given back has to be the block rather than the variable.
  if (unsigned head = headerSize(domain)) {
    // ISO 7185 §6.6.5.3 makes disposing nil an error, and until there was a
    // header it was a harmless one — `free(nil)` does nothing. Stepping back
    // over a header first turns it into a free of an address that was never
    // allocated, so the check exists where the hazard was introduced rather
    // than being extended to every pointer.
    emitTrapIf(b_.CreateIsNull(block, "isnil"), "dispose of nil");
    block = b_.CreateGEP(i8(), block,
                         {ConstantInt::getSigned(i32(), -int(head))}, "block");
  }
  b_.CreateCall(rt("pas_dispose", llvm::Type::getVoidTy(ctx_), {ptr()}),
                {block});
  // ISO 7185 §6.6.5.3 leaves the pointer undefined afterwards. Setting it to
  // nil makes the next dereference trap instead of reading freed storage —
  // a stricter choice than the standard requires, and a cheap one.
  b_.CreateStore(ConstantPointerNull::get(cast<PointerType>(ptr())), slot);
}

/// ISO 7185 §6.8.3.5 has no `else` arm, so the default is an error rather than
/// a way out: a selector matching no label stops the program. That maps onto a
/// switch exactly, and the jump table survives optimisation.
void CodeGen::emitCase(CaseStmt *s) {
  llvm::Value *selector = emitExpr(s->selector.get());
  // The switch wants a single integer type; a char or boolean selector is
  // widened, and its labels with it.
  if (selector->getType() != i32())
    selector = b_.CreateZExt(selector, i32(), "case.sel");

  BasicBlock *defaultBB = BasicBlock::Create(ctx_, "case.none", curFn_);
  BasicBlock *endBB = BasicBlock::Create(ctx_, "case.end", curFn_);

  // Every arm needs its block before anything can branch to it, because a
  // range test names it before the body is emitted.
  std::vector<BasicBlock *> armBBs;
  for (size_t i = 0; i < s->arms.size(); ++i)
    armBBs.push_back(BasicBlock::Create(ctx_, "case.arm", curFn_));

  // A range is *tested*, not enumerated: `1..maxint` is a legal label list
  // (ISO/IEC 10206:1991 §6.8.3.5) and two billion switch cases. So the ranges
  // are a chain of comparisons ahead of the switch, and only single constants
  // reach the switch itself. Sema has already proved the arms disjoint, so
  // which of the two answers first cannot matter.
  unsigned labels = 0;
  for (const CaseArm &arm : s->arms)
    labels += static_cast<unsigned>(arm.values.size());
  for (size_t i = 0; i < s->arms.size(); ++i)
    for (const LabelRange &r : s->arms[i].values) {
      if (r.lo == r.hi)
        continue;
      BasicBlock *nextBB = BasicBlock::Create(ctx_, "case.test", curFn_);
      llvm::Value *atLeast = b_.CreateICmpSGE(
          selector, ConstantInt::getSigned(i32(), r.lo), "case.ge");
      llvm::Value *atMost = b_.CreateICmpSLE(
          selector, ConstantInt::getSigned(i32(), r.hi), "case.le");
      b_.CreateCondBr(b_.CreateAnd(atLeast, atMost, "case.in"), armBBs[i],
                      nextBB);
      b_.SetInsertPoint(nextBB);
    }

  SwitchInst *sw = b_.CreateSwitch(selector, defaultBB, labels);

  for (size_t i = 0; i < s->arms.size(); ++i) {
    const CaseArm &arm = s->arms[i];
    for (const LabelRange &r : arm.values)
      if (r.lo == r.hi)
        sw->addCase(cast<ConstantInt>(ConstantInt::getSigned(i32(), r.lo)),
                    armBBs[i]);
    b_.SetInsertPoint(armBBs[i]);
    emitStmt(arm.body.get());
    b_.CreateBr(endBB);
  }

  b_.SetInsertPoint(defaultBB);
  if (s->hasOtherwise) {
    // ISO/IEC 10206:1991: the default arm is a statement-sequence rather than
    // the trap. Everything else about the lowering is unchanged, which is the
    // point — an `otherwise` is what the default block holds, not a different
    // shape of switch.
    for (StmtPtr &st : s->otherwise)
      emitStmt(st.get());
    b_.CreateBr(endBB);
  } else {
    llvm::Value *msg =
        b_.CreateGlobalString("case: no label matches the selector", "errmsg");
    b_.CreateCall(rt("pas_runtime_error", llvm::Type::getVoidTy(ctx_), {ptr()}),
                  {msg});
    b_.CreateUnreachable();
  }

  b_.SetInsertPoint(endBB);
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

  // Sema has always put a file here — the one that was written, or `output`.
  if (!s->file)
    return; // the program parameter was missing; the error is already reported
  llvm::Value *file = emitAddress(s->file.get());

  // On a file that is not a text, ISO 7185 §6.6.5.2 defines `write(f, e)` as
  // `f^ := e; put(f)` — so it is emitted as exactly that, an assignment to the
  // buffer variable and the primitive. Nothing about formatting applies.
  if (s->file->type && !s->file->type->isText()) {
    ap::Type *comp = s->file->type->elem;
    for (auto &arg : s->args) {
      llvm::Value *buf = b_.CreateCall(rt("pas_buffer", ptr(), {ptr()}),
                                       {file}, "buffer");
      emitStore(buf, comp, arg.value.get());
      b_.CreateCall(rt("pas_put", voidTy, {ptr()}), {file});
    }
    return;
  }

  for (auto &arg : s->args) {
    llvm::Value *width = arg.width ? emitExpr(arg.width.get()) : noWidth;
    llvm::Value *prec = arg.prec ? emitExpr(arg.prec.get()) : noWidth;

    // A packed array of char is written as its address plus its length —
    // which covers a string literal, since that is what a literal's type is.
    if (arg.value->type->isCharArray()) {
      llvm::Value *addr = emitAddress(arg.value.get());
      b_.CreateCall(
          rt("pas_write_str", voidTy, {ptr(), ptr(), i32(), i32()}),
          {file, addr,
           dynLength(arg.value->type, heapHeader(arg.value.get())), width});
      continue;
    }

    llvm::Value *v = emitExpr(arg.value.get());
    switch (arg.value->type->base()->kind) {
    case TypeKind::Integer:
      b_.CreateCall(rt("pas_write_int", voidTy, {ptr(), i64(), i32()}),
                    {file, b_.CreateSExt(v, i64()), width});
      break;
    case TypeKind::Real:
      b_.CreateCall(rt("pas_write_real", voidTy, {ptr(), f64(), i32(), i32()}),
                    {file, v, width, prec});
      break;
    case TypeKind::Boolean:
      b_.CreateCall(rt("pas_write_bool", voidTy, {ptr(), i32(), i32()}),
                    {file, b_.CreateZExt(v, i32()), width});
      break;
    case TypeKind::Char:
      b_.CreateCall(rt("pas_write_char", voidTy, {ptr(), i8(), i32()}),
                    {file, v, width});
      break;
    default:
      break;
    }
  }

  if (s->newline)
    b_.CreateCall(rt("pas_writeln", voidTy, {ptr()}), {file});
}

/// read/readln. Each variable is filled by the runtime call its type selects,
/// and `readln` then finishes the line — which is what makes `readln(x)` one
/// statement rather than two.
void CodeGen::emitRead(ReadStmt *s) {
  llvm::Type *voidTy = llvm::Type::getVoidTy(ctx_);
  if (!s->file)
    return;
  llvm::Value *file = emitAddress(s->file.get());

  // The mirror of emitWrite: on a file that is not a text, §6.6.5.2 makes
  // `read(f, v)` mean `v := f^; get(f)`. The buffer variable is fetched again
  // for each variable because `get` invalidates the previous one.
  if (s->file->type && !s->file->type->isText()) {
    ap::Type *comp = s->file->type->elem;
    for (auto &a : s->args) {
      llvm::Value *dst = emitAddress(a.get());
      llvm::Value *buf =
          b_.CreateCall(rt("pas_buffer", ptr(), {ptr()}), {file}, "buffer");
      if (a->type->isStructured()) {
        emitCopy(dst, a->type, buf);
      } else {
        llvm::Value *v = b_.CreateLoad(llvmType(comp), buf, "component");
        v = convertFor(v, comp, a->type);
        b_.CreateStore(checkedForStore(v, a->type), dst);
      }
      b_.CreateCall(rt("pas_get", voidTy, {ptr()}), {file});
    }
    return;
  }

  for (auto &a : s->args) {
    llvm::Value *slot = emitAddress(a.get());
    ap::Type *t = a->type;
    llvm::Value *v = nullptr;
    if (t->isChar()) {
      v = b_.CreateCall(rt("pas_read_char", i8(), {ptr()}), {file}, "ch");
    } else if (t->isReal()) {
      v = b_.CreateCall(rt("pas_read_real", f64(), {ptr()}), {file}, "num");
    } else {
      // The runtime returns i64 and has already rejected anything outside
      // -maxint..maxint, so the truncation here cannot lose a valid value.
      llvm::Value *wide =
          b_.CreateCall(rt("pas_read_int", i64(), {ptr()}), {file}, "num");
      v = b_.CreateTrunc(wide, i32(), "num.i32");
      // Reading into a subrange variable is a store like any other, so it is
      // checked like any other (ADR-0018).
      v = checkedForSubrange(v, t);
    }
    b_.CreateStore(v, slot);
  }

  if (s->newline)
    b_.CreateCall(rt("pas_readln", voidTy, {ptr()}), {file});
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

  // Both bounds are checked against the control variable's type, and nothing
  // between them needs checking: the loop never leaves [from, to].
  llvm::Value *from = checkedForSubrange(
      convertFor(emitExpr(s->from.get()), s->from->type, s->var->type),
      s->var->type);
  llvm::Value *to = checkedForSubrange(
      convertFor(emitExpr(s->to.get()), s->to->type, s->var->type),
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
  // Integer is the only ordinal with negative values; char, boolean and
  // enumerations all order as unsigned.
  bool unsignedOrdinal = !s->var->type->isInteger();
  llvm::Value *test =
      s->downto
          ? (unsignedOrdinal ? b_.CreateICmpUGE(cur, lim) : b_.CreateICmpSGE(cur, lim))
          : (unsignedOrdinal ? b_.CreateICmpULE(cur, lim) : b_.CreateICmpSLE(cur, lim));
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
  switch (sym.type->base()->kind) {
  case TypeKind::Integer: return ConstantInt::getSigned(i32(), sym.intVal);
  case TypeKind::Real:    return ConstantFP::get(f64(), sym.realVal);
  case TypeKind::Boolean: return ConstantInt::get(i1(), sym.boolVal);
  case TypeKind::Char:    return ConstantInt::get(i8(), sym.charVal);
  // An enumeration constant is its ordinal number, which Sema assigned in
  // declaration order.
  case TypeKind::Enum:    return ConstantInt::get(i32(), sym.intVal);
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
  case NK::NilLit:
    return ConstantPointerNull::get(cast<PointerType>(ptr()));
  case NK::Deref:
    return emitLoad(e);
  case NK::VarRef: {
    auto *v = static_cast<VarRef *>(e);
    if (!v->withField && v->sym->kind == SymKind::Const)
      return emitConst(*v->sym);
    // A parameterless call written as a bare name — of a function, or of a
    // functional parameter, which is the same call through a loaded address.
    if (!v->withField && v->sym->isInvocable())
      return emitUserCall(v->sym, noArgs_);
    return emitLoad(e);
  }
  case NK::Field: {
    // A schema-discriminant is the value the type was produced with, so it is
    // a constant here and there is nothing to load (§6.8.4). The width is the
    // discriminant's own ordinal type, exactly as a literal of it would be.
    auto *f = static_cast<FieldExpr *>(e);
    // ...unless the base is a schematic formal parameter, whose type was
    // produced with no tuple: then it is one field of the descriptor the
    // actual brought, and reading it is a load like any other.
    if (f->discSym)
      // A heap variable's tuple is in front of the variable, so `p^.n` is read
      // from where `p^` is; every other descriptor is reached by the walk any
      // enclosing variable takes.
      return f->discSym->heapDisc
                 ? discValue(f->base.get(), size_t(f->discSym->discIndex),
                             llvmType(e->type))
                 : b_.CreateLoad(llvmType(e->type), addressOf(f->discSym),
                                 f->discSym->name);
    if (f->isDiscriminant)
      return ConstantInt::getSigned(llvmType(e->type), f->discValue);
    return emitLoad(e);
  }
  case NK::Index:
    return emitLoad(e);
  case NK::SetLit: return emitSet(static_cast<SetExpr *>(e));
  case NK::Binary: return emitBinary(static_cast<Binary *>(e));
  case NK::Unary:  return emitUnary(static_cast<Unary *>(e));
  case NK::Call:   return emitCall(static_cast<Call *>(e));
  default:
    return ConstantInt::get(i32(), 0);
  }
}

/// A set constructor, built by or-ing one member at a time into an empty set.
/// A single value contributes `1 << v`; a range `lo..hi` contributes the bits
/// from lo to hi, which is the same pair of shifts `setUniverse` uses — with
/// the difference that the bounds are expressions, so `hi < lo` is a run-time
/// possibility and must yield the empty set rather than a mask of everything
/// (ISO 7185 §6.7.1).
llvm::Value *CodeGen::emitSet(SetExpr *e) {
  llvm::Value *result = ConstantInt::get(i256(), 0);
  llvm::Value *one = ConstantInt::get(i256(), 1);
  llvm::Value *ones = ConstantInt::getSigned(i256(), -1);
  llvm::Value *limit = ConstantInt::get(i256(), kSetLimit);
  for (SetMember &m : e->members) {
    llvm::Value *lo = setIndex(m.lo.get(), "set member out of range");
    llvm::Value *bits;
    if (!m.hi) {
      bits = b_.CreateShl(one, lo, "bit");
    } else {
      llvm::Value *hi = setIndex(m.hi.get(), "set member out of range");
      llvm::Value *below = b_.CreateLShr(ones, b_.CreateSub(limit, hi));
      llvm::Value *above = b_.CreateShl(ones, lo);
      bits = b_.CreateAnd(below, above, "range");
      // An empty range selects nothing. Without this the two masks would
      // still intersect in the bits between hi and lo.
      bits = b_.CreateSelect(b_.CreateICmpUGT(lo, hi),
                             ConstantInt::get(i256(), 0), bits, "range.or.empty");
    }
    result = b_.CreateOr(result, bits, "set");
  }
  return result;
}

/// The set operators, all of them one instruction on the bit vector:
/// union is `or`, intersection is `and`, difference is `and not`, and
/// inclusion is "nothing left over" (ISO 7185 §6.7.2.3, §6.7.2.5).
llvm::Value *CodeGen::emitSetBinary(Binary *e, llvm::Value *l,
                                    llvm::Value *r) {
  switch (e->op) {
  case BinOp::Add: return b_.CreateOr(l, r, "union");
  case BinOp::Mul: return b_.CreateAnd(l, r, "inter");
  case BinOp::Sub: return b_.CreateAnd(l, b_.CreateNot(r), "diff");
  case BinOp::Eq:  return b_.CreateICmpEQ(l, r, "seteq");
  case BinOp::Ne:  return b_.CreateICmpNE(l, r, "setne");
  case BinOp::Le:
    return b_.CreateICmpEQ(b_.CreateAnd(l, b_.CreateNot(r)),
                           ConstantInt::get(i256(), 0), "subset");
  default: // Ge — Sema has refused < and > on sets
    return b_.CreateICmpEQ(b_.CreateAnd(r, b_.CreateNot(l)),
                           ConstantInt::get(i256(), 0), "superset");
  }
}

llvm::Value *CodeGen::emitBinary(Binary *e) {
  // `and` and `or` short-circuit, which is what makes guarded tests such as
  // `while (i <= n) and (a[i] <> x)` safe to write. Extended Pascal's
  // `and then` and `or else` (§6.8.3.3) *require* that, so the one lowering
  // serves all four — the difference between them is a promise to the
  // programmer, not a difference in the code.
  if (e->op == BinOp::And || e->op == BinOp::Or || e->op == BinOp::AndThen ||
      e->op == BinOp::OrElse) {
    bool isAnd = e->op == BinOp::And || e->op == BinOp::AndThen;
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

  // `x in s` is the one operator whose operands are of different kinds, so it
  // is taken before the two are evaluated alike. A member position outside
  // 0..255 cannot be in any set, and answers false rather than trapping: the
  // value is not of the base type, which is what `in` is there to report.
  if (e->op == BinOp::In) {
    llvm::Value *raw = emitExpr(e->lhs.get());
    // Widened with its own signedness, a value outside 0..255 lands outside
    // that range in the 256-bit word too — so one unsigned compare catches a
    // negative value and an oversized one alike.
    llvm::Value *idx = e->lhs->type->isSignedOrdinal()
                           ? b_.CreateSExt(raw, i256())
                           : b_.CreateZExt(raw, i256());
    llvm::Value *ok = b_.CreateICmpULT(
        idx, ConstantInt::get(i256(), kSetLimit + 1), "in.range");
    // The shift is by a value LLVM has to see is under 256, or it is poison.
    llvm::Value *safe =
        b_.CreateSelect(ok, idx, ConstantInt::get(i256(), 0), "in.bit");
    llvm::Value *set = emitExpr(e->rhs.get());
    llvm::Value *got = b_.CreateAnd(b_.CreateLShr(set, safe),
                                    ConstantInt::get(i256(), 1));
    return b_.CreateAnd(
        ok, b_.CreateICmpNE(got, ConstantInt::get(i256(), 0)), "in");
  }

  // Strings compare through the runtime rather than in registers, and must be
  // caught before the operands are evaluated: an array has no register form.
  if (e->lhs->type->isCharArray() && e->rhs->type->isCharArray())
    return emitStringCompare(e);

  llvm::Value *l = emitExpr(e->lhs.get());
  llvm::Value *r = emitExpr(e->rhs.get());
  ap::Type *lt = e->lhs->type;
  ap::Type *rt_ = e->rhs->type;

  // Both operands are the same 256-bit word whatever their base types, so the
  // set operators need nothing from the types beyond knowing they are sets.
  if (lt->isSet() || rt_->isSet())
    return emitSetBinary(e, l, r);

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

  // Exponentiation is the one arithmetic operator with no instruction behind
  // it, so all three forms are runtime calls — and the error conditions of
  // §6.8.3.2 (a zero base with a non-positive exponent; a negative base under
  // `**`) go with them, rather than being emitted as tests around the call.
  // Integer `pow` is where the trap matters most: it is repeated
  // multiplication, and each step is checked exactly as `*` is.
  case BinOp::Exp:
    return b_.CreateCall(rt("pas_pow_real", f64(), {f64(), f64()}),
                         {toReal(l, lt), toReal(r, rt_)}, "pow");

  case BinOp::Pow:
    if (e->type->isReal())
      return b_.CreateCall(rt("pas_pow_realint", f64(), {f64(), i32()}),
                           {toReal(l, lt), r}, "pow");
    return b_.CreateCall(rt("pas_pow_int", i32(), {i32(), i32()}), {l, r},
                         "pow");

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
    // Pointers compare only for equality, which needs no predicate choice.
    if (lt->isPointer() || rt_->isPointer())
      return e->op == BinOp::Eq ? b_.CreateICmpEQ(l, r, "cmp")
                                : b_.CreateICmpNE(l, r, "cmp");
    // char, boolean and enumerations compare as unsigned ordinals; integer,
    // the only one with negative values, as signed.
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
  llvm::Value *len = dynLength(e->lhs->type, heapHeader(e->lhs.get()));
  // Sema requires equal lengths, and can say so wherever both are numbers.
  // Where one is a discriminant the requirement is the same one, made here —
  // and it has to be made, because a comparison over the wrong number of
  // characters answers rather than failing.
  if (e->lhs->type->dynamicBounds() || e->rhs->type->dynamicBounds()) {
    llvm::Value *other = dynLength(e->rhs->type, heapHeader(e->rhs.get()));
    emitTrapCall(b_.CreateICmpNE(len, other, "length.bad"),
                 rt("pas_length_error", llvm::Type::getVoidTy(ctx_),
                    {i32(), i32()}),
                 {len, other});
  }
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

  // The file enquiries take the file's address, not its value, and Sema has
  // already supplied `input` where the program left the argument out.
  if (e->builtin == Builtin::Eof || e->builtin == Builtin::Eoln) {
    if (e->args.empty())
      return ConstantInt::get(i1(), 0); // the parameter was missing: reported
    llvm::Value *file = emitAddress(e->args[0].get());
    const char *fn = e->builtin == Builtin::Eof ? "pas_eof" : "pas_eoln";
    return b_.CreateTrunc(b_.CreateCall(rt(fn, i32(), {ptr()}), {file}, "eof"),
                          i1(), "eof.b");
  }

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
    // succ and pred are errors at the ends of the ordinal type (§6.6.6.4), and
    // which type that is decides where the ends are: `blue` for an
    // enumeration, 9 for a subrange 1..9, maxint for an integer.
    bool up = e->builtin == Builtin::Succ;
    long long end = up ? at->ordinalHi() : at->ordinalLo();
    llvm::Value *limit = at->isSignedOrdinal()
                             ? ConstantInt::getSigned(a->getType(), end)
                             : ConstantInt::get(a->getType(),
                                                static_cast<uint64_t>(end));
    emitTrapIf(b_.CreateICmpEQ(a, limit, "ordinal.end"),
               std::string(up ? "succ" : "pred") + ": " +
                   Type::ordinalName(at, end) + " has no " +
                   (up ? "successor" : "predecessor") + " in " + at->name());
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
