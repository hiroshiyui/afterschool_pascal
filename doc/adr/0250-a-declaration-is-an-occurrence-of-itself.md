# 250. A declaration is an occurrence of itself

Date: 2026-08-30

## Status

Accepted, 2026-08-30.

It closes the last row on
[ADR-0246](0246-what-a-name-denotes-and-where-it-was-written.md)'s list — a
*defining* occurrence answered nothing — after
[ADR-0247](0247-a-field-is-not-a-symbol.md),
[ADR-0248](0248-an-interface-had-a-name-and-no-place.md) and
[ADR-0249](0249-a-schemas-body-is-read-where-it-was-not-written.md) closed the
three that record opened. Nothing of that list is left.

## Context

`--dump-uses` reports **applied** occurrences, which is what §6.2.2.1 calls a
name used rather than declared. A position on a declaration therefore had no
line over it: standing on `Total` in `var Total: Counter` and asking either
question got nothing back.

Two things made that worth fixing rather than explaining.

**Hover on a declaration is the most ordinary question there is.** A reader
looking straight at `var Total: Counter` wants to know what `Counter` resolves
to, and every editor offers it. Go-to-definition there is a no-op jump and the
hover is the point.

**And Pascal has a declaration/definition split.** §6.6.1's `forward` and
§6.11.1's module-heading both declare a routine whose body arrives later, and
the two are the *same* routine by §6.2.2.12. Navigating from an implementation
back to the interface that promised it is exactly what C's readers use
go-to-definition for, and this language had no way to ask.

## Decision

**A defining occurrence is reported as an occurrence of itself**: the same
position written as both the occurrence and the target, with the kind and the
type the symbol carries.

**It is reported once per block, from the scope**, not at the declaration
sites. Every name a block declares is on the scope chain at that block's
depth, so `NoteBlockDeclarations` walks from `scopeTop` while the depth
matches — one site where the declaration kinds are eight, and nothing to add
when a ninth arrives. It runs after `CheckDeclarations`, which is what makes
the **type** available: at `Declare` a variable has none yet, and reporting
there would have written `?` for every one of them.

A hidden variable is never bound into a scope — a function result, a `with`
binding — so it is never reported, which is right: no programmer wrote it. A
required identifier is declared with no position (§6.2.2.10) and is excluded
by `declLine > 0`.

**The completion of a heading resolves to the heading.** `DeclareProcHeading`
finds an `existing` symbol when a block completes a `forward` or a
module-heading, and `Declare` therefore ran once — at the heading. So the name
written at the implementation is reported as an applied occurrence of that
symbol, and answers the interface. The reverse is not available: a symbol
records one defining-point and it is the heading's.

## Consequences

**It shipped a defect and a session caught it.** The first version guarded on
`NotingHere`, which asks *which file is Sema checking* — right for an applied
occurrence and wrong here. §6.11.3 binds an imported constituent's symbol into
the importing block's scope, so the walk found `Doubled` from `middle.pas` and
reported its defining-point as an occurrence in `client.pas`. The server then
sliced that document at that position and a hover over `Doubled` came back as
**`(Double`** — a name that is not in the file.

It is ADR-0249's mistake met from the other side, and it was caught by
`lsp/sessions/definition_across.jsonl` rather than by reasoning: the golden
moved, and the moved value was visibly wrong. A defining occurrence is at the
defining-point, so the question is the *symbol's* file and not Sema's, and
`declFile = 0` is the guard.

**A declaration is now the one line a caller may see twice for one name.** The
occurrence and the target are the same position, so a tool that renders a
target range gets a range identical to what it asked about — which is what an
editor answers for a declaration anyway.

**An interface is the exception, and stays one.** §6.11.1 registers an
interface in a table beside the scope rather than in it, so the export-part
identifier is not a block declaration and answers nothing.
`lsp/sessions/definition_across.jsonl` asks and pins the `null`; closing it
means a second walk over a second table for one name per module.

**The dump grew by about a line per declaration**, which is the smallest of
the four increments: `--dump-uses` over `selfhost/apfront.pas` is 34 215 lines
before this and the corpus's own goldens moved by 34 lines across three cases.

## Alternatives rejected

**The server falling back to `--dump-symbols`.** `doc/sop.md` §7 named it, and
the server already runs that flag for the outline and already parses its
lines. It was rejected on cost and on completeness: it needs a *second*
compilation, paid on every miss including a hover over whitespace, and
`--dump-symbols` deliberately skips headings and `forward`s (ADR-0239, so a
name is not outlined twice) — which is precisely the case that is not a
no-op. The route that answers the interesting half is the compiler's.

**Reporting at each declaration site.** Eight sites, one line each, and each
with the type already set. It is the pattern `NoteUse` already uses, and it
was rejected because a ninth declaration kind would join the language and
report nothing, silently — the failure `kind-exhaustive` exists to make loud
and cannot see in hand-written calls. The scope walk cannot miss a kind: a
declaration that is not in a scope is not a declaration a name can resolve to.

**Reporting from `Declare`.** One site, and the earliest. It writes `?` for
every variable's type, because `Declare` runs before the caller sets `stype` —
so the hover that is the whole point of this record would have shown a
question mark.
