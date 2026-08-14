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

That builds **two compilers**, and the distinction matters everywhere below:

| | | |
|---|---|---|
| `build/bin/pascalc-s0` | written in C++ | stage 0 — it builds the one below |
| `build/bin/pascalc` | written in Afterschool Pascal | the compiler this project is for |

`pascalc` is `selfhost/compiler.pas` translated by `pascalc-s0`, and it compiles
itself: stage 2 equals stage 3, so the source is a fixed point. Stage 0 is kept
rather than retired — it is the second implementation `selfhost/difftest.sh`
compares against and the one `verify/` proves. [doc/roadmap.md](doc/roadmap.md)
has that trade in full.

## Using

`pascalc-s0` does the most, so it is what the examples use — it optimises,
emits objects and links:

```sh
build/bin/pascalc-s0 hello.pas          # -> ./hello
build/bin/pascalc-s0 -o greet hello.pas
build/bin/pascalc-s0 --emit-llvm hello.pas   # -> hello.ll
build/bin/pascalc-s0 -c hello.pas            # -> hello.o
build/bin/pascalc-s0 -O0 hello.pas           # -O0..-O3, default -O2
build/bin/pascalc-s0 --std=extended hello.pas  # ISO/IEC 10206:1991 instead
build/bin/pascalc-s0 --keep-temps hello.pas  # keep the intermediate .o
build/bin/pascalc-s0 --help                  # the full option list
```

**`pascalc` takes the same flags**, and reads them the only way a Pascal
program can: §6.5.1 makes every program-parameter bindable and §6.7.6.8 makes
`binding(p).name` the argument it was bound to, so the compiler asks its own
program-parameters what it was invoked with (ADR-0081, ADR-0083).

```sh
build/bin/pascalc hello.pas                          # -> hello.ll
build/bin/pascalc --std=extended prog.pas -o prog.ll
build/bin/pascalc prog.pas --import counter.pas -o prog.ll
clang hello.ll build/lib/libpasrt.a -lm -o hello     # pascalc stops at the IR
```

That last line is the one part of a driver's job that does not port: neither
standard has process control, so a compiler written in Pascal cannot spawn the
linker. It is a property of the language rather than a shortfall of this
compiler, and it is why `pascalc-s0` — which also optimises, emits objects and
links — is still what the examples below use.

ISO/IEC 10206:1991 §6.13 lets a program's components be translated separately.
A source that declares only modules is one, and it becomes an object; the
component that declares the `program` is given the others' *sources*, which is
where their interfaces are written:

```sh
build/bin/pascalc-s0 --std=extended -c counter.pas -o counter.o
build/bin/pascalc-s0 --std=extended prog.pas --import counter.pas counter.o -o prog
```

`-S` is an alias for `--emit-llvm`. Four dump flags write a stage and stop —
`--dump-tokens`, `--dump-ast`, `--dump-sema`, and `--dump-all` for all three;
they exist so the Pascal compiler can be diffed against this one, and are
described under "Stage 1" below.

The generated program links against `libpasrt.a`, built from `runtime/pasrt.c`.
`pascalc-s0` finds it in the build tree; set `AFTERSCHOOL_PASCAL_RUNTIME` to
point somewhere else. `pascalc` never links, so it never looks.

The language is selected per source. `--std=iso7185` is the default and is
what everything below describes; `--std=extended` is ISO/IEC 10206:1991, which
is **not** a superset — it reserves word-symbols (`otherwise`, `value`, `only`,
…) that a valid ISO 7185 program may use as ordinary identifiers. See
[ADR-0033](doc/adr/0033-extended-pascal-is-a-second-language-behind-std.md).
`selfhost/compiler.pas` used to be the example of that and is now written in
Extended Pascal itself ([ADR-0082](doc/adr/0082-the-stage-1-compiler-is-extended-pascal.md)),
because only that standard lets a program read its own command line.

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
procedures new, dispose, reset, rewrite, get, put,
           pack(a, i, z) and unpack(z, a, i) — copy a run of
           components between an unpacked array and a packed one,
           starting at i in the unpacked one,
           page(f) — a page separator, with an implicit writeln
           when the line is not empty,
           new(p, c1..cn) and dispose(p, c1..cn) — the variant-selecting
           forms of §6.6.5.3, which allocate only the arms chosen
literals   integers, reals, 'strings', '' escapes, nil,
           [a, b..c] set constructors, and [] the empty set,
           { } and (* *) comments, either pair closing either opening
lexis      §6.1.9's alternative representations: (. and .) for [ and ],
           which are the same tokens and not a second spelling, so
           a[2.) is a legal subscript. @ for ^ is the one alternative
           the clause leaves to the implementation, and is not provided
read       a number read takes the longest prefix that *is* one
           (§6.9.1): 1. is the integer 1 and then a point, .5 is not a
           number, and 2e+ is the integer 2 and then two characters
constants  named constants — a number, a char, a 'string' of any length, or
           another constant's name, optionally signed — plus predefined
           true, false, maxint
```

**This is the whole of ISO 7185.** The last four to arrive were §6.6.5.4's
`pack` and `unpack`, §6.9.5's `page` and §6.3's string constant — each missed
rather than declined, and each found by compiling a probe rather than by a
test, because no program in the corpus had ever written one. What is left of
the language is the next standard, not more of this one.

Two things this compiler is **more permissive** about than ISO 7185, both
deliberate and both stated here because nothing else would notice them.

An **identifier may contain an underscore**, where §6.1.3 makes one `letter {
letter | digit }`. It is how this project spells a name that would otherwise
collide with a word-symbol — `label_`, `set_`, `packed_` — and how a test
program takes the name of its file. Gating it would rename thirteen identifiers
in the stage-1 compiler and the program headers of forty-three test programs,
for a lexical rule that admits no ambiguity; the deviation is one a reader can
see, so it is written down instead.

**Set compatibility ignores packing.** §6.4.5 c) makes two set-types compatible
only if both are `packed` or neither is, and here only the base types are
compared. Every set is one 256-bit word whatever is written, so the two have
the same representation and the check could only reject programs that work —
and the standard does not say what packing a *set-constructor* has, so
requiring agreement would make `s := [1]` depend on how `s` was declared.

This list used to hold the declaration-part order, which is now checked:
§6.2.1's label, const, type, var, procedures is required again under
`--std=iso7185`. Two other deviations were closed at the same time and had
never been on the list at all, which is the more useful thing to know about
them — a constant may not be selected from, §6.8.8 belonging to the next
standard, and `f()` is refused in both standards, Pascal having no empty
argument list. The underscore entry is new here for the same reason. All three
were found by compiling a probe for a clause rather than by a test, and the
packing entry above is a narrower and truer statement of what used to be filed
as "`packed` is accepted on a `set`" — see
[ADR-0072](doc/adr/0072-three-things-the-compiler-accepted-and-neither-standard-has.md).

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

A file need not be an entire variable. §6.5.1's own example is `pooltape :
array [1..4] of FileOfInteger` and §6.5.5's is `pooltape[2]^`, so a file may be
a component of an array or a record, at any depth, and a created variable's
domain may hold one. Each is set up when the block declaring it is entered and
closed when the block exits, exactly as a file variable of its own is. The one
place a file may **not** go is a **variant part**, which §6.4.3.4 permits and
this compiler refuses: the arms share one block of storage, and a file's
storage is not just bytes — the runtime gives it a buffer and a place on the
list of open files — so two arms holding files cannot both be set up at one
address. See
[ADR-0070](doc/adr/0070-a-file-need-not-be-an-entire-variable.md).

Program parameters are the program's only connection to the outside world, as
ISO 7185 §6.10 has it: each is a variable the block declares, `input` and
`output` are the standard streams, and every other one that is a file is bound
to a command-line argument, in the order written. One that is *not* a file is
permitted — §6.10 makes its binding implementation-dependent rather than
restricting the list to files — and is bound to nothing here: an ordinary
variable, taking no argument, so the file parameters keep the positions they
would have had without it
([ADR-0074](doc/adr/0074-a-restriction-the-document-invented-and-a-message-that-explained-nothing.md)).
A file variable that is *not* a program parameter is a scratch file
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
A real written without a width comes out in floating form with twelve fraction
digits (` 5.000000000000E-01`); a width narrows the significand (`write(x:8)`
gives ` 5.0E-01`), and a width with a fraction length gives fixed-point. Under
`--std=iso7185` a width below 1 is itself an error, and stops the program.

**Errors are detected, not ignored.** ISO 7185 calls integer overflow, an array
subscript outside its bounds, a value stored outside a subrange, a `case` whose
selector matches no label, a dereference of `nil`, division by zero — real as
well as integer, and `mod` by a divisor that is not *positive* — `sqrt` of a
negative number, `ln` of one that is not positive, `dispose` of `nil`, `chr` of
a value that is no character's ordinal, `succ` past the end of a type, and
`trunc` of a real too large *errors*; this
compiler stops the program with a message rather than letting it wrap, read
past the array, or produce an arbitrary value:

```
$ pascalc-s0 overflow.pas && ./overflow
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
           the tuple is checked there (§6.2.3.2). `vec2 = vector` gives a
           schema a second name (§6.4.7), and the two denote *one* schema
           rather than alike ones — so `vec2(3)` and `vector(3)` are the
           same type and values move between them
with v     a with-element may possess a type produced from a schema
           (§6.9.3.10), and the statement is then the region over which
           that schema's discriminants are names: `with v do writeln(n)`
           where v is a `vector(3)`, a schematic formal, or a heap variable
           the tuple travelled with. They denote values, not variables
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
           any two of them, `c + d` of two chars included — table 7's
           operands are "Char-type or the canonical-string-type" and the
           clause says *a and b*, so both may be a char and the result is
           a two-character string; = < > pad the shorter with spaces (where
           ISO 7185 required equal lengths); length, index, substr and
           trim answer about one, and eq, ne, lt, gt, le, ge compare
           lengths as well as characters — so `eq('ab','ab  ')` is false
           where `'ab' = 'ab  '` is true, which is the standard's own
           example. '' is the null-string. read(f, s) fills one (§6.10.1):
           it does not skip leading blanks, never crosses an end-of-line,
           and takes at most the capacity — a substring target included.
           A single statement may not concatenate more than the runtime's
           string arena holds, and stops the program if it does
binding    var f: bindable text — a variable that may be bound to
           something outside the program. bind(f, b) attaches it to the
           file named by b.name, unbind(f) detaches it, and binding(f)
           reports both the name and whether it took. BindingType is the
           required record they trade in: a name and a boolean. This is
           the only way a program names a file while it is *running* —
           ISO 7185 binds the program parameters before it starts and
           gives it no other way out
           A program-parameter is bindable without saying so (§6.5.1),
           and binding(p).name is the command-line argument it was given
           (§6.7.6.8) — so a program can read its own command line, and
           an unbound one is how it counts the arguments there were
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
           reach `input` and `output`, or the module-heading may name them
           itself — `module m(output)`. An import-part may head *any*
           block (§6.2.1), not only a module's. A qualified name stands
           wherever a type-name may (§6.11.3): a pointer's domain, a
           restricted type, a type-inquiry's object and either bound of a
           subrange all take `i.t`. §6.13's program-components may be
           translated **separately**: a source that is all modules compiles
           on its own with `-c`, and a component that imports one is given
           it with `--import`, which reads its module-heading. The heading
           is the whole interface (§6.11.1), so there is no second file
           format — what `--import` names is the other component's source
const      const n = base * 2 — a constant-expression: wherever ISO 7185
           asked for a constant, the whole expression grammar is now
           admitted, so a subrange bound, an array bound, a case label, a
           variant label and a schema's discriminants each take one too.
           The operators fold as the emitted code computes them — `mod` is
           non-negative, an overflow is refused rather than wrapped — and
           `abs`, `sqr`, `odd`, `ord`, `chr`, `succ` and `pred` fold with
           them. A real-, set- or string-valued *operation* is not folded: a
           real constant is carried as the text that was written and never
           converted, and building characters or a set in the compiler would
           have to give the same answer in both of them. A string *literal*
           needs no folding and is a constant in either standard, and so is
           `nil` — §6.7.1 makes it an unsigned-constant, and it takes the
           type every pointer assignment will accept, so one `const q = nil`
           serves them all
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
readstr    readstr(e, v1, ..., vn) reads values out of a string as though it
writestr   were a line of a text file, and writestr(s, p1, ..., pn) writes a
           line into one. §6.7.5.5 defines both as `rewrite(f); writeln(f,
           ...); reset(f); read(f, ...)` over an auxiliary text variable, so
           a field width, the spelling of a real and where a string read
           stops all mean exactly what they mean in `write` and `read`. It
           is an error if readstr runs off the end of the string, or if
           writestr writes more than the destination can hold
values     a structured-value-constructor denotes a value of a named array or
           record type: `vec[1: 10; 2..3: 20 otherwise 0]` and
           `pt[x, y: 9]`, with `case kind: box of [w: 6; h: 7]` selecting a
           variant. Every component must be specified exactly once, and the
           `otherwise` gives a value to the ones no element names. §6.8.7.3
           puts the closing `;` outside the alternation, so it may follow a
           variant-part-value as well as a fixed part. A
           component-value may itself be one, so a value nests as the type
           does. An initial-state specifier takes one too, which is what
           makes `array [1..8] of char value [1..8: '*']` eight stars.
           A named *set* type takes the third form, §6.8.7.4's set-value:
           `digits[1, 3..5]` is the set-constructor `[1, 3..5]` with a type,
           and `digits[]` is the empty set of a type that `[]` alone cannot
           name. Its members are checked against that type, so `digits[i]`
           stops the program when i is not a value of the base type — the
           check a constructor with no name on it cannot make
const c    a constant may be structured: `const squares = vec[1: 1; 2: 4]`,
           a record one, or a set one. Its value is fixed at compile time
           and lives in storage the program cannot write to
c[i]       a constant-access selects from one — `c[i]`, `o.x`, `s[1..3]` —
           and §6.8.8.1's NOTE is what it is for: the index need not be
           constant, so `c[i]` in a loop denotes a different value each
           time. Where the index *is* constant the access is a constant
           too, so `third = squares[3]` may then bound an array or label a
           case. Selecting a component of a variant the constant did not
           select is an error, and a constant's tag is known, so it is
           reported at compile time. None of it is a variable: a
           constant-access has a designator's shape and a constant at the
           bottom of it, so assigning to one, passing it as a var parameter
           or reading into it are refused
with c     a with-element may be a constant-access, and the field names it
           introduces then denote values rather than variables
parts      the declaration parts may be written in any order and repeated,
           which §6.2.1 requires — so a constant may name a type, or an
           enumeration constant a type part declared. §6.2.2.9's rule that a
           defining-point precedes its applied occurrences is what decides
           the rest: a variable whose type is defined after it is an error,
           and §6.4.4's pointer domain is still the one exception
minreal    §6.4.2.2 b)'s three required real constants: the largest usable
maxreal    magnitude, the smallest, and the difference between 1.0 and the
epsreal    next value above it. A real is an IEEE-754 binary64 here, so they
           are its largest finite value, its smallest positive normal one,
           and its epsilon. All three are required *identifiers*, so a
           program may declare its own
for..in    §6.9.3.9.3's set-member-iteration: `for v in s do` runs the body
           once per member of s, in ascending order — the standard leaves the
           order to the implementation. The set is evaluated once, an empty
           one runs the body no times, and a control variable narrower than
           the set's base type traps on a member outside it
widths     §6.10.3.1 lowers the least field width from one to zero, and each
           clause under it says what zero writes: nothing for a string, a
           char or a Boolean, the digits for an integer, and a full
           representation for a real, since both real forms clamp. A
           FracDigits of zero still writes the point, and a width below a
           string's length truncates it — which ISO 7185 asked for too
required   maxchar — the largest char; halt — stop the program, closing what
           is open; card(s) — how many members a set has; succ(x, k) and
           pred(x, k) — step k places along an ordinal type, in either
           direction; and the operator >< — set symmetric difference. All but
           `><` are required *identifiers*, so a program may declare its own
time       §6.7.5.8's GetTimeStamp(t) fills a TimeStamp — §6.4.3.4's packed
           record of DateValid, TimeValid, year, month, day, hour, minute
           and second — with the current date and time, or with the
           standard's own fallbacks (January 1, 1 and midnight) and the
           corresponding flag false. §6.7.6.9's date(t) and time(t) then
           yield a string; the representation is implementation-defined and
           here it is ISO 8601, `YYYY-MM-DD` and `HH:MM:SS`. All four names
           are required *identifiers*, so a program may declare its own.
           "Current" is also implementation-defined, and here it is the
           instant SOURCE_DATE_EPOCH names when that variable holds one —
           read as UTC, so a build is reproducible — and the system clock
           otherwise. A value that names no calendar date gives the
           standard's fallbacks with the flags false, rather than quietly
           reverting to the clock
words      otherwise, pow, protected, value, bindable, restricted, module, export,
           import, only and qualified are reserved; `and then`,
           `or else` and `type of` reserve nothing new, because all of
           their words already are. complex, cmplx, polar, re, im and arg
           are required *identifiers* rather than word-symbols, and so are
           seekread, seekwrite, seekupdate, update, extend, position,
           lastposition, empty, string, length, index, substr, trim, eq,
           ne, lt, gt, le, ge, binding, bind, unbind, gettimestamp, date
           and time — so a program may still declare its own. So are
           `interface` and `implementation`:
           §6.1.5 and §6.1.6 make them *directives*, which are identifiers
           in the one position each may occupy, exactly as `forward` is
```

**All of §6.1.2's word-symbols are reserved**, so the lexis is complete even
though the language is not. A word-symbol is reserved only when the feature
needing it lands, and the last of the thirteen Extended Pascal adds arrived
with restricted types; nothing still missing needs a fourteenth, the time
procedures being required *identifiers* rather than word-symbols.

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
| `src/ast.h` | tag-dispatched nodes — an explicit node tag and a checked downcast helper, no C++ RTTI |
| `src/sema.cpp` | scopes, name resolution, type checking, constant folding |
| `src/codegen.cpp` | AST to LLVM IR through LLVM's C++ API; `main` is the program body |
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
python3 verify/verify.py --pascalc build/bin/pascalc-s0
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

[`doc/implementation-defined.md`](doc/implementation-defined.md) is the document
clause 5.1 requires a processor to be accompanied by. It states the compliance
level — **level 0**, conformant array parameters not being accepted — answers
every entry of both standards' annexes of implementation-defined and
implementation-dependent features, names each error this compiler does not
report, and lists the extensions and restrictions. If you want to know what
`maxint` is, what order operands are evaluated in, or what `reset(input)` does,
it is there rather than here.

[doc/glossary.md](doc/glossary.md) defines the terms this codebase uses in a
specific sense — ordinal, designator, type-denoter, static link, tautological
rule — and says which decision governs each.

## Bootstrap plan

The classic three-stage build. Stage 0 is the C++ compiler in this repository;
it only has to be good enough to compile the Pascal-written compiler once.

```
stage 0   pascalc-s0 (C++)       — this repo, grown until it accepts the stage-1 source
stage 1   pascalc1 = stage0(compiler.pas)      this is build/bin/pascalc
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
selfhost/difftest.sh build/bin/pascalc-s0  # also runs under ctest
```

Both write the same three sections, so the comparison is a plain diff:

```
$ build/bin/pascalc-s0 --dump-tokens tests/hello.pas | head -3
1 1 kw program
1 9 ident hello
1 14 op (

$ build/bin/pascalc-s0 --dump-sema tests/hello.pas | head -6
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

The AST is where the bootstrap constraints paid off: the node tag of
[ADR-0005](doc/adr/0005-tag-dispatched-ast-without-cpp-rtti.md) became a
variant record's tag and the downcast helper became the `case` that reads it,
with no `dynamic_cast` to replace and nothing to redesign.

The code generator is the one component that is **not** diffed, and could not
be: the C++ backend builds the module through LLVM's C++ API while the Pascal
one prints assembler text, and LLVM's own printer is not a specification — it
renumbers, reorders and changes between releases. So it is checked by *running*
what it produces, against the same golden output the C++ compiler is held to,
and then by closing the bootstrap:

```sh
selfhost/irtest.sh build/bin/pascalc-s0    # also runs under ctest
```

That compiles every case in `tests/` with the Pascal compiler, links the IR with
`clang`, runs it and compares against `tests/*.out` and `tests/*.err`; then
compiles the compiler with itself twice and requires stage 2 and stage 3 to be
identical. A compiler that reproduced itself and nothing else would pass that
last comparison alone, so stage 2 is put through the golden suite too. See
[ADR-0025](doc/adr/0025-the-code-generator-is-checked-by-running-it.md).

```sh
build/bin/pascalc-s0 selfhost/compiler.pas -o stage1   # = build/bin/pascalc
echo iso7185 > std.txt
: > imports.txt                                    # no imported components
./stage1 selfhost/compiler.pas stage2.ll std.txt imports.txt
clang stage2.ll build/lib/libpasrt.a -lm -o stage2
```

The last two arguments are *files*, not flags: ISO 7185 gives a program no
access to its command line beyond its program parameters, and those are files —
so the Pascal compiler cannot take a `--std` the way the C++ one does
(ADR-0033). The third holds one word, the standard to compile for. The fourth
holds ISO/IEC 10206:1991 §6.13's already-translated program-components,
concatenated, for the same reason: the compiler cannot open a file whose name it
computes, so it is handed one file holding all of them (ADR-0079). It is empty
here and must still exist, because program parameters bind to arguments in
order.

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
* `name.epoch` — one integer, seconds since 1970-01-01 UTC, exported as
  `SOURCE_DATE_EPOCH` so the program's idea of "now" is fixed. Extended
  Pascal §6.7.5.8 leaves the current date and time implementation-defined and
  this compiler defines them from that variable, which is what lets a golden
  file name a date. Without the file the variable is *unset*, so every other
  case runs against the real clock whatever the environment holds.

`tests/run_test.sh` compiles, runs, and diffs. Source paths are rewritten to
`<source>` in stderr, so diagnostics can be pinned without depending on where
the checkout lives.
