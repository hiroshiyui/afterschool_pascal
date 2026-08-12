# 57. A substring is a pointer, a length, and somewhere to store

Date: 2026-08-12

## Status

Accepted.

## Context

ISO/IEC 10206:1991 spells one notation in two clauses:

> §6.5.6   substring-variable = string-variable `[` index-expression `..`
> index-expression `]`
>
> §6.8.6.5 substring-function-access = string-function `[` index-expression
> `..` index-expression `]`

They differ in what the base is, and therefore in what the result is. §6.5.1
lists a substring-variable among the variable-accesses, so `s[2..4] := 'XYZ'`
is an assignment; §6.8.6.5's is a value, and `greeting[1..2] := 'ab'` is not.

§6.5.6 also says what type the result has:

> A substring-variable shall denote a variable possessing a new
> fixed-string-type. ... The capacity of the fixed-string-type possessed by the
> variable denoted by the substring-variable shall be equal to one plus the
> value of the second index-expression minus the value of the first.

That capacity is `hi - lo + 1`, and neither bound need be a constant. ADR-0051
deferred this feature and ADR-0056 deferred §6.8.6.5 with it, on the ground
that `parseSelectors` is shared and should learn the syntax once for both.

## Decision

**One node for both clauses.** `SubstringExpr` has a base, a low bound and a
high bound, and `Sema::isDesignator` answers for it by asking its *base* the
same question. That is the entire difference between §6.5.6 and §6.8.6.5, so
encoding it anywhere else would be encoding it twice.

**The parser decides without types.** A `..` inside a subscript can only be
this — §6.5.3.2 gives an array a single index-expression per subscript — so
`parseSelectors` needs no knowledge of what the base possesses. It is gated on
`--std=extended`, and the ISO 7185 diagnostic names the `..` that has no
production.

**The type is the canonical-string-type**, which under ADR-0051 is a pointer
and a length. §6.5.6's "new fixed-string-type" is therefore never built: the
capacity is not a compile-time number, and **nothing observable needs it to
be one**. The only rule that reads the capacity is the store, and the store
reads it at run time from the same subtraction the length came from.

**Reading one copies nothing.** `emitString` advances the base's pointer by
`lo - 1` and hands back `hi - lo + 1` — three instructions, and the same three
whether the base is a variable or a function-access. That is what makes the
two clauses one implementation rather than two.

**Writing one is the fixed-string store, unchanged.** §6.4.6 pads a shorter
value with spaces and refuses a longer one, and `pas_str_store_fixed` has done
exactly that since ADR-0051. The only thing this feature supplies is a
capacity that is computed rather than written down. No new store, no new rule,
no change to `emitStore`.

**The bounds check is new, and it had to be.** §6.7.6.7 lets `substr(s, i, 0)`
yield the null-string, so `pas_str_slice_check` accepts a count of zero;
§6.5.6 makes "the value of the first index-expression greater than the value
of the second" an error, and `s[3..2]` is precisely the empty substring. **The
two conditions agree everywhere except at the empty case**, which is the one
place a shared check would have been wrong in silence rather than loudly. So
`pas_str_substr_check` is its own function with its own message, and
`tests/extended/trap_substring.pas` is the program that distinguishes them.

**§6.7.3.3 NOTE 3 is enforced by name rather than by accident.** "An actual
variable parameter cannot denote a substring-variable because the type of a
substring-variable is a new fixed-string-type different from every named
type." The rule already in `checkArguments` — a var parameter's type must be
*the same* type — would refuse it on its own, because the canonical-string-type
is not any named type either. But the words it would use name a representation
rather than the reason, so the check is written where the clause is.

**§6.5.6's last sentence needed a walk that already existed**: "A reference or
an access to a substring of a variable shall constitute a reference or access,
respectively, to the variable." `baseSymbol` and `rootDesignator` therefore
walk through a substring exactly as they walk through a subscript, which is
what makes a protected string unwritable through one (ADR-0046).

## Consequences

`verify/` gained nothing and no lowering changed. The feature is one node, one
parser branch, one Sema case, one `emitString` case, one `emitAssign` case and
one runtime function.

It closes **ADR-0056's deferral**: §6.8.6.5 arrived here, in the shared
`parseSelectors`, which is the reason that record gave for not doing half of it
early.

**The Pascal port met §6.4.3.3's own rule about itself.** Field identifiers
must be distinct across every variant of a record, so `sbLo`/`sbHi` collided
with the subrange node's — the constraint ADR-0023 recorded when the parser was
ported, met again by the first new node kind since. The substring's are
`ssLo`/`ssHi`.

**The bounds check is one `if` with three disjuncts, and a corpus exercising
one of them proves nothing about the other two.** Three mutations survived a
green suite: dropping the lower-bound test, dropping the upper-bound test, and
— in *both* compilers — walking `baseSymbol`/`rootDesignator` through a
substring, which is what stops a protected string being written through one.
Each needed a program written for it, and the traps needed one file apiece
because a program stops at its first runtime error.

**A `declare` the C++ side gets for free is a line on the Pascal side.** The
new runtime function needed adding to the emitted module's declaration list,
and `irtest` caught it as an assembler error rather than a wrong answer. That
is the cheap failure; ADR-0052's was the other kind.

**`read` into a substring is supported**, because §6.5.1 makes one a
variable-access and §6.10 therefore admits it — and the capacity `pas_read_str`
wants is `hi - lo + 1`, which is what `emitString` already computes. Writing it
found two things in the *existing* string-read path that no program had ever
reached:

- **The Pascal Sema refused every string read.** §6.10.1 a) adds the string
  types to ISO 7185's list of what `read` accepts, and only the C++ side had
  been told. The two compilers had disagreed since ADR-0051, and `difftest`
  could not see it because no program in the corpus read a string.
- **The Pascal backend's string-read branch fell through into a store.** The
  C++ ends that case with `continue`; Pascal has none, and the port had no
  equivalent, so the store wrote whatever register the *previous* argument had
  left behind. It was unreachable — Sema refused first — which is the only
  reason it was harmless, and fixing the Sema is what would have exposed it.

`tests/extended/readstring.pas` is the program neither had, and it reads a
fixed string, a variable string, a string after a scalar, and a substring.

### What this does not do

**§6.5.6's aliasing rule is not enforced**: "It shall be an error to alter the
length of the value of a string-variable when a reference to a substring of the
string-variable exists." A reference here lives for one statement, and
detecting one would need the run-time property ADR-0027 refused for a
variant-selected heap variable. Stated, not silently omitted.

**Nothing about `readstr`/`writestr`** (§6.7.5.5), which is its own feature and
its own record.
