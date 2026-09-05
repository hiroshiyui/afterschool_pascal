# ADR-0336: The pointer that is kept, unchecked

Date: 2026-09-05

## Status

Accepted. Amends ADR-0019, whose pointer this is, and answers the one entry in
`doc/roadmap.md`'s *Known limitations* that was a limitation in ADR-0109's
sense. ADR-0181 and the AP 6.4.14 family are untouched: this record decides
what happens to the pointer they do *not* govern.

## Context

**The question had stood open with three answers and no caller**: ISO/IEC
10206:1991 §6.4.4's ordinary pointer can dangle, and the dialect could keep it,
retire it in favour of `owned ^T`, or give it a check. ADR-0109 names memory
safety as a property of the language rather than a convention, so leaving the
row unanswered was itself a claim.

The roadmap's own rule is that a row is a report and not an estimate. Both
alternatives were therefore measured rather than weighed.

**Retire.** There are **41** ordinary-pointer type-definitions outside
`tests/` — 34 in the compiler, 5 in `lib/`, 2 in `lsp/`, none in `examples/`,
the two arenas there having already taken the word. **Nought of the 41** can
become `owned ^T` plus a borrow, and each refusal has a named cause rather than
a difficulty: three `lib/` containers are the conforming layer ADR-0120 keeps
portable to another Pascal, and `owned` is the dialect's; `JsonPtr` and
`JsonChars` are refused by AP 6.4.14.2's variant part; `PathVec` and `DocMap`
by AP 6.4.14.3, an owned field making `Document` affine and killing the
whole-record assignment the map is built on.

**The compiler's own 34 decide it.** Its node graph is not a tree: `symbol`
carries `owner` upward, `intType` and its fellows are global singletons named
by every node of their type, and `node.ty` points into a shared table.
`nodePtr`, `symPtr` and `typePtr` stand in a value-parameter or result position
**695** times, every one of which AP 6.4.14.3 refuses. And the compiler calls
`dispose` **not once** — all 65 textual occurrences across the three
program-components are comments, diagnostic strings, the identifier
`disposeValue`, or the emitted `@pas_dispose` declaration. It is
arena-until-exit by design, so there is no lifetime for an owner to model.

**Retiring would also end containment**, which is the argument that would hold
even if the numbers were kind. `new(p); q := p; dispose(p)` is a conforming
Extended Pascal fragment; ADR-0117 obliges this dialect to accept it and mean
the same thing.

**Check.** The obstacle assumed in the roadmap is not the obstacle. **No `^T`
ever crosses the foreign boundary** — AP 6.7.7.3 admits `integer`, `int64`,
`real`, `string` and a handle-type, and no `@cstruct` record may have a pointer
field — so `foreign-layout`, ADR-0129's slice pair and ADR-0328's `clong`/`csize`
are untouched, and ADR-0129 does not forbid a check. Trapping is admissible
too: §6.5.4 already calls the access an error and ADR-0014 traps errors.

What defeats it is cost with no caller. ADR-0325 admits `i386-pc-linux-gnu` and
runs the corpus there, so there are no spare address bits: a generation must be
a fat pointer, 16 bytes on LP64, re-baselining every frame size and record
offset `target-layout` watches — or a side table, which is a call per
dereference, the cost ADR-0322 already priced and refused for a rarer case.
And soundness requires that a freed header word never be reused for another
object, so `dispose` stops returning storage to `free`: **the checked pointer
becomes the one that leaks by design.**

## Decision

**The ordinary pointer is kept as ISO/IEC 10206:1991 defines it, and the
dialect writes down that it is the unchecked form.**

AP 6.4.4.3 is added — a clause that adds no requirement and exists so that the
decision is where a reader looks the pointer up. Its three notes say: that a
`dispose`d identifying-value goes on identifying, that this processor stores
nil into the pointer-variable it was given so the commonest spelling reaches
the nil trap, and that a second pointer is undetected; that the safe subset is
AP 6.4.14's, opt-in and spelled; and that the default being the unchecked one
is required by AP 6.0.1 rather than chosen.

**The inversion is stated rather than glossed.** Where another language marks
its unchecked form and leaves the checked one bare, this dialect does the
reverse. That is a fact about containment — a conforming program may not change
meaning — and not a lapse. Saying so is what keeps ADR-0109's goal from reading
as a claim the compiler does not meet.

## Consequences

**The row leaves *Known limitations* as answered, not as closed.** A program
that writes `^` still has a pointer that can dangle, and this record does not
pretend otherwise; what changes is that the language now says which construct
carries the guarantee, so a reader is not left to infer that `^` was meant to.

**It is a decision that can be revisited cheaply and reversed expensively.**
Nothing built here forecloses a check: the clause adds no requirement, so a
later record may add one without superseding this one's grammar. What such a
record would have to bring is the thing this one could not find — a caller.

**The measurement is the part with a shelf life.** The 41, the 695 and the
absent `dispose` are facts about this tree on 2026-09-05, taken by command and
re-runnable. Should the compiler ever acquire a real `dispose`, the strongest
argument here weakens, and the row is worth re-asking rather than citing.

## Alternatives rejected

**Retire the ordinary pointer**, so that every heap variable is `owned ^T` and
every second name a borrow. Rejected on the numbers above and, independently,
on ADR-0117's containment, which it would end.

**Give it a dynamic check** — a generation counter or a side table. Rejected on
cost with no caller: a fat pointer moves every offset a gate watches, a side
table is a call per dereference, and soundness makes the checked pointer the
leaking one. Recorded here rather than dismissed, because the reason usually
given for refusing it — the foreign boundary — turns out to be wrong, and a
wrong reason is worth correcting even under a decision that stands.

**Leave the row open.** Rejected because an unanswered row beside ADR-0109's
memory-safety goal is itself a claim, and because the question had been open
long enough to have acquired a stale reason ("it has not been asked with a
caller") that no longer described why nobody had moved.
