"""What `src/codegen.cpp` actually emits, expressed in Z3.

This file is a *mirror* of the compiler, and the whole approach depends on it
staying one. Every function here names the `codegen.cpp` construct it models;
when that construct changes, this changes with it, and `verify.py --crosscheck`
is what catches the two drifting apart.

Representations follow `CodeGen::llvmType`:

    integer  i32   (signed)
    char     i8    (unsigned ordinal, 0..255)
    boolean  i1
    real     double

Most operations are written width-generically. Z3's bit-vector operators are
polymorphic in the width, and the lowering is too — `srem` is `srem` whether the
integer type is 32 bits or 8 — so the same model can be checked at a reduced
width when the full width is out of reach for the solver. See `verify.py` for
what that does and does not establish.
"""

import z3

INT_BITS = 32


def int_min(width=INT_BITS):
    return -(2 ** (width - 1))


def int_max(width=INT_BITS):
    return 2 ** (width - 1) - 1


def maxint(width=INT_BITS):
    """The value Sema installs for the predefined `maxint` (sema.cpp)."""
    return int_max(width)


def integer(name, width=INT_BITS):
    return z3.BitVec(name, width)


def char(name):
    return z3.BitVec(name, 8)


def real(name):
    return z3.FP(name, z3.Float64())


# --- arithmetic -------------------------------------------------------------


def mod(i, j):
    """`BinOp::Mod`: srem, then add the divisor back when the result is negative.

        rem = CreateSRem(l, r)
        neg = CreateICmpSLT(rem, 0)
        CreateSelect(neg, CreateAdd(rem, r), rem)
    """
    rem = z3.SRem(i, j)
    return z3.If(rem < 0, rem + j, rem)


def idiv(i, j):
    """`BinOp::IntDiv`: a bare signed division (after the non-zero guard)."""
    return i / j  # Z3's BitVec `/` is signed division


def sqr_int(i):
    """`Builtin::Sqr` on integer: goes through `checkedArith` like `*`."""
    return i * i


# --- the runtime checks -----------------------------------------------------
#
# ISO 7185 makes overflow and out-of-range ordinals *errors*, so the lowering
# emits a test and a call to pas_runtime_error rather than wrapping. Each
# `traps_*` predicate below is exactly the condition `CodeGen` branches on; the
# rules then prove that condition coincides with the ISO error condition.


def _no_signed_add_overflow(l, r):
    # Z3's *NoUnderflow / *NoOverflow pair split the two directions, and only
    # one of each pair takes a signedness flag — the other is signed-only.
    return z3.And(z3.BVAddNoOverflow(l, r, signed=True),
                  z3.BVAddNoUnderflow(l, r))


def _no_signed_sub_overflow(l, r):
    return z3.And(z3.BVSubNoOverflow(l, r),
                  z3.BVSubNoUnderflow(l, r, signed=True))


def _no_signed_mul_overflow(l, r):
    return z3.And(z3.BVMulNoOverflow(l, r, signed=True),
                  z3.BVMulNoUnderflow(l, r))


def _is_int_min(v):
    return v == z3.BitVecVal(int_min(v.size()), v.size())


def traps_add(l, r):
    """`checkedArith(sadd_with_overflow, ...)`: the intrinsic's overflow bit,
    or a result of INT_MIN (which fits the word but not the Pascal type)."""
    return z3.Or(z3.Not(_no_signed_add_overflow(l, r)), _is_int_min(l + r))


def traps_sub(l, r):
    return z3.Or(z3.Not(_no_signed_sub_overflow(l, r)), _is_int_min(l - r))


def traps_mul(l, r):
    return z3.Or(z3.Not(_no_signed_mul_overflow(l, r)), _is_int_min(l * r))


def traps_div(i, j):
    """`BinOp::IntDiv`: the zero guard, plus the explicit INT_MIN / -1 test."""
    return z3.Or(j == 0, z3.And(_is_int_min(i), j == -1))


def traps_chr(i):
    """`Builtin::Chr`: i < 0 or i > 255, checked before the truncation."""
    return z3.Or(i < 0, i > 255)


def traps_index(i, lo, hi):
    """`emitAddress`, NK::Index: the subscript is compared against both bounds
    before anything is computed from it.

        outside = CreateOr(CreateICmpSLT(idx, lo), CreateICmpSGT(idx, hi))
    """
    return z3.Or(i < lo, i > hi)


def index_offset(i, lo):
    """`emitAddress`, NK::Index: the element offset, a plain subtraction with
    no overflow check.

        offset = CreateSub(idx, lo)

    The omission is deliberate, and is the thing the index rules are about: the
    subtraction runs only where the bounds check has already passed.
    """
    return i - lo


def traps_subrange_store(v, lo, hi):
    """`checkedForSubrange`: both bounds, compared with the signed predicates
    an integer subrange uses.

        below = CreateICmpSLT(v, lo)
        above = CreateICmpSGT(v, hi)
        emitTrapIf(CreateOr(below, above))
    """
    return z3.Or(v < lo, v > hi)


def succ_traps_at(i, end):
    """`Builtin::Succ`, generalised to any ordinal type: equality with the last
    value of *that* type, which for an enumeration or a subrange is not
    maxint. The addition afterwards is a bare CreateAdd."""
    return i == end


def traps_fp_to_int(x):
    """`checkedFPToInt`: ordered comparisons against the two exactly
    representable powers of two just outside the integer range. Ordered means a
    NaN fails both and therefore traps."""
    lo = z3.FPVal(-2147483648.0, z3.Float64())
    hi = z3.FPVal(2147483648.0, z3.Float64())
    return z3.Not(z3.And(z3.fpGT(x, lo), z3.fpLT(x, hi)))


def round_to_nearest_away(x):
    """`Builtin::Round`: llvm.round, which takes halfway cases away from zero."""
    return z3.fpRoundToIntegral(z3.RNA(), x)


def traps_succ_int(i, width=INT_BITS):
    """`Builtin::Succ` on integer: equality with maxint."""
    return i == maxint(width)


def traps_pred_int(i, width=INT_BITS):
    return i == -maxint(width)


def odd(i):
    """`Builtin::Odd`: (a and 1) != 0."""
    return (i & 1) != 0


def ordinal_of_char(c, width=INT_BITS):
    """`Builtin::Ord` on char: CreateZExt(a, i32)."""
    return z3.ZeroExt(width - c.size(), c)


def chr_of_integer(i):
    """`Builtin::Chr`: CreateTrunc(a, i8) — note there is no range check."""
    return z3.Extract(7, 0, i)


def succ_int(i):
    """`Builtin::Succ` on integer: CreateAdd(a, 1) — note: no nsw, no check."""
    return i + 1


def pred_int(i):
    """`Builtin::Pred` on integer: CreateSub(a, 1)."""
    return i - 1


def int_to_real(i):
    """The implicit integer->real widening: CreateSIToFP(v, double)."""
    return z3.fpSignedToFP(z3.RNE(), i, z3.Float64())


def real_to_int_trunc(x, width=INT_BITS):
    """`Builtin::Trunc`: CreateFPToSI(v, i32)."""
    return z3.fpToSBV(z3.RTZ(), x, z3.BitVecSort(width))


# --- reading a number -------------------------------------------------------

# `pas_read_int` accumulates decimal digits in a 64-bit accumulator and checks
# the running value against maxint after each one:
#
#     value = value * 10 + (c - '0');
#     if (value > 2147483647LL) pas_runtime_error(...);
#
# Two things are being modelled: the arithmetic itself, and the fact that the
# check is applied *after* the multiply-add rather than before it.

ACC_BITS = 64


def read_accumulate(acc, digit):
    """One step of the accumulation, in the 64-bit accumulator the runtime
    actually uses."""
    return acc * z3.BitVecVal(10, ACC_BITS) + z3.ZeroExt(ACC_BITS - 4, digit)


def read_traps(acc, maxint):
    """The check that follows each digit."""
    return acc > z3.BitVecVal(maxint, ACC_BITS)


# --- comparisons ------------------------------------------------------------


def cmp_integer_lt(a, b):
    """Relational on integer: signed predicate (`sign` is true in emitBinary)."""
    return a < b  # Z3's BitVec `<` is signed


def cmp_char_lt(a, b):
    """Relational on char: unsigned predicate (`sign` is false)."""
    return z3.ULT(a, b)
