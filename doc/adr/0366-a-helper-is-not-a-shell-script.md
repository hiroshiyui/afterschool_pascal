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

**`target-sizes` is the ninth**, and the first with five arms rather than
four, because a gate answering about *other machines* has more ways of not
answering than of answering. Compared byte for byte: the real run, which
compiles `runtime/pasrt.c` and `runtime/pasrt_task.c` for the five targets a
cross compiler is installed for here; a `PATH` holding no triple-prefixed
compiler at all, which reaches the host through `cc` and skips with 77;
`TARGET_SIZES_REQUIRE` naming a target with no compiler, which is the refusal;
a shim compiler that runs and cannot find `<setjmp.h>`, which is the
*incomplete* arm the shell version exists to tell apart from both others, and
that arm again under `TARGET_SIZES_REQUIRE`; and ADR-0155's own defect
restaged in a copied tree — `PAS_JUMP_SIZE` back at 256, which flags aarch64
and both arms while x86-64 and i686 pass, exactly the shape that motivated the
gate.

**`install-layout` is the tenth**, and it has two entry forms rather than one:
`--prefix` is what `tools/release.sh --check` drives (ADR-0296), so a
conversion that got only the build form right would have broken the tag job
and nothing before the tag would have said so. Eight arms: both forms on this
tree; a prefix and a build directory that are not there; a file dropped from
the layout list; ADR-0244's own claim mutated, a library module renamed away
from the interface it exports, which must fail with the module's *name* in the
message and does; and the floor of twenty modules, which had to be staged with
the layout list intact, the first attempt at it having been caught one check
earlier.

**`release-archive` is the eleventh**, and the first that converts a gate
while leaving the script it drives in shell: `tools/release.sh` is unchanged,
which is what keeps this a conversion rather than a redesign. Seven arms, and
the three ADR-0296 says fail separately were made to fail one at a time by
mutating `release.sh` in a copied tree — the version refusal removed, the
version refusal reworded, the digest comparison removed — plus a build
directory with no compiler in it, an archive built without `lib/afterschool/`,
which fails through `install_layout.py --prefix` and names `pastext.pas` in
its message, and the no-argument form.

**`unicode-conformance` is the twelfth**, ten arms, and the widest spread so
far: the database absent, and again under `UNICODE_CONFORMANCE_REQUIRE`; no C
compiler, and again under it; `runtime/pasrt_unicode.c` given a GNU statement
expression, which is the `-pedantic-errors` build refusing; `NormalizationTest.txt`
present but unreadable, which is the driver's exit 2 and the one arm the shell
version carries a comment about, `$?` inside `if ! cmd` being the negation's
status; a file the driver does not open removed, which is `generate.py`
failing; `python3` off `PATH`, which is the half-checked exit 0; the committed
header edited by hand; and — the question the gate exists for — canonical
ordering made non-stable in `u_ccc`, which the database catches at U+1E14.

One arm here cannot be byte-identical and the reason is worth naming: the
header-drift arm prints a unified diff whose `+++` line names a **fresh
temporary file**, so its path and mtime differ between any two runs of
anything. `difflib` writes no timestamp at all by default, which would have
made the output stop being a diff `patch` can read, so the conversion supplies
one in `diff -u`'s own format; what is compared is then everything but that
line.

**`command-injection` is the thirteenth**, and the one whose mutation had to
be a *rebuilt language server*. Nine arms: this tree; ADR-0362's own defect
restored in a copied `lsp/` and `lib/`, the source path wrapped in apostrophes
and handed to `Run`, which both tools report; ADR-0363's private-directory
claim, its `pasls-` prefix changed to `shared-`; its scratch cleanup removed;
the arm the chr(0) refusal rests on; a server that does not build; and no
arguments at all.

Two things it taught. **The chr(0) claim does not rest where its record
suggests**: mutating `HoldsNul` to answer no leaves the gate green, the
refusal coming from the tool handler's empty-`path` arm — the JSON reader
hands it nothing for a `\u0000` string. Both versions agreed either way, so
this is a fact about the claim and not about the conversion, and it is written
here because the next person to mutate that gate will reach for `HoldsNul`
first, as I did. And **the no-argument arm is the one place byte-identity is
neither possible nor wanted**: bash's `${1:?...}` names its own line number
and is translated into the operator's locale, so what the conversion writes
instead is a plain `usage:` line.

Two things the shell version needed are gone rather than translated, and
neither is part of the question: the `sed` that spliced the payload path into
a JSON line, which built invalid JSON for any path holding a quote or a
backslash, and is now `json.dumps` with the real path; and the `sed -i`
portability wrapper written for it. The spy compiler is Python for the same
reason the gate is.

**`target32` is the fourteenth**, and the first sweep rather than a
single-question gate: 597 sources built and run for `i386-pc-linux-gnu`
against a runtime the gate builds itself. Seven arms, byte-identical
throughout, including both directions of `target32_known.txt` — a row added
for a case that passes, and the one real row removed — the floor, proved on a
symlinked tree holding three sources, the two `TARGET32_REQUIRE` arms, and a
runtime that will not compile for the target. **The sweep stays serial.** What
is compared is one list of failures in one order, and that order is the one
the catalogue was written against; making it parallel is a separate change
with its own argument, not a thing to do in passing while converting.

**`seed_current` and `seed/refresh` are the fifteenth and sixteenth, and they
had to be converted together.** ADR-0347's whole point is that the two
translate the same way — from the root, with a relative source path, because
ADR-0293 puts the source's own path into the emitted module — and in shell
that claim was two copies of one loop. Converting one alone would have put it
across two languages, which is strictly worse than two copies in one.
`seed_current.py` now imports `components`, `translate` and `unified` from
`refresh.py`: one loop, one claim.

The evidence is stronger than a differential usually gets, because the
artefact itself can be compared. Two staged trees, one reseeded by each
version: **identical console output and byte-identical seed modules**, all
three of them, 318 423 lines. Then `seed_current` run against each freshly
seeded tree, where it passes — the state this repository is only in at a
release commit, and which the stale-seed differential cannot reach. Nine arms
in all: the stale tree, the fresh tree, no compiler, no runtime, an extra
module in `seed/`, one missing, a candidate that does not reproduce, a
compiler that gets `hello.pas` wrong, and one that cannot compile it.

**Two defects of my own, and both are the kind a green run would have
hidden.** A *missing* seed module crashed the Python where the shell carried
on: `cmp` merely fails, and the set check below still had its own half to say.
The shell reached that by letting `diff` print the C library's message **in
the operator's locale**, which is one of the two reasons ADR-0366 exists, so
the conversion says it in the gate's own words instead. And the
`candidate-does-not-reproduce` arm caught **stdout buffering**: Python
block-buffers a redirected stdout where `echo` does not, so the compiler's
diagnostics landed before this script's own lines. Both scripts now set
`line_buffering`. Every harness here that prints around a subprocess it does
not capture has that hazard, and it is invisible on a terminal.

The forcing of that arm is worth recording: a candidate that fails to
reproduce needs a *non-deterministic* compiler, which nothing in the tree is.
Staging one — a wrapper appending a comment to each `.ll`, so the candidate
pass differs from the pass by the compiler built from it — is what made the
arm reachable at all.

**`tests/dumps/run` is the seventeenth**, and the first per-case harness: it
is not one gate but thirty-five ctest cases, so the differential is the whole
corpus rather than a run. All thirty-five byte-identical, plus six arms — a
golden that no longer matches, no golden at all, a status the case did not
ask for, that case again with a `.status` sidecar, a compiler that writes to
the second stream, and a `.flags` naming an option the compiler refuses,
which is ADR-0284's own failure shape.

One detail had to be copied rather than reasoned about. The shell compared
with `diff -u expected <(...)`, so the `+++` line of a failing case names
**`/dev/fd/63`** — bash's process substitution — and a golden's failure output
has been read by people in that form. The conversion writes the same name.

**`lsp/build` and `lsp/mcp` are the eighteenth and nineteenth**, and here the
artefact settles it: the server binary built by each is **byte-identical**, at
the default level, at `-O0`, and under `PASLS_COVERAGE_IR`, where the emitted
coverage IR matches too. Then the launcher: a first start that builds, a
second that does not, a library source touched so that it does again, no
compiler anywhere, and a component that will not compile.

`lsp/mcp`'s freshness test is the one thing that had to be written rather than
translated. `ls -t … | head -1` picks the newest *name* and `-nt` then
compares that name's mtime — an argmax used to compute a max, which Python
takes directly. **`.mcp.json` names this script**, so the MCP server for this
checkout must be restarted before an agent sees the converted launcher.

**`lsp/run` is the twentieth**, the largest so far, and the one where the
subject is a *protocol*: 33 recorded sessions replayed byte for byte, framing
and carriage returns and `Content-Length` counts included. All 33 identical,
plus nine arms — a session with no golden, a `.note` that no longer matches,
a `.note` removed so the server's own words are unaccounted for, no sessions
at all, a server that will not build, no arguments, a server made to exit 3,
and ADR-0363's two claims restaged through *this* harness: the private
directory's prefix changed, and its cleanup removed.

**Three shell defects surfaced, and all three are this record's own
argument.** With no `*.jsonl` to match, bash leaves the pattern in the loop
variable — no `nullglob` — so the shell reports a session literally named `*`
before saying none were replayed. `[[ $p == */* ]] && p=$(cd $(dirname $p) &&
pwd)/$(basename $p)` yields **`/pascalcc`** when the directory does not exist,
turning "no such directory" into a complaint about a file at the root. And
`lsp/build` printed a Python traceback where the shell printed a shell's
`command not found`; it now answers 127 and a line, which is what a caller
handed a wrong `pascalcc` needs to read.

One thing was dropped rather than translated: the shell wrote the server's pid
to `$work/$name.pid` and nothing ever read it.

**The twenty-first through twenty-fourth were converted in parallel**, three
of them by subagents given this record and the method, with integration, the
gate runs and the suite kept in one place. The method is what made that safe:
a differential is checkable by whoever reads the report, and every arm below
was named and compared.

**`langspec-audit/sandbox`** builds a *directory*, so what was compared is the
directory: `diff -r` over the copied compiler and runtime, the `pascalcc`
wrapper, all three comment-stripped components, `MANIFEST.txt` and
`README-reader.md`. Five arms, byte-identical throughout — a named target, no
argument at all (two temp directories whose contents still match), no
`pascalc`, no `libpasrt.a`, and — staged with placeholder PDFs, because this
machine cannot reach it naturally — the branch where `MANIFEST.txt`'s missing
list reads `nothing`.

**`tools/release`**, twenty-five arms across `--archive`, `--check` and
`--notes`. The eleventh conversion's paragraph above says this script is
unchanged; that was true then and is not now. Four things could not match, and
three are the same class: the shell leaks **GNU tar's, `mkdir`'s and `awk`'s
own diagnostics in the operator's locale** before its own refusal line. The
fourth is the archive's bytes, which no message compares — verified instead by
its members, 45 of them, identical in name, order, mode, size and ownership,
and the Python archive passes both versions of `--check`. It is also
deterministic where the shell's was not, gzip's mtime now being zero.

**`tests/spec/clauses/extract_pdfs`** (renamed, `extract.py` beside it being
the parser it calls) has the best evidence of the four: it regenerates
committed files, and regenerating them after the conversion changed **one line
in each** — the `# Generated by` header naming the new file. Nine arms
otherwise, including a fake `pdftotext` whose lines had to interleave with the
parser's in the right order, which is the buffering hazard again.

**`runtime/unicode/fetch`** downloads the database, so both versions were run
against a staged copy and the *downloaded trees* compared: byte-identical, at
the pinned version and at 16.0.0. Its failure arms diverge on purpose —
`urllib` in place of `curl -fsSL` means there is no transfer tool to quote, so
a 404 is this script's own sentence and exit 1 rather than curl's and exit 22,
and the *no curl on PATH* arm ceases to exist. That is rule 2 doing what it is
for.

**`seed/ddc`** is the twenty-fifth and the widest of the batch: seventeen
arms, every `skip` guard among them, plus a v0.1.0 that will not configure,
one that will not build, a link that fails, a PASS staged with stand-in
compilers, and a FAIL. Two arms could not match, and the cause is worth the
space: **GNU `cmp`'s messages are localised**, and in *both* directions — the
`differ` line says `byte 15` in a UTF-8 locale and `char 15` under `LC_ALL=C`,
while the EOF line's quotes flip the other way. So the finding this gate
printed was a property of the operator's locale, which is precisely the defect
class this record was written about. Under `LC_ALL=C` the two arms are
byte-identical.

It also found a hidden status: `git archive v0.1.0 | tar -x` has no
`pipefail`, so a tag naming a blob gets git's message, then **tar's, in the
operator's locale**, and exits 2 — tar's status, not git's. The conversion
reports git's message and git's status. That arm is unreachable behind the tag
guard, and it is the one place in this batch where behaviour was chosen over
byte-identity.

**Four latent defects surfaced and two were fixed.** `release.sh` called
`die` inside `$( )`, where it exits the **subshell**: a compiler that would
not answer `--version` printed that, and then a second refusal naming an empty
version — now one message naming the cause. `fetch.sh` answered an unwritable
destination with the C library's message, twice, in the operator's locale —
now its own sentence. Left alone and recorded here: `extract.sh`'s exit status
is the *last* loop iteration's, so a failure on the first standard is masked
by success on the second; and its 50-heading floor cannot detect the **wrong
document** — feeding it the Free Pascal reference as `iso10206.pdf` yields 190
"clauses", a bogus inventory and exit 0. That last is a property of
`extract.py`, which no conversion touched, and it belongs in `doc/sop.md` §7.

**`runtime-isoc` is the twenty-sixth**, 22 arms: both directions of
`nonstandard_c.txt`, the emitted half of the harvest, the skip, and every one
of the five strict compiles made to fail. Two arms diverge for this record's
own reason — bash reports a missing command in the operator's locale, naming
its own line number. It also found that the **fifth** strict compile spells
`clang` literally where the other four honour `APASCAL_CLANG`, so on a machine
where the two differ that pass answers about another compiler; preserved with
a comment and filed in `doc/sop.md` §7.

**`tls` is the twenty-seventh, and it was reporting its findings to nowhere.**
`exec 3<>"/dev/tcp/127.0.0.1/$p" 2>/dev/null` — `exec` with no command makes
its redirections **permanent for the shell**, so from the first *successful*
port probe, which is every ordinary run, fd 2 was `/dev/null` for the rest of
the script. Six diagnostics were swallowed: the probe that would not build,
the probe that exited non-zero, both "did not print what was expected" diffs,
the sanitizer's finding, and the probe failing under it. The gate still exited
1, so it failed correctly and printed **nothing to read**. The redirection is
backwards in the other direction too: when the connect fails, fd 3 fails
first, `2>/dev/null` is never applied, and bash's own `connect:` message leaks
in the operator's locale.

That is why five of its arms could not be compared against the shell as
written — the shell writes nothing. Each was compared twice: stdout and exit
status against the real script, then everything against a scratch copy with
that one line corrected, where all five are byte-identical. **The conversion
has no such construct and prints what the shell intended.** Twenty arms
besides, including the gate's own historical mutation — `SSL_VERIFY_PEER` set
to 0, which ADR-0264 names as the defect that fails quietly — and its
eight-constant floor, which turns out to be unreachable: the row-count check
sits below a `diff` that fires first on any change to the row count.

**Nothing here detects a harness whose diagnostics go nowhere**, which is the
general form of that defect and is now a row in `doc/sop.md` §7.

**`selfhost/irtest` is the twenty-eighth**, fourteen arms, and the artefact
compares: 408 programs built and run under both compilers, 189 rejected as
their `.err` says, 70 sources carrying no expectation, and stage 2 = stage 3 —
byte-identical stdout, stderr and status. The arms that had to be staged are
the ones that matter: the fixed point broken by a `clang` shim stamping each
`.ll` with a serial, a `PAS_FILE_SIZE` disagreement in both directions, an IR
that will not assemble, and both self-compile failures. One arm could not be
forced — `stage 2 emitted N modules and stage 3 M` needs a compiler resolving a
different number of program-components on two passes over one source, which
nothing here is; it is named rather than claimed.

**`tests/run_test` is the twenty-ninth and the one roughly 850 ctest cases run
through**, so the differential was the whole corpus: 597 sources, plus twelve
failure arms staged one at a time — no expectation at all, a golden that no
longer matches, a program that will not compile with and without a `.err`, a
component that will not translate, a runtime message that differs, a program
that succeeds where a failure was expected, ADR-0272's load-bearing half (a
warning with no `.warn`), a `.warn` that says something else, a correct one,
and an `.opt` sidecar.

**The corpus caught a defect of mine, and it reached back into two conversions
already pushed.** One case of 597 differed: `lib_lsp`. `Path.read_text()`
performs universal-newline translation, so a golden holding `\r\n` compares
equal to output that has lost its carriage returns. `lsp/run`'s own header says
its goldens hold the real carriage returns and the real byte counts, and the
twentieth conversion had quietly stopped holding that half — **both** sides
were translated, so no difference could appear. Proved by turning one CRLF into
LF in a session golden: byte-unequal, equal after translation, and the gate now
reports it where before it passed. All three harnesses now read a golden with
`newline=''` and split lines at `\n` alone, `str.splitlines` also breaking at a
bare carriage return.

**`tests/checks/sanitize` is the thirtieth**, and its four modes are four
sweeps: address, thread, valgrind and coverage, each byte-identical on the real
corpus, plus the mode refusal, both `SANITIZE_REQUIRE` arms, both
`VALGRIND_REQUIRE` arms, a flagged case, a catalogued one, the floor, and both
halves of ADR-0358's probe — the probe that will not build, and the probe that
builds and reports nothing, which is the state ADR-0342 describes. That last
one caught a defect of mine: `head` over a captured stream printed the empty
fragment after the final newline as a line, which `head -n` over a file does
not.

Two of the shell version's awkwardnesses are simply gone, both written for bash
3.2: the newline-delimited string standing in for `declare -A`, and the hoisted
`asan_options` that existed so `uname` was not forked five hundred times. What
each was working around is kept in a comment, because the reason is still worth
knowing.

**One question crossed two conversions and is settled here.** CLAUDE.md
requires `run_test` and `irtest` to read a `.components` file the same way. Both
now keep a final line that has no newline, where bash's `read` dropped it. No
sidecar in the tree lacks one, so no case means two things today — but the two
agree with each other, which is what the rule asks.

**`selfhost/producttest` is the thirty-first and the last.** Every tracked
shell script under test is now Python; `tools/pascalcc` remains one by the
decision of 2026-09-07, and this harness is the thing that reads it. Twelve
arms compared: the real run of 29 checks; no arguments and one argument; a
compiler that is not executable; a named file with no `.out`; one that will
not translate; a compiler that exits 0 and writes no IR; a `-h` that writes
nothing; a version that disagrees and a `CMakeLists.txt` naming none; a flag
the parser knows and the help text does not; a driver option and a subcommand
dropped from the help text; and a driver that mangles a dump instead of
passing it through.

Two things stay shell's own and should. `tools/pascalcc` is a shell script, so
the checks that derive its options and subcommands parse *its* text — the
`while` loop's case arms and the `case ${1:-}` dispatch — and the SSE2 check
traces it with `bash -x`, because what is asserted is the command line the
driver builds and not anything in the IR. What did go is `timeout`: a
subprocess deadline is an argument to `subprocess.run` and needs no coreutils,
which is what the shell's three-way `timeout`/`gtimeout`/nothing fallback for
macOS was working around.

**One arm exposed a weakness in the check itself.** Deleting `-c`'s own line
from the driver's help text leaves both versions passing, because the token
still occurs in another line's prose — "an object to link, from a component
compiled with `-c`". The shell's comment says the token test was what fixed
this class; it narrowed it and did not close it. Removing both mentions does
fire. Recorded in `doc/sop.md` §7, not fixed: the two versions agree, so this
is a fact about the check and not about the conversion.

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
