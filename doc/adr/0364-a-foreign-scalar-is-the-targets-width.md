# ADR-0364: A foreign scalar is the target's width

Date: 2026-09-07

## Status

Accepted. Rebinds nine foreign scalars in `PasIO`, `PasProcess` and `PasTls`
from `int64` to `clong` or `csize`; makes the emitter write a slice's count at
the target's pointer width (`selfhost/compiler.pas`, two sites); adds the
`foreign-width` gate and its catalogue `tests/checks/foreign_int64.txt`. Adds
nothing to the language.

## Context

The project-wide security audit run after ADR-0363 applied one lens to every
`external` declaration in the tree: **what is the C type's width on i386?**
The lens came from that morning. `PasProcess` bound `time` as answering
`int64`; `time_t` is a `long`, 32 bits on i386, and the value came back with
whatever the spare register held — `7682741216296735854` on CI's container.
Fixing it was one word. What could not be fixed was the *oracle*: on the
machine that wrote the fix the register happened to be clean, the wrong
binding gave the right answer, `target32` was green with the defect in it,
and the mutation putting `int64` back **survived**. A width defect at the
boundary has no behavioural test on any one host.

The audit found the same shape nine more times, none provable and every one
wrong by the ABI: `read` and `write` answer `ssize_t` (`PasIO`); `fflush`
takes a `FILE *` (`PasProcess`); and in `PasTls`, `SSL_get_verify_result`,
`ERR_get_error` and both `*_ctrl` routines' `larg` are `long`, while
`TLS_client_method`, `SSL_CTX_new`'s method and `SSL_CTX_set_verify`'s
callback are pointers. All were `int64`. TLS cannot be built for i386 on CI
at all, so not even the container could have seen those six.

And one in the **compiler**. A slice crosses a foreign call as an address and
a count (ADR-0129), and the emitter widened the count to `i64` on every
target — `call i32 @readlink(ptr, ptr, i64 …)` for i386, where `size_t` is
`i32`. It worked there by cdecl's grace: the callee reads the low word and
steps over the four bytes above it. The comment beside the code said the
count "is a `size_t`"; the code did not ask which target's.

## Decision

**A foreign scalar's Pascal type is the target's width, said with `clong` or
`csize`; `int64` in an `external` is a claim that the C type is 64 bits
everywhere, and the claim is catalogued.** Three parts.

1. **The nine bindings** become `clong` where the C type is `long` and
   `csize` where it is `size_t`, `ssize_t` or a pointer (AP 6.4.2.7 makes
   both the target's width). `Seconds` and the results a caller sees keep
   their `int64` type: the width a caller wants to compute in is not the
   width the boundary has.
2. **The emitter asks `PtrSize`** at both places it writes a slice's count —
   the argument (`compiler.pas`, `EmitForeignArgument`) and the declaration —
   exactly as Sema asks it to choose `csize`'s type. On LP64 nothing changes;
   on i386 the count is the `i32` it already was and is no longer widened.
3. **`foreign-width` holds both halves**, in both directions. The catalogue
   half parses every heading ending in `external` under `lib/` and `lsp/`
   (multi-line, bounded by shape rather than by `;`, because a heading's
   parameter list holds `;` itself) and requires each that names `int64` to
   have a row saying which C type is 64 bits everywhere — `ExtFileInfo`'s
   `long long *` out-parameters are the one such row — and each row to still
   name a binding. The emitter half compiles a probe for every admitted
   target and reads the declaration back: `ptr, i64` on the two LP64 targets,
   `ptr, i32` on i386. A floor of 60 declarations keeps it from passing by
   sweeping nothing.

## Consequences

**The gate is the test, and it is deterministic where the corpus is a coin.**
The mutation that survived under ADR-0363 — `time` back to `int64` — is
killed by the catalogue half on every host; the emitter half kills `ptr, i64`
put back unconditionally. Both are catalogued under this record.

**`integer` is not asked about**, C `int` being 32 bits on every target the
compiler admits, and neither are `clong` and `csize`, which are the answer.
The gate reads no C: it cannot tell a `long long` from a `long` and does not
try. What it requires is that a person wrote the C type down beside the
claim, which is what turned ADR-0185's foreign layouts from a hope into a
comparison.

**The runtime-declared `long long` stays `int64`.** `pasx_file_info` chose 64
bits so that a file over 4 GB and a date past 2038 are one answer on every
target; the catalogue row says so.

## Alternatives rejected

- **A gate that reads the C prototypes** — from the system headers, through a
  C compiler, per target. It would answer the question the catalogue asks a
  person to answer, and it is the right gate eventually; it is a project of
  its own (each binding's header, each target's sysroot) and the catalogue
  closes the hole today.
- **Widen the count on i386 and rely on cdecl.** It is what the code did, it
  passed every gate, and it is wrong by the ABI; an aarch64 ILP32 target, if
  one were admitted, would read the count from the wrong register.
- **A behavioural case per binding.** Each would be the surviving mutation
  again, on any host with a clean register.

## What this does not do

- **It does not audit `runtime/*.c`'s own prototypes**; `runtime-isoc` and
  `foreign-layout` hold those.
- **It does not make `int64` in an `external` an error.** `long long` is a
  real C type and `ExtFileInfo` is a real binding of one.
