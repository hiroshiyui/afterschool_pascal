# 308. The directory a bare name is in

Date: 2026-09-03

## Status

Accepted, 2026-09-03. Closes `doc/roadmap.md`'s row *A source named with no
directory finds no sibling module*, opened the same day by
[ADR-0295](0295-a-corpus-written-to-be-read.md)'s successor document
`doc/tour.md` and recorded there rather than fixed, because a tour is written
in a `docs:` commit and a compiler change wants a case of its own.

## Context

[ADR-0244](0244-an-import-is-found-where-the-program-is.md)'s first search
rule is the directory the source being translated is in, and it is the rule
that makes a checkout compile with no configuration: a program and its
components written in one directory find each other, with no manifest and no
build order. `README.md` says so, and `doc/tour.md`'s module section is built
around it.

`SourceDir` computed that directory from the path the compiler was handed, by
scanning back for a `/` and answering **the empty string** when there is none.
`AddPath` then drops an empty directory, deliberately and for a good reason:
an empty entry in `AFTERSCHOOL_PASCAL_PATH` would name the working directory,
which is what POSIX says of `PATH` and is a surprise nobody wants from a
compiler.

So the two decisions were each right about their own question and wrong
together. `pascalc ./prog.pas` searched the source's directory;
`pascalc prog.pas` searched **nowhere** and answered *no interface named
'greeting' has been exported*. The rule held for every spelling but the one a
person types.

**No oracle here could see it**, and the reason is the one `long-path`
(ADR-0291) and `stale-component` (ADR-0245) each give: a test case cannot
choose how it is *named*. Every case in this tree is compiled where it sits by
a harness that passes it a path, so the broken spelling is one no corpus here
can produce. It was found by writing `doc/tour.md` — prose about a compiler
being a claim nothing else here can contradict, which is why every fragment in
that document was compiled.

## Decision

**`SourceDir` answers `./` for a name with no directory in it.**

A bare name *has* a directory and it is the working one; answering the empty
string conflated "no directory was written" with "there is no directory to
search". The fix is at that question and not at `AddPath`, which is still
right to drop an empty entry — the two callers are asking different things,
and only one of them was wrong.

## Evidence

`bare-source-name`, a shell harness with two claims, is the gate. It needs to
be one rather than a test case for the reason above.

1. `cd` into a directory holding `greeting.pas` and `sayhello.pas`, compile
   `sayhello.pas` **by its bare name**, and run it.
2. Compile the same program named with a directory, from outside it.

The second claim is what keeps the change to the case it was made for: a fix
that answered `./` for *every* name would pass the first and break nothing
visible, and would have made the search the *working* directory rather than
the source's. Those are the same directory only in the first claim, by
accident of its `cd`.

The mutation is the one line put back
(`tests/mutation/mutants/0308-bare-source-name-searches-nowhere.mut`) and it
kills claim 1 alone.

## What is not done

**No other spelling is checked.** A name like `sub/prog.pas` already worked
and still does; `prog.pas` was the only broken one, because it is the only one
that yields no `/`.

**`--import-path .` is unchanged** and remains what a caller writes to add the
*working* directory rather than the source's. The two are now distinguishable,
which they were not while a bare name contributed nothing.

## Consequences

**Two right answers to two different questions can be wrong together.** Both
`SourceDir`'s empty string and `AddPath`'s skip were argued for where they
stand, and each comment names its own reason correctly. Nothing in either
names the other, and the defect lived in the join. That is the shape ADR-0291
recorded as *a comment that names a hazard is not a check*, arriving from the
other direction: here two comments each named a different hazard and neither
could see the pair.

**A document can be an oracle.** This is the second finding in two days
produced by writing prose rather than by a gate — after the container module's
header comment describing a tree three features old (ADR-0304) — and both were
found by someone reading what the tree claims rather than what it does. The
discipline that produced this one is `doc/tour.md`'s: every fragment compiled.

**Thirty-three gates**, `bare-source-name` running under `ctest` like all but
`model-drift` and costing under a second.
