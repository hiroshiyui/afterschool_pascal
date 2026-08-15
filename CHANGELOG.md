# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
follows [Semantic Versioning](https://semver.org/).

The public interface of a compiler is **the accepted language, the diagnostics
and the command line**. That is what these entries describe and what the version
number tracks.

Entries for a released version are left as they were written, so `pascalc-s0`
appears below in the release where it still existed.

## Unreleased

### Added

- **A licence.** GPLv3-or-later, `Copyright (C) 2026 Hui-Hong You`, with a
  linking exception on the runtime: `runtime/pasrt.c` is linked into every
  program this compiler builds, and without the exception compiling an ordinary
  Pascal program would place that program under the GPL. It does not — see
  `COPYING.RUNTIME`. The compiler itself carries no exception. The BSI
  validation suite and the standards under `doc/vendor/` are neither ours nor
  distributed, and `tests/bsi/README.md` states BSI's own three conditions.

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

### Changed

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

### Added

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

[1.0.0]: https://github.com/hiroshiyui/afterschool_pascal/releases/tag/v1.0.0
[0.1.0]: https://github.com/hiroshiyui/afterschool_pascal/releases/tag/v0.1.0
