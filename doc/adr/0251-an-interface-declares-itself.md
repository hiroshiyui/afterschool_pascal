# 251. An interface declares itself, and a module declares twice

Date: 2026-08-30

## Status

Accepted, 2026-08-30.

It closes the one thing
[ADR-0250](0250-a-declaration-is-an-occurrence-of-itself.md) left, and with it
everything on the list
[ADR-0246](0246-what-a-name-denotes-and-where-it-was-written.md) opened.

## Context

ADR-0250 reports a defining occurrence by walking the **scope**: every name a
block declares is on the chain at that block's depth. Two things a source
declares are not on it.

**An interface is not in a scope.** §6.11.1 registers one in a table of its
own — `FindInterface` walks a list comparing the string pool (ADR-0248) —
because §6.2.2.2 makes an interface not a scope, and the table lives beside
the scope stack rather than in it (ADR-0079). So `export exporting = (…)` had
nothing over it, while an `import` naming that interface answered.

**And a module declares in two places.** §6.11.1 puts declarations in the
module-heading and §6.2.2.12 makes every defining-point of the heading one of
the block's as well — so the scope is *kept* between them rather than rebuilt,
which is what lets the two be separately translated §6.13 components at all.
A walk to the bottom of the chain after the block would therefore report the
heading's names a second time.

Neither was visible from the corpus, and that is its own finding: **no dump
case compiled a module.** Every `--dump-uses` case was a program, so the
interface line, the module's own declarations and ADR-0250's heading-to-block
navigation — the one place that record's answer is more than a no-op — were
all covered by a language-server session and by nothing in `tests/dumps/`.

## Decision

**`NoteExportedInterface` is a third reporter**, beside ADR-0247's field: the
export-part's identifier written as an occurrence of itself, with `interface`
for the kind. It asks `ifaceRec`'s own `declFile` for the reason ADR-0250's
asks the symbol's — a defining occurrence is *at* the defining-point, so the
question is which file that is and not which file Sema is reading.

**The walk takes a boundary.** `NoteDeclarationsTo(stop)` walks the chain
until it reaches `stop`; the module-heading passes `nil` and the module-block
passes the scope top the heading left, which `modRec` already records as
`savedTop` so that a separately translated block can restore it. So each name
is reported once, by whichever of the two declared it.

**And the heading reports after its procedures, not after its declarations.**
A module-heading declares its routines in a loop of its own, after
`CheckDeclarations` — so a walk taken where an ordinary block takes one finds
every constant, type and variable and none of the procedures. That is the sort
of thing only a case can find, which is why one exists now.

**`tests/dumps/uses_export.pas` is a §6.13 component and not a program**, the
first in that corpus. It carries the interface line, the module's own
declarations, the export list's applied occurrences, and the completion of a
heading resolving back to it.

## Consequences

**Three reporters and one walk cover every occurrence this language has.**
`NoteUse` for a symbol, `NoteUseField` for §6.4.3.3's field, and this for
§6.11.1's interface; `NoteDeclarationsTo` for the defining occurrences of a
block. Nothing on ADR-0246's list is left.

**The corpus gained the shape it was missing.** A module-only dump case also
exercises the heading-to-block navigation, which no program can produce — a
program has no heading to complete. §6.6.1's `forward` is the same shape and
*is* reachable in a program; a module is where it is unavoidable.

**`savedTop` is now read by something other than the scope restore.** It was
written for §6.13's sake — a block arriving in a later translation needs the
heading's scope back — and it happens to be exactly the boundary this walk
wants. If the module scope is ever rebuilt rather than restored, this reads a
stale pointer and reports the heading twice; it is a duplicate and not a wrong
answer, which is why it is worth the coupling.

## Alternatives rejected

**Reporting the heading's names from the block and not at all from the
heading.** One call site instead of two, and the block's scope contains both
sets. It fails for a heading translated without its block, which is §6.13's
whole point and the case `selfhost/compiler.components` is built on.

**Letting the heading's names be reported twice.** Harmless — the two lines
would be identical, and the schema case already carries duplicates for a
reason that could not be removed (ADR-0249). It was rejected because here the
boundary was already recorded and cost one parameter, where the schema's
duplication would have cost storage proportional to the file.
