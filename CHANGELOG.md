# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
follows [Semantic Versioning](https://semver.org/).

The public interface of a compiler is **the accepted language, the diagnostics
and the command line**. That is what these entries describe and what the version
number tracks.

Entries for a released version are left as they were written, so `pascalc-s0`
appears below in the release where it still existed.

## [Unreleased]

### Added

- **`external` — a foreign function, under `--std=afterschool` only**
  (ADR-0121). A program can now call code this compiler did not emit, which
  is what the whole outward-facing half of ADR-0109 was waiting on: sockets,
  clocks, locales and ADR-0116's allocator convention are all behind it.

  ```pascal
  function cbrt(x: real): real; external 'cbrt';
  procedure srandom(seed: integer); external 'srandom';
  ```

  The word sits where `forward` does, so it is an *identifier* in that one
  position (ISO 7185 §6.1.4, ISO/IEC 10206:1991 §6.1.4) and nothing is
  reserved — a program that names a variable `external` is untouched, in every
  mode. The foreign name is a string-literal and there is no default: this
  lexer case-folds identifiers and a linker matches a symbol exactly, so
  deriving one from the other would be a lossy mapping to a name that has to
  be right.

  **Two types cross the boundary: `integer` and `real`.** They are the two the
  C ABI on this target needs no parameter attribute for, which was settled by
  probing `clang` rather than by reading — a `char` is passed `i8 signext` and
  disagrees with §6.4.2.2's 0..255 about the sign bit, and a `bool` is passed
  `i1 zeroext` as a `_Bool` few C interfaces take. Value parameters only, and
  the test is on the **exact** type: `1..9` does not cross, because nothing on
  the other side promises a value is in range.

  `tools/pascalcc` already links libc and libm, so a first foreign call needs
  no build change and there is no `-l` surface yet.

  **Nothing checks the declaration against the function it names.** The linker
  checks the name; nothing checks the signature. The boundary is *visible* —
  one directive, the foreign name written out — and that is the only property
  claimed for it.

  Neither conformance mode accepts it, and ADR-0119 then makes an
  `external`-using module unimportable by a conformance-mode program: so the
  outward-facing library is dialect-only, permanently, and `lib/`'s existing
  modules stay Extended Pascal that any conforming processor can take.

- **`?T` — an optional type, under `--std=afterschool` only** (ADR-0123). A
  value of T, or nothing, and the language's first way of saying "there may be
  nothing here" without inventing a convention per routine.

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
  operator is added. `?` is a character neither standard admits anywhere, so
  the lexis costs nothing and no program that compiled stops compiling — in
  either conformance mode `?` is still `unexpected character '?'`.

  **`o^` is the only way to the value, and it traps when there is none.** That
  is the guarantee read the other way round: a `T` that is not optional can
  never be absent. Nothing is assignable *from* an optional, which is the whole
  of the type discipline — two lines, and `o + 1`, `writeln(o)` and `o < nil`
  are then refused by rules that were already there.

  An optional may hold any type that is not a file and not itself an optional,
  including a record, an array or a string; it may sit in a record or an array,
  and it may be a parameter or a function result. It is name-equivalent like
  every other structured type (ADR-0017): two separately declared `?integer`
  are two types.

  The check is **not** elided by a guard — `if o <> nil then o^` still emits
  it. What the type localises is *where* the check is, not whether it happens.

- **A foreign function may return an optional string** (ADR-0123), which lifts
  ADR-0122's refusal of the result direction exactly as far as null now has
  somewhere to live.

  ```pascal
  type EnvText = string(4096);
       OptEnvText = ?EnvText;
  function getenv(name: string): OptEnvText; external 'getenv';
  ```

  Null is absence, not a failure and not an empty string. Non-null is copied at
  the call site, so **no C pointer ever becomes a Pascal value** — the program
  holds a string of its own and the pointer is dead by the end of the
  statement. The capacity is required and is checked: a value that does not fit
  is §6.4.6's error, in §6.4.6's words.

  Still refused: a bare string result (now with a message that names the
  remedy), `?integer` — C has no null integer — and every other pointer.

- **`PasEnv` — the process environment** (`lib/dialect/`, ADR-0123): `Lookup`,
  `LookupOr`, `Defined`, `Define` and `Undefine`. `Lookup` of an unset name
  answers `nil`, of a name set to the empty string answers a present value of
  length zero, and a caller can tell the two apart — which no shape in this
  library could do before.

  **`putenv` is deliberately absent**: it keeps the pointer it is handed, and
  this compiler's string arena reclaims that storage at the end of the
  statement. `setenv` copies. It is the first time the FFI's registered blind
  spot has decided an interface rather than being recorded against one.

- **`array of T` — a slice, under `--std=afterschool` only** (ADR-0125). A
  formal parameter's type, and a view of part of an array:

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
  nothing, so a routine that wanted part of one had to be handed the whole
  thing and two indices — which puts the bounds outside anything that checks
  them. **A slice carries its own length**, so the callee's `s[k]` is checked
  against the part it was given and not against the array it came from.

  §6.4.3.2 requires a bracketed index-type after `array`, so `array of T` is a
  syntax error in both standards and nothing that compiled stops compiling.
  The designator `a[i..j]` is the one §6.5.6 already gives a substring; only
  the base's type tells the two apart, and in a conformance mode it still
  means a substring and still refuses an array.

  A slice is indexed **1..length** however far into the base it starts — the
  rule §6.7.6.7 gives a substring, and a divergence from Delphi's 0-based open
  array that fails at the first access rather than quietly. `length(s)` answers
  the count. An empty slice (`a[4..3]`) is admissible.

  `var` and `protected var` only: a slice is a view of the caller's storage,
  and a value parameter is a copy. It may not be a variable, a field, a result,
  or a named type — the denoter is legal as a formal parameter's own type and
  nowhere else.

- **Fixed: a schema whose body holds an optional crashed the compiler.**
  `?T` was the seventeenth type kind and `StaticThroughout` still enumerated
  sixteen; a Pascal case-statement with no matching label stops the program, so
  a schematic formal parameter over such a schema —

  ```pascal
  type Box(n: integer) = record slot: ?integer; pad: array [1..n] of integer end;
  procedure show(var b: Box);
  ```

  — stopped `pascalc` rather than compiling. Present only in the unreleased
  ADR-0123 work, and never in a released version.

- **Fixed: two `string` parameters in one group of an `external` heading.**
  `function setenv(name, val: string; …)` was refused since ADR-0122, because
  §6.7.3.3's "one formal-parameter-section is one parameter-form, so every
  actual brings the same tuple" was being applied to a foreign heading. A
  foreign `string` formal is not a schematic formal and has no tuple. Nothing
  had asked: the only such declaration in the corpus was `strcmp`, and every
  call passed two actuals of equal length.

- **A string and a `var` parameter cross the foreign boundary** (ADR-0122),
  still under `--std=afterschool` only.

  ```pascal
  function atoi(s: string): integer; external 'atoi';
  function modf(x: real; var ip: real): real; external 'modf';
  ```

  **An address crosses only as an argument.** Nothing comes back as one: a
  returned `char *` is the callee's storage or nobody's, and it may be null —
  `getenv` of a name that is not set answers null in the ordinary course of
  things — which needs an optional type this language does not have yet. An
  *argument* is different: the caller owns the storage and outlives the call,
  so the lifetime question does not arise.

  `string` in an `external` heading means `const char *`, and it is **not** a
  schematic formal: there is no descriptor to bind and no capacity, so the
  actual has only to be a string and may be a literal, a variable, a
  concatenation, a substring or a char. What crosses is a NUL-terminated copy
  in the string arena, alive for the statement. A capacity (`string(20)`) or a
  fixed size (`packed array [1..3] of char`) on the formal is refused: a C
  string carries its length in-band as the NUL, so the size is the actual's.

  **A string containing `chr(0)` traps** rather than being truncated. C cannot
  represent one, and a path silently cut short is the class of thing every
  other check here traps on.

  A `var` parameter of `integer` or `real` crosses as the actual's own address
  — `int *` and `double *`. A **buffer** does not: it is a pointer *and* a
  length, and the length is not in-band the way a C string's is. So `read` and
  `snprintf` still wait, on a language decision about slices rather than on the
  FFI. A procedural parameter is refused outright, the static link being a half
  with no image at all in C.

- **`PasFS` — the file system** (`lib/dialect/`, ADR-0122): `Remove`, `Rename`,
  `MakeDirectory`, `RemoveDirectory` and `Exists`, over `remove`, `rename`,
  `mkdir`, `rmdir` and `access`. A routine with nothing to return answers an
  `ErrorCode` directly, `errNone` being success, because ADR-0120's result
  record draws its safety from the payload setting the tag and an arm with no
  payload has nothing to set it with.

  **Every failure is `errIO` and cannot be finer**, because `errno` is
  `*__errno_location()` on glibc and a pointer *result* is the one thing
  ADR-0122 refuses. `Readable` and `Writable` are absent for a second reason:
  `R_OK` and `W_OK` are numbers a C header supplies and an FFI without a header
  parser cannot see, while `F_OK` is 0 and 0 is 0 everywhere.

- **`hypot`, `atan2` and `atan` are names a program may have.** ADR-0121 could
  not let a program name a linker symbol the emitted module already declares,
  LLVM refusing any redeclared global, and those three were declared because
  `arctan` compiles to the first and `abs` and `arg` of a `complex` to the
  other two. They are now `pas_atan`, `pas_atan2` and `pas_hypot` in the
  runtime, so `external 'hypot'` works — in the same program that uses
  `complex`, which `tests/dialect/foreign_libm.pas` is.

  Two names are still refused and neither can move: `main` is the entry point,
  and `_setjmp` has to be called in the frame `longjmp` returns to, so a
  wrapper would return before §6.8.3.11's non-local goto ever jumped.

- **`PasMathX` — the first binding module** (`lib/dialect/`, ADR-0121):
  `Cbrt`, `Log10`, `Log2`, `FMod` and `RealOr`, over libm functions neither
  standard has. It holds one claim still — a binding module **exports Pascal
  and keeps the directive to itself** — and where a routine can fail it answers
  ADR-0120's result shape rather than a NaN: `Log10(-1.0)` reports `errRange`,
  and reading the payload without asking traps.

- **`lib/` — the beginning of a standard library** (ADR-0114), and it widens
  what the sentence above calls the public interface: until now this project
  shipped a compiler, and it now also ships Pascal that other programs import.
  Three modules, in ordinary Extended Pascal:
  - `PasStrings` — `Upper`, `Lower`, `StartsWith`, `EndsWith`, `IndexOf`,
    `PadLeft`, `PadRight`, `Times`, `Reverse`, `Replace`;
  - `PasSort` — `SortIndexed` and `LowerBound` over positions rather than
    elements, so one body serves any element type; `SortInts` and the
    `IntVector` schema for the common case;
  - `PasMath` — `IMin`, `IMax`, `Gcd`, `Lcm`, `ISqrt` and a seedable Lehmer
    generator, each written so no intermediate leaves `-maxint..maxint`.

  **The compiler is unchanged**: a library module is a §6.11 module translated
  as a §6.13 program-component, both of which were already implemented, so
  neither `--std=iso7185` nor `--std=extended` accepts or refuses anything
  different. There is no install location and no resolution by name —
  `--import` takes a path — so a program outside this repository names paths
  into a checkout.

  One thing a caller should read first, a consequence of existing behaviour
  rather than of this change: an exported function assigns its own identifier
  once at the end, §6.11.1 making its heading a `forward` whose body cannot see
  a result-variable-specification. **Fixed under Fixed, below**, in a later
  change of this same unreleased version; the paragraph is left as written
  because it is what a caller of the library at that point had to know.

- **Three more modules — containers and text** (ADR-0116):
  - `PasVector` — `IntVec`, a growable sequence of integers: `VecNew`,
    `VecPush`, `VecPop`, `VecGet`, `VecSet`, `VecReserve`, `VecFill`, `VecSum`,
    `VecClear`, `VecFree`;
  - `PasMap` — `StrMap`, a `string(32)`-keyed dictionary with open addressing
    and tombstones: `MapPut`, `MapGet`, `MapHas`, `MapDelete`, `MapCount`, and
    `MapSlots`/`MapLiveAt`/`MapKeyAt`/`MapValAt` to walk it;
  - `PasText` — `Split`, `Join`, `TrimStart`, `TrimEnd`, `TrimAll`,
    `CountChar`, `TryParseInt`, `ParseIntOr`, `IntToStr`.

  **A container is a pointer to a schema and growth replaces the variable**, so
  every routine that may grow takes `var v: VecPtr`. A schema is chosen once —
  `var v: IntVec(n)` fixes `n` at the declaration — which makes the heap the
  only mechanism for an extent that changes.

  **The element type is written out.** `PasSort` avoided "no generics" by
  phrasing itself over positions and never seeing an element; a container holds
  the elements, so their type is part of its layout. The documented answer for
  another element type is to copy the file.

  **No container takes an allocator.** An allocator record is not expressible —
  a record field may not have a procedure type — and a per-type allocator
  parameter, which does compile, can only recycle blocks `new` produced and
  serves a capacity nothing checks. `VecReserve` is what survives of the idea:
  control over *when* allocation happens.

  `TryParseInt` inspects characters itself rather than using `readstr`, because
  §6.9.1's read of an integer is an *error* when the text is not a number and
  stops the program — a library cannot offer "parse this if it is a number" on
  top of something that halts when it is not.

- **`--std=afterschool` — a third language mode, the dialect** (ADR-0117). It
  is where the project's stated goal gets built, and unlike the first two it
  **nests**: it contains ISO/IEC 10206:1991, so every Extended Pascal program is
  a valid Afterschool Pascal program meaning the same thing. `--std=iso7185` and
  `--std=extended` are unaffected and stay exactly what they are.

  **It admits no feature yet**, which is the point rather than a caveat: today
  the mode accepts exactly Extended Pascal, and that containment is the property
  every later feature is added to. `tests/dialect/inherits_extended.pas` holds
  it, and the same source under `--std=extended` and `--std=afterschool`
  produces identical output.

  It carries **no stability promise**. The dialect is what the compiler at hand
  defines; a program needing fixed behaviour should pin a compiler version.

  `tests/dialect/` is the third corpus directory and the directory decides the
  flag, as `tests/extended/` does. `selfhost/difftest.sh` **skips** dialect
  sources — the reference front end is frozen at the conformance surface, so
  there is no second implementation, and comparing two rejections would pass
  while proving nothing. Skips are counted and reported, and the corpus check
  now requires compared + skipped to equal the whole.

- **In `--std=afterschool`, a variant record's tag cannot lie** (ADR-0118) —
  the dialect's first feature. Writing a variant's field makes that variant
  active, and reading a field whose variant is not active traps, so a tagged
  union is checked rather than merely conventional. Construction needs no tag
  assignment and cannot get it wrong:

  ```pascal
  r.num := 42;      { activates ok }
  r.msg := 'nope';  { activates bad }
  writeln(r.num)    { traps: the tag selects another arm }
  ```

  §6.5.3.3 makes reading an inactive variant an **error** and §3.1 lets a
  processor leave an error undetected, which both conformance modes do — so a
  correct program never does it and the dialect detecting it changes nothing
  that was already right. Nothing in `--std=iso7185` or `--std=extended`
  behaves differently.

  Two limits: a write activates only when the arm has exactly one label, since
  `aa, bb: (i: integer)` cannot decide between them and is checked against the
  tag instead; and a variant part with **no tag field**, which §6.4.3.3 permits,
  has nothing to check against and stays an unchecked union.

- **`seed/ddc.sh` — diverse double-compiling, and it passed.** The seed is an
  opaque committed artefact whose provenance was this repository's history and
  nothing else. Building a compiler through the `v0.1.0` C++ implementation
  (LLVM's own code generator) and one through the seed, then having each
  translate `selfhost/compiler.pas`, produced identical output — 7,024,210
  bytes, sha256 `399b9cdc…`. `seed/README.md` carries the dated statement and
  the limits: `v0.1.0` is this project's own earlier compiler, so the two are
  diverse in implementation but not independently authored, which rules out a
  seed that drifted from its source rather than a mistake present in both. The
  script skips rather than fails when it cannot run, and says so explicitly on
  the day the `v0.1.0` compiler stops accepting today's source — after which the
  question can no longer be asked.

### Added

- **`lib/dialect/` — a second library layer, in `--std=afterschool`**
  (ADR-0120), and the answer to the finding three increments of `lib/` kept
  producing: every routine that can fail invents its own way of saying so.
  A fallible routine now answers one record that carries the value **or** the
  reason:

  ```pascal
  IntResult = record
    case ok: boolean of
      true:  (num: integer);
      false: (code: ErrorCode)
    end;
  ```

  Nothing assigns the tag — the write to the payload is what sets it — so a
  caller who reads `num` on a failed result **traps** rather than receiving an
  integer that was never parsed. `lib/dialect/paserror.pas` holds the shared
  `ErrorCode`; `lib/dialect/pasparse.pas` is the first producer.

  It is a shape and not a type: with no generics a result's payload type is
  part of its layout, so each producing module declares its own record and what
  is shared is the error code and the spelling of the tag.

  **The two layers do not mix.** `lib/` stays Extended Pascal and stays
  importable by any conforming program; `lib/dialect/` is dialect all the way
  down, and the entry below is what makes that enforced rather than promised.
  The cost is duplication — `ParseInt` trims its own input because it cannot
  call `PasText.TrimAll`.

### Changed

- **The program-components of one program must agree on `--std`**, and a
  mixture no longer links (ADR-0119). A module's two activation functions carry
  the mode in their names — `@m.counter.extended.init` against
  `@m.counter.afterschool.init` — so a component built under a different
  standard leaves the caller's symbol undefined, and `pascalcc` translates that
  into a sentence naming the module and the mode.

  It is a restriction, and it is there because the alternative was a false
  assurance. `--std=afterschool`'s variant rules are a *pair* — a write to a
  field activates its variant, a read of an inactive one traps — and both are
  emitted at the access, so §6.13's separate translation let them be split. A
  dialect component reading a variant that a conformance-mode component wrote
  ran its guard against a tag nothing had stored and **permitted** the access:
  the check compiled in, switched on, and answering `safe` for an unsafe read.

  Nothing in this repository mixed modes, and an all-`--std=extended` program
  links exactly as before. What changes is that rebuilding half a program after
  changing `--std` now refuses instead of misbehaving.

### Fixed

- **A module imported and not used was called and never declared.** §6.2.3.6
  activates every module that supplies the main-program-block, whether or not
  the importing component names anything of it — but the only thing registering
  an imported module for declaration was the path that names its activation
  record, which runs when something of the module's is *accessed*. So a program
  importing a module it never used emitted a call to `@m.<name>.fini` into a
  file that declared no such symbol, and the assembler refused it: the program
  did not build at all. Present since modules landed (ADR-0053), and reached by
  nothing in the corpus, every `--import` in the tree having used what it named.

- **A `forward`-declared function may name its own result.** §6.7.2's
  result-variable-specification — `function f(...): t[r]` — was refused for a
  function whose heading had already been given, so §6.11.1 putting every
  exported function's heading in a module-heading made it unavailable to every
  module in `lib/`. §6.8.2.2 makes a *read* of the function identifier a
  recursive call, so an exported function that accumulates had no name to
  accumulate in and had to use a local.

  The clause gives the result identifier a defining-point in "the block of the
  function-block, **if any**, associated with the identifier of the
  function-heading", and one paragraph later says the identical thing of the
  formal-parameter-list — which has always reached a forward body. The
  asymmetry was literal in the compiler: parameters were bound from the
  *symbol*, the result variable from the *declaration node*, and a forward
  body's node carries no specification. The refusal now reads the symbol too,
  and both halves of the clause behave alike.

  `tests/extended/forward_resultvar.pas` is the case; `doc/sop.md` §7 carried
  this as the first question for the next `langspec-audit`, which it turned out
  not to need.

- **A function's result may be a structured value parameter's actual.**
  §6.6.3.2 makes a value parameter's actual an *expression* and §6.7.1 makes a
  function-designator one, so `SumPoint(MakePoint(3, 4))` is legal wherever
  `SumPoint(q)` is. It was refused whenever the formal was structured —
  *argument 1 of 'sumpoint' is point and needs a variable* — and the refusal was
  undocumented, which is consistent with its being a defect rather than a
  decision.

  The compiler had disagreed with itself: `q := MakePoint(3, 4)` already copied
  a record out of a call's storage, and `MakePoint(9, 1).x` already selected
  from one, so the address a value parameter needs to copy from was there all
  along. What kept a call off the list of things Sema would copy from was
  `isDesignator` answering false for one — the right answer to the question a
  **var** parameter asks, where there is no variable to bind, and the wrong
  question for a value parameter.

  This is the idiom a `Result`-shaped record exists for: handing one function's
  result straight to another. Both front ends changed, since this is the
  conformance surface the reference implementation still follows.

- **A schema type containing a string may now be allocated.** `new(p, d)` where
  the domain is a schema whose component contains a variable-string — the shape
  a keyed container wants, `array [1..cap] of record key: string(k); … end` —
  stopped the *compiler* with `case: no label matches the selector`. Not a
  diagnostic and not a wrong answer: a crash, on a legal program, before
  anything was emitted. Sema's `StaticThroughout` asks whether a bound anywhere
  inside a type depends on a discriminant; its case over the sixteen type kinds
  listed fifteen, and Pascal's case-statement traps on the sixteenth rather than
  falling through. The correct arm is `true`, because a string whose capacity is
  a discriminant is answered *before* the case by the dynamic-bounds test — so
  one that reaches it has a fixed capacity and nothing inside it can vary. The
  reference front end had it right all along, its counterpart ending
  `default: return true`; `difftest` could not report the difference because the
  Pascal crashed rather than printing a different dump.

- **A variable-string may now be a value parameter**, so a string argument may
  be a literal, another function's result, a concatenation, or a string of a
  different capacity — `StartsWith(s, 'Hello')` and `Upper(Reverse(s))` compile,
  and neither did before. ISO/IEC 10206:1991 §6.6.3.2 with §6.4.6 requires it;
  this compiler refused it and said the conversion had "nowhere to build the
  result that the caller can name".

  The premise was wrong in one word. The conversion needs somewhere with the
  **formal's** capacity, which is the callee's own frame slot for the
  parameter — so the caller passes a pointer and a length (the string value
  §6.4.6 will store) and the callee's prologue makes the same store `s := expr`
  makes. A value longer than the formal's capacity is an error at the call, with
  the message an assignment gives, because it is the same check.

  A **restricted** string value parameter is still refused, and now says so in
  its own words: whether a clause forbidding assignment of a restricted value
  permits copying one into a parameter is a reading nobody has taken. A
  **fixed**-string value parameter is unchanged — `packed array [1..8] of char`
  is copied rather than converted, so an actual must still have the same length.
  ADR-0115.

## [1.4.0] — 2026-08-18

**One of the changes below turns a wrong answer into an error, and three
refuse a program that compiled before.** None of them removes language you
could rely on — in each case the program was already being compiled into
something other than what it said — but a compiler that changes its mind about
a source you have is the thing worth reading before upgrading:

- a statement whose live string values exceed the arena **stopped being
  silently wrong**. It used to wrap and write one live value over another, so
  `a + a = b + b` over two 512K strings compared a buffer with itself and
  called two values differing in every character equal, exit status 0. There is
  no repair that keeps an answer, so it is now an error;
- an identifier or a character-string longer than 255 characters is refused
  rather than truncated. Truncation made two names one, and printed 255
  characters of a 300-character literal;
- a type-name written inside a record type-denoter that is also one of that
  record's fields is refused wherever it appears, where only `^fred` was
  refused before;
- a program's own block now costs one nesting level, so 999 remain inside it.

Each is a defect against a clause, and every one of them was found by an
oracle rather than by a user: a security audit drove untrusted input at the
front end, and an independent reading of the standards went looking for the
other two. `doc/implementation-defined.md` §6 now states every limit this
processor imposes, which clause 5.1 c) requires and which it had been missing.

### Added

- **A subrange bound in a variable's own type-denoter may be an expression**,
  under `--std=extended`, so `var a: array [1..m] of real` inside a procedure
  is accepted and the array is sized when the procedure is entered:

  ```pascal
  procedure p(m: integer);
  var a: array [1..m] of real;
  ```

  ISO/IEC 10206:1991 §6.4.2.4 writes `subrange-bound = expression` and
  §6.2.3.8 b) evaluates one at the block's commencement, after the formal value
  parameters are attributed. Either end may be one, both may be, they may
  appear at more than one level (`array [1..m] of array [1..k] of real`), and
  each name of a declaration group is sized for itself. A bound outside the
  domain — `1..0` — stops the program on entry, and every subscript is bounds
  checked against the bounds the descriptor holds. **ISO 7185 is unchanged**:
  §6.4.2.4 there writes `subrange-type = constant '..' constant`, and
  `--std=iso7185` refuses it as before. ADR-0113.

  Still refused, and recorded in `doc/implementation-defined.md` §6: the same
  bound in a *type-definition* (`type t = array [1..m] of integer`) or in a
  record field, and in a module's variables, whose activation lasts as long as
  the program.

### Changed

- **An identifier or a character-string longer than 255 characters is now an
  error** rather than being silently shortened to 255. A program containing one
  compiled before and does not now, and that is the point: the limit was being
  applied by dropping the tail, so two identifiers agreeing in their first 255
  characters were *one name* — a program could assign to one and read the other
  with nothing said — and `writeln` of a 300-character literal printed 255 of
  them, so its output did not match its source. Found by a security audit;
  ADR-0110 records why the limit is reported rather than raised, and
  `doc/implementation-defined.md` §6 now states it as clause 5.1 c) requires.
- **A type-name inside a record type-denoter that is also one of the record's
  fields is now refused**, wherever it is written. §6.4.3.3 puts a field's
  defining-point in the region that is the record-type and §6.2.2.4 makes its
  scope that whole region, so `record a: fred; fred: integer end` names the
  field and not the type — as do `array [fred]`, `set of fred`, `file of fred`
  and `fred(3)`, and a field named `integer` takes that spelling from the
  required identifiers inside its own record. Only a pointer's domain-type
  (`^fred`) was refused before, which is the occurrence BSI's DEV043 pointed
  at; the clause names no production. A program that uses a type-name inside a
  record and also has a field of that spelling compiled before and does not
  now. ADR-0112; `doc/implementation-defined.md` §6.1 records the one occurrence
  still not asked, which is a *constant* one.
- **A statement whose string values need more than 1 048 576 characters at once
  now stops the program** with `more string values are live at once than the
  string arena holds`. The storage was a ring: on exhaustion it wrapped to the
  start and wrote one live value over another, so `a + a = b + b` over two
  512K strings compared one buffer with itself and reported two values
  differing in every character as **equal**, exit status 0. There is no repair
  that keeps an answer — a wrap only happens when the values do not fit — so
  what changes is that a wrong answer becomes an error. Concatenating in a loop
  is unaffected and was the reason the wrap looked harmless: a statement's
  string values are released when the statement finishes, so four megabytes go
  through the one-megabyte arena without trouble. ADR-0111 has the mechanism,
  ADR-0110 the rule it applies, and `doc/implementation-defined.md` §6 states
  the limit.
- **A block counts as one nesting level**, so 999 remain inside a program's own
  block where 1000 did before. Nothing counted a block, so a procedure
  declaration nested a scope without nesting anything the parser measured: 1001
  nested procedures indexed Sema's scope stack off its end and stopped the
  compiler with `array index out of bounds (0..1001)` on **stderr**, where its
  diagnostics go to stdout — a caller redirecting stderr got a non-zero exit
  and no message. It is now the ordinary `nesting is too deep` diagnostic.

## [1.3.1] — 2026-08-17

**Three of the fixes below change what an already-valid program prints or
reads.** A patch release does not normally do that, and this one does: each was
a defect against a clause of the standard, and correcting it necessarily
changes the output of a program that met the defect. The affected programs are

- any that writes a `real` and then calls `page` on the same file,
- any that reads a `real` written with more than 63 characters,
- any that writes a `real` in `[1e-100, 1e-99)` with an explicit field width.

Nothing else changes. If you have goldens recorded against 1.3.0 for programs
of those shapes, they will move, and the new value is the conforming one.

### Added

- **`llc-second-backend`**, a `ctest` case and a CI job, asking the one question
  no oracle here could: **is the compiler binary miscompiled?**
  `selfhost/irtest.sh` compiles the compiler with itself twice and requires
  stage 2 to equal stage 3, but both stages come from one binary — so a `clang`
  that got a corner of `selfhost/compiler.pas` wrong would build a wrong
  compiler that reproduced itself exactly, and every golden would agree, having
  been written by it. The check builds the compiler a second way, through `llc`
  at `-O0` and `-O2`, and requires both to translate `compiler.pas` to
  byte-identical IR.
  - It **skips without `llc`**, as `verify-lowering` does without z3: `llc` is
    LLVM's, and ADR-0085's claim is that the build needs nothing of LLVM's.
    The CI job installs it, in a container of its own for that reason, and
    greps the log to refuse a green bar that skipped.
  - It is **not** a second reader of the IR, and the script says so: `llc` and
    `clang` share LLVM's parser and verifier and reject the same module with
    the same message. What it varies is the backend configuration.

### Fixed

- **`page` after writing a real** wrote no line terminator. ISO 7185 §6.9.5
  performs an implicit `writeln(f)` when the current line is not empty, and
  five of the six write primitives recorded that the line had something on it.
  `write(1.5); page` therefore wrote the form feed straight after the value and
  stranded it on the previous page. Six programs in the corpus call `page` and
  none wrote a real first, so every oracle agreed —
  `doc/implementation-defined.md` E.30 included, which had stated the rule the
  code did not keep. `tests/page_after_real.pas` pins all three forms a real
  can be written in.
- **`read` of a real longer than 63 characters** returned the wrong value *and*
  desynchronised the input. §6.9.1 c) and d) take the longest sequence that
  forms a number; the runtime accumulated into a fixed buffer and stopped the
  loop rather than the read, so the digits past the sixty-third stayed in the
  file and became the next value read. A seventy-digit number came back as its
  first sixty-three digits — wrong by seven orders of magnitude — and every
  subsequent read was one number out of step. `tests/readlongreal.pas`.
- **A real in `[1e-100, 1e-99)` was written one character wider than the
  field**, against §6.10.3.4.1's requirement that the floating-point form
  occupy exactly TotalWidth characters. The exponent's width was taken from the
  magnitude of `log10` rather than from the exponent actually written, and for
  that band the two differ. `doc/implementation-defined.md` E.25 and E.27 had
  always described the intended rule correctly; nothing checked it.
  `tests/extended/writereal_width.pas` now does, by measuring the
  representation rather than pinning digits.
- **`pascalcc --help`** printed the licence header and stopped one line before
  the first option, so every option was invisible — including `-c`, `-O0..-O3`
  and `<file>.o`, which `pascalc -h` does not know about and which are
  documented nowhere else.

### Changed

- **`pascalc-s0` refuses the options it cannot honour** rather than accepting
  and ignoring them. `-o`, `-S`, `-c`, `-O0..-O3`, `--keep-temps` and
  `--import` each set a field nothing read, so `pascalc-s0 -o out.txt -S -c
  hello.pas` exited 0 and wrote no `out.txt`. They are residue from when `src/`
  was the compiler; since ADR-0108 it is a front end and generates no code.
  This binary is not the compiler and nothing shipped depends on it.

## [1.3.0] — 2026-08-16

**The differential oracle is green.** ADR-0108 brought the C++ front end back
one release ago and it arrived red: 89 of 731 files on which it and the compiler
disagreed, the drift of twenty-four Sema commits it never received. All 89 are
closed, one commit per rule, each naming the clause it ports. Two independent
front ends now agree on every Pascal source in the tree — 732 of them, token for
token and node for node.

Almost none of that is visible from a Pascal program: the reference front end
generates no code and nothing it produces ships. What *is* visible is small and
is listed below, and one item can break a build that used to work.

### Changed

- **Two schema definitions that used to compile are now refused**, and a build
  containing either will fail. Both were illegal and neither was detected,
  because a schema's body is resolved lazily at its first production, so nothing
  ever looked at the text of the definition:
  - a schema naming another **defined after it** (§6.2.2.9 requires a
    defining-point to precede every applied occurrence, with only a pointer
    domain and an export-list excepted), and
  - a schema **naming itself** outside a pointer domain, where it was never used
    (§6.4.7 states that as a rule about the definition, so it does not wait for
    a production).

  The fix is to reorder the definitions, or to write the self-reference through
  a pointer domain, which is the form §6.4.7 allows.
- **The build now requires a C++20 compiler**, for `src/`. Nothing it produces
  ships and `build/bin/pascalc` does not depend on it — it builds `pascalc-s0`,
  which is a lexer, parser and Sema with no code generator, and exists so
  `selfhost/difftest.sh` has a second answer to compare. README said "no C++
  compiler" until this release.
- `--dump-sema` prints a **redefined `write` or `read`** at the statement's real
  depth. Sema hangs the resolved call off the write statement as a husk
  (ADR-0087) and the dump padded for both nodes, so a `proccall` printed two
  levels deeper than its own arguments. `--dump-ast` runs before Sema and never
  had the husk, so it is unaffected. The reference front end is what caught it:
  the *product* was the wrong one, and copying its output into `src/` to make
  four files agree would have been ADR-0073's failure exactly.

### Added

- **An enumerated type may appear in a schema body.** §6.4.2.3 puts the
  defining-point of an enumerated type's constants in "the block, module-heading
  or module-block closest-containing the enumerated-type" — the block, not the
  production — so `t(n: one) = record c: (red, green); a: array [1..n] of
  integer end` is a legal program, and it was rejected. The constants are now
  declared once, in the block, and every production shares the one type.

### Fixed

- Every conformance rule the reference front end lacked is ported into it — 25
  commits, each naming the clause it carries — so `difftest` compares them
  again. Among them: §6.6.6.4's `succ`/`pred` host type, §6.7.5.5's
  `readstr`/`writestr`, §6.2.2.10's required identifiers as symbols, §6.6.4.1's
  redefinable read/write family, §6.2.2.9's defining-point order and its pointer
  domain exception, §6.6.5.3's `dispose`, §6.4.5 c)'s set packing, §6.6.3.3's
  var-parameter restrictions, §6.1.8's comment delimiters, §6.8.1's three goto
  conditions, §6.4.3.3's variant labels and record-as-region, §6.8.3.9's
  for-statement threats, §6.2.1's declaration interleaving, §6.6.3.2's value
  parameter containing a file, §6.6.3.6's congruity over parameter *sections*,
  §6.5.4's function result, and §6.4.3.2's four properties of a string-type.
  **None changes what `pascalc` accepts**; each closes a place where the two
  front ends disagreed. Eleven programs of the BSI validation suite came back
  with them, CONF027 and CONF116 among them.

## [1.2.0] — 2026-08-15

**The language is unchanged** — no new syntax, no new diagnostic, and nothing a
working program does differently. What makes this a minor release rather than a
patch is one new flag, `--coverage`, and it is a flag for the same reason
everything else here is: coverage in this repository was an argument, and this
release makes it a number.

Three of them, each gating in both directions: which procedures the corpus
enters, which statements it runs, and which clauses of the two standards a
scenario cites. The first measurement of any of them found four documented
`--dump` flags no test had ever passed and a procedure argued unreachable that
turned out to be exactly that.

### Added

- **`tests/spec/`**, a specification suite: 43 scenarios written against 13
  clauses of the two standards, in a subset of Gherkin, with a runner of its own
  and no new dependency. Every other test here starts from the compiler; a
  scenario starts from a clause and states the requirement in the standard's
  terms (ADR-0105). All 292 clause headings of the two standards are classified
  testable, structural or not-implemented, so coverage is measured against the
  189 that can carry a scenario, and `spec-clause-traceability` gates it in both
  directions (ADR-0106).
- **`--coverage`**, a new flag: the compiled program records which of its own
  statements ran and appends their line numbers to `$PASCOV_LINES`. What was
  instrumented is in the IR the same compilation wrote, so the two halves of a
  coverage figure come from one artefact (ADR-0104). It works on any Pascal
  program; this repository's own use of it is one caller.
- **`line-coverage`**, a `ctest` case built on that flag: 12,708 of 13,358
  statements of the compiler are run by the corpus, and the count may not grow.
  Unlike `procedure-coverage` it is a ratchet rather than an allowlist, which
  `doc/sop.md` §7 records as the weaker instrument.
- `pascalc`'s command-line error paths are tested — an unknown option, a missing
  `-o` or `--import` operand, two input files, none. Nothing had ever run them,
  and the gate that counts diagnostics is blind to them by construction: it
  filters `pascalc: ` messages out as driver output.
- **`procedure-coverage`**, a `ctest` case that measures how much of the
  compiler the corpus enters — 554 of 556 procedures — and fails when a
  procedure stops being entered *or* when one argued unreachable starts being.
  It instruments the emitted IR with clang's SanitizerCoverage, which is
  possible only because the backend is textual (ADR-0103).
- **`tests/dumps/`**, five cases and a harness for `--dump-tokens`,
  `--dump-ast`, `--dump-sema` and `--dump-all`. No case in the corpus had ever
  passed any of them, so nothing checked they did not crash.
- **`tests/extended/schema_simple_body.pas`**, for a schema whose body is a
  simple type (`counter(limit: integer) = integer`). Every schema in the corpus
  produced an array or a record, leaving the one place a type is copied rather
  than interned exercised by nothing.
- `pascalc -h` is now checked to document every flag `ParseArgs` accepts —
  derived from the parser rather than compared against a golden, since the two
  agreeing is the thing worth knowing. It was a manual release-checklist step.
- Each function in the emitted IR carries a comment naming the Pascal procedure
  it came from and the line it starts on, which is what makes `-S` output
  readable and what the coverage mapping reads.

### Removed

- `StrIsLit`, which had no callers.

## [1.1.1] — 2026-08-15

A patch release: one crash fixed, and the rest is what looks for the next one.
The language is unchanged — no new syntax, no new flag, and nothing a working
program does differently.

### Fixed

- **A `for` statement inside another loop no longer exhausts the stack.** Both
  forms of the statement claimed storage on *every iteration of the loop around
  them*, so a long-running nested loop compiled with `-O0` died on a stack
  overflow. Programs built at the default `-O2` were never affected: LLVM
  hoists an alloca whose address does not escape, and the leak disappears with
  it. The answer computed was correct either way — the program simply ran out
  of stack first, which is why 495 tests, the validation suite, the SMT proofs
  and the stage-2/stage-3 fixed point were all green over it. (ADR-0102)
- **`verify/`'s model of `succ` and `pred` described the compiler v1.1.0
  replaced.** It claimed a subrange runs out at its own last value, where
  §6.7.1 makes it the host's — so `succ(9)` of a `1..9` is 10 and not an error.
  No proof failed and none could: those rules prove the *model* against the
  *specification*, and neither touches the compiler. The one check that does
  compare them exercised `succ` on enumerations alone, which is the single
  ordinal type where the wrong reading and the right one agree.

### Added

Nothing a program can use. Everything here exists to make the next defect of
these kinds fail a test instead of shipping.

- **The whole corpus now runs at `-O0` as well as `-O2`**, in CI and on demand
  with `AFTERSCHOOL_PASCAL_OPT=-O0 ctest`. A `name.opt` sidecar pins a single
  case's level where a sweep would hide what it is testing, and the test
  harness bounds the stack so a storage leak can actually fail something.
- **`diagnostic-coverage`**, a test that every message the compiler can write
  is named by some golden. Counting them found 32 unreached at once; 26 cases
  were written, and the remaining four are argued unreachable in
  `tests/checks/unreachable_diagnostics.txt` and commented at their branches.
  It fails in both directions — an entry that later acquires a golden is as
  loud as a message with none.
- **`model-drift`**, a CI check that a change to the code generator either
  changes `verify/` or says in its commit message why it need not.
- **`doc/sop.md`** and the `change-lifecycle` skill: the standard operating
  procedure, organised around what each oracle in this repository *cannot* see,
  with a live register of what is still unchecked.

## [1.1.0] — 2026-08-15

**A conformance release, and the first one that refuses programs 1.0.0
compiled.** The language did not grow: no syntax was added and no flag. What
changed is that thirty conformance defects were found and fixed, and most of
them are rules the compiler was not enforcing — so a program relying on one now
gets a diagnostic where it used to get a binary. **Read "Changed" before
upgrading**; it lists every construct that stops compiling and, for each, what
to write instead.

None of this was found by a test failing. The BSI Pascal Validation Suite was
adopted as a test case (ADR-0086) and disagreed with the compiler on its first
run; ADR-0085 had retired the differential oracle in 1.0.0, and this release is
what filled the hole it left — first with the suite, then with an adversarial
re-reading of the compiler's own interpretations (ADR-0101).

### Added

- **A licence.** GPLv3-or-later, `Copyright (C) 2026 Hui-Hong You`, with a
  linking exception on the runtime: `runtime/pasrt.c` is linked into every
  program this compiler builds, and without the exception compiling an ordinary
  Pascal program would place that program under the GPL. It does not — see
  `COPYING.RUNTIME`. The compiler itself carries no exception. The BSI
  validation suite and the standards under `doc/vendor/` are neither ours nor
  distributed, and `tests/bsi/README.md` states BSI's own three conditions.
- **`tests/bsi`** — the BSI Pascal Validation Suite 5.7 (© 1982 British
  Standards Institution) as a `ctest` case. The suite is **fetched, not
  committed** (`tests/bsi/fetch.sh`), and the case skips when it is absent.
  Running it is **not a validation**; see `tests/bsi/README.md` for BSI's terms.
- **`.github/workflows/ci.yml`** — build and test on every push in two minimal
  containers, which is what checks that the build needs `cmake`, `make` and
  `clang` and nothing of LLVM's. A third job fetches the validation suite and
  runs it, since the case skips wherever nobody has fetched it — which was
  every container, leaving the newest oracle running only on a developer's
  machine.
- **`.claude/skills/langspec-audit`** — the procedure that produced ADR-0101:
  independent readers given the compiler's behaviour and not its reasoning, and
  told to prove it wrong from the standards text. It exists because no oracle in
  this repository can contradict a *misreading* — the goldens agree with
  whoever wrote them, and the validation-suite catalogue records what this
  compiler does.

### Fixed

Every entry changes what an **already-valid program** does, and none was found
by a test failing: the BSI Pascal Validation Suite was adopted as a test case
and disagreed with the compiler on the first run (ADR-0086).

- **A program may declare its own `write`** — or `read`, `readln`, `writeln`,
  and under `--std=extended` `readstr` and `writestr`. ISO 7185 §6.2.2.10 puts
  the required identifiers in a region enclosing the program and §6.6.4.1 is
  the procedures' half of it, so a declaration in the program hides one, as it
  already did for every other required procedure. `write(i)` in a program
  declaring `procedure write(var a: integer)` used to run the required `write`
  and report nothing; it now calls the one the program declared. This also
  makes `write := 5` an assignment where it was a syntax error, and lets a
  declared `write` be passed as a procedural parameter, which §6.6.3.7 refuses
  only for the required one. (ADR-0087)
- **A name used in a block may no longer be declared in it.** ISO 7185
  §6.2.2.9 requires a defining-point to precede every applied occurrence of its
  identifier in the region it belongs to, and this compiler enforced that only
  where the name resolved to nothing. Where it resolved to an enclosing
  declaration the earlier uses kept the outer meaning and the later declaration
  took effect from its own position — one name with two meanings in one block,
  reported by nothing. Ordinary shadowing is unaffected: a block that declares
  a name it had not already used is legal and always was. §6.2.2.9's own
  exception, a pointer domain naming a type defined later in its own
  type-definition-part, is exempt. (ADR-0088)
- **A pointer's domain binds to a type of its own type-definition-part.**
  ISO 7185 §6.2.2.9's one exception says the domain-type may name a type
  defined later in "the type-definition-part containing the defining-point of
  the type-identifier" — so an enclosing type of the same spelling does not
  settle it, the inner one still being possible further down. Such a name was
  resolved where it stood, so a pointer meant the outer type and every use of
  it was a type error. Found by the validation suite's CONF027.
- **`dispose` takes an expression**, where §6.6.5.3 gives `new` a variable and
  `dispose` "the identifying-value denoted by the expression q" — so
  `dispose(f(p))` is a conforming statement and was refused. The nil written
  back into the pointer afterwards still happens wherever there is a variable
  to write it into. Its diagnostic now names what it found and no longer says
  "variable". Found by CONF129.
- **Three programs the standard requires to be rejected now are.** ISO 7185
  §6.6.6.3 gives `trunc` and `round` a parameter of real-type, so an integer is
  no longer accepted and widened; §6.10 requires the program-parameter
  identifiers to be distinct; and §6.4.3.3 puts the `;` before a variant-part
  inside the production rather than the brackets, so a record without it is a
  syntax error. None was written by any program in this corpus, which is why
  all three had gone unnoticed.
- **`reset` appends an end-of-line to a text file that does not end in one.**
  ISO 7185 §6.6.5.2's post-assertion requires it whenever the contents are not
  empty and do not already end in one, and this compiler did not: a program
  reading back a file it wrote without a final `writeln` reached end-of-file
  where a line should have ended, and `eoln` there stopped the program with a
  run-time error instead of answering `true`. An empty file still gains
  nothing, the clause requiring the contents to be non-empty. Found by the
  validation suite's CONF067 and CONF078.
- **`rewrite` of an ordinary file puts it back at the start of a line**, so a
  `page` straight after one no longer writes a blank line before its form feed
  (§6.9.5). `rewrite(output)` is unchanged and must be: it discards nothing.
- **`succ` and `pred` on a subrange run out at the *host's* bounds**, not the
  subrange's. ISO 7185 §6.6.6.4 gives the result "the same type as that of the
  expression (see 6.7.1)", and §6.7.1 says "any factor whose type is S, where S
  is a subrange of T, shall be treated as if it were of type T". So `succ` of a
  `1..9` holding 9 is now `10` where it used to stop the program; storing that
  result back into the subrange is still an error, and is where the check
  always belonged.
- **A `for` statement whose body never executes no longer checks its bounds.**
  §6.8.3.9 requires them to be assignment-compatible with the control
  variable's type *"if the statement of the for-statement is executed"*, so
  `for i := maxint to maxint - 1 do` over an `i : 0..10` is a legal program with
  an empty loop. It used to stop with a range error. A loop that does run checks
  its bounds exactly as before.
- **`writestr(s)` with nothing to write is reported.** ISO/IEC 10206:1991
  §6.7.5.5 requires at least one write-parameter after the string-variable; the
  statement had been impossible to write, so the check for it existed only on
  the ordinary `write` path, and it compiled and wrote nothing.
- **A `readstr` missing its string no longer demands `input`.** It reads from a
  string and from no file, so the diagnostic named a rule the program was not
  breaking.
- **A program-parameter declared after a procedure is now bound.** Under
  `--std=extended` a variable-declaration-part may follow a procedure (§6.2.1),
  and the pass that binds program-parameters ran once, before the first body —
  so anything declared later was never bound and `binding(f)` reported nothing.
  It now binds at each procedure declaration and reports once the declarations
  are complete; every program that does not interleave is unaffected, the two
  passes collapsing into the single one that was there before. (ADR-0100)
- **A procedure body sees only what precedes it** under `--std=extended`
  (§6.2.2.9). Every variable of a block used to exist before any body was
  checked, whatever the source order, so a body could read a variable declared
  after it. `--std=iso7185` was never affected: §6.2.1's fixed order refuses it
  a clause earlier. (ADR-0100)
- **A diagnostic names a required type by its own name.** `integer`, `real`,
  `char`, `boolean` and `text` became symbols in this release (ADR-0097), and
  without an alias the message for a mismatch printed the type's structure
  instead of the word the program wrote.
- **The compiler no longer runs out of string space compiling itself.** The
  lexer interns every *occurrence* of every identifier and literal into one
  fixed array, which grows with the size of the source; the compiler is its own
  largest input and had reached 74 characters under the bound. Raised from
  440,000 to 700,000 and the seed refreshed to match — the seed carries the old
  bound, so this was the one change that could not wait for a release tag.
  A large program that failed with *"out of string space"* now compiles.
  (ADR-0095)

### Changed

#### Programs that used to compile and no longer do

Each of these is a rule the standard states and this compiler was not applying.
The construct compiled and ran; it now produces a diagnostic. They are ordered
by how likely they are to appear in code somebody has already written.

- **A `for` statement's control variable may not be *threatened*** — assigned
  to, passed as an actual `var` parameter, read into, or used as the control
  variable of a nested `for` — anywhere in the block, "including any
  procedure-and-function-declaration-part of the block" (ISO 7185 §6.8.3.9).
  **This is the entry most likely to reject working code**: a block-level
  counter that any procedure in the same block assigns is now refused, even
  when that procedure is never called from the loop and even when it is never
  called at all. Give the loop a variable nothing else writes. (ADR-0089)
- **A variant part's labels must be exactly the values of its tag-type** — no
  value outside the type, and none of the type left unnamed (§6.4.3.3). So
  `case tag: integer of 1: (…); 2: (…)` is now refused, because `integer` has
  other values. Write a tag-type that covers the arms (`type sel = 1..2`), or
  under `--std=extended` add an `otherwise` — which discharges coverage but
  never membership. This one looks over-strict and is not: BSI's DEV073 header
  records that its own test was *"reclassified from CONFORMANCE to DEVIANCE due
  to change in DP7185"*, so the permissive reading is pre-standard. (ADR-0096,
  audited in ADR-0101)
- **A `goto` may not jump into a branch, a loop body, a `with` body or a case
  arm.** §6.8.1 admits a label only where it is a statement of a
  *statement-sequence* containing the goto, and only a compound-statement, a
  repeat-statement and Extended Pascal's `otherwise` completer hold one. Two
  labels at the same depth in different branches of one `if` used to be mutually
  reachable. (ADR-0094, with the completer in ADR-0101)
- **A name used in a block may not then be declared in it** (§6.2.2.9) — see
  "Fixed" below; this was enforced only where the name resolved to nothing, and
  now covers the case where it resolved to an enclosing declaration.
- **A required identifier may be declared away, and then means what the program
  said.** `integer`, `ord`, `text` and the rest are now symbols in a region
  enclosing the program (§6.2.2.10), so `type integer = char` takes effect. The
  reverse also holds: a name that resolves to something *not invocable* no
  longer falls back to the required function of the same spelling, so a program
  declaring `var ord: array [1..3] of integer` can no longer also call
  `ord('a')` — §6.2.2.11 forbids one identifier denoting two things in one
  block. Required *procedures* are still not symbols. (ADR-0097, ADR-0101)
- **Inside a record's declaration a field name denotes the field** (§6.4.3.3
  makes the record-type a region), so a pointer domain spelled like a field of
  that record — or of any record it is written inside — no longer finds the type
  of that name. (ADR-0098)
- **An actual `var` parameter may not denote a component of a packed variable,
  the selector of a variant part, or a component of a string-type** (§6.6.3.3;
  the third sentence is ISO/IEC 10206:1991 §6.7.3.3 and reaches variable-strings).
  Packing does **not** propagate inward: `pa[1].f` over a `packed array of rec`
  is still legal, because `pa[1]` possesses an unpacked record. (ADR-0099,
  ADR-0101)
- **A set-type's packing decides compatibility** (§6.4.5 c). `set of boolean`
  and `packed set of false..true` are no longer compatible. A set-*constructor*
  is exempt and always was — §6.7.1 leaves it uncommitted — so `p := [true]`
  fits either. (ADR-0093)
- **A string-type is four properties at once** (§6.4.3.2): packed, an integer
  subrange index, a smallest index *value* of 1, and a component that is `char`
  and not a subrange of one. ISO 7185 adds a largest value above 1;
  ISO/IEC 10206:1991 §6.4.3.3.2 drops that clause and nothing else. An array
  meeting only some of these is no longer treated as a string. (ADR-0090)
- **A value parameter's type may not contain a file** (§6.6.3.2) — the check
  asked whether the type *was* a file, so a record or array holding one was
  copied. (ADR-0092)
- **An actual `var` parameter may not be written `(x)`** (§6.5.1 lists no
  parenthesised variable-access). The parser had been discarding the brackets,
  so `p((x))` and `p(x)` were the same tree. (ADR-0092)
- **Congruity is over parameter *sections*, not parameters** (§6.6.3.6), so
  `(var a, b: integer)` and `(var a: integer; var b: integer)` are not congruous
  and a procedural parameter may not be passed where the other is expected.
  (ADR-0092)
- **A `forward` directive must follow a heading, not a procedure-identification**
  (§6.6.1); the compiler recognised the resumption and never looked at the
  directive. (ADR-0091)
- **A pointer's domain-type must be declared** even in a block with no type
  part (§6.4.4) — the check ran only when a run of type definitions ended, so
  such a program kept an unknown domain in silence. (ADR-0091)
- **A separator is required between a number and a following identifier,
  word-symbol or number** (§6.1.10), so `1two` is no longer two tokens. Only the
  decimal form: an extended-digit sequence is maximal, a letter being a digit
  there. (ADR-0091)
- **A parameterless function identifier is not a pointer-variable** (§6.5.4), so
  `f^` where `f` is a function is refused. ADR-0056's parser gate cannot see this
  shape — a parameterless call is a bare identifier — so Sema decides it.
  (ADR-0091)
- **An assignment to a function identifier must be inside that function**
  (§6.8.2.2 says *contain*), so a sibling procedure assigning another function's
  result is refused. A procedure *nested* inside the function may still do it,
  and always could. (ADR-0094)

#### Documentation of what is not enforced

- **`doc/implementation-defined.md` §6 lists the programs this compiler accepts
  that the standard requires to be rejected**, grouped by cause, where it had
  named none of them. Clause 5.1 c) requires them to be documented and the
  largest — §6.2.2.9's rule that a defining-point precedes every applied
  occurrence in its region — accounts for nine on its own.
- **`doc/implementation-defined.md` §3 names eight more unreported errors** —
  ISO 7185's D.5, D.6, D.12, D.13, D.19, D.27, D.30 and D.48. Nothing about the
  compiler changed: each had been unenforced since the feature it belongs to
  landed, and the section had been written one feature at a time with nothing
  reading Annex D end to end against it. It is now keyed to Annex D and
  regenerable — every `ERROR` row of `tests/bsi/expected.tsv` carries the
  number it names — and it says which two entries stop the suite's own programs
  without being enforced.

## [1.0.0] — 2026-08-14

**The toolchain stands on its own.** v0.1.0 said the number would reach 1.0.0
"when the toolchain stands on its own, not when the language does" — and this is
that release. `selfhost/compiler.pas` is the only compiler, `seed/pascalc.ll`
builds it, and a clone with no C++ compiler and no LLVM development files
compiles the compiler, passes 435 tests, reaches the stage-2/stage-3 fixed point
and proves 43 SMT rules.

The language is unchanged from 0.1.0 — both standards were already complete. The
major version is about what it takes to build this, and about `pascalc-s0`
disappearing from the command line.

### Removed

- **Stage 0, the C++ compiler.** `src/` and `selfhost/difftest.sh` are deleted;
  `selfhost/compiler.pas` is the only compiler. `seed/pascalc.ll` — a working
  compiler in LLVM IR, committed — is what builds it, so a checkout still builds
  itself. (ADR-0085)
- **LLVM as a build dependency.** Nothing links `libLLVM`; `cmake` needs no
  `LLVM_DIR`, only `clang` on PATH to assemble IR.
- The differential test, which compared two independent implementations over 436
  sources. Nothing replaces it, and ADR-0085 says what that costs.

### Added

- **`tools/pascalcc`** — compile *and* link. `pascalc` writes IR and stops,
  permanently: no standard Pascal program can start an assembler.
- `--dump-tokens`, `--dump-ast`, `--dump-sema`, `--dump-all` on `pascalc`, and
  157 error-path sources adopted as real test cases with `.err` goldens, taking
  the suite from 279 to 435.

### Changed

- **`pascalc` is quiet on success** and writes `file:line:col: error: message`
  on failure, where it used to write three dump sections unconditionally.
- The repository is **x86-64 Linux only**: the seed carries a target triple.
  Tag `v0.1.0` is the last commit where a C++ compiler could reproduce a
  compiler from source alone.

### Fixed

- `cmake --build` left a stale `build/bin/pascalc` when the compiler failed to
  build, so `ctest` passed against a compiler that did not match the source.
- A fresh configure could not create `build/bin` once no C++ executable target
  remained.
- `selfhost/badparse/variant-in-variant.pas` had been accepted by both compilers
  since ADR-0026 and was no longer a negative test; a differential oracle cannot
  see a test that has stopped testing anything. Deleted — the feature is covered
  by `tests/nested_variants.pas`.

## [0.1.0] — 2026-08-14

The first versioned release. It is `0.y.z` rather than `1.0.0` deliberately:
the language is complete and the bootstrap closes, but `pascalc-s0` is still
what builds `pascalc`, no seed is checked in, and `pascalc` cannot link. The
number will reach 1.0.0 when the toolchain stands on its own, not when the
language does.

### Added

- **The whole of ISO 7185 Standard Pascal**, under `--std=iso7185` (the
  default): procedures and functions nested to any depth with `forward`,
  procedural and functional parameters; arrays, records, variant parts, sets,
  pointers and recursive types; enumerations, subranges, `case` and `with`;
  text files with the buffer variable `f^`, and `file of T`; `goto`, including
  the non-local form out of a block into an enclosing one; `pack`, `unpack` and
  `page`; and string constants.
- **The whole of ISO/IEC 10206:1991 Extended Pascal**, under `--std=extended`.
  The two are *not* nested — Extended Pascal reserves word-symbols a valid ISO
  7185 program may use as identifiers — so the standard is a property of the
  source. Among what it adds: `otherwise` in a case statement and in a variant
  part; exponentiation (`**` and `pow`); non-decimal literals; schema types and
  discriminated schemata; schematic and protected parameters; type inquiry;
  initial-state specifiers (`value`); `complex`; direct-access files; the
  `string` schema, substrings, `readstr` and `writestr`; restricted types;
  structured-value and set-value constructors; constant-accesses; binding
  (`bind`, `unbind`, `binding`); time stamps; short-circuit `and then` and
  `or else`; `for … in` over a set; modules with `export`/`import`; and §6.13's
  separately translated program-components.
- **`pascalc`, the compiler written in Afterschool Pascal.** `cmake --build`
  produces it by translating `selfhost/compiler.pas` with `pascalc-s0`. It
  compiles itself: stage 2 equals stage 3, so the source is a fixed point.
- **A command line for `pascalc`** — `-o`, `--std=`, `--import`, `--version`,
  `-h` — read through the binding of its own program-parameters, which is the
  only channel either standard gives a program to its arguments.
- **`--version`** on both compilers.
- **Formal verification** (`verify/`): 43 SMT rules proving the lowering
  against a property-style statement of the standard, 27 of them for every
  32-bit input, with no known gaps.
- **`doc/implementation-defined.md`**, the document clause 5.1 requires: the
  compliance level (**level 0**), every implementation-defined and
  -dependent feature of both standards' annexes, every error not reported, and
  the extensions and restrictions.

### Changed

- **`halt` accepts an optional exit status**, an extension: `halt(1)` was a
  compile-time error before, so no conforming program is affected, and a bare
  `halt` still exits 0. Neither standard models an exit status, and without one
  a compiler written in Pascal cannot report failure. (ADR-0084)
- **`selfhost/compiler.pas` is written in Extended Pascal**, where it was
  ISO 7185. This changes nothing about the language the compiler *accepts*.
  (ADR-0082)

### Fixed

Every entry here changes what an already-valid program does, and each was found
by compiling a probe for a clause rather than by a test failing.

- **A program-parameter is bindable** (§6.5.1) and **`binding(p)` reports the
  argument it was bound to** (§6.7.6.8). Both were unimplemented: `binding` on
  a program-parameter was refused at compile time, and a bound one reported
  `false` with an empty name.
- **`unbind` clears the binding made before the program started.** It left a
  program-parameter reporting `argv[0]` afterwards.
- **`BindingType.name` is the same type as a program's own `string(255)`.** It
  was built outside the schema intern table, so §6.4.8's identity rule failed
  for it and it could not be passed to `procedure p(var s: string)`.
- **`i mod j` with a negative `j` is an error** (§6.7.2.2), as the constant
  folder had always said and the emitted code had not.
- **`ln`, `sqrt`, `x/y` and `dispose(nil)`** report the errors Annex D names,
  where they had returned a value.
- **A `for` statement's control variable must be declared in the block that
  contains the statement** (§6.8.3.9).
- **A comment may be closed by either delimiter** (§6.1.8): `{ … *)` is one
  comment, and was two loops that could not.
- **`reset(input)` no longer discards a character** the stream had consumed.
- **A field width of zero** writes what §6.10.3 says for each type — three
  different answers, not one — and a width below a string's length truncates
  it, in both standards.
- **`char + char`** is a two-character string (§6.8.3.6).
- **Declaration parts have an order under `--std=iso7185`** (§6.2.1) and may
  interleave under `--std=extended` (§6.2.1, §6.2.2.9).
- **A constant may not be selected from under ISO 7185**, §6.8.8 belonging to
  the next standard; and **`f()` is refused in both**, Pascal having no empty
  argument list.
- **`const q = nil`** is accepted under `--std=extended` (§6.7.1).
- Crashes fixed: a designator rooted at a `with` binding over a heap variable,
  and both dumps on a source declaring only modules.

### Known limitations

- `pascalc` writes LLVM IR and **does not link** — neither standard has process
  control, so assembling is a separate `clang` step. `pascalc-s0` links.
- Conformant array parameters (§6.6.3.6 e), §6.6.3.7, §6.6.3.8) are not
  accepted; this is a **level 0** processor.
- Twelve command-line arguments and eight `--import`s are the limits of
  `pascalc`; both report rather than truncate.
- Twelve errors go unreported, each named in `doc/implementation-defined.md`.
- No binary release: `pascalc-s0` links `libLLVM`, needs `clang` on `PATH`, and
  finds `libpasrt.a` through a baked-in path.

[1.4.0]: https://github.com/hiroshiyui/afterschool_pascal/releases/tag/v1.4.0
[1.3.1]: https://github.com/hiroshiyui/afterschool_pascal/releases/tag/v1.3.1
[1.3.0]: https://github.com/hiroshiyui/afterschool_pascal/releases/tag/v1.3.0
[1.2.0]: https://github.com/hiroshiyui/afterschool_pascal/releases/tag/v1.2.0
[1.1.1]: https://github.com/hiroshiyui/afterschool_pascal/releases/tag/v1.1.1
[1.1.0]: https://github.com/hiroshiyui/afterschool_pascal/releases/tag/v1.1.0
[1.0.0]: https://github.com/hiroshiyui/afterschool_pascal/releases/tag/v1.0.0
[0.1.0]: https://github.com/hiroshiyui/afterschool_pascal/releases/tag/v0.1.0
