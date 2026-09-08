# ADR-0367: The rule about helpers is enforced

## Status

Accepted. Follows ADR-0366, which decided what a helper is written in and
converted all thirty-one scripts; adds `tests/checks/helper_portability.py`
and its catalogue, and closes the roadmap's "the lever nobody has pulled".

## Context

ADR-0366 decided that a harness here is Python 3 and reaches for the standard
library rather than a subprocess, and gave the reason: **the portability
boundary is the set of external programs a helper invokes, not the language it
is written in.** Thirty-one conversions carried it out. What was left was a
rule and a record, and this repository has learned twice what that is worth.

**A rule nothing enforces is a convention, and a convention is a sentence.**
`AFTERSCHOOL_PASCAL_OPT` was named in a job's comment and read by no harness
(ADR-0335); `SANITIZE_REQUIRE` was named in a comment for as long as the job
existed and read by nothing, the job refusing a skip by grepping its own log
instead. `require-consistency` (ADR-0330) is the gate written because a
sentence describing a mechanism is not the mechanism, and it found the
convention broken four times over. ADR-0366's own Consequences say the same
thing about itself: *"The rule is a convention until something enforces it."*

Two specific things go wrong without it, and neither is hypothetical.

**A new shell script.** The rule reaches a script only when someone is already
editing it, which is why ADR-0366 converted the set outright rather than
waiting. Nothing stops the thirty-second from being written tomorrow, and the
argument against it — Windows has no bash, no `#!` line and none of the
utilities — is on `doc/roadmap.md` where a person has to go and read it.

**A Python helper that shells out.** Two of the nine macOS failures were a
Python script running `nm`, so "it is Python" is not the claim; "it does not
start `sed` to do what `re` does" is. That distinction cannot be reviewed
reliably by eye across sixty-nine files.

## Decision

**`helper-portability` is a `ctest` case over `tests/checks/helper_portability.txt`,
and it makes three claims that each fail in both directions.**

**One: no tracked shell script the catalogue does not name.** A file is a
shell script by its extension *or* by its `#!` line — the second half is what
sees `tools/pascalcc`, which has no extension. The list is meant to stay at
one entry. The other direction is what makes it a catalogue rather than a
denylist: a `shell:` row naming a file that is gone, or one that has stopped
being a shell script, is an allowance that outlived what it allowed.

**Two: the one shell script that is left is portable.** macOS ships bash 3.2
and will not ship another, GPLv3 being the reason, so what a catalogued file
may not contain is written down: `mapfile`, `readarray`, `declare -A`,
`local -A`, `${p^^}`, `${p,,}`, `&>>`, `|&` — and **`case` inside `$( )`**,
which is not a name but a parse. bash 3.2 scans a command substitution by
counting parentheses, so the `)` that closes a case pattern ends the
substitution and the error is reported far from the line that caused it. That
one cost a CI round trip and was found by reading rather than by the run after
the one that failed. The catalogue is checked against the patterns that
recognise it, so a row this check cannot see is itself a failure.

**Three: no Python helper starts a general-purpose utility.** Invoking the
*toolchain* is the job and is not what this refuses — `clang`, `llc`, `cmake`,
`git`, `openssl`, `valgrind`, `fpc`, `pdftotext`, `ldd` are how a gate asks its
question. What it refuses is `diff` where `difflib` does it, `ls` where
`iterdir` does it, `mktemp` where `tempfile` does it. It reads the **argv
shape** — the first element of a list literal — *and* a wrapper taking the
program and its arguments as positionals, because without the second
`coverage.py`'s `run("nm", str(exe))`, the one call the catalogue allows, was
invisible to the check written to police it.

**It refuses to pass by sweeping nothing**, with a floor on Python helpers
read and on shell scripts read: a run that reached neither prints the line a
clean one prints.

**Two calls were removed rather than catalogued**, so the list starts honest:
`llc_check.py` ran GNU `diff` and now uses `difflib`, and `release_archive.py`
ran `ls -l` and now walks the directory. The first matters beyond tidiness —
`diff`, like `cmp`, writes its own text in the operator's locale, so a finding
that gate printed was partly a fact about whose machine ran it.

## Consequences

**The catalogue is one line of shell, and that is the number to watch.**
`tools/pascalcc` is the product rather than a harness — it is what a user runs
— and the decision that it stays a shell script was taken on 2026-09-07 with
the driver rewrite declined. `doc/roadmap.md`'s Windows row is the standing
argument against that line, and this gate is now where the collision is
visible: adding a second entry is a deliberate edit to a file whose header
says what the list is for.

**A helper that must start a utility can still do it**, by taking a row and
saying which file. That is the shape every catalogue here has, and the reverse
check is what keeps the reason attached to the call: remove the call and the
row fails.

**It walks the tree and filters through git, rather than asking `git
ls-files`.** The first version asked, and `git` exits 128 in a container whose
checkout it calls dubiously owned — so the gate turned four CI jobs red on the
push after it landed. **This tree had written that down twice already**, in
`clause_citations.py`'s comment and then in `format_check.py`'s, and neither
was read. Two things follow. The walk starts at the top rather than from a
list of roots, because the question is whether a shell script exists
*anywhere* and a root list is the one blind spot such a question cannot have;
`.git`, a background agent's worktree and the build trees are excluded by
name, so the answer does not change when git will not speak. And the walk
reaches a file that is **not yet staged**, which `git ls-files` would not — a
helper added and not committed is exactly what this should refuse.

**It cannot see a utility named by a variable.** `run(prog, ...)` where `prog`
was computed is invisible, as is `shutil.which('sed')`. That is the ordinary
limit of reading source rather than running it, it is the same limit
`kind-exhaustive` and `foreign-reserved` have, and both of those answered it
by asking the compiler instead — there is no equivalent here. `doc/sop.md` §7
carries it.

**It does not lint the shell for anything but portability.** No quoting rules,
no `shellcheck`. `shellcheck` is a second tool to install and would answer a
different question well; what this asks is the one question the macOS run
actually produced defects for.

## Alternatives rejected

**Run `shellcheck`.** It is thorough about shell and says nothing about the
two claims that matter here — that a shell script exists at all, and that a
Python helper started `sed`. It is also a dependency, and a gate that skips
without one is a gate that answers only where its author was (ADR-0330).

**Forbid every subprocess from a Python helper.** Then no gate could run the
compiler, which is what they are for. The line between the toolchain and a
general-purpose utility is a judgement, and a catalogue is how a judgement is
written down here.

**Grep for `subprocess.run(["sed"` and be done.** It reads only the helpers
that spell the list out. `coverage.py` — the one file the catalogue allows —
was invisible to exactly that shape, which is how the AST reader earned its
place.

**Leave it to review.** That is what ADR-0366 left it to, and it is what this
record exists to replace. Review found none of the four bash defects on the
first push; the run after it did, one at a time, because each hid the next.
