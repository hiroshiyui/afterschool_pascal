# ADR-0384: A harness does not always run what it built

## Status

Accepted. Adds `AFTERSCHOOL_PASCAL_RUNNER`, read by `tests/run_test.py` and
`selfhost/irtest.py`, and `runner-seam` to hold it. Follows
[ADR-0383](0383-a-word-size-does-not-decide-a-layout.md), which admitted a
target the machine that builds cannot run.

## Context

Every harness here executes what it built:

```python
subprocess.run([str(work / name), str(work / 'file1'), str(work / 'file2')], ...)
```

That is right for exactly as long as what it built runs on the machine that
built it, and it has been right for every target this compiler names — until
`wasm32-wasi`. A `.wasm` is started by a runtime, with its arguments handed
over and its directories granted explicitly, and no amount of correct code
generation makes `execve` accept one.

`sanitize.py`'s valgrind mode is the precedent and says so in its own comment:
*Valgrind is a wrapper where the other three modes are a build, so the only
thing that changes here is what runs the program.* A runner is that shape
again, chosen by the operator rather than by the mode.

## Decision

**`AFTERSCHOOL_PASCAL_RUNNER` is a command, split on blanks and prepended to
the invocation of the program under test.** `APASCAL_NONPOSIX_CC` is the same
shape and for the same reason (ADR-0382): a toolchain arrives as a program on
PATH or as a program with flags, and splitting on blanks admits both in one
line.

**The sandbox flags belong to the operator's command and not to the harness.**
A WASI runtime reaches no directory it was not given, and these harnesses hand
the program two scratch paths as arguments, so a runner for that target is
spelled `wasmtime --dir=.` or whatever the runtime in question wants. Writing
that into `run_test.py` would put an opinion about one runtime into the file
every ctest case goes through; the variable holds the whole command so it can
hold the opinion instead.

**Two harnesses read it, and the toolchain is never wrapped.** `run_test.py`
is what all 497 corpus cases run through, and `irtest.py` is what runs a
program the stage-1 compiler built. That compiler is itself run by `irtest.py`
— over the corpus, to produce those programs — and it is a program for the
machine this is running on however the corpus is being emitted. Wrapping it
would hand a native binary to a runtime for another target, and the failure
would read as the compiler being broken.

**Every other harness executes what it built, deliberately.** `sanitize.py`'s
four modes, `target32.py`, `lib_coverage.py` and the rest each build a
particular *native* configuration — instrumented, 32-bit, counted — and a
program for another target is not the thing they instrumented. Setting the
variable globally and running the whole suite would make them fail to exec
rather than answer wrongly, which is the failure mode to prefer; it is a
`doc/sop.md` §7 row and not a silence.

## Consequences

**`runner-seam` is the gate, and its existence is the argument.** Nothing here
runs a wasm program yet — the runtime does not build for the target (ADR-0382)
— so the corpus gate that would exercise this seam does not exist, and a seam
with no user is plumbing. It is exercised instead by a wrapper that is not a
WASI runtime at all: it records the command it was handed and `exec`s it. What
that holds is the *shape* of the invocation, which is the half a real runtime
depends on and the half that stops being true in silence.

Four claims, and the fourth is the floor:

1. `run_test.py` starts the program through the runner, with the two scratch
   paths it always passes;
2. `irtest.py` does the same for the program it compiled;
3. neither starts any part of the toolchain through it;
4. with the variable unset, nothing reaches the wrapper — otherwise the
   evidence for the first three would be *something wrote lines to a file*.

Both mutations were run: dropping the prefix from `run_test.py` fails claim 1,
and wrapping `irtest.py`'s call to the compiler it built fails claim 3.

**It costs 11 seconds**, almost all of it `irtest.py` building a stage-1
compiler to run one case. That is the price of a behavioural claim about that
harness rather than a regex over its source, and it is worth it: what is being
checked is what the harness *does*, and a check that reads code for the string
`runner()` would pass on a call that ignores the result.

**The environment is per-harness and that was learned here.** `run_test.py`
under ctest is given `AFTERSCHOOL_PASCAL_RUNTIME` naming a *directory*, which
is what `pascalcc` wants; `irtest.py` wants an archive and works one out from
where the seed compiler is, so `selfhost-codegen` sets no environment at all.
Handing irtest the directory is how this gate failed under ctest having passed
by hand — a reminder that running a harness "the way the suite runs it" is a
claim about the environment as much as the arguments (ADR-0378).

## Alternatives rejected

**Wait for the corpus gate.** 2d in the plan needs a runtime built for the
target, and that is `pasrt_posix.c` over wasi's interfaces or a build that
ships neither `PasProcess` nor `PasNet` — real work with a decision in it. The
seam is small, is the part every harness would otherwise grow its own version
of, and can be held now.

**Discover the runner: `wasmtime` if present, else `node`.** The original
plan, and it does not survive contact: `node` cannot execute a `.wasm` as a
command at all, needing a JavaScript shim this tree would then own and ship.
A discovered runner also hides which one answered, and *which runtime* is
exactly the thing a wasm result must state. The variable says it.

**Put `--dir` in the harness for the scratch paths.** It would make one
runtime's flag a fact about `run_test.py`, and it would be wrong for the next
runtime. The two scratch paths are an argument shape the harness already has,
and `runner-seam` checks they survive the wrapper.
