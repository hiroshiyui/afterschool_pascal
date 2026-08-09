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

## Decisions

`doc/adr/` holds the architecture decision records. Read them before undoing
something that looks over-complicated — most of the odd-looking choices here are
load-bearing for the bootstrap, and each record says what it costs. Add a record
when a choice constrains future work or deviates from the standard.

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
tests `= limit` before stepping so the last iteration cannot overflow; a
one-character string literal is a `char`.

**ISO error conditions trap** (ADR-0014). Integer `+ - *` and `sqr` go through
`checkedArith` and stop the program on overflow rather than wrapping — they
carry no `nsw`. `chr` outside 0..255, `succ`/`pred` at the ends of their type,
`div` by zero, and `INT_MIN div -1` all reach `pas_runtime_error` (stderr, exit
1). The integer type is **-maxint..maxint**, narrower than the `i32` behind it,
so `INT_MIN` is not a value of the type and a literal above `maxint` is a
compile-time error.

A check is omitted only where its absence is *proved* sound — the `for` step and
unary negation are unchecked, and `verify/` carries the theorems saying they
cannot overflow. Don't add a check there, and don't remove one elsewhere.

Most of these are not merely tested — they are **proved** in `verify/` for every
input. Changing one breaks a theorem, not a sample.

## Formal verification (`verify/`)

`verify/verify.py` proves each lowering rule against a property-style statement
of ISO 7185 using Z3, then cross-checks the real binary at the adversarial
points. It runs under `ctest` and skips when z3 is missing
(`pip install z3-solver`). ADR-0013 has the rationale; `verify/README.md` has the
mechanics.

Three things to know before touching it:

- **`lowering.py` is a model of `codegen.cpp` and must be maintained with it.**
  A drifted model keeps passing and proves nothing. When you change a lowering,
  change the model in the same commit.
- **Specifications state properties, never computations.** Writing `iso.py` so it
  computes the answer the way the compiler does would make every proof circular
  and the circularity invisible.
- **A `KNOWN_GAP` that starts holding fails the build.** That is intentional: it
  means the compiler was fixed and the catalogue is now describing a compiler
  that no longer exists. Flip it to `MUST_HOLD` in the same change.

New arithmetic, conversion, or comparison lowering should arrive with a rule.
The four gaps currently catalogued (`chr` range, `INT_MIN div -1`, `succ(maxint)`,
`sqr` overflow) are open language-design questions about what an ISO error
condition should *do* — not merely bugs to squash.
