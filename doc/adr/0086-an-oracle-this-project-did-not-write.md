# 86. An oracle this project did not write

Date: 2026-08-14

## Status

Accepted, and **retired by
[ADR-0232](0232-afterschool-pascal-is-the-language.md)**. The suite validates
ISO 7185, and 25 of its 812 programs use a word-symbol this compiler now
reserves -- CONF005 exists precisely to check that a conforming processor
still accepts them -- so the corpus cannot be compiled here at all. It was the
only third-party oracle this project ever had, and there is no replacement;
`doc/sop.md` 7 records the loss rather than glossing it.

## Context

ADR-0085 deleted `selfhost/difftest.sh` along with the C++ compiler and said
what that cost: it compared two independent implementations over 436 sources,
and *"what remains — goldens, the fixed point, the proofs — cannot find that
class of defect, because a golden cannot disagree with the program that wrote
it."* Nothing had answered that.

The rest of `doc/roadmap.md` says the same thing from the other end. Seven
conformance sweeps are recorded there, and every one ends with the same
sentence: **no program in the corpus had written the construct, so every oracle
agreed with a compiler that was wrong.** Both `pack`/`unpack` and `page` sat in
`isRequiredName` with no implementation while three documents asserted
completeness. The corpus is the limit, and a corpus written here cannot escape
what its authors thought to write.

The BSI Pascal Validation Suite is a corpus nobody here chose: 812 programs by
Brian Wichmann and Z. J. Ciechanowicz, published 1982, each tied to a clause of
the standard, self-checking, and covering categories this project has no
equivalent of — 266 programs that must be *rejected*, 88 pairs probing errors a
processor is permitted to miss, and 51 that a level 0 processor must refuse.

## Decision

**The suite is adopted as a `ctest` case, and it is fetched rather than
committed.**

BSI holds the copyright and makes the suite available "as is" on three terms —
that the copyright is acknowledged, that no representation suggests a
third-party validation was carried out, and that any representation of results
describes performance on the whole suite rather than selected tests. Use is
granted; redistribution is not. `tests/bsi/fetch.sh` therefore clones it into a
gitignored directory, which is the arrangement `doc/vendor/` already has for
the standards themselves, and the case *skips* when it is absent exactly as
`verify-lowering` skips without z3.

**The upstream commit is pinned**, because an oracle that changes silently is
not one: a red bar must be unambiguously a compiler regression rather than a
corpus edit.

**`tests/bsi/expected.tsv` records what the compiler does with all 812, and any
difference fails — in either direction.** A program that starts *passing* fails
the run as loudly as one that starts failing. That is `verify/`'s rule for a
`KNOWN_GAP` that begins to hold (ADR-0013), and the reason is the same: a
catalogue that silently absorbs improvements stops describing the compiler, and
one nobody must update is one nobody reads.

**BSI's third condition is honoured structurally, not by promise.** `run.sh`
runs every category on every invocation and prints all nine counts, so a
partial number cannot be quoted from a green run. Nothing here may call this a
validation.

## Consequences

**It found three defects on the first run**, each of which the 435 goldens, the
stage-2/stage-3 fixed point and 43 SMT rules all agreed was correct:

- **§6.6.6.4 with §6.7.1** — `succ`/`pred` ran out at a *subrange's* bounds
  rather than its host's. The clause gives the result "the same type as that of
  the expression (see 6.7.1)", and §6.7.1 says "any factor whose type is S,
  where S is a subrange of T, shall be treated as if it were of type T". So
  `pred(orange)` where the operand is of type `orange..green` is `red`.
- **§6.8.3.9** — the bounds of a `for` statement were checked eagerly, where the
  clause requires assignment-compatibility only "if the statement of the
  for-statement is executed". `for i := maxint to maxint - 1 do` over an
  `i : 0..10` is a legal program with an empty loop, and this compiler stopped
  it.
- **§6.6.4.1** — a program may redefine `write` as its own procedure. Not fixed
  here; see below.

**The first was wrong in the documentation as well as the code, which is the
finding that matters.** `tests/trap_succ_subrange.pas` asserted the subrange
reading *in its own comment*, citing §6.6.6.4 and not following its
cross-reference; CLAUDE.md said the same. So the compiler, the golden, the test's
prose and the orientation document all agreed, and there was no oracle left that
could disagree — which is precisely the shape ADR-0085 predicted and precisely
what an outside corpus is for. ADR-0072's lesson (a wrong citation is invisible
to every oracle here) with a fourth instance.

**The second passed the whole suite after being broken.** Moving the check under
the entry test and then deleting it outright left all 435 cases green, because
no program in the corpus ran a `for` loop with a bound outside the control
variable's type. `tests/trap_for_bound.pas` exists for that reason and was
written by mutating the fix.

**§6.6.4.1 is left unfixed and recorded.** `get` and `page` already shadow
correctly, because they are resolved by symbol; the `read`/`write` family is
not, because the parser recognises those by name in order to parse the field
widths `write(x:3)` needs — the deviation ADR-0060 states. Fixing it is "ask the
symbol, not the syntax" a sixth time, after ADR-0044, ADR-0053, ADR-0066 and
ADR-0071: the parser must admit both readings and Sema must choose. That is a
feature-sized change and belongs in its own record.

**Twenty-eight errors go undetected where `doc/implementation-defined.md` names
twelve.** The suite's `ERROR` category and Annex D are not in one-to-one
correspondence, so the two numbers are not directly comparable — but that
document was written by hand, one probe per entry (ADR-0073), and this is the
first independent count of the same property. Reconciling them is outstanding.

**Level 0 is confirmed from outside.** All 51 `LEVEL1` programs are rejected,
which is what the suite's own `DOC/README.TXT` requires of a processor without
conformant array parameters. It is the first claim in
`doc/implementation-defined.md` §1 that something other than this project has
checked.

### What this does not do

**It is not a validation, and no document here may imply one.** BSI's second
condition forbids exactly that, and the suite being run by the implementer is
not what "validated" means.

**It does not run in CI.** The fetch needs network and the run takes minutes;
the case skips when the suite is absent, which is what a fresh clone and the
containers of `.github/workflows/ci.yml` will do. Making it a cached CI job is
worth doing and is not done here.

**It does not replace what difftest was.** A validation suite is a fixed corpus
and a second implementation was not: difftest compared *every source in this
tree*, including the compiler itself, and grew with the language. This finds
what its authors thought to test in 1982, which is a great deal, and then stops.
