# 165. Extended Pascal is the default, and ISO 7185 stays reachable

Date: 2026-08-22

## Status

Accepted.

## Context

ADR-0033 made `--std=iso7185` the default because ISO 7185 was the only
standard implemented and the only language the compiler could be written in.
Neither is true now: both standards are complete, `selfhost/compiler.pas` is
itself an Extended Pascal source (ADR-0082), and ADR-0109's dialect —
`--std=afterschool` — **contains Extended Pascal** and not ISO 7185 (ADR-0117).
The default was pointing at the one of the three modes nothing is built on.

The question asked was whether ISO 7185 should be removed outright, for a
single unambiguous language. It was answered by measurement rather than by
argument, and the measurement is what this record is mostly for.

**The BSI Validation Suite survives the change almost intact.** All 812
programs were compiled both ways:

| | |
| --- | --- |
| compile identically under either standard | **811** |
| conforming program lost | **1** |
| rejections that stop being rejections | 17 (16 DEVIANCE, 1 EXTEND) |

The 17 are correct — Extended Pascal legalises what those programs deviate
from — so a catalogue built on Extended Pascal would be *more* honest, not
less. The one loss is the decisive fact: **`CONF005` is the program BSI wrote
in 1982 for exactly this decision.** Its header says the test "has been
constructed to contain a collection of identifiers that have been disallowed
by various implementations, or which are thought to be under threat of such
action … the wording of clause 5.1 makes it clear that the processor must be
able to accept all identifiers in its Standard-conforming mode; **an extended
mode may be needed**". It declares an enumeration whose constants include
`module`, `otherwise` and `restricted`.

**The corpus here says the same thing in miniature.** Of 154 ISO 7185 cases,
42 behave differently under Extended Pascal — and `tests/pointers.pas` is one,
because it has a field called `value`. That is the whole shape of the loss:
ordinary identifiers Extended Pascal reserves.

**And the silent surface is one clause wide.** Of those 42, exactly **one**
compiles under both standards and behaves differently: `trap_fieldwidth_iso`.
ISO 7185 §6.9.3.1 requires a field width "greater than or equal to one" and
ISO/IEC 10206:1991 §6.10.3.1 requires "greater than or equal to zero", so
`write('y':0)` traps under one and writes nothing under the other. Every other
difference is a diagnostic.

## Decision

**`--std=extended` is the default. `--std=iso7185` stays, and is not
deprecated.** Removing it would cost `CONF005`, the clause 5.1 a) compliance
statement written two days ago at level 1, and the ability to compile the one
corpus here that nobody wrote — for a simplification the measurement says is
worth much less than it looks.

**A default is a claim, and it is now pinned in both directions.** Nothing
checked it before, and two harnesses were riding on it:

- `verify/verify.py`'s crosscheck generator emits a program using `value` as an
  identifier. Its lowering rules are about arithmetic both standards share, so
  the mode belongs to the *generated source*, and it now says `--std=iso7185`.
- `tests/bsi/run.sh` compiled 812 ISO 7185 programs with no flag. It now says
  `--std=iso7185`, which is what the suite's own classifications mean.

Both now pass whichever way the default points, which is the property that
matters: the pins removed a dependency rather than absorbing a change.

`selfhost/producttest.sh` gained three checks — an unflagged `string(n)` must
compile, `--std=iso7185` must refuse it, and `--std=iso7185` must still accept
a program using `value` as a variable. Reverting the default fails the first by
name.

**`tests/dumps/run.sh` keeps its own `iso7185` default and now says why.** A
harness that inherited the compiler's would have recompiled five cases under
another standard and rewritten their goldens, which is the one thing a golden
must never do by itself.

## Consequences

**This is a breaking change to the command line, and the silent case is
`write(x:0)`.** A program compiled with no flag is now Extended Pascal. Almost
every program that minds will say so with a diagnostic — a reserved word used
as an identifier is a syntax error — but a program writing a field width of
zero changes from trapping to printing nothing, with nothing said. `CHANGELOG`
leads with it.

**ISO 7185 is not frozen by this.** It stays a maintained conformance surface
with its own corpus, its own compliance statement and its own oracle. What
changed is which language an unflagged source is assumed to be written in.

### What this does not do

**It does not remove anything, and it is reversible.** One assignment in
`ParseArgs`, one in `src/main.cpp`, one in `tools/pascalcc`.

**It does not make the two standards nested.** ADR-0033's reason stands
unaltered: §6.1.2 reserves thirteen word-symbols a conforming ISO 7185 program
may use as identifiers, so a source is written in one language or the other and
no default can make that go away. What a default can do is be right more often.

**It does not give a source a way to declare its own standard.** That is the
gap this change widens — an unflagged file is now assumed to be the language
most files here are *not* written in, and the repository's answer so far is an
out-of-band `name.std` sidecar. ADR-0166 is the in-band form.
