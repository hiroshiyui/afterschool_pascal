# Afterschool Pascal -- an ISO 7185 / ISO/IEC 10206:1991 Pascal compiler.
# Copyright (C) 2026 Hui-Hong You
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation, either version 3 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program.  If not, see <https://www.gnu.org/licenses/>.

"""What the compiler actually emits, expressed in Z3.

This file is a *mirror* of the code generator, and the whole approach depends on
it staying one. When a lowering changes, this changes with it, and
`verify.py --crosscheck` is what catches the two drifting apart.

The generator it mirrors is `selfhost/compiler.pas`, which since ADR-0085 is the
only one. It was written against `src/codegen.cpp` and re-pointed when stage 0
was retired; the model needed no change, because what it describes is the
*emitted instruction sequence* and not any compiler's internals.

**The tie to the compiler is behavioural, and that is weaker than it was.**
While both compilers existed the model could be read against C++ that a person
could check line by line. It cannot be read against the Pascal emitter that way:
the two backends were measured emitting different instruction counts for the
same program -- LLVM's IRBuilder constant-folds a getelementptr where a textual
emitter writes one out -- so "the same lowering" was never a claim about the
text. What holds the model to the compiler is `--crosscheck`, which runs the
adversarial point of every rule at -O0 and -O2, and the 66 `trap_*.pas` goldens,
which pin exactly the conditions these rules say the checks fire on. A change
that altered a lowering without failing either would leave this file describing
a compiler that no longer exists, and nothing would say so.

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

        emitTrapIf(CreateICmpSLE(r, 0), "the right operand of mod ...")
        rem = CreateSRem(l, r)
        neg = CreateICmpSLT(rem, 0)
        CreateSelect(neg, CreateAdd(rem, r), rem)

    The guard is not modelled as a value, because it produces none — it stops
    the program. What it does is make this model's `j > 0` precondition (see
    `rules.py`) a statement the compiler enforces rather than one the proofs
    merely assume. §6.7.2.2 leaves `mod` an error for a divisor that is not
    positive, and until the guard existed the rules said nothing about the
    values the compiler was quietly computing there.
    """
    rem = z3.SRem(i, j)
    return z3.If(rem < 0, rem + j, rem)


def idiv(i, j):
    """`BinOp::IntDiv`: a bare signed division (after the non-zero guard)."""
    return i / j  # Z3's BitVec `/` is signed division


def sqr_int(i):
    """`Builtin::Sqr` on integer: goes through `checkedArith` like `*`."""
    return i * i


def pow_int(x, e, width=INT_BITS):
    """`pas_pow_int` in runtime/pasrt.c, for a concrete positive exponent.

    This is the first model here of something the compiler *calls* rather than
    emits: exponentiation has no instruction behind it, so `BinOp::Pow` on
    integers is a call and the loop being modelled is C. The obligation is the
    same either way — this file mirrors what runs.

        long long acc = 1;
        for (i = 0; i < y; i++) {
          acc *= x;
          if (acc > PAS_MAXINT || acc < -PAS_MAXINT)
            pas_runtime_error("integer overflow in pow");
        }

    Two properties of that loop are what the rules are about, and neither is
    obvious: the accumulator is wider than the type, so a partial product is
    exact; and the check is applied to every partial product, so it could in
    principle fire on one whose final product would have been in range.

    Returns (value, traps). The value is only meaningful when it does not trap —
    the real loop exits at the first check that fires, and the disjunction below
    says the same thing about whether any of them did.
    """
    # Wide enough that the model's own arithmetic is exact for this exponent,
    # which is what makes the claim about the *check* and not about the
    # accumulator. The runtime's long long is exact for a different reason: it
    # stops as soon as a partial product leaves the type, so the next
    # multiplication is bounded by maxint * maxint.
    wide = width * (e + 1)
    acc = z3.BitVecVal(1, wide)
    xs = z3.SignExt(wide - width, x)
    hi = z3.BitVecVal(maxint(width), wide)
    lo = z3.BitVecVal(-maxint(width), wide)
    traps = z3.BoolVal(False)
    for _ in range(e):
        acc = acc * xs
        traps = z3.Or(traps, z3.Or(acc > hi, acc < lo))
    return acc, traps


def traps_pow_zero_base(x, y):
    """`pas_pow_int`'s first test, and the same one in `pas_pow_real` and
    `pas_pow_realint`: a zero base with a non-positive exponent."""
    return z3.And(x == 0, y <= 0)


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


def traps_int64_to_integer(a, narrow_bits):
    """`EmitCall, biTrunc` over an int64 operand (ADR-0128). It is the only
    narrowing in the language, and the comparison is made in the *wide* type
    before the truncation:

        %w = icmp sgt i64 %a, 2147483647
        %l = icmp slt i64 %a, -2147483647
        trap if %w or %l
        %v = trunc i64 %a to i32

    The bounds are maxint and -maxint, not INT_MIN, because the integer type is
    -maxint..maxint (ISO 7185 6.4.2.2 as ADR-0014 reads it) -- so a wide value
    of INT_MIN is refused although it fits the narrow machine word. Testing
    before the truncation is what makes it a check at all: the bits it would
    have tested are gone afterwards."""
    hi = z3.BitVecVal(maxint(narrow_bits), a.size())
    return z3.Or(a > hi, a < -hi)


def int64_to_integer(a, narrow_bits):
    """`trunc i64 %a to i32`, once the check above has passed."""
    return z3.Extract(narrow_bits - 1, 0, a)


def traps_chr(i):
    """`Builtin::Chr`: i < 0 or i > 255, checked before the truncation."""
    return z3.Or(i < 0, i > 255)


def traps_index(i, lo, hi):
    """`emitAddress`, NK::Index: the subscript is compared against both bounds
    before anything is computed from it.

        outside = CreateOr(CreateICmpSLT(idx, lo), CreateICmpSGT(idx, hi))

    ASSUMPTION, and the one thing about this rule worth knowing: `i` is the
    subscript *after* widening. The predicates emitted are signed whatever the
    index type is, and that is sound only because an unsigned ordinal reaches
    them zero-extended — a `char` subscript of 200 arrives as 200 and not as
    the -56 an `i8` holds. The rules below quantify over an already-widened
    value, so a `zext` turned into a `sext` would leave every one of them green
    while breaking each array indexed by a char above 127.

    What stands behind the assumption is `tests/highchar.pas`, which indexes
    an `array [chr(200)..chr(210)]` and fails if the widening changes.
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
    """`succ`, generalised to any ordinal type: equality with the last value of
    the type, the addition afterwards being a bare add.

    `end` is the last value of the type ISO 7185 §6.7.1 *substitutes*, which is
    what the compiler computes with `Base(t)` before asking for the bounds. An
    enumeration is its own base and so ends at its last constant. A subrange is
    not: §6.7.1 says "any factor whose type is S, where S is a subrange of T,
    shall be treated as if it were of type T", so `succ` of a `1..9` holding 9
    is 10 and traps at nothing. What traps for that value is storing it back,
    which is `traps_store_outside_subrange` and a separate rule.

    Reading `end` as the subrange's own 9 would describe the compiler this one
    was until the §6.7.1 reading was applied.
    """
    return i == end


def traps_fp_to_int(x):
    """`checkedFPToInt`: ordered comparisons against the two exactly
    representable powers of two just outside the integer range. Ordered means a
    NaN fails both and therefore traps."""
    lo = z3.FPVal(-2147483648.0, z3.Float64())
    hi = z3.FPVal(2147483648.0, z3.Float64())
    return z3.Not(z3.And(z3.fpGT(x, lo), z3.fpLT(x, hi)))


def round_shifted(x):
    """`Builtin::Round`, first half: the value handed to the range check and the
    truncation.

    `fcmp oge` against zero selects the addend, and `fadd` applies it — so the
    model is an FP addition, rounding included, and not a rounding mode. This
    replaced `fpRoundToIntegral(RNA(), x)`, which modelled `llvm.round`
    faithfully and modelled the wrong function: see `round-is-the-clause-value`
    in rules.py.

    A NaN fails `oge` and takes the -0.5 arm, where it stays a NaN for
    `traps_fp_to_int` to catch.
    """
    zero = z3.FPVal(0.0, z3.Float64())
    half = z3.FPVal(0.5, z3.Float64())
    addend = z3.If(z3.fpGEQ(x, zero), half, z3.fpNeg(half))
    return z3.fpAdd(z3.RNE(), x, addend)


def fp_to_int(x):
    """`checkedFPToInt`'s second half: `fptosi`, which truncates toward zero.
    Stated separately from the trap test because round now shifts before both.
    """
    return z3.fpRoundToIntegral(z3.RTZ(), x)


def succ_step_sum(i, k):
    """`Builtin::Succ`/`Pred` with a step: both operands are sign-extended one
    width up and the sum computed there, so it cannot wrap before the range
    check reads it. The emitted code sign-extends i32 to i64; modelled as one
    extra bit, which is what makes "33 bits suffice for the sum of two 32-bit
    values" the thing being checked rather than a constant being trusted.

    `pred(x,k)` emits `sub` on the same two extended operands, which is the
    same statement with k negated and needs no separate model — the negation
    happens after the extension, so it cannot overflow either.
    """
    return z3.SignExt(1, i) + z3.SignExt(1, k)


def succ_step_traps_outside(total, lo, hi):
    """The two `icmp`s that follow, in the wide width the sum was computed in."""
    return z3.Or(total < z3.SignExt(1, lo), total > z3.SignExt(1, hi))


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


# --- sets (ADR-0028) --------------------------------------------------------
#
# A set is one bit vector, one bit per possible member: SET_BITS wide in the
# real compiler, and width-generic here for the same reason the integer
# operations are. The member positions are unsigned, and Sema has already
# refused a base type outside 0..SET_BITS-1, so nothing below shifts by a
# amount the width cannot hold.

SET_BITS = 256


def set_value(name, width):
    return z3.BitVec(name, width)


def set_position(name, width):
    """A member's position in the bit vector — what `setIndex` produces after
    it has checked the value against 0..255 and widened it."""
    return z3.BitVec(name, width)


def set_single(v, width):
    """`[v]`, one member: emitSet's `shl i256 1, v`."""
    return z3.BitVecVal(1, width) << v


def set_range(lo, hi, width):
    """`[lo..hi]`: two masks and-ed, with the empty range selected away.
    emitSet builds it from `lshr (-1), (limit - hi)` and `shl (-1), lo`."""
    ones = z3.BitVecVal(-1, width)
    limit = z3.BitVecVal(width - 1, width)
    below = z3.LShR(ones, limit - hi)
    above = ones << lo
    return z3.If(z3.UGT(lo, hi), z3.BitVecVal(0, width), below & above)


def set_contains(s, v, width):
    """`v in s`: emitBinary's `(s lshr v) and 1`, for a v already known to be
    a representable position."""
    return (z3.LShR(s, v) & z3.BitVecVal(1, width)) != z3.BitVecVal(0, width)


def set_universe(lo, hi, width):
    """The mask `setUniverse` builds for a base type spanning lo..hi. The same
    pair of shifts as a constructor range, without the empty case: Sema has
    already refused an empty base type."""
    ones = z3.BitVecVal(-1, width)
    limit = z3.BitVecVal(width - 1, width)
    return z3.LShR(ones, limit - hi) & (ones << lo)


def traps_set_store(s, lo, hi, width):
    """`checkedForSetBase`: the store traps when anything is set outside the
    base type's own values."""
    return (s & ~set_universe(lo, hi, width)) != z3.BitVecVal(0, width)

def variant_accepts_range(tag, lo, hi):
    """ADR-0118's guard, for one arm of a variant part whose labels are the
    range lo..hi.  EmitVariantGuard emits `icmp sge` and `icmp sle` and ands
    them; a single-value label is the case lo = hi, where it emits one
    `icmp eq` instead and this says the same thing."""
    return z3.And(tag >= lo, tag <= hi)


def variant_accepts_completer(tag, lo, hi):
    """The variant-part-completer (ADR-0034): it carries no labels of its own,
    so what it accepts is whatever the other arms leave.  EmitVariantGuard
    accumulates the *others'* ranges and traps when the tag is in one, which is
    this condition negated."""
    return z3.Not(variant_accepts_range(tag, lo, hi))
