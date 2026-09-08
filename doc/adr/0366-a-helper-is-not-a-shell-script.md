# ADR-0366: A helper is not a shell script

Date: 2026-09-08

## Status

Accepted. Governs what a helper utility is written in, and supersedes the
weaker rule `doc/roadmap.md` carried for one day. Converts nothing today: it
binds the next new harness and the next substantial edit to an old one. Adds
no code and changes no gate.

## Context

The first macOS run (`doc/history.md`) produced nine failures and not one was
in the compiler. Four were bash or GNU-utility specific — `mapfile`,
`declare -A`, a `case` inside `$( )` that bash 3.2 mis-parses by counting
parentheses, and `\|` in a BSD sed regex. **Two were already in Python**, and
that is the half that decides this record: `nm --defined-only` with a non-PIE
link, and a resource limit Darwin defines and refuses. Three were in test data
and test programs, where no language has an opinion.

The rule written that day — a new harness is Python, an old one is converted
when it is being substantially edited anyway — was written for macOS, where a
shell script *runs* and differs in detail.

**Windows is different in kind and the rule does not survive it.** There is no
bash, no `sed`, no `grep`, no `nm`, no `mktemp`, and no `#!` line. All 31
shell scripts here do not misbehave there; they do not run. That makes each of
them a blocker rather than a bug, and "convert when substantially edited"
never converges, because the stable scripts nobody edits are exactly the ones
that would remain. Windows is a live row on `doc/roadmap.md` and this is
cheaper to decide before the row is taken than after.

Measured on 2026-09-08, and recount rather than quoting: 5 949 lines of shell
across 31 files; 11 844 lines of Python across 38. **Six** of those 38 invoke
a Unix tool at all and **two** use Unix-only standard library, so the Python
side is already most of the way to the rule below.

## Decision

**The portability boundary is the set of external programs a helper invokes,
not the language it is written in.** A Python script that runs `nm` is exactly
as unportable as a shell script that runs `sed`, which is what the two Python
failures on macOS demonstrated. So the rule is two rules, and the language is
the smaller one:

1. **A harness is Python 3.**
2. **A harness reaches for the standard library rather than a subprocess** —
   `pathlib`, `tempfile`, `shutil`, `re`, `difflib` in place of `find`,
   `mktemp`, `cp`, `sed`, `diff` — and guards a Unix-only module rather than
   importing it unconditionally. Invoking the *toolchain* (`clang`, `pascalc`,
   `pascalcc`, `llc`, `valgrind`) is not what this forbids; invoking a
   general-purpose Unix utility to do what the language can do is.

**A conversion is checkable, and that is what makes converting allowed at
all.** The standing objection was that these scripts *are* this project's
evidence, so rewriting one is the single change with no oracle to check it. It
has an answer, and this repository already owns it: every gate's record names
the mutation that proved it. A conversion therefore lands with two things, and
neither is a green suite —

- the two versions run on the current tree and produce **byte-identical**
  output; and
- that gate's own historical mutation is re-run against the new version and
  must fail **the same way**.

**Helpers that ship to a user are written in Afterschool Pascal; gates are
written in Python.** The split is not taste. A gate must be able to fail
*because the compiler is broken*, so it cannot be written in the language
under test. A shipped helper has the opposite constraint: it runs on the
user's machine, where the one thing this project can guarantee is present is
the compiler and runtime it just installed there. `bin/apconfig` is the
precedent and the proof — a program in this language, compiled by the compiler
the tree just built, installed beside `pascalc` and found by the same three
rules ADR-0244 gave the driver (ADR-0361).

## Consequences

**The driver is a collision this record names and does not resolve.**
`tools/pascalcc` is not a harness, it is the product; ADR-0009 made it a shell
script and the decision of 2026-09-07 kept it one, with new logic going into a
helper like `apconfig` instead. Windows has no shell to run it in, so that
decision and the Windows row cannot both stand. Deciding it is the Windows
row's own work, and ADR-0361 has already shown what the answer looks like.

A gate needing a tool that does not exist somewhere goes on skipping with 77
under the `*_REQUIRE` convention (ADR-0330). On Windows several would. That is
the gate set degrading visibly, which is the behaviour this tree already
requires of it.

**The rule is a convention until something enforces it.** Each of the four
bash defects cost a full CI round trip to find, one at a time, because each
hid the next; a lint over every tracked script — the constructs bash 3.2
lacks, the GNU-only flags, a subprocess a stdlib call would do — would have
found all four on the first push with no Mac at all. It is not built and it is
the cheapest thing on `doc/roadmap.md`.

## Alternatives rejected

**Convert all 31 scripts now.** It front-loads every conversion's risk for a
platform nobody has taken yet, and 5 949 lines of it, against a rule that
makes the same scripts portable one substantial edit at a time. The
differential-and-mutation check makes a conversion safe; it does not make
thirty of them cheap.

**Keep the weaker rule.** It was written when macOS was the only question. It
does not converge for Windows, and the scripts it would leave behind are the
ones nobody has a reason to touch.

**Require MSYS2 or Git Bash on Windows.** It makes a Unix emulation layer part
of the surface under test, and asks somebody who installed a Pascal compiler
to install a Unix environment to run its gates. It also hides the defect
rather than fixing it: the scripts would still be wrong, and would still be
wrong on the next platform.

**Write the gates in Afterschool Pascal too.** It is the most portable option
and it is the one thing a gate may not be. A gate exists to fail when the
compiler is broken, and one written in the language under test cannot run in
exactly the case it exists for.

## What this does not do

It converts no script. It does not claim Python is portable by itself — rule 2
is there precisely because it is not. It does not decide the driver. And it
does not make the rule mechanical; until the lint exists, what enforces this
is review.
