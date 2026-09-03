# 300. The edit a warning already knows

Date: 2026-09-03

## Status

Accepted, 2026-09-03. Closes the `codeAction` row of `doc/roadmap.md`'s
Tooling table, and corrects
[ADR-0283](0283-a-var-parameter-nothing-writes-through.md), whose warning
could give advice that does not compile.

## Context

The compiler has four warnings and each of them names a thing a person is
about to edit. `doc/roadmap.md` said so — *the four warnings each know the
edit they want* — and guessed three: add `protected`, delete the declaration,
delete the statement after the one that leaves.

LSP's `textDocument/codeAction` is where an editor asks for such an edit. The
client hands back the diagnostics the server published, over a range, and the
server answers with actions carrying a `WorkspaceEdit`. Nothing about the
protocol is hard. What had to be decided is **which of the four can carry an
automatic edit**, and the answer is not the one the roadmap guessed.

Two facts shaped it.

**An edit that can break a program is worse than no edit.** A quick fix is
applied with one keystroke and read afterwards, if at all. So the bar taken
here is that the edit must be decidable from what the compiler *reported* —
not from reading the source in the server, which is the shape ADR-0229 and
ADR-0230 moved `kind-exhaustive` off and ADR-0294 refused for `rename` — and
must not be able to change what the program does.

**And one of the four warnings was wrong.** ADR-0283 claims *`not
wasThreatened` is precisely the condition under which adding the word still
compiles*. That is true of a parameter and false of a
**formal-parameter-section**: §6.7.3.1 puts `protected` before the whole
section, so `var b, c: integer` takes the word for both names or for neither.

    procedure R(var b, c: integer);
    begin b := 1; writeln(c) end;

The compiler advised `'c' is never written through, so it could be
protected`; adding the word makes `b := 1` a compilation error. No source in
this tree had a section with one name written through and one not, so the
whole corpus agreed with the warning. Finding it took writing the tool that
would have applied the advice.

## Decision

**Two of the four warnings carry a quick fix, and two do not.**

**A statement that cannot be reached (ADR-0277) is deleted.** The compiler has
proved control never arrives there, so removing the text cannot change any
behaviour — which is the strongest form the safety condition takes here. The
extent comes from `--dump-stmts` (ADR-0258), matched by the statement's own
start, which is where the warning stands. The separator before it is left
alone: §6.9.2.1 makes what remains an empty statement and legal, and an edit
that reached backwards over a `;` would have to know what stands before it.

**A `var` parameter nothing writes through (ADR-0283) takes `protected`**,
inserted before its formal-parameter-section — and the compiler change below
is what makes that position available.

**An unused local (ADR-0272) is not offered a deletion**, and the reason is
not that it was harder to compute. A variable-declaration's type-denoter may
carry defining-points of its own: `var c: (red, green)` declares two constants
in the enclosing block (§6.4.2.3), and `var r: record x: integer end` a field.
Deleting the declaration deletes those names too, and the rest of the block
may use them. The roadmap guessed this one and it is the one that cannot be
done.

**A function that does not write its result on every path (ADR-0278) has no
mechanical edit at all.** Where the assignment belongs and what value it takes
is the decision the warning exists to prompt; a fix that wrote
`f := <something>` at the top of the block would silence the warning and keep
the defect.

**The warning is a question about a section, and is reported at one**
(the compiler change). `NoteUnwrittenVarParams` now judges the run of
parameters sharing a `paramSection` and records the section only when *every*
name in it could take the word; `WarnUnwrittenVarParams` reports once per
section, at the section's own first token, naming each parameter — `'a', 'b',
'c' are never written through, so they could be protected`. The symbol gained
`secLine`/`secCol` for the position, stamped where `paramSection` already was.

Three things follow, and each is a reason rather than a consequence. The
advice compiles again, which is ADR-0283's own claim restored. The diagnostic
points at the text the edit changes, which is what a person wants of it
whether or not a tool is reading. And one section is one message: two
diagnostics at one position would be two offers of the same single edit, and
applying both would write the word twice.

**The diagnostics are matched by their text.** A diagnostic here is
`file:line:col: warning: message` and carries no code, and inventing one would
change the format every `.err` and `.warn` golden in the tree holds. So the
server compares the message against the two wordings exactly. That is the one
place in this program that reads the compiler's prose, and what holds it still
is the `.warn` sidecar on every case that warns, in both directions
(ADR-0272), plus the session below.

## Evidence

`tests/dialect/protected_hint.pas` gains `Mixed(var written, read_: integer)`,
which writes through one name and not the other and **must not be warned
about**. Its `.warn` sidecar says nothing of it, and a `.warn` is checked in
both directions, so a warning appearing there fails.

The same file's `Sum3(var a, b, c: integer)` was three messages and is one.
Twenty-four `.warn` goldens across the corpus move by the width of `var `,
which is the position moving from the name to the section; every one of them
was regenerated and read.

`lsp/sessions/code_action.jsonl` is the session, and its golden was written as
a prediction — including the diagnostics the server publishes, which the
session sends back the way a client does — and matched byte for byte on the
first run. It asks for the two fixes, for an action on an ordinary error
(`[]`), and for one with no diagnostics at all (`[]`, and no compilation
started).

**The two edits were applied by hand and the result compiled**: the statement
deleted and `protected ` inserted, and the program then compiles with nothing
at all on either stream.

Three mutations, each killing what it should. Reporting the warning at the
name again fails `protected_hint` on four rows. Judging a section by one of
its names fails it on `Mixed`. And a delete that ends where the statement
begins fails `lsp-server`, the action becoming an offer to change nothing.

## What is not done

- **No fix is offered for the two declined warnings**, and if one is ever
  wanted the unused local is the reachable half: it needs the compiler to
  report the *group*'s extent and which names share it, and a rule for a
  denoter that declares names of its own. Nothing has asked.
- **A code action is offered only for a diagnostic the client hands back.** A
  client that sends an empty `context.diagnostics` gets nothing, which is the
  protocol working as intended and also why the method costs nothing on an
  ordinary cursor move.
- **The `--dump-stmts` taken for a delete is not cached**, unlike the `use`
  rows (ADR-0252). It runs only when an unreachable-statement diagnostic is in
  range, which is rare enough that a cache would be storage for nothing.
- **Nothing checks that a quick fix compiles.** The two here were applied by
  hand once. A gate would have to apply an edit and recompile, which is a
  harness this tree does not have and a row in `doc/sop.md` §7.

## Consequences

- **ADR-0283's zero moved and nothing had to change.** The warning now reports
  fewer sections than it reported parameters, and `warning-free` stayed green,
  because every section this tree's own sources would be advised about is
  already protected in full.
- **A warning's position is now part of its contract with a tool.** Moving one
  moves an edit, which is a thing to know before moving one.
- **The corpus could not see the defect and a client could.** Every case that
  warns is one somebody wrote to exercise the warning, so every group in the
  tree was all-or-nothing. The mixed section is the shape nobody writes
  deliberately and everybody writes eventually, and what found it was building
  the thing that would act on the advice — ADR-0182's lesson, that a feature's
  first real client is its sharpest oracle, met again.
