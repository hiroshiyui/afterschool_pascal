# ADR-0385: A Pascal program runs as WebAssembly

## Status

Accepted. Adds `wasm32` — the corpus built for `wasm32-wasi` and run under a
WASI runtime — with `tests/checks/wasm32_known.txt`; gives the emitted module
wasi's entry point; and teaches `tools/pascalcc` three things about the
target. Follows [ADR-0383](0383-a-word-size-does-not-decide-a-layout.md),
which admitted the triple, and
[ADR-0384](0384-a-harness-does-not-always-run-what-it-built.md), which built
the seam this drives.

**The engine below is `wasmedge` and this record says `wazero`.** That is the
one thing here CI corrected within the hour: `wazero` is in Debian *testing*
and the job holding the wasi sysroot runs on trixie, so it could not be
installed beside the thing it was measuring. See *The engine had to be one the
image has* at the end.

## Context

ADR-0383 admitted `wasm32-wasi` on the terms every target here is admitted
on: the compiler lays it out correctly and clang assembles what it emits. That
is the front half of a toolchain and it says nothing about whether a program
*works* — which is ADR-0325's whole lesson, one target further on. Both
defects the i386 port found were in neither a layout rule nor a frame, and
that port passed every arithmetic check with `select` segfaulting.

`runtime-nonposix` (ADR-0382) says how far the runtime is from this target;
`target-layout` says the arithmetic is right; `setjmp-arity` says the one
foreign call agrees with the target's header. None of them runs anything.

## Decision

**Build the corpus for `wasm32-wasi`, link it against the runtime units that
compile for the target, run each program under a WASI runtime, and compare
against the same golden every other harness compares against.** It is
`target32`'s shape: the same corpus, a runtime built for the target, and
`tests/run_test.py` doing the per-case work — with `AFTERSCHOOL_PASCAL_RUNNER`
prepending the runtime, which is what ADR-0384 exists for.

**The runtime is partial, and that is the measurement rather than a
shortcut.** The gate reads `nonposix_headers.txt` and builds exactly the units
that catalogue says compile — two of four today. So what a program can reach
is what a port has actually got, and a program wanting more fails at the
*link*, with the symbol named. One fact in one place: a unit that starts or
stops compiling moves both gates together.

**`wazero` is the runtime.** Debian packages it, it is one binary with no
runtime dependencies, and `APASCAL_WASM_RUNNER` names another. Neither of its
flags is decoration: `-mount=/:/` because a WASI program reaches no directory
it was not given and every case is handed two scratch paths, and
`-env-inherit` because it is handed no environment either.

### What the emitted module had to change: the entry point

**On wasi the program's entry is `__main_argc_argv`, not `main`** — clang
*renames* a C `main` when compiling for this target. A module defining `main`
literally is the one case wasm-ld does not complain about and does not
resolve: it leaves an undefined weak symbol, the link succeeds, and the
program traps on `unreachable` the instant it starts. That is exactly how it
was found.

So the name is keyed on `targetIx`, which is the second time a target has
needed a name of its own in the emitted module after Win64's `_setjmp` arm
(ADR-0371, gone with ADR-0380). `__main_` is reserved as a foreign-name
prefix, on **every** target rather than on the one that writes it: a name is
refused because this compiler *may* emit it, and keying the refusal on
`--target=` would make a program compile for one target and collide on
another. ISO C 7.1.3 reserves every identifier beginning with two underscores
to the implementation, and nothing under `lib/` or `lsp/` binds one, so the
prefix costs a program nothing it was entitled to.

### What the driver had to learn: three flags, none of them a default

- **`-mllvm -wasm-enable-sjlj`.** The emitted module calls `@_setjmp` on every
  target — the non-local goto is a language feature here (§6.8.1) — and on
  wasm that call needs LLVM's SjLj lowering or the module does not compile.
- **`-lsetjmp`, and `-pthread` off.** That lowering calls `__wasm_setjmp`,
  which lives in wasi's own `libsetjmp.a` and is not linked by default; and
  asking for threads on a target that has none is
  `--shared-memory is disallowed by pasrt.o`, a link error naming an object
  the caller did not write.
- **`-Wl,-z,stack-size=1048576`.** wasm-ld gives a module **64 KB** of stack
  where the machines this language is otherwise compiled for give a thread 8
  MB, and that is not enough for programs this corpus already contains. The
  argument is `-march=pentium4`'s (ADR-0346): a target-specific number the
  driver owns so that no program has to.

## Consequences

**519 of 598 corpus programs compile for WebAssembly, link, and answer their
golden.** That is the headline and it was not the expected one — the runtime
is two translation units short of a port.

The 79 that do not are one of six causes, and the file groups them with what a
port would do about each:

| Cause | Cases | What it is |
| --- | --- | --- |
| `tmpfile` | 52 | wasi-libc declares it and does not define it |
| channels and tasks | 14 | `pasrt_task.c` does not compile: no threads |
| processes, sockets, directories, the terminal | 9 | `pasrt_posix.c` does not compile: five headers |
| a foreign name wasi has not got | 2 | an undefined weak symbol, so it traps rather than failing to link |
| the non-local goto | 1 | **wazero** has no exception-handling proposal |
| a 2 GB allocation | 1 | `target32_known.txt`'s row, for its reason |

**`tmpfile` is the single largest thing between this corpus and WebAssembly,
and it is one function.** It is §6.7.5.5's auxiliary file — `rewrite(f)` on a
file bound to no name — and a port closes all 52 rows with one routine that
opens a temporary file in a directory the module was granted. Nothing in the
language or the emitter is involved. `runtime-nonposix` had recorded the
deprecation warning; this is where a warning became 52 link errors, which is
the difference between a gate that compiles and one that runs.

**Two defects were behavioural, and no other oracle here could have seen
either.**

- **64 KB of stack.** `tests/dialect/lib_regex.pas` overran it and printed
  seven hundred stray spaces into the middle of a line — a *wrong answer* that
  reads exactly like a code-generation defect. It is fixed in the driver.
- **A lost `SOURCE_DATE_EPOCH`.** A WASI runtime passes no environment unless
  told to, so the case with a `.epoch` sidecar printed today's date instead of
  2001 — again a wrong answer rather than a failure to start. It is fixed in
  the runner command, and the lesson is that a runner's flags are part of what
  a result means.

**One row is about the engine and not about this compiler**, and the summary
line names the runner so it can be told apart: a `goto` out of a procedure
lowers through SjLj into a wasm *tag*, and wazero answers `tag section not
supported as feature "exception-handling" is disabled`. A runtime implementing
the proposal runs it.

**The `non-posix` job became the WebAssembly job.** Both questions need one
toolchain and it is the only image with a wasi sysroot; asking *how far is the
runtime* and *does a program behave* on two machines would be two answers
about two machines, which is the mistake ADR-0382's catalogue header already
records being made once.

## Alternatives rejected

**Wait for a full runtime.** `pasrt_posix.c` over wasi's interfaces is real
work with a decision in it, and waiting would have meant no measurement at
all — while 519 programs already work. ADR-0369's rule is that a port is
measured or it is an estimate, and the catalogue is now a port's work queue
with the cost of each row attached.

**Catalogue a reason per row and check it.** The rows would then claim
something the gate cannot verify without reading diagnostic text, which is
what `runtime-nonposix` refuses to do and for the same reason: a compiler's
words are its version and the operator's locale. The causes are prose over
groups, where a reader meets them and no check depends on them.

**A `--write` mode that rewrites the catalogue.** It existed for one hour and
was removed: the file's value is the paragraph over each group saying what a
port would do, and a mode that regenerates the file throws that away to save a
copy and paste. It prints the rows now.

**Ship a JavaScript shim so `node` can be the runtime.** ADR-0384 rejected
this for the seam and it is worse here: the tree would own a fourth language
to run a test. `wazero` is one apt line.

## The engine had to be one the image has

`wazero` took the measurement above and the job could not install it: it is in
Debian testing and the wasi sysroot is pinned to trixie, which is where
`runtime-nonposix` and this gate must both run — one question, one toolchain,
one image, which is the lesson `nonposix_headers.txt`'s own header records
being learned the expensive way.

`wasmedge` is in trixie and answers **519 of 598**, the same programs to the
case. What differed was two, and the difference was not the engine's
WebAssembly: `wazero` has `-env-inherit` and `wasmedge` takes `--env NAME=VALUE`
per variable, so the case with a `.epoch` sidecar printed today's date rather
than 2001 under it.

**A fixed runner prefix cannot pass an environment it never saw**, and that is
the structural point. `AFTERSCHOOL_PASCAL_RUNNER` is set once for the sweep
(ADR-0384); the environment that matters is the one `tests/run_test.py` built
for *this case*. So `tests/checks/wasi_run.py` sits between them: it forwards
the variables the program may read and `exec`s the engine.

**The list of them is a claim rather than a guess.** It is every name
`runtime/*.c` passes to `getenv` — `PASCOV_BRANCHES`, `PASCOV_LINES`,
`PASHEAP_BALANCE` and `SOURCE_DATE_EPOCH` — and the gate compares the two sets
in both directions. A fifth added to the runtime without the adapter is a
variable that silently stops arriving on this target, which shows up as a
*wrong answer* and not a failure; that already happened once, and the check is
what stops it happening quietly.

The row about the non-local goto is unchanged and is still the engine's:
neither implements the exception-handling proposal that SjLj lowers into.
