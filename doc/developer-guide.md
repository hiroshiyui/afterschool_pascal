# Developer guide

For working **on** the compiler rather than with it. `README.md` is the
user-facing document — what the compiler is, how to build it, how to invoke it,
and what language it accepts; this one is the repository, the bootstrap, the
oracles and the conventions a change has to satisfy.

Two other documents sit beside it. `doc/sop.md` is the standard operating
procedure — how a change is classified, what its class has to satisfy, and, in
§7, the standing register of what none of the checks here can see.
`CLAUDE.md` is the same ground in the form an agent needs it, and
`doc/design-digest.md` is a paragraph per mechanism with the record behind each.

## How it fits together

| File | Role |
| --- | --- |
| `selfhost/compiler.pas` | **the compiler** — lexer, parser, Sema, code generator and driver, one source file |
| `selfhost/compiler.std` | one word: which standard that source is written in |
| `seed/pascalc.ll` | a working compiler in IR, committed, so the tree can build itself |
| `runtime/pasrt.c` | formatted output and runtime checks |
| `tools/pascalcc` | compile *and link*, which the compiler cannot do for itself |
| `src/` | the reference front end — lexer, parser and Sema only, so difftest has a second answer |
| `lib/`, `lib/dialect/` | the standard library, in two layers: `lib/` is written in `--std=extended` and usable from it, `lib/dialect/` needs the dialect and is where the `external` bindings live (ADR-0114, ADR-0120) |
| `doc/` | the records, the reference documents and this guide |
| `tests/` | one `.pas` per case, with expected stdout in `.out` or an expected failure in `.err` |
| `tests/extended/` | the same, for cases written in Extended Pascal — the directory selects `--std` |
| `tests/dialect/` | the same again, for `--std=afterschool` — three corpora, three modes, and the path is what tells every harness which (ADR-0117) |
| `selfhost/badparse/`, `selfhost/badsema/` | one file per diagnostic; the parser stops at its first, Sema accumulates |
| `tests/dumps/` | what the *compiler* writes under a `--dump` flag, rather than what a program wrote |
| `tests/spec/` | scenarios written against clauses of the two standards, each tagged with its clause |
| `tests/bsi/` | the fetched validation suite, and a catalogue of what this compiler does with all 812 |
| `tests/checks/` | the gates and their catalogues — which diagnostics, procedures and statements the corpus reaches, whether the two front ends still agree, whether a lowering changed without its model, whether a second backend builds the same compiler, and the two rules no `tests/` case can express: that a discarded base still yields a range (`model-drift-base`) and that program-components translated under different `--std` do not link (`mixed-mode-link`, with its own two-component corpus in `tests/checks/mixedmode/`). `foreign-reserved` is the sixth catalogue and reads no file: its list lives in the compiler, in `ReservedForeignName`, and the check compares it against the `declare` and `define` literals the emitter writes (ADR-0121). `kind-exhaustive` is the seventh and reads no file either: it takes the `typeKind` enumeration as the compiler declares it and requires every `case … kind of` to name every kind, because a case-statement with no matching label stops the program and a missing arm is therefore a crash no golden can hold (ADR-0124). `buffer-headroom` is the eighth and reads the compiler's own `tokMax` against the tokens its own source needs — a watch on a bound rather than a claim, because the array that has to hold this source is the *seed's* and raising the constant here does not raise the one that matters (ADR-0126) |
| `verify/` | SMT proofs that the lowering means what ISO 7185 says |
| `selfhost/difftest.sh` | the two front ends' `--dump` output, over every Pascal source in the tree |
| `selfhost/irtest.sh` | runs what the compiler builds, and requires stage 2 = stage 3 |
| `selfhost/producttest.sh` | that `build/bin/pascalc` itself exists, versions itself, reports failure, and that both it and `tools/pascalcc` document every option they accept |

Two constraints shaped this, and only one is still live:

* **Textual `.ll` output is a first-class path, not a debugging aid.** It was
  the backend that had to survive the rewrite; it is now the backend, and
  `seed/pascalc.ll` makes it the thing that lets the repository build itself.
* **No `dynamic_cast`, no exceptions in the AST walk** — a rule about the C++
  that no longer exists. It is why the AST is a tag and a variant record, which
  is the shape `selfhost/compiler.pas` still has, so the record explains the
  code even though it constrains nothing.

## The second front end

`clang` is wanted as an assembler and a linker; the C++ in this tree is for
something else entirely. `src/` builds `pascalc-s0`, which is
**not a compiler**: lexer, parser and Sema only, no code generator and no LLVM.
It exists so that `selfhost/difftest.sh` has a second answer to compare — two
independent front ends over every Pascal source in the tree, agreeing token for
token, node for node ([ADR-0108](adr/0108-the-reference-front-end-comes-back.md)).
Nothing it produces ships, and `build/bin/pascalc` does not depend on it.

It was a whole compiler once, and was retired when it had nothing left to do
([ADR-0085](adr/0085-stage-0-is-retired.md)); what that cost is written down
there rather than glossed, and getting it back — as a front end, at a fraction
of the size — is what ADR-0108 answers. Tag `v0.1.0` is the last commit where it
generated code.

## Bootstrap plan

The classic three-stage build, and it is **finished**. Stage 0 was a compiler
written in C++, kept only until it had nothing left to do; it was retired once
the Pascal compiler was the product, and what used to start the chain is now a
committed artefact:

```
seed      seed/pascalc.ll        — a working compiler, in IR, in this repository
stage 1   pascalc1 = seed(compiler.pas)         this is build/bin/pascalc
stage 2   pascalc2 = pascalc1(compiler.pas)
stage 3   pascalc3 = pascalc2(compiler.pas)     require pascalc2 ≡ pascalc3 byte-for-byte
```

**This holds.** The compiler compiles itself, and stage 2 and stage 3 are
identical, byte for byte, checked under `ctest` by `selfhost/irtest.sh`.

What the fixed point proves has never depended on which compiler started the
chain, which is why replacing stage 0 with the seed cost the claim nothing —
and why retiring stage 0 was possible at all
([ADR-0085](adr/0085-stage-0-is-retired.md)). What it *did* cost is the
differential test, and that record says so plainly rather than in passing.

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
the parser, Sema, the code generator and its own driver, in **one source file**,
because neither standard has an include mechanism and the finished compiler is
one source. It is itself written in **Extended Pascal** — the language it is
written in and the language it accepts are independent, and only that standard
lets a program read its own command line
([ADR-0082](adr/0082-the-stage-1-compiler-is-extended-pascal.md)). It is
checked by running what it builds against 404 golden files, and then by closing
the bootstrap.

```sh
selfhost/irtest.sh build/bin/pascalc-seed   # also runs under ctest
```

That compiles every case in `tests/` with the compiler, links the IR with
`clang`, runs it and compares against `tests/*.out` and `tests/*.err`; then
compiles the compiler with itself twice and requires stage 2 and stage 3 to be
identical. A compiler that reproduced itself and nothing else would pass that
last comparison alone, so stage 2 is put through the golden suite too. See
[ADR-0025](adr/0025-the-code-generator-is-checked-by-running-it.md).

The error paths a valid program never reaches have a corpus of their own:
`selfhost/torture.pas` for the lexer, `selfhost/badparse/` for the parser (one
file per message, because it stops at its first) and `selfhost/badsema/` for
Sema (which accumulates). Those were compared between two compilers until
ADR-0085 left one; each is now pinned against a `.err` golden.

**It is also checked differentially**, against a second implementation of the
front end, stage for stage on every Pascal source in the tree — the strongest
oracle this project has. It was written against the C++ compiler stage 1 was
ported from; retiring stage 0 gave it up (ADR-0085) and ADR-0108 brought it
back, `src/` now being a lexer, parser and Sema with no code generator. What it
catches is worth knowing, because nothing else here catches it: a diagnostic
that named two types identically and explained nothing, a comment-delimiter
rule implemented wrongly in *both* compilers, a builtin's enumerator one apart.

Two things it still cannot do. It says nothing about the **code generator**,
which it never compared — two backends' assembler text is not comparable — and
it cannot contradict a **reading**, because one author writes both sides. The
`.err` goldens above are what covers the first; `langspec-audit` is what
covers the second. See
[ADR-0022](adr/0022-the-lexer-port-is-checked-differentially.md),
[ADR-0023](adr/0023-the-ast-is-a-variant-record-and-a-sibling-list.md),
[ADR-0024](adr/0024-the-stage-1-compiler-becomes-one-source-file.md) and
[ADR-0085](adr/0085-stage-0-is-retired.md).

The AST is where the bootstrap constraints paid off: the node tag of
[ADR-0005](adr/0005-tag-dispatched-ast-without-cpp-rtti.md) became a
variant record's tag and the downcast helper became the `case` that reads it,
with no `dynamic_cast` to replace and nothing to redesign.

Done by hand, that is:

```sh
clang -Wno-override-module seed/pascalc.ll build/lib/libpasrt.a -lm -o stage1
./stage1 --std=extended selfhost/compiler.pas -o stage2.ll
clang stage2.ll build/lib/libpasrt.a -lm -o stage2
```

`stage2` is `build/bin/pascalc`, built the same way by `cmake --build`.

**A Pascal program has a command line only because ISO/IEC 10206:1991 gives it
one.** §6.5.1 makes every program-parameter possess "the bindability that is
bindable" whatever its type says, and §6.7.6.8's NOTE 2 makes `binding(f)`
report the binding §6.12 made *before the program was activated* — so
`binding(argk).name` is argument *k*. The compiler declares twelve
program-parameters, opens none of them, reads their bindings, and then `bind`s
its source, its output and each imported component to names it computed. An
unbound parameter is how the argument list ends, there being no other way to
count. See [ADR-0081](adr/0081-a-program-can-read-its-own-command-line.md)
and [ADR-0083](adr/0083-the-compiler-has-a-command-line.md).

ISO 7185 has none of that, which is why the compiler took four positional files
until it was rewritten in the other standard, and why the last line above is
still `clang`: neither standard has process control, so `pascalc` stops at the
IR permanently.

[doc/roadmap.md](roadmap.md) expands this: what items 5 and 6 actually
involve, the order the stage-1 source gets ported in, and the known limitations
— including the ones that are deliberate.

## Verified, not just tested

A compiler is the one program whose bugs are inherited by everything it builds,
and a miscompilation is silent — the source is right, the test is right, the
answer is wrong. So the arithmetic the compiler emits is **proved** correct
rather than sampled:

```sh
pip install z3-solver
python3 verify/verify.py
```

For each construct, `verify/` states what ISO 7185 requires of the result as a
*property*, models what the compiler emits, and asks Z3 whether any input makes
the two disagree. The rules established are the
non-negative `mod`, truncating `div`, `odd` on negative values, ordinal `char`
comparison, the exact integer-to-real widening, the `for` loop's inability to
overflow, an array subscript's inability to leave its bounds, a subrange's
inability to hold a value outside it, a set constructor containing exactly the
members it names, and the digit accumulator in `read` being unable to wrap
before its check sees it — most of them for all 2³² inputs. **The count lives
in `README.md` and nowhere else**, deliberately: it has moved four times, and
this paragraph carried a stale one for three releases because it kept a second
copy.

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
[ADR-0013](adr/0013-formal-verification-of-the-lowering.md) for what this
does and does not establish.

Every sweep that established the two standards were complete was run here,
though — Annex A's productions, both Annex Ds' errors, Annexes E and F's
implementation-defined features, Annex C's required identifiers — and a corpus
written here cannot escape what its authors thought to write. So the **BSI
Pascal Validation Suite** — 812 ISO 7185 programs published in 1982, © British Standards
Institution — is a `ctest` case as well. It is fetched rather than committed
(`tests/bsi/fetch.sh`), because BSI grants use and not redistribution, and the
case skips until you fetch it. **Running it is not a validation and nothing
here claims to be validated**: BSI makes the suite available on the condition
that no representation suggests a third-party validation was carried out, and
that any statement of results describes the whole suite rather than selected
tests. See `tests/bsi/README.md`. It found three real defects on its first run,
which is the point of having an oracle nobody here wrote.

A proof and a golden both cover only what they *name*, so how much of the
compiler the corpus actually reaches is measured rather than assumed. Three
`ctest` cases answer it — which diagnostics are printed by some case, which
procedures are entered, and which statements are run — and each fails when
coverage is lost. Counting for the first time is what tends to find things: 32
diagnostics nothing named, four documented `--dump` flags no case had ever
passed. `pascalc --coverage` is the product feature underneath the third and
works on any Pascal program. `doc/sop.md` §7 keeps the standing list of what
none of this sees — statement coverage is not branch coverage, and a clause
cited by a scenario is not a clause covered in depth.

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
* `name.components` — the other program-components this one is translated
  against, one path per line, relative to the case's own directory. Extended
  Pascal §6.13 separates translation from linking, and each component is
  compiled on its own and the objects linked together.
* `name.opt` — one word, the optimisation flag to compile this case with. Reach
  for it least: the corpus compiles at `-O2` and should go on doing so, but a
  defect in *storage* is invisible there, since LLVM may hoist an `alloca` whose
  address never escapes. The two cases that pin one both say `-O0` and would
  pass at `-O2` while the bug was present.

`tests/run_test.sh` compiles, runs, and diffs. Source paths are rewritten to
`<source>` in stderr, so diagnostics can be pinned without depending on where
the checkout lives.

Two smaller corpora have harnesses of their own, because what they compare is
not what a compiled program wrote:

* **`tests/dumps/`** compares what the *compiler* writes to standard output
  under `--dump-tokens`, `--dump-ast`, `--dump-sema` and `--dump-all`. Sidecars
  are `name.dump` (the golden), `name.flags` (which flag, `--dump-all` by
  default) and `name.std` (the standard, `iso7185` when absent).
* **`tests/spec/`** is written against *clauses* rather than against the
  compiler: scenarios in a subset of Gherkin, each tagged with the clause of
  ISO 7185 or ISO/IEC 10206:1991 whose requirement it states. Its README says
  how to add one, and what the suite deliberately is not.

## Decisions

`doc/adr/` records the architecture decisions and what each one costs — why the
AST avoids C++ RTTI, why textual IR is a supported output, why `and` and `or`
short-circuit, and what is still open. Start with
[ADR-0004](adr/0004-self-hosting-is-the-near-term-goal.md) if you only read
one.

[`doc/design-digest.md`](design-digest.md) is the condensed form: a
paragraph per mechanism — activation records, designators, schemata, strings,
modules, and every feature of both standards as it landed — each citing the
record behind it. It is where to look when you know the area but not the
number.

[`doc/afterschool-pascal-spec.md`](afterschool-pascal-spec.md) specifies the
dialect, as an amendment to ISO/IEC 10206:1991 in that standard's clause
numbering. It is the one document here written in the register of a
requirement rather than of an explanation, and ADR-0135's rule for keeping it
true is that it is derived from the decision records and verified by probe —
**never from `selfhost/compiler.pas`**, which would make it agree with the
compiler by construction and contradict nothing.

[`doc/implementation-defined.md`](implementation-defined.md) answers what the
two standards leave to a processor, and names every error this one does not
report — the document clause 5.1 requires. [doc/glossary.md](glossary.md)
defines the terms these documents use in a specific sense, and says which
decision governs each. Both are introduced in `README.md`, because a *user* of
the compiler needs the first of them as much as a contributor does.

