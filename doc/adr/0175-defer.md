# 175. `defer`: a statement armed where it is written

Date: 2026-08-23

## Status

Accepted. AP 6.9.3.11.

## Context

`doc/roadmap.md`'s borrowings table has carried `defer` as **open and cheap**
since ADR-0109: "a block already has one exit and the epilogue already closes
files; `defer` generalises a mechanism that exists". ADR-0151 then made the
lifetime half of the memory-safety model explicit — an owned value is released
when the variable holding it dies — and ADR-0174 gave a foreign address the
same treatment. What is left over is everything the language does **not** own:
a heap variable, a vector the library allocated, a descriptor `PasIO` opened, a
file the program bound and wants unbound, a temporary it wants removed.

For each of those the program writes the release at every place control can
leave the block, or it leaks. There are three such places — the end, a `goto`
out, and `halt` — and the last two are exactly the ones a program forgets,
because they are somewhere else in the text.

## Decision

**`defer S` arms S. An armed statement runs when the statement-sequence it was
armed in is completed, or when the activation terminates, whichever comes
first.**

- **The spelling reserves nothing** (ADR-0140), and the test is asked of the
  token *after* the identifier. A statement beginning with an identifier can
  continue only as a designator (`:=`, `[`, `.`, `^`), as a call (`(`), or not
  at all — a terminator, which §6.9.2.1's empty statement makes `;`, `end`,
  `else`, `until` and `otherwise`. Anything else is a token no conforming
  program could have written there. So `defer;`, `defer(x)`, `defer := 3` and
  `if c then defer else s` all stay what a program that declared `defer` meant
  by them; `tests/dialect/inherits_extended.pas` declares the procedure and
  calls it in each of those positions.

- **The sequence, not the activation** — which is Zig's rule rather than Go's,
  and the reason is a loop. `for … do begin new(p); defer dispose(p) end` is
  the case that decides it: a defer belonging to the *activation* would run
  once, with the last `p`, and leak the rest. A compound-statement is a
  statement-sequence, so the body of a loop written the way loops are written
  is completed once per iteration and what that iteration armed runs there.
  §6.9.3's three sequence-holders — a compound, a repeat-body, and 6.9.3.5's
  completer — are the three places `EndSequence` is called from, and a branch
  of an `if` or the body of a `while` is a *statement*, so a defer written
  directly in one belongs to the sequence outside it.

- **Storage is a flag apiece, not a stack**, and that is what keeps the loop
  case free. A defer-statement can be pending at most once — its sequence
  cannot be re-entered without being left — so what "armed" needs is one bit,
  and arming what is already armed has no further effect. That last sentence
  is not tidiness either: `1: defer S; goto 1` is the one way a defer-statement
  is reached twice without its sequence completing, and a stack would grow
  without bound there.

- **The order is the reverse of the order they are written.** Where the
  sequence is entered once — every program without a backward `goto` over a
  defer-statement — that is the reverse of the order they were armed in, which
  is what every language with this feature promises. Stating it textually is
  what lets the flags be flags.

- **A `goto` past the block and `halt` reach the armed statements through a
  runner.** The compiler emits one function per block that defers, taking the
  block's own frame, and `pas_defer_init` puts it on a runtime list beside the
  files' and the handles' — with a mark in `struct pas_jump` beside theirs, so
  the two walks that already existed gained a third. The runner takes the frame
  rather than allocating one, which is what makes a name inside a deferred
  statement mean there what it meant where it was written: `FrameAt` of the
  block's level is that parameter, and of any enclosing level walks the static
  chain from it exactly as the block's own code does.

- **Defers run before files, handles and the function result.** All three
  walks put them first, because a deferred statement may still write to a file
  the block owns — `tests/dialect/defer.pas` reads that file back — and because
  a function's value is taken from its result variable after the block's
  epilogue, so a deferred statement may still adjust it.

- **A deferred statement contains no label, no goto and no defer.** The first
  two are what the two emissions cost: the statement is emitted where its
  sequence completes *and* inside the runner, so a label in one would be two
  labels with one number and a goto in one would leave a function that is not
  running. They are stated in 6.9.3.11.3 as requirements rather than left to be
  discovered, which is the difference between a restriction and a defect.

## Consequences

- **Nothing changes for a program that does not defer.** The frame grows two
  fields only where `deferCount > 0`, no call is emitted, and the two
  `declare` lines are the whole of the difference in a module's text. The
  compiler itself defers nowhere, so `seed/pascalc.ll` is unaffected and no
  reseed is needed.
- **What it unlocks.** `dispose`, `SVecFree`, `MapFree`, `PasIO.Close`,
  `unbind`, and removing a temporary — the releases the language does not own,
  written beside the thing they undo and correct across all three exits.
- **What it does not do.** It does not give a deferred statement a value, an
  outcome or anything to report to; there are no exceptions here for it to
  interact with. It does not run on a *trap* — an error detected under Annex A
  terminates the program without terminating an activation, and the deferred
  statements do not run, which Annex C now records. It does not arm during a
  run: a defer inside a deferred statement is refused rather than answered,
  because the ordering question has more than one defensible answer and no
  program here needs it yet. And it does not evaluate anything at the moment of
  arming — Go's `defer f(p)` captures `p`, and this executes a *statement*,
  which reads its operands when it runs. `tests/dialect/defer.pas` pins that
  difference with a variable changed after the arming.
- **`nodeKind` grew by one** and `kind-exhaustive` named all fifteen partial
  cases over it; `--dump-ast` prints a defer-statement and `--dump-sema` adds
  the flag it was given. `tests/checks/target_layout.pas` gained a frame with
  three armed statements, so the record and the flag array are compared for
  offsets on both admitted targets — an odd number of flags on purpose.
- **An eighth row in Annex B**, and `src/` needs nothing: both conformance
  modes stop at the token after the identifier, which is machinery that
  predates the dialect.

## Mutation

Four, each a different line of the design. The disarm removed before the
statement runs: `defer` prints *armed second* twice, the sequence and the
runner both firing. The registration removed: `defer_halt` loses all three of
its lines and `defer` segfaults, an unregistered record being read at the
epilogue. The runtime's jump walk removed: `defer` loses *inner armed* and
*jumper armed*, and the stale records left on the list corrupt a later frame.
`EndSequence` removed from the compound: `defer` loses *end of iteration 1*
and *2* — the loop case this design was chosen for, and the one a per-
activation defer would fail. A fifth, over the module path, fails differently
and is worth the sentence: with `EmitDeferRunner` not called for a module, the
compiler builds and emits IR naming a function it never defined, so
`defer_module` fails at the assembler with *use of undefined value
'@p1.defer'* rather than at run time.
