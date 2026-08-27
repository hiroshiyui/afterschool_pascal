# 223. The compiler checks its own variant record

Date: 2026-08-27

## Status

Accepted.

## Context

`selfhost/compiler.pas` has exactly **one** variant record. `case kind:`
appears once in 36,000 lines, and it is the AST — 63 arms, read by the parser,
Sema, both dump walkers and the code generator. Symbols and types carry an
ordinary `kind` field, which is why the 29 `^.kind :=` assignments elsewhere
are harmless.

ISO/IEC 10206:1991 §6.5.3.3 makes reading a field of an inactive variant an
**error**, and §3.1 lets a processor leave an error undetected.
`selfhost/compiler.std` says `extended`, so this compiler leaves it
undetected — in itself. A wrong-arm read of a node is silent rubbish, and where
the field is a pointer the next walk follows it.

**ADR-0118 already fixes this, for programs that ask.** Under
`--std=afterschool` a write to a variant's field activates that variant and a
read of an inactive one traps. The check is built, specified, tested and
mutation-tested. The compiler was not using it on itself.

| build | occurrences of the trap message |
| --- | --- |
| `--std=extended` (what ships) | 1 — a string constant the emitter carries |
| `--std=afterschool` | **2821 guards** |

## Decision

`variant-check` builds a second compiler from the same source under
`--std=afterschool` and compiles the corpus with it — 1019 sources under
`tests/`, `selfhost/` and `lib/`, each with `--dump-all` so both walkers run
and not only the four passes, which is how `difftest.sh` drives them and for
the same reason.

**The shipped compiler does not change.** This is `llc_check.sh`'s shape: a
second build used only as a reader, never as the product. `compiler.std` stays
`extended`, so the fixed point `irtest.sh` proves is untouched.

That distinction is what makes this different from the alternative ADR-0190
rejected. That record considered making `selfhost/compiler.std` say
`afterschool` so the compiler could call the Unicode runtime, and refused it
because *"the fixed point holds only while the compiler is an Extended Pascal
source"*. The objection is about the **product**. Nothing here is the product.

## That it works is measured, and the mutation is the argument

A wrong-arm read that changes what a program prints is caught by a golden, so
it proves nothing about this. The mutation that matters is one whose value is
**right by accident**: `nkStr` is `(stAt, stLen: integer)` and `nkVar` begins
`(vrAt, vrLen: integer)`, so the two pairs occupy the same storage. Reading
`n^.vrAt` on a string node yields exactly `n^.stAt`.

`DumpExpr`'s `nkStr` arm was changed to do that, and:

| oracle | verdict |
| --- | --- |
| `ctest`, all 808 | **green** |
| `selfhost/difftest.sh`, 882 files | **both compilers agree stage for stage** |
| `tests/spec/`, 323 scenarios | **green** |
| `variant-check` | **582 of 1019 sources** |

Every existing oracle agreed with the defect, including the two independent
front ends, because the value printed was identical. That is the whole case for
this record: it is the only thing here that can see a wrong-arm read, and the
reads it sees are exactly the ones nothing else can.

It also refuses to pass by asking nothing. A guarded build carrying fewer than
100 guards fails rather than succeeding, because a change that stopped emitting
ADR-0118's check would otherwise turn this green.

## Consequences

**It costs 8.5 seconds** — the second translation, one `clang -O2`, and 1019
compilations. It is a `ctest` case rather than a CI job for that reason: it runs
before a push, as every gate here does but `model-drift`.

**A compilation and not a run.** Every pass that touches a node runs during a
compilation; running the compiled program says nothing about the compiler's own
AST.

**Its failure to build is a containment defect, not a skip.** ADR-0117 makes the
dialect contain Extended Pascal, so a source `--std=extended` accepts must
compile under `--std=afterschool`. If it does not, this says so in those words
rather than skipping.

**What it cannot see** is §6.4.3.3's tagless variant part, which `doc/sop.md` §7
already carries: there is no tag to compare against, so such a record stays an
unchecked union under the dialect too. The AST's variant part has a tag, so this
covers it — and a *second* variant record added without one would be outside
this silently. That is the row to widen if one ever is.

It also cannot see a wrong-arm read on a path no corpus source takes, which is
the ordinary limit of a dynamic check and the reason `ast-fields` (ADR-0222)
sits beside it asking a static question about the same record.

## Alternatives

**Make `selfhost/compiler.std` say `afterschool`.** ADR-0190 considered and
rejected this, and the rejection stands: it changes the product, and the fixed
point holds only while the compiler is an Extended Pascal source. Building a
second compiler costs 8.5 seconds and gives up nothing.

**Run the whole `ctest` suite against the guarded compiler.** It is what was
done by hand while measuring — 807 cases, 323 scenarios and difftest's 882
files all pass with the guards armed — and as a gate it would be a test that
runs the suite, doubling every case's cost to exercise one binary. Compiling
the corpus reaches the same code.

**Trust the mutation harness instead.** `tests/mutation/` is 31 mutants, each
written by someone who thought of it. The whole point of a wrong-arm read is
that it is the mistake nobody thought of; a guard that checks 2821 sites on
every run is not the same instrument as 31 hand-written cases.
