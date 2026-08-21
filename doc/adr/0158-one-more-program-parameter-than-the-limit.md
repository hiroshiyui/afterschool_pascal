# ADR-0158: One more program-parameter than the limit

Date: 2026-08-22

## Status

Accepted. Found by ADR-0159's work, which could not proceed without it.

## Context

ISO 7185 gives a program no access to its command line beyond its
program-parameters, and those are files. ADR-0081 is how this compiler has one
anyway: §6.7.6.8's NOTE 2 makes `binding(f)` report the binding §6.12 made
*before the program was activated*, so `binding(argk).name` is argument *k*, and
an **unbound** program-parameter is how the list ends — there being no other way
to count arguments.

There were twelve of them, and ADR-0081 said "twelve arguments and eight
`--import`s are array bounds, and both report rather than truncate". Half of
that sentence was false. `maxImports` reports; twelve did not, and **could not**:
a program-parameter list is written out, so a compiler with twelve of them
cannot tell twelve arguments from twenty-one. `Arg(13)` answers `false`, the
parse loop ends, and everything past the twelfth is silently gone.

Twelve was also not headroom. `tests/dialect/lib_os.pas` has four
program-components, so

    --std=afterschool  --import a --import b --import c --import d  src  -o out

is `1 + 8 + 1 + 1 + 1` = **exactly twelve**. Adding ADR-0156's `--target=` — one
flag, on a command line that was already correct — pushed the `-o` file name off
the end, and the compiler reported

    pascalc: -o needs a file name

which is an accusation against the last argument that arrived rather than the
first one that did not. With more surplus still it dropped the source too and
printed the usage, so a compilation that never happened looked like a help
request.

## Decision

Twenty-four usable program-parameters, and **one more than that**.

`argOver` is declared beside `arg1..arg24`, is never read for its name, and is
bound exactly when there was an argument with nowhere to go. `ParseArgs` tests
it before parsing anything and reports:

    pascalc: more than 24 arguments

This is what makes an over-long command line *detectable* by a program that
cannot count its arguments. One extra parameter converts "the list ended" into
"the list ended because it ran out", which are the two things a fixed
program-parameter list otherwise cannot tell apart.

Twenty-four is twice what a `--import`-heavy command line needs: eight imports
are sixteen words, and `--std=`, `--target=`, a `--dump` flag, `--coverage`, the
source, `-o` and its file name are seven more.

## Consequences

`AFTERSCHOOL_PASCAL_TARGET` (ADR-0159) can be set for a whole run without
breaking the one case that was already at the limit. Every other command line
gains twelve words of headroom.

**Mutations, both run.** Removing the `argOver` test makes a 25-argument command
line exit 0 with the surplus quietly absorbed; `selfhost/producttest.sh` fails
on `'…' exited 0`. Putting `argMax` back to 12 makes a 24-argument command line
report "more than 12 arguments"; producttest fails twice — once for the refusal
naming the wrong number, once for the acceptance that no longer happens. The
second mutation is why the positive check exists: a check that pins only the
refusal passes just as well with the bound left where it was.

**Two producttest checks and two coverage sweeps.** These messages carry the
`pascalc: ` prefix, which `diagnostic_coverage.py` filters out as driver output
rather than a diagnostic about a program, so the gate that counts messages is
blind to them by construction — the same hole ADR-0104's line coverage found
before. `tests/checks/coverage.py` therefore drives a command line of exactly
`argMax` words and one of `argMax + 1`, and producttest asserts both outcomes.
Without the first, twelve of `Arg`'s arms are statements no case reaches, and
`line-coverage` said so within one run of the bound being raised.

## What this does not do

- It does not make the limit unbounded. A program-parameter is a name, not a
  subscript, so every one of them is an arm of a `case` statement written out;
  ADR-0081 called that "the whole cost of the approach" and it is unchanged.
  What changed is that going over the end is now a message instead of a
  mystery.
- It does not tell the user *how many* arguments they gave. `argOver` bound
  means "more than `argMax`" and nothing finer, which is all a fixed list can
  say.
- It does not revisit `maxImports`. Eight imports already report, and the two
  bounds are independent — sixteen of twenty-four words is comfortable.
