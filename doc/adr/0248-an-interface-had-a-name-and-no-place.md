# 248. An interface had a name and no place

Date: 2026-08-30

## Status

Accepted, 2026-08-30.

It closes the second of the three rows
[ADR-0246](0246-what-a-name-denotes-and-where-it-was-written.md) added to
`doc/sop.md` §7, after
[ADR-0247](0247-a-field-is-not-a-symbol.md) closed the first. The third — a
name inside a schema's own body — stands, and is a different shape from
either.

## Context

`--dump-uses` (ADR-0246) reports two spans for §6.11.3's qualified name `M.x`:
the interface for its own length, and the whole of `M.x`. The second answered;
the first hovered and jumped nowhere, because `ifaceRec` held a name, an owner
and a list of constituents, and never where the `export` clause was written.

The reason is the same one behind ADR-0247's field, arrived at from a
different direction. An interface is found by **spelling**: `FindInterface`
walks a list comparing the string pool, and every question the compiler asks
about an interface — has one of this name been exported, does it have a
constituent called `x`, which module owns it — is answered without any
position at all. So nothing had ever recorded one.

**The occurrence that matters is not the qualifier.** `M.x` is uncommon —
§6.11.3's `qualified` is a form most programs never write. The interface name
in an **import-clause** is not: `import Middle;` is where a module says where
it gets things from, and it is the line a reader most wants to follow. That
occurrence was reported by nothing at all, the import path never having gone
near `NoteUse`.

## Decision

**`ifaceRec` records its defining-point** — `line`, `col`, `declFile` — set in
`CheckExports` from the export-part's own node, which is the only place a
source writes one. §6.11.1 makes the export-part's identifier the interface's
defining-point, so there is exactly one site. The two required interfaces —
`StandardInput` and `StandardOutput`, built by the compiler and written in no
source — answer 0, which is the same zero a required identifier's symbol
carries and means the same thing.

`declFile` and not `file`, for ADR-0247's reason: §6.1.2 reserves that word.

**The import-clause's interface name is reported**, in `CheckImports`, and the
symbol it makes for the importing block carries the *supplying* module's
position. §6.11.3 gives the import-clause a defining-point in the importing
block, and that is not where a reader wants to be sent — it is where they
already are. An imported constituent already behaves this way: `Answer`
imported from `Base` sends a reader to `Base`, not to the `import` line. The
interface now matches it.

## Consequences

**Two occurrences answer where one did.** The qualifier of `M.x` was the case
the row was written about and the import-clause is the case that is worth
having; both fall out of one position on one record.

**A defining occurrence still answers `null`, and that is now visible.**
`lsp/sessions/definition_across.jsonl` asks for the definition of the
export-part identifier itself — the line that declares the interface — and
gets nothing, because this dump reports *applied* occurrences and a
declaration is not one. That is uniform: a position on a `var` line, a
procedure heading or a type definition answers the same way. Editors usually
answer a declaration with itself, and what it would take here is the compiler
reporting every defining-point as an occurrence of itself — a change to what a
`use` line means rather than a fix to this one, and it would add a line per
declaration to a dump already a line per name. Registered in `doc/sop.md` §7
rather than done.

**The export list was already answered and nobody had noticed.** Compiling a
module alone shows `use` lines for every name in its `export` clause —
`kept`, `Keep`, `mark`, `marker` each resolving to their declarations further
down the file. That came free: `AddExportItem` resolves through the same
lookup every other applied occurrence does. It is recorded here because it was
found by *reading the dump* rather than by writing a test, which is how
ADR-0247's finding arrived too.

## Alternatives rejected

**Sending a reader to the module's own name rather than to the export-part.**
`modRec` has `line` and `col` already, so `module Middle;` was reachable
without adding a field. It is the wrong target: §6.11.1 makes the *export
part* the interface, an interface-identifier and a module-identifier are
different names that merely usually agree, and `module counter; export
counting = (…)` is the case in this tree where they do not.

**Recording the position on the interface's symbol instead.** The symbol is
made per import, in the importing block, so it would have had to be filled
from somewhere — and the only somewhere is the interface. Putting it on the
record puts it where the fact is, once, for however many blocks import it.
