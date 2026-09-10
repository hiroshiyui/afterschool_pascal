# ADR-0383: wasm32 is admitted, and a word size does not decide a layout

## Status

Accepted. Admits `wasm32-wasi` as this compiler's sixth `--target=`, splits
`WideAlign` out of `WordAlign`, and re-classes `target-layout`'s first claim.
Follows [ADR-0325](0325-a-pointer-is-not-always-eight-bytes.md), whose generalisation is
what made this cheap, and [ADR-0382](0382-the-non-posix-target-is-wasm.md),
which measured the runtime's distance from the same target. Corrects that
record's headline finding.

## Context

ADR-0382 pointed `runtime-nonposix` at `wasm32-wasi` and left the compiler
alone: the gate asks what a *port* would cost and nothing was emitting for the
target. Admitting the triple is the other half, and it is the step this
project has taken five times — a constant, an arm in `TargetIndex`, an arm in
`TargetName`, a datalayout arm, and whatever `PtrSize`, `WordAlign` and
`CLongSize` have to say about it.

Two of the gates enrol a target by reading the compiler's own `--target=`
refusal (ADR-0144), so admitting one is also the act of *submitting* it to
them. That is the design working: what follows was found by those gates on the
first run and by nothing else.

## Decision

**`wasm32-wasi` is admitted, on the same terms as every other target**: the
compiler lays it out correctly and states its layout, and clang assembles what
it emits. Three spellings are read — `wasm32-wasi`, clang's normalised
`wasm32-unknown-wasi`, and `wasm32-wasip1` — for the reason the aarch64 and
i386 pairs have two: they name one thing and a person types whichever their
toolchain does. The datalayout is clang's own line for the target, taken from
`clang --target=wasm32-wasi -x c /dev/null -S -emit-llvm` and not edited; the
module states `wasm32-unknown-wasi`, which is what clang normalises to and so
raises no `-Woverride-module`.

**What admitting a target means here is what it has always meant** — that the
arithmetic is right, which `target-layout` decides. It does *not* mean a
program links: the runtime does not build for this target yet, and ADR-0382's
catalogue says exactly how far away that is.

### `WideAlign`, and why one number was two

`WordAlign` answered two questions from ADR-0325 until now: what a pointer
aligns to, and what an *eight-byte datum* aligns to. i386 answers 4 to both,
and it was the only ILP32 target here, so nothing could tell that two
questions were being asked. wasm32 is ILP32 with `i64:64` — a pointer aligns
to 4 and an i64 to 8 — and the conflation became four wrong numbers the
moment the target was admitted.

`target-layout`'s claim 2 reported them on the first run, before any of this
was understood:

```
wasm32-wasi: wi64 size -- the compiler says 12, LLVM lays it out as 16
wasm32-wasi: wi64 alignment -- the compiler says 4, LLVM puts the field at 8
wasm32-wasi: wreal size -- the compiler says 12, LLVM lays it out as 16
wasm32-wasi: wreal alignment -- the compiler says 4, LLVM puts the field at 8
```

That is ADR-0325's second claim — *the compiler's own arithmetic against
LLVM's, per target* — doing precisely what it was built for. A wrong alignment
costs no diagnostic anywhere; without that claim this would have been a
correctly-refused target or a silently mislaid frame.

So `LlAlign`'s five-type arm becomes two: `tyPointer` follows `WordAlign`, and
`tyInt64`, `tyReal`, `tyFile` and `tyHandle` follow `WideAlign`. A file and a
handle are arrays of i64, which is why they go with the datum and not with the
pointer.

### `target-layout` classes by arithmetic, not by word size

Claim 1 was *targets of the same word size lay a frame out identically*, with
the class keyed on the pointer size. With `WideAlign` correct, that claim put
i386 and wasm32 in one class and reported **337 offsets as a divergence**,
every one of them right for its own target — claim 2 had just said so.

The class is now the compiler's whole answer for the six probe shapes. What
claim 1 says is then exact: *targets whose layout arithmetic is identical must
lay every frame out identically*. It is derived on each run, so a seventh
number coming to vary splits the classes without the gate being edited — the
same property that makes the target list the compiler's own refusal. i386 and
wasm32 are each alone now, and the run says so rather than hiding it.

## Consequences

**The correction to ADR-0382, and it is the important one.** That record's
headline was that `runtime/pasrt.c` is blocked on `_longjmp` on *both*
non-POSIX targets ever measured, which made the non-local goto look like this
runtime's one real portability question. It is not. wasi-libc **declares**
`_setjmp` and `_longjmp`; the header puts them behind `_XOPEN_SOURCE ||
_GNU_SOURCE || _BSD_SOURCE`, all three of which `__STRICT_ANSI__` turns off —
and `runtime-nonposix` compiled with `-std=c11` while CMake builds every one
of these units with `-std=gnu11`, `CMAKE_C_STANDARD 11` leaving
`C_EXTENSIONS` on. The gate asked a question no build here asks and reported
the answer as a fact about the runtime.

`pasrt.c` compiles for `wasm32-wasi`. The gate now compiles as the tree does,
and the catalogue records it. Two details are worth keeping: `-D_POSIX_C_SOURCE`
alone does *not* unblock it, `_longjmp` being XSI rather than base POSIX; and
mingw-w64 genuinely had neither name, which is why one true measurement looked
like confirmation of a false one. **Two measurements agreeing is not two
measurements** when the same instrument is misconfigured for both.

This was found while admitting the target — `setjmp-arity` could not reach
wasi's headers without the sysroot flags, and asking why led to the header
that declares the very name the other gate called missing.

**What compiles today**: `pasrt.c` and `pasrt_unicode.c`. `pasrt_posix.c`
wants five of the seventeen headers it names, and `pasrt_task.c` is blocked
because the target has no threads. Neither is a name this source uses wrongly.

**`setjmp-arity` gained per-target flags.** wasm32 is the first target here
whose headers are not where clang looks by default, and the first whose
`<setjmp.h>` refuses without a build flag. Without them it reported *no
headers here* and was silently not compared, which is a gate passing by asking
nothing. With them: wasi declares `setjmp` as a function and `_setjmp` beside
it, like Darwin and unlike glibc, and the arity is 1, which is what this
compiler emits.

**Not every target is POSIX any more**, and one sentence in `CLAUDE.md` rested
on that: the `_setjmp` call is one shape *because every target agrees*, and
ADR-0380 had made "every admitted target is POSIX" the reason. The shape is
still one, and what holds it is what it always was — `setjmp-arity` comparing
each target against its own header.

**`target-sizes`, `target32` and the runtime build are untouched.** This
target has no runtime here, so nothing links for it; what is new is that the
compiler emits a module clang assembles into a `.wasm` object, which is the
front half of a toolchain and is measured as that and not as a port.

## Alternatives rejected

**Class `target-layout` by hand — put wasm32 in a class of its own.** It would
work today and be a second opinion about the compiler's arithmetic, kept in a
gate, free to drift from it. Deriving the class from the probe costs three
lines and cannot drift.

**Keep `WordAlign` and special-case wasm32 in `LlAlign`.** Same numbers, and
the conflation stays: the next ILP32 target with an eight-aligned i64 would be
a second special case rather than a second member of a class. The two
questions are different questions, and i386 answering the same to both is a
coincidence of one ABI.

**Leave `-std=c11` in `runtime-nonposix` and catalogue `pasrt.c` as wanting a
macro** — the `crt` row's shape, which exists for exactly this. It would be a
true row about a configuration this tree does not build with, and it would
keep a gate asking a stricter question than any port faces. Whether the source
is ISO C is `runtime-isoc`'s question and it asks it properly, by stripping
the non-ISO includes rather than by hiding the target's declarations.

**Wait for the runtime to build before admitting the target.** It inverts the
order this project has used five times: the compiler is what admits a target,
the gates are what judge the admission, and a port is measured afterwards
against a compiler that can emit for it. Waiting would also mean the alignment
defect above stayed invisible until somebody was debugging a wasm binary.
