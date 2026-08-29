# 240. A program may ask before it writes

Date: 2026-08-29

## Status

Accepted, 2026-08-29.

It supersedes nothing. It answers the half of
[`doc/roadmap.md`](../roadmap.md)'s language-server finding — *a program cannot
make a temporary file, and cannot survive failing to* — that the finding itself
called "a language question and the sharper of the two". The other half, a
temporary *name*, is a library gap and is not answered here.

## Context

ISO/IEC 10206:1991 gives a program one question about an external entity and it
is the wrong one for half the openings a program makes.

§6.7.5.6's NOTE 2 offers `binding(f).bound` as the way "to test the success of
binding a variable to an external entity", and
[`doc/implementation-defined.md`](../implementation-defined.md) E.16 makes it
mean *the entity exists*. That serves a program about to **read**: it may ask
whether there is anything to read, and `tests/extended/bind_missing.pas` is the
program that does. A program about to **write** wants the opposite question —
*could an entity be created or opened here?* — and `bound` answers it backwards
in both directions. A file about to be created reports false; a file that
exists and cannot be written reports true.

There was no other way to ask. §6.7.5.2 defines `rewrite` and `extend` by
post-assertions and says those "imply corresponding activities on the external
entities, if any, to which the file-variables are bound", leaving the
activities implementation-defined (E.15). What this processor does when the
entity cannot be created is **terminate the program**:

    runtime error: cannot open for writing: /no/such/directory/f.txt

So the failure is not recoverable, not reportable, and not foreseeable. That is
conforming and it is a bad place for a program to be.

**Six sites said so, which is what made it a demand rather than an idea**
(ADR-0116). `lib/pasfile.pas` exports four writers — `WriteAllText`,
`WriteLine`, `AppendLine`, `AppendText` — and every one of them was a
`procedure`: a routine that could not report failure and could fail, killing
its caller. `CopyFile` was worse, because it *returns a boolean* and that
boolean covered only the source; a destination that could not be written
stopped the program from inside a routine whose signature said it would tell
you. And `lsp/pasls.pas` could be killed by a bad `PASLS_SCRATCH` however
carefully it was written, which is what put the finding on the roadmap.

Three ways to answer it.

**A library probe.** `PasFS` could export `CanCreate(path)` over `access`. It
needs no language change and `access` is already catalogued (ADR-0172). It is
also a guess that reads like a guarantee, it leaves the six sites free to trap
anyway, and it puts a question about *a file variable* in a module that does
not know about file variables.

**A fallible open.** The dialect has AP 6.4.13's `T ! E` and `try`, so an open
that yields a result rather than stopping is expressible. It is also a new
statement or a new factor, and ADR-0140 asks first whether a feature needs a
spelling at all. This one does not.

**A third field of `BindingType`.** §6.4.3.4's own NOTE 7: *"A processor may
provide additional fields as an extension."* The standard put the door there.

## Decision

**`BindingType` has a third field, `writable`, of type `Boolean`.** Where the
file-variable is bound to an external entity, it is true if and only if the
entity could be opened for writing when `binding` was applied; where it is
bound to nothing it is false, as `bound` is. AP 6.4.3.4.7 is the clause; §5 of
`doc/implementation-defined.md` is the extension statement clause 5.1 g)
requires.

**It has no spelling, and that is the point.** ADR-0184 admitted a record at an
`external` heading and spelled nothing, and observed that ADR-0140's "a feature
with no position has found the real limit" assumes every feature needs a
position. This is the second time none has, and it is the first where the
*standard* named the extension point: `binding` is a required function that
already returns a record, so the feature arrives at a position every conforming
program already writes, and a program that does not read the field cannot tell
it is there.

**It is a probe and not a promise**, and the specification says so in a NOTE.
It is exactly as strong as `bound`: an entity that exists when `binding` is
applied may be gone at `reset`, and one that could be opened for writing may
not be at `rewrite`. A full disc, a descriptor table that has run out and a
name replaced between two statements are all outside it. What it covers is
every failure the *path* can be blamed for — a directory that is not there, a
name below a file, a directory where a file was meant, no permission — which is
the whole of what a program pointed at a bad path meets.

`pas_can_write` is where that is decided, and it is two questions because a
name that exists and a name that does not are two questions. An entity that is
there is asked whether it admits a write; a name that nothing is at moves the
question to the directory that would hold it. Both branches then rule out a
**directory**, which passes `access(W_OK)` — that is permission to create
entries *in* it — and stops the program at `fopen`. That is asked without
`struct stat`, which this translation unit cannot have (ADR-0186's catalogue
holds a function and never a type): POSIX requires a pathname with a trailing
slash to resolve to a directory, so appending one and asking `access` again is
the same question by a route the catalogue already admits. No new foreign name
and no new header.

## Consequences

**The four writers of `lib/pasfile.pas` are functions**, and `CopyFile`'s
boolean now covers what it looked as though it covered. That is an API change
to a library this project owns, with eight call sites in two test programs, and
it is the change the field was for: a routine that can fail and cannot say so
is the defect, not the trap.

**They became one routine with two flags, and the reason is a second finding.**
A **bindable file cannot cross a parameter.** §6.4.1 makes `bindable` part of a
*variable-declaration* and not of a type-denoter, so no formal parameter
accepts one — `var f: text` compiles and `bind(f, b)` inside is then refused,
*"only a variable whose type-denoter says 'bindable' can be bound to something
outside the program"*. The obvious shape, a helper taking the file and the
path, is unwritable, so the helper takes the whole job instead. It is recorded
on the roadmap rather than answered: making `bindable` expressible at a
parameter needs its own decision about what a callee may do to a caller's
binding, and nothing has asked for it twice.

**The server survives a bad scratch path.** `lsp/sessions/unwritable.jsonl`
replays a session whose `PASLS_SCRATCH` names a directory no machine has: the
server says once per document what is wrong and where to fix it, publishes
nothing it cannot stand behind, answers `documentSymbol` with an empty outline
rather than a stopped process, and shuts down cleanly. `lsp/run.sh` gained a
`name.scratch` sidecar for it, which exists precisely so a session can name a
path no work directory would be.

**What is not answered** is the finding's other half: there is still no
`getpid`, no `mkstemp` and nothing in `PasFS` that answers a temporary *name*,
so two servers sharing a `TMPDIR` still share one scratch file. That is a
library gap with an obvious shape and it stays open.

**A `readable` field was considered and not added.** The read side already has
`bound`, which catches the case that actually happens — the file is not there.
A file that exists and cannot be read is a permissions accident, and no caller
has asked twice. It would be added the same way if one did.

**Evidence.** `tests/dialect/binding_writable.pas` pins the six answers
including the two false positives a naive probe gives — a directory, and a name
below a file — and writes at every name it was told it could, so a wrong
positive stops the program. `tests/spec/features/dialect_binding_writable.feature`
is the clause-shaped half, and its last two scenarios are the argument in
miniature: the same program with the guard exits successfully and without it
stops at run time. `tests/extended/lib_file.pas` refuses at five entry points
and shows the source still intact after a refused copy.
`lsp/sessions/unwritable.out` is the protocol half. Making `pas_can_write`
always answer yes fails all three suites.
