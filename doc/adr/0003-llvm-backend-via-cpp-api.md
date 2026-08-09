# 3. Compile through LLVM, driven by the C++ API

Date: 2026-08-09

## Status

Accepted

## Context

The compiler needs a code generator. Writing one directly for x86-64 means
owning instruction selection, register allocation, and object file emission
before the first program runs — months of work orthogonal to Pascal.

LLVM 21 development files are installed on the development machine, so the C++
API, the optimisation pipelines, and object emission are all available without
building anything.

Three ways to reach LLVM: link the C++ API, link the C API, or emit textual IR
and shell out to `llc`.

## Decision

Stage 0 links the LLVM C++ API and builds a `Module` with `IRBuilder`, then runs
the new pass manager and emits an object file through `TargetMachine`.

`llvm_map_components_to_libnames(core support irreader passes native)` keeps the
link line to what is used; `find_package(LLVM CONFIG)` handles the rest.

## Consequences

Optimisation and target support are inherited rather than written: `-O0` through
`-O3` work, and retargeting is a triple away. IR is verified by `verifyModule`
before anything is emitted, so codegen bugs surface as a compiler failure rather
than a miscompiled program.

The build now requires matching LLVM development files, and the API is not
stable across major versions — `Intrinsic::getOrInsertDeclaration` and the
`Triple`-taking `createTargetMachine` are both recent renames. Version bumps
will need small edits.

Debian's LLVM is built without RTTI, which is one of the two reasons behind
ADR-0005.

This decision covers stage 0 only. The Pascal-hosted compiler cannot link a C++
API at all, which is ADR-0006.
