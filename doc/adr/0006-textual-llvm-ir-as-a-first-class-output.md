# 6. Textual LLVM IR is a first-class output

Date: 2026-08-09

## Status

Accepted

## Context

ADR-0003 has stage 0 building an LLVM `Module` in memory through the C++ API.
ADR-0004 says the compiler is eventually written in Pascal.

Those do not compose. A Pascal program cannot link a C++ API: no templates, no
`IRBuilder`, no name mangling to bind against. The backend that stage 0 uses is
unavailable to its successor, so the port would arrive at a compiler with a
complete front end and no way to emit code.

The options for the Pascal-hosted backend:

* **Emit textual `.ll`** and hand it to `llc` or `clang`. Needs nothing beyond
  writing characters to a file — which the compiler must be able to do anyway.
* **Bind the LLVM-C API** via `external` declarations. Workable, since the C API
  is stable and callable, but needs pointer types, opaque handles, and a
  C-calling-convention story before any of it can be tested.
* **Emit assembly directly**, abandoning LLVM for stage 1. Discards the
  optimiser and the retargeting.

## Decision

Textual IR is a supported output, not a debugging convenience: `--emit-llvm`
(equivalently `-S`) prints the module and stops, and it is exercised regularly
rather than left to rot.

The Pascal-hosted compiler will emit textual `.ll` and invoke `llc`/`clang`.
Binding LLVM-C from Pascal stays possible but is off the critical path.

## Consequences

The port has a backend that is reachable with only file output, so stage 1 does
not need pointers-to-foreign-functions working before it can produce a program.
It also gives the differential test named in ADR-0004: both compilers emit IR
text for the same input, and the texts can be compared.

The cost is a slower stage-1 compiler — IR is serialised, reparsed, and
re-verified — and a dependency on `llc`/`clang` at run time. Neither matters for
a compiler whose job is to compile itself once per change.

There is a subtler cost: textual IR is a wider interface than the in-memory one,
so anything expressible only through C++ API calls with no textual spelling is
off limits. In practice IR is fully round-trippable, so this has not bitten.
