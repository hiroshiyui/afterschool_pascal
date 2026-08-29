# 242. A name no other live process will choose

Date: 2026-08-29

## Status

Accepted, 2026-08-29.

It supersedes nothing. It answers the other half of
[`doc/roadmap.md`](../roadmap.md)'s language-server finding — *a program cannot
make a temporary file, and cannot survive failing to* — the half that finding
called "a library gap with an obvious shape". [ADR-0240](0240-a-program-may-ask-before-it-writes.md)
answered the first half, which was a language question; this one is not, and
`doc/afterschool-pascal-spec.md` is untouched by it.

## Context

`lsp/pasls.pas` writes the document an editor is holding to a scratch file,
because the compiler reads a file and an editor holds a buffer that was never
saved. The path was `$TMPDIR/pasls-scratch.pas` — one fixed name, overridable
with `PASLS_SCRATCH` — and the header comment said why in as many words: *there
is no `getpid` anywhere in this tree, no `mkstemp`, and nothing in `PasFS` that
answers a temporary name, so a program wanting a name no other process will
choose cannot make one.*

Two servers sharing a `TMPDIR` therefore shared the file. That is not exotic:
an editor with two workspaces open starts two servers, and an agent running one
transport while a person runs the other is exactly what
[ADR-0241](0241-a-second-transport-over-one-program.md) made ordinary. Each
would write the other's document into the file the other was about to compile,
and the diagnostics that came back would be about a source neither client had.

The workaround shipped with the server — *point `PASLS_SCRATCH` somewhere of
your own if you run more than one* — is a correct instruction that nobody
reads, and it is the shape this project treats as a finding rather than a
feature.

## Decision

**`PasProcess` exports `ProcessId`, and the server's default scratch name
carries it.**

    function ProcessId: integer;   { getpid }

    scratchPath := LookupOr('PASLS_SCRATCH',
                            LookupOr('TMPDIR', '/tmp') + '/pasls-' + mine
                            + '.pas')

Four things were decided rather than assumed.

**The primitive lands and the name does not.** ADR-0116's rule is that one site
is an anecdote and two are a demand, and there is exactly one caller. So what
this record adds to the library is the process identifier — a fact about the
running program, which is the first line of `PasProcess`'s own header comment —
and the *name* is built at the call site. A `PasFS.TemporaryPath` would be a
routine designed for a single caller, with a prefix convention, a suffix
convention and a directory policy all chosen by guessing at the second one.
When a second caller appears it will say what the shape is.

**It is not `mkstemp`'s guarantee, and it could not have been.** `mkstemp`
creates the file exclusively and hands back a descriptor; §6.7.5.6's `bind`
binds a file-variable *by name*, so the file would have to be opened a second
time to be written and the exclusivity is given up at that moment. There is no
way through this language to carry an exclusive creation into a Pascal file
variable, so the strongest property a *name* can have is the one taken: no
other **live** process will choose it. It says nothing about a process that has
exited — the system is free to hand the number out again, and `rewrite`
truncates what it finds, which is the right answer for a leftover.

**`getpid` is bound by the module and not by the runtime.** `pid_t` is a POSIX
typedef, and [ADR-0186](0186-the-runtime-has-a-posix-half-and-a-catalogue-that-holds-only-functions.md) put
`struct stat` in `runtime/pasrt_posix.c` because a library module may not
declare a struct whose layout differs between systems. A *scalar* typedef is
the case that rule does not reach: POSIX says only that `pid_t` is a signed
integer type, and the two widths this foreign-function interface offers can be
judged against that. `integer` is the safe direction — where the typedef is
wider the low word is read and a process identifier fits it, where `int64` were
used and the typedef is `int` the high word would be whatever the call left in
the register. `time_t` in the same module is `int64` for the mirror-image
reason. The rule `runtime/pasrt_posix.c` states for itself — *everything a
program can declare and check, it should* — decides this, and it is worth
having met the case that tests it.

**The file is still left behind.** It is the exact source `pascalc` was handed,
which is the one artefact worth having when the server and the editor disagree
about a document, and it is now one file per process under `TMPDIR`, which is
what `TMPDIR` is for.

## Consequences

`tests/dialect/lib_process.pas` pins `ProcessId` **against the operating
system** rather than against a golden. A number that differs on every run
cannot be written down, so what is compared is the module's answer with the
shell's: `popen` starts a child, the child is the shell, and a shell's `$PPID`
is this program. Nothing in that file had previously asked libc a question only
libc knows the truth of, and this is the shape for one.

`lsp/run.sh` gains a `.tmpdir` marker and `lsp/sessions/scratchname.jsonl` uses
it. **Every other session is handed a `PASLS_SCRATCH` by the harness**, so none
of them can see the name the server picks — the default path was exercised by
nothing at all, which is its own small finding. A session with the marker gets
an empty `TMPDIR` of its own and no `PASLS_SCRATCH`, and what is checked
afterwards is the listing of that directory: it must be `pasls-<pid>.pas` and
`pasls-<pid>.pas.ll`, with the pid the harness captured from `$!`. Taking the
number back out of the name leaves 738 ctest cases green and fails that one
session, which is the whole argument for it.

Two files and not one, and naming both is deliberate: the compiler writes its
IR beside the source it was given, so "everything this server left behind is
its own" is the property, and a second server's leavings would be a second
pair.

**`PASLS_SCRATCH` still overrides the whole path**, and two servers told the
same path share it again — by the instruction of whoever told them. That is a
different thing from sharing it by default, and the harness relies on it: a
session is entitled to a path nothing else has touched, and two runs of the
suite would otherwise hand the same session the same name.

**What this does not do.** It gives no program a temporary *file*, only a
temporary *name*; there is still no `mkstemp` and no `PasFS.TemporaryPath`, and
a program that needs a name unique against processes that have already exited
still has nothing. The roadmap's finding is closed as it was written and that
residue is recorded in its place.
