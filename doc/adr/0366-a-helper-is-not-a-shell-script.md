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

**The pilot is `seed-portable`, converted with this record** (2026-09-08). It
was chosen as the smallest gate here — 73 lines, a leaf nothing else invokes,
with its own mutation named in ADR-0347 — so that what it proves is the
*method* and not the port. Both checks were run before the shell version was
deleted: byte-identical output on the current tree and on five constructed
trees covering every branch the real one cannot show (a clean sweep, an
absolute path present, below the floor, no modules at all, and both faults at
once), and then the gate's own mutation applied to the **real** committed seed,
where both versions refused it in the same words and the artefact was restored
byte for byte.

**`tool-dumps` is the second, converted the same day, and it is the one that
matters** — its shape, enumerate a corpus and run the compiler over every
member of it, is what about ten gates here do, so what it settles is the
template rather than one gate. Six comparisons: the real tree, all 3 600
invocations, byte for byte; a stub compiler crashing one source by the runtime
message and another by exit status, which pins both detectors, the two-line
report, the two-space indent, the empty-output arm and the order 900 sources
are swept in; a compiler path that is not executable; a corpus below the floor;
an empty corpus; and a source the git filter removes. It gained no temporary
file to clean up and it enumerates by **byte order** rather than piping `find`
into `sort`, whose collation follows `LANG` — the same names in a different
order on a differently configured machine.

A missing root directory is the one behaviour that changed: `find` wrote a
diagnostic and carried on, and the walk is simply empty. The floor is what
guards that, which is what a floor is for (ADR-0282).

**`variant-check` is the third**, and it is the one that shows the check has
teeth on a gate with real machinery: it builds a compiler out of three
components, counts the guards in it, links it and sweeps 901 sources with it.
Six arms compared — the real run, a compiler path that does not exist, a
compiler that cannot compile the components (where `head -20` over *two* files
writes `==>` headers and a blank line between them, and the reproduction had
to match that), a build carrying no guards, a build whose IR does not link,
and no `clang` at all, which is the skip. Only the temporary directory's name
differed, which differs between any two runs. It shed the same locale-dependent
`sort`, and one more: the git filter leaned on GNU grep keeping every line when
handed an empty pattern file, where POSIX says an empty pattern set matches
nothing — a BSD grep could have emptied the corpus and left the floor to report
it.

**`bare-source-name` and `long-path` are the fourth and fifth**, both small
leaves and both compared on every arm: the real driver, a driver path that is
not executable, and a driver that refuses everything, which makes each claim
fail in turn and prints the per-claim notes. `long-path`'s only difference is
the number inside its own message — `mkdtemp` names a directory three
characters shorter than `mktemp -d` does, so it builds a 298-character path
where the shell built 301, and the claim is that it passes 255.

Both lost one line of noise, and every remaining script with a required
argument has it: `${1:?usage: …}` makes bash print its own `<script>: line 42:
1:` in front of the usage text, naming a line number and a positional
parameter that mean nothing to a reader. The usage line is printed plainly.
Every arm that states a claim is byte for byte what the shell wrote.

**`stale-component` and `new-project` are the sixth and seventh.** The first
edits a source between two compilations and reads the driver's diagnosis, and
was compared on all four claims plus the arms that make each fail: a driver
that translates nothing and dumps its log, one that links anything so a stale
object is accepted, and one that refuses the stale link without saying why.
The second drives eight sections of `new-project`, `build`, `run` and `test`
over a generated skeleton and fourteen rewrites of its project file, and was
compared on the real driver, one that refuses everything, and one whose reader
accepts a misspelled key. Both shed the `edit()` helper that existed only
because BSD sed's `-i` takes a mandatory suffix: a substitution over a string
needs no temporary file and no rename.

**A conversion can also introduce a defect, and three of these did.** The
prose of a shell script was spliced in below a licence header the script
already carried, so `bare-source-name`, `long-path` and `stale-component` were
pushed with the licence in them twice. Nothing here reads a licence header, so
no gate could have said so; it was found by counting the blocks across all
seven files after the eighth splice put in a third. The lesson is the ordinary
one — a mechanical edit repeated by hand goes wrong the same way every time —
and the answer is the same as everywhere else here: count them rather than
read them.

**`llc-second-backend` is the eighth**, and the first whose *skip* is part of
what was compared. Four arms: the real build, which assembles 158 modules and
then builds two more compilers through `llc` at `-O0` and `-O2` and requires
each to translate all three program-components to identical IR; `llc` absent,
which is the skip with 77; `llc` absent with `LLC_REQUIRE` set, which is the
refusal ADR-0330's convention exists for; and a build directory that is not
there. A gate that can skip has to be shown skipping *and* refusing to skip,
or half of it is untested by the conversion.

A conversion may fix something, and this one did: the shell version wrote its
matches to `.seed-portable.tmp` **in the repository root**, a harness leaving a
file in the tree it measures. That is not a licence to redesign — the question,
the wording, the floor and the exit status are unchanged, which is what made
the differential possible at all.

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
