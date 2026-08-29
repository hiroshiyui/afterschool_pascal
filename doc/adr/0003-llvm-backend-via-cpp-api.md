# 3. Compile through LLVM, driven by the C++ API

Date: 2026-08-09

## Status

**Deprecated.** It was accepted, and is retired by
[ADR-0085](0085-stage-0-is-retired.md). This record covers stage 0 only -- it
says so in its own last paragraph -- and stage 0 is gone, so every mechanism
below it is: there is no `Module` built with `IRBuilder`, no pass manager, no
`TargetMachine`, no `verifyModule`, and no `find_package(LLVM CONFIG)`. The
project declares `LANGUAGES C` and links nothing of LLVM's; there is not one
C++ source tracked in the tree, the last of them having gone with `src/` in
[ADR-0232](0232-afterschool-pascal-is-the-language.md).

What replaced it is the alternative this record listed third and did not take:
[ADR-0006](0006-textual-llvm-ir-as-a-first-class-output.md)'s textual IR,
which was written as a second output to keep the Pascal-hosted compiler
possible and is now the only one. That is the reversal worth reading here --
the option chosen for what it inherited (optimisation, retargeting, a verifier)
lost to the option chosen for what it did *not* require.

Two consequences below outlived it. The verifier did not, and nothing replaced
it: `clang` refusing to assemble a module catches malformed IR and never wrong
IR, which is why `llc-second-backend` exists. And Debian's LLVM being built
without RTTI is the reason behind
[ADR-0005](0005-tag-dispatched-ast-without-cpp-rtti.md), which is itself
historical now and still explains why the AST is a tag and a variant record.

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
