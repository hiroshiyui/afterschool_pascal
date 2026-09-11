# ADR-0406: A case is run where nothing else is

## Status

Accepted. Corrects a claim [ADR-0281](0281-the-suite-was-never-slow.md) rests
on and `CLAUDE.md` states.

## Context

The suite runs at `-j12` because every harness here is parallel-safe, and
`CLAUDE.md` says what makes that true:

> What makes it safe is one property held by every harness here: **each works
> in a directory it created for the run**, and a port is asked for rather than
> assumed.

That is true of the harness's own scratch files — `tests/run_test.py` and
`selfhost/irtest.py` each `mkdtemp` and compile into it — and it was **false
of the program under test**, which was started with no `cwd` at all and so ran
in whatever directory the harness had been invoked from. Every case in the
corpus shared one.

For almost every case that costs nothing, because a case's two scratch paths
are handed to it as absolute arguments. `tests/dialect/lib_process_execute.pas`
is the one that names a file relatively — it has to, being about starting a
child and what a child can see — and its own closing comment had noticed
half of it:

> What this program made, it takes away: `irtest.sh` runs every case in the
> checkout, and a case that leaves a file behind is a case that dirties the
> tree it is measuring.

The cleanup keeps the tree clean and is also the race. Two copies of this
program in one directory — the ctest case and the same source swept by
`selfhost-codegen`, which run concurrently — and one `rm -f victim.txt` while
the other is at

```
runtime error: cannot open for reading: victim.txt
  at tests/dialect/lib_process_execute.pas:259:3
```

It appeared on CI three times in two pushes, on three different jobs, and was
invisible here because this machine is faster and loses the race less often.

## Decision

**The program under test is run in the harness's own working directory**, not
the invoker's: `cwd=work` on the one `subprocess.run` in each of
`tests/run_test.py` and `selfhost/irtest.py` that starts a compiled program.

Those two harnesses and no others, which is the same boundary
`AFTERSCHOOL_PASCAL_RUNNER` has (ADR-0384) and for the same reason: they are
the two that start *the thing under test*, and everything else here starts a
**toolchain**, which is a program for the machine it runs on and belongs where
it was invoked.

The claim in `CLAUDE.md` becomes true rather than nearly true, which is the
point. A parallel suite resting on "each works in a directory it created" had
one program that did not, and the sentence was the reason nobody looked.

## What holds it

A race cannot be held by a case, so what is recorded is a **reproduction**:
two copies of `lib_process_execute` started at once from one directory, ten
times over.

| | failures |
| --- | --- |
| without the change | **8 of 20** |
| with it | **0 of 20** |

That is the named case that fails without the change, and it is the strongest
form available for a defect whose shape is *sometimes*.

## What this does not do

It does not make a case's relative paths portable to a target whose runtime
grants preopened directories rather than a working directory. `wasm32.py`
hands a WASI runtime its own `--dir` and that is where a relative path is
decided there (ADR-0385); this changes what a native program sees.

It does not remove the cleanup from `lib_process_execute.pas`. It no longer
keeps the checkout clean, but it is still the sweep that makes the case's
own claim about what a child leaves behind, and the comment now says which
of the two jobs it is doing.

It does not audit the corpus for other cases naming a file relatively. The
change makes that class safe rather than finding its members, which is the
right direction: a case added tomorrow that names a file relatively is now
correct by construction instead of by review.
