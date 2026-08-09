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
    """`Builtin::Sqr` on integer: CreateNSWMul(a, a)."""
    return i * i


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


# --- comparisons ------------------------------------------------------------


def cmp_integer_lt(a, b):
    """Relational on integer: signed predicate (`sign` is true in emitBinary)."""
    return a < b  # Z3's BitVec `<` is signed


def cmp_char_lt(a, b):
    """Relational on char: unsigned predicate (`sign` is false)."""
    return z3.ULT(a, b)
