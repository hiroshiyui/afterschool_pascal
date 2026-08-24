# Afterschool Pascal

A Pascal compiler, written in Pascal, that compiles itself — conforming to
ISO 7185 and to ISO/IEC 10206:1991 (Extended Pascal), both complete.

**The long-term goal is a Pascal you can get work done in**: a dialect and a
standard core library for the things modern programs actually do — networking,
internationalisation, concurrent execution, and memory safety as a property of
the language rather than a convention.

The two conformance modes are not going anywhere. `--std=iso7185` and
`--std=extended` stay exactly what they are — they are the only part of this
compiler with an external specification, and they are what every check here is
calibrated against. The dialect is a third mode beside them, not a relaxation
of either.

Bootstrapping was the previous long-term goal and it is **done**: the compiler
compiles itself, and stage 2 equals stage 3. It is now a constraint on the order
features can land in rather than a destination.

## Building

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
ctest --test-dir build --output-on-failure
```

Requires `cmake`, a `make`, `clang` and a **C++20 compiler** on PATH, and
**nothing of LLVM's** — no development files, no `LLVM_DIR`. `clang` is wanted
as an assembler and a linker, not as a compiler front end: **the compiler is
written in Afterschool Pascal**, and the one that builds it is
`seed/pascalc.ll`, a working compiler in LLVM IR committed to this repository.
`clang` assembles the seed; the seed translates `selfhost/compiler.pas`; that is
`build/bin/pascalc`, and it compiles itself to a fixed point.

The build produces one other binary, `pascalc-s0`, which is **not a compiler** —
a second front end kept only so the two can be compared. Nothing it produces
ships, and `build/bin/pascalc` does not depend on it. See
[doc/developer-guide.md](doc/developer-guide.md) if you are working on the
compiler rather than with it.

## Using

**`pascalc` writes LLVM IR and stops there.** Neither standard has process
control, so a compiler written in Pascal cannot start an assembler — a property
of the language rather than a shortfall of this one. `tools/pascalcc` is where
the missing half lives, and is what the examples use:

```sh
tools/pascalcc hello.pas               # -> ./hello
tools/pascalcc -o greet hello.pas
tools/pascalcc -S hello.pas            # -> hello.ll, no linking
tools/pascalcc -c hello.pas            # -> hello.o
tools/pascalcc -O0 hello.pas           # -O0..-O3, handed to clang
tools/pascalcc --std=extended hello.pas   # ISO/IEC 10206:1991 instead
tools/pascalcc --std=afterschool hello.pas   # the dialect (ADR-0117)
```

The compiler underneath takes the same flags, and reads them the only way a
Pascal program can: §6.5.1 makes every program-parameter bindable and §6.7.6.8
makes `binding(p).name` the argument it was bound to, so it asks its own
program-parameters what it was invoked with.

```sh
build/bin/pascalc hello.pas                          # -> hello.ll
build/bin/pascalc --std=extended prog.pas -o prog.ll
build/bin/pascalc prog.pas --import counter.pas -o prog.ll
clang hello.ll build/lib/libpasrt.a -lm -o hello     # the half it cannot do
```

ISO/IEC 10206:1991 §6.13 lets a program's components be translated separately.
A source that declares only modules is one, and it becomes an object; the
component that declares the `program` is given the others' *sources*, which is
where their interfaces are written:

```sh
tools/pascalcc --std=extended -c counter.pas -o counter.o
tools/pascalcc --std=extended prog.pas --import counter.pas counter.o -o prog
```

**Every component of one program must be translated under the same `--std`**
(ADR-0119). The two `--std=extended` above are not repetition: a mixture does
not link, and says so —

```
pascalcc: error: module 'counter' was translated under a different --std
```

The dialect's variant rules are a pair — a write activates a variant, a read of
an inactive one traps — and each is emitted at the access, so a component
holding one half without the other checks a tag the other half never stored and
reports an unsafe read as safe. Rebuilding half a program after changing
`--std` used to link and misbehave.

`-S` is an alias for `--emit-llvm`. Four dump flags write a stage and stop —
`--dump-tokens`, `--dump-ast`, `--dump-sema`, and `--dump-all` for all three.
`--dump-limits` is the odd one out: it compiles as usual and then writes how
full the compiler left its own fixed arrays, which is what says how much room a
larger program still has.

```
$ pascalc --std=extended --dump-limits big.pas -o /dev/null
pool 491964 of 1000000
tokens 144756 of 300000
```

`--target=` says which machine the emitted module is for — `x86_64-pc-linux-gnu`
by default, or `aarch64-linux-gnu`. `pascalcc` hands it to `clang` as well, so
with a cross toolchain installed it cross-compiles:

```sh
tools/pascalcc --target=aarch64-linux-gnu -c hello.pas -o hello.o
```

Any other target is refused. The list is short because each entry is a claim
that this compiler's own size and alignment rules have been compared against
LLVM's for that machine, which has been done for those two and no others — and
the comparison is re-run on every build, over every frame size and field
offset the compiler emits.

Set `AFTERSCHOOL_PASCAL_TARGET` instead to point a whole run of `pascalcc` at
one machine without writing the flag each time; an explicit `--target=` wins.

The repository is developed on x86-64 Linux, and the compiler is **built and
tested on arm64 as well**: the same suite runs there natively on every push.
No release ships an aarch64 binary, and `seed/pascalc.ll` is still generated
for x86-64 — but it needs no editing to be used elsewhere: `clang` overrides
the two header lines with the host's, and the compiler that comes out passes
the whole suite.

`--coverage` compiles a program that records which of its own statements ran.
Set `PASCOV_LINES` when running it and the line numbers are appended there, one
per line, for every statement the run reached:

```sh
tools/pascalcc --coverage prog.pas -o prog
PASCOV_LINES=prog.cov ./prog
```

What was *instrumented* is in the IR the same compilation wrote — one
`call void @pas_cov_hit(i32 <line>)` per statement — so the two halves of a
coverage figure come from one artefact and cannot disagree about which lines
were executable.

The generated program links against `libpasrt.a`, built from `runtime/pasrt.c`;
set `AFTERSCHOOL_PASCAL_RUNTIME` to point `pascalcc` at a copy outside the build
tree.

The language is selected per source. **`--std=extended` — ISO/IEC 10206:1991 —
is the default** (ADR-0165); `--std=iso7185` selects the older standard and is
kept for compatibility, because the two are **not** nested: Extended Pascal
reserves word-symbols (`otherwise`, `value`, `only`, …) that a valid ISO 7185
program may use as ordinary identifiers, so an ISO 7185 program with a field
called `value` needs the flag.

**A source can say which standard it is written in**, in a comment before the
program heading, so the flag is not needed on every invocation:

```pascal
{ @std:iso7185 }
program legacy(output);
var value: integer;          { an ordinary identifier under ISO 7185 }
begin value := 7; writeln(value:1) end.
```

`@std:iso7185`, `@std:extended` and `@std:afterschool` are the three spellings.
Only the header counts — an annotation after the first token of the program is
an ordinary comment — and an explicit `--std=` on the command line wins over
it, so a build system that names a standard still gets what it asked for.
`selfhost/compiler.pas` used to be the example of that and is now written in
Extended Pascal itself, because only that standard lets a program read its own
command line.

There is a third: **`--std=afterschool`, the dialect** (ADR-0117), and it is
where the goal at the top of this file will be built. Unlike the first two it
*nests* — it contains ISO/IEC 10206:1991, so every Extended Pascal program is a
valid Afterschool Pascal program meaning the same thing. Nothing forces the
first two apart except the two specifications disagreeing; nothing forces this
one apart at all, because the language is ours.

The containment is the property every later feature is added to, and it is
checked by compiling the whole ISO/IEC 10206:1991 test corpus a second time
under `--std=afterschool` and requiring the same answers. The two conformance
modes are not affected by anything that lands in it — they are the only part of
this compiler with an external specification, and they stay exactly what they
are.

It carries **no stability promise**. The dialect is what the compiler in your
hand defines; a program that needs fixed behaviour should pin a compiler
version. That will change by a decision that says so.

**What it is, clause by clause, is
[`doc/afterschool-pascal-spec.md`](doc/afterschool-pascal-spec.md)** — an
amendment to ISO/IEC 10206:1991, in that standard's own clause numbering, so
each addition sits at the address of the clause it changes. The listing below
is the tour; the specification is the statement, and it is where a requirement
is written precisely enough to be argued with (ADR-0135).

### What it adds so far

**A variant record's tag cannot lie** (ADR-0118). Writing a variant's field
makes that variant active, and reading a field whose variant is not active
traps — so a tagged union is checked rather than merely conventional:

```pascal
type Outcome = (ok, bad);
     Res = record
       case tag: Outcome of
         ok:  (num: integer);
         bad: (msg: string(32))
       end;
var r: Res;
begin
  r.num := 42;        { the write activates ok; no tag assignment needed }
  writeln(r.num);     { fine }
  r.msg := 'nope';    { now bad is active }
  writeln(r.num)      { traps: the tag selects another arm }
end.
```

§6.5.3.3 makes reading an inactive variant an **error**, and §3.1 lets a
processor leave an error undetected — which is what `--std=iso7185` and
`--std=extended` do, conformingly. A correct program never does it, so the
dialect detecting it changes nothing that was already right.

Two limits worth knowing. A write activates only when the arm has exactly one
label — `aa, bb: (i: integer)` cannot decide between them, so it is checked
against the tag instead. And a variant part with **no tag field**, which
§6.4.3.3 permits, has nothing to check against and stays an unchecked union.

**A program can call code this compiler did not emit** (ADR-0121). `external`
follows a procedure or function heading, in the position §6.1.4 gives to
`forward`:

```pascal
function cbrt(x: real): real; external 'cbrt';
procedure srandom(seed: integer); external 'srandom';
```

The foreign name is written out and there is no default, because identifiers
here are case-folded and a linker matches a symbol exactly. `external` is not
a reserved word in any mode — a directive is an identifier in the one position
it may occupy — so a program that uses the spelling for something else is
unaffected. **One linker symbol is one `external` declaration** within a
program-component: a second heading on a name already declared is refused, and
the two names are compared exactly, so `'ABS'` and `'abs'` are different
symbols. Two modules of one program may each declare the same name; they are
translated separately.

**Things cross the boundary by their exact type** — a subrange does not cross,
and neither does `boolean`, a pointer, a set or anything structured. `integer`,
`real` and `int64` cross as values and as a function result; ADR-0122 added the
two address rows:

```pascal
function atoi(s: string): integer; external 'atoi';
function modf(x: real; var ip: real): real; external 'modf';
```

`string` there means `const char *` — a NUL-terminated copy of the value, made
for the statement — and it is **not** a schematic formal: the actual has only
to be a string, so a literal, a variable, a concatenation, a substring or a
char will all do, and the formal states no capacity because a C string carries
its length in-band. A string containing `chr(0)` traps rather than being
truncated. A `var` parameter of `integer` or `real` crosses as the actual's own
address.

**An address crosses only as an argument**, with one exception that is itself
an argument's worth of storage: a returned `char *` may be null, and an
optional is where null now lives (below). A **buffer** crosses as a slice, and
that is ADR-0129 — the entry that used to stand here said it waited on a
language decision, and the decision was ADR-0125's.

libc and libm are already linked, so a foreign call needs no extra build step;
there is no way yet to name another library.

**Nothing checks the declaration against the function it names.** The linker
checks the name and nothing checks the signature, so a wrong type or a wrong
parameter count is undefined behaviour with no diagnostic. What the feature
gives you is that the boundary is *visible*: one directive, the foreign name
beside it, greppable. Everything past it is on you.

**Two foreign names are refused**, and the compiler says so rather than leaving
it to the linker: `main` and `_setjmp`, both of which the emitted module
already declares. LLVM refuses a redeclared global whatever the two say, so
those two spellings are not available to a program. Nothing else in libc or
libm is reserved — `hypot`, `atan2` and `atan` were until the runtime took
private names for them.

**A value may be absent, and the type says so** (ADR-0123). `?T` is a value of
T or nothing:

```pascal
type OptName = ?string(16);
var n: OptName;
begin
  n := nil;                       { absent }
  n := 'hello';                   { present, by ordinary assignment }
  if n <> nil then writeln(n^)
end
```

`nil` is the absent value and `= nil` is the test, so no identifier and no
operator is added; `?` is a character neither standard admits anywhere, so
nothing that compiled stops compiling and `?` in either conformance mode is
still `unexpected character '?'`.

**`o^` is the only way to the value, and it traps when there is none** — the
same check §6.4.4's pointer already has, with the same spelling. Read the other
way round that is the guarantee: a `T` that is not optional can never be
absent. Nothing is assignable *from* an optional, and everything else follows —
`o + 1`, `writeln(o)` and `o < nil` are refused by rules that were already
there. An optional may hold anything but a file and another optional, may sit
in a record or an array, and may be a parameter or a result. The check is not
elided by a guard: `if o <> nil then o^` still makes it.

**And it is how a pointer comes back from C.** ADR-0122 refused every foreign
result that is an address, because a returned `char *` may be null and null is
not a failure. An optional is where null lives:

```pascal
type EnvText = string(4096);
     OptEnvText = ?EnvText;
function getenv(name: string): OptEnvText; external 'getenv';
```

The value is copied at the call site, so **no C pointer ever becomes a Pascal
value** — the program holds a string of its own. The capacity is required and
checked; a value that does not fit is an error, in the words §6.4.6 uses for an
over-long assignment. A bare string result is still refused, and so is
`?integer`: C has no null integer.

**Part of an array can be passed** (ADR-0125). `array of T` is a formal
parameter's type, and a slice carries its own length:

```pascal
function Total(protected var s: array of integer): integer;
var k, t: integer;
begin
  t := 0;
  for k := 1 to length(s) do t := t + s[k];
  Total := t
end;
...
Total(a);          { the whole of it }
Total(a[3..5]);    { three components }
```

Extended Pascal gives a string a substring (§6.7.6.7) and gives an array
nothing, so a routine that wanted part of one had to be handed the whole thing
and two indices — which puts the bounds outside anything that checks them.
**The bounds travel with the pointer**, so `s[k]` is checked against the part
the callee was given.

`array of T` is a syntax error in both standards — §6.4.3.2 requires a
bracketed index-type — so nothing that compiled stops compiling. `a[i..j]` is
the designator §6.5.6 already gives a substring; only the base's type tells the
two apart, and in a conformance mode it still means a substring.

A slice is indexed **1..length** however far into the base it starts, `length`
answers the count, and `a[4..3]` is the empty slice. It is a `var` or
`protected var` parameter and nothing else: not a variable, not a field, not a
result, not a named type — a view of the caller's storage is not a thing that
can outlive the call.

**And a slice is how a buffer reaches C** (ADR-0129). The pair crosses as
`(ptr, i64)` — the address of the first component, then how many there are —
which is the argument shape `read`, `write`, `recv`, `send` and `snprintf` all
take:

```pascal
function PosixRead(fd: integer; var buf: array of char): int64;
  external 'read';
...
n := PosixRead(0, buf[1..5]);      { five bytes, and read is told so }
```

**The program never writes the count.** `PosixRead` has two parameters and
`read(2)` has three: the length C receives is the one the compiler computed
from the designator and checked against the array, so a buffer overrun is not
something a caller can spell. That is the opposite of what an FFI usually does
to a bounds property.

The component may be `char`, `integer`, `int64` or `real`, and the list is not
the one above because a slice is storage the callee **writes**: a subrange
would come back unchecked, and 254 of a byte's patterns are not values of
`boolean`. `char` is admitted here and refused as a value for a reason that is
about the register convention and not about the byte — in memory the type has
no bit pattern that is not a value of it. Note that a count is components and
C's is bytes, so binding `read` to an `array of integer` asks for a quarter of
what it looks like.

A C function whose length does not immediately follow its pointer — `memcpy`,
or anything spelled `(size_t n, void *p)` — cannot be bound with a slice, and
there is no bare-address escape hatch.

**An integer twice as wide** (ADR-0128). `int64` is the type a `size_t` and an
`ssize_t` cross the boundary as, and it is the other half of the data path the
slice above is one half of:

```pascal
function llabs(x: int64): int64; external 'llabs';
var n: int64;
begin
  n := 5000000000;              { a literal above maxint is where it begins }
  writeln(n * 2, ' ', maxint64)
end.
```

It is a **numeric** type and not an ordinal one, and everything else follows
from that. It answers where `real` answers — the arithmetic and relational
operators, `abs`, `sqr`, and the widening from `integer` — and it is refused
wherever an ordinal is wanted: no case label, no array index, no subrange
bound, no set base, no `for` control variable, no `succ`, `pred`, `ord`, `odd`
or `chr`. `trunc` is the one way back to `integer`, and it traps outside
`-maxint..maxint`, which is §6.6.6.3's own error condition.

The reason for the shape is the compiler: `selfhost/compiler.pas` is written in
this language, so its own integers are 32 bits and it has no value of the wide
type to hold. A literal is carried as the **text** that was written, all the way
into the IR — which is what a real literal has done since the beginning, for the
same reason.

**So a constant cannot have this type** (ADR-0136): a symbol has nowhere to keep
text, and `const c = 5000000000` is refused, naming the type and the remedy.
Assign the literal to a variable, as above. Every position that wants an ordinal
refuses it for the older reason and says so in the words it always used.

Overflow traps as `integer`'s does, at both ends: `-maxint64..maxint64` is the
type, so the machine word's least value is not one of its values.

**The command line as a list** (ADR-0173). `argcount` is how many arguments
the program was given and `argument(k)` is the `k`-th, a string:

```pascal
program echo(output);
var k: integer;
begin
  for k := 1 to argcount do writeln(k:1, ': ', argument(k))
end.
```

Neither standard gives a program its arguments except one file variable at a
time through `binding(p).name`, which is still there and names the same list.
Both are required identifiers and so shadowable: a program with its own
`argument`, or its own `argcount`, keeps it. `argument(k)` outside
`1..argcount` stops the program.

**A handle is an owned foreign address** (ADR-0174). A `FILE *` or a `DIR *`
comes back from a foreign routine and the type says what releases it:

```pascal
type Dir = handle external 'closedir';
function ExtOpendir(path: string): Dir; external 'opendir';
var d: Dir;
begin
  d := ExtOpendir('.');          { the one assignment a handle has }
  if d <> nil then writeln('open')
end.                             { closedir runs here, as a file closes }
```

It has a file variable's rules, through the same predicate: no copy, no
comparison but with `nil`, released when the variable dies — at the block's
end, on a `goto` out of it, on `halt`, on `dispose`. Assigning another value
releases the old one first. That assignment is the **only** place such a call
may stand — anywhere else there would be nothing to own what it answered —
and a parameterless one written as a bare name is that call, in the one
position it may stand and in none of the others. A handle may be lent to a
foreign routine as a value parameter, and lending an empty one stops the
program. What it is not is a value: no Pascal function returns one and no
record copies one.

**A fallible type is a value or the reason there is none** (ADR-0176). `T ! E`
is the record a module used to write per payload type, with the field names
fixed by the language:

```pascal
type IntResult = integer ! ErrorCode;

function ParseInt(s: string) = r: IntResult;
begin
  if bad then r := errSyntax      { the value's type says which outcome }
  else r := n
end;

r := ParseInt(s);
if r.ok then writeln(r.val:1) else writeln(ErrorText(r.cause))
```

`ok` says which outcome was written, `val` is the value and `cause` the
reason, and **reading the arm the tag does not select stops the program** — so
a caller who does not check gets a halt rather than a stale value. The tag is
read-only: it says what was assigned, and nothing else may set it. Neither
side may be a fallible type, nor hold a file or a handle. Assigning a value
both sides admit is refused where it is written, since it names no outcome.

**`defer` runs a statement on the way out** (ADR-0175). Written beside the
thing it undoes, and correct at every exit the block has:

```pascal
procedure work;
var v: StrVecPtr;
begin
  SVecNew(v, 16);
  defer SVecFree(v);        { runs at the end of the block, on a goto out of
                              it, and on halt }
  …
end;
```

It arms a statement rather than registering a call, so nothing is evaluated
until it runs. What it is armed in is the **statement-sequence** — a compound,
a repeat-body, a case-completer — so a `defer` in a loop body runs at the end
of each iteration, with that iteration's values; several armed in one sequence
run in the reverse of the order they are written. Armed statements run before
the block's files and handles are closed, so a deferred statement may still
write to one. A deferred statement may not contain a label, a `goto` or
another `defer`, and `defer` is nobody's word: a program that declares one
keeps it in every position a conforming program could have written it.

**`exit` leaves the block early** (ADR-0177), which no standard Pascal has and
every widely used one does:

```pascal
function FirstAbove(n: integer): integer;
var k: integer;
begin
  for k := 1 to 100 do
    if k * k > n then exit(k);      { the guard clause, written as a guard }
  FirstAbove := 0
end;
```

It terminates the activation of the block it stands in — never an enclosing
one — and `exit(e)` first assigns `e` to that block's function result, which
counts as the assignment §6.7.2 asks every function for. Where the result is a
fallible type the value picks the arm, so `exit(errSyntax)` is a failure and
`exit(n)` is a value. Terminating an activation is not `halt`: the armed
statements run, the block's files and handles close, and in the main program
the module finalizations still run. `exit` is nobody's word either — a program
that declares one keeps it — and a deferred statement may not contain one.

**`try` propagates a failure** (ADR-0178), which is what a fallible type was
missing and what `exit` was landed for:

```pascal
function ReadConfig(path: PathName): TextResult;
var body: string(4096);
begin
  body := try(PasFS.ReadAll(path));   { or leave, with the cause }
  ReadConfig := Parse(body)
end;
```

`try(x)` is `x.val` where `x` succeeded. Where it did not, the cause is
assigned to the enclosing function's result and that activation terminates —
so everything `exit` does on the way out happens here too: the armed
statements run and the block's files and handles close. The enclosing result
does not have to be a fallible type; it has to be something the cause can be
assigned to, so a function answering the error type takes it directly. It may
stand only in a function, the operand is evaluated once however many times its
value is read, and `try` is nobody's word — a program that declares one keeps
it. A deferred statement may not contain one.

A binding is a module that exports Pascal and keeps the directive to itself —
`lib/dialect/pasmathx.pas`, `lib/dialect/pasfs.pas`, `lib/dialect/pasenv.pas`,
`lib/dialect/pasio.pas` and `lib/dialect/pasos.pas` are the five, and they are
what a caller sees instead. `lib/dialect/passtream.pas` is the first binding
over a handle: a `Stream` the caller declares and the module fills, so what a
program holds is a variable that closes itself and never the address.

**The runtime has a second surface**, and it is one routine wide (ADR-0131).
`pas_` names are what the compiler emits calls to and are refused as foreign
names; `pasx_` names are what a *program* may bind, and `pasx_errno` is the
only one. It exists because C specifies `errno` as a **macro**, so it has no
linker symbol any foreign-function interface could name.

## The standard library

`lib/` holds the beginning of one (ADR-0114). It is ordinary Extended Pascal —
§6.11 modules, translated separately as §6.13 program-components — so it needed
no compiler change and changes nothing about what either conformance mode
accepts. Eight modules so far:

| Module | What it has |
| --- | --- |
| `lib/passtrings.pas` | `Upper`, `Lower`, `StartsWith`, `EndsWith`, `IndexOf`, `PadLeft`, `PadRight`, `Times`, `Reverse`, `Replace` |
| `lib/passort.pas` | `SortIndexed` and `LowerBound` over positions, `SortInts` over an integer array, and the `IntVector` schema |
| `lib/pasmath.pas` | `IMin`, `IMax`, `Gcd`, `Lcm`, `ISqrt`, and a seedable Lehmer generator |
| `lib/pasvector.pas` | `IntVec`, a growable sequence: `VecNew`, `VecPush`, `VecPop`, `VecGet`, `VecSet`, `VecReserve`, `VecFill`, `VecSum`, `VecFree` |
| `lib/pasmap.pas` | `StrMap`, a `string(32)`-keyed dictionary: `MapPut`, `MapGet`, `MapHas`, `MapDelete`, and `MapSlots`/`MapLiveAt` to walk it |
| `lib/pastext.pas` | `Split`, `Join`, `TrimStart`, `TrimEnd`, `TrimAll`, `CountChar`, `TryParseInt`, `ParseIntOr`, `IntToStr` |
| `lib/pasfile.pas` | whole files by name: `FileExists`, `LineCount`, `ReadLine`, `ForEachLine`, `ReadAllText`, `WriteAllText`, `WriteLine`, `AppendLine`, `AppendText`, `CopyFile` — every reader answers **false** for a file that is not there rather than stopping, which is what ADR-0172's `binding(f).bound` made possible in conforming Pascal |
| `lib/passtrvec.pas` | `StrVec`, a growable sequence of `string(255)`: `PasVector`'s interface under `SVec` names, plus `SVecIndexOf`, `SVecSort`, `SVecJoin` and `SVecSplit`. `PasFile.ForEachLine` with a nested procedure is how a file's lines become one |

**`lib/dialect/` is a second layer, and it does not mix with the first**
(ADR-0120). Its modules are `--std=afterschool` all the way down, so only a
dialect program can link them — `--std` is part of a module's linkage name and
a mixture is refused (ADR-0119).

| module | what it is |
| --- | --- |
| `lib/dialect/paserror.pas` | `ErrorCode` — six categories — with `ErrorText` and `Failed` |
| `lib/dialect/pasparse.pas` | `ParseInt`, answering an `IntResult` that carries the value **or** the reason |
| `lib/dialect/pasmathx.pas` | `Cbrt`, `Log10`, `Log2`, `FMod`, `RealOr` — libm through `external`, with a `RealResult` where the answer can fail |
| `lib/dialect/pasfs.pas` | `Remove`, `Rename`, `MakeDirectory`, `RemoveDirectory`, `Exists`, `WorkingDirectory`, `LinkTarget`, `PathOr` — the file system through `external`, answering an `ErrorCode` or a `PathResult` |
| `lib/dialect/pasenv.pas` | `Lookup`, `LookupOr`, `Defined`, `Define`, `Undefine` — the environment, where an unset variable is `nil` and one set to nothing is not |
| `lib/dialect/pasio.pas` | `OpenRead`, `Close`, `ReadInto`, `WriteFrom`, `WriteAll`, `WriteText`, `AtEnd` — descriptor I/O through `external`, on ADR-0129's buffer. It reads files and writes to descriptors already open: creating one needs `O_WRONLY` and `O_CREAT`, which are header numbers this FFI cannot see — `PasStream` is where to create one |
| `lib/dialect/pasos.pas` | `LastErrorNumber`, `LastErrorText`, `ErrorNumberText` — why the last call failed, in libc's own words. It gives the sentence and not a classification: ENOENT and EACCES are header numbers this compiler cannot read |
| `lib/dialect/pasprocess.pas` | `Run` — a command through the shell, answering its exit code or `errIO` — `Capture` and `CaptureLines`, its output into a string or onto a `StrVec` with the code beside it, `ExitCode`, `Sleep`, `Seconds` and `CpuSeconds`. `Run` flushes the program's own output first, so what was written before the command comes out before it |
| `lib/dialect/passtream.pas` | `Stream`, a handle over `fopen` — `OpenRead`, `OpenWrite`, `OpenAppend`, `Close`, `WriteText`, `WriteLine`, `ReadLine`, `Flush`. The file creation `PasIO` could not do, and the first module built on ADR-0174: the stream is closed when its variable dies |

The trade is stated rather than hidden: the layers duplicate, because
`ParseInt` cannot call `PasText.TrimAll`. What it buys is that a caller who
forgets to check does not get a stale value —

```pascal
r := ParseInt('not a number');    { r.code := errSyntax, and the tag with it }
writeln(r.num:1)                  { traps: the tag does not select num }
```

— where `TryParseInt` hands back an integer that was never parsed. Nothing
assigns `r.ok`: the write to the payload is what sets it.

Use one the way §6.13 asks: translate it, then hand the program its *source*,
which is where the interface is written.

```sh
tools/pascalcc --std=extended -c lib/passtrings.pas -o passtrings.o
tools/pascalcc --std=extended prog.pas --import lib/passtrings.pas passtrings.o -o prog
```

Strings are passed by value, so an argument may be a literal, another
function's result, a concatenation, or a string of any capacity:

```pascal
var s: Line;
begin
  s := 'Hello, World';
  writeln(StartsWith(s, 'Hello'));
  writeln(Upper(Reverse(s)))
end.
```

Neither of those lines compiled when the library was written: a variable-string
could not be a value parameter, so every string formal was `protected s: string`
and every actual had to be a *variable*. ADR-0115 fixed that, and the library's
own test was rewritten to the form above **without its golden changing** — same
answers, and the interface stopped documenting a compiler defect as a house
style.

**An exported function may name its own result.** §6.8.2.2 makes every *read*
of the function identifier a recursive call, so accumulating into it is not
available; the other way is a result-variable-specification, and until
`ab8d125` it was refused for an exported function, §6.11.1 making every module
heading a `forward` and the name in the heading not reaching the body. §6.7.2
puts that name's defining-point in "the block of the function-block, **if
any**, associated with the identifier of the function-heading" — the same words
the clause uses one paragraph later of the formal-parameter-list, which has
always reached a forward body. So this compiles now, and an exported function
no longer has to accumulate into a local:

```pascal
function Upper(s: Line) = r: Line; forward;   { r names the result }

function Upper;
var k: integer;
begin
  r := '';
  for k := 1 to length(s) do
    r := r + Cap(s[k])          { reading r is not a recursive call }
end;
```

**A container is a pointer, and growth replaces it** (ADR-0116). A schema is
chosen once — `var v: IntVec(n)` fixes `n` at the declaration — so anything
whose size changes lives on the heap, and every routine that may grow takes a
`var` pointer:

```pascal
var v: VecPtr;
begin
  VecNew(v, 4);
  VecPush(v, 10);          { may reallocate, so `v` is passed by reference }
  writeln(VecGet(v, 1):1);
  VecFree(v)
end.
```

**The element type is written out, and copying the file is the answer for
another one.** `PasVector` holds integers and `PasMap` maps `string(32)` to
integers. `PasSort` avoids this by phrasing itself over *positions* and never
seeing an element, but a container holds the elements, so their type is part of
its layout — and a schema parameterises a type by a value, never by another
type. That is a real limitation, recorded rather than worked around.

**No container takes an allocator**, though the roadmap expected one to. An
allocator record is not expressible — a record field may not have a procedure
type — and while a per-type allocator *parameter* compiles, it can only recycle
blocks `new` produced, because `new` is the only origin of a typed pointer and
there is no pointer arithmetic. Worse, the capacity it serves is unchecked: a
pool asked for 9 may return a block of 4, and `p^.cap` then reads 4. What the
caller gets instead is control over *when* — `VecNew` sets the initial capacity
and `VecReserve` grows once so that no later push reallocates.

**There is no install location and no resolution by name.** `--import` takes a
path, so a program outside this checkout names paths into it, and `maxImports`
bounds one program at eight components. Sockets, locales, threads and containers
are still absent, and the reason has moved again for three of them: the
foreign-function interface they waited on **exists** (ADR-0121) and a string
now crosses it (ADR-0122). A string now comes back too
(ADR-0123), ADR-0125 gives the language the buffer shape a socket needs,
ADR-0128 the 64-bit integer an `ssize_t` comes back as, and ADR-0129 puts the
two together: `read`, `write`, `recv` and `send` are bindable, every word of
them. And a failure's *reason* is readable: ADR-0131 puts `errno` in the
runtime, because C makes it a **macro** with no symbol to bind, and `strerror`
needed nothing new — a `char *` result is what ADR-0123 already receives. The
code a binding module answers stays `errIO`, classifying one needing header
numbers.

`getcwd` and `readlink` are bound too, and needed nothing built (ADR-0132):
they write into a buffer the **caller** owns, so the slice lends the storage
and the optional copies the answer back. A returned pointer that is the
caller's own storage coming home has no ownership question in it, which is the
same distinction ADR-0122 drew for arguments.

What is left is a pointer to storage the **callee** owns whose contents are
not characters — a `DIR *` you must hand back to `closedir`, a
`struct sockaddr *` with a layout C fixes and this compiler would have to agree
with. That is where the memory-safety model actually bites, and it is what
stands between here and a socket. A container waits on something else entirely —
parameterising a type by a type, which schemata do not do. `doc/roadmap.md` has
the ordering, and `doc/history.md` has each increment that got this far.

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
           procedural and functional parameters, congruity-checked,
           array [u..v: T] of C — conformant array parameters (level 1),
           packed and unpacked, nested, and the abbreviated form
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

**This is the whole of ISO 7185, at level 1.** Conformant array parameters —
§6.6.3.6 e), §6.6.3.7 and §6.6.3.8 — were the last of it, and are the whole of
the difference clause 5.1 a) draws between the two levels; before them this was
a level 0 processor, which is a complying level rather than a shortfall. The
four before that were §6.6.5.4's `pack` and `unpack`, §6.9.5's `page` and
§6.3's string constant — each missed rather than declined, and each found by
compiling a probe rather than by a test, because no program in the corpus had
ever written one. What is left of the language is the next standard, not more
of this one.

One thing this compiler is **more permissive** about than ISO 7185, deliberate
and stated here because nothing else would notice it.

An **identifier may contain an underscore**, where §6.1.3 makes one `letter {
letter | digit }`. It is how this project spells a name that would otherwise
collide with a word-symbol — `label_`, `set_`, `packed_` — and how a test
program takes the name of its file. Gating it would rename thirteen identifiers
in the stage-1 compiler and the program headers of forty-three test programs,
for a lexical rule that admits no ambiguity; the deviation is one a reader can
see, so it is written down instead.

This list used to hold the declaration-part order, which is now checked:
§6.2.1's label, const, type, var, procedures is required again under
`--std=iso7185`. Two other deviations were closed at the same time and had
never been on the list at all, which is the more useful thing to know about
them — a constant may not be selected from, §6.8.8 belonging to the next
standard, and `f()` is refused in both standards, Pascal having no empty
argument list. The underscore entry is new here for the same reason. All three
were found by compiling a probe for a clause rather than by a test.

It also used to hold **set compatibility ignoring packing**, and that entry was
wrong rather than merely out of date. It was justified by the claim that the
standard does not say what packing a set-constructor has; §6.7.1 says exactly
that, in a sentence both standards carry word for word, and the claim had been
copied into three documents and a test written to hold the compiler to it.
§6.4.5 c) is checked now.

Enumerations and subranges are ordinal types like `char`: they index arrays,
drive `for` loops, answer `ord`/`succ`/`pred`, and select `case` arms. `succ`
runs out at the end of its own type — at `blue`, or at 9 for a `1..9` — not at
`maxint`. A record may have a variant part, tagged or not, which is what makes
a tag-plus-variant AST node expressible.

A set is one 256-bit word — a bit per possible member — so its base type's
values must lie in 0..255, and `set of integer` is refused rather than
truncated. That makes a set a *value*: it is assigned, compared and passed
exactly as an integer is, and the operators are one instruction each. Set
compatibility is decided on the base type structurally, which is ISO 7185's own
departure from the name equivalence it gives every other structured type.

Arrays and records assign whole (`b := a` copies every component), pass as
value parameters by copy and as `var` parameters by reference, and nest freely
in each other. A string literal has the type ISO 7185 gives it — `packed array
[1..n] of char` — so it assigns to, compares with, and passes as a variable of
that type with no special case anywhere.

Two types are the same only when one type identifier denotes both, as
ISO 7185 §6.4.5 requires, so two separately written `array [1..3] of integer`
are different types.

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
claims it is.

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
place a file may **not** go is a **variant part**, which ISO 7185 §6.4.3.3 and
ISO/IEC 10206:1991 §6.4.3.4 — the same clause under two numbers — both permit
and this compiler refuses: the arms share one block of storage, and a file's
storage is not just bytes — the runtime gives it a buffer and a place on the
list of open files — so two arms holding files cannot both be set up at one
address.

Program parameters are the program's only connection to the outside world, as
ISO 7185 §6.10 has it: each is a variable the block declares, `input` and
`output` are the standard streams, and every other one that is a file is bound
to a command-line argument, in the order written. One that is *not* a file is
permitted — §6.10 makes its binding implementation-dependent rather than
restricting the list to files — and is bound to nothing here: an ordinary
variable, taking no argument, so the file parameters keep the positions they
would have had without it.
A file variable that is *not* a program parameter is a scratch file
with no external name. Files are closed when the block declaring them exits,
which is the standard's own rule and needs no `close`. Using `write` without
`output` in the program header is an error, because §6.10 says it is.

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
the first has lines.

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
$ tools/pascalcc overflow.pas && ./overflow
runtime error: integer overflow in sqr
```

The integer type is `-maxint..maxint`, which is narrower than the machine word
it lives in — so `2147483648` is rejected at compile time rather than silently
becoming `-2147483648`.

The last of ISO 7185 to arrive was the non-local `goto`, which leaves a block
rather than a statement: the target's activation record carries somewhere to
jump back to, and the jump closes the files of every block it abandons — the
work those blocks' own exits would have done.

One implementation limit: nesting deeper
than 1000 levels — parentheses, statements, type denoters, blocks, or the
depth of the *tree* an operator chain builds — is a compile-time error rather
than a stack overflow, in the parser or in any walk after it. A program's own
block is one of those levels, so 999 remain inside it.

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
           the tuple is checked there (§6.2.3.2). A plain subrange bound may
           be a variable in the same place — `var a: array [1..m] of real`
           inside a procedure, sized on entry and bounds-checked against what
           the entry computed. Either end, both ends, an expression rather
           than a name, and at more than one level (§6.4.2.4, §6.2.3.8 b).
           A **type-definition** of a procedure may have one too —
           `type t = array [1..m] of integer` and `type t = vector(m)` — and
           the bound is evaluated **once** for the type however many variables
           of it the block declares, so two of them are one type with one
           extent and `a := b` between them is an assignment.
           `vec2 = vector` gives a
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
           protected, because protecting either would protect nothing.
           A conformant array parameter is a variable parameter like any
           other here, in both directions: it may say `protected` itself,
           and a protected variable may not be handed to one that does not
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
           one, as may a discriminated schema: `var t: string(4) value
           'jk'`. The value must read nothing that can change — a literal,
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
           string arena holds, and stops the program if it does.
           A string value may be assigned to a char: c := s[2..2],
           and the null-string gives a space (6.4.5 d), 6.4.6 f))
           `procedure p(s: string)` takes any string *expression* --
           a literal, a char, a constant, a concatenation, a function
           result -- and the formal's capacity is the length of the
           value it was handed (§6.7.3.2), not the capacity of the
           variable it came out of
           A `packed array [1..n] of char` value parameter takes any
           string expression too, and pads it: §6.7.3.2 holds the actual
           to assignment-compatibility, so `p('abc')` for a formal of
           capacity 5 hands over 'abc  ' -- the same rule, and the same
           padding, that `f := 'abc'` has always followed. An actual
           longer than the capacity stops the program (§6.4.6 c))
           read(f, s) at end of *file* stops the program (D.97); at end
           of line it reads nothing and answers with the null-string
binding    var f: bindable text — a variable that may be bound to
           something outside the program. bind(f, b) attaches it to the
           file named by b.name, unbind(f) detaches it, and binding(f)
           reports both the name and whether it took. BindingType is the
           required record they trade in: a name and a boolean. This is
           the only way a program names a file while it is *running* —
           ISO 7185 binds the program parameters before it starts and
           gives it no other way out
           Bindability belongs to the variable-access, so a bindable
           *field* and a bindable array *component* may each be bound:
           bind(r.log, b) and bind(pool[i], b) (§6.4.3.4, §6.4.3.5)
           A program-parameter is bindable without saying so (§6.5.1),
           and binding(p).name is the command-line argument it was given
           (§6.7.6.8) — so a program can read its own command line, and
           an unbound one is how it counts the arguments there were
           A bindable variable may not be a `for` statement's control
           variable (§6.9.3.9.1), and `bind` here needs a *file* variable:
           §6.7.5.6 admits any bindable one, and that restriction is
           recorded in `doc/implementation-defined.md` §6
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
           them, and so do `succ(x, k)`, `pred(x, k)`, `length` and
           `index` — the last is what §6.3.2's own example needs, whose
           closing line is
           `hex_alpha = hex_string[index(hex_string,'A')..index(hex_string,'F')]`.
           A real-, set- or string-valued *operation* is not folded: a
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
           one the body must assign it at least once. A parameterless one is
           called by writing its name — Pascal has no empty argument list —
           and that bare name is the call in every position the written-out
           one stands in, a value parameter included
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
           types, and a restricted type is nonbindable. §6.4.3.4 keeps it out
           of a **variant part**, at any depth, and keeps a bindable
           type-denoter out of one too
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
           is open, and halt(n) to stop with exit status n, which is an
           extension because neither standard models one at all and a
           Pascal program otherwise cannot report failure;
           card(s) — how many members a set has; succ(x, k) and
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

**All of §6.1.2's word-symbols are reserved**, and the lexis was complete before
the language was: a word-symbol is reserved only when the feature needing it
lands, and the last of the thirteen Extended Pascal adds arrived with restricted
types. Nothing needed a fourteenth, the time procedures being required
*identifiers* rather than word-symbols.

**This is the whole of ISO/IEC 10206:1991.** §6.13's separately translated
program-components were the last clause, and the claim is not an
impression: Annex A's 274 productions were probed in both directions,
both Annex Ds' errors, Annexes E and F's 80 implementation-defined and
-dependent features, and Annex C's 94 required identifiers — each with a
program compiled and run rather than with a reading. `doc/history.md` records
what each sweep found; the tag `iso-10206-1991-done` is where it was settled.

**One position of it is refused**: a subrange whose bounds are not constants,
as a **set's base type**. Every set here is one 256-bit word whose base type
must have its values in 0..255, and a bound the block evaluates cannot be
checked against that before the program runs — the limit `set of integer`
already states, reached another way. Everywhere else the bound works:
`var x: 1..m`, `type t = 1..m` and `array [1..m] of 1..m` since ADR-0133, and a
record's field and a file's component since ADR-0134.
`doc/implementation-defined.md` §6 states it with the clause.

## What backs the answers

A compiler is the one program whose bugs are inherited by everything it builds,
and a miscompilation is silent — the source is right, the test is right, the
answer is wrong. So the arithmetic this compiler emits is **proved** correct
rather than sampled: forty-six rules under Z3, thirty of them for all 2³²
inputs and seven of those at 64 bits too, each stating what ISO 7185 requires
of a result as a *property* and
asking whether any input makes the emitted code disagree. Every run-time check
is proved to fire exactly when the standard says the operation is in error —
both directions, since trapping always would satisfy one of them. There are
currently **no known gaps**.

Beside that: 637 cases under `ctest`, the compiler compiled with itself to a
fixed point, scenarios written against clauses of the two standards, and the
1982 BSI Pascal Validation Suite. What none of it sees is written down rather
than left to be discovered — `doc/sop.md` §7 keeps that list.

[doc/developer-guide.md](doc/developer-guide.md) has the whole of it, including
how to run the proofs.

## Documentation

[`doc/implementation-defined.md`](doc/implementation-defined.md) is the document
clause 5.1 requires a processor to be accompanied by, and it is the one to read
next if you are *using* this compiler. It states the compliance level —
**level 1**, conformant array parameters being accepted — answers every
entry of both standards' annexes of implementation-defined and
implementation-dependent features, names each error this compiler does not
report, and lists the extensions and restrictions. If you want to know what
`maxint` is, what order operands are evaluated in, or what `reset(input)` does,
it is there rather than here.

[doc/glossary.md](doc/glossary.md) defines the terms these documents use in a
specific sense — ordinal, designator, type-denoter, static link, tautological
rule — and says which decision governs each.

[doc/developer-guide.md](doc/developer-guide.md) is for working on the compiler:
the repository layout, the bootstrap, how each part is checked, and how to add a
test.

**Why any of it is the way it is** is in [doc/adr/](doc/adr/) — one record per
decision, what it costs, and the alternatives that were rejected; the index
lists all of them by title. [`doc/design-digest.md`](doc/design-digest.md) is
the condensed form, a paragraph per mechanism. Nothing above cites a record by
number: this document says what the compiler does, and those say why.

## Licence

**GNU General Public License, version 3 or later.** `LICENSE` carries the text;
`Copyright (C) 2026 Hui-Hong You`.

**The runtime carries an exception, and it is the part most people need.**
`runtime/pasrt.c` is linked into every program this compiler builds — it holds
the formatted output, the file machinery and the run-time checks ISO 7185
requires, none of which can be expressed in the emitted IR. Without an
exception, compiling an ordinary Pascal program with `pascalcc` would place
that program under the GPL. It does not:

> As a special exception, if you link the Runtime Library with other files to
> produce an executable, that does not by itself cause the resulting executable
> to be covered by the GNU General Public License.

`COPYING.RUNTIME` has the full wording and the reasoning. **Your programs are
yours** — the IR `pascalc` writes is derived from your source rather than from
the compiler, so it was never covered in the first place.

**The compiler itself has no such exception.** `selfhost/compiler.pas`,
`tools/pascalcc`, the build files and the proofs in `verify/` are GPLv3-or-later
outright: modify the compiler and distribute it, and your changes travel under
the same terms. `seed/pascalc.ll` is the compiler in another form — generated
from `selfhost/compiler.pas`, which is the corresponding source the GPL asks
for, and committed beside it.

**Two things in this repository are not covered by it, and neither is
distributed.** The BSI Pascal Validation Suite is *(C) Copyright 1982, British
Standards Institution*, used under terms that grant use and **not**
redistribution — `tests/bsi/README.md` states all three conditions, and
`tests/bsi/fetch.sh` puts it in a gitignored directory for that reason. The
standards themselves live in `doc/vendor/`, also gitignored. Nothing in either
place is ours to relicense.
