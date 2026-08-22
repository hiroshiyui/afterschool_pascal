# 163. A variant-denoter restricts more than this compiler knew

Date: 2026-08-22

## Status

Accepted.

## Context

ADR-0162 closed the first adversarial reading of the standards with one thing
left on the table: `CONF068`. Of the BSI Validation Suite's 236
`CLASS=CONFORMANCE` programs this compiler refuses exactly one, and a
deliberately refused conformance program is the only place in the one corpus
nobody here wrote where over-strictness could still be hiding. It was outside
every reader's brief, so it was recorded rather than answered.

The answer is that the refusal is correct as designed. `CONF068` declares a
record with `file of char` in two variant arms; ADR-0070 refuses that, and
`doc/implementation-defined.md` has carried it as a known deviation ever since.
Nothing about it has changed.

**What reading the clause properly found was two other things.**

### The citation named the wrong clause

Four living places said the permission belongs to §6.4.3.4. It does not, or
rather it does under only one of the two standards, and nothing said which:

| | ISO 7185 | ISO/IEC 10206:1991 |
| --- | --- | --- |
| Record-types | **6.4.3.3** | **6.4.3.4** |
| Set-types | 6.4.3.4 | 6.4.3.5 |
| File-types | 6.4.3.5 | 6.4.3.6 |

Extended Pascal inserts String-types at 6.4.3.3 and everything below it shifts
by one. So a bare "§6.4.3.4" beside an ISO 7185 program — which is what
`tests/bsi/expected.tsv` had against `CONF068`, a `LEVEL=0` ISO 7185 test whose
own header cites 6.4.3.5-4 — points at **Set-types**. `README.md`,
`doc/implementation-defined.md` and both compilers' comments said the same.

This is ADR-0072's failure mode exactly: a citation nothing checks, repeated
until it looks corroborated. `spec-clause-traceability` cannot see it, because
it gates the clause **tags** in `tests/spec/`, and prose citations are not tags.

### The clause has a sentence this compiler never read

ISO/IEC 10206:1991 §6.4.3.4 says, of the very construct ADR-0070 was about:

> A variant-denoter shall not contain a type-denoter denoting either a
> restricted-type or the bindability that is bindable or denoting a
> structured-type having any component whose type-denoter is not permissible as
> a type-denoter contained by a variant-denoter.

ISO 7185's §6.4.3.3 has no counterpart; neither word-symbol exists there. This
compiler accepted all three limbs:

```pascal
type r = restricted integer;
     v = record case boolean of true: (a: r); false: (b: integer) end;
```

compiled and ran under `--std=extended` and `--std=afterschool` alike, as did
the `bindable` spelling and both reached through a container.

**It is a violation and not an error**, which is what makes it compulsory
rather than optional. Annex D's `D.3` for §6.4.3.4 is the discriminant-selector
rule and names nothing here, so clause 5.1 e) applies: the processor "shall be
able to determine whether or not the program violates any requirements of this
International Standard, where such a violation is not designated an error or
dynamic-violation, report the result of this determination to the user of the
processor before the activation of the program-block, if any, and shall prevent
activation of the program-block".

## Decision

**Both limbs are refused, and neither is gated on `--std`.** `restricted` and
`bindable` are word-symbols of Extended Pascal alone, so under ISO 7185 the
constructs cannot be spelled in that position at all and a mode test would be
dead code. The dialect contains Extended Pascal (ADR-0117), so it inherits the
rule with no site of its own.

**The two limbs are asked two different ways, and the split is forced.**
`ContainsRestricted` is a recursion over the resolved *type*, mirroring
`ContainsFile` — restrictedness is `tyRestricted`, so the clause's third limb
costs one predicate. Bindability is not on a type: §6.4.1 makes it a property
of the **type-denoter**, and a field records none, so `BindableOf` is asked of
the denoter at the call site. That asymmetry is the clause's, not an
implementation convenience — `type bint = bindable integer` hands bindability
on, so an arm must be refused for a word it does not itself contain.

**The citation is corrected to name both numbers wherever it appears.** Writing
"one clause under two numbers" costs a clause and removes the question a reader
would otherwise have to answer with two standards open.

## Consequences

`tests/extended/variant_denoter.pas` is the case, and it carries the legal
control in the same file: the same two types in a **fixed part** draw no
diagnostic, because the restriction is on the variant-denoter and nowhere else.
Four scenarios join `@extended:6.4.3.4` in `tests/spec/`.

**The coverage ratchet found a hole in the first version of the test**, which
is the part worth recording. `ArmsContainRestricted` was entered by nothing:
the test reached a nested record's *fixed* fields but never a nested
**variant-part**, and `procedure-coverage` said so before any human read it.
The case `deep`/`bad5` exists for that walk alone. The final change adds
**zero** unreached statements — `line-coverage` passes without the ratchet
being regenerated — and getting there meant factoring the arm's
error-attribution, which had been written out three times and would have
counted one unreachable recovery path three times over.

Three mutations, each killing a named test:

| mutation | what fails |
| --- | --- |
| drop the `ContainsRestricted` check | `variant_denoter`, and `difftest` — the front ends disagree |
| drop the `BindableOf` check | `variant_denoter`, missing exactly the `bindable` line |
| stop `ContainsRestricted` reaching through a container | `variant_denoter`, missing exactly the three containment lines and keeping the three direct ones |

### What this does not do

**It does not catch `bindable` reached through a container.** The clause's
third limb covers both words, and this compiler applies it to `restricted`
only, because a field records no bindability — `fieldRec` has no flag for it
and `AddField` is handed a type rather than a denoter. A record with a
`bindable` field, used in a variant arm, is still accepted. The case is narrow
today for a second reason: `bind` is refused for any component, so a bindable
field is inert here in every other respect as well. Adding the flag is the fix
if either changes. `doc/sop.md` §7 carries it.

**It does not revisit ADR-0070.** The file refusal stays a deviation, argued
where it was argued. What changed is the clause it is a deviation *from*.

**It does not audit the other 235 `CLASS=CONFORMANCE` programs individually.**
All 812 BSI programs are run on every `ctest` and any movement in either
direction fails (ADR-0086); what this record closes is the one entry the
catalogue marked `REJECTED`, which no re-run could have flagged.
