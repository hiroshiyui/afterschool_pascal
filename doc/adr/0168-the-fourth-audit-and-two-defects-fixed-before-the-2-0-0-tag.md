# ADR-0168: The fourth audit, and the two defects fixed before the 2.0.0 tag

Date: 2026-08-22

## Status

Accepted. The fourth run of `.claude/skills/langspec-audit/`; ADR-0101 and
ADR-0107 record the first, ADR-0162 the second, ADR-0167 the third.

## Context

The audit was aimed at what ADR-0167 left: ISO/IEC 10206:1991's still-uncited
clauses. Four readers, one group each.

1. §6.8.7.x structured-values and §6.8.8.x constant-accesses.
2. §6.9.2.3–4, §6.9.3.9.x, §6.9.3.10, §6.9.4 — the statement clauses and the
   threat rule.
3. Clause 6.10 — textfiles and the write procedures.
4. §6.4.3.3.x, §6.4.5, §6.4.6, §6.5.6, §6.7.5.5 — string-types, compatibility
   and assignment-compatibility.

They returned roughly two dozen findings between them. **All four disclosed
that the harness injected `CLAUDE.md` before their first turn**, which is the
row `doc/sop.md` §7 already carries: a CONFIRMED verdict from this skill means
"no independent oracle contradicts it", not "an uninfluenced reader agreed".

This record covers **two** of those findings — the two adjudicated and fixed
before the v2.0.0 tag, chosen because they are the two that a program cannot
work around and cannot see coming. The rest are unadjudicated and are listed
below so that nobody reads their absence as a clean bill.

## Decision

### 1. A string value assigned to a `char` (§6.4.5 d), §6.4.6 f))

Two clauses have to be read together, and reading one of them is enough to
write the defect:

> **§6.4.5** Types T1 and T2 shall be designated compatible if any of the
> following four statements is true: … d) T1 is either a string-type (see
> 6.4.3.3) or the char-type and T2 is either a string-type or the char-type.

> **§6.4.6** A value of type T2 shall be designated assignment-compatible with
> a type T1 if any of the following six statements is true: … f) T1 and T2 are
> compatible, T1 is a string-type **or the char-type**, and the length of the
> value of T2 is less than or equal to the capacity of T1.

So `c := s` for `c: char` is legal, and §6.4.6's last paragraph says what it
means: the value is treated as a fixed-string value of the destination's
capacity, "followed by zero or more spaces". A char has capacity one, so a
one-character value stores that character and the null-string stores a space.
The error list's c) makes a longer value an *error*.

Sema had this right — it accepts the assignment on §6.4.5 alone. **CodeGen
asked the wrong predicate.** The guard choosing the string path in `EmitStore`
read `IsStringType(t)`, which is false for `char`, so the assignment fell past
it into the scalar store and stored the string's *pointer* into an `i8` slot.
Ten spellings emitted `store i8 %v6, ptr %v5` — IR that `clang` refuses, so the
program's author saw an LLVM error naming a temporary file they never wrote —
and `c := s[i..j]` stored `chr(0)` and said nothing.

`EmitStringStoreValue` **had the char arm all along**, calling
`@pas_str_store_char`, whose body is `pas_str_fits(len, 1)` and
`*dst = len == 1 ? src[0] : ' '` — the clause's error and the clause's padding,
both already written. The whole defect was one predicate in the caller keeping
an assignment from reaching correct code. The guard now asks `IsStringOrChar`,
excludes two chars because that is an ordinary scalar store, and adds
`IsChar(t)` to the disjunction because a char has no `TypeLength` to compare.

This is CodeGen only, so `src/` is unaffected — and ISO 7185 is unaffected
because it has no such rule: there `c := f` over a `packed array [1..1] of
char` is refused by Sema in both directions and CodeGen is never reached.

### 2. An initial-state-specifier after a discriminated-schema (§6.4.1)

§6.4.1 offers the specifier after any of four bases:

> type-denoter = [ `bindable` ] ( type-name | new-type | type-inquiry |
> discriminated-schema ) [ initial-state-specifier ] .

> If an initial-state-specifier occurs in a type-denoter, the type-denoter
> shall denote the initial state that is denoted by the initial-state-specifier
> (see 6.6) …

with no exception for which base it followed, and §6.2.3.5 then creates each
variable "in its initial state".

`CheckVarDecl` has two paths, because §6.2.3.2 lets a discriminated schema's
discriminants be variables and that needs a resolution of its own. The schema
path resolved the denoter — which runs `CheckInitialState`, so a *wrong* value
was still reported — and then returned without ever calling `InitialStateOf`.
`init := InitialStateOf(g^.grType)` lived only in the other path.

So the two spellings of one declaration disagreed:

```pascal
type s4 = string(4);
var a: string(4) value 'jk';   { the state was dropped }
    b: s4 value 'jk';          { the state was honoured }
```

A **global** was merely zeroed, which is benign and invisible. A **local** was
left reading whatever the frame slot held: `writeln(t)` wrote the stack, 4099
bytes in one run and 20,909 in the reader's. That is an information disclosure
with no diagnostic, in a program that looks correct and whose type-name
spelling works.

`src/sema.cpp` carried the identical defect — the port is line-for-line and so
was the bug — and now carries the identical fix.

## Consequences

Three cases, and two mutations killing two different tests:
`tests/extended/char_from_string.pas` sweeps nine spellings of the char
destination including the space-padding, `tests/extended/trap_char_capacity.pas`
pins §6.4.6 c)'s error, and `tests/extended/initial_state_schema.pas` covers
both storage classes and the group-sharing. Seven scenarios were added under
`@extended:6.4.1`, `@extended:6.2.3.5`, `@extended:6.4.5` and `@extended:6.4.6`,
which is four clauses off `pending.txt`.

**One gate blind spot was found and is now registered.** The second defect sat
identically in both front ends and `difftest` was green over it, because
`--dump-sema` does not print a symbol's initial value. "difftest agrees" covers
what Sema *prints*, not what Sema *decides*; `doc/sop.md` §7 carries the row.
Widening the dump was rejected — the goldens would churn on every field added
to a symbol — so the compensating rule is ADR-0108's unchanged: a Sema change
lands in both front ends on its merits, not because an oracle asked.

### What this record does not do

It does not adjudicate the other findings. They are pre-existing — none is a
regression since v1.8.0 — and they are recorded here rather than in a reader's
report so that they survive the session. Verbatim from the reports, unverified:

- Clause 6.10's fixed-point representation is add-half-then-truncate where
  §6.10.3.4.2 prescribes an algorithm conditioning the sign on the *rounded*
  magnitude; a reader implementing the clause swept 2576 triples and found 131
  disagreements, `0.125:6:2` among them, and a `-0.00` the clause legislates
  away. The same rounding question is raised for the floating-point form, and
  left partly UNSETTLED there.
- §6.9.4 e) makes `new(p)` a threat to `p`, which is unimplemented, so a
  function that allocates its own result variable is refused.
- §6.9.4 b) is not applied to actuals of variable-conformant-array parameters,
  which also leaves `protected` unenforced on one.
- A constant-name bound to a *structured* component of a constant reads as
  all-zero; a constant-access takes its type from the written expression rather
  than from the component.
- §6.9.3.9.1's "control-variable … shall be nonbindable" is unchecked.
- A value parameter of a fixed-string type admits only an exactly-equal-length
  actual.
- `value` on a discriminated-schema in a *parameter* position, and §6.4.6 d)'s
  dynamic-violation between two variable-strings of different capacity.

Each needs step 7 — the probe reproduced and the clause re-read — before it is
believed, which is the step that moved two verdicts in ADR-0167.
