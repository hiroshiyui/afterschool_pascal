# 243. A name that stays taken

Date: 2026-08-29

## Status

Accepted, 2026-08-29.

It completes [ADR-0242](0242-a-name-no-other-live-process-will-choose.md),
which closed the first half of `doc/roadmap.md`'s *a program cannot make a
temporary file* and named its own residue: no `mkstemp`, no
`PasFS.TemporaryPath`, and no name unique against a process that has already
exited. This is that residue.

## Context

ADR-0242 gave a program `PasProcess.ProcessId`, and a name built from a process
identifier has exactly one property: no other **live** process will choose it.
That is what the language server needed and it is not what a library should
offer as *the* answer, because the system is free to hand a process identifier
out again. A program that composes a name from one and finds a file already
there cannot tell a leftover from a collision, and if it guesses wrong either
way it destroys somebody's data or refuses to run.

The unique-against-everything answer is to **create the file**. A name whose
file exists goes on being taken after the process that made it has gone, and
the creation has to be exclusive or two processes racing on the same name both
believe they won.

`mkstemp` is the POSIX routine for this and **cannot be bound from Pascal
here**. It takes one `char *` and *modifies* it, and the only mutable storage
this foreign-function interface lends is a slice — which supplies a pointer
**and** a count (ADR-0129), so reaching a one-argument C function through it
would mean passing an argument the callee does not declare and asserting that
the machine does not mind. That is a claim about an ABI, and ADR-0030's whole
line of decisions exists so that this compiler never has to make one.

## Decision

**`PasFS.TemporaryPath(dir, prefix)` answers a path in `dir` that names nothing
else, with the file created empty.** Nothing removes it; it is the caller's,
and `Remove` is how it goes away.

**The mechanism is ISO C and `mkstemp` is not in it.** C11 7.21.5.3 gives
`fopen` the exclusive mode: with `x` it *"fails if the file exists or cannot be
created"*. So `pasx_temp_name` composes a name from a counter, tries to create
it and nobody else's, and goes round again on the one that lost — 4 096 times
before it gives up. The counter is seeded from `time`, which is ISO C too.

That is the decision worth arguing for, because the obvious route was to
catalogue `mkstemp` in `tests/checks/nonstandard_c.txt` and be done. The
catalogue is the measurement of *what a port to another C library costs*
(ADR-0161), it has stood at five names since `access` joined it, and `mkstemp`
would have brought `close` with it — **seven**. The ISO route costs nothing at
all, and the property is the same one: the exclusive create is what `mkstemp`
does underneath.

**A process id is deliberately not the seed.** `getpid` is POSIX, this routine
is not, and what a pid buys — fewer collisions on the first try — the retry
already covers. The two records answer different questions and it is worth
being plain about which: ADR-0242's `ProcessId` gives a **predictable** name,
which is what the language server wants because it should leave one file behind
however many times it runs; this gives a **unique** one, which is what a
program wants when it will remove what it made.

**The language server keeps its pid name for that reason.** It is not a caller
of this routine and the roadmap says so. A server started a thousand times
should leave one file in `TMPDIR` and not a thousand, and the name being
predictable is what makes the scratch source findable when the server and the
editor disagree about a document.

## Consequences

`tests/dialect/lib_fs.pas` pins every property of the answer that is not its
spelling — eight hexadecimal digits from a clock cannot be written in a golden.
The directory asked for is the directory it is in, the prefix is at the front,
the length is the prefix plus eight, **the file exists**, a second call answers
a different name, `Remove` takes it away, and a directory that is not there is
`errIO`.

**Two mutations, and the second is the interesting one.** Returning the name
without creating the file leaves `temp exists = FALSE`, `temp removed = the
operation was refused`, and a trap on the last line where a successful result's
`cause` is read — three failures for one mutation, the last of them ADR-0118's
variant guard. Then *stopping the counter* fails the second call outright:
every one of its 4 096 tries finds the file the first call created. That is a
demonstration inside one process that C11's exclusive mode is exclusive, which
is the property the whole routine rests on and the one a single-process test
looked least able to reach.

**What no test here stages is two processes.** The retry loop matters when two
programs seeded in the same second walk the same names, and nothing in this
tree runs two programs at once and compares what they got. The mutation above
is the argument that the mechanism is sound; the concurrency is not staged, and
`doc/sop.md` §7 records it.

`lib/dialect/pasfs.pas`'s header comment is rewritten rather than extended. It
said `getcwd`, `readlink` and `strerror` "all hand a pointer back and are
absent for that reason" — true when it was written and false since ADR-0132,
which brought two of them back. The claim that survived is the interesting one
and it is now what the paragraph says: a pointer that comes back is the
caller's own buffer coming home, or is read once and copied in the same
statement, and no C pointer becomes a value a module holds.
