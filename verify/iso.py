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


def in_char_range(i):
    """chr(i) is defined only where i is the ordinal of some char (0..255)."""
    I = wide(i)
    return z3.And(I >= 0, I <= 255)


def in_integer_range(x, maxint):
    """ISO 7185 §6.4.2.2 — the integer type is -maxint..maxint. Note this is
    *narrower* than the machine type the compiler uses: at 32 bits, -2147483648
    is representable in an i32 but is not a value of the Pascal type."""
    X = wide(x)
    return z3.And(X >= -maxint, X <= maxint)
