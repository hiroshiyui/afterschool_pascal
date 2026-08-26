# 212. An imported component's tokens are kept

Date: 2026-08-26

## Status

Accepted.

## Context

ADR-0211 made a generic routine's body **re-parsed** rather than copied: the
declaration records the token its block starts at, and each instantiation sets
`pos` back to it and parses again. That was chosen over a copy walker because
re-parsing cannot disagree with parsing, where a walker over sixty-odd node
kinds can name every one of them and still copy a single field wrongly with
`kind-exhaustive` satisfied.

It rested on the token array outliving the parse, and for the source named on
the command line it does. For a component read by `--import` it did not:

    tokCount := 0;
    pos := 1;

at the end of each iteration of the import loop, so each component's tokens
were overwritten by the next one and finally by the program.

**The failure that would have caused is worse than an error.** A saved position
is an index into an array that still exists and now holds *a different
source*. Nothing is nil, nothing is out of range, and no check could have
fired: the body of some unrelated routine would have been parsed in the
generic's scope and translated. ADR-0211 registered it in `doc/sop.md` §7 for
exactly that reason, and observed that no corpus case could reach it, because
no module declared a generic — and none could until this was closed. That
circularity is why the row had to be written rather than left to a test.

It also meant the library could not use the feature at all. `PasVector`,
`PasStrVec`, `PasList` and `PasMap` are the caller ADR-0116's rule wants for
generics, and every one of them is a module.

## Decision

**The token array is not cleared between components.** Each `--import`'s tokens
are appended after the previous one's, the source named on the command line
follows them, and `mainTokBase` records where it begins.

**What that costs is what a fixed buffer means.** ADR-0012's arrays are sized
for this compiler's own source; this one now holds *every source in a
translation* rather than one. The measurement, rather than an estimate:
`selfhost/compiler.pas` uses 167 921 tokens of 300 000 and imports nothing, so
`buffer-headroom` — which reads the compiler's own compile — does not move at
all; a client importing three library modules reaches 1 969 in total. A module
is about 1 250 tokens. The bound that would bite is a program importing more
than a hundred of them, which is a different program from any that exists.

**The dump still means this source.** `--dump-tokens` walks from `mainTokBase`,
because what a token dump has always shown is the source being compiled, and
`difftest` and `tests/dumps/` compare it.

## Consequences

**An instantiation is emitted by the translation that demanded it.** This is
the half that was not obvious. §6.13 has a translation emit nothing of a
module it imported — but an instantiation for a type *this* program named
cannot exist in that module's object file, which was translated without ever
hearing of the type. So instantiations are kept on a list of the translation's
own and emitted from there, their frame types are named beside every other
one, and a call to one is exempt from the `compiledElsewhere` rule that would
otherwise declare it external and define it in the same module.

**A generic's body position is recorded by whichever declaration carries the
body.** 6.11.1 splits a module routine into a heading in the interface and an
identification in the block; the heading has the parameters and no body, so
`RecordGenericBody` is called from the completion — one routine rather than two
copies of six assignments, because the two callers must agree about every one
or a body is read in the wrong scope.

**The type arguments are resolved once, in the caller's region.** They were
resolved twice, and the second time ran after the generic's scope had been
restored — where a type the *client* declared does not exist. A client calling
an imported generic with a record of its own got a frame slot of no type,
which LLVM refuses as `void` in a struct. The resolved type is now kept on the
argument node, which is about to be unlinked from the argument list anyway.

**What is still not done.** A generic instantiated by two different
translations is translated into both, so the same routine can appear in two
object files. Nothing links them, and nothing here notices: the linkage name is
this translation's own counter, so the two do not collide and the cost is
duplication rather than an error. It is what C++ needs `inline` linkage and a
COMDAT for, and the reason it can wait is that duplication is not a wrong
answer. `doc/sop.md` §7 carries it.
