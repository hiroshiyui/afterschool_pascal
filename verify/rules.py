"""The rule catalogue: one entry per claim about the compiler's lowering.

Each rule pairs a precondition with a claim. The runner proves a rule by asking
Z3 for a counterexample — a model of `precondition AND NOT claim`. `unsat` means
no such input exists, so the claim holds for *every* input, which is the thing a
test suite cannot tell you.

Two statuses, and the difference is the point of the catalogue:

  MUST_HOLD  the compiler is claimed to be correct here. A counterexample fails
             the build.
  KNOWN_GAP  the compiler is known to be wrong or unchecked here, and the
             counterexample is the documented evidence. If one of these starts
             holding, that is *also* a failure — it means the gap was fixed and
             the catalogue is now lying about the compiler.

That second half is what keeps this file honest as the compiler changes.

Each rule also declares the widths it is checked at. `FULL` means the real
32-bit integer type: the claim is established for every value the program can
actually hold. `BOUNDED` means the claim involves a symbolic division or
multiplication, which bit-blasts into a circuit too large to solve at 32 bits,
so it is established exhaustively at small widths instead. See verify.py.
"""

import z3

import iso
import lowering as low

MUST_HOLD = "must-hold"
KNOWN_GAP = "known-gap"

FULL = (32,)
BOUNDED = (4, 6, 8, 10)


class Rule:
    def __init__(self, name, status, iso_ref, source, build,
                 widths=FULL, note=None):
        self.name = name
        self.status = status
        self.iso_ref = iso_ref
        self.source = source
        self.build = build  # (width) -> (precondition, claim)
        self.widths = widths
        self.note = note

    @property
    def bounded(self):
        return self.widths != FULL


# --------------------------------------------------------------------- rules


def _mod_correct(w):
    i, j = low.integer("i", w), low.integer("j", w)
    pre = j > 0  # ISO leaves mod undefined for a non-positive divisor
    return pre, iso.is_iso_mod(i, j, low.mod(i, j))


def _mod_nonnegative(w):
    i, j = low.integer("i", w), low.integer("j", w)
    return j > 0, low.mod(i, j) >= 0


def _mod_below_divisor(w):
    i, j = low.integer("i", w), low.integer("j", w)
    return j > 0, low.mod(i, j) < j


def _div_truncates(w):
    i, j = low.integer("i", w), low.integer("j", w)
    # Exclude the one case LLVM calls undefined; it gets its own rule below.
    pre = z3.And(j != 0, z3.Not(z3.And(i == low.int_min(w), j == -1)))
    return pre, iso.is_iso_div(i, j, low.idiv(i, j))


def _odd_correct(w):
    i = low.integer("i", w)
    return z3.BoolVal(True), iso.is_iso_odd(i, low.odd(i))


def _ord_chr_roundtrip(w):
    c = low.char("c")
    return z3.BoolVal(True), low.chr_of_integer(low.ordinal_of_char(c, w)) == c


def _chr_ord_roundtrip_in_range(w):
    i = low.integer("i", w)
    claim = low.ordinal_of_char(low.chr_of_integer(i), w) == i
    return iso.in_char_range(i), claim


def _char_compare_matches_ordinal(w):
    a, b = low.char("a"), low.char("b")
    claim = low.cmp_char_lt(a, b) == (
        low.ordinal_of_char(a, w) < low.ordinal_of_char(b, w))
    return z3.BoolVal(True), claim


def _int_to_real_is_exact(w):
    """Every 32-bit integer is exactly representable in a double, so the
    implicit widening must round-trip."""
    i = low.integer("i", w)
    return z3.BoolVal(True), low.real_to_int_trunc(low.int_to_real(i), w) == i


def _for_step_cannot_overflow(w):
    """The design claim made in `CodeGen::emitFor` and in CLAUDE.md: because the
    loop tests `current = limit` and exits *before* stepping, the increment can
    never overflow — not even when the limit is maxint.

    Modelled as the loop invariant (current <= limit) together with the
    condition under which the step block is reached (current <> limit).
    """
    cur, limit = low.integer("cur", w), low.integer("limit", w)
    pre = z3.And(cur <= limit, cur != limit, limit <= low.maxint(w))
    claim = z3.BVAddNoOverflow(cur, z3.BitVecVal(1, w), signed=True)
    return pre, claim


def _for_downto_step_cannot_underflow(w):
    cur, limit = low.integer("cur", w), low.integer("limit", w)
    pre = z3.And(cur >= limit, cur != limit, limit >= -low.maxint(w))
    claim = z3.BVSubNoUnderflow(cur, z3.BitVecVal(1, w), signed=True)
    return pre, claim


# --- known gaps -------------------------------------------------------------


def _chr_rejects_out_of_range(w):
    """ISO 7185 §6.6.6.4: chr(i) is an error unless i is a char ordinal. The
    lowering is a bare truncation, so an out-of-range argument silently aliases
    onto a valid character instead of being diagnosed."""
    i = low.integer("i", w)
    pre = z3.Not(iso.in_char_range(i))
    claim = low.ordinal_of_char(low.chr_of_integer(i), w) == i
    return pre, claim


def _div_overflow_is_unguarded(w):
    """INT_MIN div -1 has no representable result; LLVM's sdiv calls it
    undefined behaviour, and the compiler guards only against a zero divisor."""
    i, j = low.integer("i", w), low.integer("j", w)
    pre = z3.And(i == low.int_min(w), j == -1)
    return pre, z3.BoolVal(False)  # nothing is claimed; expect the witness


def _succ_overflows_silently(w):
    """succ(maxint) is an error in ISO 7185; the lowering is a bare add with no
    check, so it wraps to a negative value."""
    i = low.integer("i", w)
    return i == low.maxint(w), iso.in_integer_range(low.succ_int(i),
                                                    low.maxint(w))


def _sqr_overflows_silently(w):
    """sqr(i) is emitted with `nsw`, so on overflow the result is poison and the
    optimiser may assume it cannot happen. ISO calls the overflow an error."""
    i = low.integer("i", w)
    pre = i > 0
    claim = z3.Implies(z3.Not(iso.is_exact_square(i, low.sqr_int(i))),
                       z3.BoolVal(False))
    return pre, claim


ALL = [
    Rule("mod-satisfies-iso", MUST_HOLD,
         "ISO 7185 §6.7.2.2 — 0 <= i mod j < j, and j divides (i - r)",
         "codegen.cpp BinOp::Mod", _mod_correct, widths=BOUNDED),
    Rule("mod-is-non-negative", MUST_HOLD,
         "ISO 7185 §6.7.2.2 — the result of mod is never negative",
         "codegen.cpp BinOp::Mod", _mod_nonnegative),
    Rule("mod-is-below-the-divisor", MUST_HOLD,
         "ISO 7185 §6.7.2.2 — the result of mod is less than the divisor",
         "codegen.cpp BinOp::Mod", _mod_below_divisor),
    Rule("div-truncates-toward-zero", MUST_HOLD,
         "ISO 7185 §6.7.2.2 — div truncates toward zero",
         "codegen.cpp BinOp::IntDiv", _div_truncates, widths=BOUNDED),
    Rule("odd-handles-negatives", MUST_HOLD,
         "ISO 7185 §6.6.6.5 — odd(i) for every i, including negatives",
         "codegen.cpp Builtin::Odd", _odd_correct),
    Rule("ord-chr-round-trip", MUST_HOLD,
         "ISO 7185 §6.6.6.4 — chr(ord(c)) = c",
         "codegen.cpp Builtin::Ord/Chr", _ord_chr_roundtrip),
    Rule("chr-ord-round-trip-in-range", MUST_HOLD,
         "ISO 7185 §6.6.6.4 — ord(chr(i)) = i for i in 0..255",
         "codegen.cpp Builtin::Chr", _chr_ord_roundtrip_in_range),
    Rule("char-compare-matches-ordinal", MUST_HOLD,
         "ISO 7185 §6.7.2.5 — char comparison follows ordinal order",
         "codegen.cpp emitBinary (unsigned predicate for char)",
         _char_compare_matches_ordinal),
    Rule("integer-to-real-is-exact", MUST_HOLD,
         "ISO 7185 §6.4.6 — the implicit integer->real conversion is exact",
         "codegen.cpp CodeGen::toReal", _int_to_real_is_exact),
    Rule("for-step-cannot-overflow", MUST_HOLD,
         "the limit-then-step design claim in emitFor",
         "codegen.cpp CodeGen::emitFor", _for_step_cannot_overflow),
    Rule("for-downto-step-cannot-underflow", MUST_HOLD,
         "the limit-then-step design claim in emitFor, downto direction",
         "codegen.cpp CodeGen::emitFor", _for_downto_step_cannot_underflow),

    Rule("chr-rejects-out-of-range", KNOWN_GAP,
         "ISO 7185 §6.6.6.4 — chr(i) is an error outside the char ordinals",
         "codegen.cpp Builtin::Chr", _chr_rejects_out_of_range,
         note="chr is a bare truncation, so an out-of-range argument aliases "
              "onto a valid character instead of being diagnosed."),
    Rule("div-min-by-minus-one", KNOWN_GAP,
         "no representable result; LLVM's sdiv calls this undefined",
         "codegen.cpp BinOp::IntDiv (guardNonZero checks only j = 0)",
         _div_overflow_is_unguarded,
         note="The divisor guard catches zero but not the INT_MIN / -1 "
              "overflow, which is undefined behaviour in the emitted IR."),
    Rule("succ-at-maxint", KNOWN_GAP,
         "ISO 7185 §6.6.6.4 — succ(maxint) is an error",
         "codegen.cpp Builtin::Succ", _succ_overflows_silently,
         note="succ and pred are a bare add and sub with no range check, so "
              "they wrap instead of reporting an error."),
    Rule("sqr-overflow", KNOWN_GAP,
         "ISO 7185 §6.7.2.2 — arithmetic overflow is an error",
         "codegen.cpp Builtin::Sqr", _sqr_overflows_silently,
         note="Emitted with nsw, so an overflowing square is poison rather "
              "than a diagnosed error."),
]
