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
build/bin/pascalc --std=extended hello.pas  # ISO/IEC 10206:1991 instead
```

The generated program links against `libpasrt.a`, built from `runtime/pasrt.c`.
`pascalc` finds it in the build tree; set `AFTERSCHOOL_PASCAL_RUNTIME` to point
somewhere else.

The language is selected per source. `--std=iso7185` is the default and is
what everything below describes; `--std=extended` is ISO/IEC 10206:1991, which
is **not** a superset — it reserves word-symbols (`otherwise`, `value`, `only`,
…) that a valid ISO 7185 program may use as ordinary identifiers, and this
compiler's own stage-1 source does. See
[ADR-0033](doc/adr/0033-extended-pascal-is-a-second-language-behind-std.md).

## What the compiler accepts today, with `--std=iso7185`

```
program-header, const part, type part, var part, compound statement
types      integer  real  boolean  char
           (red, green, blue) — enumerations
           lo..hi — subranges of any ordinal type, range-checked on store
           array [ordinal-type] of T, multi-dimensional, any ordinal index
           record, nested to any depth, packed, with variant parts
           set of T — sets over any ordinal type with values in 0..255
           packed array [1..n] of char — the string types
           ^T — pointers, including to a type defined later
           text — text files, with the buffer variable f^
           file of T — files of any type that is not, and holds, no file
routines   procedures and functions, nested to any depth, recursive,
           value and var parameters, forward declarations,
           procedural and functional parameters, congruity-checked
statements := , if/then/else, while, repeat/until, for/to/downto,
           begin/end, case, with, procedure call,
           label declarations, labelled statements,
           goto — within a block, and out of one into an enclosing block,
           write, writeln, read, readln
operators  + - * / div mod, and or not (short-circuiting),
           = <> < <= > >=  (including on strings),
           + - * on sets — union, difference, intersection,
           <= >= on sets — inclusion, and `in` — membership
functions  abs sqr odd ord chr succ pred sqrt sin cos ln exp arctan
           trunc round eof eoln
procedures new, dispose, reset, rewrite, get, put
literals   integers, reals, 'strings', '' escapes, nil,
           [a, b..c] set constructors, and [] the empty set,
           { } and (* *) comments
constants  named constants, plus predefined true, false, maxint
```

**This is the whole of ISO 7185.** Every feature of the standard is
implemented; what is left of the language is the next standard, not more of
this one.

Enumerations and subranges are ordinal types like `char`: they index arrays,
drive `for` loops, answer `ord`/`succ`/`pred`, and select `case` arms. `succ`
runs out at the end of its own type — at `blue`, or at 9 for a `1..9` — not at
`maxint`. A record may have a variant part, tagged or not, which is what makes
a tag-plus-variant AST node expressible. See
[ADR-0018](doc/adr/0018-ordinal-types-and-variant-records.md).

A set is one 256-bit word — a bit per possible member — so its base type's
values must lie in 0..255, and `set of integer` is refused rather than
truncated. That makes a set a *value*: it is assigned, compared and passed
exactly as an integer is, and the operators are one instruction each. Set
compatibility is decided on the base type structurally, which is ISO 7185's own
departure from the name equivalence it gives every other structured type. See
[ADR-0028](doc/adr/0028-a-set-is-one-256-bit-word.md).

Arrays and records assign whole (`b := a` copies every component), pass as
value parameters by copy and as `var` parameters by reference, and nest freely
in each other. A string literal has the type ISO 7185 gives it — `packed array
[1..n] of char` — so it assigns to, compares with, and passes as a variable of
that type with no special case anywhere.

Two types are the same only when one type identifier denotes both, as
ISO 7185 §6.4.5 requires, so two separately written `array [1..3] of integer`
are different types. See
[ADR-0017](doc/adr/0017-structured-types-use-name-equivalence.md).

A pointer's domain may name a type defined *later* in the same type part —
the only forward reference in the language, and what lets a record contain a
pointer to itself:

```pascal
type
  link = ^cell;                          { cell arrives on the next line }
  cell = record value: integer; next: link end;
```

Every dereference is checked against `nil`, and `dispose(p)` sets `p` to nil so
the commonest use-after-dispose becomes that same check. Use-after-dispose
through a *second* pointer to the same storage is not detected, and nothing here
claims it is — see
[ADR-0019](doc/adr/0019-pointers-and-the-only-forward-reference.md).

A text file has a **buffer variable** `f^` — one character of lookahead — and
ISO's primitives `get` and `put` are what `read` and `write` are built from,
here as in the standard. That is the operation a lexer is written against, and
a lexer is the first thing the self-hosted compiler needs:

```pascal
program Copy(input, output, src, dst);
var src, dst: text; c: char;
begin
  reset(src); rewrite(dst);            { src and dst are argv[1] and argv[2] }
  while not eof(src) do begin
    while not eoln(src) do begin
      c := src^;                       { look at the next character... }
      get(src);                        { ...and only now consume it }
      write(dst, c)
    end;
    readln(src); writeln(dst)
  end
end.
```

Program parameters are the program's only connection to the outside world, as
ISO 7185 §6.10 has it: `input` and `output` are the standard streams, and every
other one names a file variable bound to a command-line argument, in the order
written. A file variable that is *not* a program parameter is a scratch file
with no external name. Files are closed when the block declaring them exits,
which is the standard's own rule and needs no `close`. Using `write` without
`output` in the program header is an error, because §6.10 says it is. See
[ADR-0021](doc/adr/0021-text-files-keep-the-buffer-variable.md).

A **`file of T`** is the same thing with the component type changed. It has no
lines and no external representation of a number, so `readln`, `writeln` and
`eoln` are all refused on one; what it has instead is `read` and `write` in the
form ISO 7185 §6.6.5.2 defines for it — `read(f, v)` is `v := f^; get(f)`, and
`write(f, e)` is `f^ := e; put(f)`. The component may be any type that is not,
and does not contain, a file:

```pascal
program Records(output, data);
type point = record x, y: integer end;
var data: file of point; p: point;
begin
  rewrite(data);
  p.x := 1; p.y := 2; write(data, p);
  reset(data);
  while not eof(data) do begin
    writeln(data^.x:1, ' ', data^.y:1);   { f^ is a designator with fields }
    get(data)
  end
end.
```

`text` is **not** `file of char`: §6.4.3.5 makes them different types, and only
the first has lines. See
[ADR-0031](doc/adr/0031-a-file-of-t-is-a-text-with-two-constants-changed.md).

**Characters are bytes.** `char` is one octet with an ordinal of 0..255, and
nothing in the compiler or the runtime consults the locale — `write` emits the
bytes it is given and `read` returns the bytes it finds. UTF-8 text therefore
passes through unchanged, but a multi-byte character is several `char` values:
`é` is two, `日` is three. Encoding is the program's business, not the
language's.

Field widths follow Pascal: `write(x:8)`, `write(x:8:3)` for reals.
A real written without a width comes out in floating form (`5.0E-01` style);
with a width and a fraction length it comes out fixed-point.

**Errors are detected, not ignored.** ISO 7185 calls integer overflow, an array
subscript outside its bounds, a value stored outside a subrange, a `case` whose
selector matches no label, a dereference of `nil`, `chr` of a non-ordinal,
`succ` past the end of a type, and `trunc` of a real too large *errors*; this
compiler stops the program with a message rather than letting it wrap, read
past the array, or produce an arbitrary value:

```
$ pascalc overflow.pas && ./overflow
runtime error: integer overflow in sqr
```

The integer type is `-maxint..maxint`, which is narrower than the machine word
it lives in — so `2147483648` is rejected at compile time rather than silently
becoming `-2147483648`. See
[ADR-0014](doc/adr/0014-iso-error-conditions-trap-at-run-time.md) and
[ADR-0015](doc/adr/0015-real-to-integer-conversions-are-range-checked.md).

The last of ISO 7185 to arrive was the non-local `goto`, which leaves a block
rather than a statement: the target's activation record carries somewhere to
jump back to, and the jump closes the files of every block it abandons — the
work those blocks' own exits would have done
([ADR-0032](doc/adr/0032-a-non-local-goto-is-a-jump-record-in-the-target-frame.md)).

One implementation limit: nesting deeper
than 1000 levels — parentheses, statements, type denoters, or the depth of the
*tree* an operator chain builds — is a compile-time error rather than a stack
overflow, in the parser or in any walk after it. See
[ADR-0020](doc/adr/0020-the-parser-bounds-tree-depth.md).

## What `--std=extended` adds

ISO/IEC 10206:1991, one feature at a time. Everything above is accepted here
too, except that Extended Pascal reserves the word-symbols its own features
need — so an ISO 7185 program that uses one of them as an identifier compiles
under `--std=iso7185` and not under `--std=extended`. That is the standard's
rule, not a limitation of this compiler.

```
statements case ... otherwise <statements> end — the default arm
words      otherwise is reserved
```

Not accepted yet: schemata (parameterised types), the `string` type,
modules, `otherwise` in a variant part, case-constant ranges, non-decimal
literals, `pow` and `**`, `and_then`/`or_else`, `protected` parameters,
initial-state specifiers (`value`), binding (`bind`/`unbind`), direct-access
files, and complex numbers. A word-symbol is reserved only when the feature
needing it lands, so until the list above is complete `--std=extended` accepts
some programs a conforming processor would reject. `doc/roadmap.md` has the
order and the reasoning.

## How it fits together

| File | Role |
| --- | --- |
| `src/lexer.cpp` | source text to tokens; folds case, handles both comment forms |
| `src/parser.cpp` | recursive descent over the ISO grammar, builds the AST |
| `src/astdump.cpp` | the `--dump-*` format — a specification, since the Pascal compiler writes it too |
| `src/ast.h` | tag-dispatched nodes (`NK` + `as<T>()`), no C++ RTTI |
| `src/sema.cpp` | scopes, name resolution, type checking, constant folding |
| `src/codegen.cpp` | AST to LLVM IR via `IRBuilder`; `main` is the program body |
| `src/main.cpp` | driver: optimisation pipeline, object emission, linking |
| `runtime/pasrt.c` | formatted output and runtime checks |
| `tests/` | one `.pas` per case, with expected stdout in `.out` or an expected failure in `.err` |
| `tests/extended/` | the same, for cases written in Extended Pascal — the directory is what selects `--std` |
| `verify/` | SMT proofs that the lowering means what ISO 7185 says |
| `selfhost/compiler.pas` | the same compiler, written in Afterschool Pascal |

Two deliberate constraints, both there for the bootstrap:

* **No `dynamic_cast`, no exceptions in the AST walk.** Node kinds are explicit
  tags. Pascal has neither facility, so the C++ code stays within shapes that
  translate directly into a Pascal variant record.
* **Textual `.ll` output is a first-class path, not a debugging aid.** A
  compiler written in Pascal cannot call LLVM's C++ API. Emitting IR text is the
  backend that survives the rewrite.

## Verified, not just tested

A compiler is the one program whose bugs are inherited by everything it builds,
and a miscompilation is silent — the source is right, the test is right, the
answer is wrong. So the arithmetic the compiler emits is **proved** correct
rather than sampled:

```sh
pip install z3-solver
python3 verify/verify.py --pascalc build/bin/pascalc
```

For each construct, `verify/` states what ISO 7185 requires of the result as a
*property*, models what the compiler emits, and asks Z3 whether any input makes
the two disagree. Thirty-five rules are currently established — the
non-negative `mod`, truncating `div`, `odd` on negative values, ordinal `char`
comparison, the exact integer-to-real widening, the `for` loop's inability to
overflow, an array subscript's inability to leave its bounds, a subrange's
inability to hold a value outside it, a set constructor containing exactly the
members it names, and the digit accumulator in `read` being unable to wrap
before its check sees it — twenty-seven of them for all 2³² inputs.

Several rules keep their bounds *symbolic*, so they are theorems about every
array, every subrange, every enumeration and every set base type rather than
about the ones a test happens to declare.

Each runtime check is proved to fire *exactly* when ISO says the operation is in
error. Both directions matter: trapping always would satisfy "never produces a
wrong answer", and never trapping would satisfy "never rejects a valid program".
There are currently **no known gaps**.

Some rules exist to justify a check the compiler deliberately does *not* emit —
the `for` loop's step, unary negation, and an array's offset subtraction. The
last of those failed the first time it was run, on an array whose bounds span
more than `maxint` values, and the compiler now rejects such an array at compile
time. Proving why a check is unnecessary is how you find out that it isn't.

Not everything gets a rule. Pointer safety is not an arithmetic-lowering
question, and a rule saying "the nil check fires exactly when the pointer is
nil" would be the same sentence written twice — it would pass at once and prove
nothing while making the count look better. Pointers are covered by the
cross-check and by a run under AddressSanitizer instead, and ADR-0019 says so
plainly rather than inflating the catalogue. The same reasoning keeps `eof`,
`eoln` and the buffer variable out: they are state properties of a stream. What
they get instead is a test that can actually fail — `files_scratch.pas` opens
three thousand scratch files, which exhausts the descriptor table if a block
exit ever stops closing them, and that was checked against a deliberately
broken runtime.

The proofs are paired with a cross-check that compiles and runs real Pascal at
the adversarial points, at both `-O0` and `-O2`, because a proof about a model of
the compiler is only worth what keeps it tied to the compiler. See
[ADR-0013](doc/adr/0013-formal-verification-of-the-lowering.md) for what this
does and does not establish.

## Decisions

`doc/adr/` records the architecture decisions and what each one costs — why the
AST avoids C++ RTTI, why textual IR is a supported output, why `and` and `or`
short-circuit, and what is still open. Start with
[ADR-0004](doc/adr/0004-self-hosting-is-the-near-term-goal.md) if you only read
one.

[doc/glossary.md](doc/glossary.md) defines the terms this codebase uses in a
specific sense — ordinal, designator, type-denoter, static link, tautological
rule — and says which decision governs each.

## Bootstrap plan

The classic three-stage build. Stage 0 is the C++ compiler in this repository;
it only has to be good enough to compile the Pascal-written compiler once.

```
stage 0   pascalc (C++)          — this repo, grown until it accepts the stage-1 source
stage 1   pascalc1 = stage0(compiler.pas)
stage 2   pascalc2 = pascalc1(compiler.pas)
stage 3   pascalc3 = pascalc2(compiler.pas)      require pascalc2 ≡ pascalc3 byte-for-byte
```

**This now holds.** The compiler compiles itself, and stage 2 and stage 3 are
identical, byte for byte, checked under `ctest` by
`selfhost/irtest.sh`.

Reaching stage 1 means the accepted language has to cover what a compiler is
written in. In dependency order:

1. ~~**Procedures and functions**~~ — done: nested to any depth, value and
   `var` parameters, `forward`, implemented with static links (ADR-0016).
2. ~~**Arrays and records**~~ — done: static arrays of any ordinal index,
   `packed`, nested records, `with`, bounds-checked subscripts (ADR-0017).
   Variant parts wait for `case`.
3. ~~**Enumerations, subranges, `case`**~~ — done, together with the variant
   records they unlock (ADR-0018). An AST node is now expressible: the tag is
   an enumeration and the node is a variant record.
4. ~~**Pointers and `new`/`dispose`**~~ — done, with the forward-referenced
   pointer domain that makes a recursive type possible (ADR-0019). The AST can
   now be a heap-allocated tree rather than an array of nodes.
5. ~~**Text files**~~ — done: `reset`, `rewrite`, `read`, `readln`, `eof`,
   `eoln`, and the buffer variable with `get`/`put` that a lexer wants
   (ADR-0021). The compiler can now read source and write `.ll`.
6. ~~**Character strings**~~ — decided: a length-plus-buffer record in strict
   ISO Pascal, no extension (ADR-0012). Measuring the existing compiler settled
   it: a compiler reads text in and writes text out rather than manipulating
   it, so nearly every concatenation becomes a `write` and the only strings
   that must be *stored* are identifiers and about sixty padded table entries.
   `tests/bootstrap_strings.pas` is the working evidence.

**Every prerequisite for stage 1 is now in place**, and the Pascal source that
needed them is written.

## Stage 1

`selfhost/compiler.pas` is the compiler written in its own language: the lexer,
the parser, Sema and the code generator, in **one source file**, because ISO
7185 has no include mechanism and the finished compiler is one source. It is
checked against the C++ stages it was ported from, on every Pascal source in the
tree — 207 files, compared stage for stage:

```sh
selfhost/difftest.sh build/bin/pascalc     # also runs under ctest
```

Both write the same three sections, so the comparison is a plain diff:

```
$ build/bin/pascalc --dump-tokens tests/hello.pas | head -3
1 1 kw program
1 9 ident hello
1 14 op (

$ build/bin/pascalc --dump-sema tests/hello.pas | head -6
program hello
  params
    name output @1:15
  frames
    frame hello level 0
      var output #0 : text (stdout 0)
```

That is the checkpoint rather than a convenience. A disagreement between the
two is bisectable now; the same disagreement discovered at stage 3 is two
compiler binaries differing by a byte. The corpus includes the Pascal compiler's
own source, and three directories cover the error paths a valid program never
reaches: `selfhost/torture.pas` for the lexer, `selfhost/badparse/` for the
parser (one file per message, because the parser stops at its first error) and
`selfhost/badsema/` for Sema (thirteen files, because Sema accumulates). See
[ADR-0022](doc/adr/0022-the-lexer-port-is-checked-differentially.md),
[ADR-0023](doc/adr/0023-the-ast-is-a-variant-record-and-a-sibling-list.md) and
[ADR-0024](doc/adr/0024-the-stage-1-compiler-becomes-one-source-file.md).

The AST is where the bootstrap constraints paid off: the `NK` tag of
[ADR-0005](doc/adr/0005-tag-dispatched-ast-without-cpp-rtti.md) became a
variant record's tag and `as<T>()` became the `case` that reads it, with no
`dynamic_cast` to replace and nothing to redesign.

The code generator is the one component that is **not** diffed, and could not
be: the C++ backend builds an `llvm::Module` through the API while the Pascal
one prints assembler text, and LLVM's own printer is not a specification — it
renumbers, reorders and changes between releases. So it is checked by *running*
what it produces, against the same golden output the C++ compiler is held to,
and then by closing the bootstrap:

```sh
selfhost/irtest.sh build/bin/pascalc       # also runs under ctest
```

That compiles every case in `tests/` with the Pascal compiler, links the IR with
`clang`, runs it and compares against `tests/*.out` and `tests/*.err`; then
compiles the compiler with itself twice and requires stage 2 and stage 3 to be
identical. A compiler that reproduced itself and nothing else would pass that
last comparison alone, so stage 2 is put through the golden suite too. See
[ADR-0025](doc/adr/0025-the-code-generator-is-checked-by-running-it.md).

```sh
build/bin/pascalc selfhost/compiler.pas -o stage1
./stage1 selfhost/compiler.pas stage2.ll        # source, then where the IR goes
clang stage2.ll build/lib/libpasrt.a -lm -o stage2
```

[doc/roadmap.md](doc/roadmap.md) expands this: what items 5 and 6 actually
involve, the order the stage-1 source gets ported in, and the known limitations
— including the ones that are deliberate.

## Adding a test

Drop `tests/name.pas` plus its expectation into `tests/`, then re-run CMake so
the case is registered — the suite is globbed at configure time.

* `name.out` — expected stdout. The program must compile and exit 0.
* `name.err` — expected stderr, for a program that is *supposed* to fail: one
  that should be rejected at compile time, or that should stop on a runtime
  error. A non-zero exit is then required, and `name.out` (if present) is
  compared against whatever was written before the failure.
* `name.in` — fed to the program's standard input. Without it stdin is
  `/dev/null`, so a program that reads sees end-of-file rather than waiting for
  a terminal. Two writable scratch paths are always passed as arguments, so a
  program whose header names external files has somewhere to put them.

`tests/run_test.sh` compiles, runs, and diffs. Source paths are rewritten to
`<source>` in stderr, so diagnostics can be pinned without depending on where
the checkout lives.
