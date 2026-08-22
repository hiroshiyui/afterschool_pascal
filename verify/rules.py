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
# ADR-0128's int64 is the same lowering one width up -- the emitter takes the
# width and writes i32 or i64 through one path, so two copies of a checked
# multiply cannot drift apart. The rules below are already generic in the
# width, so what says the wide lowering is right is *running* them at 64 as
# well as at 32 rather than a second family of rules. Only the rules whose
# emitted code int64 actually shares carry this: a `trunc` from a double is
# still to an i32, and a `for` statement's control variable is still an
# ordinal, so widening those would prove a claim about code nothing emits.
WIDE = (32, 64)
# The set rules are checked at reduced *set* widths rather than reduced integer
# widths: a set is 256 bits wide in the compiler and a symbolic shift that wide
# bit-blasts into a circuit no solver will finish. The lowering is generic in
# the width — the same two shifts whether the vector is 16 bits or 256 — so a
# proof at these widths establishes the construction, not a sampled instance of
# it. What it does *not* establish is anything that depends on 256 in
# particular, and nothing in the lowering does: the only place the number
# appears is the bound Sema checks a base type against.
SET_WIDTHS = (8, 16, 32)


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
        # "Bounded" means *reduced* widths, not "more than one width": ADR-0128
        # made WIDE a second real width rather than a sampled one, and a rule
        # proved at 32 and 64 is proved at both types' full width.
        return min(self.widths) < 32


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


def _int64_narrowing_traps_exactly_out_of_range(w):
    """ADR-0128: `trunc` of an int64 is an error exactly when the value is not
    a value of the integer type. Checked at 64 (the width the compiler emits)
    and at 32, whose narrow half is 16 -- so the claim is about the
    construction rather than about one pair of widths."""
    narrow = w // 2
    a = low.integer("a", w)
    error = z3.Not(iso.in_integer_range(a, z3.BitVecVal(low.maxint(narrow),
                                                        w)))
    return z3.BoolVal(True), low.traps_int64_to_integer(a, narrow) == error


def _int64_narrowing_exact_when_accepted(w):
    """An accepted narrowing yields the same value, which is what the check is
    for: the truncation discards bits, and this says the discarded ones carried
    nothing."""
    narrow = w // 2
    a = low.integer("a", w)
    pre = z3.Not(low.traps_int64_to_integer(a, narrow))
    claim = z3.SignExt(w - narrow, low.int64_to_integer(a, narrow)) == a
    return pre, claim


def _trunc_traps_on_nan_and_infinity(w):
    """The case a range check written with unordered comparisons would miss."""
    x = low.real("x")
    pre = z3.Or(z3.fpIsNaN(x), z3.fpIsInf(x))
    return pre, low.traps_fp_to_int(x)


def _round_traps_exactly_out_of_range(w):
    """round(x) applies the range test to the *shifted* value, which is what
    the clause's own trunc(x+0.5) asks for — so a real just below maxint + 0.5
    is accepted and one just above is an error.

    The theorem moved when the lowering did: it used to test the value
    llvm.round produced. Both readings have to make the trap coincide exactly
    with "the clause's result is a value of the integer type", and it is not
    obvious in advance that shifting first leaves that true.
    """
    x = low.real("x")
    shifted = low.round_shifted(x)
    error = z3.Not(iso.truncation_is_an_integer_value(shifted, low.maxint()))
    return z3.BoolVal(True), low.traps_fp_to_int(shifted) == error


def _round_is_the_clause_value(w):
    """What round(x) *is*, which nothing here stated before.

    verify/ had a rule for round's range and none for its value, so
    `lowering.py` could model llvm.round faithfully while llvm.round was the
    wrong function — a catalogue with no known gaps, proving the compiler
    matched a model of a mistake. This is the statement that fails against the
    lowering shipped up to v1.8.0.
    """
    x = low.real("x")
    pre = z3.Not(low.traps_fp_to_int(low.round_shifted(x)))
    return pre, iso.is_iso_round(x, low.fp_to_int(low.round_shifted(x)))


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


def _read_accumulator_cannot_overflow(w):
    """The accumulator in `pas_read_int` is 64 bits and the check that guards
    it fires only *after* a digit has been folded in, so the multiply-add has
    to be shown incapable of wrapping before the check can see it.

    This is the read counterpart of `negation-cannot-overflow`: a rule whose
    job is to justify a check the runtime deliberately does not emit. The
    precondition is the loop invariant — the previous digit left a value the
    check accepted — which is the same statement the check itself makes, so
    the two cannot drift apart.
    """
    acc = z3.BitVec("acc", low.ACC_BITS)
    digit = z3.BitVec("digit", 4)
    pre = z3.And(acc >= 0,
                 z3.Not(low.read_traps(acc, low.maxint(w))),  # the invariant
                 z3.ULE(digit, 9))
    stepped = low.read_accumulate(acc, digit)
    # The 64-bit step agrees with the exact one, which is what "did not wrap"
    # means: it is stated by comparison with the wider domain rather than by
    # asserting a bound, so it cannot be true by construction.
    claim = z3.ZeroExt(64, stepped) == iso.the_number_the_digits_denote(acc,
                                                                       digit)
    return pre, claim


def _read_traps_exactly_outside(w):
    """The check fires on exactly the digit sequences whose value is not a
    value of the integer type. Both directions matter as usual: a runtime that
    rejected every number would satisfy "never reads a wrong value"."""
    acc = z3.BitVec("acc", low.ACC_BITS)
    digit = z3.BitVec("digit", 4)
    pre = z3.And(acc >= 0,
                 z3.Not(low.read_traps(acc, low.maxint(w))),
                 z3.ULE(digit, 9))
    stepped = low.read_accumulate(acc, digit)
    exact = iso.the_number_the_digits_denote(acc, digit)
    # A magnitude is what is accumulated; the sign is applied afterwards, and
    # the integer type is symmetric, so "in the type" is the same test either
    # way round.
    claim = low.read_traps(stepped, low.maxint(w)) == z3.Not(
        iso.in_integer_range_wide(exact, low.maxint(w)))
    return pre, claim


def _subrange_traps_exactly_outside(w):
    """The store check fires on exactly the values ISO calls an error, for
    every subrange — the bounds are symbolic, so this is one theorem about all
    subranges rather than a sample of some."""
    v = low.integer("v", w)
    lo, hi = low.integer("lo", w), low.integer("hi", w)
    # `lo <= hi` is a restriction the compiler enforces rather than an
    # assumption made here, which is what keeps this rule from proving
    # something about a subrange nothing can declare. Sema rejects an empty one
    # where both bounds fold; where one is evaluated at the block's
    # commencement (ADR-0133) the declaration traps instead, which is why that
    # check is load-bearing and not a nicety.
    pre = z3.And(lo <= hi,
                 iso.in_integer_range(lo, low.maxint(w)),
                 iso.in_integer_range(hi, low.maxint(w)),
                 iso.in_integer_range(v, low.maxint(w)))
    claim = low.traps_subrange_store(v, lo, hi) == z3.Not(
        iso.is_a_value_of_the_subrange(v, lo, hi))
    return pre, claim


def _succ_traps_exactly_at_the_end_of_its_type(w):
    """succ over an arbitrary ordinal type, not just integer: it traps exactly
    at the type's last value, and elsewhere gives the next one.

    The bounds are symbolic, so this is one theorem about every ordinal type
    rather than about whichever ones a test happens to declare — the case the
    old integer-only rule could not see, because it hard-coded maxint as the
    end.

    `lo` and `hi` are the bounds of the type ISO 7185 §6.7.1 substitutes: an
    enumeration's own, and for a subrange its *host's*. A subrange does not end
    its own `succ` — `succ(9)` of a `1..9` is 10, and what is an error there is
    storing the 10 back, which `_store_check_fires_exactly_on_the_values_iso_
    calls_an_error` covers. So instantiating this rule with 1 and 9 would be
    describing a compiler this one is not; instantiating it with the host's
    bounds is what makes it true of the emitted code.
    """
    i = low.integer("i", w)
    lo, hi = low.integer("lo", w), low.integer("hi", w)
    pre = z3.And(lo <= hi,
                 iso.in_integer_range(lo, low.maxint(w)),
                 iso.in_integer_range(hi, low.maxint(w)),
                 iso.is_a_value_of_the_subrange(i, lo, hi))
    traps = low.succ_traps_at(i, hi)
    claim = z3.And(
        traps == z3.Not(iso.has_a_successor_in(i, lo, hi)),
        # and where it does not trap, the result is right and still in the type
        z3.Implies(z3.Not(traps),
                   z3.And(iso.successor_of(i, low.succ_int(i)),
                          iso.is_a_value_of_the_subrange(low.succ_int(i),
                                                         lo, hi))))
    return pre, claim


def _set_range_selects_exactly_its_members(w):
    """`[lo..hi]` contains a position exactly when the position lies between
    the bounds — including the empty range, where it contains nothing. The
    bounds are symbolic, so this is one theorem about every constructor range
    rather than a sample of some, in the same way the array and subrange rules
    quantify over their bounds."""
    lo, hi = low.set_position("lo", w), low.set_position("hi", w)
    v = low.set_position("v", w)
    pre = z3.And(z3.ULT(lo, w), z3.ULT(hi, w), z3.ULT(v, w))
    claim = low.set_contains(low.set_range(lo, hi, w), v, w) == \
        iso.is_in_the_set_range(v, lo, hi)
    return pre, claim


def _set_single_selects_exactly_one_member(w):
    """`[x]` contains x and nothing else. The one-member case is a separate
    shift in emitSet, so it is a separate claim."""
    x, v = low.set_position("x", w), low.set_position("v", w)
    pre = z3.And(z3.ULT(x, w), z3.ULT(v, w))
    claim = low.set_contains(low.set_single(x, w), v, w) == (v == x)
    return pre, claim


def _set_store_accepts_only_values_of_the_base_type(w):
    """A set the store check accepts has no member outside the base type. This
    and the rule below are the two halves of "traps exactly": the trap is an
    existential over members, so it cannot be stated as one biconditional with
    a free position the way the subrange check can."""
    s = low.set_value("s", w)
    lo, hi = low.set_position("lo", w), low.set_position("hi", w)
    v = low.set_position("v", w)
    pre = z3.And(z3.ULE(lo, hi), z3.ULT(lo, w), z3.ULT(hi, w), z3.ULT(v, w),
                 z3.Not(low.traps_set_store(s, lo, hi, w)),
                 low.set_contains(s, v, w))
    return pre, iso.is_a_value_of_the_set_base_type(v, lo, hi)


def _set_store_traps_on_any_member_outside_it(w):
    """And a set with a member outside the base type is rejected — so no
    accepted value carries a member that does not exist."""
    s = low.set_value("s", w)
    lo, hi = low.set_position("lo", w), low.set_position("hi", w)
    v = low.set_position("v", w)
    pre = z3.And(z3.ULE(lo, hi), z3.ULT(lo, w), z3.ULT(hi, w), z3.ULT(v, w),
                 low.set_contains(s, v, w),
                 z3.Not(iso.is_a_value_of_the_set_base_type(v, lo, hi)))
    return pre, low.traps_set_store(s, lo, hi, w)


# The exponents the `pow` rules are established for. The loop has to be
# unrolled to be symbolic, so the claim is "for every base, at each of these
# exponents" rather than for every exponent — and 1 is in the list because a
# single multiplication is where an off-by-one in the check would hide.
POW_EXPONENTS = (1, 2, 3, 5)


def _pow_traps_exactly_when_the_value_leaves_the_type(e):
    def build(w):
        x = low.integer("x", w)
        value, traps = low.pow_int(x, e, w)
        exact = iso.the_exact_power(x, e, value.size())
        # Both directions at once: the trap fires for no base whose exact power
        # is a value of the type, and for every base whose power is not. The
        # first half is the one worth having — the check is applied to each
        # partial product, and a partial product that leaves the type while the
        # final one comes back would be a spurious trap. (It cannot happen,
        # because |x| >= 1 whenever the loop runs at all, and that is exactly
        # what this proves rather than assumes.)
        return x != 0, traps == z3.Not(iso.in_integer_range_wide(
            exact, low.maxint(w)))
    return build


def _pow_is_exact_when_it_does_not_trap(e):
    def build(w):
        x = low.integer("x", w)
        value, traps = low.pow_int(x, e, w)
        exact = iso.the_exact_power(x, e, value.size())
        return z3.And(x != 0, z3.Not(traps)), value == exact
    return build



def _variant_completer_is_the_exact_complement(w):
    """ADR-0118: every tag value is accepted by exactly one arm.

    Not a restatement of the emitted test, which is the trap ADR-0013 warns
    about.  What is proved here is a property of the *pair* of conditions
    EmitVariantGuard emits: a labelled arm's and the completer's partition the
    tag type between them.  Both halves matter and neither is obvious from the
    code --

      * if some value satisfied both, one store could activate two arms and the
        tag would have stopped being authoritative, which is the whole claim;
      * if some value satisfied neither, a record built through the completer
        would trap on every subsequent read of a field that *is* live -- a
        correct program broken by the safety feature.

    §6.4.3.3 with ADR-0096 makes a variant part's labels exactly its tag-type's
    values, so exhaustiveness is a language rule; this says the lowering keeps
    it.  Quantified over the bounds as well as the value, so it speaks about
    every variant part rather than a sampled one (ADR-0013's rule for keeping
    bounds symbolic).
    """
    tag = z3.BitVec("tag", w)
    lo = z3.BitVec("lo", w)
    hi = z3.BitVec("hi", w)
    labelled = low.variant_accepts_range(tag, lo, hi)
    completer = low.variant_accepts_completer(tag, lo, hi)
    # a non-empty label list is the only shape a variant part can have
    return lo <= hi, z3.Xor(labelled, completer)


ALL = [
    Rule("variant-completer-is-the-exact-complement", MUST_HOLD,
         "ISO 7185 §6.4.3.3 with ADR-0096 — a variant part's arms partition "
         "its tag-type, so exactly one accepts any tag value",
         "EmitVariantGuard", _variant_completer_is_the_exact_complement),
    Rule("mod-satisfies-iso", MUST_HOLD,
         "ISO 7185 §6.7.2.2 — 0 <= i mod j < j, and j divides (i - r)",
         "EmitBinary, opMod", _mod_correct, widths=BOUNDED),
    Rule("mod-is-non-negative", MUST_HOLD,
         "ISO 7185 §6.7.2.2 — the result of mod is never negative",
         "EmitBinary, opMod", _mod_nonnegative),
    Rule("mod-is-below-the-divisor", MUST_HOLD,
         "ISO 7185 §6.7.2.2 — the result of mod is less than the divisor",
         "EmitBinary, opMod", _mod_below_divisor),
    Rule("div-truncates-toward-zero", MUST_HOLD,
         "ISO 7185 §6.7.2.2 — div truncates toward zero",
         "EmitBinary, opIntDiv", _div_truncates, widths=BOUNDED),
    Rule("odd-handles-negatives", MUST_HOLD,
         "ISO 7185 §6.6.6.5 — odd(i) for every i, including negatives",
         "EmitCall, biOdd", _odd_correct),
    Rule("ord-chr-round-trip", MUST_HOLD,
         "ISO 7185 §6.6.6.4 — chr(ord(c)) = c",
         "EmitCall, biOrd and biChr", _ord_chr_roundtrip),
    Rule("chr-ord-round-trip-in-range", MUST_HOLD,
         "ISO 7185 §6.6.6.4 — ord(chr(i)) = i for i in 0..255",
         "EmitCall, biChr", _chr_ord_roundtrip_in_range),
    Rule("char-compare-matches-ordinal", MUST_HOLD,
         "ISO 7185 §6.7.2.5 — char comparison follows ordinal order",
         "EmitBinary (unsigned predicate for char)",
         _char_compare_matches_ordinal),
    Rule("integer-to-real-is-exact", MUST_HOLD,
         "ISO 7185 §6.4.6 — the implicit integer->real conversion is exact",
         "ToReal", _int_to_real_is_exact),
    Rule("for-step-cannot-overflow", MUST_HOLD,
         "the limit-then-step design claim in emitFor",
         "EmitFor", _for_step_cannot_overflow),
    Rule("for-downto-step-cannot-underflow", MUST_HOLD,
         "the limit-then-step design claim in emitFor, downto direction",
         "EmitFor", _for_downto_step_cannot_underflow),

    # The runtime checks: each proves the compiler traps *exactly* when ISO
    # says the operation is in error, in both directions.
    Rule("chr-traps-exactly-out-of-range", MUST_HOLD,
         "ISO 7185 §6.6.6.4 — chr(i) is an error outside the char ordinals",
         "EmitCall, biChr", _chr_traps_exactly_out_of_range),
    Rule("chr-correct-when-accepted", MUST_HOLD,
         "ISO 7185 §6.6.6.4 — an accepted chr(i) has ordinal i",
         "EmitCall, biChr", _chr_correct_when_it_does_not_trap),
    Rule("div-traps-exactly-on-error", MUST_HOLD,
         "a zero divisor, and the one quotient with no representable value",
         "EmitBinary, opIntDiv", _div_traps_exactly_on_error, widths=WIDE),
    Rule("succ-traps-exactly-at-maxint", MUST_HOLD,
         "ISO 7185 §6.6.6.4 — succ(x) is an error when x has no successor",
         "EmitCall, biSucc", _succ_traps_exactly_at_maxint),
    Rule("pred-traps-exactly-at-minimum", MUST_HOLD,
         "ISO 7185 §6.6.6.4 — pred(x) is an error when x has no predecessor",
         "EmitCall, biPred", _pred_traps_exactly_at_minimum),
    Rule("add-traps-exactly-on-overflow", MUST_HOLD,
         "ISO 7185 §6.7.2.2 — arithmetic overflow is an error",
         "EmitCheckedArith(sadd_with_overflow)",
         _add_traps_exactly_on_overflow, widths=WIDE),
    Rule("sub-traps-exactly-on-overflow", MUST_HOLD,
         "ISO 7185 §6.7.2.2 — arithmetic overflow is an error",
         "EmitCheckedArith(ssub_with_overflow)",
         _sub_traps_exactly_on_overflow, widths=WIDE),
    Rule("mul-traps-exactly-on-overflow", MUST_HOLD,
         "ISO 7185 §6.7.2.2 — arithmetic overflow is an error (also sqr)",
         "EmitCheckedArith(smul_with_overflow)",
         _mul_traps_exactly_on_overflow, widths=BOUNDED),
    Rule("add-exact-when-accepted", MUST_HOLD,
         "an accepted sum equals the mathematical sum",
         "EmitCheckedArith(sadd_with_overflow)",
         _add_exact_when_it_does_not_trap, widths=WIDE),
    Rule("mul-exact-when-accepted", MUST_HOLD,
         "an accepted product equals the mathematical product",
         "EmitCheckedArith(smul_with_overflow)",
         _mul_exact_when_it_does_not_trap, widths=BOUNDED),
    Rule("negation-cannot-overflow", MUST_HOLD,
         "why UnOp::Neg needs no check: INT_MIN is not a value of the type",
         "EmitUnary", _negation_cannot_overflow, widths=WIDE),

    Rule("int64-narrowing-traps-exactly-out-of-range", MUST_HOLD,
         "ADR-0128 with ISO 7185 6.6.6.2 - trunc of an int64 outside "
         "-maxint..maxint is an error",
         "EmitCall, biTrunc (IsInt64 arm)",
         _int64_narrowing_traps_exactly_out_of_range, widths=WIDE),
    Rule("int64-narrowing-exact-when-accepted", MUST_HOLD,
         "an accepted narrowing loses nothing",
         "EmitCall, biTrunc (IsInt64 arm)",
         _int64_narrowing_exact_when_accepted, widths=WIDE),
    Rule("trunc-traps-exactly-out-of-range", MUST_HOLD,
         "ISO 7185 §6.6.6.2 — trunc(x) is an error outside the integer type",
         "CheckedFPToInt", _trunc_traps_exactly_out_of_range),
    Rule("trunc-traps-on-nan-and-infinity", MUST_HOLD,
         "a NaN or an infinity has no integer value",
         "CheckedFPToInt (ordered comparisons)",
         _trunc_traps_on_nan_and_infinity),
    Rule("round-traps-exactly-out-of-range", MUST_HOLD,
         "ISO 7185 §6.6.6.3 — round(x) is an error outside the integer type",
         "EmitCall, biRound", _round_traps_exactly_out_of_range),
    Rule("round-is-the-clause-value", MUST_HOLD,
         "ISO 7185 §6.6.6.3 / ISO/IEC 10206:1991 §6.7.6.3 — round(x) is "
         "equivalent to trunc(x+0.5), or trunc(x-0.5) when x is negative",
         "EmitCall, biRound", _round_is_the_clause_value),

    Rule("index-traps-exactly-out-of-bounds", MUST_HOLD,
         "ISO 7185 §6.5.3.2 — a subscript outside the index type is an error",
         "EmitAddress, nkIndex",
         _index_traps_exactly_out_of_bounds),
    Rule("accepted-index-selects-the-right-element", MUST_HOLD,
         "why the offset subtraction needs no overflow check of its own",
         "EmitAddress, nkIndex",
         _accepted_index_selects_the_right_element),

    Rule("read-accumulator-cannot-overflow", MUST_HOLD,
         "why `value * 10 + digit` in pas_read_int needs no check of its own",
         "runtime/pasrt.c pas_read_int",
         _read_accumulator_cannot_overflow),
    Rule("read-traps-exactly-outside-the-integer-type", MUST_HOLD,
         "ISO 7185 §6.9.1 with §6.4.2.2 — a number read must be a value of the "
         "integer type",
         "runtime/pasrt.c pas_read_int", _read_traps_exactly_outside),

    Rule("subrange-traps-exactly-outside-its-bounds", MUST_HOLD,
         "ISO 7185 §6.4.6 — storing a value outside a subrange is an error",
         "CheckedForSubrange", _subrange_traps_exactly_outside),
    Rule("succ-traps-exactly-at-the-end-of-its-type", MUST_HOLD,
         "ISO 7185 §6.6.6.4 — succ over any ordinal type, not just integer",
         "EmitCall, biSucc",
         _succ_traps_exactly_at_the_end_of_its_type),
    Rule("set-range-selects-exactly-its-members", MUST_HOLD,
         "ISO 7185 §6.7.1 — [lo..hi] is the values from lo to hi, and none\n          when hi precedes lo",
         "EmitSet", _set_range_selects_exactly_its_members,
         widths=SET_WIDTHS),
    Rule("set-single-selects-exactly-one-member", MUST_HOLD,
         "ISO 7185 §6.7.1 — [x] is the set whose one member is x",
         "EmitSet", _set_single_selects_exactly_one_member,
         widths=SET_WIDTHS),
    Rule("set-store-accepts-only-values-of-the-base-type", MUST_HOLD,
         "ISO 7185 §6.4.6 — a set with a member outside its base type is\n          not a value of the type",
         "CheckedForSetBase",
         _set_store_accepts_only_values_of_the_base_type, widths=SET_WIDTHS),
    Rule("set-store-traps-on-any-member-outside-it", MUST_HOLD,
         "ISO 7185 §6.4.6 — and every such set is refused, not merely\n          some of them",
         "CheckedForSetBase",
         _set_store_traps_on_any_member_outside_it, widths=SET_WIDTHS),
]

# Exponentiation is the first thing proved about the *runtime* rather than
# about emitted IR: `pow` has no instruction behind it, so its loop and its
# overflow check are C. One pair of rules per exponent, because the loop is
# unrolled to be made symbolic.
ALL += [
    Rule("pow-traps-exactly-when-the-value-leaves-the-type-e%d" % e,
         MUST_HOLD,
         "ISO/IEC 10206:1991 §6.8.3.2 with ISO 7185 §6.4.2.2 — a power\n          outside -maxint..maxint is an error, and one inside it is not",
         "runtime/pasrt.c pas_pow_int",
         _pow_traps_exactly_when_the_value_leaves_the_type(e),
         widths=BOUNDED)
    for e in POW_EXPONENTS
] + [
    Rule("pow-is-exact-when-it-does-not-trap-e%d" % e, MUST_HOLD,
         "ISO/IEC 10206:1991 §6.8.3.2 — x pow y is x * (x pow (y-1))",
         "runtime/pasrt.c pas_pow_int",
         _pow_is_exact_when_it_does_not_trap(e), widths=BOUNDED)
    for e in POW_EXPONENTS
]
