# 194. A predicate is not a case-statement, and nothing was reading one

Date: 2026-08-25

## Status

Accepted. `predicate-kinds`, the twenty-first gate, and `--dump-predicates`
behind it.

## Context

ADR-0124 and ADR-0145 built `kind-exhaustive` on a sentence: a `case … of` over
an enumeration with a constant left off is a compiler **crash**, not a wrong
answer, and no other oracle can see it. It reads all twelve enumerations and 55
case-statements, and it works — adding `tyText` failed it six times, once per
case that needed the arm, and each was a real decision.

It reads case-statements and nothing else. **Three defects in three
increments** lived in a predicate instead:

- **ADR-0191.** `IsMemory` was `IsStructured or IsOwned or IsVarString`, so a
  freshly added `tyText` was not memory, so the relational operators took a
  text for a simple type and emitted `icmp eq { i32, [64 x i8] }`. clang
  refuses it — "an error about a file nobody wrote", ADR-0139's defect
  reproduced by adding a kind.
- **ADR-0191 again**, one level down: the code generator's comparison dispatch
  had the same shape and needed the same arm.
- **ADR-0193.** `EmitAssign` selects the string store with
  `if IsStringType(t)`, and a text is not a string-type — so `t := s` fell
  through to the schema tuple-comparison, which reads the *destination's*
  schema without asking whether the source came from the same one. It compared
  a string's capacity against a text's and stopped the program.

None is a case-statement. All three were found by **writing a program that used
the new type** — the first two by probing every operation by hand on the day
the kind existed, the third by writing the library the type exists to be used
through. That is ADR-0182's lesson a third time and it is not a thing a gate
does.

## Decision

**The compiler reports what every type-classifying predicate answers about
every kind of type, and a catalogue records it.**

`--dump-predicates` builds a fresh `NewType(k)` for each of the 21 `typeKind`
constants and asks each of the 36 `function Is…(t: typePtr): boolean` about it,
printing one row per predicate:

    kinds 21: tyVoid tyInteger tyReal …
    IsMemory 7 of 21: tyArray tyRecord tyFile tyOptional tyHandle tyString tyText
    IsStringType 1 of 21: tyString

**`N of M` is the whole mechanism**, and it is `partial_cases.txt`'s
(ADR-0145). Adding a kind moves `M` on every row, so all 36 fail and each is a
question: *should this predicate be true of the new kind?* That is exactly the
moment all three defects needed a reader and did not get one.

**It is a prompt, not a proof, and the catalogue says so in its own header.**
The file records what the answers *are*, not what they should be; a wrong cell
written into it passes. Every other catalogue here has the same shape and
`unreachable_diagnostics.txt` is honest about it too — what cannot pass is
nobody looking.

**Two halves**, which is ADR-0148's shape for `buffer-headroom` and ADR-0144's
lesson about a gate holding both sides of its own comparison. The compiler
answers, and the **source** says which predicates exist: the gate greps
`selfhost/compiler.pas` for the signature and requires the dump to name exactly
that set, so a predicate added without a row fails rather than passing unseen.

**The signature is the definition** of "a type-classifying predicate":
`function Is…(t: typePtr): boolean`. It is narrow on purpose. A routine taking
more than a type is asking about more than a type, and `Assignable` and its
relatives are swept from the other end by `predicate-callers` (ADR-0146).

**The reported answer is the flag-clear one.** A fresh `NewType(k)` has no
element, no flags and no fields, so `IsFallible` reports `tyRecord` as false and
every predicate that looks through `Base()` reports `tySubrange` as false. Both
are stated in the header rather than hidden, and both are the *default* answer
— which is where all three defects were.

## Consequences

**Three directions, each demonstrated.** A predicate whose answer changes:
reintroducing ADR-0191's `IsMemory` defect moves one row and fails. A kind
added: a probe constant changes `of 21` to `of 22` on all 36 rows. A predicate
declared and not dumped: the source half names it and fails.

**`tyVoid` and `tySubrange` are true of no predicate at all**, which the dump
now makes visible by listing the kinds before the answers. The first is
correct — it is the absence of a type — and the second is a property of the
probe rather than of the language: every ordinal predicate looks through
`Base()`, and a subrange with no host to look through answers no to all of
them. Making that visible is worth more than hiding it, and it covers two case
arms that were otherwise unreachable.

**`tests/dumps/` gains a case**, because ADR-0103 found four documented
`--dump` flags that no case in the tree had ever passed. The gate reads the same
output for a different question, so the two are not one reader.

**Twenty-one gates.** `doc/sop.md` §7's row on this blind spot is struck: it
stood for one increment with one instance, gained two more, and is closed by
the gate those three argued for.

## What this does not do

**It does not know which answer is right.** Above, and it is the honest limit.
A reader who regenerates the catalogue without thinking gets a green bar and
the defect. What the gate guarantees is that the reader is *asked*.

**It does not see a predicate's callers.** Whether `IsMemory` is asked in the
right places is `predicate-callers`'s question from the other end, and neither
gate covers the middle: a call site that asks the *wrong predicate* — which is
what all three defects actually were — is visible to neither. What this closes
is the narrower thing: a predicate whose answer for a new kind nobody
considered.

**It does not cover a predicate with a different signature.** `ContainsFile`,
`HoldsFile`, `StaticThroughout` and the rest take a type and answer a question
that is not a classification; widening the signature is a decision and would
need a different catalogue shape, since their answers depend on what a type
*contains* rather than what it is.

**It reports one type per kind.** A predicate that distinguishes two types of
one kind — a packed array from an unpacked one, a fallible record from an
ordinary one — reports only the default. `IsCharArray` answers `0 of 21` for
that reason, which is accurate and uninformative.

## Alternatives rejected

**Parsing the predicate bodies and evaluating them symbolically.** The bodies
are regular enough — five shapes, all inside a small boolean grammar — and a
three-valued evaluator would have given a richer matrix, distinguishing "false
for every type of this kind" from "depends on a flag". Rejected because it
reads the *source* where the compiler can be asked, and CLAUDE.md is explicit
that source-reading is the weaker oracle in every case: `kind_exhaustive.py`
and `reserved_words.py` both do it and both say so. ADR-0148 gave
`buffer-headroom` a second half the compiler answers for exactly this reason.

**Deriving the predicate list inside the compiler** rather than writing out 36
`Row(…)` calls. Pascal has no reflection, so there is no way; what makes the
written list safe is that the gate checks it against the source, which is the
half ADR-0144 found missing from `foreign_reserved.py`.

**Failing only when a kind is added**, rather than on any change of answer.
Cheaper and one-directional, and it would have missed ADR-0191's `IsMemory`
defect entirely — that was a wrong answer for a kind that already existed by
the time the fix landed. Both directions, as every catalogue here.

**Adding the three defective call sites to `predicate-callers` instead.** That
gate sweeps one predicate's callers and derives the positions from the source;
extending it to "every call site of every predicate" is a much larger and much
vaguer question, and it would still not have caught these — the call sites were
not wrong about `Assignable`, they asked a predicate that gave the wrong answer.
