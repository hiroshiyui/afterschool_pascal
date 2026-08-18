# ADR-0117: The dialect is a third `--std`, and it is Extended Pascal plus

## Status

Accepted. Opens the dialect mode ADR-0109 named and left unbuilt, and settles
four things it listed as open or unstated. **No language feature lands here** —
this record decides where one would go and what it must satisfy, so that the
first feature is not also the thing that sets the precedent by accident.

It answers ADR-0109's fourth open question ("how far the C++ reference front end
follows") and leaves the other three — the memory-safety model, the text model
and the memory model — exactly as open as it found them.

## Context

Both standards are complete. CLAUDE.md's rule for anything further is blunt:
inside `--std=iso7185` and `--std=extended` an extension is a *defect* unless
`doc/implementation-defined.md` lists it. So a new feature has nowhere to go
until a third mode exists.

The library made that concrete rather than theoretical. Three increments of
`lib/` produced one recurring shape: **every routine that can fail invents its
own way of saying so.** `TryParseInt` answers a boolean and writes through a
`var`, `MapGet` takes a `whenAbsent` value, `VecNew` clamps a bad capacity
silently. There are already three shapes for one missing feature, and the reason
none of them is "report the error" is that a library here **may not halt** —
§6.9.1's read of an integer is an *error* when the text is not a number and
stops the program (ADR-0076), so nothing built on `readstr` can offer "parse
this if it is a number". Pascal has no exceptions and no result convention. That
is the gap, and it is a language gap.

### The mechanical fact that shapes the decision

`stdKind = (stdIso7185, stdExtended)`, and `src/` has
`enum class Std { Iso7185, Extended }`. Counted rather than estimated, in
`selfhost/compiler.pas`:

| Form | Sites | What it means | Under a third mode |
| --- | --- | --- | --- |
| `langStd = stdExtended` | 38 | "does this mode have Extended Pascal?" | **wrong** — excludes the dialect |
| `langStd <> stdExtended` | 2 | "is this ISO 7185?" | **wrong**, and in the *opposite* direction — includes the dialect |
| `langStd = stdIso7185` | 12 | "is this exactly ISO 7185?" | correct as written |

Adding a third enumerant therefore does not extend the language. It *silently
removes* Extended Pascal from the dialect at 38 sites at once — schemata,
`otherwise`, string types, `**`, binding, modules all switch off — while 2 more
sites break the other way and start treating dialect sources as ISO 7185.
Nothing fails to compile. The dialect would simply be ISO 7185 wearing a new
flag, and 12 sites would be right, which is the worst possible ratio for
noticing.

**The two inequality sites are the ones to be careful with**, because they read
as the negation of a mode and are actually the assertion of a different one.
They are the reason this is a predicate conversion and not a search-and-replace.

This is the single most important thing to get right, and it is not a feature
decision. It is why this record exists before any feature.

## Decision

### 1. The mode is `--std=afterschool`, and it is Extended Pascal plus

The third mode **nests**, where the first two deliberately do not. ADR-0033
established that `--std=iso7185` and `--std=extended` are not nested because
Extended Pascal reserves word-symbols a valid ISO 7185 program may use as
identifiers — a real incompatibility forced by the two specifications.

No such force applies here. The dialect is ours, so it may simply *contain*
ISO/IEC 10206:1991: every Extended Pascal program is a valid Afterschool Pascal
program with the same meaning, and the dialect adds. Where a standard already
spells something, the dialect spells it that way (CLAUDE.md's existing rule).

So the keyword table gains a **third tier** on the same construction as the
second — `isoKwCount` ⊂ `kwCount` ⊂ the dialect's count — and ADR-0033's
discipline carries over unchanged: **a word-symbol is reserved when the feature
needing it lands, not before.**

### 2. The test becomes a predicate, in its own change, before any feature

`stdKind` gains `stdAfterschool` as the **last** enumerant — last so that the
ordering `stdIso7185 < stdExtended < stdAfterschool` matches the containment —
and all 40 tests against `stdExtended` become predicates:

```pascal
{ true for every mode that has ISO/IEC 10206:1991, which is Extended Pascal
  and everything built on it }
function HasExtended(s: stdKind): boolean;
begin HasExtended := s >= stdExtended end;
```

That conversion is a **mechanical, self-contained commit with no behaviour
change**, landed *before* the enumerant is reachable from the command line — so
it can be reviewed as a refactor and mutation-checked as one. `src/` takes the
same shape for as long as it follows (see 4).

Equality stays correct in one place, and the distinction is the whole of the
work:

- the 38 `= stdExtended` become `HasExtended(langStd)`;
- the 2 `<> stdExtended` become **`not HasExtended(langStd)`** — not
  `= stdIso7185`. Both are equivalent with three modes, and the predicate says
  the intent: each of the two guards a refusal of an Extended Pascal feature
  (`RefuseConstAccess`, and the function-access selector check), so what it
  wants is "this mode does not have Extended Pascal" and not "this mode is ISO
  7185". They differ the day a fourth mode lacks Extended Pascal, and the
  predicate is right in advance;
- the 12 `= stdIso7185` stay. They ask *"is this exactly ISO 7185?"* in order to
  name `--std=extended` in a diagnostic, and that is still what they mean.

The middle line is the one to check by hand: it is the only place where the
*meaning* changes rather than the spelling, and it reads as a negation while
being an assertion about a different mode.

### 3. A feature is admitted on a reason of its own, and the corpus says which mode

`tests/dialect/` is the third corpus directory, and the directory decides the
flag exactly as `tests/extended/` does (ADR-0034's unanchored-glob trap
included). `name.std` still overrides for a source outside it.

Admission rules, which are the point of having a mode rather than a licence:

- **A reason of its own.** "The standard has it" was the bar during
  conformance and cannot be, here — no standard has these. The reason must
  name what cannot be written today and what it costs, the way this record
  names three ad-hoc failure shapes in `lib/`.
- **Spelled as a standard spells it, wherever one does.**
- **It must not change what the two conformance modes accept.** A dialect
  feature that requires touching a shared path must prove the conformance modes
  are unaffected, and the existing corpus is what proves it.
- **It must be expressible in what `seed/pascalc.ll` accepts**, or the seed is
  refreshed first (CLAUDE.md's surviving bootstrap constraint). The compiler is
  written in Extended Pascal and stays so; **the dialect does not get to be the
  language the compiler is written in** without its own record, because that
  would make the seed's refresh order load-bearing in a new way.

### 4. The C++ reference front end freezes at the conformance surface

ADR-0109 called this the obvious answer and did not take it. Taken now:
**`src/` implements ISO 7185 and ISO/IEC 10206:1991 and stops.** It will not
grow dialect features.

The reasoning is ADR-0085's, unchanged: a front-end feature shipping twice is
the cost that retired stage 0, and a dialect is expected to move quickly. What
`src/` is *for* is guarding the surface that must not regress, and that surface
is exactly the two conformance modes.

`selfhost/difftest.sh` must therefore **skip dialect sources rather than compile
them under the wrong flag**, which is ADR-0034's lesson restated: comparing two
identical rejections passes and proves nothing. A dialect source under
`--std=afterschool` handed to a front end that does not know the mode is that
failure exactly.

## Consequences

- **The strongest oracle here goes blind on the newest code.** Dialect sources
  are compared by no second implementation. That is not a side effect to be
  discovered; it is the price of 4, and it lands in `doc/sop.md` §7 with this
  record. The compensations are the ones that do not need a second front end —
  goldens, `verify/` for any new lowering, `tests/spec/` for anything with a
  clause-shaped requirement, and the fixed point, which still holds because the
  compiler stays an Extended Pascal source.
- **`--std=afterschool` carries no stability promise yet**, and this record
  declines to invent versioning before there is anything to stabilise. The
  honest statement is that the dialect is what the compiler at hand defines, and
  a program pinning behaviour should pin a compiler version. When stability is
  promised it will be by a record that says so, and a versioned spelling is the
  escape hatch available then.
- **Three modes is a real cost in every harness**, not only in the compiler:
  `run_test.sh`, `irtest.sh`, `producttest.sh` and the coverage corpus each
  derive the standard from a path, and each gains a third case. The `.std`
  sidecar mechanism already generalises.
- **`doc/implementation-defined.md` is unaffected.** It describes a *conforming
  processor*, and the dialect is not one. Its §1 level-0 declaration and its
  list of two extensions continue to speak only for the first two modes.

## What this does not do

- **It admits no feature.** Sum types with payloads are the motivating case and
  are not decided here — not their spelling, not their representation, and not
  whether variant records are extended or something new is added beside them.
  That is the next record, and this one exists so that it can be argued on its
  merits rather than doubling as the decision to have a dialect at all.
- **It does not decide the memory-safety model, the text model or the memory
  model.** ADR-0109 named all three and each remains open. Nothing here
  prejudges them, and the admission rules above are deliberately silent on
  them — a feature touching one should be blocked on that record, not on this.
- **It does not make the dialect the compiler's own language.** See 3.
- **It does not remove `src/`.** Freezing is not retiring: it goes on comparing
  every conformance-mode source in the tree, which is 546 cases' worth of what
  must not regress.
