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

"""ISO 7185 semantics, stated as *properties* rather than as an implementation.

The distinction matters. If the reference model computed `mod` the same way the
compiler does, proving them equal would prove nothing — the circularity would be
invisible and the whole exercise decorative. So the specification here says what
must be true of a result (its range, its divisibility, its uniqueness) and lets
the solver decide whether the lowering delivers it.

Every specification is stated at double the program's width, so the *spec* is
exact and only the *implementation* is ever at risk of wrapping.
"""

import z3


def wide(x):
    """Sign-extend a program value into an exact spec domain twice as wide."""
    return z3.SignExt(x.size(), x)


def abs_wide(x):
    return z3.If(x < 0, -x, x)


def is_iso_mod(i, j, r):
    """ISO 7185 §6.7.2.2 — `i mod j` is defined only for j > 0, and denotes the
    unique r with 0 <= r < j such that j divides (i - r).

    Those two conditions characterise r uniquely, so a lowering that satisfies
    both is correct by definition rather than by resemblance.

    Divisibility is tested as a remainder of `i - r`, which is a different query
    from the one the lowering performs (a remainder of `i`): the specification
    never recomputes the value it is checking, so the check does not assume its
    own conclusion.
    """
    I, J, R = wide(i), wide(j), wide(r)
    in_range = z3.And(R >= 0, R < J)
    divides = z3.SRem(I - R, J) == 0
    return z3.And(in_range, divides)


def is_iso_div(i, j, quotient):
    """ISO 7185 §6.7.2.2 — `i div j` truncates toward zero.

    Characterised without dividing: the remainder i - q*j must be smaller in
    magnitude than j, and must not have the opposite sign to i — which is what
    distinguishes truncation from flooring.
    """
    I, J, Q = wide(i), wide(j), wide(quotient)
    rem = I - Q * J
    smaller = z3.And(rem > -abs_wide(J), rem < abs_wide(J))
    truncates = z3.Or(rem == 0, z3.And(rem > 0, I > 0), z3.And(rem < 0, I < 0))
    return z3.And(smaller, truncates)


def is_iso_odd(i, b):
    """`odd(i)` is true exactly when i is not divisible by two — including for
    negative i, where a naive remainder test can get the sign wrong."""
    two = z3.BitVecVal(2, wide(i).size())
    return b == (z3.SRem(wide(i), two) != 0)


def is_exact_square(i, squared):
    """The computed square equals the mathematical one — i.e. it did not wrap."""
    return wide(squared) == wide(i) * wide(i)


def truncation_is_an_integer_value(x, maxint):
    """ISO 7185 §6.6.6.2 — trunc(x) is defined only when the truncated value is
    a value of the integer type.

    Stated as a property of the *truncated* value — it must lie in
    -maxint..maxint — which is what §6.6.6.2 actually says. The compiler instead
    tests the *argument* against the two powers of two just outside the range,
    so proving the two coincide is a real theorem rather than a restatement:
    the subtle part is precisely whether bounding x by ±2^31 is equivalent to
    bounding trunc(x) by ±maxint.

    A NaN or an infinity truncates to nothing in the type, and the leading
    `finite` conjunct is what says so.
    """
    finite = z3.And(z3.Not(z3.fpIsNaN(x)), z3.Not(z3.fpIsInf(x)))
    truncated = z3.fpRoundToIntegral(z3.RTZ(), x)
    limit = z3.FPVal(float(maxint), z3.Float64())
    return z3.And(finite,
                  z3.fpLEQ(truncated, limit),
                  z3.fpGEQ(truncated, z3.fpNeg(limit)))


def is_iso_round(x, result):
    """ISO 7185 §6.6.6.3 / ISO/IEC 10206:1991 §6.7.6.3 — round(x) is defined by
    *equivalence*, not by a rounding mode: "If x is positive or zero, round(x)
    shall be equivalent to trunc(x+0.5); otherwise, round(x) shall be
    equivalent to trunc(x-0.5)."

    Characterised the way `is_iso_div` characterises truncation rather than by
    recomputing one: `result` must be an integral value no further from the
    shifted value than 1, on the side the shifted value lies. The shift itself
    is stated, because the clause states it — it is the whole content of the
    definition — but nothing here performs the compiler's `select`, and the
    truncation is characterised instead of applied.

    Note what this deliberately is *not*: "round half away from zero". That
    reading is what the compiler shipped, it agrees with the clause at every
    halfway point, and it disagrees wherever x ± 0.5 is inexact. Nothing in
    verify/ stated the value of round at all until this — only its range — so
    the drift was invisible to a catalogue with no known gaps.
    """
    zero = z3.FPVal(0.0, z3.Float64())
    half = z3.FPVal(0.5, z3.Float64())
    shifted = z3.If(z3.fpGEQ(x, zero),
                    z3.fpAdd(z3.RNE(), x, half),
                    z3.fpSub(z3.RNE(), x, half))
    one = z3.FPVal(1.0, z3.Float64())
    integral = result == z3.fpRoundToIntegral(z3.RTZ(), result)
    nearer_zero = z3.And(z3.fpLEQ(z3.fpAbs(result), z3.fpAbs(shifted)),
                         z3.fpLT(z3.fpSub(z3.RNE(), z3.fpAbs(shifted),
                                          z3.fpAbs(result)), one))
    return z3.And(integral, nearer_zero)


def index_is_in_bounds(i, lo, hi):
    """ISO 7185 §6.5.3.2 — a subscript must be a value of the index type, which
    for `array [lo..hi]` means lo <= i <= hi. Stated over the wide domain so
    the claim is about the mathematical value rather than the machine one."""
    return z3.And(wide(i) >= wide(lo), wide(i) <= wide(hi))


def offset_selects_the_right_element(i, lo, hi, offset):
    """The component `a[i]` denotes is the one `offset` elements from the start
    of the array, and that element exists.

    Stated as facts about the *mathematical* offset — that it equals i - lo and
    lies in 0..hi-lo — rather than by recomputing what the compiler computes.
    The first says the address is the right one; the rest say it is inside the
    array. Everything is in the wide domain, so the specification cannot wrap
    where the implementation would.
    """
    I, LO, HI, OFF = wide(i), wide(lo), wide(hi), wide(offset)
    return z3.And(OFF == I - LO, OFF >= 0, OFF <= HI - LO)


def index_span_is_representable(lo, hi, maxint):
    """The condition Sema enforces on an array's index range: the distance
    between the bounds must itself be a value of the integer type, since the
    lowering subtracts them. Without it, `i - lo` can wrap."""
    return wide(hi) - wide(lo) < z3.BitVecVal(maxint, wide(lo).size())


def is_a_value_of_the_subrange(v, lo, hi):
    """ISO 7185 §6.4.2.4 — the values of `lo..hi` are exactly those of the host
    type from lo to hi inclusive, and §6.4.6 makes storing anything else an
    error."""
    return z3.And(wide(v) >= wide(lo), wide(v) <= wide(hi))


def has_a_successor_in(i, lo, hi):
    """ISO 7185 §6.6.6.4 — succ(x) exists when x is not the last value of its
    own ordinal type. Stated over the type's own bounds rather than the machine
    type's, which is the whole difference an enumeration makes.

    Which type is "its own" is §6.7.1's answer, not the denoter's: a factor of
    a subrange type "shall be treated as if it were of type T", so for a
    subrange the bounds here are the host's. §6.6.6.4 says the result has "the
    same type as that of the expression (see 6.7.1)" and that cross-reference
    is the whole of the rule."""
    return z3.And(wide(i) >= wide(lo), wide(i) < wide(hi))


def successor_of(i, result):
    """The successor's ordinal is one greater — checked in the wide domain, so
    a lowering that wrapped at the end of the machine type would be caught."""
    return wide(result) == wide(i) + 1


def in_char_range(i):
    """chr(i) is defined only where i is the ordinal of some char (0..255)."""
    I = wide(i)
    return z3.And(I >= 0, I <= 255)


def in_integer_range(x, maxint):
    """ISO 7185 §6.4.2.2 — the integer type is -maxint..maxint. Note this is
    *narrower* than the machine type the compiler uses: at 32 bits, -2147483648
    is representable in an i32 but is not a value of the Pascal type."""
    return in_integer_range_wide(wide(x), maxint)


def in_integer_range_wide(x, maxint):
    """As `in_integer_range`, for a value already in the wide spec domain."""
    limit = z3.BitVecVal(maxint, x.size())
    return z3.And(x >= -limit, x <= limit)


def the_number_the_digits_denote(previous, digit):
    """ISO 7185 §6.9.1 — reading a number reads a sequence of digits, and the
    value is what those digits denote in decimal.

    Stated as the mathematical relation between the value before a digit and
    the value after it, over a domain wide enough that it cannot itself
    overflow. The runtime's accumulator is 64 bits and this is 128, which is
    the point: the specification has room to be wrong where the implementation
    would silently wrap."""
    P = z3.ZeroExt(64, previous)
    D = z3.ZeroExt(124, digit)
    return P * z3.BitVecVal(10, 128) + D


def the_exact_power(x, e, wide_bits):
    """ISO/IEC 10206:1991 §6.8.3.2 — `x pow y` for a positive y is
    x * (x pow (y-1)), with `x pow 0` one.

    The standard states this operator as a recursion rather than as a property,
    so a specification that refused to compute would have nothing to say. What
    keeps the rule from being circular is *where* it computes: this evaluates
    in a domain wide enough that it cannot wrap, and by repeated squaring
    rather than by the repeated multiplication the runtime performs. The claim
    is therefore about the checks and the width, which is where an
    implementation of exponentiation can actually be wrong.
    """
    result = z3.BitVecVal(1, wide_bits)
    base = z3.SignExt(wide_bits - x.size(), x)
    while e:
        if e & 1:
            result = result * base
        e >>= 1
        if e:
            base = base * base
    return result


def is_in_the_set_range(v, lo, hi):
    """ISO 7185 §6.7.1 — `[lo..hi]` denotes the values from lo to hi, and no
    values at all when hi precedes lo. Member positions are ordinals of the
    base type, which §6.4.3.4 leaves the implementation to bound; this one
    bounds them at 0..255, so they compare unsigned."""
    return z3.And(z3.ULE(lo, v), z3.ULE(v, hi))


def is_a_value_of_the_set_base_type(v, lo, hi):
    """§6.4.3.4 — the members of a `set of T` are values of T, and §6.4.6 makes
    storing a set with any other member an error."""
    return z3.And(z3.ULE(lo, v), z3.ULE(v, hi))
