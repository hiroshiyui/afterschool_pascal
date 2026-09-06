# ADR-0342: What an audit found that every oracle was green over

Date: 2026-09-06

## Status

Accepted. Three fixes to `selfhost/apfront.pas` and three to
`doc/afterschool-pascal-spec.md` (`c3ffb0a`). Does not supersede ADR-0319,
ADR-0320 or ADR-0327; it is the first audit of the memory model those records
built, and it corrects a claim ADR-0319's clause made.

## Context

`langspec-audit` was run over the memory model and memory safety: the
unchecked ordinary pointer (AP 6.4.4.3), owned pointers and `take`
(AP 6.4.14), handles and container ownership (AP 6.4.12, ADR-0337), the
borrow rule (AP 6.4.14.7 to 6.4.14.9), and what two threads of control do to
each alias rule (AP 6.4.16, AP 6.7.8). Six independent readers, each in
ADR-0228's sandbox, given the specification and a compiler and no reasoning.

**The suite was green over every finding below.** So were `sanitizers`,
`heap-balance`, `thread-sanitizer`, `verify/` and the stage-2/stage-3 fixed
point. That is the ordinary result of this skill and is what it is for
(ADR-0101, ADR-0107): no oracle here can contradict a reading, and four of
these six defects are readings.

**Two things about the harness failed first and are worth more than one
finding.** A `-p` reader has nobody to approve a permission prompt, so the
first launch returned two reports opening with "no probe could be compiled or
run", every verdict resting on the stripped source — exactly the evidence
step 3 forbids. And a subscription session limit refused four of six readers
in one line of output that reads like a report, so a word count is now the
first thing to check. Both are fixed in the skill (`fb24139`).

## Decision

### Three defects in the compiler, each with a case and a mutation

**A `take` under a `with` bound to what the taken variable owns.**
AP 6.4.14.7 names three release points and the compiler asked all three of
what a statement *releases*. A move releases nothing: `with o^ do s := take(o)`
leaves the binding naming storage that now dies under `s`, and `dispose(s)`
outside printed 42 through the binding and exited 0. Asked now in `CheckTake`,
which is the only place that sees `take`'s argument in both of its positions —
an assignment's right side and a spawn's actual. `owned_borrow_errors` is the
case; the mutation is the arm's own condition.

**A schematic formal on a task emitted invalid IR.** `task T(x: string)`, a
conformant array parameter and a bare schema-name formal all wrote a
`getelementptr` through an undefined `%frame`, so what a programmer saw was
LLVM complaining about a file nobody wrote — ADR-0144's shape in a new place.
Refused now, because the lowering has nowhere to go: what a schematic formal
brings is an address and a tuple, and a task's entry has no caller's frame to
read the tuple from. `concurrency_errors` is the case.

**A value parameter of an undiscriminated schema whose body holds an owned
pointer.** `q(x: Sch(3))` was refused and `q(x: Sch)` was not, the type on
that path being produced where the formal is declared and never reaching the
check the discriminated form takes. Worse than an acceptance: a whole-variable
copy of an affine field copies nothing, so the callee read nil where the
caller held a value and the program stopped at a dereference in a routine that
had done nothing wrong. `owned_schema_errors` carries the pair.

### Three sentences of the specification that disagreed with their own clause

AP 6.4.16 said a channel was the only thing two activations may both name;
AP 6.7.8.2 NOTE 3 already recorded that its rule is not transitive. AP 6.4.12.2
said there are exactly three forms of assignment to a handle and named an
external-declaration in the first, which a strict reading makes refuse every
factory AP 6.4.12.6 requires. And AP 6.4.12.6 carried two paragraphs belonging
to AP 6.4.12.5, one of them numbered NOTE 4 a second time.

## Consequences

**AP 6.4.14.7 NOTE 6's "the two together leave no residue" was false and is
now known to be.** A reader found five shapes where a borrow or a with-binding
survives a release reached through a second name — a with-body calling a
helper that disposes the owner, an owner reached under two names, a function
actual in the same call that releases it — and every one compiles, runs and
writes to freed storage. The `take` fix closes one of the five. The other four
are the class ADR-0319 costed and declined, and they are a row in
`doc/sop.md` §7 rather than a claim withdrawn: what changes is that the NOTE
no longer says there is nothing there.

**AddressSanitizer does not see compiled Pascal at all.** The emitted IR
carries no `sanitize_address` attribute, and clang's pass instruments only
functions that do, so a plain use-after-free written by a Pascal program runs
clean under a fully ASan-linked binary. `sanitizers` is honestly described —
it asks whether the runtime's own C survives the suite — but every argument of
the form "ASan reports nothing" made about a *program's* behaviour is empty,
and `doc/sop.md` §7 makes one. Adding the attribute is one line in the emitter
and was measured to work: with it, the same program reports the use-after-free
with a stack trace. It is not taken here, being a change to what every
compilation emits and one that would redden the gate over whatever the corpus
turns out to contain.

**A task can still reach a global through a procedure declared outside it**,
which is AP 6.7.8.2 NOTE 3 and was already known. What the audit adds is the
measurement: four tasks incrementing a global through such a call, two million
times each, print about 2.3 million of eight million at `-O0`, exit 0, and
ThreadSanitizer reports nothing, its instrumentation being subject to the same
attribute.

## What this does not do

**It does not fix the four remaining borrow residues.** Each needs the
whole-program mechanism ADR-0319 costed, and choosing one is a decision and
not a task.

**It does not decide the two questions the readers left unsettled**: whether
AP 6.4.14.7 a)'s "entire-variable" means the same variable or any variable so
bound, and whether AP 6.4.17.2's ban on a task-valued function survives
AP 6.4.12.6's factory, which the compiler admits. Both are in `doc/sop.md` §7.

**It does not promote AP 6.4.4.3's NOTEs to normative text.** A reader argued
that ISO clause 4 makes a NOTE informative, so the sentence documenting that
this processor stores nil on `dispose` and does not detect a second pointer's
use cannot be the accompanying-document statement ISO 5.1 g) 2) requires.
`doc/implementation-defined.md` is that document and carries the entry; the
clause pointing at it rather than restating it is the shape the rest of this
specification uses.

## Alternatives rejected

**Lower a schematic formal for a task by copying the tuple with the value.**
It is buildable and it is a feature, not a fix: what crosses would then be a
new size chosen at the spawn, and AP 6.7.8.1's sentence is about what a value
*is*. Refusing costs a program nothing it cannot write with a fixed capacity.

**Refuse `take` of any variable under any open `with`.** Simpler and wrong in
the direction that matters: `with s^ do` after `s := take(o)` is exactly the
shape a program uses to move something and then work on it, and refusing that
would make the move useless.
