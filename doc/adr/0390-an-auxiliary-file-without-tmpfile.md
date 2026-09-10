# ADR-0390: An auxiliary file, without `tmpfile`

## Status

Accepted.

## Context

ISO/IEC 10206:1991 §6.7.5.5 gives `rewrite(f)` on a file variable bound to no
external name an *auxiliary file*: scratch storage the program can write, read
back and forget. `runtime/pasrt.c` obtained one from ISO C's `tmpfile()`, at
three sites — `pas_reset`, `pas_rewrite` and `pas_extend`.

ADR-0385 built the corpus for `wasm32-wasi` and ran it under a WASI engine, and
**that one function was the largest single thing between this corpus and
WebAssembly**. wasi-libc declares `tmpfile` — with
`__attribute__((__deprecated__("tmpfile is not defined on WASI")))` — and does
not define it. So `runtime/pasrt.c` compiled, which is what
`tests/checks/nonposix_headers.txt` catalogued, and every program that reached
one of the three sites failed at the *link*:

```
wasm-ld-21: error: libpasrt.a(pasrt.o): undefined symbol: tmpfile
```

52 of 598 corpus programs, of the 79 that did not pass. The catalogue said what
a port would do about it — "a temporary file opened in a directory the module
was granted, named by the runtime rather than by the C library" — and left it
undone.

The obvious way to do it is an `#ifdef __wasi__`, and that is **not a free
move**. `runtime/pasrt.c` holds no preprocessor conditional at all, and
`runtime-isoc` compares the set of them against an *empty* catalogue in both
directions, so a conditional is a decision with a record and not a habit. One
stood for a week (ADR-0373) and ADR-0380 removed the *target* rather than keep
it. Reversing that for a second target would have been the whole cost of this
change.

## Decision

**Stop calling `tmpfile`.** `runtime/pasrt.c` gains a static `pas_tmpfile()`
that makes the same object out of two other ISO C functions, and the three call
sites name it instead. No preprocessor conditional, and one behaviour on every
target rather than one per C library.

The mechanism is two sentences of C11:

- **7.21.5.3** gives `fopen` the exclusive mode: with `x` it "fails if the file
  exists or cannot be created". So composing a name and creating nobody else's
  is a retry loop rather than a race. `pasx_temp_name` (ADR-0243) already rests
  on that sentence, and the two now share one counter — `pas_temp_tick`, seeded
  from `time(NULL)` — because two counters walking the same names would be the
  same claim written twice.
- **7.21.4.1**'s `remove`, called on the open file immediately, gives
  `tmpfile`'s own contract back: the stream stays usable and the name is gone
  before any other program can see it. Where `remove` refuses, the file is
  closed and the directory abandoned, so no candidate ever leaves something
  behind — the routine either returns an anonymous stream or nothing.

**Two fixed directories, `/tmp` then `.`, and they are fixed on purpose.**
Reading `TMPDIR` would be a fifth name this runtime hands to `getenv`, and
`wasm32` holds that set against what `tests/checks/wasi_run.py` tells the engine
to forward, in both directions — a variable that silently stops arriving is a
*wrong answer* and not a failure, which that gate learned once already from a
`SOURCE_DATE_EPOCH`. `/tmp` is glibc's own `P_tmpdir`; `.` is the fallback for a
sandbox granted the working directory and nothing else, which is somewhere
`tmpfile` could never have looked.

Measured on both platforms before it was written: under wasmedge with
`--dir /:/`, `fopen("/tmp/…", "w+bx")` succeeds, `remove` on the open file
succeeds and the stream reads back what was written to it, and a second
exclusive create of the same name is refused. Natively, the same, plus `.`.

## Consequences

**519 of 598 corpus programs became 558.** Thirty-nine of the 52 now compile,
link and answer their golden for `wasm32-wasi`.

**Thirteen of the 52 were behind a second cause and have moved rows**, which is
the part a summary number hides and the reason the catalogue is grouped by cause
rather than counted:

| Cause | Cases |
| --- | --- |
| `runtime/pasrt_posix.c` is not built for this target | 7 |
| the SjLj tag no engine here implements | 3 |
| a relative path in a module granted only `/` | 2 |
| a program binding `tmpfile` by name itself | 1 |

The last is `tests/dialect/handle_bare_call.pas`, and it draws this decision's
line exactly: the parameterless C routine it binds to exercise AP 6.7.7.6's bare
call *is* `tmpfile`. Taking the name out of the runtime cannot take it out of a
program that asks for it.

The two relative-path cases are a finding this change did not act on. A WASI
preopen is a directory and not a working directory, so `fopen("scratch.tmp",
"w")` answers NULL under this engine while the absolute path answers a stream —
probed directly, on one run. Adding `--dir .:.` does not close it, measured,
because the preopen resolves where the engine was started and a case runs
somewhere else. What would close it is a runner granting the case's own working
directory by absolute path, and that is a question about `wasi_run.py` and
ADR-0384's fixed prefix.

**What it costs.** `tmpfile` on glibc creates a file that never had a name; this
creates one and unlinks it, so between the `fopen` and the `remove` there is a
window in which a name exists. It is closed within two library calls and the
name is unguessable-ish rather than unguessable — but nothing depends on that:
the file is created exclusively, so a process that guessed the name could not
have created it first, and after the `remove` there is nothing to open. What is
genuinely lost is `tmpfile`'s guarantee across a *crash* in that window; a
program killed between the two calls leaves a `pas-aux-XXXXXXXX` in `/tmp` where
`tmpfile` would have left nothing.

It also costs a directory search that `tmpfile` did not make. An auxiliary file
is rare — no corpus program opens more than a handful — and `writestr`, which is
not rare, has not touched a file since ADR-0370 and does not now.

**What it does not do.** It does not touch `pasx_temp_name`'s contract, which
is still "the file is the caller's from here, nothing removes it": that routine
answers a *name* for `PasFs.TemporaryPath` and this one answers an anonymous
stream, and they are two different requirements that happen to share a counter.
It does not make `runtime/pasrt_posix.c` or `runtime/pasrt_task.c` compile for
wasi, which is the rest of the port. And it adds no preprocessor conditional, so
`tests/checks/nonstandard_c.txt`'s empty list is still empty and still a claim.

## Alternatives rejected

**`#ifdef __wasi__` around a replacement.** The shape the problem invites, and
the one this record exists to refuse. It would reverse ADR-0380 — which dropped
a target rather than keep a conditional — for a second target, and it would put
a *different implementation of the language* on wasi from the one every other
oracle here tests. The replacement turned out to be portable, so the conditional
would have bought nothing but the divergence.

**A fifth translation unit.** The runtime is four units, each bounded by what it
may depend on, and a split is how a dependency is confined. There is no
dependency here to confine: the replacement is ISO C, so a fifth unit would
record a boundary that does not exist and `runtime-nonposix` would gain a row
saying nothing.

**A shim linked only for wasi, by `tools/pascalcc`.** This is the conditional
again, moved into the build system where no gate reads it, and it would make the
wasm build a different program from the native one with nothing here able to see
the difference. `tools/pascalcc` also stays a shell script, so the logic would
have had to go somewhere else again.

**Keeping `tmpfile` and catalysing the 52 as unportable.** They are not: what
they use is §6.7.5.5, which is the language and not an extension, and a port
that cannot open a scratch file has given up more than a row.

## Evidence

- `tests/eoln_appended.pas` under `tests/checks/wasm32.py` — fails at the link
  with `undefined symbol: tmpfile` before the change, passes after. Thirty-eight
  more with it.
- The mutation: put `tmpfile()` back at the three sites, rebuild the runtime for
  `wasm32-wasi`, and the gate reports 39 catalogued-passing cases failing.
- `tests/dumps/`, `ctest` and `runtime-coverage` hold the native half: the same
  three sites are what every internal-file case in the corpus runs on this
  machine, so a `pas_tmpfile` that did not work would fail `tests/typedfiles.pas`
  and forty others before any of this was reached.
