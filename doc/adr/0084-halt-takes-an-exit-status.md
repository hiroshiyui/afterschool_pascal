# 84. `halt` takes an exit status

Date: 2026-08-14

## Status

Accepted.

## Context

ADR-0083 gave `selfhost/compiler.pas` a command line, and the release checklist
then asked the question no test had: what does it exit with?

```
$ pascalc bad.pas -o bad.ll
bad.pas:3:3: error: undeclared identifier 'x'
$ echo $?
0
```

`pascalc-s0` exits 1 there. A compiler that cannot report failure is not usable
from a build rule — `pascalc bad.pas && clang bad.ll ...` runs the linker on a
file that was never written.

**Neither standard offers a way.** ISO/IEC 10206:1991 §6.7.5.7 is one sentence
and gives `halt` no parameters; there is no other control procedure; and clause
3.6 does not model a process exit status at all, so normal completion, `halt`
and termination by an error are the same thing as far as either standard is
concerned. ISO 7185 does not even have `halt`.

This project refuses extensions: "an extension should be taken from
ISO/IEC 10206:1991's spelling rather than invented here." That rule has held for
every language feature since the bootstrap. It is the reason this record exists
rather than a commit.

## Decision

**`halt` takes an optional integer argument, the exit status.** `halt` alone is
§6.7.5.7's, and exits 0. `halt(n)` exits with `n`.

**The rule it is being weighed against is about the language, and this is
not.** Every extension refused here would have changed which programs are valid
or what a valid program means. This one cannot:

- §6.7.5.7's `halt` takes no parameters, so `halt(1)` was a compile-time error
  until now — *no conforming program contains it*, and none changes meaning.
- The value a conforming program exits with is unchanged: 0, from every path
  that reached it before.
- `halt` is a required *identifier*, which §6.1.3 makes shadowable, so a program
  that declares its own is unaffected.
- Under `--std=iso7185` nothing changes at all, that standard having no `halt`.

What is extended is therefore the **processor**, in a dimension the standard
does not describe — the same dimension in which a run-time error already exits
1 and no clause says so. That is the whole of the argument, and it is why the
answer here differs from every previous request for an extension.

**The status is an ordinary integer expression**, not a literal: Sema asks only
that it be an integer, and the boundary is now "at most one argument, and it
must be an integer" rather than "no arguments".

**The compiler uses it, which is why it exists**: `if errorSeen or argsBad then
halt(1)`. A bad command line and a rejected program both report failure; `-h`
does not, which is why the command line carries two flags rather than one.

## Consequences

**`doc/implementation-defined.md` §5 has a second entry.** Clause 5.1 g)
requires extensions to be described, and the document had listed exactly one
(the underscore in an identifier) since it was written. It now lists two, and
that count is the honest measure of what this decision cost.

**`difftest.sh` had to learn that 1 means rejected.** A large part of the corpus
— `badparse/`, `badsema/`, `torture.pas`, every `tests/*.err` case — is meant to
be refused, and the harness treated any non-zero status as a crash. It now
distinguishes: 1 is a rejection and the dumps still decide whether the two
compilers agree about it; anything else is still a crash.

**A mutation survived 279 tests and is what added the check.** Deleting the
compiler's own `halt(1)` left every case green: the golden files compare what a
program *wrote*, never how it stopped, so nothing in this repository had an
opinion about an exit status. `selfhost/producttest.sh` now compiles a program
it must refuse and requires a non-zero status, no IR, and a diagnostic naming
the fault — and requires 0 for one it accepts, since a compiler that always
failed would satisfy the first half. ADR-0067's lesson in its plainest form: a
claim no test names is a claim nothing checks.

**`verify/` gains nothing.** There is no arithmetic here, and the rule that
would restate the lowering is the one ADR-0013 refuses.

### What this does not do

**It does not give a program the status it was invoked with**, nor any other
process state. §6.12 binds the program-parameters and nothing else crosses.

**It does not define what a status *means*.** `halt(0)` is a successful halt and
`halt(1)` a failed one only by the convention of the system running the program;
the compiler picks 1 for failure because that is what `pascalc-s0` does.

**It does not change how a program that falls off the end of its block exits.**
That is still 0, and still §6.7.5.7's answer for a bare `halt`.

**It does not make the status available to a run-time error.** Those still exit
1 from `pas_runtime_error`, which no clause requires and no program can choose.
