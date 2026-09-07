# ADR-0362: A command is words, not a line

Date: 2026-09-07

## Status

Accepted. Adds `PasProcess.Execute` and four routines beside it, and
`pasx_argv_*` / `pasx_exec_*` to `runtime/pasrt_posix.c` over three new
catalogued headers. Converts `lsp/pasls.pas` to it, closing a command
injection reachable over LSP and over MCP. Adds the `command-injection` gate.
Adds nothing to the language.

## Context

`PasProcess` has had one way to run a program since ADR-0120: `Run`, `Capture`
and `CaptureLines`, all three built on `system` and `popen`, both of which take
a **command line** — one string, which a shell then reads.

That is the right interface for a command a program wrote out, and the wrong
one for a command assembled out of values, because in a shell's hands every
value is syntax. `lsp/pasls.pas` assembled exactly such a command and had done
since ADR-0236:

```pascal
cmd := compilerCmd + flags + imports + ' ''' + source + ''' -o '''
       + scratchPath + '.ll''';
```

The apostrophes are the defence, and an apostrophe in `source` walks through
them. `source` is `PathArg`'s answer — `params.arguments.path` under MCP, the
document URI under LSP — so it is supplied by an editor, or by whatever is
driving the model.

**It was proved, not reasoned about.** `tests/hello.pas` copied to a file named

```
a'; touch PWNED; echo '.pas
```

and asked of the running server as `tools/call` `diagnostics`:

```
exit=0
PWNED                          ← created
a'; touch PWNED; echo '.pas
```

`ImportsFor`'s `--import` words, read out of a `.components` sidecar, reach the
same string by the same road, so a build description could carry the payload
instead of a file name.

**`tools/pascalcc` was never exposed**: it is bash and uses arrays throughout,
which is the same distinction this record is about, one language over.

## Decision

**Add an interface that carries words as words, and convert the one caller in
this tree that assembles a command out of values.**

```pascal
ArgV = handle external 'pasx_argv_free';

function NewArgs(var v: ArgV): ErrorCode;
function AddArg(var v: ArgV; arg: string): ErrorCode;
function ArgsLen(protected var v: ArgV): integer;
function DropArgs(var v: ArgV; keep: integer): integer;

function Execute(protected var v: ArgV): RunResult;
function ExecuteInto(protected var v: ArgV; var into: string): RunResult;
function ExecuteBoth(protected var v: ArgV; var into: string): RunResult;
function ExecuteLines(protected var v: ArgV; var lines: StrVecPtr): RunResult;
function ExecuteToFile(protected var v: ArgV; path: string): RunResult;
```

Seven decisions inside that.

1. **The vector is built on the far side and is a handle.** argv is a
   `char *[]` — an array of pointers, which AP 6.7.7.6.2's boundary has no way
   to spell. So a caller pushes one string at a time and no pointer ever
   crosses. It is a handle (AP 6.4.12) for ADR-0151's reason: what would cross
   otherwise is memory a program could copy and free twice.

2. **`AddArg` takes a schematic `string` and not `StrItem`.** Probed rather
   than assumed: an `external` does take a value parameter of any capacity, so
   an argument is not bounded at `StrVec`'s 255 — which matters, ADR-0291
   having established that a path may be longer than a name.

3. **`posix_spawn`, not `fork` + `execvp`.** This language has two threads of
   control (AP 6.9.3.12), and a `fork` in a process with more than one leaves
   the child able to call only what is async-signal-safe. `posix_spawnp` is
   the PATH-searching form, which is what a driver needs.

4. **`Run` stays.** `system` is the right interface for a pipeline, a
   redirection, or a line a person wrote, and removing it would leave
   `PasDir`'s documented `CaptureLines('ls -1 dir', names)` unspellable. The
   rule is in the module: prefer `Execute` wherever any part of the command
   came from outside the program.

5. **Five entry points, because the streams are the caller's question and no
   caller can write `2>&1` any more.** `ExecuteInto` leaves standard error
   alone, as `Capture` does; `ExecuteBoth`, `ExecuteLines` and `ExecuteToFile`
   join it to standard output, because each answers a question — what did this
   command *report* — whose answer is on both.

6. **`DropArgs` exists because a builder speculates.** `pasls` walks a
   workspace trying `.components` sidecars and all but one are the wrong one.
   `ArgsLen` is the mark and `DropArgs` the reset. `take` was probed and does
   move a handle, but a move replaces where an append was wanted.

7. **The empty vector is guarded on both sides and that is not duplication.**
   AP 6.4.12.3 makes lending an empty handle to a foreign routine a run-time
   error, so the Pascal guard is what stands between a released vector and a
   stopped program. The compiler said so when the guard was removed.

**`PASLS_COMPILER` is split on blanks and nothing else.** It could always hold
a program with flags after it, a shell having split it, and `lsp/run.sh` sets
it to `env -u PASHEAP_BALANCE <pascalc>` — three words. It is this program's
own configuration and not a caller's, and blank-splitting is the whole of what
the shell did to it that anyone relied on.

## Consequences

**The porting surface grows by three headers**, all catalogued with their
arguments in `tests/checks/nonstandard_c.txt`: `<spawn.h>` for
`posix_spawn_file_actions_t`, `<sys/wait.h>` for `WIFEXITED`/`WEXITSTATUS`, and
`<fcntl.h>` for the open flags `ExecuteToFile` needs. Each is a *type* or a
macro over one, which is what `runtime/pasrt_posix.c` exists for (ADR-0186);
none could have been a name in `pasrt.c`'s catalogue.

**A command that is not there is now `errIO` and not an exit code of 127.** No
shell runs, so there is no shell to exit. POSIX lets a system report this
either from the call or through a child that exits 127 and the two are
distinguishable nowhere, so `lib/dialect/README.md` records it beside the other
boundary answers the rules there do not reach — not
`doc/implementation-defined.md`, which is what the *processor* decides and
holds no library answer.

**`pasls` lost its command-line length checks and gained a real bound.** The
old code refused to build a command longer than `CommandMax` and silently
dropped the tail of a long `.components`; there is no line now, so
`AddArg` answers `errFull` at 4096 words and the compiler reports what it
cannot take.

**`lsp-coverage` moved down**, 94 uncovered statements to 92: five callers lost
a cleanup branch each when `AskLines` took ownership of the vector it fills.
The ratchet fails in both directions and was regenerated.

## Alternatives rejected

**Quote the path properly** — double every apostrophe inside the single-quoted
run. Five lines, and it would have closed the hole. Rejected because it makes
the quoting of somebody else's path this program's problem for ever, which is
the thing ADR-0361 had just finished removing from the driver one directory
away; because the next value added to the command line is a new chance to
forget; and because the value is not the only reader — `--range=`, `-o` and a
dump path all pass through the same string. The `command-injection` gate is
written so that this answer fails it: it asserts the payload file still
*compiles*, which quoting satisfies, **and** that nothing ran, which is where
the argument is, so the two halves together say the shell has gone rather than
that the quoting improved.

**Rewrite `tools/pascalcc` in Pascal now that a driver could.** The blocker
named when that was investigated on 2026-09-07 was precisely this — that a
Pascal driver would have to build shell strings where the script uses arrays —
and it is gone. The decision stands anyway and for its other reason: the driver
is the one part of this toolchain the compiler cannot miscompile.

**Give `apconfig` the driver's subcommands** (the `afterschool` proposal that
raised this). Deferred, not rejected: it is a separate decision with its own
costs, and it was blocked on this one.

## What this does not do

- **It adds nothing to the language.** No word-symbol, no required identifier,
  no clause. `doc/afterschool-pascal-spec.md` is unchanged, this being a
  library and a runtime over constructs AP 6.4.12 already specifies.
- **It does not audit the rest of the tree for the same shape.** `pasls` is the
  only program here that builds a command out of a value it was handed;
  `tools/pascalcc` uses arrays, and the harnesses are shell written by this
  project. A sweep for `Run`/`Capture` callers is a `security-audit` question
  and is noted in `doc/sop.md` §7 rather than answered here.
- **It does not make `Run` unavailable or deprecated.** There is no mechanism
  here for deprecating an export and no case for inventing one: a shell is the
  right answer to a pipeline.
- **`ExecuteInto` still cannot separate the two streams into two values.** A
  caller wanting standard error apart from standard output has no way to ask;
  it needs a second pipe and a reader that does not deadlock on either, and no
  caller here wants it.
