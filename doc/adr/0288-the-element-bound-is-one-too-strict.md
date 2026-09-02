# 288. The element bound is one too strict, and the model agreed with it

Date: 2026-09-02

## Status

Accepted, 2026-09-02. Records a `langspec-audit` of ADR-0287's readings. The
over-strictness it found is **not fixed here**; see *What is not done*.

## Context

ADR-0287 gave Sema a bound on a type's storage and moved the layout arithmetic
to ApFront. It sits beside an older bound — an array's index-type may span at
most `maxint` values — enforced since the conformance sweeps and, until
ADR-0287, documented in no `doc/*.md` at all. Both are readings, and
`doc/sop.md` records that no oracle here can contradict a reading.

An audit was run under `.claude/skills/langspec-audit/`, in the built sandbox
(ADR-0228): the two standards, a working `pascalcc`, the compiler's source with
every comment stripped, and nothing else. The reader confirmed no project
documentation reached it.

## Decision

Record what the audit settled.

**CONFIRMED — refusing a type above `maxint64` bytes.** ISO 7185 §1.2 a): *"This
International Standard does not specify a) the size or complexity of a program
and its data that will exceed the capacity of any specific data processing
system or the capacity of a particular processor, nor the actions to be taken
when the corresponding limits are exceeded"*. A type of 1.8e19 bytes exceeds
this processor's capacity, and the action on exceeding it is unspecified, so
refusing is permitted.

**CONFIRMED — accepting a 2.4 GB record.** §5.1 a) and b) require a processor to
accept the features of clause 6, and nothing bounds a record's size.

**CONFIRMED — the storage bound belongs in `doc/implementation-defined.md`.**
AP 5.1 i) says this language's specification does not specify *"any
representation, storage layout or calling convention"*, so a bound in **bytes**
cannot be stated there. §1.2 a) makes it a processor capacity, and clause 5.1's
accompanying documentation is where a capacity is recorded.

**OVER-STRICT — the element bound refuses `array [0..maxint] of char`.** The
compiler refuses a **2 147 483 648**-byte array while accepting a
**2 400 000 000**-byte record, so the refusal is not a capacity limit and §1.2 a)
does not cover it. `array [1..maxint] of char` is accepted and
`array [0..maxint] of char` is not; `array [integer] of char` is refused too.

**And the reason is an off-by-one that the model shares.** The lowering
subtracts `i - lo` without a check, so what the bound must guarantee is that
`hi - lo` is a value of the integer type — which is `-maxint..maxint`, so
`hi - lo <= maxint`. The compiler refuses at `hi - lo >= maxint` and
`verify/iso.py`'s `index_span_is_representable` says `hi - lo < maxint`, while
its own docstring gives the `<=` justification. **The two agree, so `verify/`
proves the lowering correct under a precondition stricter than its own stated
reason, and no gate can see it** — ADR-0072's shape, met in a proof rather than
in a document.

The relaxation is sound and that is not an argument: with the predicate changed
to `<=`, **all 48 rules still prove**, `accepted-index-selects-the-right-element`
among them. `array [integer] of char` stays refused on the correct ground —
`hi - lo` is `2 * maxint` there, which is not a value of the integer type.

## What is not done

The fix is not one line and is not in this record's change. It needs
`TypeLength` widened to `int64` in ApTypes, since `maxint + 1` elements is not
an `integer`; the bound restated as `hi - lo > maxint`; `verify/iso.py`
relaxed in the same commit, ADR-0013's rule being that the model moves with the
lowering; and a case for each of the three shapes. It is a language change —
programs this compiler refuses today would compile — so it takes its own record
and its own release note.

Ranked as the audit ranked it: **high likelihood of mattering**, because
`0..maxint` is how a Pascal programmer spells "as large as an index can be",
and low likelihood of breaking anything, because it only ever accepts more.

## Consequences

**A reading that has survived an adversarial check is a different thing from
one that has not**, and the three CONFIRMED above are now the first kind.

**The audit's own harness has a defect worth recording**: the reader could not
run `bin/pascalcc`, could not run `pdftotext`, and could not write into
`probes/` — the sandbox's tool permissions refused all three — so it returned a
documentary verdict where the skill asks for compiled probes. Every probe in
its report was reproduced by hand here before any of it was believed, and the
over-strictness is stated above on reproduced evidence and a re-run proof
rather than on the reader's say-so. A sandbox whose compiler cannot be invoked
is a sandbox that cannot do the job the skill describes.
