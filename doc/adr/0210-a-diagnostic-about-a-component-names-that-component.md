# 210. A diagnostic about a component names that component

Date: 2026-08-26

## Status

Accepted.

## Context

This was found by a probe while designing generic routines, and it is older
than that work by every increment since ADR-0079.

`--import` reads an already-translated program-component for the interfaces its
module-headings export (§6.13). It does that by **re-parsing the component's
full source**, and `CheckModuleBlock` has no `mdElsewhere` guard — so the
component's block is not merely parsed in the client, it is fully checked
there. Only *emission* is suppressed.

`curFile` is a single global that `ErrorAt` writes. The import loop sets it to
the component's name while reading, and puts it back before returning, because
what is compiled after that is the client. By the time `RunSema` walks the
module the client imported, `curFile` is the client's — and every diagnostic
about the component's block carries the client's name with the component's line
and column:

    $ pascalc --std=extended --import badmod.pas client.pas
    client.pas:15:3: error: cannot assign packed array [1..14] of char ...

`client.pas` is three lines long. It is not merely the wrong file; it is a
position the named file does not have, and an editor asked to go there cannot.

**Why no oracle here saw it.** `tests/run_test.sh` translates every
`name.components` entry **separately, and first**, and gives up if one of them
fails — which is right, and which means no case in the corpus can reach the
state that shows this: a component that does not translate on its own, handed
to `--import` anyway. Every module under `lib/` is correct, every `--import`
case is a success path, and so the whole corpus agrees. The one golden that
names a component — `tests/extended/import_program.err` — is reported by the
import loop itself, while `curFile` is still the component's, which is why that
path worked and this one did not.

The harness knew. `run_test.sh`'s `normalise` rewrites the case's own directory
out of a golden, and its comment says *an `--import` reports a heading's errors
against the file that wrote it*. That sentence was true of the loop's own
messages and false of everything Sema reports, and nothing compared the two.

## Decision

**A module node records which source it was parsed from, and `CheckModule`
reports against that source.**

`nkModule` gains `mdFileIdx`: 0 for the source named on the command line, *k*
for the *k*'th `--import`. It is set at parse time from a global the import
loop maintains, because that is the only moment the answer is known.
`CheckModule` saves `curFile`, sets it from the node, and puts it back.

**At `CheckModule` and not at each message.** Three messages of its own, and
everything `CheckModuleHeading` and `CheckModuleBlock` report beneath it, are
about text in the component — so the question is asked once, at the top of the
subtree that is entirely about one file, rather than at each of the several
places that write one. A message added later inside that subtree inherits the
answer instead of having to remember it.

**An index and not a name.** A `nameStr` in the node variant would put a
`string(strMax)` in every node of every kind that shares the record. The import
names are already an array with a stable index, so the node carries an integer
into it.

## Consequences

`tests/checks/importdiag/` holds the two sources, beside `stdannot/` and for
the same reason spelled one degree sharper: `stdannot`'s probes cannot be
reached because every harness passes `--std=` explicitly, and these cannot be
reached because the harness compiles components first *by design*. The probe is
in `selfhost/producttest.sh`, which tests the built `pascalc`.

**It fails in both directions**, which is what stops the obvious wrong fix. A
change that named the component for everything would pass the first half; the
second half compiles a client with an error of its own and requires the
client's name.

`0211-import-diagnostic-names-the-client.mut` puts the defect back. It is
killed by `pascalc-product` and **by nothing else**: with the mutation applied,
every case under `tests/` passes, which is the measurement this record rests
on rather than an argument about it.

**What it does not do.** A node still carries `line, col` and no file, so this
is a fact about *modules* and not a general answer. Nothing else here is parsed
from a second file — the import loop refuses a component that declares a
program — so the two are the same set today. A future feature that checks a
tree parsed from one file while compiling another inherits the original defect
and not the fix; the case in front of us is a generic routine instantiated in a
client, which is why this was written first and separately.
