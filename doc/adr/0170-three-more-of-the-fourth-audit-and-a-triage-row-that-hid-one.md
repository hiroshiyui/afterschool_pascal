# ADR-0170: Three more of the fourth audit, and a triage row that hid one

Date: 2026-08-22

## Status

Accepted. Continues ADR-0168, which recorded the fourth
`.claude/skills/langspec-audit/` run and adjudicated two of its findings
before the v2.0.0 tag; ADR-0169 took two more. This one takes three.

## Context

ADR-0168 closed with a list of findings "pre-existing … recorded here rather
than in a reader's report so that they survive the session", each needing
step 7 — the probe reproduced and the clause re-read — before being believed.
Three of them are now adjudicated. All three reproduced; one of them turned
out to be two defects in opposite directions, and one arrived attached to a
second claim that did **not** reproduce.

## Decision

### 1. §6.9.4 b) reaches a conformant array's actual

> **§6.9.4** A statement S shall be designated as threatening a
> variable-access V if one or more of the following statements is true. …
> b) S contains V in an actual-parameter that is an actual variable parameter
> corresponding to a formal variable parameter that is not protected (see
> 6.7.3.1).

A variable conformant array is a formal variable parameter, and §6.7.3.7.3
says so in those words — "Each actual-parameter corresponding to a formal
variable parameter shall be a variable-access". §6.5.1's own cross-reference
settles the rest: "No statement shall threaten (see 6.9.4) a variable-access
closest-containing a protected variable-identifier (see 6.7.3.1, **6.7.3.7.1**,
and 6.11.3)" — §6.7.3.7.1 being there because a
conformant-array-parameter-specification may itself say `protected`.

The conformant-array arm of the argument check is separate from the ordinary
var-parameter arm and never asked. Both consumers of §6.9.4's answer were
therefore wrong, and in opposite directions:

- **`protected` was defeated, silently.** A protected parameter handed to an
  unprotected variable conformant array was written through, exit 0 — through
  a record field too, §6.9.4 h) reaching the container — and a protected
  conformant array could be handed on to an unprotected one, which is the
  base case b)'s "that is not protected" exists to create.
- **§6.7.2's result rule could not see the threat.** A function that fills its
  result by handing it to a conformant array procedure was refused with "never
  writes to its result variable". That is ADR-0169's `new` defect one letter
  of the same list over, and it is the second time this list's incompleteness
  has been an over-strictness rather than a permission.

The value form is deliberately not a threat: §6.7.3.7.2 attributes the
*expression's* value to a variable of the activation, so nothing of the actual
is written. The guard asks the parameter kind for that reason, and the third
mutation is what pins it.

`tests/extended/protected_conformant.pas` and
`tests/extended/conformant_threatens_result.pas` are the two directions;
`funcresult_errors.pas` gained the value-form case beside `mute` and `spoken`,
which were already the same distinction one construct along.

### 2. §6.9.3.9.1's control-variable shall be nonbindable

> **§6.9.3.9.1** The control-variable shall be an entire-variable whose
> identifier is declared in a variable-declaration-part of the block
> closest-containing the for-statement. The control-variable shall possess an
> ordinal-type **and shall be nonbindable**.

Two requirements in one sentence and only the first was asked, so
`var i: bindable integer` was a legal control variable.

The second is not decoration. §6.5.1 makes a bindable variable
totally-undefined while it is unbound, so a loop over an unbound one attributes
a value to a totally-undefined variable — Annex D's error — and a loop over a
*bound* one writes an external entity once an iteration, which the equivalent
program fragment of §6.9.3.9.2 says nothing about. The clause resolves it
statically instead. It is not an Annex D error, so §5.1 e) requires it reported.

No `--std` guard: `bindable` is not in ISO 7185's lexis, so no ISO 7185 program
can possess the bindability this refuses. The question goes through
`DesignatorBindable`, which is where §6.4.3.4's and §6.4.3.5's "the bindability
denoted by the type-denoter" is decided for every other caller.

### 3. A constant-access naming a structured component read as all-zero

> **§6.8.8.1** The value and type of a constant-access shall be the value and
> type, respectively, either of the constant-name of the constant-access or of
> the indexed-constant, field-designated-constant, or substring-constant of the
> constant-access-component.

§6.3's Examples exercise the scalar half — `UnitDistance = Unit.r` and
`column1 = BlankCard[1]` — and that half was right. A name bound to a
**structured** component was not:

```pascal
const grid = outer[1: inner[1:1; 2:2; 3:3]; 2: inner[1:4; 2:5; 3:6]];
      row  = grid[2];
```

`row[i]` printed 0 where `grid[2][i]` printed 4, 5, 6 — in one program, with no
diagnostic. `H.b` for a record was the same.

The cause is ADR-0069's arrangement read one step too narrowly. A §6.8.7
constructor has no LLVM initialiser, so its constant is a zeroed global filled
by the prologue of the block that defined it, and the test for "the block that
defined it" was whether the folded node *is* the written expression. A
constant-access is not: the fold answers with the component's node, which lives
inside the containing constant's value, and `ConstAddress` memoises that node
into a global of its own — keyed on a different node from the container's, so
nothing ever filled it.

Two spellings define such a constant and both now count. What must still not
fill is a plain constant-name: `const b = a` hands on `a`'s node, so `b` shares
`a`'s storage and filling it again would write it once per activation of `b`'s
block, which need not be `a`'s. A module-qualified name (§6.11.3) is that same
alias.

Only `nkStructValue` was affected. A string component, a set component and a
whole-constant alias were all correct before and are the test's controls.

**The reader's second claim did not reproduce.** "A constant-access takes its
type from the written expression rather than from the component" is not what
this compiler does: `row` possesses `inner` and `H.b` possesses `rs`, in an
assignment that succeeds, in one that fails, and in the diagnostic's own words.
It is recorded as not reproduced rather than as fixed.

### 4. The triage row that hid the third

§6.8.8.1 was classified `structural` in `tests/spec/clauses/triage.tsv` —
"introduces the subclauses below it; states no requirement of its own" — and
the sentence quoted above is a requirement, the one defect 3 broke.

This is the failure direction ADR-0106 names and
`.claude/skills/langspec-audit/SKILL.md` step 5 asks a reader to hunt: a
requirement filed as `structural` leaves the denominator, so no scenario is
ever asked for and `pending.txt` — the work queue — never names it. A wrongly
`testable` clause only wastes someone's time; this one cost a defect that
printed wrong data.

It is `testable` now, and cited.

## Consequences

Four new cases, four new scenarios, and six mutations across the three fixes,
each naming the test it killed. `tests/extended/funcresult_errors.pas` gained
its case through a type-definition-part written *after* a function-declaration
— §6.2.1's interleaving (ADR-0069) — so that no line number in the existing
golden moved and the goldens above it were not regenerated.

Six clauses off `pending.txt`: §6.5.1, §6.7.3.7.1, §6.7.3.7.2, §6.7.3.7.3,
§6.8.8.2 and §6.8.8.3, with §6.8.8.1 added to the denominator and cited in the
same change.

**Two of the three change what an already-valid program does**, and that is the
half a user cannot see coming:

- a program that passed a `protected` variable to a variable conformant array
  compiled and now does not, which is the rule working;
- a program that read a constant bound to a structured component read zeros and
  now reads the component, which is a *silent* change of printed output. There
  is no spelling under which the old behaviour was right, so no deprecation is
  offered — but it belongs in release notes rather than in a changelog line
  nobody reads.

### What this record does not do

It does not adjudicate the rest of ADR-0168's list, which stands as written
there minus these three.

One thing was reached a second time on the way. ISO/IEC 10206:1991 §6.7.5.6
says of `bind(f,b)` that "If the variable-access f possesses a file-type, it
shall be a dynamic-violation if the variable does not possess the bindability
that is bindable; **otherwise, the variable shall possess the bindability that
is bindable**", so a *non-file* bindable variable is bindable and this compiler
answers `'bind' needs a file variable`. That is **not** new — ADR-0167's third
reader found it and `doc/roadmap.md` has carried it since, as a design owed
rather than a bug, and this record does not change that verdict. What was
missing is that `doc/implementation-defined.md` §6 did not name it, and §6 is
the list a user searches for "programs the standard admits and this processor
refuses". It does now. Being on a work queue is not being documented, and the
two lists have different readers.
