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


# --- the runtime checks -----------------------------------------------------
#
# Each of these proves a *biconditional*: the compiler traps exactly when ISO
# says the operation is in error. One direction alone would be worthless —
# trapping always would satisfy "never produces a wrong answer", and never
# trapping would satisfy "never rejects a valid program".


def _chr_traps_exactly_out_of_range(w):
    """ISO 7185 §6.6.6.4 — chr(i) is an error unless i is a char ordinal."""
    i = low.integer("i", w)
    return z3.BoolVal(True), low.traps_chr(i) == z3.Not(iso.in_char_range(i))


def _chr_correct_when_it_does_not_trap(w):
    i = low.integer("i", w)
    pre = z3.Not(low.traps_chr(i))
    return pre, low.ordinal_of_char(low.chr_of_integer(i), w) == i


def _div_traps_exactly_on_error(w):
    """The error conditions for div are a zero divisor and the one quotient
    that has no representable value."""
    i, j = low.integer("i", w), low.integer("j", w)
    error = z3.Or(j == 0, z3.And(i == low.int_min(w), j == -1))
    return z3.BoolVal(True), low.traps_div(i, j) == error


def _succ_traps_exactly_at_maxint(w):
    """ISO 7185 §6.6.6.4 — succ(x) is an error when x has no successor in its
    type, which for integer means maxint."""
    i = low.integer("i", w)
    error = z3.Not(iso.in_integer_range(low.succ_int(i), low.maxint(w)))
    return z3.BoolVal(True), low.traps_succ_int(i, w) == error


def _pred_traps_exactly_at_minimum(w):
    i = low.integer("i", w)
    error = z3.Not(iso.in_integer_range(low.pred_int(i), low.maxint(w)))
    return z3.BoolVal(True), low.traps_pred_int(i, w) == error


def _add_traps_exactly_on_overflow(w):
    """The sum is in error exactly when its exact value leaves -maxint..maxint."""
    l, r = low.integer("l", w), low.integer("r", w)
    exact = iso.wide(l) + iso.wide(r)
    error = z3.Not(iso.in_integer_range_wide(exact, low.maxint(w)))
    return z3.BoolVal(True), low.traps_add(l, r) == error


def _sub_traps_exactly_on_overflow(w):
    l, r = low.integer("l", w), low.integer("r", w)
    exact = iso.wide(l) - iso.wide(r)
    error = z3.Not(iso.in_integer_range_wide(exact, low.maxint(w)))
    return z3.BoolVal(True), low.traps_sub(l, r) == error


def _mul_traps_exactly_on_overflow(w):
    l, r = low.integer("l", w), low.integer("r", w)
    exact = iso.wide(l) * iso.wide(r)
    error = z3.Not(iso.in_integer_range_wide(exact, low.maxint(w)))
    return z3.BoolVal(True), low.traps_mul(l, r) == error


def _add_exact_when_it_does_not_trap(w):
    l, r = low.integer("l", w), low.integer("r", w)
    pre = z3.Not(low.traps_add(l, r))
    return pre, iso.wide(l + r) == iso.wide(l) + iso.wide(r)


def _mul_exact_when_it_does_not_trap(w):
    l, r = low.integer("l", w), low.integer("r", w)
    pre = z3.Not(low.traps_mul(l, r))
    return pre, iso.wide(l * r) == iso.wide(l) * iso.wide(r)


def _negation_cannot_overflow(w):
    """`UnOp::Neg` is emitted as an unchecked `nsw` negation. That is only sound
    because INT_MIN is not a value of the Pascal integer type — so this proves
    the omission of a check rather than the presence of one."""
    i = low.integer("i", w)
    pre = iso.in_integer_range(i, low.maxint(w))
    claim = iso.in_integer_range(-i, low.maxint(w))
    return pre, claim


def _trunc_traps_exactly_out_of_range(w):
    """ISO 7185 §6.6.6.2 — trunc(x) is an error when the truncated value is not
    a value of the integer type."""
    x = low.real("x")
    error = z3.Not(iso.truncation_is_an_integer_value(x, low.maxint()))
    return z3.BoolVal(True), low.traps_fp_to_int(x) == error


def _trunc_traps_on_nan_and_infinity(w):
    """The case a range check written with unordered comparisons would miss."""
    x = low.real("x")
    pre = z3.Or(z3.fpIsNaN(x), z3.fpIsInf(x))
    return pre, low.traps_fp_to_int(x)


def _round_traps_exactly_out_of_range(w):
    """round(x) applies the same range test to the rounded value, so a real just
    below maxint + 0.5 is accepted and one just above is an error."""
    x = low.real("x")
    rounded = low.round_to_nearest_away(x)
    error = z3.Not(iso.truncation_is_an_integer_value(rounded, low.maxint()))
    return z3.BoolVal(True), low.traps_fp_to_int(rounded) == error


def _index_traps_exactly_out_of_bounds(w):
    """The check fires on exactly the subscripts ISO calls an error — for every
    array, not merely for the ones a test happens to declare, because the
    bounds are symbolic here too."""
    i = low.integer("i", w)
    lo, hi = low.integer("lo", w), low.integer("hi", w)
    pre = z3.And(lo <= hi,  # Sema rejects an empty index at compile time
                 iso.in_integer_range(lo, low.maxint(w)),
                 iso.in_integer_range(hi, low.maxint(w)),
                 iso.in_integer_range(i, low.maxint(w)))
    claim = low.traps_index(i, lo, hi) == z3.Not(
        iso.index_is_in_bounds(i, lo, hi))
    return pre, claim


def _accepted_index_selects_the_right_element(w):
    """The claim that lets `emitAddress` subtract without a check: wherever the
    bounds test passes, `i - lo` is exact and lands inside the array.

    This is the array counterpart of `negation-cannot-overflow` — a rule whose
    job is to justify a check the compiler deliberately does *not* emit.
    """
    i = low.integer("i", w)
    lo, hi = low.integer("lo", w), low.integer("hi", w)
    pre = z3.And(lo <= hi,
                 iso.in_integer_range(lo, low.maxint(w)),
                 iso.in_integer_range(hi, low.maxint(w)),
                 iso.in_integer_range(i, low.maxint(w)),
                 # Sema rejects a wider index range than this, and the
                 # counterexample that made it do so is why the conjunct is
                 # here: without it the subtraction really can wrap.
                 iso.index_span_is_representable(lo, hi, low.maxint(w)),
                 z3.Not(low.traps_index(i, lo, hi)))
    claim = iso.offset_selects_the_right_element(i, lo, hi,
                                                 low.index_offset(i, lo))
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

    # The runtime checks: each proves the compiler traps *exactly* when ISO
    # says the operation is in error, in both directions.
    Rule("chr-traps-exactly-out-of-range", MUST_HOLD,
         "ISO 7185 §6.6.6.4 — chr(i) is an error outside the char ordinals",
         "codegen.cpp Builtin::Chr", _chr_traps_exactly_out_of_range),
    Rule("chr-correct-when-accepted", MUST_HOLD,
         "ISO 7185 §6.6.6.4 — an accepted chr(i) has ordinal i",
         "codegen.cpp Builtin::Chr", _chr_correct_when_it_does_not_trap),
    Rule("div-traps-exactly-on-error", MUST_HOLD,
         "a zero divisor, and the one quotient with no representable value",
         "codegen.cpp BinOp::IntDiv", _div_traps_exactly_on_error),
    Rule("succ-traps-exactly-at-maxint", MUST_HOLD,
         "ISO 7185 §6.6.6.4 — succ(x) is an error when x has no successor",
         "codegen.cpp Builtin::Succ", _succ_traps_exactly_at_maxint),
    Rule("pred-traps-exactly-at-minimum", MUST_HOLD,
         "ISO 7185 §6.6.6.4 — pred(x) is an error when x has no predecessor",
         "codegen.cpp Builtin::Pred", _pred_traps_exactly_at_minimum),
    Rule("add-traps-exactly-on-overflow", MUST_HOLD,
         "ISO 7185 §6.7.2.2 — arithmetic overflow is an error",
         "codegen.cpp checkedArith(sadd_with_overflow)",
         _add_traps_exactly_on_overflow),
    Rule("sub-traps-exactly-on-overflow", MUST_HOLD,
         "ISO 7185 §6.7.2.2 — arithmetic overflow is an error",
         "codegen.cpp checkedArith(ssub_with_overflow)",
         _sub_traps_exactly_on_overflow),
    Rule("mul-traps-exactly-on-overflow", MUST_HOLD,
         "ISO 7185 §6.7.2.2 — arithmetic overflow is an error (also sqr)",
         "codegen.cpp checkedArith(smul_with_overflow)",
         _mul_traps_exactly_on_overflow, widths=BOUNDED),
    Rule("add-exact-when-accepted", MUST_HOLD,
         "an accepted sum equals the mathematical sum",
         "codegen.cpp checkedArith(sadd_with_overflow)",
         _add_exact_when_it_does_not_trap),
    Rule("mul-exact-when-accepted", MUST_HOLD,
         "an accepted product equals the mathematical product",
         "codegen.cpp checkedArith(smul_with_overflow)",
         _mul_exact_when_it_does_not_trap, widths=BOUNDED),
    Rule("negation-cannot-overflow", MUST_HOLD,
         "why UnOp::Neg needs no check: INT_MIN is not a value of the type",
         "codegen.cpp emitUnary", _negation_cannot_overflow),

    Rule("trunc-traps-exactly-out-of-range", MUST_HOLD,
         "ISO 7185 §6.6.6.2 — trunc(x) is an error outside the integer type",
         "codegen.cpp checkedFPToInt", _trunc_traps_exactly_out_of_range),
    Rule("trunc-traps-on-nan-and-infinity", MUST_HOLD,
         "a NaN or an infinity has no integer value",
         "codegen.cpp checkedFPToInt (ordered comparisons)",
         _trunc_traps_on_nan_and_infinity),
    Rule("round-traps-exactly-out-of-range", MUST_HOLD,
         "ISO 7185 §6.6.6.3 — round(x) is an error outside the integer type",
         "codegen.cpp Builtin::Round", _round_traps_exactly_out_of_range),

    Rule("index-traps-exactly-out-of-bounds", MUST_HOLD,
         "ISO 7185 §6.5.3.2 — a subscript outside the index type is an error",
         "codegen.cpp emitAddress, NK::Index",
         _index_traps_exactly_out_of_bounds),
    Rule("accepted-index-selects-the-right-element", MUST_HOLD,
         "why the offset subtraction needs no overflow check of its own",
         "codegen.cpp emitAddress, NK::Index",
         _accepted_index_selects_the_right_element),
]
