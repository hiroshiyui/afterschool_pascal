# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Afterschool Pascal: an ISO 7185 Standard Pascal compiler with an LLVM backend,
written in C++20 against the LLVM 21 C++ API. The near-term goal is
**self-hosting** — see "Bootstrap constraints" below, which govern design
choices that would otherwise look arbitrary.

## Commands

```sh
# configure (LLVM_DIR is required on Debian; llvm-config is not on PATH)
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DLLVM_DIR=/usr/lib/llvm-21/lib/cmake/llvm
cmake --build build -j

ctest --test-dir build --output-on-failure
ctest --test-dir build -R control --output-on-failure   # a single case, by name
tests/run_test.sh build/bin/pascalc tests/control.pas   # same case, without ctest

build/bin/pascalc tests/hello.pas -o /tmp/hello && /tmp/hello
build/bin/pascalc -O0 --emit-llvm tests/hello.pas -o /dev/stdout   # inspect IR
```

Adding `tests/foo.pas` + `tests/foo.out` requires **re-running `cmake`** — cases
are registered by a `file(GLOB)` at configure time.

`pascalc` shells out to `clang` to link, and finds `libpasrt.a` through the
build path baked in as `APASCAL_RUNTIME_DIR`; `AFTERSCHOOL_PASCAL_RUNTIME`
overrides it.

## Pipeline and its contracts

`main.cpp` runs: Lexer → Parser → Sema → CodeGen → PassBuilder → TargetMachine →
`clang` link. Each stage bails before the next if `Diagnostics::hasErrors()`.

The contract that keeps `codegen.cpp` simple: **Sema leaves every `Expr::type`
non-null and every `VarRef::sym` resolved.** CodeGen therefore never inspects
names, never re-derives types, and reports no user-facing errors — if it needs a
fact about the source program, that fact belongs in Sema. On an error path Sema
still assigns a placeholder type rather than null, so codegen can't crash on a
half-checked tree.

Errors: the parser throws `ap::ParseAbort` (the only exception in the codebase)
when it cannot make progress; Sema and the lexer instead accumulate into
`Diagnostics` so one run reports many errors.

`Sema::variables()` gives codegen the declaration-ordered variable list; it
allocas one slot per symbol into `main`'s entry block and keeps the mapping in
`slots_`. There is no separate lvalue path yet — assignment writes straight to a
slot.

## Bootstrap constraints (do not casually violate)

1. **No C++ RTTI in the AST.** `ast.h` tags nodes with `NK` and casts via
   `as<T>(n)` / `is<T>(n)`, where each node declares `static constexpr NK
   NodeKind`. Two reasons: Debian's LLVM is built without RTTI, and the eventual
   Pascal-hosted compiler has no `dynamic_cast` — the tag + variant record is
   what it will use. Adding a node means adding an `NK` enumerator and the
   `NodeKind` member.
2. **Textual `.ll` output stays a first-class path.** A compiler written in
   Pascal cannot call LLVM's C++ API, so `--emit-llvm` is the backend that
   survives the rewrite, not a debugging aid.
3. Prefer C++ that maps onto Pascal — plain structs, tags, explicit control
   flow — over template or exception machinery in the tree walks.

Feature priority follows what a compiler is written in (procedures, records,
pointers, text files, a usable string type), not ISO chapter order. README.md
holds the three-stage plan and the dependency ordering.

## Where things live

`src/lexer.cpp` case-folds identifiers and knows every ISO reserved word, even
ones the parser rejects. `src/parser.cpp` is recursive descent shaped like the
ISO grammar (`expression` → `simple-expression` → `term` → `factor`) — note a
leading sign binds to the whole *term*, so `-7 mod 3` is `-(7 mod 3)`.
`src/sema.cpp` owns scopes, type rules, and constant folding. `runtime/pasrt.c`
holds anything not expressible in IR — formatted output and runtime checks —
where `width < 0` / `prec < 0` mean "not given".

Adding a language feature usually touches, in order: `token.h`/`lexer.cpp` →
`ast.h` → `parser.cpp` → `sema.cpp` → `codegen.cpp` → a `tests/` pair, plus
`runtime/pasrt.c` if it needs library support.

## Pascal semantics already encoded (keep them)

`mod` yields a non-negative result (not C's truncating remainder); `and`/`or`
short-circuit; `/` is always real division; `for` evaluates its limit once and
tests `= limit` before stepping so the last iteration cannot overflow; `div`/`mod`
by zero call `pas_runtime_error`; a one-character string literal is a `char`.
