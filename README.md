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
types      case ... otherwise (fields) in a record — the variant no label
           claims
labels     1..9, 'a'..'z' — a range wherever a case constant may appear,
           in a case statement and in a variant alike
literals   16#ff, 2#1010, 36#z — any base from 2 to 36, letters as the
           digits above nine
operators  x ** y and x pow y — exponentiation, binding tighter than * and
           looser than not. ** always yields a real; pow takes an integer
           exponent and yields the type of its left operand, so 2 pow 3 is
           the integer 8 and 2 ** 3 is 8.0
           a and then b, a or else b — the short-circuit operators, which
           evaluate the right operand only when the left has not settled
           the answer. Each is one word-symbol written as two words
types      vector(n: integer) = array [1..n] of real — a schema, and
           vector(3) a type produced from it. Two productions with the same
           discriminants are the same type and two with different ones are
           not, whatever they look like; v.n is the value a type was
           produced with. A discriminant may also be a variable — `vector(n)`
           in a variable declaration is sized when the block is entered, and
           the tuple is checked there (§6.2.3.2)
params     procedure p(var v: vector) — a schematic formal parameter, whose
           bounds come from the actual: one body serves every tuple, and
           v.n reads the tuple the argument brought. A value parameter of
           one is copied on entry, at whatever size the tuple says
records    a schema may produce a record holding a dynamically bounded
           array as its *last* field — the shape `string` has: a length
           beside a buffer whose capacity is the discriminant. Only last,
           because a field after it would sit at an offset nothing can
           compute; a variant part is refused for the same reason
pointers   ^vector — a schema as the domain of a pointer, with
           new(p, 3) giving the tuple. The variable's discriminants travel
           with it, so p^.n, p^[i] and passing p^ to a schematic formal all
           work wherever the pointer reaches; dispose gives the storage back
variants   record case k of ... end inside a schema — a discriminant as the
           variant-selector (§6.4.3.4), so which arm is live is fixed by the
           tuple the type was produced with rather than by a value the
           program stores. The selector is not a field, so nothing can
           disagree with it, and one compiled body serves every variant
assign     v := w between two variables of one schema's types. Where both
           tuples are written in the program the compiler decides it;
           where one is not known until the block is entered, the tuples
           are compared while the program runs and a mismatch stops it
           (§6.4.6 d)
params     procedure p(protected c: integer; protected var d: point) — a
           parameter the body may not change. It says nothing about how the
           argument travels: the promise is that no statement of the body
           assigns it, reads into it, or hands it to something that would.
           Passing it on to another *protected* parameter is allowed, and
           that is what makes the word usable; a file or a pointer cannot be
           protected, because protecting either would protect nothing
types      type of x — a type-inquiry: the type the variable x already
           possesses, handed back rather than built again. That is what
           makes `b: type of a` assignable from a, where a second
           `record x, y: integer end` written out would not be. It reaches
           a parameter of the same list, so `procedure p(var a: point;
           b: type of a)` writes the type once
types      integer value 1 — an initial-state specifier: the value a
           variable bears when the block declaring it is entered, and
           again on every later activation of that block. It belongs to
           the type-denoter, so `type count = integer value 7` gives it to
           every variable of count, and a record's fields may each carry
           one. The value must read nothing that can change — a literal,
           a constant, an operator over those, or a required function
types      complex — a *simple* type, so it is assigned, passed and
           returned as a value like a real. cmplx(x, y) and polar(r, t)
           build one (the standard gives it no literal); re, im, arg and
           abs take one apart, all yielding a real. + - * / work, and an
           integer or real operand widens; = and <> compare, and the
           ordering operators do not, there being no order on the complex
           numbers. sqr, sqrt, exp, ln, sin, cos and arctan give a complex
           for a complex, with C99's principal values
files      file [1..100] of integer — a direct-access file. The index type
           in brackets is what makes one, and its values are the
           positions: SeekRead, SeekWrite and SeekUpdate move to one,
           position and lastposition report one, and empty says whether
           there are any. update(f) writes the buffer variable back over
           the current component without advancing, which is what makes
           read-modify-write possible; extend(f) opens for writing at the
           end and needs no index type at all
strings    string(n) — the required schema of §6.4.3.3.3: a length and up
           to n characters. Assignment keeps the value's own length and
           stops the program if it does not fit; a `packed array [1..n]
           of char` is the other string type and is padded instead, and
           the two are compatible with each other and with char. s[i]
           indexes to the *length*, s.capacity is the type's. + joins
           any two of them; = < > pad the shorter with spaces (where
           ISO 7185 required equal lengths); length, index, substr and
           trim answer about one, and eq, ne, lt, gt, le, ge compare
           lengths as well as characters — so `eq('ab','ab  ')` is false
           where `'ab' = 'ab  '` is true, which is the standard's own
           example. '' is the null-string
binding    var f: bindable text — a variable that may be bound to
           something outside the program. bind(f, b) attaches it to the
           file named by b.name, unbind(f) detaches it, and binding(f)
           reports both the name and whether it took. BindingType is the
           required record they trade in: a name and a boolean. This is
           the only way a program names a file while it is *running* —
           ISO 7185 binds the program parameters before it starts and
           gives it no other way out
modules    module m; export i = (a, b => c, lo..hi); ... end; ... end. —
           a module: a heading that says what it exports and a block that
           implements it, either written together or as separate
           program-components with `interface` and `implementation`. A
           program is a sequence of those, one of which is the `program`.
           import i; brings everything an interface holds; `only (x)` says
           the list is exhaustive, `qualified` says the names arrive as
           i.x and never bare, and `=>` renames at either end.
           `protected v` exports a variable the importer may read and not
           write. A procedure's heading may sit in the module-heading and
           its body in the module-block — the `forward` mechanism under
           another name. `to begin do` and `to end do` are the module's
           initialization and finalization; the modules that supply the
           program are activated in the order they were written and
           finalised in the reverse (§6.2.3.6), and one that supplies
           nothing is never activated at all. StandardInput and
           StandardOutput are the required interfaces a module imports to
           reach `input` and `output`
const      const n = base * 2 — a constant-expression: wherever ISO 7185
           asked for a constant, the whole expression grammar is now
           admitted, so a subrange bound, an array bound, a case label, a
           variant label and a schema's discriminants each take one too.
           The operators fold as the emitted code computes them — `mod` is
           non-negative, an overflow is refused rather than wrapped — and
           `abs`, `sqr`, `odd`, `ord`, `chr`, `succ` and `pred` fold with
           them. A real-, set- or string-valued one is not folded: a real
           constant is carried as the text that was written and never
           converted, and there is nowhere to keep the other two
funcs      a function may return a record, an array, a set or a string — any
           type that is not, and does not contain, a file, and is not
           bindable. The result travels in storage the *caller* supplies, so
           nothing about it is limited to small values. `function mk(a, b:
           integer) = r: point` names the result, which is how one is built a
           field at a time: without a name the only way to write it is
           `mk := e`, because reading `mk` is a recursive call. With a name
           the function identifier may not be assigned at all, and without
           one the body must assign it at least once
f(x).y     a selector may follow a call: `mk(7, 8).y` reads a field of a
           result, `scale(10)[2]` a component, and `alloc(3)^` the variable
           a returned pointer identifies. Only the last of those is a
           *variable* — §6.5.1 says so, because what a pointer points at is
           a variable however the pointer was obtained — so only it may be
           assigned to, passed as a var parameter or read into. The others
           are values: a function-access is not a variable-access
s[i..j]    a substring, of a string variable or of a call's result. Of a
           variable it is a variable — `s[2..4] := 'XYZ'` writes three
           characters in place, and a shorter value is padded with spaces as
           any fixed-string assignment is; of a call's result it is a value.
           Reading one copies nothing. `s[3..2]` is an error, where
           `substr(s, 3, 0)` is the null-string: the two rules agree
           everywhere except the empty case
restricted a restricted type has another type's values and representation
           and almost none of its operations: it may be assigned to and from
           the underlying type, passed as a value or var parameter to a
           formal of that type, and returned from a function, and §6.4.2.5
           says "no other operations ... are possible". Its initial state is
           the underlying type's. Two restrictions of one type are still two
           types, and a restricted type is nonbindable
words      otherwise, pow, protected, value, bindable, restricted, module, export,
           import, only and qualified are reserved; `and then`,
           `or else` and `type of` reserve nothing new, because all of
           their words already are. complex, cmplx, polar, re, im and arg
           are required *identifiers* rather than word-symbols, and so are
           seekread, seekwrite, seekupdate, update, extend, position,
           lastposition, empty, string, length, index, substr, trim, eq,
           ne, lt, gt, le, ge, binding, bind and unbind — so a program may
           still declare its own. So are `interface` and `implementation`:
           §6.1.5 and §6.1.6 make them *directives*, which are identifiers
           in the one position each may occupy, exactly as `forward` is
```

Not accepted yet, and each its own piece of work: structured-value
constructors and `readstr`/`writestr`.

Also absent, and smaller — the cost is in writing them twice rather than in the
design: `halt`, `card`, the symmetric difference `><`,
`maxchar`/`minreal`/`maxreal`/`epsreal`, the two-argument `succ`/`pred`, zero
field widths in `write`, the time procedures, and set-member iteration.

A word-symbol is reserved only when the feature needing it lands, so until that
list is empty `--std=extended` accepts some programs a conforming processor
would reject.

The program-components of a program-block are **not compiled separately**: they
go in one file, in an order consistent with §6.2.2.9's. §6.13 asks for separate
compilation with a *should* rather than a *shall*, and accepting them apart
means defining an interface artefact — a second file format, and one the
stage-1 compiler could not write. See
[ADR-0053](doc/adr/0053-a-level-0-activation-record-is-a-global.md).
`doc/roadmap.md` has the order and the reasoning.

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
the two disagree. Forty-three rules are currently established — the
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
tree, compared stage for stage — the harness prints how many:

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
echo iso7185 > std.txt
./stage1 selfhost/compiler.pas stage2.ll std.txt   # source, IR, and the standard
clang stage2.ll build/lib/libpasrt.a -lm -o stage2
```

The third argument is a *file* holding one word, not a flag: ISO 7185 gives a
program no access to its command line beyond its program parameters, and those
are files — so the Pascal compiler cannot take a `--std` the way the C++ one
does (ADR-0033).

[doc/roadmap.md](doc/roadmap.md) expands this: what items 5 and 6 actually
involve, the order the stage-1 source gets ported in, and the known limitations
— including the ones that are deliberate.

## Adding a test

Drop `tests/name.pas` plus its expectation into `tests/`, then re-run CMake so
the case is registered — the suite is globbed at configure time.

**The directory selects the language.** A case in `tests/` is compiled with
`--std=iso7185` and one in `tests/extended/` with `--std=extended`; the two are
globbed separately for exactly that reason, and every harness derives the flag
from the path so that none of them can be told something different about one
file (ADR-0034).

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
