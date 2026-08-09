# Afterschool Pascal

An ISO 7185 Standard Pascal compiler with an LLVM backend.

The long-term goal is **bootstrapping**: Afterschool Pascal should be written in
Afterschool Pascal and able to compile itself. Everything below is arranged to
serve that.

## Building

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DLLVM_DIR=/usr/lib/llvm-21/lib/cmake/llvm
cmake --build build -j
ctest --test-dir build --output-on-failure
```

Requires LLVM 21 development files, a C++20 compiler, and `clang` on PATH for
linking.

## Using

```sh
build/bin/pascalc hello.pas          # -> ./hello
build/bin/pascalc -o greet hello.pas
build/bin/pascalc --emit-llvm hello.pas   # -> hello.ll
build/bin/pascalc -c hello.pas            # -> hello.o
build/bin/pascalc -O0 hello.pas           # -O0..-O3, default -O2
```

The generated program links against `libpasrt.a`, built from `runtime/pasrt.c`.
`pascalc` finds it in the build tree; set `AFTERSCHOOL_PASCAL_RUNTIME` to point
somewhere else.

## What the compiler accepts today (milestone 1)

```
program-header, const part, var part, compound statement
types      integer  real  boolean  char
statements := , if/then/else, while, repeat/until, for/to/downto,
           begin/end, write, writeln
operators  + - * / div mod, and or not (short-circuiting),
           = <> < <= > >=
functions  abs sqr odd ord chr succ pred sqrt sin cos ln exp arctan
           trunc round
literals   integers, reals, 'strings', '' escapes, { } and (* *) comments
constants  named constants, plus predefined true, false, maxint
```

Field widths follow Pascal: `write(x:8)`, `write(x:8:3)` for reals.
A real written without a width comes out in floating form (`5.0E-01` style);
with a width and a fraction length it comes out fixed-point.

Not accepted yet: procedures and functions of your own, arrays, records, sets,
pointers, files, `case`, `with`, `goto`, subranges, enumerations.

## How it fits together

| File | Role |
| --- | --- |
| `src/lexer.cpp` | source text to tokens; folds case, handles both comment forms |
| `src/parser.cpp` | recursive descent over the ISO grammar, builds the AST |
| `src/ast.h` | tag-dispatched nodes (`NK` + `as<T>()`), no C++ RTTI |
| `src/sema.cpp` | scopes, name resolution, type checking, constant folding |
| `src/codegen.cpp` | AST to LLVM IR via `IRBuilder`; `main` is the program body |
| `src/main.cpp` | driver: optimisation pipeline, object emission, linking |
| `runtime/pasrt.c` | formatted output and runtime checks |
| `tests/` | one `.pas` per case with its expected stdout in `.out` |

Two deliberate constraints, both there for the bootstrap:

* **No `dynamic_cast`, no exceptions in the AST walk.** Node kinds are explicit
  tags. Pascal has neither facility, so the C++ code stays within shapes that
  translate directly into a Pascal variant record.
* **Textual `.ll` output is a first-class path, not a debugging aid.** A
  compiler written in Pascal cannot call LLVM's C++ API. Emitting IR text is the
  backend that survives the rewrite.

## Decisions

`doc/adr/` records the architecture decisions and what each one costs — why the
AST avoids C++ RTTI, why textual IR is a supported output, why `and` and `or`
short-circuit, and what is still open. Start with
[ADR-0004](doc/adr/0004-self-hosting-is-the-near-term-goal.md) if you only read
one.

## Bootstrap plan

The classic three-stage build. Stage 0 is the C++ compiler in this repository;
it only has to be good enough to compile the Pascal-written compiler once.

```
stage 0   pascalc (C++)          — this repo, grown until it accepts the stage-1 source
stage 1   pascalc1 = stage0(compiler.pas)
stage 2   pascalc2 = pascalc1(compiler.pas)
stage 3   pascalc3 = pascalc2(compiler.pas)      require pascalc2 ≡ pascalc3 byte-for-byte
```

Reaching stage 1 means the accepted language has to cover what a compiler is
written in. In dependency order:

1. **Procedures and functions** — nested, value and `var` parameters, `forward`.
   Needs a real activation record and static links.
2. **Arrays and records** — static arrays, `packed`, nested records, `with`.
   Token tables and AST nodes live here.
3. **Enumerations, subranges, `case`** — the node-kind tag itself wants these.
4. **Pointers and `new`/`dispose`** — the AST is a heap-allocated tree.
5. **Text files** — `reset`, `rewrite`, `read`, `readln`, `eof`, `eoln`, so the
   compiler can read source and write `.ll`.
6. **Character strings.** ISO 7185 offers only `packed array [1..n] of char`,
   which is painful for a compiler that manipulates identifiers. This is the one
   place a documented non-standard extension is likely worth it; the decision is
   still open.

Backend for the Pascal-hosted compiler: emit textual LLVM IR and hand it to
`llc`/`clang`. That needs nothing but file output. Binding the LLVM-C API from
Pascal is possible later but is not on the critical path.

A useful checkpoint before stage 1 is *differential testing*: once the C++
compiler and the Pascal compiler both exist, they should produce equivalent IR
for every file in `tests/`.

## Adding a test

Drop `tests/name.pas` and `tests/name.out` (expected stdout) into `tests/`, then
re-run CMake so the case is registered. `tests/run_test.sh` compiles, runs, and
diffs.
