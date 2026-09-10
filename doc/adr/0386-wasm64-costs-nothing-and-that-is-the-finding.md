# ADR-0386: wasm64 costs nothing, and that is the finding

## Status

Accepted. Admits `wasm64-wasi` as the seventh `--target=`. Follows
[ADR-0383](0383-a-word-size-does-not-decide-a-layout.md), which admitted
wasm32 and split `WideAlign` out of `WordAlign`, and
[ADR-0325](0325-a-pointer-is-not-always-eight-bytes.md), whose generalisation
is what this spends.

## Context

WebAssembly's **memory64** proposal gives a module a 64-bit address space, and
clang has had the target for several releases: `wasm64-unknown-wasi` answers
with a datalayout and assembles. The dialect's own goal is a hobby project
aiming at WebAssembly as a first-tier target, and a 32-bit address space is
the constraint a wasm program hits first — `tests/index_span.pas` is already
catalogued as failing on wasm32 for exactly that, as it is on i386.

## Decision

**`wasm64-wasi` is admitted on the layout claim alone**, which is the position
wasm32 was in before ADR-0385: the compiler lays the target out correctly and
clang assembles what it emits. Four spellings are read, as wasm32's are; the
datalayout is clang's own line, which is wasm32's with a 64-bit pointer and
nothing else changed; and the entry point is `__main_argc_argv`, wasi's, the
condition becoming a set of two targets rather than an equality.

**What it does not claim is that anything runs.** Debian ships no wasm64
sysroot — memory64 is a proposal engines gate behind a flag — so
`runtime-nonposix`, `setjmp-arity` and `wasm32` all abstain for it and say so
in their own words. Nothing here pretends otherwise, and a reader who asks
those gates gets *not compared* with a reason rather than silence.

## Consequences

**It cost nothing in `aptypes.pas`, and that is the whole of what is worth
saying.** wasm64 is LP64 — an eight-byte pointer, an eight-byte C `long`, an
eight-byte datum aligned to eight — so `PtrSize`, `WordAlign`, `CLongSize` and
`WideAlign` all answer it with the arm they already had. Three targets have
now been admitted since the layout rules stopped being constants: the first
(i386) made those functions target-dependent, the second (wasm32) split
`WideAlign` out of `WordAlign`, and the third needed neither. That is what a
generalisation is supposed to do, and it is measurable rather than asserted —
the diff is a constant, a count, four spellings, a name and a datalayout.

**`target-layout` gave it the strongest welcome any target here has had.** It
lands in a class with `x86_64-pc-linux-gnu`, `aarch64-linux-gnu` and both
Darwin triples, and **all 11 162 frame offsets are identical to theirs** — a
much stronger statement than wasm32 gets, which lays out like no other
admitted target and is held by claim 2 alone. Nothing was edited in that gate
to make this happen: the target list is the compiler's own refusal and the
class is derived from the probe, which is ADR-0383's classing doing what it
was rewritten for.

**Three gates abstain and each says which.** `setjmp-arity` reports *clang has
no headers for it here*; `runtime-nonposix` measures one target and it is
wasm32; `wasm32` is named for its target and does not enrol a seventh. A
sysroot arriving later turns all three from abstention into measurement
without any of them being edited.

**`tests/dumps/target_wasm64.dump` is the golden**, and the three layout dumps
now read as the dialect's whole word-size story: `wi64` is 16 bytes on wasm64
and on wasm32 and 12 on i386; `wptr` is 16 here and 8 on both 32-bit targets;
nothing else moves.

## Alternatives rejected

**Wait for a sysroot.** It would leave the compiler unable to emit for a
target clang has had for years, and the layout claim is the one that catches
the defect that costs most — a wrong alignment has no diagnostic anywhere.
ADR-0383's own admission found four wrong numbers on its first run, and it
found them because the target was admitted rather than deferred.

**Admit `wasm64-unknown-unknown` as well.** It is a different project: no
libc, so only `pasrt_unicode.c` survives, and ADR-0382 already put it out of
scope. The triple is not read, and a program naming it gets the refusal that
names the seven.

**Fold wasm32 and wasm64 into one `tgtWasm`.** They differ in the one field
that decides every layout question here, so the arm would need the width
anyway — and `TargetName` would have nothing to answer with.
