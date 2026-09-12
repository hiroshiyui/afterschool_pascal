# How it got here

The record of how this compiler reached where it is: the bootstrap, the two
standards, the sweeps that checked them, and the dialect one increment at a
time.

**Everything here is settled.** What is still open — the goal, what blocks it,
the questions no ADR has answered, and the known limitations — is in
[`doc/roadmap.md`](roadmap.md), which is the document that changes. This one
grows only by having something added to the end of it.

The two were one file until they were not. A roadmap and a history have
different readers and different lifetimes, and keeping them together meant the
part that never changes was the first 2,000 lines a reader met.

## How to read this

| Chapter | What it holds |
| --- | --- |
| [The three-stage build](#the-three-stage-build) | how the compiler builds itself, and what "stage 2 = stage 3" means |
| [The six bootstrap items](#the-six-bootstrap-items-all-done) | what self-hosting needed, with [text files](#item-5--text-files-done) and [strings](#item-6--character-strings-decided) written out |
| [Stage 1](#stage-1-done) | the port to Pascal, and [what it taught](#what-the-port-taught) |
| [Beyond self-hosting](#beyond-self-hosting) | [what ISO 7185 had left](#what-iso-7185-had-left) once the compiler stood on its own |
| [Stage 2](#stage-2--isoiec-102061991) | ISO/IEC 10206:1991 — [how it arrives](#how-the-second-standard-arrives), [every feature](#the-features-in-the-order-they-landed), [what is left](#what-is-left) |
| [Conformance sweeps](#conformance-sweeps) | what was checked rather than asserted, and what that found |
| [The two things that were not features](#the-two-things-that-were-not-features) | a required document, and an oracle nobody here wrote |
| [The dialect, increment by increment](#the-dialect-increment-by-increment) | forty-seven of them, [indexed](#the-increments-at-a-glance) — the first thirty with a section each, and [why the rest are a table](#the-increments-after-thirty) |
| [What the roadmap answered](#what-the-roadmap-answered) | the questions that page carried and closed, and what each found on its first run |
| [Cross-platform support](#cross-platform-support-measured) | what the x86-64 lock turned out to be, measured over twenty-five targets |
| [The text model](#the-text-model) | AP 6.4.15 in four increments, and where its oracle story ends |
| [The examples](#the-examples-and-what-writing-them-found) | twelve programs written to be read, each a case, and the seven findings writing them produced (ADR-0295) |
| [The oracles turned on themselves](#the-oracles-turned-on-themselves) | eight gates that check another gate's blind spot, five of them checking a *document* |
| [The compiler becomes three program-components](#the-compiler-becomes-three-program-components) | ADR-0233 — why one source file stopped being the answer, and why the count is three rather than two |
| [A second processor answers the corpus](#a-second-processor-answers-the-corpus) | Free Pascal under `-Miso`, the last of the roadmap's tasks, taken because the option was shrinking |
| [The language server](#the-language-server-and-the-bound-it-found-before-it-ran) | the one client big enough to answer a usability question, and what it found before it ran |
| [A second transport over one program](#a-second-transport-over-one-program) | MCP over the language server's own binary, kept in the form the proposal had, with what actually happened marked where the two differ — [and it is in use here](#and-it-is-in-use-here) |
| [The three questions the roadmap closed after version 3](#the-three-questions-the-roadmap-closed-after-version-3) | three of the four struck, in the form they had when they were |
| [Version 3](#version-3--what-it-took-and-what-it-left) | four proposals, three records, one that dissolved, and the one left open |
| [What a daily program could not reach for](#what-a-daily-program-could-not-reach-for-and-now-can) | the roadmap chapter of eight estimates, moved whole when the last closed, and its own error rate |
| [What would make this easier to work on](#what-would-make-this-easier-to-work-on) | the roadmap's five tooling items, moved the same way — four built and the fifth never open |
| [What each landed feature left open](#what-each-landed-feature-left-open) | the FFI and container residue, and the prior it arrived at: ask whether the address can be retired at the call |
| [The concurrency row and the four cheaper answers](#the-concurrency-row-and-the-four-cheaper-answers) | the cell that became an essay — measure the cost before naming the mechanism, four times over and once against itself |
| [The four decisions the goal forced](#the-four-decisions-the-goal-forced) | ADR-0109's four, and the thing they have in common: not one decided the question its row was written to pose |
| [The 32-bit port, and the width it left](#the-32-bit-port-and-the-width-it-left) | the two struck rows of the cross-platform chapter, moved whole, and the third time a foreign width was wrong — found by a register nobody could have found it with |
| [After v3.6.0](#after-v360-a-configuration-file-and-the-boundary-audited) | six records in one day: a TOML library, a project reader that read all of it, and a command injection found, closed, audited and audited again |
| [The blind-spot register](#the-blind-spot-register-the-audits-and-what-closed) | `doc/sop.md` §7's six audits and every row struck as closed, moved whole when the register was compacted to what is open |
| [Windows, measured and then dropped](#windows-measured-and-then-dropped) | the roadmap's Windows row, whole, and what ADR-0380 changed on the day the platform was dropped |
| [The concurrency clauses, audited](#the-concurrency-clauses-audited) | four readers given the behaviour and not the reasoning found seven defects in a surface every gate here called green |
| [The first macOS run](#the-first-macos-run) | nine failures, five runs, and not one of them in the compiler — what a suite learns the first time it is run somewhere else |
| [The roadmap as it stood](#the-roadmap-as-it-stood-on-2026-09-07) | the whole page, verbatim, the moment before it was compacted to what is open |
| [WebAssembly, measured and then run](#webassembly-measured-and-then-run) | the slot Windows vacated, in four steps that each corrected the one before — and the two abstentions a gate had to learn |
| [The editor, un-withdrawn](#the-editor-un-withdrawn) | the only thing here withdrawn by decision and brought back, and the four increments that followed in nine days |

If you are here for **what the language accepts today**, this is the wrong
document: `README.md` is the user-facing statement and
[`doc/afterschool-pascal-spec.md`](afterschool-pascal-spec.md) is the dialect's
clause by clause. If you are here for **why** something is the shape it is,
find the ADR number here and read `doc/adr/` — this file says what happened and
the records say why.

---

## The three-stage build

```
seed      seed/pascalc.ll        — a working compiler, in IR, committed here
stage 1   pascalc1 = seed(compiler.pas)        this is build/bin/pascalc
stage 2   pascalc2 = pascalc1(compiler.pas)
stage 3   pascalc3 = pascalc2(compiler.pas)      require pascalc2 ≡ pascalc3 byte-for-byte
```

**The comparison now holds.** `selfhost/irtest.sh` runs all three stages under
ctest and requires stage 2 to equal stage 3; they are compared as IR rather than
as binaries, because IR is what the Pascal compiler emits (ADR-0025).

Stage 0 only had to be good enough to compile the Pascal-written compiler
*once*, which is why the feature list grew in the order it did rather than the
standard's. For as long as it existed, both compilers grew together — a feature
landed in C++ and in `selfhost/compiler.pas` in the same commit, because the
differential test compared them on every file in the tree. **That is what
retiring it ended** (ADR-0085): a feature is now written once.

The stage-2 ≡ stage-3 comparison is the whole point, and it does not depend on
what started the chain: stage 2 is built by a compiler the seed built, stage 3
by one that stage 2 built, and both come from the same source. The bytes match,
so the Pascal source is a fixed point.

## The six bootstrap items (all done)

| # | Feature | State | Record |
| --- | --- | --- | --- |
| 1 | Procedures and functions | **done** — nested to any depth, recursive, value and `var` parameters, `forward` | [ADR-0016](adr/0016-nested-procedures-use-static-links.md) |
| 2 | Arrays and records | **done** — any ordinal index, multi-dimensional, `packed`, nested, `with`, bounds-checked | [ADR-0017](adr/0017-structured-types-use-name-equivalence.md) |
| 3 | Enumerations, subranges, `case` | **done**, with the variant records they unlock | [ADR-0018](adr/0018-ordinal-types-and-variant-records.md) |
| 4 | Pointers, `new`/`dispose` | **done**, with the forward-referenced domain that makes a recursive type possible | [ADR-0019](adr/0019-pointers-and-the-only-forward-reference.md) |
| 5 | Text files | **done** — `reset`, `rewrite`, `read`, `readln`, `eof`, `eoln`, and the buffer variable with `get`/`put` | [ADR-0021](adr/0021-text-files-keep-the-buffer-variable.md) |
| 6 | Character strings | **decided** — a length-plus-buffer record, no extension; the `string` type arrived later, with the second standard | [ADR-0012](adr/0012-character-strings-for-self-hosting.md), [ADR-0051](adr/0051-a-string-value-is-a-pointer-and-a-length.md) |

Items 1–4 mean the AST of a self-hosted compiler is now *expressible*: the node
kind is an enumeration, the node is a variant record, and the tree is heap
allocated through a recursive pointer type. `tests/pointers.pas` builds exactly
that shape as a proof by construction. Item 5 means it can now read its input
and write its output, so **every structural prerequisite for stage 1 is in
place**.

Item 6 is a decision rather than a feature, and it is now made, so **the
language was finished for bootstrap purposes** at that point: what remained was
writing the Pascal, not growing what it is written in. That writing is done
too — see "Stage 1", below — and everything since has been conformance.

Alongside the language, 550 ctest cases — the Pascal programs of `tests/` and
`tests/extended/`, the error-path corpus of `selfhost/badparse/` and
`selfhost/badsema/`, the verification run, the bootstrap and the product check —
and 44 SMT rules, 28 of them for all 2³² inputs and 16 at bounded
width, with no known gaps.

### Item 5 — text files (done)

Delivered as ADR-0021. The two decisions worth remembering:

- **The buffer variable is real.** `f^`, `get` and `put` exist, and `read` and
  `write` are derived from them in the runtime the way ISO 7185 §6.6.5.2
  derives them. The apparently redundant primitive is one character of
  lookahead, which is exactly what the lexer at the head of the port is written
  against.

- **Program parameters bind to the command line**, in the order written, with
  `input` and `output` as the standard streams. §6.10 leaves the binding to the
  implementation, so this is the kind of choice that becomes folklore unless it
  is written down.

Two SMT rules came with it, both about `pas_read_int`'s digit accumulator —
the one place the file code computes a number that could be computed wrongly.
Everything else about files is a state property and is covered by tests, one of
which (`files_scratch.pas`, three thousand scratch files) fails by exhausting
the descriptor table if block exit ever stops closing files.

### Item 6 — character strings (decided)

Settled as ADR-0012: a length-plus-buffer record in strict ISO Pascal, no
extension, ADR-0002's conformance untouched. That record named the one thing
that would expire the decision — committing to Extended Pascal, which defines a
`string` type of its own — and it has since expired: ADR-0051 landed §6.4.3.3's
required schema. What follows is why the record shape was still right for a
compiler written in ISO 7185, which is what `selfhost/compiler.pas` is.

What settled it was measuring the existing compiler rather than reasoning about
the language. The record's own earlier warning — that strict ISO would cost
"every line that touches text" — turned out to be **wrong**:

- A compiler *reads text in and writes text out*; it rarely manipulates it. Of
  164 string concatenations in the C++ source, nearly all build a diagnostic or
  an LLVM label, and both are written — so in Pascal they become `write` calls
  and need no string to exist at all.

- Exactly one function returns a built-up string (`Type::name()`), and its
  Pascal form writes directly instead, which is what a text-emitting backend
  wants anyway.

- Diagnostics are never sorted, so a message can be written the moment it is
  produced and never stored.

- What must be stored is bounded and small: identifiers, the literals of the
  program being compiled, and about sixty padded entries in fixed tables.

`tests/bootstrap_strings.pas` is the evidence rather than an illustration —
the record, the lexer's accumulate-a-word loop, keyword matching against padded
literals, a symbol table interning by comparison, and IR emission — compiling
and running against the compiler as it stands.

## Stage 1 (done)

Nothing in the language was blocking, and these went in this order:

1. ~~**Port the lexer.**~~ **Done** (ADR-0022) — checked *at the time* against
   the C++ lexer on every Pascal source in the tree by `selfhost/difftest.sh`.
   Both are gone (ADR-0085), which is why that record is the one marked
   superseded: its decision was "not against a golden file", and goldens are
   what pin the lexer now.
2. ~~**Port the parser and the AST.**~~ **Done** (ADR-0023) — the bootstrap
   constraints paid: the `NK` tag became a variant record's tag and `as<T>()`
   became the `case` that reads it, with no cleverness needed.
3. ~~**Port Sema**, including the type arena.~~ **Done** (ADR-0024) — and with
   it the stage-1 sources merged into one `selfhost/compiler.pas`, because ISO
   has no include mechanism and a third program would have carried a third copy
   of the lexer. It dumps every stage in one pass, against `--dump-all`; 434
   files agree stage for stage today — every `.pas` in the tree, which is what
   the number tracks and why it moves with the corpus rather than with the
   port.
4. ~~**Port CodeGen against textual IR.**~~ **Done** (ADR-0025) — ADR-0006's
   path. The C++ backend still uses the LLVM API; the Pascal one prints `.ll`
   and `clang` assembles and links it. Binding the LLVM-C API from Pascal
   remains possible and remains off the critical path.

**Stage 1 is complete, and the bootstrap closes**: the compiler compiles itself,
and stage 2 and stage 3 are identical.

**Differential testing was the checkpoint**, and it did come before stage 1 was
declared working: the first three components are compared against the C++ ones
stage for stage, on every file in the tree, and each was merged into the same
program and dumped in the same pass rather than getting a harness of its own.
The fourth could not be — two backends' assembler text is not comparable, since
LLVM's printer is not a specification — so it is checked against the golden
output of the programs it builds instead, and then against itself.

The harness is only worth what its corpus reaches, and that has to be
*counted*, not assumed. **Every time it has been counted, something turned out
to be uncompared.** No file contained a tab, so the lexer's control-character
class was never exercised (ADR-0022). No file produced a parser diagnostic, so
all 43 message contexts and 61 token spellings were unchecked (ADR-0023). Sema
reached 48 of its 85 messages before `badsema/` was written (ADR-0024). Then
sets (ADR-0028), congruity (ADR-0030), non-text files (ADR-0031) and the
non-local goto (ADR-0032) each had mutations survive a green suite until their
corpus was extended. Every one was found by mutating the source and noticing
that nothing went red.

Those records disagree about *which* time it was — two of them say "the fourth"
and two say "the sixth". That is what a running tally across records that are
immutable once accepted does, and it is why the count is not kept here either:
the number was never the point, and the list above is.

### What the port taught

Three things the lexer port learned, which the next components will meet again
(ADR-0022):

- ISO's file model gives **one** character of lookahead and the lexer needs
  **three**, so a window over the buffer variable is unavoidable.

- The overflow check must precede the multiply: this compiler traps rather than
  wrapping (ADR-0014), so the C++ habit of converting in a wider type and
  comparing afterwards is not available to its own source.

- Pascal has no early return and no way to discard a function result, which
  changes how guards and character-consuming helpers are shaped.

Four more from the parser (ADR-0023):

- **A vector becomes a sibling list**, and the one place it shows is where the
  C++ walks a vector *backwards* (`with a, b do S`), which a list cannot.

- **The one exception becomes a flag.** No exceptions, and no `goto` in this
  compiler, so `aborted` is tested by every loop — where a forgotten test is an
  infinite loop rather than a wrong answer.

- **Field identifiers must be distinct across every variant** (§6.4.3.3), so
  the arms of the node type cannot all call their operand `base`.

- **Reading a function's own name is a call** (§6.8.2.2), so a node under
  construction cannot live in the result variable. `f^.field := v` compiles and
  recurses forever; only `new(f)` is caught.

And four from CodeGen (ADR-0025), before four from Sema:

- **The oracle changes when the output stops being a data structure.** A tree
  can be dumped in a format both sides write; a *program* can only be run.

- **Writing text instead of building a module made the port smaller.** No
  instruction list is needed, because the C++ builder never returns to a block
  it has left; and no named types are needed, because opaque pointers make
  every Pascal type non-recursive when printed.

- **The real literal never needed converting.** Carried as source text it goes
  straight into the IR, and LLVM's assembler is the `strtod` — the same
  correctly-rounded conversion the C++ side gets from its own. Three records
  deferred a conversion that turned out to be unnecessary.

- **The layout rules have to be written out**, because there is no DataLayout to
  ask. They are needed in only two places, and the one number that cannot be
  derived — the size of a file variable — is checked against `pasrt.h` by the
  harness.

And four from Sema (ADR-0024):

- **A selector may follow only a variable-access** (§6.5.1), so `Base(t)^.kind`
  cannot be written at all and every predicate takes a local first.

- **A check computed in a wider type has to be rearranged.** `hi - lo` over the
  whole integer type is `2*maxint`. This is the second such rewrite, so it is
  now a pattern to expect rather than a surprise.

- **`||` short-circuits, and the C++ relies on it** — a port that evaluated
  both subrange bounds would report a different number of errors.

- **`continue` has no Pascal equivalent**, and the nearest thing — an empty
  statement before the `else` — was rejected by this compiler until the
  conformance fix that followed the port. ISO 7185 §6.8.1 always allowed it.

- **A string-valued helper is worth designing away.** One hidden name was built
  from a type name; renaming it to use the frame slot removed the only reason
  the Pascal Sema would have needed a string-building `Type::name()`.

## Beyond self-hosting

Stage 3 compares equal, so this is the live section. The order was settled as
**finish base ISO 7185 first, and only then take on ISO/IEC 10206:1991
(Extended Pascal)** — and the first half of that is done, so the second has
begun (ADR-0033).

That ordering is what decides whether a feature is in scope. Anything ISO 7185
has is worth adding on conformance grounds alone, even where nothing in this
compiler's own source needs it — which was the bar during the bootstrap and is
no longer. Anything the standard lacks waits, and should then be taken from
Extended Pascal's spelling rather than invented here.

### What ISO 7185 had left

In the order they were taken — nothing is left now, and each entry says what
the feature turned out to cost:

- ~~**Sets.**~~ Done (ADR-0028): one 256-bit word, with the base type bounded
  at 0..255 under the latitude §6.4.3.4 gives.

- ~~**`goto` and labels.**~~ Done: the local form (ADR-0029), where §6.8.1's
  restriction turned out to be one prefix test on statement paths, and then the
  non-local one (ADR-0032) — a jump record in the *target's* activation record,
  reached through the static chain. The part that was not small is the one
  ADR-0029 predicted: the abandoned blocks' files, which have to be found
  dynamically because a procedural parameter can be called from a block that is
  not on the jumping procedure's static chain.

- ~~**Procedural and functional parameters.**~~ Done (ADR-0030): the value is
  the pair `{code, static link}`, so a passed procedure runs in the scope it
  was *declared* in. It is the first thing here that makes an activation
  record's address outlive the call that made it — safe only because the
  language gives no way to store the pair.

- ~~**Non-text files.**~~ Done (ADR-0031): a `file of T` is the text-file
  machine with the component size and the line structure made into two
  constants the runtime is told. `text` stays a type of its own, because
  §6.4.3.5 makes it one and only it has lines.

## Stage 2 — ISO/IEC 10206:1991

### How the second standard arrives

**Extended Pascal has begun.** It is the second stage, not an ad-hoc pile of
extensions. ADR-0033 settled how it arrives: `--std` selects the language per
source, ISO 7185 stays the default, and `tests/extended/` is the corpus. The
two are *not* nested — Extended Pascal reserves word-symbols a valid ISO 7185
program may use as identifiers, and the stage-1 compiler is such a program.

### The features, in the order they landed

**Every feature of the second standard gets a record**, including ones that
decide nothing a later feature has to live with. The point is not that each was
hard but that the language's growth reads end to end from `doc/adr/`; a feature
with a short record is then distinguishable from one that was never written
down. The list below is in that order — ADR number, which is also the order
they landed — rather than in the standard's.

- ~~**`otherwise`.**~~ Done (ADR-0033), in the case statement. It retires
  ADR-0018's "ISO 7185 has no `else` and none is invented": the standard has
  one now, and the lowering is unchanged — an otherwise-part is what the
  default block of the same switch holds.

- ~~**`otherwise` in a variant part.**~~ Done (ADR-0034). The same word in a
  record's `case`, and it turned out to touch neither the variant layout of
  ADR-0018 nor the paths of ADR-0026: the completer is an arm with no labels,
  and nothing in the layout ever reads a label. The one place that does is
  `new(p, c)`, where an unclaimed tag value now selects it.

- ~~**Case-constant ranges.**~~ Done (ADR-0035). `1..9` wherever a case
  constant may appear, in a case statement and in a variant alike, because
  Extended Pascal generalised the constant *list* and both name it. A range is
  tested rather than expanded, so `1..maxint` costs two comparisons.

- ~~**Non-decimal literals.**~~ Done (ADR-0036). `base#extended-digits` for any
  base in 2..36, with letters as the digits above nine (§6.1.5). Purely
  lexical: what the parser receives is an integer literal, so no rule anywhere
  later knows the difference. Two things worth remembering — the digit sequence
  is *maximal*, so `16#ffand` is one ill-formed number, and the overflow is
  caught *while accumulating*, because the Pascal lexer has no wider type to
  convert in and then compare.

- ~~**`pow` and `**`.**~~ Done (ADR-0037). Exponentiation, and with it the one
  precedence level Extended Pascal adds that ISO 7185 has not — so this is the
  first feature to change the shape of the expression grammar: every factor is
  now a primary, and a factor is a primary with an optional operator and
  another primary. `**` always yields a real and `pow` yields the type of its
  left operand, which is why the standard has two. Integer `pow` traps on
  overflow because it *is* repeated multiplication, and the proof rules reach
  into `runtime/pasrt.c` for the first time to say the check fires exactly when
  the exact power leaves the type.

- ~~**`and_then`/`or_else`**~~ Done (ADR-0038), and **the standard spells them
  `and then` and `or else`** — two words apiece, no underscore. Each is one
  word-symbol per §6.1.2, so the lexer joins two tokens rather than looking a
  spelling up, and the feature reserves nothing: all four of its words are
  already reserved in ISO 7185. It was indeed small, but not for the reason
  written here: the parser change was trivial and the *lexical* question — what
  may sit between the two words — was the one that needed deciding.

- ~~**Schemata**~~ Done, over seven records (ADR-0039 to ADR-0045). `vector(n:
  integer) = array [1..n] of real` and `vector(3)` work, and §6.4.8's identity
  rule — one tuple one type, distinct tuples distinct types — is an intern
  table rather than a comparison, so `assignable` gained no case at all. A
  discriminated schema produces an *ordinary* type, which is why codegen
  needed one line (for `v.n`) and the proof rules needed none.

  Six halves were left after the first record, and all six are now done:

  - ~~**A schematic formal parameter**~~ Done (ADR-0040). `procedure p(var v:
    vector)`. The bounds come from the actual, so they travel: a descriptor
    beside the address, the shape ADR-0030 already uses for a procedural
    parameter. It is the first array here whose extent is not known at compile
    time, which is what turned a size into emitted arithmetic. The proof rules
    needed nothing added, because the array rule was already quantified over
    its bounds.

  - ~~**Discriminants that are not constants**~~ Done (ADR-0041). `var s:
    vector(n)` — §6.2.3.2 evaluates them when the block is entered, so the
    variable's size is not known until then. It needed almost no new
    machinery: such a variable is ADR-0040's descriptor with the tuple
    *computed* on entry rather than brought by a caller. What it did need is
    the two checks ADR-0040 could argue away — a discriminant outside its own
    type, and a tuple that leaves an index range empty — because "the tuple
    was checked where the type was produced" only holds if every tuple is.

  - ~~**Assignment between two schematic types**~~ Done (ADR-0042), and it is
    the clause rather than a third mechanism: §6.4.6 a) is "the same type",
    §6.4.8 makes one schema with one tuple one type, and §6.4.6 d) says what
    happens when the tuples are not both known — a **dynamic-violation**,
    which §6.1's f) lets a processor report either at preparation time or
    during execution. So `vector(3) := vector(4)` stays a diagnostic and the
    generic case becomes one `icmp` per discriminant. Sema decides only that
    both types came from one schema; everything else was already written.

  - ~~**A schema as the domain of a pointer**~~ Done (ADR-0043). §6.4.4's
    domain-type may be a bare schema-name, and §6.7.5.3's `new(p, d1, ..., ds)`
    gives the tuple. The created variable has no activation record, so its
    tuple is a **header in front of it** and the pointer denotes the variable
    rather than the block — which is what leaves everything else a pointer does
    untouched. The header is rounded to 16 so `malloc`'s alignment survives to
    the variable; a corpus with no set component let a rounding of 8 pass every
    test until one was written.

  - ~~**A discriminant as a variant-selector**~~ Done (ADR-0044). §6.4.3.4's
    variant-selector may be a discriminant-identifier, so which arm of a
    variant part is live is fixed by the tuple rather than stored. The selector
    is then **not a field**, which is the whole design: it has no storage, the
    layout is a tagless `case T of`, codegen and `verify/` are untouched, and
    §6.4.3.4's dynamic-violation cannot be committed because no designator
    denotes the selector. What it costs is one flag saying a symbol is a bound
    discriminant — the *kind* cannot answer, because a constant production
    binds them as ordinary constants.

  - ~~**A schematic formal whose discriminants reach past an array**~~ Done
    (ADR-0045). A record may hold a dynamically bounded array as its **last**
    field — the shape `string` has, a length beside a buffer whose capacity is
    the discriminant. Only last, and no variant part, because both a later
    field and a variant part's shared block sit at an offset nothing can
    compute; the record's layout is therefore entirely static and only its
    *size* is dynamic, which is what `dynSize` already existed to say. LLVM had
    the representation already: a dynamically bounded array is `[0 x T]`, so
    such a record is a flexible-array-member struct and every field access is
    the getelementptr it always was.

  **Schemata are done**, and what they unblocked was the required schema
  `string` itself (§6.4.3.3) — expressible by hand once ADR-0045 landed, but
  its own type-class with a capacity, a truncating assignment and comparison
  across unequal lengths. It arrived as ADR-0051, below.

  And one **defect**, found while the assignment was being written and fixed
  on its own: a schema producing a `packed array [1..n] of char` produces a
  *string* type, and both of the things a string type can do read a length.
  Both read it from `Type::length()`, which is `hi - lo + 1` — on bounds that
  are discriminants that is arithmetic on placeholders, so every comparison
  answered `true` and every `write` printed nothing. No oracle saw it because
  the corpus had no schema producing a string; the length is now computed where
  the bounds are, and the equal-length requirement §6.7.2.5 makes is checked
  there too. It is the second time a wrong answer has hidden behind a
  plausible-looking number — the first was `hi - lo` over the whole integer
  type during the Sema port — and both were found by asking what a *number*
  meant rather than by a failing test.

- ~~**Protected parameters.**~~ Done (ADR-0046). §6.7.3.1's `protected`, and
  the first Extended Pascal feature here that adds no way to write anything
  down — it removes one. The enforcement is §6.5.1's one sentence, "no
  statement shall threaten a variable-access closest-containing a protected
  variable-identifier", and §6.9.4's list of what threatens one turned out to
  name only places this compiler had already decided the argument was a
  variable, so every check sits beside an existing test. Two things worth
  remembering: protection **forwards** — a protected parameter may be passed to
  another protected one, and without that clause the word would be unusable —
  and `new(p)` needs no check at all, because §6.4.1 makes a pointer
  unprotectable and so nothing that reaches `new` can be protected.

- ~~**Type-inquiry.**~~ Done (ADR-0047). §6.4.9's `type of x`, the only
  type-denoter that names a *variable*. It resolves to the `Type *` that
  variable already holds and builds nothing — which is not a shortcut but what
  the clause asks for: under ADR-0017's name equivalence a type-inquiry that
  built a type alike the original could not be assigned from it, and that is
  the one thing anybody writes one for. It reserves nothing, both of its words
  being ISO 7185 word-symbols already, and its parameter form needed no new
  lookup because a scope is pushed before the formals are built. Refused: a
  parameter naming itself (§6.7.3.1), and an object that is a schematic formal,
  whose bounds are in a descriptor a second name would have to share.

- ~~**Initial-state specifiers.**~~ Done (ADR-0048). §6.6's `value`, and the
  record's title is the design: the specifier belongs to the *type-denoter*, so
  a type-name hands it on to every variable of that type, and §6.2.3.5
  attributes it at every *activation* rather than once — a recursive
  procedure's local is created in its initial state on each call. It is a
  prologue beside the two that were already there, and `emitStore` does the
  storing, so both backends and `verify/` needed nothing new.

  - **Nonvarying (§6.8.2) is a question about what an expression reads**, not
    about what the compiler can fold: §6.6's own examples include `ord(red)`
    and `polar(exp(1.0), pi)`, so what survives the test is *computed* at block
    entry rather than folded into a constant.

  - **The parser decides where the word attaches, and only one reading
    parses.** `set of 1..9 value [2]` has one place for it and a recursive
    denoter would have taken it for the base type — so the three permitted
    positions parse the specifier and every nested denoter stops before the
    word. That is what makes §6.6 NOTE 3's `array [1..8] of char value '*'`
    the type error the note says it is.

  - **The first reserved word to cost the corpus something**: an existing test
    had a record field named `value`. ADR-0033's reason for making the standard
    a property of the source, made concrete.

  - A component-value may only be an **expression** here; §6.8.7's array-values
    and record-values are the structured-value-constructor feature, which is
    usable in an ordinary expression too and is therefore its own item. That
    deferral is closed by ADR-0061, below.

- ~~**Complex numbers.**~~ Done (ADR-0049). §6.4.2.2 e) makes `complex` a
  **simple** type, and that one word decides the feature: a complex is a value,
  assigned with a store and passed in a register, exactly where a set is
  (ADR-0028) and nowhere near the by-address machinery of ADR-0017.

  - **The representation is `<2 x double>`, a vector and not a struct**, for
    ADR-0030's reason: nothing may depend on how a struct is passed between
    the two backends. Only three functions know it is rectangular, which is
    what makes §6.4.2.2's NOTE 4 free to honour.

  - The arithmetic is inline; only the six transcendentals go to the runtime,
    and each is **two calls**, one per part — the same trade ADR-0030 made, so
    that no complex-shaped value ever crosses the C boundary.

  - **The first feature gated in Sema rather than in the lexer.** `complex`,
    `cmplx`, `re` and the rest are required *identifiers*, not word-symbols: a
    valid ISO 7185 program may declare them, and `tests/complex_redeclared.pas`
    is one that does. Sema had to learn which standard it is checking.

  - `abs` and `arg` of a complex yield a **real** — the two places table 2's
    result kind does not follow its operand — and §6.8.3.5 gives complex only
    `=` and `<>`, there being no order to give the other four.

- ~~**Direct-access files.**~~ Done (ADR-0050). §6.4.3.6's `file [T] of C`, and
  the record's title is the design: ADR-0031 made a `file of T` the text-file
  machine with two constants changed, and this makes a direct-access file that
  machine with **one number** added. `struct pas_file` gained one flag.

  - **Counted in components, never bytes**, because that is the unit the
    index-type gives — and the **lower bound is folded in the compiler**, so
    the runtime never sees an ordinal. `SeekRead(f, 'c')` on a
    `file ['a'..'z'] of T` arrives as 2, the same division of labour ADR-0017
    gave indexing.

  - `position` and `LastPosition` return a value of the **index type**, which
    is the whole reason that type is kept rather than checked and discarded.

  - **Seeking one past the end is legal** — that is the append position, and
    §6.7.5.2's pre-assertion says so.

  - **Update mode has exactly one door**, `SeekUpdate`, because §6.7.5.2 gives
    `reset` and `rewrite` no direct-access variant. What it buys is `update`:
    write the buffer back and *do not advance*.

  - The lookahead of ADR-0021 became observable for the first time: after a
    fill the stream is one component ahead of the program, so `position`,
    `update` and a mid-file `put` all have to step back.

- ~~**`string`.**~~ Done (ADR-0051). ADR-0012 chose the length-plus-buffer
  record partly because the project had not committed to this standard; it now
  has, so that reason expired, and ADR-0045 had already made the shape
  expressible. The record's title is the design: **a string value is a pointer
  and a length**, two scalars that travel separately — the third time this
  project has reached for ADR-0030's shape, and for the same reason each time.

  - **`substr` and `trim` copy nothing**: a value costs nothing to make under
    that representation. Only `+` makes characters that did not exist, and it
    takes them from a ring in the runtime, whose one limit — a single
    *statement* concatenating more than the ring holds — is stated rather than
    silently wrong.

  - **The required schema has no body**, which is what makes it required: the
    production builds the type instead of resolving a denoter, and §6.4.8's
    intern table then treats it like any other schema. A schematic formal
    `var s: string` is ADR-0040's descriptor with the capacity as its one
    discriminant.

  - **The canonical-string-type is that kind with a negative capacity** — no
    storage, so no capacity to exceed, which is exactly why §6.4.6 checks a
    value's length against the *destination's* capacity.

  - **Two comparisons that must not be unified**: §6.8.3.5's operators pad the
    shorter operand with spaces, §6.7.6.7's `EQ`/`LT` family compares lengths
    too. The standard's NOTE 3 says so outright, and the test prints both
    answers side by side.

  - It **retires ISO 7185's equal-length rule** and the trap `158549b` added
    with it. What that trap protected has not gone away — the defect was a
    length computed from placeholder bounds — so the evidence moved from a
    program that stops to one that answers.

  - Deferred and stated: substring *variables* (§6.5.6's `s[i..j]` as an
    assignment target), `readstr`/`writestr` (§6.7.5.5, which need a text file
    over a string buffer), a string-valued function result, and §6.10.3.6's
    zero and truncating field widths.

- ~~**Binding.**~~ Done (ADR-0052). §6.7.5.6's `bind`/`unbind`, §6.7.6.8's
  `binding` and §6.4.3.4's `BindingType`. It is the feature the string type
  unblocked: `BindingType.name` has "an implementation-defined
  variable-string-type", and there was none to give it before ADR-0051.

  - **The external entity is a file name**, which is the one thing ISO 7185
    could not express: §6.10 binds the program parameters *before* the program
    starts. A bound file is a program parameter that named itself, so `reset`,
    `rewrite` and `extend` needed no change — `pas_external` simply gained a
    third answer.

  - **`bindable` belongs to the type-denoter**, so a type-name hands it on
    (§6.4.1) — which is what makes `type btext = bindable text` the way to
    write a bindable *parameter*, since `text` never is.

  - **`binding(f)` is built in a hidden frame slot**, the mechanism a `with`
    binding uses: it is the only required function returning a record, and the
    call then *is* a designator, so a whole-record assignment and a value
    parameter both work with no case anywhere.

  - It found a real disagreement between the backends: the Pascal `LlSize` for
    a string was unrounded, so a record's field after one fell outside a
    whole-record copy. `irtest` caught it as a wrong answer, which is what
    that harness exists for — two backends can agree on every dump and still
    disagree about a number no dump prints.

- ~~**Modules.**~~ Done (ADR-0053). §6.11's module-declaration and §6.13's
  program-components, and with it the last of the eight features the README
  listed. It is the only one that changes what a *program* is.

  - **A level-0 activation record is a global**, and that one sentence is the
    whole of the code generator's share. A module has exactly one activation
    (§6.2.3.6) that must outlive the function commencing it, and the main
    program is in the same position — so `addressOf` asks a symbol's *owner*
    rather than its level, which is the only way an imported variable can be
    reached at all.

  - **Written order is a legal activation order and no sort produced it.**
    §6.2.2.9 already puts a module-heading before everything that imports its
    interface, so a supplier is textually first — exactly §6.2.3.6's
    condition. Finalizations run in reverse. Two modules can still supply each
    other through a *split* module, and §6.11.1 then forbids an
    initialization- or finalization-part in either — the one rule here that
    needs a reachability check rather than the text's order.

  - **An interface is a table, not a scope** (§6.2.2.2), a heading in a
    module-heading is `forward` under another name (§6.11.1), and a qualified
    name is told from a field selection by the *symbol* — three places where
    the feature reused a mechanism rather than adding one.

  - Five word-symbols, not seven: §6.1.5 and §6.1.6 make `interface` and
    `implementation` directives, which are identifiers exactly as `forward`
    is.

  - Deferred and stated: **separate compilation of program-components**, which
    §6.13 asks for with a *should* rather than a *shall* and which was thought
    to need an interface artefact this compiler does not define — ADR-0079
    found the artefact was the module-heading and did it; a module variable
    with computed discriminants; and a module-parameter that is neither
    `input` nor `output`, which §6.11.1 NOTE 6 lets go unbound.

- ~~**Constant-expressions.**~~ Done (ADR-0054). §6.8.2's
  `constant-expression = expression`, which replaces ISO 7185 §6.3's and
  §6.4.2.4's one-token `constant` in every position that asked for one. The
  feature is one function: `evalConst` already served the constant definition
  and `evalOrdinal` — a wrapper on it — already served subrange bounds, array
  bounds, case labels, variant labels and a schema's discriminants, so adding
  the expression grammar to that one place opened all six at once and no
  caller changed except to say less. The parser changed in exactly one spot:
  a bound is no longer two tokens from the `..`, so telling a subrange from a
  type name is a scan for a `..` at bracket depth zero, and only under
  `--std=extended`. Refused and stated: real-, set- and string-valued
  constant-expressions — the first because ADR-0025 carries a real literal as
  its source text and neither compiler has a float to fold with, the other
  two because a `Symbol` has nowhere to keep the value. ADR-0068 gave it
  somewhere for a string, so what is refused there is now the *operation*
  rather than the value: `const s = 'ab'` folds and `const t = 'a' + 'b'`
  does not.

- ~~**Structured function result types.**~~ Done (ADR-0055). §6.7.2, both
  halves of it: a function may return anything that is not, and does not
  contain, a file and is not bindable, and a result-variable-specification
  (`function mk(a, b: integer) = r: point`) gives the result a name. The two
  arrive together because §6.8.2.2 makes every *read* of a function identifier
  a recursive call, so without a name a structured result could be assigned
  whole and never built a field at a time. The result travels in storage the
  *caller* supplies — ADR-0052's hidden frame slot, generalised — and the
  callee binds the incoming address exactly as a `var` parameter does, which
  is why assignment, copying, subscripting and field selection over a result
  all needed nothing. It found a real bug in `selfhost/compiler.pas` the day
  it landed: `ParseTypeDenoter` assigned a *sibling* function's result and
  never its own, which five oracles had not noticed.

- ~~**Function-accesses.**~~ Done (ADR-0056). §6.8.6: a call may carry
  selectors, so `mk(7, 8).y`, `scale(10)[2]` and `alloc(3)^` are expressions.
  It is the smallest feature in this list and the record's title says why —
  **a parser change**, one function in each compiler, with Sema and CodeGen
  told nothing. That is ADR-0055's dividend: a result living in memory already
  travels in caller-supplied storage, so a call in that position already
  yields an address.

  - **§6.8.6's NOTE was already written**, as `Sema::isDesignator` answering
    `false` for a call. An actual var parameter and a `read` target are two of
    its call sites; an assignment's target and a `with`'s record are refused
    one level earlier by the grammar, because §6.5.1's variable-accesses do
    not include a record-function-access. Four refusals, no new rule.

  - **§6.8.6.4 is the exception and it is a variable**, so `alloc(3)^.x := 1`
    is legal and a statement beginning with a name and arguments is no longer
    certainly a procedure-statement. Telling them apart is a scan to the
    *matching* `)` — the second bracket-depth walk this parser has needed.

  - The ISO 7185 gate could not be tested with a record result: §6.6.2 refuses
    that first, so the program would pass whatever the parser did. It returns
    a **pointer** instead. ADR-0054 found the same fault in
    `constexpr_iso.pas`; this time it was recognised before it landed.

  - Deferred with §6.5.6: **§6.8.6.5's substring-function-access**, because
    `parseSelectors` is now shared and would learn `[i..j]` once for both.

- ~~**Substring variables.**~~ Done (ADR-0057). §6.5.6's `s[i..j]` as a
  variable, and §6.8.6.5's substring of a function-access with it — one node,
  because §6.5.1 makes the first a variable-access and the second a value and
  the *base* is the whole difference, which `isDesignator` was already asking.
  It closes ADR-0056's deferral in the place that record named.

  - **The capacity is never a compile-time number and never needs to be.**
    §6.5.6 calls the result "a new fixed-string-type" of capacity `hi - lo + 1`;
    this compiler gives it the canonical-string-type, which under ADR-0051 is a
    pointer and a length. The only rule that reads a capacity is the store, and
    the store reads it at run time from the same subtraction.

  - **Writing one is the fixed-string store, unchanged**: §6.4.6 already pads a
    shorter value with spaces and refuses a longer one.

  - **The bounds check could not be shared with `substr`'s**, and the reason is
    exactly one program: `substr(s, 3, 0)` is the null-string and legal, while
    `s[3..2]` is an error — the two conditions agree everywhere except at the
    empty case, which is where a shared check would have been wrong in silence.

  - The Pascal port met §6.4.3.3's rule that field identifiers are distinct
    across every variant — the first new node kind since ADR-0023 recorded it,
    and it collided at once.

- ~~**Restricted types.**~~ Done (ADR-0058). §6.4.2.5's `restricted T`, the
  feature whose point is a type-name exported without its structure. The
  record's title is the design: a **type kind**, so every predicate answers
  `false` and each forbidden operation refuses it through the diagnostic it
  already had. Seven diagnostics in the negative test and six were written for
  other features.

  - **`isStructured` and `isMemory` are the only predicates that see through**,
    because how a value travels is not an operation the program performs.

  - **The comparison is the one refusal written down**, and only because
    §6.4.2.5's assignment rule had to teach `assignable` about restricted
    types — a relational operator asks `assignable`, so the permission leaked.
    A shared predicate's new permission reaches every caller of it.

  - It is the **first word-symbol too long for the Pascal keyword table**:
    `kwLit` is nine wide and `restricted` is ten. Recognised beside the table
    rather than repadding 188 literals, and printed in the token dump beside
    the two-word symbols, which are in no table either.

- ~~**Five required things.**~~ Done (ADR-0059). `maxchar` (§6.4.2.2 d)),
  `halt` (§6.7.5.7), `card` (§6.7.6.3), the two-argument `succ`/`pred`
  (§6.7.6.4) and the set symmetric difference `><` (§6.8.3.4) — each too small
  to be a feature and too separate to be part of one.

  - **`><` is decided in the lexer**, because under ISO 7185 the two characters
    can only be `>` followed by `<`, which no expression admits: joining them
    there would turn one clear diagnostic into a cascade. ADR-0036's argument
    again.

  - **`succ(x, k)` widens to i32 before it checks.** The one-argument form
    tests one end and steps; `ord(x) + k` may leave the type in either
    direction and by any amount, so the sum must not wrap before it is looked
    at.

  - **`halt` closes the open files through the same list ADR-0032 walks**,
    because a halt leaves every block without running its epilogue and "still
    open" and "abandoned" are the same set once nothing further will run.

  - Two enumerators had to be *placed* rather than written where they read
    best: the AST dump prints a builtin as its ordinal, so both compilers must
    agree on the index. `difftest` caught each as a number one apart.

- ~~**readstr and writestr.**~~ Done (ADR-0060). §6.7.5.5's two string
  transfer procedures, and the deferral ADR-0051 named: they need a text file
  over a string buffer, and now they have one.

  - **The standard defines them as file operations, and so does this
    compiler.** `fmemopen` and `open_memstream` give the runtime an ordinary
    `struct pas_file` with no external entity behind it, so every
    `pas_read_*` and `pas_write_*` primitive is reused *unchanged* — a field
    width, the spelling of a real and where a string read stops all mean what
    §6.10 says, because they are the same code.

  - **writestr's error condition was already emitted.** "eoln(f) is false upon
    completion" is false exactly when more was written than the destination
    holds, which is §6.4.6's capacity check every string store already makes.

  - The characters readstr reads from are **copied**, so `readstr(e, i, e)`
    reads into the variable it reads from; and the auxiliary file is
    heap-allocated per statement, so a writestr may appear in the
    write-parameters of another.

  - Both are parsed *by name*, as `read` and `write` are. That was a stated
    deviation — under `--std=extended` a program could not declare its own,
    where §6.7.5.5 makes them required identifiers — and ADR-0087 retired it
    by leaving the parser only the statement's shape and giving Sema the
    question of what the name denotes.

- ~~**Structured-value constructors.**~~ Done (ADR-0061). §6.8.7's array-value
  and record-value, and the initial-state form ADR-0048 deferred.

  - **A structured value is built, not computed.** An array and a record have
    no register form (ADR-0017), so the components are stored into the storage
    the value will occupy and the expression's value is that address — the
    hidden frame slot ADR-0055 gives a memory-living result at the top of an
    expression, the component itself for a nested value, and the destination
    for an assignment or an initial state.

  - **Three of the four productions were already here.** A selector is a
    case-constant-list (ADR-0035), a field-list-value corresponds to a
    field-list and an arm's is one too (ADR-0026), and a component-value is
    what `emitStore` already does — so a subrange component is range-checked
    and a string component padded by code written for something else.

  - **The completer is filled in first and the elements written over it**, so
    §6.8.7.2 b)'s "each component not mapped to by an element" needs no
    complement computed; and a component-value is emitted **once** however
    many components it is for, then copied.

  - **`[a: 1]` cannot be told apart by the parser**: it is an array-value when
    `a` is a constant and a record-value when it is a field name. Both are
    parsed as expressions and Sema decides from the type, which is the third
    bracket-depth lookahead scan in this parser.

  - Not done, and stated: §6.8.7.4's set-value (a set is a value and needs
    none of this machinery, and `sieve[2,3]` cannot be told from `a[2,3]`
    without the symbol), §6.8.8's constant-accesses — which that record calls
    "structured constants" — and a value of a dynamically bounded type. The
    first landed as ADR-0066, below.

- ~~**§6.8.7.4's set-value.**~~ Done (ADR-0066). The third form of §6.8.7.1's
  structured-value-constructor, and four lines of standard:
  `set-value = set-constructor`, so `digits[1, 3]` is `[1, 3]` with a type name
  in front and what the name adds is a **type**.

  - **The reason it was deferred is the reason it works.** ADR-0061 refused it
    because `sieve[2, 3]` cannot be told from `a[2, 3]` without the symbol —
    so the symbol is what tells them apart, in Sema, where ADR-0053 already
    parts a qualified name from a field selection and ADR-0044 a
    variant-selector from a tag-type. The parser builds a subscript spine and
    Sema walks down its base links to the root to ask what the name denotes.

  - **The spine carries the answer instead of being rewritten**, which is
    `FieldExpr::qualified`'s shape and forced by the same thing: the checker
    takes a raw pointer and cannot replace the node its parent holds.

  - **It makes a check ADR-0028 called impossible.** That record says
    `checkedForSetBase` is the check "a set constructor cannot make for itself,
    because a constructor does not know what it is being assigned to" — and a
    set-value knows, so §6.8.7.4's assignment-compatibility rule is that check
    moved to the constructor. `digits[i]` traps with no assignment in sight.

  - **One rule was given up in the parser and taken back in Sema**: a comma may
    now follow a range in brackets, because a set-value's members are a list
    and a substring's range is not, and the flag saying one followed is what
    keeps `s[1..3, 2]` from quietly meaning `s[1..3][2]` for a string.

  - It reserves nothing, and `verify/` gained nothing — no new arithmetic, and
    the one error condition is an existing check at a second call site.

- ~~**The three required real constants.**~~ Done (ADR-0062). §6.4.2.2 b)'s
  `minreal`, `maxreal` and `epsreal`, and the deferral three records had made.

  - **The text was always the mechanism.** ADR-0025 carries a real as the
    characters that were written and this compiler has no floating-point type,
    so what was missing was never a conversion — it was somewhere to put
    twenty-two characters. Each constant is the shortest decimal that
    round-trips to the binary64 value it names, spelled identically in both
    compilers.

  - Required *identifiers*, so shadowable; CodeGen and `verify/` untouched.
  - The test asserts the clause's property (`1.0 + epsreal > 1.0` and
    `1.0 + epsreal / 2.0 = 1.0`), not the printed digits.

  - A real-valued *constant-expression* is still refused (ADR-0054): these are
    values a symbol holds, not values an operator can produce.

- ~~**Set-member iteration.**~~ Done (ADR-0063). §6.9.3.9.3's `for v in s do`,
  the second of the two iteration-clauses §6.9.3.9.1 splits the for-statement
  into.

  - **A walk over the bits.** A set is one 256-bit word (ADR-0028), so the
    lowering is a counter over the base type's ordinals and the same bit test
    the `in` operator emits.

  - **Clamped to 0..255**, because a set *constructor* infers `set of integer`
    from `[1, 2]` and that type's ordinal range is −maxint..maxint. The first
    run scanned two billion values.

  - Three obligations came free: the set is a *value*, so evaluating it before
    the loop is evaluating it once; D.96's error is the store's existing range
    check; and the counter cannot overflow, so the sequence form's
    stop-before-stepping care is unnecessary rather than omitted.

  - Reserves nothing — `in` is already an ISO 7185 word-symbol.

- ~~**Zero field widths in `write`.**~~ Done (ADR-0064). §6.10.3.1 lowers the
  least width from one to zero, and every subclause under it then says what
  zero writes.

  - **Three different answers**: nothing for a string, a char or a Boolean;
    the digits for an integer, since §6.10.3.3 b) applies whenever the width
    is under IntDigits + 1; a full representation for a real, since both real
    forms clamp.

  - **The bound is checked in the compiler**, because which number is least is
    what the standard decides and the runtime is never told which language it
    was compiled for — and because `-1` has to stay usable as the "no width
    given" sentinel.

  - It **fixed two conformance gaps that predate Extended Pascal**:
    §6.10.3.6's truncation of a string written narrower than its length, which
    is ISO 7185 §6.9.3.6's rule word for word, and §6.10.3.4.1's DecPlaces
    derivation, which the runtime replaced with a hard-coded six.

  - Stated deviation: ExpDigits is not a fixed number.

- ~~**The time procedures.**~~ Done (ADR-0065). §6.7.5.8's `GetTimeStamp` and
  §6.7.6.9's `date` and `time`, over §6.4.3.4's packed `TimeStamp` — the only
  feature in either standard that reads something outside the program which is
  not a file.

  - **A time stamp is eight numbers, and the layout stays in the compiler.**
    The clock is sampled once and read field by field, so what crosses to the
    runtime is integers; passing the record was rejected for ADR-0030's
    reason, a Boolean field being an `i1`. §6.4.3.4's field order is then
    agreed in **three** places — Sema's record, CodeGen's `date`/`time` base
    indices, and the runtime's slot numbering — and cannot be reduced to one,
    since the runtime has no view of the record and ADR-0008 forbids CodeGen
    to look a field up by name. A test that gives every field a different
    small number is what holds them together.

  - **The subranges do most of the enforcement** (ADR-0018), which is what
    leaves §6.7.6.9's error condition small enough to be one function:
    February the 30th, and a year the fixed-width representation cannot
    write. `year` is the one field of a TimeStamp whose type does not bound
    it.

  - **§6.9.4 f) is the entry on that list ADR-0046 could not have a call site
    for**, its procedure not existing yet — the only place that record's "each
    check sits beside an existing `isDesignator` test" had to be written
    rather than found.

  - It **reserves nothing**, all four names being required identifiers; and
    `verify/` gained nothing, the two errors being calendar facts rather than
    lowering rules.

  - **The clock had to be made fixable before anything could test it.**
    Mutation testing found that `tm_mon` written unadjusted survives every
    oracle: no program knows what day it is except by asking the same
    function, so a test can assert only what holds at every moment, and an
    off-by-one holds at almost every moment. §6.7.5.8 leaves "current"
    implementation-defined, so it is now `SOURCE_DATE_EPOCH` when that is set
    — read as UTC — and the system clock otherwise. The harnesses gained a
    `name.epoch` convention beside `name.in`, and the eight fields have a
    golden file.

  - **Two of the thirty mutants changed the code rather than the tests**,
    which is the part worth remembering. An epoch is now rejected unless the
    conversion consumes the whole word, because C's `strtoll` answers 0 for a
    word it cannot read and would have dated every program 1970-01-01; and an
    epoch that parses but names no calendar date now takes §6.7.5.8's
    **invalid arm** rather than falling through to the clock, since answering
    a *set* variable with the wall clock made the output vary run to run. Both
    were wrong answers rather than refused ones, which a corpus of golden
    files is structurally poor at noticing. The second also made the standard's
    `DateValid` false arm reachable, and it had never once executed.
    Counting what the corpus reaches has now turned something up every time it
    has been done.

- ~~**§6.8.8's constant-accesses.**~~ Done (ADR-0069), and with them the
  structured constants ADR-0061 deferred and ADR-0068 half-unblocked. A
  constant-access is `isDesignator`'s shape with a constant at the bottom of
  it, so CodeGen and `verify/` gained nothing at all: the spine is the one the
  parser already built, and D.88 to D.91 are the array, string and substring
  bounds already proved. What the feature is *for* is §6.8.8.1's NOTE — `c[i]`
  denotes a different value on each iteration, so a constant-access is a
  run-time read — while a constant index makes it a constant, which is what
  §6.3.2's own `column1 = BlankCard[1]` needs.

  - A structured constant is a **global filled by a prologue**, not an LLVM
    aggregate initializer: printing one would need record padding, variant arms
    and 256-bit sets spelled as text in *both* backends, and ADR-0025's
    emitter has `LlSize`/`LlAlign` and no struct-literal printer.

  - It forced the **declaration parts to be read in written order**, which
    §6.2.1 has always required of Extended Pascal and Sema had never done —
    a conformance fix in its own right, since `const first = red` after a type
    part has no structured constant in it.

### What is left

**Nothing.**

- ~~**Separate compilation of program-components.**~~ Done (ADR-0079). §6.13's
  one sentence, and the last item on this list. ADR-0053 deferred it because it
  "would need an interface artefact this compiler does not define"; the artefact
  turned out to be the **module-heading**, which §6.11.1 already makes the whole
  of what a module exports and which is written in Pascal — so `--import` reads
  another component's *source* and no second file format exists.

  - **Nothing numbered may cross a component boundary**, which is what the
    feature actually cost. A procedure was named with a counter from this
    translation's walk and a variable with a frame index, and a frame's layout
    is decided by the module-*block* — the half a separate translation does not
    have. Each exported slot now carries an external name beside the record,
    which stays internal: `nm` on a component is its interface.

  - **The two compilers' objects are interchangeable.** A module translated by
    `selfhost/compiler.pas` linked against a program translated by the C++
    compiler,
    which is a sharper statement than either passing its own tests.

  - The stage-1 compiler takes the other components as one more program
    parameter, **concatenated** — ADR-0033's constraint for the third time —
    and that costs nothing to define, a sequence of program-components being
    exactly what a source file already is.

**With the time procedures the required procedures and functions are
complete**, with §6.8.8 the grammar is too, and with §6.13 the last *should*
is answered — so no production, required identifier, required type, lexical
rule or clause of ISO/IEC 10206:1991 is outstanding.

## Conformance sweeps

**That last sentence has been checked rather than asserted.** Each sweep below
took a bounded list — a grammar, a set of restrictions, an annex — and put a
compiled program against every entry, which is what ADR-0067 asks for before
any claim of completeness. Two ran in each direction: what the standard has and
this compiler refused, and what it accepts and no standard has.

Every sweep found something, and the finding always had the same shape: no
program in the corpus had written the construct, so all five oracles agreed
with a compiler that was wrong. That is the reason this section exists as a
list of dated sweeps rather than as a claim of conformance.

### Annex A, forwards: what the grammar admits and the compiler refused

ADR-0071. Every one of Annex A's 274 productions was probed with a compiled
program and also looked for in the corpus. It held for 268 of them; five were
constructs the standard admits and this compiler refused — `char + char`, a
qualified name in four type positions and in a subrange bound, a schema's
second name, a `with` over a type produced from a schema, and the `;` after a
variant-part-value — and one, `array [1..4] of file of integer`, was a segfault
(ADR-0070).

The sweep left two lists behind: ~30 accepted-but-unexercised forms, and the
implementation-defined choices of Annexes E and F, most of which had no
document. Both are taken up below.

### Annex A, backwards: what the compiler accepted and neither standard has

ADR-0072: fifteen ISO 7185 restrictions probed, six unenforced. Three are now
checked — an empty argument list, the order of a block's declaration parts, and
selecting from a constant — two are the deliberate deviations listed under
"Known limitations", and one was a fault in the probe rather than in the
compiler, `writeln(5:0)` being accepted and then trapped, which §6.1 f)
permits. Three ISO programs in the corpus were themselves out of order, which
is why nothing had failed.

### The unexercised forms, and the document clause 5.1 requires

ADR-0073 wrote the document — the compliance level, all 80 Annex E and F
entries, and the errors that go unreported — and writing it found two bugs,
since answering an entry meant compiling a probe for it.

**ADR-0076 is the other list.** Working through it found two things that were
not merely unchecked but wrong: a number read took a character more than §6.9.1
allows — `7..9` read as 7 and swallowed a point, so a program reading input
that looks like Pascal source would have lost the `..` — and §6.1.9's `(.` and
`.)` were never provided, which that clause requires of every processor whose
character set has the characters. Five more claims are now pinned by programs
rather than asserted, including `maxreal` and `minreal`, whose printed text was
checked only to thirteen significant digits in either compiler. The list is
shorter, not empty.

### Annex D: the errors the standard enumerates

ADR-0077. Annex D lists all sixty errors clause 6 defines, which makes it the
same kind of bounded checklist Annex A's productions were — and one nobody had
put a program against. Six were answered with a value instead: `ln` of a number
that is not positive, `sqrt` of a negative one, `x/y` with a zero divisor for
real *and* for complex, `i mod j` with j negative, and `dispose` of nil. None
was in the list of errors this processor leaves unreported, so each was
undocumented as well as unchecked, against a README that has said "ISO error
conditions trap" since ADR-0014.

`mod` is the one to remember: Sema's folder had always refused a constant
divisor that is not positive, with a comment saying the emitted code followed
the same rule. It did not — `const c = 5 mod -3` was a diagnostic and the same
expression over a variable computed 1. The compiler disagreeing with itself is
the sharpest form this section's shape takes.

**The second Annex D is the newer language's, and it was almost clean**
(ADR-0078). ISO/IEC 10206:1991 lists a hundred and five errors — the same sixty
plus the ones its features brought — and exactly one of the forty-five it adds
was unreported: `sqr` of a real that overflows, which is in the first annex too
(D.32). Everything else probed stopped the program already.

Six of sixty against one of forty-five is the interesting number, and the
difference is not the standards but when the code was written. Every Extended
Pascal feature here arrived with a record that had to say what it did *not* do,
and an error condition is the first thing that question turns up. ISO 7185's
arithmetic predates the practice, so `sqrt`, `ln`, real `/` and `mod` were
written when the only question was whether they computed the right answer. That
is the first time one of these sweeps has produced evidence about the method
rather than about the compiler.

The same sweep found the one §6.8.3.9 restriction that had never been checked:
a control variable must be declared in the block closest-containing the `for`
statement, so a procedure looping over the program's `i` is not a program
either standard has. Nothing in the corpus wrote one — including
`selfhost/compiler.pas`, whose 274 `for` statements all obey it already.

### Annex C: the required identifiers

ADR-0080, and the sweep that had never been run. Annex C enumerates all 94
required identifiers with the clause defining each, and every one was probed
with a program that *uses it* — compiled, run, and its answer checked. **All 94
pass**, and so do the three required directives. It is the first sweep here to
find nothing, which is the first evidence that the corpus has caught up with
the standard rather than a wasted afternoon.

It was run because the claim above — no required identifier outstanding — was
the one part of it backed by a reading rather than by probes, and because that
is the list that failed before: `pack`, `unpack` and `page` were missing from
ISO 7185 while three documents said otherwise, their names present in
`isRequiredName` and nowhere else. `tests/extended/required_identifiers.pas`
is what the sweep left behind, so the claim is now a test.

**The sweep's own first design would have passed a compiler that was wrong.**
It asked whether a name *resolves* and required two probes to agree before
reporting a gap, so a parse error in one masked the other — ADR-0034's fault,
two rejections compared and passing. "Is the name in scope" is not what a
required identifier means, which is precisely what `pack` and `page` had
already demonstrated.

### Refusals found by reading the clause rather than by probing

Two more constructs the standards have and this compiler rejected. Both are
rules a *syntactically valid* program passes, so the grammar sweep could not
have reached the first at all — and did reach the second, wrote it down here as
outstanding, and left it for two more rounds.

**A program-parameter that does not possess a file-type** (ADR-0074). Neither
standard restricts the list to files — §6.10 makes the binding of a non-file one
implementation-*dependent* and §6.12 drops the distinction — and the refusal's
message asserted a rule neither has. It is accepted now, bound to nothing and
consuming no argument. The same record adds §6.4.1's reason to the five
messages that name two types, which had been printing one spelling twice.

**`const q = nil`** (ADR-0075), rejected under both standards. ISO 7185 §6.3's
constant has no `nil`, so that half was right; ISO/IEC 10206:1991 §6.7.1 makes
it an unsigned-constant and §6.8.2 admits any nonvarying expression, so that
half was a gap — and being written down here rather than fixed is the only
reason it survived two more conformance rounds. §6.4.4's NOTE 2 gives the
token the type every pointer assignment accepts, so nothing outside the folder
changed. It also gave `nil^` a way of being written and so exposed a message
that named the wrong rule: the nil-value "does not identify a variable"
(NOTE 1), which is not the same complaint as "not a pointer".

### The validation suite's DEVIANCE category

**Twenty-nine programs the suite ran that a conforming processor must refuse,
and every one is refused now.** ADR-0086 fetched the BSI suite and catalogued
what this compiler did with all 812; twenty-seven `DEVIANCE` programs ran to
completion and two more printed PASS. Each was triaged to a clause, then fixed —
nine records, ADR-0089 to ADR-0099.

The shape of what it found is the point, not the count:

- **Six were one predicate.** §6.4.3.2 designates a string-type by four
  properties at once and `IsCharArray` asked two of them, so an array whose
  lower bound was not 1, or whose components were a *subrange* of char, was a
  string — and §6.9.3.6 gives a whole-array write the same rule (ADR-0090).

- **Five were a rule whose machinery already existed.** ADR-0046 built §6.9.4's
  threat list for protected parameters; §6.8.3.9's control-variable rule needed
  the same call sites to answer yes for a second reason (ADR-0089).

- **Two retired a deviation this repository had argued for and got wrong.**
  ADR-0072 declined §6.4.5 c)'s set-packing rule because "the standard does not
  say what packing a set-constructor has". §6.7.1 says exactly that, in a
  sentence both standards carry verbatim, and the claim had been copied into
  three documents and a test written to hold the compiler to it (ADR-0093).

- **One needed the ceiling raised.** The compiler interns every identifier and
  literal it reads, without deduplication, and sat 74 characters under
  `poolMax`; adding diagnostics broke the build with its own out-of-space
  message. The seed carried the old bound, so the fix was a bump plus an
  out-of-cycle reseed (ADR-0095).

**Three programs in this tree were wrong, and one was ours.** Two wrote `case
integer of` with two labels — legal only if every integer is named — while
testing something else entirely. `tests/extended/bindprogparam.pas` passed a
component of a packed `BindingType` by reference, illegal from the day ADR-0052
wrote it, twice, with every oracle agreeing.

**And the suite is not a replacement for reading the clause.** §6.6.3.3's packed
rule has two readings — the immediate container, or every container on the
designator — and §6.4.3.1 settles it: packing does not propagate inward. All 812
programs are silent on the difference; only the test written for it fails the
wrong reading (ADR-0099). That is ADR-0067's rule where it costs the most.

### The lexis is complete

**ADR-0033's caveat has expired.** That record said a word-symbol is reserved
only when the feature needing it lands, so until the list was empty
`--std=extended` would accept some programs a conforming processor rejects.
§6.1.2's word-symbol list adds thirteen to ISO 7185's — `and then`, `bindable`,
`export`, `import`, `module`, `only`, `or else`, `otherwise`, `pow`,
`protected`, `qualified`, `restricted`, `value` — and all thirteen are now
reserved, the first and seventh by the lexer joining two tokens (ADR-0038) and
the rest from a table. Nothing on the list above needs a fourteenth: the time
procedures are required *identifiers*, which §6.1.3 makes shadowable rather
than reserved. So the lexis is complete even though the language is not.

## The two things that were not features

Neither is a language feature, and both are now settled — the first against
itself, a few hours after being decided the other way. See below.

- **Retire stage 0 — done** (ADR-0085). `src/` and `selfhost/difftest.sh` are
  gone, `seed/pascalc.ll` builds the compiler, and a tree with no C++ compiler
  and no LLVM development files passes all 435 cases, reaches the
  stage-2/stage-3 fixed point and proves all 43 rules.

  **This entry decided the opposite a few hours earlier, and the record of why
  is worth more than the correction.** It weighed the loss of `difftest.sh` and
  of `verify/`'s subject against "a capability the fixed point already
  provides", and concluded there was nothing to gain. The gain it missed was not
  a capability: **every language feature shipped twice**, in C++ and in Pascal,
  in the same commit, and halving the cost of every future feature is the whole
  argument. A record framed around capabilities could not see it.

  The three parts this entry listed as open are all closed by it. A seed is
  committed and refreshed at release tags. The proofs were re-pointed at the
  Pascal backend, which needed no change to the model — `lowering.py` describes
  an emitted instruction sequence, not a compiler's internals — and are now tied
  to the compiler by `--crosscheck` and the 66 `trap_*.pas` goldens rather than
  by C++ a person could read. And the driver landed as ADR-0083.

  What was given up is stated where it belongs, in ADR-0085: a differential
  oracle over 436 sources, replaced by goldens that cannot disagree with the
  program that wrote them; and a repository that is now x86-64 Linux only,
  because a seed carries a target triple.

- **Keep the proofs alive across the port.** ADR-0025 made the decision the
  earlier version of this line asked for: the theorems stay attached to the C++
  model, and the Pascal generator is tied to it by *behaviour* — the golden
  files carry the traps and their messages, so a lowering that stopped checking
  fails `irtest.sh`.

  **Stage 0 was retired without re-pointing the model, and that was the right
  call.** `lowering.py` describes an emitted instruction sequence rather than
  any compiler's internals, so it transferred unchanged (ADR-0085). What it no
  longer has is a reader: the two backends were *measured* emitting different
  instruction counts for the same program, so the model could be checked
  against C++ line by line and cannot be checked against the Pascal emitter
  that way. The tie is now `--crosscheck`'s 44 adversarial values at `-O0` and
  `-O2` and the 66 `trap_*.pas` goldens — which is the tie ADR-0013 always
  specified, and is behavioural rather than structural. A rule can still drift
  from the emitter it claims to model without any of the 435 cases noticing,
  and no rule in the catalogue is aimed at that.


## The dialect, increment by increment

ADR-0109's goal and what still blocks it are in
[`doc/roadmap.md`](roadmap.md#the-goal-adr-0109); this chapter is what has been
built towards it so far.

### The known-limitations chapter, as it stood under the standards

`doc/roadmap.md`'s *Known limitations* was two lists, *Under ISO 7185* and
*Under ISO/IEC 10206:1991*, and every entry was a deviation from a clause
marked as a decision or as work. **Retired as a frame on 2026-09-02**: with
the conformance modes gone (ADR-0232) a deviation from a clause is not a
limitation of this language, and every fact the fifteen entries stated was
already in `doc/implementation-defined.md`. Six entries that were simply the
language's rule now point at the register; three capacities became a table;
the three bindability shapes and the language-server chapter's bindable-file
entry became one decision; the dangling ordinary pointer became the chapter's
lead, being the one entry that is a limitation in ADR-0109's sense. Two
entries had closed inside the chapter and are kept here in their own words.

**~~§6.4.9's type-inquiry-object is a variable-access~~ — it is not, and this
entry was wrong** (ADR-0214). The clause reads `type-inquiry-object =
variable-name | parameter-identifier`, and §6.5.1's variable-name is
`[ imported-interface-identifier '.' ] variable-identifier` — a *name*. So
`type of a[1]`, `type of p^` and `type of r.f` are outside *that clause*, and
refusing them was conformance rather than a gap in it. **Accepting them under
`--std=extended` would have been the defect**, which is the direction this
entry pointed. This language admits them — AP 6.4.9, ADR-0215 — which is a
different thing from having misread §6.4.9, and ADR-0232 removed the mode in
which the distinction was enforced.

It was written from the wish rather than the clause — the wish being to read a
container's element type off its pointer, `x: type of v^.a[1]`, which would
halve the type arguments a generic call in `lib/dialect/pascontainer.pas`
carries. ADR-0047 had quoted the production correctly since the feature landed
and this entry contradicted it for a day; nothing here could see that, which is
the point. What *did* come of it: the three refusals now say which rule they
are, instead of stopping at the declaration's own semicolon and reporting a
missing separator, and the wish itself became a dialect feature the same day
([question 4](roadmap.md#2-3-and-4--answered),
ADR-0215) — which is the useful ending: the clause is unchanged and the thing
that was wanted exists where it belongs.

- **Nothing is known and unfixed about conformance** beyond this list. Both
  standards are complete, four adversarial audits have run (ADR-0162,
  ADR-0167, ADR-0168, ADR-0171), and the last seven findings of the fourth
  were closed on 2026-08-23. A claim no test names is a claim nothing checks
  — so the next audit is worth running whenever the list above has not moved
  for a while.

### The increments at a glance

Forty-seven so far. What each one *is*, for someone who wants to use it, is in
[README's "What it adds so far"](../README.md#what-it-adds-so-far); the
sections below are why each was built in that order and what building it
found. Seventeen of the forty-seven — 1, 2, 4, 11, 12, 13, 23, 26, 27, 31, 33,
34, 38, 41, 42, 43 and 44 — are library work rather than language work, and
several of those found a compiler defect nothing else in the tree could reach,
which is a theme the sections return to. One of them, 24, built nothing at
all: it is here because it is the last word on the question ADR-0151 deferred,
and because withdrawing a question is a thing that happens to a language and
has to be recorded somewhere.

**The first thirty have a section each and the rest do not**, which is
explained [below the table](#the-increments-after-thirty) rather than left for
a reader to notice. This preamble said *thirty* for seventeen increments,
which is the thing a table of this kind fails at: it is appended to by whoever
lands an increment and read by nobody, so the sentence counting it goes stale
silently. The count is now the row count, and the sentence says so.

| # | What landed | Record |
| --- | --- | --- |
| 1 | `lib/` — `PasStrings`, `PasSort`, `PasMath`, in ordinary Extended Pascal | ADR-0114 |
| 2 | `PasVector`, `PasMap`, `PasText` — a sequence, a map, a text buffer | ADR-0116 |
| 3 | `--std=afterschool` itself, and a variant tag that cannot lie | ADR-0117 – 0119 |
| 4 | `lib/dialect/` — the result record, and one shared `ErrorCode` | ADR-0120 |
| 5 | `external` — a call to code this compiler did not emit | ADR-0121 |
| 6 | `var` and `string` actuals across that boundary | ADR-0122 |
| 7 | The optional type — `?T`, `nil` as its absent value, `o^` to read it | ADR-0123 |
| 8 | Slices — `array of T` as a formal, the bounds travelling with it | ADR-0125 |
| 9 | `int64` — the width `ssize_t` answers in | ADR-0128 |
| 10 | A slice crosses to C as the pair `(ptr, i64)` | ADR-0129 |
| 11 | `PasIO` — descriptor I/O on that buffer | ADR-0130 |
| 12 | `errno` and `strerror`, through a second runtime surface (`pasx_`) | ADR-0131 |
| 13 | `WorkingDirectory` and `LinkTarget`, with no compiler change at all | ADR-0132 |
| 14 | The handle-type — `handle external '…'`, a foreign address with an owner | ADR-0174 |
| 15 | `defer` — a statement armed where it is written | ADR-0175 |
| 16 | `T ! E` — the result record, written by the compiler | ADR-0176 |
| 17 | `exit` and `exit(e)` — one activation left early | ADR-0177 |
| 18 | `try(x)` — propagation, and error handling closed | ADR-0178 |
| 19 | `owned ^T` — a variable created by `new` given an owner | ADR-0181 |
| 20 | `take(v)` — the move an affine type needs to be usable | ADR-0182 |
| 21 | A record crosses to C as a `var` parameter | ADR-0184 |
| 22 | A foreign routine may answer a record, and what comes back is a copy | ADR-0187 |
| 23 | `PasDir` — a directory listing, without the struct | ADR-0188 |
| 24 | *Nothing*: the aliasing fork withdrawn as posed, the concurrency shape settled | ADR-0201 |
| 25 | `h := nil` — a handle released before its variable dies | ADR-0202 |
| 26 | `PasNet` — a socket is a handle, and both ends are strings | ADR-0203 |
| 27 | `PasNet.Wait` — a server serves many clients | ADR-0205 |
| 28 | `release(h)` — the closer's result, at last | ADR-0206 |
| 29 | `break` and `continue` — one loop left early | ADR-0208 |
| 30 | A discriminant may name a type — a container written once | ADR-0209 |
| 31 | `PasContainer` — a growable vector and a string-keyed map, over whatever element type a program names | ADR-0211 – ADR-0213, ADR-0216 |
| 32 | `type of` takes a whole variable-access, so a generic reads an element type off the container it was handed | ADR-0214, ADR-0215 |
| 33 | `PasJson` — a document navigated rather than mapped | ADR-0217 |
| 34 | `PasLsp` — a frame whose header is lines and whose body is bytes | ADR-0218 |
| 35 | The **empty** substring, and a name bound to the null-string | ADR-0219, ADR-0220, ADR-0224 |
| 36 | A string-valued and a real-valued constant-expression | ADR-0226, ADR-0227 |
| 37 | `binding(f).writable` — a program may ask before it writes | ADR-0240 |
| 38 | `PasFS.TemporaryPath` — a name no other live process will choose, with the file created | ADR-0242, ADR-0243 |
| 39 | An import that names no file — `--import-path` and `AFTERSCHOOL_PASCAL_PATH` | ADR-0244 |
| 40 | The **factory** — a function of this program may answer a handle, and a fallible value may be owned | ADR-0254 – ADR-0256 |
| 41 | A map keyed by whatever a program names, and no constraint was needed | ADR-0260 |
| 42 | `PasTerm` — the terminal, and the settings the runtime remembers | ADR-0262 |
| 43 | `PasTls` — TLS is a module, and the only new risk is a transcription | ADR-0264 |
| 44 | `PasHttp` and `PasHttps` — the grammar and the transport are two modules | ADR-0265 |
| 45 | A type parameter may say what it needs | ADR-0266 |
| 46 | `take` widens — **a handle moves** | ADR-0267 |
| 47 | **Two threads of control** — `task`, `spawn`, `channel [n] of T`, `send`, `receive` | ADR-0268 |

### The increments after thirty

**Seventeen increments landed after the table stopped counting**, and this
section is what stands where seventeen `###` sections would. That is a
decision and not an omission, so it is worth the paragraph.

The sections above were each written while the increment was live — what was
estimated, what the estimate got wrong, what building it found — and a section
written afterwards from its own record would say what the record says, in more
words and with a worse claim to have been there. This file's rule is that it
grows at the end and does not get rewritten; reconstructing seventeen
narratives would break it in the one way that matters, by producing prose that
reads like a contemporaneous account and is not one.

**Most of them are narrated already, in chapters organised by something other
than the increment count**, which is the real reason the table stopped being
kept: the file outgrew its own index.

- **31, 32, 41 and 45** — the generic, from a container written once to a
  type parameter that says what it needs — continue
  [the thirtieth increment](#the-thirtieth-increment-half-a-container-and-the-wall-was-not-where-it-was-expected),
  which is where the wall turned out not to be.
- **33, 34, 37 and 39** are the language server's prerequisites and its
  compiler-side surface, in
  [The language server](#the-language-server-and-the-bound-it-found-before-it-ran)
  — including the five **bounds** that chapter is worth reading for, every one
  of them chosen by counting what the largest thing in the tree needed at the
  time, and the largest thing in the tree was a test case.
- **40**, the factory, is in
  [What each landed feature left open](#what-each-landed-feature-left-open):
  it was the one item on that page with a named cost, and the estimate was
  wrong in *both* directions at once.
- **46 and 47**, the widened move and the two threads of control, are in
  [The concurrency row and the four cheaper answers](#the-concurrency-row-and-the-four-cheaper-answers)
  — the row that named its own trigger four times and was answered by
  something cheaper each time, and was then built anyway on an instruction,
  with the record saying in as many words that ADR-0116's bar is not met.

**Four have their record and nothing else**, and each is a small, complete
thing rather than a story: **35** and **36**, the empty substring and the two
constant-expression folds, which are language rules with the clause in the
record; **38**, a temporary name no other live process will choose **with the
file created**, so it stays taken after this process has gone; **42**,
`PasTerm`, which is the prerequisite `doc/roadmap.md` named for a text-mode
IDE and then built before anything asked for it; and **43** and **44**, TLS
and HTTP over it, whose interesting half is a gate rather than a feature —
six numbers transcribed out of OpenSSL's headers that a wrong transcription
would have made *quietly* wrong, `SSL_VERIFY_PEER` written as 0 being
`SSL_VERIFY_NONE` with every behavioural case still green.


### The first increment (done)

`lib/` exists (ADR-0114): three modules — `PasStrings`, `PasSort`, `PasMath` —
in ordinary Extended Pascal, translated as §6.13 program-components and imported
by path. **No compiler change and no third `--std`**, which is the point: a
library module is a §6.11 module, so nothing about what either conformance mode
accepts moved.

It **qualifies the ordering the roadmap sets out.** "FFI comes first" is true
of the outward-facing half — sockets, clocks, locales — and was never true of the
inward-facing one, and building that first bought three facts about this
language that no amount of design would have produced:

- **A string argument had to be a variable**, which was the biggest obstacle to
  a usable library and was *conformance* work rather than dialect work. It is
  **fixed** (ADR-0115), in the change after the one that found it: the library
  is what turned a limitation recorded from the compiler's side into one a
  caller could feel.

- **A `forward`-declared function lost its result-variable-specification**, and
  §6.11.1 makes every exported function a `forward` — so an exported function
  accumulated into a local. It was a defect, and is **fixed** (`ab8d125`):
  §6.7.2 puts the result identifier in the block of "the function-block, if
  any", the same words the next paragraph uses of the formal-parameter-list,
  which had always reached a forward body. Recorded as a reading nobody had
  taken and settled by taking it.

- **No generics is survivable by phrasing algorithms over positions.**
  `SortIndexed` takes `less(i, j)` and `swap(i, j)` and never sees an element,
  so one body sorts an array, several parallel arrays, or anything else the
  caller's closures reach.

What it did **not** do: no install location, no resolution by name, no
containers, and nothing touching the operating system.

### The second increment (done)

`PasVector`, `PasMap` and `PasText` (ADR-0116) — a growable sequence, a
string-keyed dictionary, and the splitting, joining and parsing that turns one
string into several and back. Still no compiler change *in the increment*,
though it exposed one: a schema whose component contains a variable-string
stopped the compiler outright, and no program in the corpus had ever written
one, so every oracle agreed it worked. That is the third defect a library has
found and the first that was a crash.

It bought three more facts, and one of them **corrects [the roadmap's borrowings table](roadmap.md#where-the-ideas-come-from)**:

- **A container cannot use the positions trick.** `SortIndexed` never sees an
  element, so it needs no element type; a container *holds* them, so their type
  is part of its layout. `PasVector` holds integers and the documented answer
  for another element type is to copy the file. This is where "no generics"
  actually bites, and it bites libraries harder than programs.

- **Explicit allocator passing does not survive contact** — that table's row,
  rewritten. It was the cheapest thing on the list and is now behind the FFI
  with everything else.

- **A library may not halt**, which is a sharper constraint than it sounds.
  §6.9.1's read of an integer is an *error* when the text is not a number and
  stops the program (ADR-0076), so nothing built on `readstr` can offer "parse
  this if it is a number" — `TryParseInt` inspects the characters itself. The
  same rule decides that `VecNew` clamps a bad capacity and that `MapGet` takes
  a default rather than reporting. **This is the strongest argument yet for
  sum types with payloads**: every routine that can fail currently invents its
  own ad-hoc shape, and there are already two.

What it still did **not** do: no install location, no resolution by name, no
error-handling convention, no second element type, and nothing touching the
operating system.

### The third increment: the dialect opened, and closed a hole it opened

`--std=afterschool` (ADR-0117) and its first feature, a variant tag that cannot
lie (ADR-0118). Both were built against the argument above — a library may not
halt, so every routine that can fail invents its own shape — and neither
changed what the conformance modes accept.

It bought one more fact, and it was found by probing rather than by reasoning:

- **A safety rule emitted at the access belongs to a compilation unit, not to a
  type.** ADR-0118's two rules are a pair, and §6.13's separate translation let
  them be split across program-components built under different modes. The
  surviving half then ran its check against a tag the other half never stored
  and *passed* the access — a check answering `safe` for an unsafe read, which
  is worse than the documented gap it replaced. ADR-0119 refuses the mixture at
  the link.

  It also **decides the next question rather than leaving it open**: a library
  cannot be a dialect layer under conformance-mode callers. If a dialect
  library is wanted it is dialect all the way down — separate modules, dialect
  callers — and `lib/` as it stands is Extended Pascal and stays usable by any
  conforming program. That is not the decision ADR-0118 parked; it is the
  removal of the option that would have been unsafe.

### The fourth increment: the library grew a second layer

`lib/dialect/` (ADR-0120) — the result shape, and the answer to the finding the
first three increments kept producing. A fallible routine answers one record
carrying the value or the reason, the tag is set by writing the payload, and a
caller who does not check traps instead of reading a stale value.

It settles the question ADR-0118 parked, and it settles it *against* rewriting
`lib/`: those modules are the only Pascal here a reader can take away to another
ISO/IEC 10206:1991 processor, which is worth more than the safety, and making
the dialect's first user its only user would have been the wrong shape for
something that has to earn its keep against a specification.

Two facts came out of building it, and both are about the wall rather than the
feature:

- **A result shape cannot be a library type.** With no generics the payload type
  is part of the layout, so each producing module declares its own record and
  what is shared is `ErrorCode` and the spelling of the tag. ADR-0116 hit the
  same wall from the container side; twice from different directions is worth
  recording before anyone proposes generics as a convenience.

- **Two layers duplicate, and there is no way around it.** `ParseInt` trims its
  own input because ADR-0119 will not link `PasText` into a dialect program.
  That is the containment being enforced rather than promised, and the cost is
  paid in copies.

It also turned up a defect nothing in the corpus could reach: a module imported
and *not used* was activated and never declared, so the program did not build.
Present since ADR-0053. Every `--import` in the tree had used what it named,
which is the shape of gap this project keeps finding — a claim no program writes
is a claim nothing checks.

### The fifth increment: the enabler, in its narrowest form

`external` (ADR-0121), under `--std=afterschool` only. Everything above needs
to call code this compiler did not emit, and until this the only route was a
hand-written `pas_*` primitive in `runtime/pasrt.c` — right for the twenty-odd
things the standards require, and no way to reach a socket.

The blocker recorded one increment ago is what made it possible: a syscall
wrapper is a routine that can fail, and ADR-0120 gave the language a shape to
say so in. The blocker recorded in
[the roadmap](roadmap.md#what-each-landed-feature-left-open) is not solved — an FFI is
a hole in every safety property, and the memory-safety model is still open — so
the
boundary is made **lexically visible** instead, which is the answer the
roadmap's borrowings table already said was most likely to fit. A directive
prejudges nothing.

Three facts came out of it, and two are about how little is checked:

- **The type mapping is an ABI question and was probed, not reasoned.**
  `integer` and `real` cross, and they are exactly the two `clang` passes with
  no parameter attribute — a `char` is `i8 signext` and disagrees with
  §6.4.2.2's 0..255 about the sign bit, a `bool` is `i1 zeroext` as a `_Bool`.
  Two rows of a four-row table, and the other two are the next increment.

- **The `declare` is not the ABI; the call site is.** Giving the foreign
  declaration a static link it does not have assembles, links and runs
  correctly — LLVM does not check a *direct* call against the declaration under
  opaque pointers. So nothing anywhere checks a foreign signature, which is
  what an FFI is without a header parser.

- **A foreign name can collide with one the compiler emits**, and LLVM answers
  with an error about a file nobody wrote. Refused as a diagnostic now, and
  `hypot` and `atan2` were unavailable to a program because `complex` used
  them — the one place the rule bit something a user would want. ~~Unavailable~~
  **no longer**: the runtime has since taken `pas_`-prefixed names for those
  uses and the bare spellings are free. Only `main` and `_setjmp` are reserved
  today, which ADR-0135's probe of the record established.

What it does **not** do is the whole of what comes next: no pointers, no
strings, no `var` parameters, no callbacks, no way to name a library. Every one
of sockets, locales and clocks needs the first two.

### The sixth increment: the pointer, on the side that has no lifetime

ADR-0122, and it is the increment this file said might have to be designed
together with the memory-safety model. It was not, and the reason is a
distinction the next sentence already contained: *a pointer* outlives the
call, and **an argument does not**.

A `var` actual and a string actual are storage the caller owns and outlives, so
the lifetime is settled before any model is chosen. A returned `char *` is the
callee's or nobody's, and is blocked twice — once on ownership, and nearer than
that on **null**, which `getenv` answers in the ordinary course of things and
which needs the *optional type* row of the roadmap's borrowings table rather
than the memory-safety row. So an address crosses only as an argument.

`string` in an `external` heading means `const char *` and is not a schematic
formal; the copy goes in ADR-0111's arena, which already had exactly the
lifetime wanted for reasons that had nothing to do with C. That is why the
increment is small. A NUL inside the value traps, which is the one safety
property it adds rather than makes visible.

Two things it deliberately did not take:

- **A buffer** — `var b: packed array of char`, what `read` and `snprintf`
  want. Not a lifetime objection: it is a pointer *and* a length, and the
  length is not in-band the way a C string's is. That is the **slices** row of
  the roadmap's borrowings table, and it is a language decision. Admitting it here would
  invent a fifth spelling of the two-scalar shape at the one place nothing can
  check it.

- **A callback.** The static link is the half of a procedural value with no
  image at all in C, and a Pascal procedure without one is a different feature.

And one thing it could not: **`errno`**. glibc spells it
`*__errno_location()`, so it is a pointer result, so `lib/dialect/pasfs.pas`
answers `errIO` for every failure and cannot say which. The first thing the
next increment buys is the ability to say which.

### The seventh increment: the type null needed

ADR-0123, and it is the first of ADR-0109's four open decisions to be settled —
the **optional** row of the roadmap's borrowings table, not the memory-safety
row. `?T` is a
value of T or nothing; `nil` is the absent value, `= nil` the test, and `o^` the
only way to a value, checked exactly as §6.4.4's dereference already is.

It is here because the increment before it stopped at a wall that was not about
memory at all. A returned `char *` may be null, and null is not a failure —
`getenv` of a name that is not set answers it on purpose — so trapping would
stop a program on a normal answer and the empty string would conflate "not set"
with "set to nothing". The language simply had no way to say "there may be
nothing here", and every fallible thing built so far had invented its own:
ADR-0120's record carries a *reason* as well, `MapGet` takes a `whenAbsent`
argument, `TryParseInt` writes through a `var`. Absence with no reason is the
commonest case and had the least support.

Four things are worth carrying forward:

- **The lexis cost nothing, again, and by a different route.** `?` is a
  character neither standard admits anywhere, so nothing that compiled stops
  compiling and the reference front end needed **no** teaching at all — it
  already said `unexpected character '?'`, where ADR-0121's `external` needed
  six lines in `src/`. A syntax made of a character no standard uses is cheaper
  than one made of an identifier.

- **The guarantee is the refusal, not the check.** Nothing is assignable *from*
  an optional — two lines in `Assignable` — so a `T` that is not optional can
  never be absent, and eight of the twelve refusals in the test file come from
  diagnostics that already existed. Refusal by construction paid here more than
  anywhere since ADR-0058.

- **No C pointer becomes a Pascal value.** The copy is made at the call site, so
  the program holds a string of its own and the pointer is dead by the end of
  the statement. The capacity is required and is §6.4.6's check, in §6.4.6's
  words.

- **The blind spot decided an interface.** `lib/dialect/pasenv.pas` refuses to
  bind `putenv`, which keeps the pointer it is handed — the hazard
  `doc/sop.md` §7 records against ADR-0122 — and binds `setenv`, which copies.
  That is the first time a registered gap has changed what gets built rather
  than only being written down beside it.

And writing it found a defect ADR-0122 had shipped: two `string` parameters in
one group of an `external` heading were held to §6.7.3.3's one-tuple rule,
which is not about them. `strcmp('b', 'ab')` had been refused since that
increment, and nothing asked because every call in the corpus passed actuals of
equal length.

### The eighth increment: the bounds travel with the pointer

ADR-0125, and it is the **slices** row of the roadmap's borrowings table — "a
pointer and a length; excellent, and already the house style" — which this file predicted
correctly and for the right reason.

It was deferred to by name: ADR-0122 refused a buffer at the foreign boundary
because "it is a pointer *and* a length, and the length is not in-band … that
is the slices row, and it is a language decision, not an FFI one." So it was
built as a language decision, and it has a reason that does not mention C at
all: Extended Pascal gives a string a substring and gives an array nothing.

Three things it confirms about how this dialect grows:

- **The lexis has now cost nothing three times, by three different routes.** A
  directive (ADR-0121), a character no standard admits (ADR-0123), and a
  *combination* of two reserved words that no standard's grammar allows —
  §6.4.3.2 requires a bracketed index-type, so `array of T` is a syntax error
  in both. Looking for the spelling a standard has already left free is the
  cheapest design move available here.

- **"Ask the symbol, not the syntax" paid for most of the increment.**
  `a[i..j]` is §6.5.6's substring designator and was already parsed; only the
  base's *type* decides which construct it is. The parser was not touched for
  it.

- **Confining a feature to an argument worked a third time.** ADR-0122 found
  that an argument has no lifetime question; a slice that cannot be stored in a
  variable, a field or a result cannot outlive the array it views. Three
  increments have now taken that shape, and it is worth stating as a pattern:
  where a feature's danger is *lifetime*, confining it to an argument removes
  the danger without deciding anything about ownership.

And a probe reshaped what comes next. `clang` on this target:

    declare i64 @read(i32, ptr, i64)
    declare i64 @write(i32, ptr, i64)
    declare i64 @recv(i32, ptr, i64, i32)

Every length is `size_t` and every one of them *answers* `ssize_t`. A slice
could cross with an `i64` length without difficulty, the compiler generating
that word — but the result cannot be received, this language's `integer` being
`i32` with nothing wider. **So the data path needs two things and this is one
of them**; shipping the buffer argument alone would have put a knowingly wrong
ABI in the tree for a call that cannot say how many bytes it moved.

### The ninth increment: the half the probe named

ADR-0128, and it is the increment ADR-0125's closing probe wrote the
specification for. `clang` on this target declares `read`, `write` and `recv`
as taking an `i64` length and *answering* `ssize_t`; a slice could cross with
that length, and the result could not be received. `int64` is the half that
answers.

It is the first dialect feature whose constraint is the **compiler** rather
than a standard, and the constraint decided the design twice over.
`selfhost/compiler.pas` is written in this language, so its own integers are 32
bits: there is no value of the wide type anywhere in the compiler to fold with,
compare, or put in a constant.

- **So a value is carried as text**, all the way into the IR. That is ADR-0025's
  answer for a real literal, arrived at again one clause later and for the same
  sentence: LLVM's assembler is what reads the digits, and nothing this compiler
  converts can be converted wrongly. `Int64TooLarge` compares *text* against the
  limit, because neither side of that comparison is a number it could hold.

- **And it is numeric rather than ordinal**, which is one line — `IsOrdinal`
  answers no — and thirteen refusals that needed no message of their own. Every
  construct that refuses it is one that needs the compiler to *hold* the value,
  so the line is forced as well as preferred.

- **`verify/` proved the wide lowering by running the rules it already had.**
  The model was written generic in the width, so `WIDE = (32, 64)` establishes
  the emitted code at its real width rather than a second family of rules
  restating the first. Worth recording as a property of how that catalogue was
  built: a model written symbolically pays a second time, years later, for a
  type nobody had in mind.

**The lexis cost something, for the first time in four increments.** A
directive, a character no standard admits, a combination of two reserved words
— three routes to a free spelling, and there is no fourth for a *type*.
`int64` is an identifier, available only because §6.2.2.10 makes a required
identifier shadowable rather than reserved. That is a weaker kind of free, and
it is why the containment test grew a paragraph rather than being left alone.

### The tenth increment: the shape decision, and it had no mechanism left

ADR-0129, and it is the first increment here whose whole content was a choice
between two things that both worked. The entry that stood in this place named
them: a slice crossing as its address alone, with the program passing the
count, or as the pair `(ptr, i64)`. It went to the pair, and the reason is not
the one this file gave.

This file said the pair was "more useful and assumes a convention" and that the
address alone "assumes nothing and puts the count in the program's hands". That
second half was the wrong way round. **Putting the count in the program's hands
is the C hazard**, and it is the one ADR-0122 refused to reintroduce at the one
place nothing can check anything: a length travelling separately from its
pointer is a length nothing relates to the storage. `PosixRead` has two
parameters where `read(2)` has three, and the count C receives is one the
compiler computed from the designator and checked against the array. A buffer
overrun is not something a caller can spell.

Three things came out of building it:

- **A rule with a side gets read twice.** ADR-0121 admitted a type by testing
  it rather than `Base(t)`, and argued it as *passing a subrange is sound,
  returning one is not*. A slice is storage the callee **writes**, so every
  component sits on the returning side of that argument — which decided the
  component list without a new principle. `char` then came in for the mirror
  reason: it is refused *by value* over `i8 signext`, an objection about the
  register convention, and in memory the type has no bit pattern that is not a
  value of it. That property — and not "a byte is a byte" — is what makes a
  component safe for a routine this compiler did not emit to write into.

- **Two mutations survived, and both are ADR-0121's registered gap seen
  again.** Writing `ptr` where `ptr, i64` belongs, so the declaration and the
  call disagree about *arity*, assembles and runs; so does dropping the `sext`
  and passing the count as an `i32`. The first is the gap recorded for
  parameter types, now confirmed for arity — the `declare` is documentary. The
  second is right for a reason no program here can exhibit, both target
  architectures zeroing the upper half of a 32-bit register write. Both are in
  `doc/sop.md` §7 rather than claimed as covered.

- **The prediction this file made about slices held a second time.** The
  "already the house style" row was written about a language feature; the same
  two words are now what an operating system takes, with no adapter between
  them. That is the sixth thing here travelling as two scalars and the first
  where the far side chose the shape.

### The eleventh increment: the library, and the streak that ended

ADR-0130 and `lib/dialect/pasio.pas` — descriptor I/O on ADR-0129's buffer,
answered the way every fallible thing in the second layer answers. It closes
the entry that stood here.

**Its result is that there was no result**, and that is what the record is for.
Four library increments in a row found a compiler defect nothing else could
see — ADR-0114 a string argument that had to be a variable, ADR-0116 a schema
holding a variable-string that stopped the compiler outright and a `forward`
function that lost its result variable, ADR-0120 a module imported and not
used that never linked. This one found nothing, and not for want of asking: a
slice reached `write` from a global, a record field, a schema-bounded array, an
enclosing procedure's local through the static chain, a `with` binding, a `var`
parameter sliced by two expressions, a slice of a slice, an empty slice and an
`array of int64`. Every one behaved.

The narrow reading is the right one. ADR-0129's feature is built out of
ADR-0125's, which arrived with a corpus, and confining it to an argument kept
it away from everything that has a lifetime. It says nothing about the rest of
the FFI: the two mutations ADR-0129 recorded as surviving still survive.

What the library *did* find is about the library, and both were caught by
mutation rather than by running it:

- **`AtEnd`'s first conjunct is load-bearing and was untested.** `r.ok and
  (r.count = 0)` is safe because `and` short-circuits, so `r.count` is never
  read on a result whose tag says there is none. Dropping `r.ok` passed the
  whole suite until a case asked `AtEnd` of a *failed* result — then it traps
  with *variant: the tag selects another arm*. ADR-0118's rule and §6.7.2's
  short-circuit holding each other up, and invisible along the successful path.

- **`WriteAll`'s retry branch cannot be reached from a test here.** A short
  write needs a descriptor that takes fewer bytes than it was handed; a regular
  file never does and a pipe blocks rather than truncating. Its failing exit is
  covered, the retry is not, and that is written down rather than left.

### The twelfth increment: the wall was a misdiagnosis

ADR-0131, and it closes the entry that stood here — the one three records in a
row had closed by naming. **The reason every one of them gave was wrong.**

They said `errno` is unreachable because glibc spells it
`*__errno_location()`, a function returning `int *`, and a returned pointer is
what ADR-0122 does not admit. True, and a detail of one C library. The reason
that matters is in the language: **C specifies `errno` as a macro.** It has no
linker symbol, so no foreign-function interface can bind it — not this one,
not a better one, not one with a header parser, which would read the macro and
still have nothing to call. So it was never blocked on ADR-0109's
memory-safety model at all, and the thing it was waiting for is the oldest
mechanism here: `runtime/pasrt.c`, which is where anything not expressible in
the emitted IR has always gone.

Three things worth carrying forward:

- **The runtime now has two surfaces, and the prefix is the decision.**
  `ReservedForeignName` refuses the whole `pas_` prefix and is right to — those
  are names the emitted module declares, and LLVM will not take a second
  declaration. A routine the emitter *never* names is not that hazard, so it
  gets `pasx_` and a program binds it. That keeps the predicate a mirror of the
  emitter rather than a list of exceptions, which is the property
  `foreign-reserved` fails in both directions to hold.

- **`strerror` needed nothing.** It answers a `char *` and ADR-0123's optional
  string already receives one, with the copy made at the call site. The half of
  this increment that looked hardest was already paid for.

- **A wall recorded three times is worth re-deriving once.** Each record
  restated its predecessor's reason rather than the clause behind it, and the
  restatement was cheaper to believe than to check. The same shape as
  ADR-0067's `pack` and `page`: three documents asserting something no probe
  had been written for.

### The thirteenth increment: half of "every returned pointer" was never blocked

ADR-0132, and like the increment before it the finding is that a recorded
blocker was one sentence covering two unlike things.

"Every returned pointer that is not a string" ran together **a pointer to
storage the callee owns** — `getenv`'s, `strerror`'s, where whose it is and
how long it lives are real questions ADR-0123 answered by copying at the call
site — and **a pointer to storage the caller just lent it**. `getcwd` answers
the buffer it was handed, or null. There is no ownership question in that at
all: the storage is the caller's, it outlives the call by construction, and
the pointer is a success flag with an address attached.

So `WorkingDirectory` and `LinkTarget` needed **no compiler change and no new
mechanism**. Three things already in the tree met: ADR-0129's slice lends the
buffer and supplies two C arguments from one formal, ADR-0123's optional
receives `getcwd`'s result, ADR-0128's `int64` receives `readlink`'s
`ssize_t`.

That is the same distinction ADR-0122 drew for the argument side — "a pointer
outlives the call, and an argument does not" — applied to a result that is an
argument coming home. **Three increments in a row have now found that a
decision described as needing the memory-safety model needed it for only part
of its surface**, which this file already wrote down once as a lesson and has
now had to learn a third time.

One thing it adds to the register rather than to the language:

- **Binding a C interface produces guards for cases the platform cannot
  currently produce.** `LinkTarget` reports `errFull` when `readlink` fills the
  buffer exactly, because there is no terminator and truncation cannot be told
  from a target that just fits — and that arm is unreachable, `MaxPath` being
  Linux's `PATH_MAX` and the kernel refusing to create a longer target. Third
  in three increments, after `WriteAll`'s retry and `ErrorNumberText`'s null.
  They are correct to write and impossible to test from here; the honest
  treatment is to say which branch and why, not to delete the guard so the
  coverage reads better.

### The fourteenth increment: the property had a spelling already

ADR-0174, and the finding is the one this file has now recorded four times in
a row: a decision described as needing the memory-safety model needed it for
none of its surface.

AP §6.7.7.9 c) forbade an external result that is "an address of storage the
callee owns whose contents are not characters", and the roadmap carried that
prohibition as the single item standing between the library and a directory
listing, a pipe, a socket. ADR-0151 found two things about it. It was **never
enforced** — `int64` carries a `DIR *` today, it copies, arithmetic on it is
legal, and closing it twice aborts the process. And the property such an
address needs is a **lifetime**, which this language answered in 1983: a file
variable is released when the variable holding it dies, cannot be copied out
of it, and is released across every exit the language has — block epilogue,
non-local `goto`, `halt`, `dispose`.

So the question was never *what is ownership*. It was how to spell a type with
a file variable's semantics for an address a foreign routine answered, and
what a second kind of owned variable costs machinery built for the first. The
answer to the second was: nothing. `IsOwned` is a file **or** a handle,
`ContainsFile` walks it, and every refusal a file has — assignment, the
relational operators, a value parameter, a function result, anything
containing one — reached a handle with no new arm at any of the 21 positions
`predicate-callers` sweeps.

Three things a handle has that a file does not are written out as exceptions
beside the rules they except, which is the shape this project prefers to a
list of what is forbidden: one assignment form and no other, `= nil` as the
emptiness test, and a value parameter of an *external* — lent, where an empty
one is an error at the lend, because a C routine given NULL for a stream does
not report. What it unlocked was `popen`, `fopen` with a mode and `opendir`,
each a library module away and none of them more language.

### The fifteenth increment: a loop decided the unit

ADR-0175. `defer` had sat in the borrowings table as **open and cheap** since
ADR-0109 — "a block already has one exit and the epilogue already closes
files" — and the design question turned out to be neither of the two the table
implied. It was: *what is a deferred statement armed in?*

Go says the function. Zig says the block. The case that decides it is a loop:

    for ... do begin new(p); defer dispose(p) end

A defer belonging to the **activation** runs `dispose(p)` once, with the last
`p`, and leaks the rest. So the unit is the statement-sequence — and
§6.9.3 has exactly three constructs holding one, a compound-statement, a
repeat-statement's body and a case-statement-completer, which is why a `defer`
written directly in an `if` branch or a `while` body belongs to the sequence
outside it.

That choice is what makes the storage a **flag apiece** rather than a stack. A
defer-statement can be pending at most once, its sequence not being
re-enterable without being left, so "armed" needs one bit and arming what is
armed has no further effect. That last sentence is not tidiness: `1: defer S;
goto 1` is the one way a defer-statement is reached twice without its sequence
completing, and a stack would grow without bound there.

The three exits a block has were already three walks — the epilogue, the
runtime's non-local `goto`, and `halt` — so the armed statements became a
third list beside the files' and the handles', walked *first* in all three
because a deferred statement may still write to a file the block owns. And one
restriction is stated in the specification rather than left to be found: a
deferred statement may contain no label and no `goto`, because it is emitted
**twice** — where its sequence completes and inside the runner — so a label in
one would be two labels with one number.

It also added a row to the blind-spot register that nothing can close by
testing: **nothing derives the list of statement-sequence holders**. A fourth
such construct added to the language would arm correctly, refuse a label
correctly, and run its deferred statements late, through the runner, which is
the backstop working rather than the feature.

### The sixteenth increment: the estimate was wrong in the cheap direction

ADR-0176, and for the third time in this file an estimate that assumed a
feature needed its own machinery was worth probing before it was believed.

The borrowings table called error unions "the larger of the two — a type
constructor over a type". `T ! E` turned out to need **no new type at all**:
it denotes an ordinary record with a flag on it, so the copy, the layout, the
value parameter, the function result and ADR-0118's trap on reading an
inactive variant all came free, and **CodeGen was not touched**. The whole
feature is a type-denoter, one arm in `Assignable`, and a Sema rewrite of
`r := x` into the field assignment that already had a lowering.

Four things only the implementation found, each now a case.

- **Assigning to a function's own identifier is a separate path.** Sema
  accepted `f := 1` in a function answering a fallible-type, nothing rewrote
  it, and CodeGen stored an integer into a record. A segfault, with the whole
  suite green.
- **The rewrite must not re-check its base.** Reading a function identifier is
  §6.8.2.2's recursive call, so `f.val` looped until the stack ran out. The
  field is resolved directly instead.
- **`LooksLikeSubrange` had to learn `!`**, or `integer ! 1..5` scanned as one
  subrange and the diagnostic complained about a `..` that was never missing.
- **The tag needed `Threatened`, not the assignment.** Refusing `r.ok := true`
  alone would have left `read(r.ok)` setting the tag with no arm written.

And a **gate changed the design**. `predicate-callers` refused a
declaration-time check that the two sides do not both admit a value, because
it made the resolver a caller of `Assignable` with no sweepable position.
Moving the question to the assignment — where a value actually is — was both
the answer the gate would accept and the better rule: `integer ! 1..5` became
a usable errno-shaped type, and only the ambiguous shorthand is refused.

The library migration is what paid for it. Six result records became six
one-line types, and the failing side is `cause` everywhere; it had had three
spellings, and one module's `code` was a *success* payload where four others'
was the error.

**What it cost is worth recording beside what it bought.** `DumpTypeExpr` had
no arm for the new node kind, so `--dump-ast` and `--dump-sema` stopped the
compiler on any program declaring a fallible-type — for three days, with 714
cases green. `kind-exhaustive` fired at the time and the *number was moved
rather than the case fixed*, which is the one thing that entry format warns
about. No oracle could see the result: the dumps' own corpus had no such
program, `difftest` skips a dialect source by directory, and the coverage
sweep drives `--dump-all` over everything without reading what it exits with.
It surfaced only because a later feature added a branch in the same walker and
`line-coverage` asked why it went unreached.

### The seventeenth increment: the first borrowing from another Pascal

ADR-0177. `try X` needs a way out of a block that is not the end of it, and a
Pascal block has exactly one exit — §6.9.2.4's `goto` needs a label at the
block's end and §6.7.5.7's `halt` ends the program. So propagation waited on a
statement, and `exit` is it.

It is the first dialect feature whose authority is **not a standard**. Turbo
Pascal, Delphi and Free Pascal all have `Exit`, two of them with a value, and
open question §1 had just been rewritten to say that where one of the other
Pascals has already answered a question this dialect is asking, that answer is
a reference point — not because it is authoritative, but because a Pascal
programmer arriving here already knows it.

It is also the feature where **ADR-0140's rule does not apply**. That rule
asks whether a conforming program could have written the construct *in that
position*, and a procedure-statement is a position ISO/IEC 10206:1991 admits.
What makes the name the dialect's is only that it is nobody's under a
conformance mode — `int64`'s answer and `argcount`'s, a required identifier
made shadowable by §6.1.3. Three features now have that shape, so it is the
second kind of spelling rather than an exception to the first.

The lowering cost nothing again, and for a reason this file has recorded
before: the emitter writes text. An `exit` branches to a label the emitter has
not written yet, which textual IR admits and an instruction list would not —
the sequential emitter cannot return to a block it has left. The branch lands
on the epilogue every block already had, so the armed statements, the files
and handles, and the load of the result slot were all discharged by code that
was already there.

What was not free was a gate. `exit(e)` can stand only in a function-block,
and `predicate-callers`'s probe program declared its subject as a *procedure*
— so the position would have been refused for the wrong reason, and the gate
would have passed while checking nothing. Making the subject a function, with
its result assigned before the snippet, was six lines. A gate that passes for
the wrong reason is worth more attention than the feature that revealed it.

### The eighteenth increment: the rule that did not transfer

ADR-0178, and it closes error handling. `T ! E` says what a failure is
(ADR-0176), `exit` is how a block is left (ADR-0177), and `try(x)` is the
construct that connects them: the value where the operand succeeded, and
otherwise the cause assigned to the enclosing function's result and that
activation terminated.

Both of the questions the roadmap had left open got answers, and neither was
the answer the question expected.

**What must the enclosing result type be?** Nothing in particular. The
construct makes an assignment to the result and hands it to
`CheckResultAssign` — ADR-0177's routine, where `f := e` and `exit(e)` already
agree — so the requirement is assignment-compatibility and no more. A function
answering the *error* type takes the cause directly; one answering a fallible
type gets AP 6.4.13's arm shorthand; one answering neither is refused by the
message any unassignable result is refused by. The question dissolved rather
than being answered, which is the third time in this dialect that a feature
turned out to need no machinery of its own.

**Is there a spelling a conforming program could not have written?** No — and
that is the finding worth keeping. ADR-0176 had sketched `try X` by the rule
ADR-0175 uses for `defer`: an identifier followed by a token that could not
follow it. That rule is about a *statement*, where six tokens may follow a
statement-initial identifier. A **factor** is not so constrained. A factor may
be a variable-access, so a conforming program that declares `try` may write

    try (x)     try [x]     try + x     try - x     try.f     try^

and mean something by each. Only an operand beginning with an identifier, a
number, a character-string, `nil` or `not` would have been unambiguous, which
is a rule about six of the operands rather than about the construct. So `try`
took ADR-0177's shape — a required identifier, nobody's under a conformance
mode, shadowable by §6.1.3 — and the parentheses became part of the spelling.
Four features have that shape now; it is the commoner of the two.

The implementation found one thing a reading would not have. All three parts
of the construct read the operand, and a function-designator written three
times is three calls — so the operand is bound once to a frame slot holding
its address, which is a `with` statement's binding taken unchanged. Nothing
else in CodeGen is new: the branch is `and then`'s, the transfer is `exit`'s,
and a value-type that is a string or a record is a *field of a record*, so
every path that carries one already carried it. The mutation that removed the
binding left every behaviour case green and failed one spec scenario — the
one that counts the calls, written for exactly that.

It also found a defect in the increment before it. ADR-0177's NOTE said
6.9.3.11.3 forbids an exit-statement in a deferred statement; 6.9.3.11.3
listed three items and said nothing of the kind, so a processor reading only
the numbered requirements would have been right to allow one. The clause now
carries all five.

### The nineteenth increment: the sentence that quantified over the wrong thing

ADR-0181, and it is the first increment since ADR-0151 to touch the
memory-safety model itself rather than to route around it.

ADR-0151's finding was that a model was already here and nobody had named it:
*an owned value is released when the variable holding it dies, and cannot be
copied out of that variable*. That sentence was written as the answer to the
lifetime half, and the roadmap has said the lifetime half was finished ever
since.

**It quantifies over a variable, and a variable created by `new` is held by
nothing.** AP 6.4.12.3 releases a handle at the first of "termination of the
activation in which the variable exists", `dispose` of a variable containing
it, and reassignment. A heap variable exists in no activation. So a record on
the heap holding a stream is set up correctly — `new` emits `pas_handle_init`
for every handle in the domain — and torn down correctly — `dispose` emits
`pas_handle_done` for every one — and nothing whatever makes `dispose` happen.
Both halves built, both halves right, and no third thing joining them.

It was in no register: not `doc/sop.md` §7, not the specification's Annex C,
not the roadmap's own entry on the subject, which said the half was done. What
found it was a probe written to ask a different question, and what measured it
was `ulimit -n 64` and a counting loop: `fopen answered empty at iteration 62`.

The fix is visible in the defect. The 1982 model works because every file
variable is *declared*, so it has exactly one scope that ends; a heap variable
has no scope, therefore no owner, therefore no release. `owned ^T` gives it
one.

Three things about the increment are worth keeping.

**It was available because it decides nothing.** ADR-0151 left aliasing open
with a criterion — it becomes decidable at the first construct admitting two
live names for one owned value — and an owned pointer admits none, since it
cannot be copied at all. That is ADR-0174's move a second time, and it is now
the pattern: the lifetime half can be extended indefinitely without touching
the fork, and each extension is available precisely because it refuses to
alias. What it costs is visible in the feature — there is no iterative
traversal, because a loop would need a second pointer.

**One name was two questions.** `IsOwned` was asked by `ContainsFile`, which
decides the copy refusals, and by `IsMemory`, which decides that a value
travels by address. Those had been the same question while the only owned
things were a file and a handle. An owned pointer is affine and its value is
still one word, so the name had to split: `IsAffine` for the ownership,
`IsOwned` for the representation. Everything else came free — the assignment,
the comparison, the value parameter, the result and the fallible side are all
refused through the predicate, without a call site being edited.

**The gate that caught the emitter caught it again.** `@ownrelN` is a global
name the emitter writes, and `foreign-reserved` failed on the first run, for
`@frame1`'s reason and by ADR-0144's mechanism — the half of that gate which
harvests what the compiler *emits* rather than what its source spells. A
release routine is the second generated function per translation, after
ADR-0175's defer runner, and the first whose number has to be handed out
before its body exists: a type may own a variable of its own type, so the
routine calls itself.

### The twentieth increment: the client that was never written

ADR-0182, and it is the first increment here whose whole justification is a
module that does not exist.

The plan after ADR-0181 was `PasList`, on the reasoning this dialect has
earned twice: write a client the same day and it finds something. It found
something before a line of it was written. An owned pointer has no copy, so a
chain of owned nodes admits push-back and pop-back by recursion, the walks by
recursion, and `dispose` — every one O(n), and **no operation in constant time
at all**. Push-front and pop-front are unwritable, because `fresh^.next := n`
and `n := fresh` are each a copy.

Beside `PasVector` — O(1) push, O(1) index, and a `VecFree` you must remember
— such a module would have been worse at everything and its only merit would
have been needing no free. The finding was not about the library. **The
missing primitive was a move**, and the four refusals that said so were one
diagnostic, right every time.

`take(v)` empties the variable and yields what it held, in the one position
6.4.12.2 already defines for the handle. Three things are worth keeping.

**The position machinery was already built.** ADR-0174 wrote it for the
handle, ADR-0179 taught it that a bare parameterless call is a call, and
ADR-0180 made it reach both spellings. `take` needed a flag of the same shape
and nothing else — the fifth construct spelled as a required identifier, which
is now decisively the commoner of the dialect's two shapes.

**The evaluation order is a language decision, not a lowering.** The source is
read and emptied before the target's address is taken, because a target
reached *through* the source would otherwise make a node its own successor: a
cycle held by no variable and reachable by no release. Emptying first turns
that program into a nil dereference. It is the same choice ADR-0018 makes
everywhere here — a defect reported beats an answer that is wrong — and it
bought something unlooked-for: `n := take(n^.next)` is pop-front entire,
because the source is the head's own field, so releasing what the target held
disposes the head alone.

**A scenario was found asserting less than its name.** The mutation that
removed the target's release left the spec suite green: the scenario written
for exactly that check leaked a node holding nothing observable, so nothing
could see it. It now puts the stream in the target's old value. This is the
failure `tests/spec/` exists to prevent, it survived being written
deliberately for the property it failed to check, and it was written by the
hand that wrote the feature — which is when it happens and why the mutation
step is not optional.

### The twenty-first increment: the gap was permission, not arithmetic

ADR-0184, and it is the fourth estimate in five FFI increments to be wrong in
the same direction.

`doc/roadmap.md` had carried a foreign **struct with a layout** — `struct
stat`, `struct dirent`, `struct sockaddr` — as what stood between here and a
directory listing, and had said what it needed: *the compiler and C to agree
about offsets, which nothing here does for a foreign type*. The measurement was
taken before anything was designed, and **nothing had to be made to agree**.
`RecordLayout` rounds each field up to its own alignment, takes the widest
field's alignment as the record's, and rounds the total — which is not a rule
chosen to resemble C's, it *is* C's rule. A Pascal record of `struct stat`'s
fields, with glibc's two holes written out as fields of their own, is 144 bytes
at 144 bytes' offsets and emits one `llvm.memcpy` of that length.

What was missing was **permission**. AP 6.7.7.6 admitted `integer`, `int64` and
`real` at a `var` parameter of an `external` heading and refused everything
else, so a caller-owned buffer had no way across as a single argument. Widening
that list is the whole feature.

**It is the first dialect feature to need neither of ADR-0140's two shapes.**
`var buf: StatBuf` at an `external` heading is something a program could always
write and was told it could not have: no word-symbol, no directive, no position
that did not already exist. ADR-0140's rule assumes every feature needs a
spelling, and this one inherits `external`'s — which is why `grep external`
still finds it. `exit` had failed the same premise one step earlier by finding
no position at all, so ADR-0184's consequences had to carry both.

**What qualifies is decided by the fields and not by a marker**, and the list is
ADR-0129's slice-component list for ADR-0129's reason: the callee writes through
the address, so a type with a byte pattern that is not a value of it cannot be
admitted. `boolean` has 254 such patterns, an enumeration has as many as it
lacks constants, and nothing runs `CheckedForStore` over what a routine this
compiler did not translate left behind. A **variant part** is refused, and it is
the one refusal here about this compiler's own representation rather than about
a value set: an arm's storage is `[k x iN]`, a shape chosen here (ADR-0028), and
a C union is not laid out from it.

The record shipped no library consumer on purpose, for a reason it stated and
did not solve — which is the twenty-third increment.

### The twenty-second increment: an address retired rather than modelled

ADR-0187. ADR-0122 had refused every foreign result that is an address, rightly:
a returned `char *` may be null, `getenv` of an unset name answers one in the
ordinary course of things, and this language had nothing to say *no value* in.
ADR-0123 built that something and lifted the refusal exactly as far as a string
with a capacity, because the copy the call site makes needs somewhere of a known
size to go. **The size was the whole of the condition, and after ADR-0184 a
record has one.**

So the question was not whether a struct can come back — two earlier increments
had answered that between them — but what it comes back **as**. A null address
yields the absent value; any other address yields a copy, made where the call
occurs, into the frame slot Sema already gives every call whose result lives in
memory.

**The copy is the feature and not the implementation.** `readdir` answers one
static object per directory stream and overwrites it on the next call. A view
onto that would be a value of this language whose contents change when the
program does something unrelated, and would hand ADR-0109's aliasing question to
every program that lists a directory. Reading the address once, at the call, and
letting it die at the end of the statement is the same sentence ADR-0123 wrote
about a `char *` — and it is the fourth increment running to be answered by
arranging for nothing to hold an address. *An ownership question is only a
question while something holds the address.*

**The length is the record's and not the struct's**, there being nothing the far
side could report. A record declaring a *prefix* of the members reads the
prefix, which is how `struct tm` is usable without naming the `char *` glibc
puts after the nine that matter; a record larger than the struct reads storage
the callee does not own, which is a requirement on the program of exactly the
class AP 6.7.7.9 c) already is.

A record result **by value** stays refused and gained a diagnostic naming the
remedy, having been reaching the general *only `integer`, `int64` and `real`
cross the boundary* — true, and unhelpful about a program whose mistake is the
direction rather than the type. How a struct comes back by value is a fact about
C's ABI, and ADR-0030 is the standing rule that nothing here may depend on one.

### The twenty-third increment: the module did not use the feature that unblocked it

ADR-0188. ADR-0187 closed the roadmap's last row, and both the record and the
roadmap named what it unblocked: `readdir`, and with it a directory listing.
`lib/dialect/pasdir.pas` is that module, and **it does not use ADR-0187**.

The reason is three commits older. ADR-0185's fifth decision is that a
**library may not make a struct claim**: a record crossing the boundary is a
claim about some C compiler's layout, checkable by `foreign-layout` on the
machine you build on, and `lib/` has to work on machines nobody here builds on.
`struct dirent` is that case at its worst — glibc puts an `unsigned short` and
an `unsigned char` in front of `d_name`, macOS puts a 64-bit seek offset and two
16-bit fields, and POSIX itself requires only `d_ino` and `d_name`, **in any
order**. There is no field list a portable module could write.

**The generalisation is why this is a record and not a paragraph in the
module.** `struct tm` is *standardised* — ISO C 7.27.1 — and a library may not
declare that one either, because the same clause lets the members appear in any
order. The set of structs a library may declare is close to empty. Nothing about
ADR-0187 was wrong; what was wrong was reading *readdir is declarable* as *the
module can declare it*.

So `PasDir` binds `opendir` and `closedir`, neither of which has a struct in its
signature, holds the `DIR *` as a handle-type with `closedir` as its closer —
ADR-0174's own worked example arriving as a library at last — and asks the
runtime for exactly one thing, the name.

Two decisions in it are worth keeping. **There is no entry kind**, because
`d_type` is not POSIX, is invisible under `_POSIX_C_SOURCE` — which is what
`runtime-isoc` compiles the POSIX half with — and is `DT_UNKNOWN` on filesystems
that do not carry the field; a caller composes `PasFS.Info(dir + '/' + name)`
instead and gets an answer that is right everywhere. And **the capacity is
checked on the far side**, which closed a `doc/sop.md` §7 row for this module:
`pasx_dir_next` holds the pointer and can call `strlen`, so the caller's own
capacity travels *in* and an over-long name comes back as `errFull` rather than
stopping the program — which is what `PasEnv.Lookup` still does with `getenv`'s
answer, and could be given the same treatment and has not been.

### The twenty-fourth increment: the fork was withdrawn rather than decided

ADR-0201, and nothing landed. It is here because it is the last word on the
question ADR-0151 deferred with a criterion rather than a mood — ARC or
borrow-checking, decidable *at the first construct that lets two live names
reach one owned value* — and because the record was started to pick a
concurrency construct and did four probes instead.

**Containment forbids both candidates on `^T`.** `new(p); q := p; dispose(p)` is
a conforming Extended Pascal program, and §6.6.5.3 makes a later use of `q^` an
error this processor does not detect. ARC changes what `dispose` does and what a
pointer costs; borrow-checking **refuses** the program. Either breaks ADR-0117,
and `^T` is the only reference type an ISO program has — so the fork as posed
cannot be applied to the pointer the question was about.

**The dialect's own answer to aliasing is refusal, given three times.** A file,
a handle and `owned ^T` are `IsAffine`, none may be copied, and a second name
for one is refused in as many words. There is nothing left for either candidate
to govern.

**And a borrow was already here, unnamed.** `Bump(o^)` binds a `var` parameter
to what an owned pointer owns, for the duration of the call. It cannot escape:
Pascal has no address-of — §6.1.9's alternative `@` is refused, in
`torture.pas` — and `new` is the only thing that produces a pointer, so no
pointer can ever name what a `var` parameter refers to. `kept := n` is a type
error and that is the whole enforcement. **Unformable rather than checked**,
which is stronger and free, and which nothing in the compiler knows: a future
feature adding a way to form such a value takes the property with it in silence,
and `doc/sop.md` §7 is where that is written down rather than watched. Even the
classic hazard is safe — `P(o, o)` over `a := take(b)` is a self-move, the
variable is not nil afterwards, and the heap balances.

That is ADR-0151 §1's pattern a second time: the property was already held, by
construction, and unremarked.

What is left of the fork is **two threads of control**, the only sentence that
breaks *a borrow cannot outlive a call because the caller is not running during
it*. So the construct must be share-nothing, a task owning what it is given, and
the lineage to read is Pascal's own rather than Rust's: Concurrent Pascal had
`process` and `monitor` in 1975. The record then declined to build it and named
the trigger — *a socket module serving more than one client*, with `select` as
the cheaper answer to try first. **The trigger came and went in two days**,
three increments below, and the cheaper answer was enough.

### The twenty-fifth increment: the release the type had no way to ask for

ADR-0202. ADR-0174 gave the handle one form of assignment, the answer of an
external function of its own type, which is what makes AP 6.4.12.3's *at most
once* keepable — a value is born in one place and the variable receiving it owns
it. It also meant a program could not release a handle before its own variable
died, and both modules built over the type wanted to: `PasStream.Close` and
`PasDir.Close` each assigned the answer of a call they knew would fail —
`fopen('', 'r')`, `opendir('')` — because the release is the *assignment's* and
a null answer leaves the variable empty. It worked, at the price of a refused
system call, a stale `errno`, and a `LastErrorText` after `Close` naming the
empty path rather than whatever had actually failed.

**`h := nil` assigns no value, and that is why it fits rather than widening the
type.** `nil` already denotes the empty state of every handle-type — 6.4.12.2's
own second paragraph admits it on the right of `=` — so the type still has
exactly one way to *acquire* a value and this is a way to give one up. Every
restriction ADR-0174 argued for is untouched: no copy, no second name, no value
parameter, no result.

**One Sema arm and nothing else**, exactly as the roadmap had predicted:
`pas_handle_set` already released what the slot held before storing, and
`EmitExpr` of `nil` is a null pointer, so the existing lowering of the first
form *is* the second when the value is null. CodeGen was not touched and neither
was the runtime.

What made it land was the **second caller**. The roadmap had said the spelling
"waits for a second module to want it", and `PasDir` wanted it on the day it was
written — ADR-0116's rule doing the thing it is for.

Its evidence is a loop: two thousand streams opened and closed through one
variable, under `run_test.sh`'s `ulimit -n 256`, so a release that does not
happen stops the program at about the two hundred and fiftieth. That is
`str_arena_loop.pas`'s argument and it needs the same thing to be true — a bound
low enough that exhausting it is cheap. Releasing an empty handle is not an
error, and the case says so on its own line, because a caller of a `Close` that
answers nothing will call it twice.

### The twenty-sixth increment: the module that could not declare what it talks to

ADR-0203. Networking is the first of ADR-0109's four goals and was the only one
with no module. The roadmap had said what was left: *a decision about what a
portable `sockaddr` declaration looks like*. There is not one, and ADR-0188 had
already generalised why — so the question was what the module asks for
**instead**.

**Both ends of every call are strings.** A host and a *service* — `http`, or a
number written out — go to `getaddrinfo`, which decides what they mean. Nothing
in the module or the runtime names an address family, a port number, an address
or a byte order: no `sockaddr`, no `htons`, no `sin_port`, no choice between
IPv4 and IPv6, and the loop takes the first address that works, so a caller gets
IPv6 where it exists and IPv4 where it does not without a line about either.

Two things fell out that were not the reason. `<netinet/in.h>` and
`<arpa/inet.h>` are not needed, so ADR-0186's header catalogue grew by two
rather than four. And an **ephemeral port is expressible**: listen on service
`'0'`, ask `Service`, and get back the numeric string `Connect` takes — so a
program can talk to itself with no number type involved at all, which is the
whole of what the test needs.

**A socket is a handle rather than an integer**, because AP 6.4.2.6.2 makes an
integer numeric on purpose: a program holding a descriptor could add to it, copy
it and close it twice, which is the door ADR-0151 records as open and unclosable
for `int64`. The runtime keeps the descriptor in a structure of its own, and
`s := nil` — landed the same day, one increment above — closes it early.

**Reading is by line and the buffer is in the runtime**, forty lines of C rather
than a trap for whoever writes the first program that reads and writes on one
connection: `PasStream` gets lines from `FILE *` and a socket cannot, a stream
over a non-seekable descriptor being forbidden to switch between reading and
writing without a positioning call.

And **SIGPIPE is ignored once**, where a socket is first made. Writing to a
connection the far end has closed raises it, and its default disposition ends
the process with no diagnostic — which is not an outcome a routine answering an
`ErrorCode` can report. `signal` is ISO C; `MSG_NOSIGNAL` and `SO_NOSIGPIPE` are
one system's each.

### The twenty-seventh increment: the client was written first, and it compiled

ADR-0205, and it is the cleanest demonstration in this file of `doc/sop.md`
§4a — *a feature with a surface needs a client, not a case*.

ADR-0203 had said in as many words that it could not wait on several
connections, and ADR-0201 had said that a program serving two clients needs a
construct this language has not got. The roadmap put a second row in front of
it: of the three affine kinds only `owned ^T` moves, so a socket cannot be
handed to anything and a task could not be **given** a connection.

The work began by writing the server, and **the server compiled**. An array of
handles is admitted (AP 6.4.12 NOTE 3), a `var` parameter binds to one of its
elements, so `Accept(srv, clients[k])` puts a connection in a slot without
anything being copied, `clients[k] := nil` releases one, and a schema gives the
array whatever length the program wants. Nothing had to move because nothing was
ever assigned: **a handle reaches its home by being the `var` parameter its
producer writes through**, and a server never needs a second name for one. Two
roadmap rows closed with no feature between them.

What was actually missing was one answer — *which of these can I read without
blocking* — and a probe pinned it exactly: two clients connect, the second
speaks, the server reads the first, and the program hangs.

`Wait` is one call, and **nothing is held between calls**, which is the safety
argument rather than a simplification. The obvious API is C's — a set built up,
waited on, asked about — and it would make the set a second name for every
socket in it, held across statements, dangling the moment a program wrote
`clients[k] := nil`: ADR-0151's aliasing question arriving through the library
door. Building the list inside one call retires it the way ADR-0187's copy
retired an address, and between the call's first statement and its last nothing
can close a socket, because every statement in it is this module's.

Three smaller decisions. **An empty slot is a hole, not something to compact** —
POSIX has `poll` ignore a negative descriptor and zero its `revents`, so a
server that closes a client needs no bookkeeping, which is a property of the far
side taken whole. **`poll` and not `select`**: the roadmap said `select` and
meant the shape, and `select` would have cost `fd_set`, `FD_SETSIZE` and four
macros for the same answer, with a bound this module would then have inherited
and had to explain. And **a socket holding a line the runtime has already read
is ready, and the operating system cannot say so** — `ReadLine` buffers, so
readiness is the descriptor's answer *or* the buffer's, and a server asking only
`poll` sits still holding a line it was handed.

### The twenty-eighth increment: the gap was a place to put the answer

ADR-0206. `runtime/pasrt.c` had carried the argument for this clause since
ADR-0174, written as the reason for the gap rather than as a request to close
it: *the closer's result is deliberately not inspected — a handle is released on
the way out of a block and there is no statement left to report to.* That is
true of every release AP 6.4.12.3 lists — a block terminating, a `goto` past it,
a `halt`, a `dispose`, an external's answer assigned, `nil` assigned. None of
them is a place a program could receive an integer.

**What a closer answers is not a formality.** `pclose` answers the child's wait
status; `fclose` reports a flush that failed, which is the last chance to learn
that a file was not written. `PasProcess.Capture` is the client that lived
without it, and what it did instead is the argument entire: the command was
wrapped in a subshell, `( cmd ); printf '\n\001%d' "$?"`, and the reader split
the stream at a newline followed by the character 1 — so a program that wrote a
control character 1 at the start of a line was **misread**, everything after it
becoming the status and everything before it becoming the whole output.

`release(h)` releases what the variable holds, yields what the closer answered,
and leaves the variable empty. **It is `take`'s shape with the position rule
removed, and the difference is the reason there is none**: AP 6.4.14.6 confines
`take` to the right of an assignment because what it yields is an *owned value*
and anywhere else it would be held by no one, while this yields an integer — so
a function-designator may stand wherever an integer may be written, and
`if release(a) = 0 then` is a scenario of the clause.

**An empty variable answers zero and is not an error**, which is the assignment
of `nil` rather than `dispose` of nil: a program that released nothing has
nothing to be told about, and a caller needing to tell *closed, and the closer
said zero* from *there was nothing to close* has the variable itself to ask,
before. And the emptying stays in the runtime — `pas_handle_release_result` is
`pas_handle_release` with the result kept, the same three lines rather than a
second copy beside the first, because a copy is free to drift and this is the
invariant 6.4.12.3's *at most once* rests on.

The strongest thing that can be said for it is what it removed: `Capture`'s
golden passed unchanged with the marker, the subshell and the reader's lookahead
all deleted.

### The twenty-ninth increment: the borrowing that settles nothing

ADR-0208, and it is the plainest case in this file of the argument the roadmap
makes about the other Pascals. `break` leaves the closest-containing
repetitive-statement and `continue` completes the current iteration of it —
taken whole from Turbo Pascal, Delphi and Free Pascal, down to the spelling and
to leaving *one* loop rather than a named one. It settles no open decision and
unblocks nothing. **A question the standards do not answer and three Pascals
answer alike is one where novelty would be a cost with nothing to show for it.**

**It cost two branches, because the blocks were already there.** CodeGen keeps
two integers saved and restored around each loop's body — the lexical nesting is
the stack, so there is none to keep — and the statement writes `br label %LN`
and opens a fresh block for what follows, which is `exit`'s shape. Three of the
five loop forms needed no new block at all: a while-statement continues at its
condition, a for-in over a text at its head, and a for-in over a set at its
step. The two that did are the two AP 6.7.5.11 names for a reason — a
repeat-statement's condition follows its sequence, and a for-statement tests its
control variable against the limit *after* the body, so *the beginning* is the
wrong description of where `continue` goes and the clause enumerates the four
forms instead of saying it.

**And the deferred statements needed nothing.** AP 6.9.3.11 NOTE 2 already said
that leaving a statement-sequence by a `goto` does not *complete* it, so what it
armed waits for the activation to terminate. That sentence was written for
`goto` and is true of these two unchanged — a clause paying for a feature
written three increments after it. What `defer` did need was the other
direction: `defer break` is refused, because the loop depth is zeroed for the
duration of the deferred statement's check while the statement path is not,
6.8.1's reachability being about where a statement was *written*.

The spelling is ADR-0140's second shape, a required procedure-identifier
shadowable by §6.1.3, so both conformance modes say *unknown procedure* and
`src/` needed no change.

### The thirtieth increment: half a container, and the wall was not where it was expected

ADR-0209. `PasVector` holds integers, `PasStrVec` strings, `PasList` strings and
`PasMap` maps a string to an integer — four modules where one would do, and the
way to have a fifth for another element type is to copy a file. This is the
increment that takes half of that away: `Vec(T: type; cap: integer)` is a schema
whose production for each `T` is a distinct type with its own layout, and two
productions naming the same type are the same type.

**`type` in a discriminant position is a spelling nothing had to be reserved
for.** It is a word-symbol of both standards standing where a type name would
go, so no conforming program could have written it there and `reserved-words` is
untouched.

**Everything else is ADR-0039's machinery reused, and that is the finding.** The
intern key was already `(schema, tuple)` and the body was already re-resolved
per distinct tuple — *a schema keeps its syntax and not a type*. What was
missing was only an integer for a tuple component to name a type by, so every
type object now carries a `typeId` from `NewType`, never reused: equal ids are
the same object, which is ADR-0017's name equivalence and deliberately not a
structural comparison, since two records written alike are two types and must
produce two. Binding `T` as `skType` rather than `skConst` is what lets
`array [1..cap] of T` reach the existing subrange and array code with nothing
added. And the parser cannot tell the two kinds of actual apart — an
actual-discriminant is an expression either way — so Sema looks the name up, for
the sixth time.

**It found a latent defect nothing else could have.** `GenericFromSchema`
assigned its result in two branches and had a third that assigned none,
reachable only after an error, so it answered whatever the result slot held and
the first caller to print that type stopped the compiler on a case with no
matching label. No correct program could reach it, which is why it had sat
there: every oracle here starts from a program.

**And the wall is not where it was expected.** A schema with a type discriminant
may not be a parameter-form, because a schematic formal reads its discriminants
from a run-time descriptor (ADR-0040) and a type cannot travel in one — so
`Push(var v: Vec; x: T)` is refused in as many words, and a routine generic in
`T` needs translating once per `T`. The half that was *feared* — separate
translation, and what a generic body would have to be delivered as — turned out
not to exist: `--import` re-parses each component's full source and keeps only
its module-headings, so the body is already in the client's memory and no
header, template or mangled-name format is needed. **What is missing is
instantiation, not delivery**, and the roadmap carries it as the row a container
written once opened.

## What the roadmap answered

`doc/roadmap.md` holds what is open. For two years it also held the full
account of every question it had closed — struck through and kept, because
what a survey *found* was the part worth carrying forward. That was right
and it made the roadmap unreadable, so the accounts live here now, in the
order the roadmap ranked them. Each is the text as it stood when the entry
was closed; the record that closed it is named in the first paragraph.

### The seven structural questions about the dialect

The roadmap's chapter *The two standards and the dialect* asked seven
questions about the relationship between `--std=afterschool` and the two
conformance modes — where it was asserted more strongly than checked, and
which decisions were being made by default. Six have a record. The seventh,
the dialect's lack of an external authority, is a standing risk and stays on
the roadmap; what its audits found is below with the rest.


#### 1. The dialect has spent no reserved word, and that is a fact rather than a policy

Four features have landed and none of them cost the lexis anything:

| Feature | What it cost |
| --- | --- |
| `external` (ADR-0121) | nothing — a directive, in the one position `forward` occupies |
| `?T` (ADR-0123) | nothing — `?` was unused punctuation |
| `array of T` (ADR-0125) | nothing — two words already reserved |
| `int64` (ADR-0128) | a *required identifier*, which §6.1.3 makes shadowable |

That is a real discipline and it was never decided: each feature found a cheap
spelling on its own, and the pattern is visible only in aggregate. **It is also
the only thing keeping the containment claim itself true — §3 below (the containment stops at the link).** The
moment the dialect reserves a word-symbol, a valid Extended Pascal program
using that identifier stops compiling — which is exactly how ISO 7185 and
Extended Pascal came to be non-nested (ADR-0033), and the reason `--std` is a
property of a source rather than a switch.

The collision is coming. `defer`, error unions, traits and actors — every
remaining borrowing in *Where the ideas come from* wants a word. The dodges
available are a directive position (only where the grammar admits exactly one),
a required identifier (names, never statement syntax), punctuation (a small
supply, and poor for statements), and ADR-0038's trick of joining two words the
lexer already has, the way `and then` is joined.

**Decided (ADR-0140): a constraint, and permanently.** The dialect reserves no
word-symbol, and the question of "spending a budget" turns out to be the wrong
frame — what is scarce is not spellings but **positions**, and a position is
not used up by being occupied. `external` taking the directive slot does not
stop something else taking the statement-initial slot.

So the rule the four features were following, written down: **a dialect feature
is spelled in a position where a conforming program could not have written
it.** The test is one sentence — could a conforming program have written this
spelling *in this position*? — and it is answerable before a spelling is
chosen rather than after.

**Statements were the case this question was really about**, and they pass the
test. A statement-initial identifier in either conforming language is followed
by exactly one of `(`, `:=`, `[`, `.`, `^`, or a statement terminator (`;`,
`end`, `else`, `until` — the last three because §6.8.1 admits an empty
statement; probed, not derived). So `defer <statement>` is decidable with one
token of lookahead and cannot collide. A program that declares `var defer`
keeps its variable and loses the statement form in that scope, which is the
right direction: the dialect yields to the standard it contains.

`reserved-words` is the gate, and it is not redundant with the containment sweep (§4):
reserving `defer` in the dialect leaves **all 619 cases green**,
`dialect-containment` included, because no corpus program uses that identifier.
AP §6.1.2 states the requirement.

#### 2. The dialect has no external authority — what the audits found

The third row is literal rather than rhetorical. `tests/spec/run.py` matches

```python
TAG = re.compile(r"@(iso7185|extended):(\d+(?:\.\d+)*)")
```

was the pattern until ADR-0135's wiring, so a dialect scenario could not be
tagged at all and ADR-0105's apparatus — the one suite whose unit is a clause
rather than a program — was unavailable to the fastest-growing part of the
compiler. It now reads `@(iso7185|extended|afterschool)`.

Every oracle in this repository bottoms out in *the standard says X*.
`.claude/skills/langspec-audit/` exists because no oracle here can contradict a
**reading**, and its remedy is independent readers holding the standards text.

**Half of this is now answered.** ADR-0135 wrote
[`doc/afterschool-pascal-spec.md`](afterschool-pascal-spec.md), an amendment to
ISO/IEC 10206:1991 in that standard's own clause numbering, derived from the
thirteen records and verified by probe rather than from the compiler's source —
so there is a text to hold, and the fourth row above is no longer empty. It
found five divergences on its first pass, one of them a compiler crash no gate
here could see.

**The third row followed it.** `tests/spec/run.py` takes `@afterschool:` beside
the two standards' tags, and 47 of the specification's 49 testable clauses are
cited by a scenario — the two that are not are 6.11 and 6.13.1, both rules
about which program-components may be *linked* together, and the harness
compiles one program (`doc/sop.md` §7). The clause table is generated from the
document rather than transcribed, so the two cannot drift.

**And the second row moved, though not to "yes" (ADR-0160).** `src/` is frozen
at the conformance surface — but *what a conformance mode says about a dialect
construct is conformance behaviour*, which is ADR-0121's rule and ADR-0154's
generalisation of it. So the refusal surface was never on the dialect's side of
the freeze; it simply had no programs. The specification's Annex B is the table
of that surface, and of its five constructs exactly one had a case, under one
mode.

There are ten now, one per construct per conformance mode, and `annex-b` reads
the annex and requires each golden to contain the message the document states —
so the annex is enforced rather than accompanied, and difftest compares the two
front ends on all ten. **Probing them found the annex wrong**: it claimed the
two modes say the same thing, and ISO 7185's parser stops at the `..` in
`a[i..j]` where Extended Pascal parses it and Sema refuses it by type. One
column became two.

Worth carrying into the next dialect feature: **four of the five refusals need
no code in `src/` at all.** ADR-0140's rule — a dialect construct is spelled
where a conforming program could not have written it — means the refusal usually
falls out of a grammar both front ends already share. `external` is the
exception, §6.1.4 making a directive an ordinary identifier in the one position
it may occupy. A construct that needs teaching in `src/` is a signal that its
spelling is not in such a position.

What is **still** empty is the first row, and it is not something a document or
a harness can supply: there is no third-party corpus for a language this project
invented, and the BSI suite is unavailable for a second reason besides novelty —
the dialect does not contain ISO 7185, Extended Pascal's reserved word-symbols
being in the way (ADR-0033). The second row is *partial* rather than full:
everything the dialect **accepts** is still compared by no second
implementation, `difftest.sh` skipping a dialect source by directory. A high
citation fraction here means the specification is young and was written against
a compiler someone could probe, not that the dialect is as well checked as the
conformance modes.

One external authority is already in play and is worth naming, because ADR-0129
noticed it and then dropped it: **POSIX and the C ABI are specifications**, and
`read`, `write`, `recv` and `send` taking a pointer and a count is the far side
of the boundary choosing a shape rather than this project choosing it. Every
FFI-facing decision has an authority available to it.

**And so does the largest feature that is not FFI-facing**, which this entry
denied and ADR-0152 found. ISO 7185 §6.6.3.7's **conformant array parameter**
is a formal parameter whose bounds travel with the actual — the question
AP §6.7.3.9's slice exists to answer — and ISO/IEC 10206:1991's schematic
formal is a third member of the same family. The standard answers it
differently in three ways the dialect chose against on purpose: bounds
preserved rather than renumbered from 1, a whole array rather than any
contiguous run of one, and a value form as well as a borrow. None of that was
written down; the slice clause's own NOTE reached for "the open array of other
Pascal dialects" while a standard on the shelf had the question. It is a NOTE
at AP §6.7.3.9.1 now. Note the coincidence this file kept without noticing:
*Conformant array parameters, and level 1* below is about the same clause.

**And one more turned up when the spec was aligned with the standard's clause
numbering**: ISO/IEC 10206:1991 §6.1.4's NOTE anticipates a remote-directive
spelled `external` for a heading whose block lies outside the program-block —
so ADR-0121 chose the spelling the standard names, without knowing it. The same
NOTE recommends enforcing type compatibility across the boundary, which this
compiler cannot; the departure is now written down rather than merely true.
Nothing else in the dialect has an authority.

**And the path from an authority to a gate had a hole in it (ADR-0152).** The
risk this entry names is that a mistake survives every oracle at once because
every oracle bottoms out in the same reading. What it did not anticipate is a
mistake in the *machinery* between the standard and the gate. `tests/spec/`'s
clause inventory is generated from the standards by a script, and every
sub-clause of §6.2.2 (Scopes) and §6.2.3 (Activations) in both standards is a
bare number on a line of its own with the requirement under it — no title. The
extractor read only lines carrying a title, so **37 real clauses** were in no
inventory, no triage and no work queue, and `spec-clause-traceability` answered
*"§6.2.3.8 is not a clause of that standard"* about a clause two ADRs are about.
§6.2.2.9 is the most-cited clause in this repository at 56 citations; 214
citations across the tree named a clause the apparatus did not have. No reader
would find this, because a reader cites the clause from the standard and never
opens the `.tsv`.

Fixed, and guarded from both sides: the triage and the inventory must now name
the same clauses, so a clause the extractor loses fails as an orphaned triage
row and a clause it gains fails as an unclassified denominator. Reverting the
extractor fails the gate 37 times. `tests/spec/features/scopes.feature` is six
scenarios for clauses that could not be cited at all the day before.

**Audited once (ADR-0144).** Five independent readers were given
`doc/afterschool-pascal-spec.md` and the two standards and told to prove it
wrong. That is the substitute for an authority and it is a partial one: it works
for every claim the document makes *about* ISO 7185 and ISO/IEC 10206:1991 —
**nine of those were wrong**, including `external` called a remote-directive
and §6.1.3 credited with a rule that is §6.2.2.5's — and it cannot work for a
requirement the dialect invents, where a reader can only ask whether the
processor agrees with the document.

It also found four defects in the compiler, two of them memory-unsafe, and one
clause of the specification that contradicted another while being classified
`structural`, which makes a requirement unfalsifiable by construction. So the
substitute is worth running; it is not an authority.

#### 3. The containment stops at the link, and no document says so

ADR-0117's claim is that the dialect **contains** Extended Pascal:
`HasExtended(s)` is `s >= stdExtended`, and
`tests/dialect/inherits_extended.pas` is the witness. At the source level it
holds. It does not survive separate translation:

```
$ tools/pascalcc --std=extended -c lib/pasmath.pas -o pm.o     # fine
$ tools/pascalcc --std=afterschool use.pas --import lib/pasmath.pas pm.o
ld: undefined reference to `m.pasmath.afterschool.init'
pascalcc: error: module 'pasmath' was translated under a different --std
```

Sema accepts that program **completely** — the interface resolves and
`PasMath.IMax(3, 4)` type-checks — and it dies at the link. So the six
conforming modules in `lib/` are unreachable from the dialect: the layer
ADR-0114 built so the *conforming* language would have a library is the layer
the language that contains it cannot use.

ADR-0119's reason is real and the hole it closes is real — the dialect's
variant rules are a pair emitted at the access, so a dialect component reading
a variant a conformance-mode component wrote runs its guard against a tag
nothing stored and **permits** the read. What is wrong is not the rule but its
granularity: the mangling names the *mode*, and the mode is a proxy for the ABI
that is far too coarse. `lib/pasmath.pas` contains no variant record at all,
and its object code is identical under both modes.

The principled fix is the move this project already makes everywhere else —
**ask what actually differs, not what the flag says** (ADR-0044, ADR-0053,
ADR-0066, ADR-0071, ADR-0087 are the same sentence about five other
constructs): mangle on a fingerprint of the ABI-relevant features a module
actually uses, or emit both symbols where the object code is mode-independent.

**ADR-0137 took the second of those two moves**, and the entry above describes
the compiler as it was. What ships now: Sema asks whether any type reachable
from a module's interfaces is a record with a variant-part having a tag-field —
the emitter's own condition for the check, asked over the interface instead of
at one access — and a module for which the answer is no emits its activation
names under the dialect's spelling as well as its own. `lib/`'s six modules are
reachable from the dialect and not one of them needed changing; none has a
variant-part anywhere.

The alias was taken over the fingerprint because **only the definer computes
it**. A fingerprint both sides compute is the more general answer and puts one
predicate in two places, and the day they disagree is a link error nobody can
read. The caller is unchanged: it asks for its own mode's name, as it always
did.

**One direction stays closed**, and that is ADR-0120's decision rather than
work left undone: a dialect module may call `external` routines and is not a
conforming program-component, so a conforming program still cannot link one.

So the honest phrasing is no longer that the containment stops at the link. It
is that **the linkage follows the language except where the dialect would emit
a check the other mode does not**, and AP §6.13.1 now carries that sentence —
the first clause of that document to change because the language did.

#### 4. Containment is a claim about every program, witnessed by one

`dialect-containment` is that sweep (ADR-0138). The whole of `tests/extended/`
is compiled a second way under `--std=afterschool` and required to behave
identically — 228 cases, 13 seconds, four divergences with an argument apiece
in `tests/checks/containment_exceptions.txt`.

The proposal above said "require identical results" and the word doing the work
turned out to be *results* rather than output: diffing the emitted IR does not
work, because 19 of 219 sources differ textually and sixteen of those differ
because the dialect is working — ADR-0119 spells `--std` into a module's
activation names, ADR-0118 adds a tag check to every variant access. So the
gate runs the case, which is what `run_test.sh` already decides.

**What it was worth is measurable.** Switching Extended Pascal off for the
dialect at the `readstr`/`writestr` site — the literal mistake `CLAUDE.md`
warns against — leaves **all 617 existing cases green**, `inherits_extended`
included, and `dialect-containment` names sixteen. At the string-comparison
site the single witness does fail, with one opaque error where the gate reports
ten cases and their diagnostics.

It also found the only case in 228 that diverges for a reason of its own,
`substring_errors`, and following that thread found a defect the corpus could
not reach: two slices are compatible, the relational operators ask
compatibility, and `a[1..2] = a[3..4]` compiled to invalid IR (ADR-0139).

#### 5. The dialect was pulled, not designed, and the pieces have not been checked for coherence

Every feature so far was demanded by the foreign interface or by the library
built on it: `external` because nothing outside the program was reachable
without it, `?T` because a `char *` may be null, `array of T` because a buffer
needs bounds at the boundary, `int64` because `read` answers an `ssize_t`, and
the variant rules and the result record because the library needed a way to
report failure. The one *designed* feature — ADR-0116's allocator — did not
survive contact.

That is a strength: nothing speculative has landed, and the record of the last
five increments is that each blocked half turned out narrower than written
down. The risk is its mirror — no one has stepped back and asked whether the
pieces form a language rather than a set of local optima.

The sharpest instance was that **the dialect had two ways to say "this may have
failed"**: an optional (`?T` — absence) and a result record (ADR-0120 — absence
with a code). **Answered (ADR-0141)**, and the survey found the premise
understated: there are **four** shapes, not two, and the fourth is not about
failure at all.

| Shape | Routines | What it says |
| --- | --- | --- |
| `ErrorCode` | 9 | the routine acted; it worked or here is why not |
| `?T` | 1 | there is a value, or there is not, and nothing to add |
| a result record | 9 | there is a value, or here is why there is not |
| `boolean` | 4 | a question about the world, with no failure of its own |

The rule is two questions in order: **is there a value to return?** — no, and it
is an `ErrorCode`; then **can it be missing for a reason the caller could act
on?** — no, an optional; yes, a result record. All 35 exported routines
classify. `absence is not a failure` was the right slogan for the second
question's *no* arm and was never a rule for the whole surface, which is why it
alone would not have told an author what to do about `Remove`, which returns
nothing, or `Exists`, which cannot fail.

`lib/dialect/README.md` is that written for the author of the next module, and
it is where the two spelling rules live too — a result record's tag is `ok`
everywhere, and an extractor is `XOr(result, default)`.

**One routine breaks the rule and cannot be fixed**, which is the part worth
carrying forward: `PasEnv.Lookup` stops the caller's program on an environment
value longer than 4096 characters, a third outcome its optional cannot express.
`getcwd` is lent a buffer and reports `ERANGE`; `getenv` returns a pointer to a
string of a length nobody stated, and the dialect has no result form that can
receive an unmeasured one. So the rule ends with a clause about honesty rather
than shape — where a boundary cannot report a failure, say so at the routine.

**The other three near-overlaps are examined too (ADR-0149)**, and they divide
the same way three times — on **ownership**, the second member of each pair
being the shape that describes something outside the block:

| Pair | The owned shape | The other shape | What the other shape says |
| --- | --- | --- | --- |
| absence | `^T` | `?T` | there may be no value |
| sequences | `string(n)`, `packed array [1..n] of char` | `array of T` | the sequence belongs to the caller |
| numbers | `integer` | `int64` | the number came from outside |

From which one rule for a module's author: **a boundary shape may be a
parameter and may not be a result.** The language already enforces two-thirds
of it — AP §6.7.3.9.2 makes a slice result a syntax error and AP §6.4.2.6.5
makes no `int64` expression a constant — and the library was written to it
three times over before anyone stated it: of 35 exported routines, none returns
an `int64` or mentions one, three take a slice and all three are byte I/O, and
the only exported optional is a `?string`. There is **not one pointer type in
seven modules**; all three `^` in `lib/dialect/` are optional accesses.

What the survey found and did not fix is `?^T`, an optional of a pointer, which
has two absent values that are not the same value — `op = nil` is false while
`op^ = nil` is true. It is argued for rather than refused: the redundancy is the
program's and not the language's, the two checks compose in the right order, and
nothing here writes it. It is in AP §6.4.11.2's NOTE and in `doc/sop.md` §7.

So §5 is answered for the shapes that exist. It says nothing about the shapes
not yet added, and every rule in it turns on the word *owns*, which §7 is what
has not defined.

#### 6. "The conformance modes stay exactly as they are" is slightly stronger than the truth

ADR-0121 requires `src/` to carry the *refusal* of `external`, and the message
names the mode — so a program written for the dialect and compiled under
`--std=extended` is told about the dialect.
`.claude/skills/release-engineering/` makes diagnostics part of the public
interface, alongside the accepted language and the command line.

**Answered (ADR-0154).** The exact claim is: *the dialect does not change what
the conformance modes accept; it does change what they say* — and four
documents now say that instead of the stronger thing: `CLAUDE.md` in two
places, `doc/glossary.md`, `doc/afterschool-pascal-spec.md` §5.3 and this file.
It is unavoidable and is not a conformance question, §5.1 being about accepting
and rejecting; refusing to name the dialect would keep the old sentence true and
make the diagnostic worse.

**And the sentence had a second reader problem the entry had not seen.** In
`CLAUDE.md` it sat one paragraph from ADR-0109's goal, where it reads as a
promise about the whole compiler — and ADR-0153 made that false in a much larger
way, `--std=iso7185` now accepting conformant array parameters. That change has
nothing to do with the dialect. So the corrected sentence names its subject: a
conformance mode's accepted language moves only for a reason inside its own
standard, and level 1 is such a reason where the dialect never is.

#### 7. The memory-safety fork: deferral, or discovery?

ADR-0109 wants networking, internationalisation, concurrency and memory safety,
and this entry put three of the four behind one decision never made — the safety
model, "ARC, ownership, or neither". It offered two readings of the increments
before it, that the decision genuinely kept proving unnecessary or that it was
being routed around, and said the opaque handle (`DIR *`, `FILE *`) "is the
first item that forces it, which is the reason it has not simply been started."

**Answered (ADR-0151)**, and neither reading was right. Three findings, and the
second is the one that cost something.

**There was already a model here and nobody had named it.** A file variable
cannot be copied — no assignment, no relational operator, no value parameter,
no function result, and since ADR-0150 none of those for anything *containing*
one — and it is released on every exit the language has: the block epilogue, a
non-local `goto` (ADR-0032), `halt`, and `dispose`, which emits `pas_file_done`
before the free. The runtime states the invariant that makes it work, that file
lifetimes nest. That is affine ownership with scope-based release — move
semantics and `Drop` — reached from ISO 7185 §6.4.6 a) and §6.6.3.1 in 1982,
and implemented across 30 `IsFile` sites, 14 `ContainsFile` and 9 `HoldsFile`.
It is now the dialect's stated model: **an owned value is released when the
variable holding it dies, and cannot be copied out of that variable.**

**The handle was never blocked, and the sentence above was protecting nothing.**
AP §6.7.7.9 c) forbids an external result that is an address of storage the
callee owns; AP §6.7.7.8 admits `int64`, which ADR-0128 added for `ssize_t`; a
pointer fits in 64 bits and no processor can tell a count from an address. So
`function ExtOpendir(path: string): int64; external 'opendir'` compiles, links
and opens the directory — and because AP §6.4.2.6.2 makes `int64` numeric on
purpose, the handle copies, `d := d + 8` is a legal statement about an open
directory stream, and closing it twice is `double free or corruption (!prev)`,
exit 134. It was in no register: not here, not ADR-0128, not Annex C.
`tests/dialect/foreign_int64_handle.pas` is the program, and Annex C.7 and
`doc/sop.md` §7 are where it now lives.

**The remaining fork is forced by aliasing, not by lifetime.** ADR-0122's
argument side, ADR-0123's null, ADR-0132's lent buffer and now the handle were
four questions about *when storage dies*, which is the half answered in 1982 —
which is why five increments produced nothing that discriminates between ARC
and borrowing. Those two differ about what may hold a **second name** for one
owned value. The deferral therefore has a criterion instead of a mood: it
becomes decidable at the first construct admitting two live names for one owned
value — a handle as a result, a handle stored in something outliving its block,
a second pointer to a disposed variable, or concurrency. Concurrency is the one
that certainly forces it, and it is unstarted.

Internationalisation is the fourth of ADR-0109's four and is wholly unstarted.
It is also the one with the best model available to copy, and the one whose
absence a "practical Pascal" would be judged on first. It is now the largest
thing on this page that no record has touched.

#### What kind of work each of these was

The order above is the ranking, so what is left to say is the kind:

- **§1 was a decision** and is made (ADR-0140). It governs the spelling of
  every remaining feature, and what it turned into was a *test* a spelling has
  to pass rather than a quantity to ration.

- **§2 is a risk.** It is the condition under which this project's own history
  says a mistake survives every oracle at once.

- **§3 is a bug.** Concrete, reproduced above, and probably a day's work under
  the ABI-fingerprint framing.

- **§4 was cheap** and is done. It also demonstrated its own limit, which is
  what motivated §1's gate: a word-symbol the dialect reserves breaks
  containment for every program using that identifier, and the sweep reports it
  only where a corpus program does — which for `defer` is nowhere.

- **§5 is written** — its sharpest instance in ADR-0141, the remaining three
  near-overlaps in ADR-0149 — and what was left of it was §7, both records
  dividing their shapes on ownership while neither could say what owning is.
  **§7 now says** (ADR-0151): released when the variable holding it dies, and
  not copyable out of that variable. **§6 is written too** (ADR-0154), and it
  was one sentence: what a conformance mode accepts does not move for the
  dialect, and what it says may.

- **§7 turned out to be two questions wearing one name.** The half about
  lifetime was answered before this project began and only needed naming; the
  half about aliasing is open, undecidable from the evidence five increments
  produced, and waits on the first construct that gives one owned value two
  live names. What it cost to leave them merged is in Annex C.7.

### The oracles the roadmap asked for

*What is next* was five items. Two were open when this was written — a
third-party differential and mutation testing committed to the tree — and
mutation testing has since landed (ADR-0207,
[below](#a-mutation-as-a-file)), so one is left. The other three are done,
and what each found on its first run is the argument the roadmap still makes
for the one above them.

#### The oracle nobody here wrote — what the two restorations paid

ADR-0085 stated the cost, and **two entries have since answered it** — this
section is kept because the reasoning is what justifies the third candidate
below, which is still open.

`selfhost/difftest.sh` compared two independent implementations over 436
sources; what ADR-0085 left — the 435 cases, the stage-2/stage-3 fixed point,
and 43 SMT rules — all shared one implementation, and **a golden cannot
disagree with the program that wrote it**. The defects difftest caught were
exactly the ones every other oracle agreed about: a builtin's enumerator one
apart (ADR-0059), a comment-delimiter rule implemented wrongly in *both*
compilers (ADR-0073), a diagnostic that named two types identically and
explained nothing (ADR-0074).

Both restorations have now paid. The BSI suite found three defects on its first
run (in *the oracle nobody here wrote*), and the returned front end found a **dump defect in the product**
that no golden could have: `pascalc` padded twice for a redefined `write`,
once for the husk node and once for the call it looks through, so a `proccall`
printed two levels deeper than its own arguments. Copying that into `src/`
would have closed four files and been ADR-0073's failure exactly — two
compilers wrong the same way, difftest agreeing happily —
so the Pascal was fixed and `tests/dumps/redefine_family.pas` pins it.

Three candidates, cheapest first, and not exclusive:

- ~~**The Pascal Validation Suite**~~ **Done** (ADR-0086). The BSI suite,
  version 5.7, 812 programs — fetched rather than committed, because BSI grants
  use and not redistribution, and pinned to one upstream commit so a red bar
  cannot be a corpus edit. `tests/bsi/expected.tsv` records what the compiler
  does with every one and fails on any difference **in either direction**, which
  is `verify/`'s rule for a `KNOWN_GAP` that starts holding.

  - **It found three defects on the first run**, all of which the goldens, the
    fixed point and the 43 proofs agreed were correct: `succ`/`pred` running
    out at a *subrange's* bounds rather than its host's (§6.6.6.4 with §6.7.1),
    the `for` bounds being range-checked when the loop does not execute
    (§6.8.3.9), and a program being unable to redefine `write` (§6.6.4.1). The
    first was wrong in `tests/trap_succ_subrange.pas`'s own comment and in
    CLAUDE.md as well as in the compiler — which is exactly the shape ADR-0085
    said nothing left here could catch.

  - **All three are fixed**, the third by ADR-0087, which also retired
    ADR-0060's deviation on `readstr`/`writestr` and found a check that had
    never been reachable. CONF116 is the only one of the 812 whose verdict has
    moved since, and the catalogue is what said so.

  - **Level 0 is now confirmed from outside**: all 51 `LEVEL1` programs are
    rejected, as the suite requires of a processor without conformant array
    parameters. The first claim in `doc/implementation-defined.md` §1 that
    something other than this project has checked.

  - ~~Outstanding from it: **28 undetected errors against that document's
    twelve**~~ **Done.** The two numbers were never comparable — 28 is a count
    of *programs* and the document's rows are *rules* — so the reconciliation
    was done against Annex D itself, which both sides can be keyed to. The 28
    programs name fifteen distinct entries, of which
    `doc/implementation-defined.md` §3 had eight: D.5, D.6, D.12, D.13, D.19,
    D.27, D.30 and D.48 were missing, each unenforced since the feature it
    belongs to landed. Every ERROR row of `tests/bsi/expected.tsv` now carries
    its Annex D number, so the section is regenerable rather than asserted, and
    D.59 — the one entry the suite has no program for — was probed by hand and
    is reported.

  - The largest of the accepted-but-should-be-rejected group is closed:
    §6.2.2.9's rule that a defining-point precedes every applied occurrence in
    its region was nine programs, and five are now refused (ADR-0088). The
    other four turn on a required identifier being recognised by *name* rather
    than being a symbol — ADR-0087's seam from the other side. Declaring the
    required identifiers as symbols in an outermost scope would close those
    four, §6.2.2.10 for required *types* (`type integer = char` is accepted and
    then ignored), and the rest of ADR-0087's own deferral, in one change. That
    is the next thing worth doing here.

  - Two entries the suite *reports* are not enforced either, and the document
    now says so: an undefined pointer is usually nil here, because a level-0
    activation record is a global (ADR-0053), so the nil checks catch D.4 and
    D.24 for the shape where the variable was never assigned and catch neither
    where the pointer is stale. A check that coincides with a rule is not that
    rule being enforced, and a green run of those two programs must not be read
    as one.

- ~~**The reference front end**~~ **Done** (ADR-0108). `src/` came back as
  `pascalc-s0` — lexer, parser and Sema, no code generator — so
  `selfhost/difftest.sh` compares tokens, AST and Sema over every source in the
  tree again. It arrived red at **89 of 731** files, the drift of twenty-four
  Sema commits, and the baseline is **now empty** over 732: every one of those
  rules was ported into `src/`, one commit per rule naming its clause. Eleven
  BSI CONFORM programs came back with them, CONF027 and CONF116 among them.

  - **It is a `ctest` case and an ordinary regression gate**, so any file the
    baseline names is a disagreement the change under review introduced.

  - What it still cannot do is contradict a **reading**: both sides are written
    by one author from one reading, which is why the candidate below is not
    struck through.

#### Diverse double-compiling, while it was still possible

**Run on 2026-08-18 at commit `ef49570`, and it passed.** The two outputs were
identical — 7,024,210 bytes, sha256 `399b9cdc…` — so a compiler reached through
LLVM's code generator and one reached through the seed translate
`selfhost/compiler.pas` to the same text. `seed/ddc.sh` is the procedure, and
`seed/README.md` holds the dated statement with what it does and does not
establish; the short version of the latter is that `v0.1.0` is this project's
own earlier compiler, so the implementations are diverse but not independently
authored.

The window was still open, which was not certain — the four steps below are kept
because they are the argument, and because `ddc.sh` reports the day they stop
working as a *skip* saying so rather than as a failure.

ADR-0085's sharpest cost is that provenance became "a chain rather than an
inspection": the first compiler now comes from a committed artefact whose only
warrant is this repository's history. That is answerable **once**, by David A.
Wheeler's diverse double-compiling, and `v0.1.0` still holds the second
implementation it needs.

1. Build `pascalc-s0` from `src/` at `v0.1.0`.
2. Have it translate today's `selfhost/compiler.pas` — call the result **A**.
3. Have `seed/pascalc.ll` build a compiler the ordinary way — call it **B**.
4. Have A and B each translate `compiler.pas`, and compare *those* outputs.

They must be identical, because both are the Pascal backend running on one
source, while the compilers that produced them came from unrelated
implementations. A and B cannot be compared to each other — ADR-0025 settled
that two backends' assembler text is not comparable — which is exactly why the
comparison is made one stage further on.

**The window closes on its own**, and nothing will announce it: it works only
while the v0.1.0 C++ compiler still accepts `compiler.pas`, and every feature
the compiler starts *using* risks ending that. Worth doing now and recording
the result in `seed/README.md` even if it never runs again — a dated statement
that the seed carried nothing the C++ compiler did not is worth more than the
ability to repeat it.

#### Conformant array parameters, and level 1

**Done (ADR-0153)**, and `doc/implementation-defined.md` §1 states level 1.

The estimate held in both directions and is worth keeping for the next one.
*Most of the mechanism is already here* was right: ADR-0040's schematic formal
parameter is a descriptor beside the address, which is exactly what a
conformant array parameter needs, and the bound-identifiers are `skDisc`
symbols — §6.6.3.7's NOTE 2 saying one denotes an object that "is neither a
constant nor a variable", which that kind already was. Indexing, the bounds
check and the size walk needed nothing.

*What is genuinely new is §6.6.3.7's congruity rules* was right too, and it was
the smaller half. What the estimate missed is that the **third-party corpus
already existed**: `tests/bsi/suite/LEVEL1/` is 51 programs, `expected.tsv`
recorded all 51 as rejected, and they found nine defects in the first
implementation and one older one — `pack` of a schematic formal had never
worked, and no program in this repository packs one.

*The feature buys conformance and not expressiveness* also held: a schematic
formal covers the same ground in Extended Pascal. What it bought that the entry
did not anticipate is the external-authority question's
authority — §6.6.3.7 is the standard's own answer to the question AP §6.7.3.9's
slice asks, and ADR-0152 found the two entries were about one clause.

#### Measuring what the corpus reaches

Both versions this entry proposed were built, and each found something the run
before it could not see.

- **The cheap version** — every diagnostic literal looked for in the `.err`
  goldens — landed in v1.1.1 as `diagnostic-coverage`. It found **32 messages
  nothing named** at once; 26 cases were written and four are argued unreachable
  in a catalogue that fails in both directions.

- **`procedure-coverage`** (ADR-0103) instruments the *emitted IR* with clang's
  SanitizerCoverage, which is possible only because the backend is textual.
  563 of 565 procedures are entered. It found four documented `--dump` flags no
  case had ever passed, and `tests/dumps/` exists because of it.

- **The expensive version** — `pascalc --coverage` (ADR-0104) — landed in
  v1.2.0 and did want a record. The compiler instruments itself, one counter per
  statement, and the *denominator* is read back from the same `.ll` the
  compilation wrote, so the two halves of a figure cannot disagree about which
  lines were executable. 12,949 of 13,403 statements are run by the corpus.

- **`tests/spec/`** (ADR-0105, ADR-0106) is the same question asked of the
  *standards* rather than of the compiler: a minority of the testable clauses cited,
  with 140 of the 419 headings triaged out as structural or unimplemented so
  the denominator means something. The inventory those numbers are counted
  against was 37 clauses short until ADR-0152, and the triage and the inventory
  are now required to name the same clauses in both directions.

**Two things it did not buy, both in `doc/sop.md` §7.** A statement is not a
branch — `if c then a else b` on one line is covered when either arm runs — and
the line-coverage gate is a **ratchet** rather than an allowlist, so it notices
a loss and cannot argue that what is uncovered ought to be. The corpus is also
enumerated by glob, so the shell harnesses are invisible to it; that is how
`Usage` and `Version` first read as unreached.

#### What continuous integration does and does not check

`.github/workflows/ci.yml` builds and tests on every push and pull request, in
two minimal **containers** rather than on a machine with a toolchain already
installed — which is the whole of what it adds. Every machine this compiler has
been built on has LLVM 21 and a C++ toolchain, so "the build needs nothing of
LLVM's" is a claim none of them can test. It also puts an assembler *older*
than the one that emitted the seed against that seed, a portability property
nothing else checks; and at a `v*` tag it requires `seed/pascalc.ll` to be what
the current source produces, which is the one question ADR-0085's
refresh-at-release-tags policy otherwise leaves to a human to remember.

**It adds no oracle.** It runs the ones that already exist, on a machine that
has never seen this repository. Item 1 is not something CI can supply.

**Its first two runs each found something**, which is the argument for having
written it:

- **README.md's build instructions were wrong.** "Requires `clang` on PATH, and
  nothing else" is false — `--no-install-recommends` gives no `make`, and
  configure fails before it reaches a compiler. Nobody could have noticed on a
  machine that has one. The sentence now names `cmake`, `make` and `clang`, and
  claims *nothing of LLVM's* rather than nothing at all.

- **Which z3 is installed decides whether the proofs pass.** `verify.py` gives
  each rule 30 seconds and reports a timeout through the same channel as a
  counterexample, so Debian trixie's z3 4.13.3 — slow enough to exceed it on
  the two symbolic 32-bit modulo rules — produces *"verification FAILED:
  mod-is-non-negative"*. That reads as the compiler getting `mod` wrong, which
  is ADR-0074's lesson about a message naming the wrong rule, in the one
  directory whose entire purpose is being sure. CI installs the pip package
  `verify/README.md` documents, and that README now says which failures to
  disbelieve; **making a timeout report as something other than a disproof is
  not done.**

One thing the workflow had to be told explicitly: `verify.py` *skips* when z3
is absent, which is right for a checkout and wrong for CI — the rest of the
suite would report green with every rule never run. It asserts z3 is
importable before it configures, so a green bar means the proofs ran.

### Cross-platform support, measured

The roadmap's cross-platform chapter keeps what is still open — the small
specific things; 32-bit was among them until ADR-0325, and [its rows are
below](#the-32-bit-port-and-the-width-it-left) — and a summary of what the lock
turned out to be.
This is the measurement it rests on, made on 2026-08-22 against
`aarch64-linux-gnu`, and the three items it closed.

#### What was measured

The comparison target is **aarch64-linux-gnu**: little-endian, LP64, IEEE
double — the closest thing to x86-64 that is a different machine. Everything
here was run with the `aarch64-linux-gnu` cross toolchain and `llc`, on the
v1.7.0 tree.

**The emitter's half is two lines.** `target triple = "x86_64-pc-linux-gnu"` is
the only literal architecture mention in `selfhost/compiler.pas`, and the
`target datalayout` beside it is the other half (ADR-0028). Nothing else in the
compiler names a machine.

**Frame layout is target-independent, and that is the surprise.** This file used
to list `LlSize`/`LlAlign` as the thing most likely to be baked in. Every frame
size and field offset LLVM computes was compared under the two datalayouts
clang reports for the two triples:

| Source of the frames | Sizes and offsets | Result |
| --- | --- | --- |
| `seed/pascalc.ll`, all 613 frame types | 4480 | identical |
| a probe carrying `i256`, `complex`, a file, a variable-string, an optional, `int64` and a conformant array | 21 | identical |

The second row exists because the first has no `i256` in a frame, and an i256 in
a record is the exact shape of the segfault ADR-0028 records — 16-aligned by the
stated datalayout and 8-aligned by LLVM's default. So the hand-written layout
rules need no change for an LP64 little-endian target. To re-run it: emit
`@g = global i64 ptrtoint(ptr getelementptr(%frameN, ptr null, i32 0, i32 K) to
i64)` for every frame and field, assemble under each triple, and diff the
values.

**The seed retargets textually.** Replacing those two lines and running
`clang --target=aarch64-linux-gnu -c seed/pascalc.ll` produces a valid aarch64
object from all 181,302 lines, with one `-Woverride-module` warning and nothing
else. The only symbol the emitted code names outside `runtime/pasrt.c` and
LLVM's intrinsics is `_setjmp`. **That breaks the chicken-and-egg**: a compiler
for the new host can be built without a compiler on the new host.

**And then the runtime refuses to compile.** Two C structs have their size
mirrored as a Pascal constant, because the two files cannot include one another
and the numbers are checked rather than shared:

| struct | x86-64 | aarch64 | declared |
| --- | --- | --- | --- |
| `pas_file` | 112 | 112 | `PAS_FILE_SIZE` = 120, `fileSize` = 120 |
| `pas_jump` | 216 | **328** | `PAS_JUMP_SIZE` = 256, `jumpSize` = 256 |

`pas_file` is four pointers and some ints, so it is the same on any LP64 — the
entry this file *did* name is the one that is fine. `pas_jump` embeds a
`jmp_buf`, which is **200 bytes on x86-64 and 312 on aarch64**, so its
`_Static_assert` fires and the build stops. That is the right failure and it is
the actual blocker; `jumpSize = 256` is an x86-64 measurement written as a
constant.

#### So the lock was three things

For an LP64 little-endian Linux target, and not for any other:

1. two lines of emitted text — **done**, ADR-0156;
2. one size constant that has to be a per-target maximum rather than a
   measurement of this one — **done**, ADR-0155;
3. a seed for the new host, which the retarget above supplies, and which
   nothing here automates.

It is not a rewrite of the layout rules, which is the opposite of what this
file predicted.

#### The three items that were done

**1. ~~Make `PAS_JUMP_SIZE` a per-target maximum.~~ Done (ADR-0155).** It is
1024, which clears every target in the aarch64 table above and glibc's powerpc64
besides, and both sites carry the measurements rather than a fresh guess. The
cost is paid only by a block that is a non-local `goto` target, and
`selfhost/compiler.pas` contains no `goto`, so the seed did not have to be
regenerated.

`tests/checks/target_sizes.sh` is the gate, and it asks the question one machine
cannot: for every target a compiler is installed for it compiles
`runtime/pasrt.c`, which is where the two `_Static_assert`s live — the real
file rather than a copy of the struct, which is ADR-0144's lesson. It reports
which targets it reached and skips with 77 when only the host is available. CI
installs the aarch64 and armhf cross compilers for it.

**And a complete aarch64 `pascalc` links.** Retarget `seed/pascalc.ll`'s two
header lines, assemble with `clang --target=aarch64-linux-gnu`, link against a
runtime built by `aarch64-linux-gnu-gcc`. It is the first compiler binary this
repository has produced for another architecture — and it has not been *run*,
because there is still no emulator here.

**2. ~~`--target=`.~~ Done (ADR-0156).** `pascalc --target=` selects which
triple and datalayout the module states, `tools/pascalcc --target=` hands it to
both halves, and `pascalcc --target=aarch64-linux-gnu -c hello.pas` produces an
aarch64 object on an x86-64 machine.

**It admits two targets and refuses the rest, and that is the decision.** A
target belongs on the list when this compiler's hand-written layout rules have
been shown to agree with LLVM's for it — the 4501 offsets above, for aarch64.
It does not hold for a 32-bit target, where `LlSize` says a pointer is 8, so
`--target=i686-linux-gnu` is refused rather than answered with a module whose
header and contents disagree.

**And the emitter's half was worth less than this entry assumed.** `clang`
overrides both lines with its own target's and warns about the triple only —
measured: a module carrying a 32-bit datalayout, compiled with
`--target=x86_64`, lays its structs out the 64-bit way silently. So on the
`pascalcc` path those lines are *advisory*, and ADR-0028's segfault was about
the datalayout being **absent** rather than wrong. What they are for is every
consumer that trusts the module instead — `llc` with no `-mtriple`, which is a
`ctest` case here, `opt`, and a reader.

**3. ~~A real aarch64 port, with CI.~~ Done (ADR-0157, ADR-0159).** Two halves,
because the question has two shapes.

*Compared, without leaving x86-64.* `target-layout` is a `ctest` case that reads
the frame type definitions out of what the built compiler emits — for
`selfhost/compiler.pas`, and for a probe carrying the types the compiler has no
frame slot of, an `i256` in a record first among them — and assembles them as
`ptrtoint getelementptr` constants once per admitted target. **Every offset it
emits, on every run** — the gate prints the count, and no document pins it,
because it moves with every declaration added to the compiler. The list of targets is parsed from the compiler's own `--target=`
refusal, so a third one is compared without the gate being edited. It fails when
a field moves and when the comparison reached nothing; admitting
`i686-linux-gnu` moves 86% of them.

*Run.* A CI job on GitHub's `ubuntu-24.04-arm` runner builds and runs the whole
suite natively — **639 of 639 on the first attempt**, from a seed whose two
header lines still say x86-64. `AFTERSCHOOL_PASCAL_TARGET=aarch64-linux-gnu` is what makes it
mean something — without it the compiler emits an x86-64 header for clang to
override *silently*, and the job would be green over an emission path never
taken. Two steps refuse a green run that asked nothing: `uname -m` must say
aarch64, and `TARGET_SIZES_REQUIRE` is mirrored so the target the host cannot
ask about itself is x86-64.

**It found a defect before it ran once.** Setting the variable over the existing
suite failed `lib_os`, whose command line was already exactly at the
twelve-argument program-parameter limit — see ADR-0158. Twelve was a bound that
truncated in silence and could not have done otherwise, an unbound
program-parameter being the only end-of-list there is; one *extra* parameter is
what makes going over detectable, and there are twenty-four now.

#### Twenty-five targets, and where the differences really are

**4. Anything that is not LP64 little-endian Linux.** A different and much
larger question — and **the layout half of it is much smaller than this entry
used to claim.** Measured on 2026-08-22 by running `target-layout`'s own
comparison against 25 targets instead of the two the compiler admits, all 4538
offsets each:

| target | offsets differing | |
| --- | --- | --- |
| aarch64, riscv64, powerpc64le, loongarch64, mips64el | 0 | LP64 little-endian |
| **powerpc64, mips64, aarch64_be, sparcv9** | **0** | LP64 **big-endian** |
| **x86_64-apple-darwin, arm64-apple-darwin** | **0** | Mach-O |
| **x86_64 and aarch64 windows-msvc, windows-gnu** | **0** | COFF |
| **s390x** | **13** of 4538 | LP64 big-endian, and the one exception |
| i686, arm, armeb, riscv32, mipsel, mips, powerpc, x32 | 3858–3904 | every 32-bit target |

So three of this entry's four bullets were wrong about *layout*, and only about
layout — the differences they name are real and are somewhere else:

- **big-endian is not a layout problem.** Four big-endian 64-bit targets are
  identical, which is what one would expect on reflection: endianness decides
  what a byte *means*, not where a field sits.
- **s390x is the exception, and it is ADR-0028's shape exactly.** It aligns
  `i256`, `i128` and `<2 x double>` to **8** where every other target here says
  16, so `LlAlign`'s `tySet := 16` — a comment that reads "LLVM aligns an i256
  to 16" — is a fact about most targets rather than all. Thirteen offsets, every
  one of them in a frame holding a `set` or a `complex`.
- **macOS and Windows agree about layout**, and the C library was measured too
  (ADR-0161). `bind` is *not* a POSIX assumption: §6.7.5.6's binding is `fopen`,
  and the file model is `fopen`, `fseek`, `ftell`, `fread`, `fwrite` and
  `tmpfile`, every one of them ISO C — as are the time procedures and `getenv`.
  **The runtime's whole departure from the standard is five names**, and they
  split the two platforms apart:

  | name | for | macOS | Windows CRT |
  | --- | --- | --- | --- |
  | `_setjmp`, `_longjmp` | §6.8.2.4 / §6.9.2.4's non-local goto | yes | yes |
  | `fmemopen` | ADR-0057's `readstr` | 10.13+ | **no** |
  | `open_memstream` | ADR-0057's `writestr` | 10.13+ | **no** |
  | `access` | §6.7.5.6's `binding` asking whether the file is there (ADR-0172) | yes | `_access` |

  So **macOS needs no runtime change at all** on this axis, and a **Windows**
  port is two hand-written `FILE*`-over-memory functions, one renamed call,
  plus `_Complex`, which MSVC lacks and §6.7.6.2's complex functions are
  written in. `runtime-isoc` keeps the list at five in both directions — and
  since ADR-0172 it compiles a copy with every non-ISO `#include` removed,
  because `__STRICT_ANSI__` hides what POSIX adds to an ISO header and not a
  header ISO C never had, which is how `<unistd.h>`'s `access` went through it.
- **32-bit is the real layout blocker, and it is every 32-bit target.** 85–86%
  of offsets move, because `LlSize` says a pointer is 8 by construction, and
  ADR-0129's `i64` count at the foreign boundary is a second, independent one.

**A caveat about the gate turned up in the same sweep and is now fixed.** Mach-O
puts a zero-valued global in `.zerofill` rather than emitting a directive with a
0 in it, and a 32-bit machine has no 64-bit directive, so an `i64` constant
arrives as two `.long`s. `target-layout` could read neither — loudly, with "N
constants were not folded to a number", rather than comparing something wrong,
but it meant no such target could have been admitted without teaching it first.
Both taught, and the split constant is reassembled from the datalayout's own
`e`/`E` rather than a guess: big-endian `powerpc-linux-gnu` yields exactly the
number little-endian `arm` and `mipsel` do, where a reversed word order gives
4.0 × 10¹⁶. All nine of the targets that defeated it parse 4538 of 4538 now.

## The text model

`doc/roadmap.md` carried one row unchanged through eleven records: *"the text
model — unstarted; `char` is a byte and nothing consults the locale. The
largest thing on this page that no record has touched, and the one a
'practical Pascal' would be judged on first."* It was settled in five
increments over one day, and the interesting parts are the two places the plan
was wrong.

**The choice the roadmap offered did not exist.** It said *a wider character
type **or** a text type distinct from §6.4.3.3's strings*. Widening `char`
stops `set of char` compiling — every set here is one 256-bit word (ADR-0028) —
which breaks ADR-0117's containment outright. So it was never two options, and
ADR-0189 records the rejected one rather than omitting it, because a reader
would otherwise wonder what became of it.

**What was decided** (ADR-0189): a text is a bounded buffer of well-formed
UTF-8 in normal form C whose elements are extended grapheme clusters, spelled
`utf8(n)` with the capacity in bytes. The load-bearing choice is normalising
where a value is *constructed* rather than where two are compared — it makes
`=` byte equality and canonical equivalence at once, so a text can be a
`pasmap` key and a comparison decodes nothing. That is not Swift's, and Swift
cannot afford it: its `String` is a reference-counted heap buffer, which is
the construct ADR-0151 says forces the aliasing decision.

**The runtime came first, and on purpose** (ADR-0190). This is the one part of
the language whose correctness is settled by a document written elsewhere:
`NormalizationTest.txt` and `GraphemeBreakTest.txt` state an input and the
answer, and were written by people with no interest in this compiler. Every
other oracle here compares the compiler against a reading taken here, which is
ADR-0072's blind spot. 20 034 normalisation cases, 766 segmentation cases and a
sweep of every code point the first does not list — 1 094 978 of them — passed
on the first run, so four mutations were made and each was caught by the
section it should be. The sharpest: 59 primary composites have a **starter** as
their second element, so the obvious streaming rule loses exactly those
compositions and passes everything else.

**Then the type** (ADR-0191), **joining and walking** (ADR-0192), and
**`PasUnicode`** (ADR-0193). The last is where the fallible conversion lives —
ill-formed bytes stop the program under AP 6.4.15.5, which is right for a
program's own literals and wrong for a line off a socket.

### What it cost, and what that argued for

**A clause written three days earlier was wrong, and only implementing it
showed that.** AP 6.4.15.5 refused an assignment from a `string`, routing every
conversion through a fallible function on the argument that invalid input from
the outside world is not an error in the program. True, and it does not reach
the conclusion: §6.4.6 admits assignments that can fail everywhere, and a store
outside a subrange has been an error since 1982. What made it visible was
writing the tests — under the clause as written a text could be filled from a
literal and from nothing else, so every test was a test about literals. AP
Annex E.11, and the first divergence there found by implementing a clause
rather than by auditing one. AP 5.6, invented on the first day so a design
could be written down before it was built, is what made amending it legitimate.

**Three defects of one shape, in three increments.** `IsMemory` asking
`IsVarString`, so the relational operators took a text for a register value and
emitted `icmp` on an aggregate; the code generator's comparison dispatch; and
`EmitAssign` choosing the string store with `IsStringType`, so a text target
fell through to a schema tuple-comparison and stopped the program. Each is a
**predicate** used as a guard, none is a case-statement, and so `kind-exhaustive`
— the gate that exists for exactly this class of mistake — saw none of them.
`predicate-kinds` (ADR-0194) is what those three argued for, and ADR-0195
closed the smaller gap beside it: AP 5.6's marker and the triage rows were one
truth in two places with one of them read.

**All three were found by writing a client**, not by a gate: two by probing
every operation against the new type by hand on the day it existed, the third
by writing the library the type exists to be used through. That is ADR-0182's
lesson a second time, and it is now a rule rather than an observation —
`doc/sop.md` §4a, *a feature with a surface needs a client, not a case*, with
the corollary that a feature's library belongs inside its own work rather than
after it.

**What is left of the text model**: case mapping, case folding and
grapheme-indexed slicing, each wanting a Unicode table the runtime does not
carry.

**Nothing is, two increments later**, and the second of them is the one worth
keeping. Case mapping and case folding landed together (ADR-0196) over two more
transcribed tables, and they are where this model's oracle story **ends**:
Unicode publishes a conformance file for normalisation and one for
segmentation and **none for casing**, so those routines rest on a transcription
where everything above them rests on a document written elsewhere. That is a
weaker footing than the rest of AP 6.4.15 has, and it is stated rather than
averaged in.

Grapheme-indexed slicing was then answered by **not offering the index**
(ADR-0199). The clause had refused an integer index from the first day, for
Swift's reason, and the open question was how to spell the operation that
wants one. The answer was to spell a **boundary**: `PasUnicode.ElementEnd`
says where one element ends, and a slice, a lockstep comparison of two texts
and a resumable walk are all compositions over it, written in the program that
pays for them. A feature can be finished by declining to add the thing that
looked missing, and this is the second time on this page — ADR-0187 retired an
address instead of modelling it, and this retires an index instead of hiding a
walk behind it.

---

## The oracles turned on themselves

Eight records between ADR-0183 and ADR-0207 are neither features nor
conformance work. Each checks something another oracle could not see, and
**five of them check a document rather than the compiler** — which is the
shape this period found and had not been looking for.

### The oracle that reads no output

ADR-0183. Every oracle here reads what a program **prints**: a golden its
output, a `.err` its diagnostics, `tests/dumps/` what the compiler wrote,
`difftest` two front ends' answers, the BSI catalogue a pass or a fail,
`verify/` a lowering against a model, `tests/spec/` a scenario's result.

A leak prints nothing.

Two records in one day turned on exactly that — ADR-0181's handle in an
unowned heap record, measured with `ulimit -n 64` and a counting loop, run
once, by hand; and ADR-0182's abandoned chain, 5.8 MB against 58 MB, taken the
same way. Both had been reachable for as long as the constructs existed, with
the suite green throughout, and after each fix nothing was left watching.

So the runtime tallies `pas_new` against `pas_dispose` and writes the balance
at exit when `$PASHEAP_BALANCE` is set — `--coverage`'s discipline, so a
program not being measured pays one `getenv`. Three things were decided with
it. **A count and not a byte total**: `dispose` is handed a pointer and no
size, a runtime header carrying one would move every address the compiler
computes, and the count is the exact question anyway — one `new` unmatched is
one variable nobody gave back, where a byte total or a peak-RSS reading is a
statistic that would miss a two-variable leak. **A nonzero balance is not an
error**, no standard obliging a program to dispose what it created, and 7 of
the 29 heap-using cases legitimately end with something outstanding — so it is
a catalogue failing in **both** directions, `verify/`'s rule for a `KNOWN_GAP`
that starts holding. And the whole argument for it is one number: making
`dispose` free nothing leaves **735 of 735 cases and 230 of 230 scenarios
green** and moves nineteen balances.

### A claim about a struct, judged by the real header

ADR-0185. ADR-0184's soundness rests on `RecordLayout` being C's rule, and that
record wrote down in the same breath what it left open: *that the declared
fields **are** `struct stat`'s, in that order and with that padding, is
unchecked, and uncheckable without a header parser.*

It is a worse claim than a signature in one specific way. A wrong signature is
usually wrong immediately and loudly; a wrong field list can be right for
eleven fields and wrong for the twelfth, with every field after the mistake
silently wrong. `struct stat` on glibc/x86-64 is 144 bytes with **two holes** —
four bytes after `st_gid`, twenty-four at the end — and a program that omits
the first gets a plausible number out of `st_size` that is really
`st_blksize`.

So the source states its claim in a **comment** — `{ @cstruct: … }`,
`{ @cfield: … }` — which costs the language nothing and has ADR-0166's
`{ @std:iso7185 }` as precedent; the compiler reports the offsets it computed,
through `--dump-layout`; and a C compiler holding the real header judges the
two. The pairing is by **order** and not by name: a missing annotation shifts
the rest and the count check fires, where name-matching would silently check a
subset and call it a pass.

**The second half of the record is the one that reached furthest.** A library
may not make such a claim at all, because `lib/` has to work where nobody here
can build — which then decided `PasFS.Info`, `PasDir`, `PasNet`, and the shape
of every module since.

### A catalogue that could only ever hold functions

ADR-0186, and it was found by the gate rather than by a reader, within minutes
of the code being written:

    runtime/pasrt.c:2681: error: variable has incomplete type 'struct stat'

ADR-0161 proves its five-name catalogue complete by a specific mechanism: strip
every non-ISO `#include` from a copy, compile what is left, harvest what the
compiler calls undeclared, then silence exactly those names and require the
rest to still compile. That works for a **function**, whose undeclared use is a
diagnostic. A *type* has no such behaviour — `struct stat` with `<sys/stat.h>`
stripped is an incomplete type, a hard error no flag silences and no catalogue
entry can excuse.

**So a POSIX dependency needing a type could never live in that file, however
well it was argued for** — not because it was rejected, but because the
mechanism that keeps the file honest cannot describe it. The constraint had
always been there and had never been met, because all four earlier non-ISO
dependencies happened to be functions.

The answer is a second translation unit, `runtime/pasrt_posix.c`, bounded by
its **headers** rather than by its names — *what does a port have to supply* is
answered better by `<sys/stat.h>` and `<unistd.h>` than by the members that
happen to be read today — required to be clean POSIX C11 under `-Werror`, and
required to contain nothing but `pasx_`, so a system without those headers
loses library routines and **not the language**.

### The register that was only ever appended to

ADR-0197. `doc/sop.md` §7 is the live list of what is not checked here, and its
own instruction is two sentences: add a row when a gate is declined, remove one
when it closes. **Only the first had ever been followed.** The register reached
57 rows over ninety-odd records with nobody reading it end to end — each change
adding the row its own work argued for and leaving the rest alone, which is
exactly the decay a blind-spot register exists to prevent, happening to the
register.

Four rows in 57 were stale, and **one had predicted its own violation**.
ADR-0111's string arena is released at the end of any statement that took
storage; which statements those are is a counter the emitter's producers bump;
and the row about it ended *a fifth would still have nothing looking for it*.
Three arrived at once with AP 6.4.15 — a text's join, its store, and the
operand of a comparison that is not already a text — and none was pinned by
anything. The sentence naming the hazard was in the tree, in the file whose job
is naming hazards, while the hazard happened.

**The failure mode is not carelessness about one row.** A row stating the
condition under which it closes has no reader at the moment that condition is
met, because the person who meets it is working on the feature and not on the
register. The remedy is a dated end-to-end read, which `docs-engineering` now
asks for — along with the sharper half of the same finding: a number quoted
from a gate is checked by running the gate and never by trusting the sentence.

### The question, not the answer

ADR-0198. `predicate-kinds` (ADR-0194) had written its own limit into its
record: it does not see a predicate's callers, and neither it nor
`predicate-callers` covers the middle — a call site asking the **wrong
predicate**, which is what all three of the text model's defects were.

The shape they share is sharper than that. In each one the guard asked a
predicate whose answer for the new kind is **right**: `IsMemory` asked
`IsVarString`, correctly false of a text, since §6.4.3.3.3's rules do not apply
to one; the code generator's comparison dispatch asked `IsStringOrChar`, and a
text is neither; `EmitAssign` selected the string store with `IsStringType`,
and `IsStringType 1 of 22` is a correct row. **No catalogue over answers can
see any of them, and `predicate-kinds` is satisfied by exactly the row that
hides the defect.** What was wrong was the *question*: each of those guards
means *does this take the string path?* and spells it *is this a string?*,
which were the same sentence until a second kind shared the representation.

So `--like OLD NEW` is a query and not a gate. It lists every predicate true of
the kind the new one resembles and false of the new one, with every call site
of each — for the text, three predicates and 42 call sites, with all three
defects among them. **The resemblance is a fact about why the kind was added,
and a person has to name it**; nothing here can derive it.

### Two sweeps of the triage, from opposite sides

ADR-0200 and ADR-0204. ADR-0106 made the clause denominator a triage —
`testable`, `structural`, `not-implemented` — with only the first entering the
coverage figure and the work queue, so a requirement filed `structural`
**disappears completely**: in no percentage, in no `pending.txt`, and nothing
ever asks for it again. An earlier audit had read about twenty of those rows by
hand and found four wrong, two of them sharing one copied reason string, and
§7 had carried the rest as unaudited ever since. ADR-0197's sweep of that
register is what brought the row back into view.

ADR-0200 read every one of them. ADR-0204 then read the mirror, which ADR-0200
had named and left open: a clause filed `testable` that states no requirement
sits in `pending.txt` for ever as work nobody can do — about 350 rows wide, and
a much weaker signal, since *states a requirement* cannot be read off the
presence of `shall`. **The weaker signal turned out to be the same signal read
the other way**: a `structural` row is wrong when its clause *does* say
`shall`, and a `testable` row is suspect when its clause *never* does.

### A mutation as a file

ADR-0207. `doc/sop.md`'s rule is that a green suite is not evidence and
evidence is a named case that fails without the change. Mutation is how that
gets demonstrated, it is asked for by §4 of the same document, and it has found
something every time it has been run here — ADR-0065's two mutants changed the
compiler rather than the tests.

**And it had never existed as anything but prose.** Two hundred records carry
sentences of the form *the mutation that moves the slice arm one line down
leaves all 625 cases green* — each a claim about the tree on the day it was
written, in a document that may not be edited. Nobody could re-run one. A
renamed test, moved code, or a later change that makes a mutation stop being
caught were all invisible.

The roadmap had carried it with two conditions attached, both learned the
expensive way: a wall-clock and output-size limit per mutant, because a looping
mutant filled a disk before anything noticed; and a restore that does not
preserve the mtime, or the mutant binary stays in the build tree and the next
control run reads as a broken feature. **A third arrived while ADR-0205 was
being written**, which is why this landed then rather than staying on the list.
A mutant was restored with a plain `cp` and a `touch` — correctly, by the rule
— and nothing rebuilt, so the next run measured the mutant, reported a property
of the new feature as false, and a golden was taken against it before the cause
was found. The rule was right and one step too short.

What it is, and the roadmap says so where a catalogue could be mistaken for a
measurement: **eleven mutations are files**, and two hundred records carry one
in their prose. *The mutation suite passes* means those eleven claims still
hold and nothing more.

## The compiler becomes three program-components

ADR-0233. The compiler had been one source file since ADR-0024, and the reason
given there — neither standard has an include mechanism, so a second file would
need its own copy of everything below it — stopped being true at ADR-0053 and
ADR-0079, which gave the language modules and §6.13's separately translated
program-components. `doc/roadmap.md` carried the split as a proposal across two
releases and version 3 did not take it.

It was taken the day after v3 shipped, and it is the one record in this tree
written **Proposed** — deliberately, because ADR-0001 asks for the record while
the alternatives are still live and the expensive half was a decision about the
seed that a release cannot take back. It was accepted two days later without a
word of the argument changing, and implemented the same day.

**Writing it before the work changed the proposal twice.** The roadmap's
headline reason was the fixed arrays: `poolMax` and `tokMax` are sized to hold
this compiler's own source, and components were supposed to make that
structural instead of watched. Measured, that is wrong — `--import` re-tokenises
the *entire* imported file, so a 2 011-line module with a four-line interface
costs 12 065 tokens as an import against 12 043 compiled, and the unit that
imports the rest pays for the whole tree again. Nor can it be recovered by
reading only the interface, which is the obvious fix: AP 6.7.3.10 instantiates a
generic in the *client's* translation, so the client needs bodies. What survives
is the second reason, the linking blind spot, and the record takes the split for
that alone. The second change was the shape: **three components and not the
four or five the roadmap sketched**, because three is the smallest number that
makes every build translate a module alone, translate a module that imports
another, and link the result — and Pascal writes the cut down for you, a call to
a later-defined routine requiring a `forward`, so the 66 forwards are the
complete list of back-edges in source order and all 66 are inside one stage.
The file order had been a topological order all along.

**Doing the work corrected the record twice**, and both are recorded in its
Status rather than in its argument, which stands as written.

- **The pool peak does fall**, by 27%: 693 850 of 1 000 000 for the one file,
  against 507 120 for the worst of the three translations — and the worst is
  ApFront's, not the program's. The record's "this change does not lower the
  peak" is right about the tokens (171 968 against 173 555, slightly worse, as
  predicted) and wrong about the pool. `buffer-headroom` measures all three now
  and reports the worst with the component that set it, which is a stronger
  question than it was asking.
- **The 179 globals did not have to be partitioned by hand.** §6.2.3.6 commences
  a supplying module before the program-block, so the 47 assignments that opened
  the main program body became three `to begin do` parts and each component
  initialises its own state. ApFront exports **one** variable where a straight
  partition would have exported 31, and 19 routines.

**What it cost was the gates, not the compiler.** The three sources compile,
link, and translate the old single file to byte-identical IR; the whole corpus
of 503 sources came through with identical IR *and* identical diagnostics; the
fixed point holds in every module. But eleven `ctest` cases failed at once, and
every one of them for the same reason: a gate that reads "the compiler's
source" or runs the compiler over it was reading or measuring a third of a
compiler. `tests/checks/components.py` is what they all go through now — one
place that says what the components are and in what order, read from
`selfhost/compiler.components`, which is an ordinary §6.13 component sidecar and
the same file CMake, `seed/refresh.sh`, `selfhost/irtest.sh` and the CI seed job
read.

Two of those failures were **silent**, and both are in `doc/sop.md` §7 now
because neither is peculiar to this change. `procedure-coverage` and
`line-coverage` degrade to a *skip* when the compiler cannot translate its own
source, so a real break in them reads as a missing `clang`. And an exported
routine's header appears **twice** — §6.11.1 puts it in the module-heading and
leaves the block repeating the name alone — so `foreign-reserved`'s regex,
anchored on `function ReservedForeignName`, matched an interface entry with no
body and reported that the predicate names no words it can read.

`line-coverage` needed more than a redirect. `--coverage` appends *line
numbers*, and three files whose line numbers overlap would have unioned
ApTypes' unreached statements with ApFront's reached ones, so each component now
gets a compiler in which only it is instrumented and the corpus is swept three
times.

**And the first fix was not enough, which is the part worth keeping.** The
ratchet then read 402 unreached where it had read 446, and that was written
down here as an improvement the split had bought — the corpus having grown by
two module-only translations. It had bought nothing. `--coverage` *appends*,
and the three sweeps shared one work directory, so sweep two read sweep one's
lines and every component looked better than it was. Given a directory apiece
the figure is **446**, exactly what it was before the split, and the ratchet
says so. The plausible explanation was the trap: a number that moves the right
way after a change invites a reason, and the reason was available.

**Three things it closed.** `doc/sop.md` §7's linking row is narrowed to the
combinations the compiler's own structure does not use, the build having become
the test. `seed/ddc.sh`'s diverse-double-compiling window closed for good: the
`v0.1.0` C++ compiler has no `--import`, so it cannot read this compiler at all,
and the check now says so and exits 0 — the row stays, because the gap it names
does. And ADR-0024's one-file half is superseded, twelve records after the
reason for it expired.

## A second processor answers the corpus

**2026-08-28** — ADR-0234, and the last of the roadmap's tasks. Open question
§2 had stood since before v3 in one sentence that never changed: *a second
answer, on programs that already exist*. It was taken because it was
shrinking. Nobody else implements this dialect, so a third-party differential
can only ever reach the part of the corpus that is still ordinary Pascal, and
that part gets smaller with every release.

**What it corrected before it ran.** The entry named the eight conforming
`lib/` modules first, as the portable half a second Extended Pascal processor
could run. None can: FPC's `-Mextendedpascal` does not implement §6.13's
modules at all, and `module m interface;` is *"Syntax error, BEGIN
expected"*. So the differential is over programs, and the estimate that had
stood for three releases was wrong about its own best target.

**What it found is nothing, and the shape of the nothing is the finding.**
Sixty-four of the 103 comparable cases differ byte for byte, which is almost
entirely padding — ISO 7185 §6.9.3.1 leaves the default TotalWidth to the
processor, and FPC writes an integer in eleven columns where this one writes
the fewest it can. Numbers compare by value and blanks are dropped; two
classes are counted rather than listed, an ISO error this compiler traps and
FPC runs past being one of them. Eleven disagreements survive that, six turn
on a clause, and **all six are decided here**.

**Three of the six corroborate a reading nothing in this tree could
challenge**, which is the whole of what a second processor buys and is worth
naming one by one:

- ADR-0073's mixed comment delimiters. §6.1.8 NOTE 1 lets a comment open with
  a brace and close with a star-paren; FPC ends one only at the matching
  delimiter, swallows a statement, and totals 27 where the clause gives 31.
  That record says in as many words that nothing here could have caught the
  original defect — a comment is invisible to every stage after the lexer, so
  the token dumps `difftest` compared would have agreed whatever a comment
  did. It has now been caught by something.
- `round`, which §6.6.6.3 defines by *equivalence* to `trunc(x+0.5)` rather
  than by a rounding mode. At 0.49999999999999994 the addition itself rounds
  to 1.0, so the clause's answer is 1. The test's own comment had predicted
  that "a processor emitting a round-half-away-from-zero instruction answers
  0" and had never met one. FPC answers 0.
- ADR-0076's longest-prefix number read, where FPC consumes the point that
  `-1.` leaves behind and then fails with its own runtime error.

**What it cannot do is the honest headline.** FPC refuses 141 of the 244 cases
with a golden, modules above all, and it can never reach `tests/dialect/` —
which is open question §1 and not something a gate discharges. The row it adds
to §1's table is a second *processor*, and it does not fill either of the two
that ADR-0232 emptied.

## The language server, and the bound it found before it ran

`doc/roadmap.md` has proposed a language server since before version 3, and it
has never been proposed as a feature. It is proposed as **the caller**: the
program large enough to say whether this dialect is pleasant to write in, which
is a question no gate here can answer and which ADR-0109's goal is actually
about. Every client of the language so far had been a library module or a test
case, and those are small, single-purpose, and written by whoever was already
holding the feature.

Three of its prerequisites had already been written, and each of the three
corrected the plan rather than fulfilling it. The chapter said there was no
JSON, and `PasJson` (ADR-0217) took two decisions the paragraph had guessed
wrong. It said `PasStream` frames the messages, and `PasStream` cannot — a body
is a byte count and a reader that has consumed a header line is holding the
first bytes of it, so `PasLsp` (ADR-0218) had to exist. It said `PasParse`
reads `file:line:col: error:` back off the compiler, and `PasParse` parses an
integer; `PasLspDiag` is what actually reads one. Three guesses in one
paragraph, and they share a shape that is worth carrying: **a module named by
what its name suggests is a guess, not a survey.**

Then the program was written, and it did not compile.

`lsp/pasls.pas` imports ten modules, and not one of them is a convenience:
`PasIO` needs `PasFS` for a path type, `PasJson` needs `PasContainer` for the
vector that makes a string value unbounded, `PasProcess` needs `PasStrVec`, and
the server itself needs `PasProcess` to invoke the compiler, `PasEnv` to find
it and the three protocol modules to speak. `maxImports` was **8**. The
compiler said so — *more than 8 --import arguments*, which is ADR-0110's rule
working exactly as designed, a limit reported rather than a list truncated —
and it was still a program that could not be built.

ADR-0158 had raised the *other* command-line bound two months earlier and said
in as many words that it did not revisit this one, because nothing had asked.
ADR-0114 had recorded the consequence a year before that: *a library of more
than eight modules cannot be used whole*. Both sentences were true and both had
sat there, because the largest thing in the tree had always been a test case,
and a test case with four components fits inside eight imports with room over.

The fix is ADR-0235 and its one idea is that **the two numbers are one number**.
An import costs two words of the command line, so a bound on imports is only
real as far as the argument list can express it; raising `maxImports` alone
would have moved the refusal to a message about arguments, which is a worse
diagnostic for the same failure. They are 32 and 72 now, the second derived
from the first in the comment that declares it, and the cost is literal — 48
more program-parameters and 48 more arms of one case-statement, because §6.5.1
gives a program-parameter a binding and not a subscript.

Two harnesses count in terms of the bound and had to move with it, and the
second is the interesting one: `tests/checks/coverage.py` fills a command line
to exactly `argMax` so that every arm of `Arg` is reached, and without that
edit 48 arms would have been reported unreached. That is `line-coverage`'s
ratchet doing precisely its job, and it would have been a true finding about a
change nobody had tested.

**The server itself does one thing** (ADR-0236): it publishes the compiler's
diagnostics for every document a client opens or changes. It holds documents by
URI, writes the one it was asked about to a scratch file — an editor's buffer
has never been saved, which is the whole reason a language server exists —
invokes `pascalc` through `PasProcess.Capture`, and reads the diagnostics back
with `PasLspDiag`. It lives in `lsp/` and not in `tests/`, because a test case
is compiled into a temporary directory and thrown away and a server has to be a
binary an editor can be pointed at; that is what makes the protocol's external
authority real rather than theoretical, which is the third of the roadmap's
three arguments for choosing a server over the text-mode IDE it proposed first.

It produced five findings on the day it was written, of which the bound is one.
`PasContainer`'s `MapKey` is 63 characters and a document URI is past that
before the file name starts, so the store is a vector searched linearly.
[Corrected on 2026-09-02: that reason was wrong. The map had been generic over
its key type since ADR-0254 and never had the bound; what had it was the
ready-made hash, and ADR-0290 widened congruity so the pair serves any
capacity. The store is a map now. This sentence is left as it was written
because this section is the findings **as they were recorded**.]
`JsonLine` is 255 and a URI is not a line. There is no `getpid` anywhere in
this tree and no `mkstemp`, so a scratch file cannot be given a name no other
process will choose — and `rewrite` on a name that cannot be created is a
run-time error that *stops the program*, with no way to ask beforehand, so a
server cannot survive a bad scratch path however carefully it is written. And
`binding(f).bound` is not a readiness test although it reads exactly like one:
E.16 binds a variable when the external name *exists*, so a file about to be
created reports false and one already written reports true, and the first
version of `WriteScratch` asked it and refused to write anything at all.

Four of those five are bounds, and every one of them was chosen by counting
what the largest thing in the tree needed at the time. That is the chapter's
argument, arriving in its first hour: the finding is never that the library is
weak, it is that nothing had yet asked it for anything the size of real work.

**Six records followed in the same week, and the five findings did not
survive them.** The server negotiated its position encoding (ADR-0237), so a
client offering `utf-8` gets the compiler's own columns and one that says
nothing gets the protocol's default with the conversion done — which is what
made the UTF-16 edge, named as the sharpest one in the idea before any of it
was written, an externally specified test rather than a reading. It learned to
find a file's **imports** by reading `.components`, this tree's own build
description, on the rule *take the entries before this file* (ADR-0238);
without that the compiler is handed a module alone and answers 21 171
diagnostics about names it was never shown. It drew an **outline**, and the
decision behind it outlived the method: `--dump-symbols` is the compiler
answering a tool's question in Pascal's own words, because the alternative was
a second reader of Pascal-shaped output living outside the compiler, which is
the shape two gates had already been moved off (ADR-0239). It gained a second
**transport** — the same binary answering MCP over stdio with two tools, one
of which is that outline (ADR-0241).

And the two library findings were closed by two records that are not the same
kind of thing. `binding(f)` gained a third field, `writable`, so a program may
ask whether it could create a file before `rewrite` stops it for trying (AP
6.4.3.4.7, ADR-0240) — a **language** change, and the demand for it turned out
not to be the server at all but `lib/pasfile.pas`, whose four exported writers
were procedures that could fail and could not say so, written long before this
chapter existed. Then `PasProcess` gained `ProcessId`, and the scratch name
carries it, so two servers sharing a `TMPDIR` no longer share a file
(ADR-0242) — a **library** change, and one that had to say what it was not:
§6.7.5.6 binds a file by *name*, so `mkstemp`'s exclusive creation could never
have survived being opened a second time to be written, and what a name can
carry is a number no other **live** process has.

That the one entry needed two records is the argument for having written it as
two halves. A single finding would have been closed by the language change,
and the shared scratch file would have gone with it.

### The language server's findings, as they were recorded

The section above narrates the first of these. This is the register itself,
moved out of `doc/roadmap.md` as each entry closed, each with what closing it
found. The ones still open stay in the roadmap, which is where the count of
both lives: it stood here as *fifteen of the twenty-one* while that page said
twenty-six and nine, and a number written down in four places is a number that
will disagree with itself. A finding recorded and left is a finding wasted,
which is what the register is for.

There is deliberate overlap with the prose above: that is the story of the
first week, and these are the entries in the words they were written in, which
is how a reader can tell an estimate from an outcome.

The first two came from the framing alone, before a single protocol message
had been dispatched. The next two came from the diagnostics, before a server
existed to send one. **Everything after that came from the program itself**,
and the first of those is the one worth reading before the others: it is a
limit that looked generous beside a test case and turned out not to be a limit
a *program* could live inside, and it had to be fixed before the server could
be compiled at all.

The shape of the whole list is the argument for the chapter. **Five of them
are bounds** — 8 imports, 24 arguments, a 63-character key, a
255-character line, a 16 384-byte capture — and every one of them was chosen by
counting what the largest thing in the tree needed at the time. The largest
thing in the tree was a test case. One is not a gap at all: the protocol asked
the text model a question it had been designed to refuse, and the answer was
already exported. One came from pointing the finished program at the
repository it was written in, which is not a thing the earlier ones had needed
— and two more came from asking the compiler a question no gate had ever asked
it. **One pair is worth reading last**: one of them changed the language and
the demand for it turned out not to be this program at all but a library
module written a year of increments earlier, whose five writers could fail and
could not say so. A finding this chapter produced was already true everywhere
else.

**And the last six are all about what the compiler had never been asked.**
Two are things it did not keep — where a symbol was declared, and where a
field-identifier is — each thrown away by code that had the answer in its hand
and no reason to hold it. One is a fact it *did* keep, for a diagnostic, and
that answered a second question with nothing added but a file index. One is a
fact nothing had ever wanted, because the thing it describes is found by
spelling. One needed no new fact at all: the first of the four had already
added it, for something else. The last is not a demand on the language at all:
it is a defect this program shipped and an oracle caught, and it is here
because of *which* oracle.

**One entry took two records to close and they are not the same kind of
thing.** *A program cannot make a temporary file, and cannot survive failing
to* was written as two halves; the second was a language question and became
AP 6.4.3.4.7 (ADR-0240), the first was a library one and became
`PasProcess.ProcessId` (ADR-0242). Splitting it when it was recorded is what
made that visible — a single entry would have been closed by the language
change and the sharing of one scratch file between two servers would have gone
with it, unfixed and unrecorded.

- ~~**There is no empty substring**~~ — **answered, and it is the first
  finding this chapter produced that changed the language** (AP 6.5.6,
  ADR-0219). §6.5.6: *"it shall be an error if … the value of the first
  index-expression is greater than the value of the second"*. So
  `s[1..length(s) - 1]`, the ordinary way to drop a last character, **traps on
  a string of one** — and the header line that ends a frame's headers is
  exactly one character, a bare carriage return. This entry closed with
  *"whether the dialect should have `s[i..i-1] = ''` is undecided and wants a
  second sighting; one site is an anecdote."*

  **The second sighting arrived the next day, and it had already shipped.**
  `lib/dialect/pasparse.pas`'s blank trim is the same shape, written a week
  earlier, and `ParseInt(' ')` stopped the program where it should have
  reported a syntax error — through every gate, because no test passed a string
  that trims down to exactly one character. Three sites in the tree, three
  different treatments: `pastext.pas` builds its result a character at a time
  and never takes a substring, `paslsp.pas` writes the guard out, `pasparse.pas`
  gets it wrong. This language now admits `s[i..i-1]` and still refuses
  `s[4..2]`, which cost one flag on one runtime check — a flag ADR-0232 then
  removed, there being no mode left that keeps §6.5.6's trap for the empty
  case. **The argument was in the tree already** — §6.7.6.7's
  `substr(s, i, 0)` is the null-string and ADR-0125's `a[i..i-1]` is the empty
  slice, so `s[i..i-1]` was the only bracketed range that could not be empty.

- **The chapter named a module by what its name suggests, for the third
  time.** It says `PasParse` reads `file:line:col: error:` back off the
  compiler. `PasParse` parses an **integer** and nothing else — ADR-0120's
  result shape applied to one parse — and reads no diagnostic. That is the
  third prerequisite this chapter guessed wrong about its own plan, after the
  JSON row and after `PasStream` framing a message it cannot frame, and the
  three share a shape worth naming: **a module named by what its name suggests
  is a guess, not a survey.** `lib/dialect/paslspdiag.pas` is the module that
  actually reads them, and it landed with the conversion the protocol needs —
  LSP counts lines and characters from zero where `ErrorAt` counts from one.

- **The first realistic payload found a defect in `PasJson`.**
  `JsonCharsInto` asks whether a rendered document fits the *caller's*
  capacity and then built the answer through a 255-character local, so a
  document between 256 and the caller's capacity passed the guard and stopped
  the program. A `publishDiagnostics` notification carrying two diagnostics is
  321 characters. Nothing had rendered one that long — every case in
  `tests/dialect/lib_json.pas` fits a line — which is why it was invisible.
  **This is the chapter's argument in miniature and it arrived before the
  server did**: the finding is not that the library is weak but that nothing
  had asked it for anything the size of real work.

- ~~**The command line cannot express a program with ten modules**~~ —
  **answered, and it is the finding that had to be answered first** (ADR-0235).
  `maxImports` was 8 and `argMax` was 24. The server's import chain is ten
  modules and none is optional: `PasIO` needs `PasFS`, `PasJson` needs
  `PasContainer`, `PasProcess` needs `PasStrVec`, and the server needs
  `PasProcess`, `PasEnv` and the three protocol modules. The compiler answered
  *"more than 8 --import arguments"* — ADR-0110's rule working exactly as
  designed, reporting rather than truncating — and it was still a program that
  could not be built.

  **The two numbers are one number**, which is the part worth carrying
  forward: an import costs two words of the command line, so a bound on
  imports is only real as far as the argument list can express it. They are
  now 32 and 72, and the second is *derived* from the first in the comment
  that declares it. ADR-0114 recorded *"a library of more than eight modules
  cannot be used whole"* as a limitation of the library; there are 25 modules
  in `lib/` and that sentence is struck.

- ~~**A program cannot make a temporary file, and cannot survive failing to.**~~
  **Both halves answered.** There was no `getpid` anywhere in this tree, no
  `mkstemp`, and nothing in `PasFS` that answered a temporary name, so the
  scratch path was one fixed name under `TMPDIR` and two servers sharing a
  `TMPDIR` shared the file. Worse: `rewrite` on a bound name that cannot be
  created is a run-time error and *stops the program*, and neither standard
  gives a program a way to ask beforehand — so a server could not survive a bad
  scratch path however carefully it was written.

  ~~The first half~~ — **answered, and it stayed a library question** (ADR-0242).
  `PasProcess` exports `ProcessId`, the server's default name carries it, and
  two servers no longer share a file. It is *not* `mkstemp`'s guarantee and
  could not be: §6.7.5.6 binds by **name**, so a file created exclusively would
  have to be opened a second time to be written and the exclusivity is given up
  at that moment. What a name can carry is a number no other **live** process
  has. `getpid` is bound by the module rather than by the runtime because
  `pid_t` is a *scalar* typedef and ADR-0186's rule reaches structs — the one
  case that distinction has been tested on. The primitive landed and the *name*
  did not: there is one caller, and ADR-0116 says one site is an anecdote.

  ~~**The residue**~~ — **answered too, and by ISO C** (ADR-0243).
  `PasFS.TemporaryPath(dir, prefix)` answers a path that names nothing else
  **with the file created**, which is what makes it unique against a process
  that has already exited as well as against one running now; the caller
  removes it. `mkstemp` is still absent and stays absent: it takes a `char *`
  it *modifies*, and the only mutable storage this FFI lends is a slice, which
  supplies a pointer **and** a count — so binding a one-argument C function
  through it would be a claim about an ABI. C11 7.21.5.3's exclusive `fopen`
  mode is the mechanism instead, tried in a loop, and the non-ISO-C catalogue
  stays at five names where `mkstemp` would have brought `close` and made it
  seven.

  **The two records answer different questions** and the language server is the
  reason to say so: `ProcessId` gives a **predictable** name and `TemporaryPath`
  a **unique** one. A server started a thousand times should leave one file in
  `TMPDIR` and not a thousand, and a predictable name is what makes the scratch
  source findable when the server and the editor disagree — so the server keeps
  the first and is not a caller of the second.

  ~~That second half~~ — **answered, and it is the second finding this chapter
  produced that changed the language** (AP 6.4.3.4.7, ADR-0240). §6.7.5.6's
  NOTE 2 offers `bound` to a program about to *read* and the write side had
  nothing, so `BindingType` gained a third field, `writable`. It needed **no
  spelling**: §6.4.3.4 NOTE 7 says *"a processor may provide additional fields
  as an extension"*, so the standard named the extension point and `binding`
  is a required function that already returns a record. That is the second
  feature in this dialect to need no position at all, after ADR-0184's, and
  the first where a standard put the door there.

  **The demand was not the server.** It was `lib/pasfile.pas`, whose four
  exported writers were *procedures* — routines that could not report failure
  and could fail, killing their caller — and whose `CopyFile` returned a
  boolean that covered only the source. Five sites in one module, written long
  before this chapter existed and never noticed, because nothing had pointed
  any of them at a path it could not write. One site is an anecdote and this
  was six.

- ~~**The protocol counts in a unit nothing here answers in**~~ — **answered,
  and the text model needed no change at all** (ADR-0237). This chapter had
  said the conversion was one nothing in the tree could do, because AP 6.4.15
  refuses an integer index and `PasUnicode` answers in scalar values. The
  refusal stands and the count did not need it: a scalar below U+10000 is one
  UTF-16 code unit and one at or above it is two, so `Utf16Column` is a walk
  over `NextScalar`. It is the fourth estimate on this page to be wrong in the
  useful direction, after the three the FFI increments produced — *a decision
  that looks like it needs a model may need it for only part of its surface.*

  **What was genuinely missing was the negotiation.** 3.17 lets a client offer
  `positionEncodings`, and under `utf-8` the compiler's column is already the
  protocol's — so a server that converted unconditionally would be *introducing*
  the error it was written to remove. Two sessions in `lsp/sessions/` differ in
  nothing but the offer and in nothing but that number.

- ~~**The server works on a single-file program and on nothing in this
  repository**~~ — **answered by reading the build description** (ADR-0238).
  The compiler is handed one file and a program is several, so a module
  compiled alone fails on every name it imports: 48 diagnostics for
  `lib/dialect/pasjson.pas`, two real and 46 cascade — and **21 171** for
  `selfhost/apfront.pas`, which is not a partial answer but noise the length of
  the file. Every module in `lib/` and every source in `selfhost/` behaved the
  same way, and it was invisible for exactly as long as the server was only
  ever pointed at documents this chapter wrote itself.

  The answer is `.components`, which is this tree's build description and is
  already read by five other things — `compile_commands.json` is what clangd
  reads and `go.mod` is what gopls reads, and none of them makes the compiler
  resolve names. **One rule covers every shape: take the entries before this
  file.** A sidecar beside the file and named after it gives all of them,
  because it does not name the file; `selfhost/compiler.components` names
  `compiler.pas` and gives the two before it, which is the case a second rule
  would have been written for.

  ~~**What this does not close is `README.md`'s gap**~~ — **closed**
  (ADR-0244), and by the compiler, exactly where this entry said it belonged.
  An `import` naming an interface no `--import` supplied is looked for as
  `<directory>/<name>.pas` in the source's own directory, then in each
  `--import-path`, then in each entry of `AFTERSCHOOL_PASCAL_PATH`; the search
  is transitive and post-order, so the list it produces is the activation order
  §6.2.3.6 requires. `--dump-imports` is the other half — resolution finds an
  *interface* and something still has to translate the file and link it, and
  that something is `tools/pascalcc`, which is now the second caller of a dump
  flag after the language server.

  **The install location went with it.** `cmake --install` lays out
  `<prefix>/bin`, `<prefix>/lib` and `<prefix>/lib/afterschool`; `pascalcc`
  looks for its compiler and its runtime beside itself before it looks in a
  build tree, and adds the installed library to the search path only when the
  variable says nothing. `install-layout` is the gate and is the first oracle
  here that runs an *installed* compiler — every other harness drives one out
  of the build tree, which is exactly the configuration an installed copy does
  not have.

  The server keeps reading `.components`, and that is not redundant: it needs
  the imports of a file it is *not* compiling as a program, for a document that
  may not parse, and the sidecar answers without the compiler having to.

- ~~**The whole-output buffer was sized for diagnostics**~~ — **answered by
  not having one** (ADR-0239). `CaptureMax` is 16 384 and the outline of
  `selfhost/apfront.pas` is **51 192 bytes**, so `documentSymbol` on the
  largest thing in this tree would have stopped a third of the way through and
  said nothing about it — `Capture` reads and drops the tail, which is right
  for a diagnostic and wrong for an answer whose length is proportional to the
  file. The fifth bound on this page, and the first that was *removed* rather
  than raised: an outline is a **list of lines**, so `CaptureLines` collects it
  on the heap and what is left is a per-line bound against six short fields.
  The diagnostics path keeps `Capture` deliberately — a compilation is long
  only when the file is badly broken, where an outline is long whenever the
  file is.

- ~~**The driver had never been handed a dump**~~ — **answered** (ADR-0239),
  and it is the entry on this page that failed most quietly. `PASLS_COMPILER`
  may name `tools/pascalcc` as readily as `pascalc` — `lsp/README.md` said so —
  and `pascalcc` knew no `--dump-` flag at all: it wrote `pascalcc: unknown
  option '--dump-symbols'` to *standard error*, which the server was not
  reading, and answered an empty outline with no complaint anywhere. Nothing in
  the tree had ever run a dump through the driver, because every dump case is
  handed `pascalc` and every ordinary case wants a program. It passes them
  through now and `producttest.sh` asks; the general shape is that **the two
  halves of this compiler have a seam and only one side of it is swept**.

- **The compiler did not know where a symbol was declared** — answered, and
  it is the finding that made go-to-definition possible at all (ADR-0246).
  Every applied occurrence in this compiler resolves to a `symbol`, and a
  `symbol` could not say where it came from. `Declare` is *handed* a line and
  a column — for its own "is already declared in this block" message — and
  threw them away, at the one site every named declaration passes through.

  Nothing had ever wanted them, and the reason is worth keeping: a diagnostic
  reports where the **mistake** is, and for thirty-six thousand lines of
  compiler that was the only question anyone asked about a position. A tool
  asks the opposite one. Three integers on the record and three lines at the
  site were the whole of it, which is what makes it a finding rather than a
  feature: the fact was already in the hand of the code that discarded it, and
  what it cost to keep was nothing.

- **A schema's body is read where it was not written** — answered
  (ADR-0249), and it is the one of these four that was not a missing fact at
  all. §6.4.7 keeps a schema's *syntax* and resolves that body again per
  distinct tuple, at the place the type is **written** — so the compiler reads
  line 35 while `curFile`, the one thing it knows about which source it is
  checking, names the file line 43 is in. For a schema out of `lib/` those are
  two files, and a position reported from there would send a reader to
  whatever happens to sit at that line and column of the wrong document.

  What closed it was already in the tree: a schema is a symbol, and a symbol
  carries a file since the first of these four. So the question becomes *is
  the schema this document's* rather than *is Sema checking this document*,
  and the fact answering it was created three increments earlier for naming a
  defining-point in an import. **The negative half is what needed a case
  written**: a rule that silently reports nothing and one that correctly
  reports nothing are indistinguishable from outside, so a component's schema
  is produced on every run of a dump case and the golden shows no line from
  its body.

- **An interface was registered by spelling and by nothing else** — answered
  (ADR-0248). `ifaceRec` held a name, an owner and its constituents, and never
  where the `export` clause was written: every question the compiler asks
  about an interface is answered by walking a list and comparing the string
  pool, so no position had ever been needed. Three integers on that record
  closed it, at the one site §6.11.1 puts a defining-point.

  **What it changed is which occurrence matters, and the estimate was wrong
  in the useful direction again.** The row this closes was written about
  §6.11.3's `M.x` — the qualifier hovered and jumped nowhere — and that form
  is one most programs never write. The occurrence a reader actually points at
  is `import Middle;`, which is where a module says where it gets things from,
  and *no code path had taken it anywhere near the reporter*. The gap was
  larger than the row describing it, which is the fifth estimate on this page
  to be wrong that way.

- **A record field resolves to nothing a report could name** — answered
  (ADR-0247), and it is the finding this chapter produced by *reading its own
  output*. `--dump-uses` answered `v.cap` and not `r.x`: a schema's
  discriminant is a symbol and a field is a `fieldPtr`, §6.4.3.3 making a
  record a region with a defining-point in it while nothing about a field is
  ever looked up in a scope. The two look identical in the source, the
  asymmetry was visible in the golden, and it was explained nowhere in it.

  It cost **one integer**. `fieldRec` was already keeping `line` and `col` for
  a diagnostic (ADR-0045); what was missing is which *file*, a record declared
  in an imported module having fields whose positions are that module's. That
  is the same shape as the symbol finding below and the opposite conclusion:
  there the fact was thrown away, here it was kept for one purpose and served
  another untouched. **A program that uses records writes more field
  selections than anything else**, so what looked like a corner was most of a
  file.

- **The parse tree records a field-designator's `.` and not its name** —
  answered, and it is the other half of the extent finding above. A field node
  is built when the parser sees the point and before it reads the identifier,
  so the node's own line and column are the point's; whitespace is legal on
  either side of one, so `col + 1` is a guess and not a derivation. `nkField`
  carries `fdLine`/`fdCol` now, which is what lets a schema's discriminant be
  reported at the name a reader is pointing at. The declaration end is still
  not recorded and that half stays open.

- **A leak with every golden green, and only one oracle here could see it**
  (ADR-0246). Both new methods began by making a JSON `null` and replacing it
  where there was an answer, which abandoned one node per successful request —
  thirteen over two sessions. Every reply was byte-for-byte correct, because
  what leaked was a value nobody printed.

  It is not a demand on the language and it is here for **which** oracle
  caught it: `heap-balance` is the one gate in this tree that reads no output
  at all (ADR-0183), written after two leaks had each been found by a
  measurement taken once, by hand, and by nothing afterwards. This is the
  first program to exercise it since, and it failed on the first run. The
  chapter's own argument, met from the other side: the value of a client large
  enough to get tired inside is not only what it demands but what it trips.

- **A declaration answered nothing, where every editor answers one** —
  answered (ADR-0250), and it is the entry that came from *using* the feature
  rather than from writing it. `--dump-uses` reports 6.2.2.1's **applied**
  occurrences, so standing on `Total` in `var Total: Counter` and asking
  either question got silence. Hover there is the most ordinary question a
  reader has, and it is the one this could not answer.

  A declaration is now an occurrence of itself, reported from the **scope** —
  every name a block declares is on the chain at that block's depth, so one
  walk covers eight declaration kinds and needs nothing when a ninth arrives.
  It runs *after* the declarations are checked rather than at `Declare`,
  because a variable has no type until its caller sets one and the hover would
  have shown a question mark.

  **And it is not a no-op everywhere.** 6.6.1's `forward` and 6.11.1's
  module-heading declare a routine whose body arrives later, and 6.2.2.12
  makes the two the same routine — so the name written at the implementation
  resolves to the interface that promised it. That is the navigation C readers
  use go-to-definition for, and this language had no way to ask for it.

  **It shipped a defect and a session caught it.** The first version asked
  which file *Sema* was checking, which is right for an applied occurrence and
  wrong for a defining one: 6.11.3 binds an imported constituent into the
  importing block's scope, so the walk found `Doubled` from `middle.pas` and
  reported its position as an occurrence in `client.pas`. The server sliced
  that document there and a hover over `Doubled` came back as **`(Double`** —
  a name not in the file. The golden moved and the moved value was visibly
  wrong; nothing about it was caught by reasoning.

- **No dump case had ever compiled a module** — answered (ADR-0251), and it
  is the finding that came from writing a *test* rather than from writing or
  using the feature. Every `--dump-uses` case in `tests/dumps/` was a program,
  so three answers were covered by a language-server session and by nothing
  else: an interface's own export-part, a module's own declarations, and the
  completion of a heading resolving back to it — which is the one answer no
  program can produce, a program having no heading to complete.

  Writing the case found two defects in the increment before it. §6.11.1
  registers an interface in a table beside the scope rather than in it, so the
  walk over block declarations could not see one at all. And a module-heading
  declares its routines in a loop *after* `CheckDeclarations`, so a walk taken
  where an ordinary block takes one found every constant, type and variable
  and no procedure. Both were invisible to reasoning and immediate in a
  golden.

**Seven entries moved here together on 2026-09-02**, the day the roadmap's
rule became *what is done goes to history*. Six had been kept in place after
closing, on the argument that what each was worth reading for was what closing
it found; that is still what they are worth reading for, and it reads the same
here. The seventh is the third of the usability findings, closed in both its
halves within four days of being written. They are in the words they were
written in, strikethrough and all.

- **A program may not mix `writeln` with a descriptor write.** `output` is
  buffered and `PasIO.WriteText` is not, so the two appear in an order that
  depends on when the buffer flushes, and neither standard gives a program a
  `flush`. A program that speaks a descriptor protocol has to say *everything*
  that way, including its own diagnostics — which is what
  `tests/dialect/lib_lsp.pas` does and says at the top. Nothing is wrong here;
  it is a thing a writer has to know and nothing tells them.

  **The server closed this one by construction rather than by care.**
  `lsp/pasls.pas` declares *no program-parameters at all*, and §6.9.1 makes the
  default file of `write` a program-parameter — so a stray `writeln` in it is a
  compile-time error and not a corrupted frame. The discipline is enforced by
  the compiler; the finding stands for every other program that speaks a
  descriptor protocol.

- ~~**`PasContainer`'s map cannot key on a URI.**~~ **Closed by ADR-0290, and
  the sentence was wrong.** It read: *`MapKey` is 63 characters and
  `file:///home/someone/projects/afterschool_pascal/selfhost/apfront.pas` is
  69, so the document store is a vector searched linearly* — and the map has
  been generic over its key type since ADR-0254. A probe keys one on a
  200-character string and stores the 69-character URI in it, so the map could
  always have held the document store and the entry named a limitation the
  library did not have.

  **What was true is one layer down.** `StrHash` and `StrEq` — the ready-made
  pair — were declared over `MapKey`, and ISO/IEC 10206:1991 §6.7.3.6 makes a
  procedural parameter's congruity exact, so a map keyed on any other capacity
  got the pair refused and its client wrote eight lines of its own. AP 6.7.3.6
  lets a schematic `string` value formal stand where a produced string type is
  written, the pair is schematic now, and a client writes nothing.

  **This is the second entry in this chapter to be corrected by a probe rather
  than by a test**, after the `T ! E` one above, and both corrections say the
  same thing: *the language could do it and the convenience layer could not*.
  The first illustration here was 44 characters and did not fit the claim; the
  claim itself then turned out not to fit the library. Nothing in this tree
  can check a sentence, which is why writing the probe is the only method
  there is — and it is cheap, and it was not done for eleven increments.

  `lsp/pasls.pas` was converted the same day, and the conversion is the last
  word on the entry: it **removed** code rather than adding it — `Store` went
  from two paths to one, and `Forget` from closing a gap in the vector by hand
  to deleting a key — and the nine `at: integer` declarations it left behind
  were named by the unused-variable warning rather than by a reader. Nothing
  got faster and nothing was meant to: an editor holds a handful of documents.
  The two mutations are what the change rests on, and they fail differently —
  a `Forget` that does not delete is a **double free** in three sessions, the
  text having been released while the entry stayed; a shutdown walk that frees
  nothing moves `heap_balance.txt`.

- ~~**`JsonLine` is 255 characters and a URI is not a line.**~~ **Closed by
  ADR-0291, and it was recorded as a bound that had not yet cost anything.** It
  had, three times over, and the entry named the least of them.

  What it said is that the server holds its document key at 255 *deliberately*,
  `DiagPublish` taking one, so a URI the server could hold and that module could
  not would be a truncation at the boundary instead of a refusal at the door.
  True, and two floors below it the same bound was doing worse. **The library
  did not truncate, it stopped the program** — §6.4.6 c)'s error at the call,
  `a string of length 300 does not fit a capacity of 255`. **The server answered
  go-to-definition with a URI naming a different file**, `PathToUri` appending
  under a `< LineMax` test and simply stopping, which a client resolves with
  nothing on either stream to say it was cut. **And the compiler had the same
  bound and it was the sharpest**: `nameStr` was 255 and its own comment read
  *"a file name or a command-line argument"*, so `pascalc` at a 310-character
  path stopped at `pas_str_fits` **naming no file**. A checkout a few
  directories deeper than usual is the whole of what it takes.

  Two comments in this tree had walked up to it and stopped. `compiler.pas`
  says of `envMax` that *"nameStr … is 255 and is the bound on one path"* and
  then never asks whether 255 is right for one path; `pasls.pas` says of
  `ItemMax` that four of this program's findings are *"bounds chosen by
  counting what the largest thing in the tree needed at the time"*. **A comment
  that names a hazard is not a check**, and the number sitting next to it was
  wrong in both.

  It closed as three schematic-parameter changes, one derived constant, one new
  gate — `long-path`, because no test case can choose its own path — and an
  **out-of-cycle reseed**: `BindingType`'s capacity for a program is decided by
  the compiler translating it, so the shipped `pascalc` went on reading its own
  arguments into a 255-character field however the source read. That is
  ADR-0126's sentence about the seed, met for a value rather than a buffer.

- ~~**`PasStrVec.ItemMax` is 255 and a dump line carrying a path crosses it.**~~
  **Closed by ADR-0292, and the design it asked for was not needed.** The
  entry proposed a container generic over its element's capacity, on the
  reading that the server needed one vector to hold both 40 821 short rows and
  a handful of paths. It needed **two**, sized by the two different facts, and
  the thing that had to be replaced was not the container at all.

  It was the *reader*. `PasProcess.CaptureLines` cuts every line at `ItemMax`
  — its contract says so, and the contract is right for the 40 000 rows it was
  reached for — and the server used it for a dump one of whose rows carries an
  absolute path. **Pascal's own `readln` reads a line into a string variable of
  whatever capacity the reader declared**, so the fix was to write the dump to
  a file and read it with the language rather than with the library: no
  container, no generic, no new capability, and one bound fewer than before.

  **The probe that found this took two minutes and the entry had proposed a
  language feature.** That is the third time in this chapter — after `T ! E`
  and the map — and all three corrections say the same thing a different way:
  the reach for a library convenience is what introduced the bound, and the
  language underneath it had none.

  The warning it left — `readln`'s silent truncation, and `PasFile.ReadLine` still handing back 255 characters — is open and stays in the roadmap.

- **The compiler does not keep the spelling a programmer wrote.** Not a
  defect and not a gap — the lexer case-folds an identifier and the string pool
  holds one copy, which is the whole of what makes `CaseTest` and `casetest`
  one name. It is here because an outline is the first thing that ever wanted
  the other spelling back, and the answer shows what a compiler's report is
  for: `--dump-symbols` gives a position and a length beside the folded name,
  and the caller holding the document slices the written spelling out of its
  own copy. Retaining both in the pool would have moved the one array whose
  headroom this tree measures (ADR-0126) for a display string. **The parse tree
  has no *extent* either** — a declaration's start was recorded and its end was
  not, which is why `range` and `selectionRange` were both the name. **That is
  closed** (ADR-0253): `ParseBlock` records the position past its closing
  `end`, `--dump-symbols` writes it, and a procedure's range now reaches its
  `end` where its `selectionRange` stays on the name. **And so is the other
  half** (ADR-0258): a statement carries its own extent, `--dump-stmts`
  reports it, and the server answers `foldingRange` and `selectionRange` from
  it — so expanding a selection steps outward through nested statements
  instead of jumping to the declaration.

  The answer did **not** have the same shape, which is the part worth keeping.
  A block ends at the token *past* its `end`, and that is right because the
  token there is the `;` or `.` immediately after it. A statement is followed
  by `;`, `end`, `else`, `until` or `otherwise`, routinely lines later and
  with comments between — and a comment is not a token, so the same convention
  would swallow whatever a reader wrote after the statement. A statement had
  to end at its own last token, and the token record could not say where that
  was: `len` is a length in the string *pool*, zero for most tokens and
  different from the source length for a literal. The token gained an end
  column before a statement could have an extent. Both wrong answers are
  staged as mutations and each is caught twice.

- ~~**`binding(f).bound` is not a readiness test, and reads exactly like one.**~~
  **Closed by ADR-0240 — eight hours after this entry was written, and the
  entry never said so.** The trap it describes is real and unchanged:
  `doc/implementation-defined.md` E.16 binds a variable when the external name
  *exists*, so a file about to be created reports `false` and one already
  written reports `true`, which is the opposite of what a "can I write here?"
  check wants in both directions. The first `WriteScratch` asked it and
  refused to write anything at all.

  What the entry went on to say — *nothing else does either, which is why it
  survived to be met by the first program that needed it* — stopped being true
  the same afternoon. AP 6.4.3.4.7 gives `BindingType` a third field,
  `writable`, which is the question `bound` reads like and is not, and both
  `lib/pasfile.pas` and `lsp/pasls.pas` ask it where they mean the write side.
  §6.4.3.4 NOTE 7 admits the extension, so it needed no spelling.

  **The finding here is about the register and not the language.** This entry
  was written at 04:55 and the record answering it landed at 13:22 on the same
  day, and nothing linked them for four days — long enough for the entry to be
  read three times as an open question. A chapter that says *a finding recorded
  and left is a finding wasted* has to mean a finding left **unlinked** too:
  what stays worth knowing is the trap, which no fix removes, and a reader
  needed to be told in the same paragraph that the answer exists.

- **A comment in the client is the third finding, and both halves of it were
  wrong within four days.** It read: `MapKey` is 63 characters, so the document
  store is a vector searched linearly; `JsonLine` is 255, so a URI is held as a
  line — and the *reason* they are tolerable is the same reason `…Or` is, the
  program being small enough that linear search and a per-type helper cost
  nothing.

  Neither was tolerable and neither was about size. The first was not a bound
  at all (ADR-0290): the map had been generic over its key since ADR-0254 and
  the refusal belonged to the ready-made hash, and the store is a map now with
  *less* code than the vector had. The second was three silent defects
  (ADR-0291, ADR-0292), one of which answered go-to-definition with a location
  in a file nobody named. **They were tolerable because nobody had run the
  program from a deep enough directory**, which is a different sentence
  entirely and not an ergonomic one.

  The entry is kept because that is the finding now. An ergonomic pass asks
  *what was unpleasant*, and unpleasantness is judged against the program you
  have; a bound nothing has met yet reads as a preference rather than as a
  defect. **None of these three findings would have been found by a program
  that was merely correct** — and this one shows the converse too: the pass
  that finds them can also file a defect as a taste.

- **`references` and `rename`** — answered (ADR-0294), and they were the two
  rows the roadmap's Tooling table called nearly free. They were: every `use`
  row the document caches carries a defining-point, so the rows sharing the
  one under the cursor are the occurrences of one thing, and a rename is that
  list with an edit per row. What was not free was the *unit*. The dump
  reports no occurrence inside a component — `NotingHere` keeps it to the
  document's text — so a rename asked from `client.pas` could see one
  occurrence of `Doubled` and not the four in `middle.pas`, and the answer
  was to compile each entry of the document's file table again with the
  entries before it as its imports, which is exactly what the document's own
  translation had read. A field's declaration is in no row at all and is
  added by position.

  **The finding was the compiler's, and it had been wrong since ADR-0246.**
  An `nkField` stands at its point and `CheckExpr` passed that position to
  `LookupName`, so every qualified name in an expression was reported from
  the `.`: `Middle` in `Middle.Doubled` was inside neither span and `.Doubl`
  hovered as the interface. Three dump goldens, five definition sessions and
  an independent client had read those columns and none had stood on one.
  The session that did was written for a rename, and its prediction differed
  from the server's answer by a placeholder of `.Doubl` — visibly wrong, as
  ADR-0250's was. Two call sites now pass the qualifier's position and
  `tests/dumps/uses_module.dump` moved six rows, each by the qualifier's
  length. `rename` is also the first method here that *refuses* rather than
  answering `null`, with LSP's `RequestFailed` and a message, because a report
  may be partial and an edit may not.

**An eighth followed on 2026-09-03**, the second of the usability findings,
and it is the one whose measurement changed the task it named.

- ~~**`only` is a collision workaround, not a narrowing tool.**~~ **Closed by
  ADR-0298, and the entry had counted three of thirty-seven.** It read: the
  server imports twelve modules, and both of its §6.11.3 `only` clauses
  exist because two modules export the same spelling — `PasDir` exports
  `Close` and `NameMax`, which `PasIO` and `PasJson` also export, and
  `PasParse` exports `ResultText`, and so does `PasError`. Collisions grow
  with the product of the export lists, `only` is per-import and
  enumerative, `qualified` makes every use wordier, and the fortieth-import
  program should be written before designing anything.

  **The fortieth-import program did not need writing; reading the
  export-parts did.** Every spelling exported by more than one module under
  `lib/` was listed, folded, and there were **37**: twenty shared by
  `PasContainer` and the fixed `PasVector`/`PasMap` it generalised, nine
  shared among five transports on purpose (ADR-0264, ADR-0265), four
  modules each exporting a `LineMax`, and four accidents — of which the
  entry's `ResultText` was `PasIO`'s and `PasParse`'s, not `PasError`'s, and
  `PasDir.List` collided with a *type* in `PasList` that nothing had noticed
  because nothing imported both. The deliberate ones settled the design:
  each transport imported the one beneath it `qualified`, which is the very
  cost the entry complained of, paid inside the library at every layer. So
  the rule is absolute — no two modules under `lib/` export one spelling —
  and the less general side of each collision took a prefix. Both `only`s
  and both `qualified`s are gone, and `export-unique` reads every
  export-part from the compiler's token stream and refuses to pass by
  reading nothing. A collision is now a failed build and not a comment
  beside an import.
- ~~**The dialect's error-handling constructs are unused by its largest
  client.**~~ **Closed by ADR-0297 on 2026-09-03**, four days after the
  feature it asked for had landed. As written: `lsp/pasls.pas` contained no
  `T ! E` and no `try`, and reached for the accessor instead — `IntOr`
  eighteen times, `JsonIntegerOr` eight, `LookupOr` three, `PathOr` once,
  thirty calls against zero. The entry had corrected itself once already,
  from *a generic over the fallible type cannot be written* to *the helpers
  are a workaround for missing inference*, and ADR-0254 landed inference with
  that paragraph as its cause. Then nothing used it: the four fallible
  accessors stood, the twelve result types in `lib/` were twelve separate
  `T ! ErrorCode` denoters that §6.4.1 makes twelve types, and
  `grep -rn ValueOr lib lsp` found nothing.

  Closing it was a library change — `PasError` exports
  `Fallible(T: type) = T ! ErrorCode` and one `ValueOr`, every result type is
  a production of it under its old name, the four accessors are retired and
  27 call sites moved — and it found **two compiler defects** on the way,
  because the probe was written in the library's shape before the library
  was touched. A production whose argument is spelled like the discriminant
  read the discriminant itself and resolved its body over nil, which is the
  *natural* spelling for a generic over `Fallible(T)` and had been avoided
  by every case in the tree by accident of declaration order; and ADR-0254's
  "graceful degradation" for a schema the caller cannot see was not one — the
  next actual bound the type instead. Both are Sema fixes with named killers.

  **The measurement, retaken with the feature present**: 19 accessor calls
  became 19 `ValueOr` calls and the `try` count stayed at zero — which is the
  answer. A server must respond to every request, `try` leaves the routine,
  and there is no place in the server where that is the right shape; there
  are two shapes, propagate and default, and this program is entirely the
  second. `tests/dialect/try_depth.pas` answers the other half the chapter
  had left open, four `try`s deep across two modules: it reads well, a cause
  crosses every level unnamed, and the one thing a reader has to know is that
  `try` is a function that leaves the block, which nothing at the call site
  says.
- ~~**A bindable file cannot cross a parameter**~~ — **closed by ADR-0299 on
  2026-09-03, and the entry was half wrong.** It said §6.4.1 makes `bindable`
  part of a variable-declaration, so no formal parameter accepts one and
  `lib/pasfile.pas`'s four writers had to be one routine with two flags. A
  two-minute probe showed `type BText = bindable text; procedure P(var f:
  BText)` had bound inside its body all along — §6.4.1 puts the word in a
  *type-denoter* and a type-name hands it on — so what the library could not
  offer was a helper its callers could reach with a plain `text`, which is a
  different sentence. The entry sat here as *one decision nobody has asked
  for twice*, and the count was wrong too: this module asked, the server's
  `WriteScratch` asked, and §6.7.6.8's own worked example
  `procedure bindfile(var f: text)` had asked in 1991.

  What closed it dissolved four shapes at once rather than the one this
  chapter held: every file variable is bindable (AP 6.5.1), so a `var f:
  text` formal, `p^` for `p: ^text`, a `text` field and a `text` element all
  bind without the word, and `bind` asks nothing but whether it was given a
  file. It is the first dialect decision that *admits* a program the
  standard requires rejected instead of adding a construct, and the test it
  passes is AP 6.0.1's — no conforming program changes meaning. The
  library's `Attach`, `Found` and `Opened` now take the file, the flags are
  gone, and `NotBindable` — the one message `bind`, `unbind` and `binding`
  shared — is deleted rather than catalogued, no program being able to
  reach it. Five cases die when the standard's refusal is put back.

### The chapter as it closed

**Removed from `doc/roadmap.md` on 2026-09-03**, the day its last three
findings closed, because a chapter with nothing to do is length the roadmap
does not need. What follows is the chapter as it stood that day, with its
in-chapter links repointed here; the register above is where its findings
are, and the argument for the chapter is the section after this one.


**A Language Server Protocol implementation, written in Afterschool Pascal and
for it**, and it is written: `lsp/pasls.pas` answers `publishDiagnostics`,
`documentSymbol`, `definition`, `hover`, `foldingRange`, `selectionRange` and
formatting for a document and for a range, and the same binary speaks MCP over
stdio when given `--mcp`. `lsp/README.md` says what it is and how to run it;
`.mcp.json` declares it as this project's own development tooling, which is
the loop closed from the other end — the program written to judge the language
is a program the people working on the language use every day.

It was proposed as **the caller** and not as a feature. Every gate here says
whether the compiler is correct; not one of them can say whether a program
large enough to get tired inside is *pleasant* to write in this dialect —
where the boilerplate collects, which of the three affine kinds gets in the
way, whether `T ! E` and `try` still read well at depth, whether a module's
export list is a help or a chore at the fortieth import. **The argument, why a
server rather than the text-mode IDE this chapter first proposed — now
withdrawn — and what
each of its increments found are in
[the chapter above](#the-language-server-and-the-bound-it-found-before-it-ran)**
— including the one result no golden here could have produced, an
independent client computing UTF-16 columns the server then agreed with, which
is the external authority open question §1 says the dialect structurally
lacks.

Nothing about the program is open, and since 2026-09-03 nothing that writing
it demanded of the language is open either. The chapter was kept one day for
the method, which is the product, and then moved here whole.

#### The findings, all closed

Twenty-seven entries, and **all twenty-seven are in
[the register above](#the-language-servers-findings-as-they-were-recorded)**
— twenty-five acted on, and two that needed no action because each is a
thing a writer has to know rather than a defect. The last three closed
together on 2026-09-03 and each was a decision this chapter had been
carrying as a question: the library now uses the inference it asked for
(ADR-0297), no two library modules export one spelling and a gate holds it
(ADR-0298), and every file variable is bindable (ADR-0299). Two of the three
were wrong as recorded — the collision entry had counted three of
thirty-seven, and the bindable entry's *nobody has asked twice* was answered
by counting — which is the shape the whole register has: a finding recorded
and left is a finding wasted, and the rule that made the first one
actionable was this section's own — one site is an anecdote, two are a demand
(ADR-0116).

The shape of the register is the argument for the chapter: five of the
twenty-seven were **bounds** — 8 imports, 24 arguments, a 63-character key, a
255-character line, a 16 384-byte capture — and every one of them was chosen
by counting what the largest thing in the tree needed at the time. The
largest thing in the tree was a test case.

#### The usability findings, which took a deliberate pass to get

**Twenty-three findings and not one of them was about *usability*, which is
what this chapter said it was for.** Every one was a capability finding — a
bound too small, a routine absent, `getpid` missing, a compiler that did not
record a position. Those are *X was not there*; this chapter asked *Y was
unpleasant*, and named four questions: where the boilerplate collects, which
of the three affine kinds gets in the way, whether `T ! E` and `try` still
read well at depth, and whether a module's export list is a help or a chore at
the fortieth import.

The reason is structural rather than flattering. Each increment was
feature-driven and recorded what **blocked** it, because a block stops you and
an annoyance does not — so the method this chapter proposed is biased toward
capability gaps by construction. Getting the other kind took reading the
finished program as a *reader* rather than as its author, which is a different
activity and had never been done. Three came out of one pass and all three
are closed: one in both its halves within four days (ADR-0290, ADR-0291,
ADR-0292), which taught that the pass that finds an annoyance can also file
a defect as a taste; the accessor finding by ADR-0297, whose probe found two
compiler defects a green suite had not, and whose retaken measurement answers
the depth question — `try` reads well four levels deep across two modules,
and a server has no place for it because a server answers every request; and
the `only` finding by ADR-0298, where the fortieth-import program did not
need writing because reading the export-parts did. Of the four questions,
two are answered by those records, and two — where the boilerplate collects,
and which affine kind gets in the way — are still questions with no
finding against them, which after 3 280 lines of server is itself the
answer for now.

**What the examples then found** (ADR-0295) is the next register, and it is
in [*Writing a daily program*](roadmap.md#writing-a-daily-program) rather than here:
twelve one-page programs written to be read produced seven findings in an
afternoon, which is the sentence this chapter kept making — the next finding
comes from somebody writing a program.

**The text-mode IDE this chapter once proposed is withdrawn**, on 2026-09-01
and by decision rather than by discovery: the language server is the better
tool for what the IDE was wanted for, it exists, and it is in daily use here.
The reasoning that chose a server over it is in
[the section below](#the-chapter-as-it-stood-and-the-argument-it-was-made-on),
and so is the withdrawal. Nothing was lost in capability — `PasTerm` built the
terminal binding the IDE would have needed (ADR-0262), and it stands as a
library module like any other.

Everything after that is unknown on purpose. **The list of what this demands is
the product of writing it**, and enumerating it here would be designing
features without a caller — which is the practice this entry exists to serve
rather than to break.

### The chapter as it stood, and the argument it was made on

**The IDE was withdrawn on 2026-09-01**, which closes the argument below
rather than leaving it hanging. It was never struck when the chapter changed
shape — the roadmap carried it as *later, not struck* for six increments — and
what withdrew it is not a discovery but a judgement: **the language server is
the better tool for what the IDE was wanted for**, it exists, it answers eight
questions about a document, and it is this project's own development tooling
over MCP. The thing the IDE was proposed to buy — a *Pascal-lineage answer
key*, so that "this was easier in Turbo Pascal" would be a finding rather than
a matter of taste — was real and is given up, and the argument below is worth
reading for having named that cost before anyone knew whether it would matter.

**No capability went with it.** `PasTerm` (ADR-0262) built the terminal
binding the IDE would have needed, before anything asked for it and while the
roadmap still listed the IDE as waiting on exactly that — five `pasx_term_*`
routines, `<termios.h>` and `<sys/ioctl.h>` joining ADR-0186's catalogue, and
the saved settings living in the runtime because a program cannot hold a
`struct termios` at all. It stands as a library module like any other, and a
program that wants a terminal has one.


`doc/roadmap.md` carried the argument below from before the server existed
until 2026-09-01, when the last of its narrative stopped being about anything
open. It is moved here whole, in the tense it was written in, because the
argument is what a reader needs and it was made **before the outcome was
known** — which is the only condition under which a proposal can be judged.

Three things in it are worth marking before reading it. It gave up a
**Pascal-lineage answer key** on purpose and said so, and named three things
that had to buy that back; all three were redeemed, the third by Microsoft's
own `vscode-jsonrpc` driving the server as a client. It named **one hazard**,
LSP counting in UTF-16 code units where AP 6.4.15 refuses an integer index,
and the hazard turned out to be half wrong in the useful direction — the
*count* never needed the index. And it listed what was already in hand, got
one item wrong and missed another: there was no JSON anywhere in the tree
(`PasJson`, ADR-0217), and `PasStream` cannot frame a message whose header is
line-oriented and whose body is not (`PasLsp`, ADR-0218).

**A Language Server Protocol implementation, written in Afterschool Pascal and
for it**, and since v3.1.0 it is *written*: `lsp/pasls.pas` reads `didOpen` and
`didChange`, compiles what it is handed, and answers `publishDiagnostics`,
`documentSymbol`, `definition` and `hover` — every occurrence this language
has, across program-components — and since ADR-0258 `foldingRange` and
`selectionRange`, which are what a *statement's* extent buys. It was written
**here**, which was the whole
condition: a shim in another language wrapped around `pascalc` would have been
a statement about tooling and not about this dialect, and outside ADR-0116's
discipline entirely.

This chapter is kept in the tense it was written in below, because the
argument is what a reader needs and it was made before the outcome was known.
What follows the argument is what actually happened.

It is not proposed as a feature and it is not part of the compiler. It is
proposed as **the caller**, and the reason is ADR-0116's rule taken as far as
it goes. Every feature since ADR-0117 has had to be demanded by something, and
the discipline has held — the one facility that was designed rather than
demanded did not survive contact, and `take` (ADR-0182), `h := nil` (ADR-0202)
and the element walk (ADR-0199) were each shaped by the client written beside
them, sometimes into a different feature than the one that was set out to be
built. But every client so far has been a **library module or a test case**,
and those are small, single-purpose, and written by whoever was already holding
the feature. None of them can answer the question ADR-0109's goal is actually
about.

**What it measures is usability, and nothing here measures usability.** The
gates say whether the compiler is correct. The specification says what the
language is. `tests/spec/` says a clause is honoured. Not one of them can say
whether a program large enough to get tired inside is *pleasant* to write in
this dialect — where the boilerplate collects, which of the three affine kinds
gets in the way, whether `T ! E` and `try` still read well at depth, whether a
module's export list is a help or a chore at the fortieth import, what one
reaches for and finds missing at the moment of reaching. Those are answered by
writing something big, and by nothing else.

**Why a server, and what changing to one gives up.** This chapter proposed a
text-mode IDE in Turbo Pascal's mould from the day it was written, and the
argument for that shape was an **answer key**: [the open questions](roadmap.md#1-the-dialect-has-no-external-authority-and-every-gate-here-is-anchored-in-one)
name the other Pascals as an authority wherever one of them has already
answered a question this dialect is asking, and a Pascal programmer arriving
here already knows that IDE — so *this was easier there* would be a finding
and not a matter of taste. **That is given up, and it is a real loss**: LSP has
no Pascal-lineage precedent, so an ergonomic judgement against it falls back on
expectation, which is the softer evidence the IDE argument was chosen to avoid.
Three things buy it back.

- **No prerequisite.** The IDE could not start until a whole POSIX binding
  landed in front of it — there is still no terminal control anywhere in this
  tree, no `termios`, no `isatty`, no way to read a key without waiting for a
  line, no cursor addressing, no window size — which is a facility built
  *before* the first usability finding arrives, in the practice this entry
  exists to serve rather than break. A server over stdio needs none of it.
  `PasStream` frames the messages, `PasProcess.Capture` invokes `pascalc`,
  `PasParse` reads `file:line:col: error:` back off it, and a server that does
  nothing whatever but `publishDiagnostics` is producing findings on the first
  day.
- **It stresses both live design gaps by construction, rather than by
  argument.** Documents by URI, symbols per file, positions, capability
  records: a heterogeneous container is unavoidable, so the four monomorphic
  containers stop being something this page asserts and become something met
  in the first hour — which is the row [above](#what-each-landed-feature-left-open) and
  the caller ADR-0116 wants for it. And `didChange` arriving while a compile is
  in flight, with request cancellation, is **exactly the sentence** the
  concurrency row [below](roadmap.md#where-the-ideas-come-from) says no program here has
  yet said: a slow client not slowing the others.
- **It has an external authority**, which is the one thing open question §1
  says the dialect structurally lacks. The LSP specification is third-party and
  versioned, and there are independent clients that disagree with a server
  objectively. It answers nothing about the *language* — the specification is
  about a protocol — but the program judging the language is then held to
  something this project did not write.

  **That argument went unredeemed for six increments and is redeemed now.**
  Every session in `lsp/sessions/` is a golden written here, which is the
  *"a golden agrees with whatever wrote it"* blind spot this project is most
  careful about everywhere else — so the one thing LSP was chosen for was the
  one thing not being collected. What redeems it is **Microsoft's own
  `vscode-jsonrpc`**, the reference implementation of the wire protocol that
  VS Code itself uses, driving the server as a client: initialize with a real
  capabilities object, `initialized`, `didOpen`, diagnostics received,
  `definition`, `hover`, `documentSymbol` with hierarchy, `$/cancelRequest`,
  pipelined requests, positions past the end of a document and of a line, a
  method the server does not implement, `shutdown`, `exit`. **Zero connection
  errors and zero unhandled notifications**, across every probe.

  The sharpest result is ADR-0237's, and it is the one no golden here could
  have produced. Given a line where an astral pair and an accented letter
  precede an identifier — byte column 20, UTF-16 column 17 — the server
  answered **17** under `utf-16` and **20** under `utf-8`, against expectations
  the *client* computed from the document. A reading this project made about a
  protocol it does not own is now confirmed by an implementation it did not
  write. That is what open question §1 asks for and had never had.

~~**One hazard, and it is the sharpest edge in the idea.**~~ **Answered, and
the text model came through it** (ADR-0237). LSP positions are **UTF-16 code
units** by default; UTF-8 is negotiable since 3.17 and not guaranteed. AP
6.4.15 refuses an integer index outright and makes an element an extended
grapheme cluster, and `PasUnicode` offers a scalar view — so the protocol's
unit is a **third** one, and this page said nothing in the text model answers
in it.

**Half of that was wrong, and it is the useful half.** The index is refused and
always will be, but the *count* the protocol wants never needed one: a scalar
below U+10000 is one UTF-16 code unit and one at or above it is two, so
`PasLspDiag.Utf16Column` is a walk over `PasUnicode.NextScalar` and nothing
else. The externally specified stress test of AP 6.4.15's central choice was
run, and what it found is that refusing the index cost this nothing — the
scalar view was the right thing to have exported, and it was exported for a
different reason (ADR-0199).

**What the exercise did produce is a decision the plan had not seen**: the
encoding must be *negotiated* rather than converted to. Under `utf-8` the
compiler's own column is already the protocol's, so converting it would be the
defect and not the fix — and a client that offers `utf-8` is the common case in
practice. The server takes it when offered, echoes what it took, and converts
only under the default.

**What is already in hand**, which is more than one would guess: `PasStream`
and `PasFile` for the files, `PasProcess.Capture` for invoking `pascalc`,
`PasParse` for reading the diagnostics back off it, `PasVector`, `PasList` and
`PasMap` for the tables, `owned ^T` and `take` for a document store whose
entries are replaced rather than copied (ADR-0181, ADR-0182), and `utf8(n)` for
the content — which would be the text model's first client outside a test.
~~**One library gap is visible before starting**: there is no JSON anywhere in
this tree~~ — `PasJson` (ADR-0217), and it took two decisions this paragraph
had guessed wrong.

**And a second gap this paragraph did not see**: it says `PasStream` frames the
messages, and `PasStream` cannot. A message is `Content-Length: N` and then
exactly N bytes, so the header is line-oriented and the body is not — a reader
that has just consumed a header line is usually holding the first bytes of the
body, and nothing that reads *lines* can hand those back. `PasLsp` (ADR-0218)
is the buffer between `PasIO`'s byte reads and the frame, and it is what the
sentence should have said.

**The first increment is written** (ADR-0236). `lsp/pasls.pas` holds documents
by URI, writes the one it was asked about to a scratch file, invokes `pascalc`
on it and publishes what came back — `initialize`, `didOpen`, `didChange`,
`didClose`, `shutdown`, `exit`, and `MethodNotFound` for every other request.
It lives in `lsp/` and not in `tests/` because a server has to be a binary
someone can point an editor at, which is what makes the external authority
above real rather than theoretical; `lsp/build.sh` produces one and
`lsp/run.sh` replays recorded sessions against it as the `lsp-server` case.

**And the second method is answered, which is where the chapter first reached
the compiler** (ADR-0239). `textDocument/documentSymbol` is an outline, and
this compiler had nothing structured to say about a program that was not
`--dump-sema` — a format ADR-0085 demoted from a specification to a debugging
aid on the day there was no second front end to diff it against. So the choice
was between a server that parses Pascal-shaped debugging output and a compiler
that answers the question, and it is the second: `--dump-symbols` writes every
name a source declares with its kind, position and depth, in **Pascal's**
words rather than the protocol's numbers. `--dump-dispatch` (ADR-0229) and
`--dump-layout` (ADR-0185) are the precedent; what is new is that the caller is
not a gate. The flag stops after the *parse* on purpose — an outline is what an
editor draws while the file is wrong — which also means it needs no `--import`,
so this is the one question about a source that can be asked of the file alone.

~~**The next method is the one that will decide whether that surface
generalises.**~~ **It does, and the two methods turned out to be one**
(ADR-0246). Hover and go-to-definition want a *type* and a *defining point*,
which are Sema's and not the parser's — and Sema knows both at the same
moment, so `--dump-uses` carries them on one line and answers both. The shape
is `--dump-symbols`'s unchanged: the compiler in Pascal's words, the server
holding the protocol's table.

**What each had to say about a file that does not check** is the part the
record above declined to settle, and the answer is the opposite of the
outline's. `--dump-symbols` stops *before* Sema, so a wrong file still
outlines; a defining-point cannot do that, so `--dump-uses` is the one dump
**not guarded by `errorSeen`** and carries on instead. Sema accumulates its
diagnostics rather than stopping at the first, so a source with three mistakes
has resolved everything else correctly — and an editor asks where a name is
declared exactly while the file is being edited into shape. Two answers, one
requirement, reached from opposite ends of the pipeline.

**It also crosses a file, which is what the method is worth having for.** A
`file <index> <path>` table heads the dump, the imports come from the same
`.components` walk the diagnostics use (ADR-0238), and the name a reader does
not already know is exactly the one declared somewhere else.


## A second transport over one program

The entry below was written in `doc/roadmap.md` before the work was started,
with a prerequisite in front of it and an expected finding named in advance,
and it is kept in the form it had — the proposal, with what actually happened
marked where the two differ. Both the prerequisite and the prediction did
their job, which is the reason it is worth keeping rather than summarising:
the prediction was **half** right, and the half that was wrong is the useful
half.

**A second transport over the same program**, asked about because an agent is
now a reader of this repository as much as an editor is. It was recorded here
before it was started, with a prerequisite in front of it and an expected
finding named in advance, and both of those did their job: the prerequisite was
ADR-0239 and the prediction was half right in a way worth reading. What follows
is the entry as it was written, with what actually happened marked where it
differs.

**What is already shared, and it is most of it.** `lsp/pasls.pas` splits into a
transport half and a work half, and the split is clean: `ImportsFor`,
`WriteScratch`, `Compile`, `DiagnosticsIn`, the document store and `UriToPath`
know nothing about LSP beyond taking a URI. MCP speaks the same JSON-RPC 2.0
envelope with the same error codes, so `Dispatch`, `NewResponse`, `CopyId` and
the `-32601` path carry over unchanged. That makes it `pasls --mcp` rather than
a second binary — one document store, one import resolver, one scratch path.

**The one real code change is the framing**, and it is the interesting part.
MCP's stdio transport is newline-delimited JSON; LSP is `Content-Length: N` and
then exactly N bytes. `PasLsp` (ADR-0218) exists *because* that framing is not
line-oriented — a reader that has just consumed a header line is usually
already holding the first bytes of the body, and nothing that reads lines can
hand those back. Newline-delimited is the easier of the two, so the work is
small and the value is not the work: it asks whether `PasLsp`'s seam is an
abstraction or merely the one shape it was written for, which is a question one
framing cannot answer.

**The scenario that benefits is not the editor's.** LSP serves a human in an
editor; MCP would serve an agent working on this repository, which is a real
reader here. An agent editing `selfhost/apfront.pas` — 22 102 lines — has no
semantic route into it and falls back on `grep`, which fails in a way this tree
has already paid for: §6.11.1 puts an exported routine's header in the
module-heading *and* leaves the block repeating the name, so `^function Name(`
matches an interface entry with no body, which is how `foreign-reserved` broke
on the day of the three-component split. *Where is this declared*, *what does
this name resolve to* and *which component exports it* are questions the
compiler answers exactly and a regex answers by accident.

**That argument is already accepted here**, which is why this entry exists at
all: ADR-0229 and ADR-0230 moved `kind-exhaustive` off a Pascal-parsing regex
and onto the compiler's own `--dump-dispatch`, deleted 85 lines of it, and
found three dispatch sites the text match had simply missed. The agent is the
next reader in that line, and MCP is the socket it plugs into.

**Where it buys little**, said plainly so the entry is not read as larger than
it is. Compiling, running the suite and reading diagnostics are all done
through a shell today and are not improved by wrapping them in a tool call. The
gates gain nothing: a Python reader wants a line-oriented `--dump-*` flag,
which is what it has and the better interface for it. Editor users gain nothing
whatever.

**What it would stress that LSP has not.** Two things, both live. `PasJson`
under *construction* load — MCP tool descriptors are JSON Schema, nested and
heterogeneous and kilobytes long, where a flat `publishDiagnostics` carrying
two diagnostics is 321 characters and that alone found the `JsonCharsInto`
defect; `JsonLine` at 255 and `MapKey` at 63 are both open findings above, and
a tool list is the payload that turns them from recorded into blocking. And a
second framing over one reader, which is ADR-0116's two-sites test applied to
`PasLsp` itself.

**The prerequisite, and it decided the ordering.** Nearly every tool worth
exposing needs the compiler to answer a structured question *about a program*,
and when this was written it could not: the only route was `--dump-sema`, which
ADR-0085 demoted from a specification to a debugging aid the moment there was
no second front end to diff it against. That is **settled now** — ADR-0239
gave the compiler `--dump-symbols` and the decision behind it, which is that
the answer comes from the compiler and not from a second reader of its
debugging output. One question is answered and the surface is one question
wide; what the tool list above would need is more of them, and each will ask
the question ADR-0239 deliberately left open — whether it belongs behind this
flag, behind another, or behind something that is not a flag.

**The finding it is expected to produce**, named in advance the way the
concurrency row names its sentence, because a second surface added without one
is breadth where this chapter wants depth: *`PasLsp` is a frame reader and not
a transport, and the second transport is what says so.*

**That was right, and it was the smaller of the two.** `LspReader`, `Ready` and
`NextByte` are shared unchanged; `LspRead` is 40 lines and the pair that
replaces it 58. The module's name is now narrower than its contents and is kept
anyway — a third caller wanting the reader and *neither* framing would be the
reason to rename it.

**The finding the prediction did not have is the one worth carrying.** The
*work* half was less transport-neutral than the paragraph above claims, and only
a second caller could say so. `CompilerCommand` had the scratch path baked in
as the **source**, which is an LSP assumption — a document may never have been
saved, where MCP's unit is a file on disk. And the tool's `path` has to be made
absolute, because `ImportsFor` compares against sidecar entries it resolved
against the sidecar's own directory: a relative path matches none of them and
`lib/dialect/pasjson.pas` reports its 48 diagnostics again. **That is
ADR-0238's defect arriving a second time by a different road**, and the LSP
side never met it because `UriToPath` always yields an absolute path. *A
routine is not neutral because it has one caller; it is neutral when a second
one does not have to change it* — which is ADR-0116's two-sites rule applied to
an interface rather than to a feature, and is the sentence this entry adds to
the page.

**And one prediction above is wrong**, which is worth leaving visible rather
than editing away. The tool descriptors were expected to stress `PasJson` and
turn `JsonLine`'s 255 and `MapKey`'s 63 from recorded findings into blocking
ones. The whole `tools/list` frame is **931 bytes** and every literal in it is
under 255. What stressed something was the *outline*: 40 146 characters holding
1 624 newlines, in a frame of 41 859 bytes and one line, because `JsonRender`
escapes a newline and the frame therefore holds none — so what it stressed was
the framing, and `JsonlWrite` refuses a body holding a real newline rather than
assuming the property.

**What it cost** is what was estimated: a second thing to keep green. It is
one more session in the same corpus rather than a corpus of its own —
`lsp/sessions/mcp.jsonl` with a `.mcp` marker that says the framing is one
message to a line — plus `tests/dialect/lib_lsp_jsonl.pas` for the module half,
which had to be a second *program* because one program has one standard input
and the two framings cannot be read from it at once.

One caveat about the reading above, in this page's own spirit: the LSP and
`lsp/` facts here were taken from the sources, and the MCP-side ones —
newline-delimited stdio framing, the JSON-RPC envelope, the shape of a tool
descriptor — are from knowledge of that protocol and were not checked against
its specification in this tree. Confirm them against the published version
before any of this is built on.

### And it is in use here

The short-term goal `doc/roadmap.md` recorded beside the proposal was that the
server become this project's own development tooling, and it is: `.mcp.json`
in the checkout declares it, `lsp/mcp.sh` is the stable command it names —
finding a compiler in the build tree or on `PATH`, building the server if the
binary is missing or older than its sources, and execing it with `--mcp` — and
an agent working on this repository asks `outline` where something is declared
and `diagnostics` what the compiler makes of a file without shelling out to
either. `lsp/README.md` has the mechanics.

It is a launcher and not a CMake target on purpose, and the two decisions do
not conflict: `lsp/build.sh` says a server wants a binary a *user* can point an
editor at rather than one buried in a build tree, and what an agent needs is a
stable **command**, which is a different thing.

**Why that was a goal and not a convenience.** It closes the loop from the
other end. The program written to judge the language becomes a program the
people working on the language use every day, which is the only way a tool's
own rough edges get found — and it is the first time anything in this tree is
a *client* of the dialect during development rather than a subject of its test
suite.

## The three questions the roadmap closed after version 3

Four questions stood in that chapter and one is still open — the dialect has
no external authority, which no record can close. These are the other three,
in the form they had when they were struck.

### 2. ~~A third-party differential~~ — done (ADR-0234)

`fpc-differential` compiles every case with a golden under Free Pascal's
`-Miso` and compares. It is a `ctest` case that skips without `fpc`, and
`tests/checks/fpc_disagreements.txt` is the catalogue, failing in both
directions like every other catalogue here.

**It found no defect in this compiler**, which is the result and not a
disappointment: of eleven catalogued disagreements, six turn on a clause and
all six are decided here, two are implementation-defined, and three are not
verdicts. Three of the six corroborate a reading that nothing in this tree
could previously challenge — ADR-0073's mixed comment delimiters, whose own
record says a comment is invisible to every stage after the lexer so no oracle
here could have caught it; `round` defined by equivalence rather than by a
rounding mode, where the test's comment had predicted the disagreement and had
never met a processor that made it true; and ADR-0076's longest-prefix number
read.

**Two things this entry got wrong, both worth keeping.** It named the eight
conforming `lib/` modules first, as the portable half — and no second
processor can run them: FPC's `-Mextendedpascal` does not implement §6.13's
modules at all, so `module m interface;` is a syntax error. And it said the
option was worth more now than later; the numbers say how much more. FPC
refuses **141 of 244** cases with a golden, so the differential reaches 103,
and every release moves that the wrong way.

What is left is not a task. `tests/dialect/` is compared by nothing and no
third party can be found for it, which is
[§1](roadmap.md#1-the-dialect-has-no-external-authority-and-every-gate-here-is-anchored-in-one)'s
standing risk.

### 3. ~~Mutation testing, committed to the tree~~ — done (ADR-0207)

`tests/mutation/` holds one file per recorded mutation and a harness that runs
them. Both conditions this entry named are enforced by it, and a **third**
arrived while ADR-0205 was being written: a mutant restored with a plain `cp`
and a `touch`, correctly by the old rule, and never rebuilt — so the next run
measured the mutant and a golden was taken against it. The rule was right and
one step too short.

What is left of the entry is a caution rather than a task, and it is in
`doc/sop.md` §7: the catalogue is a **register of demonstrations, not a
measurement**. `ls tests/mutation/mutants/` is where to count them, and **this
sentence no longer says how many**, having gone stale twice — it said eleven
when there were eleven and again when there were forty-five. "The mutation
suite passes" means those recorded claims still hold and nothing more.

Many more records carry a mutation in their *prose* instead, most naming code
that has since moved, and nothing runs one of those. **`doc/sop.md` §7 owns
that comparison** and carries the count with the grep that produced it; this
entry says only that the register is much the smaller half, so that one
sentence does not come to disagree with itself in two files.

### 4. ~~Should the dialect read a type off a *component*?~~ — yes (ADR-0215)

`type of` now takes §6.5.1's whole variable-access, and
`lib/dialect/pascontainer.pas` is the caller it was built for: five of its
headings lost a type parameter.

```pascal
procedure VecPush(Ptr: type; Elem: type; var v: Ptr; x: Elem);  { was }
procedure VecPush(Ptr: type; var v: Ptr; x: type of v^.a[1]);   { is }
```

Three things it settled that the question above had only guessed at.

**The cost was not the resolution.** The worry was a designator typed without
being evaluated inside re-entrant declaration checking, re-entered per generic
instantiation. It needed nothing: `ResolveType` caches on the denoter's own
`ntype`, `ForgetResolved` clears exactly that, and `CheckExpr` re-resolves
every name unconditionally rather than consulting what is already there. The
non-evaluation is likewise free — the type of `a[i]` does not depend on `i`,
and a type-denoter is never walked by CodeGen.

**What it cost instead was the substring**, which nothing above had thought of.
§6.5.6's substring-variable *is* a variable-access and what it possesses is the
canonical string-type — a pointer and a length with no capacity, which no
variable may have. The program compiled, ran, and stopped at *a string of
length 3 does not fit a capacity of 0*. It is refused now, and that is the only
variable-access this denoter cannot answer for.

**And it found where the widening stops.** `VecGet` and `MapGet` still take the
element type, because they *return* it and §6.7.2 makes a result-type a
`type-name`:

```
result-type = type-name .
```

So `function VecGet(…): type of v^.a[1]` is unwritable in the dialect too. That
is a second production and wants the same argument made again about a different
clause; it is not carried here as an open question, because nothing is waiting
on it — the two-parameter form works and reads fine.

(The clause number here read §6.7.1 until 2026-09-05, as ADR-0215's own text
still does. §6.7.1 is *Procedure-declarations* and §6.7.2 is
*Function-declarations*; `clause-citations` cannot tell them apart, both being
clauses, and ISO 7185's §6.7.1 is *General* — an expressions clause several
records here cite correctly, which is what made the wrong one read as ordinary.
ADR-0324 records the correction. **And the production was widened after all**,
for a discriminated-schema and not for a type-inquiry: `function f: string(5)`
compiled the whole time and nobody had asked.)

## Version 3 — what it took, and what it left

**Shipped, 2026-08-28.** This chapter was four proposals looking for a
decision; three of them are now records and the fourth dissolved. What is left
open is §1, and it is written out below rather than struck through, because it
is the one that did not happen and the reasons it was wanted are unchanged.

[`CHANGELOG.md`](../CHANGELOG.md) says what the number tracks — *the accepted
language, the diagnostics and the command line* — and by that definition three
of the four original proposals were invisible to it. §0 is what the number is
actually for.

### 0. Afterschool Pascal is the language — **this is v3** — ADR-0232 ✔

`--std` is gone, and with it the two conformance modes, ADR-0166's `{ @std: }`
header comment, the `.std` sidecars and the clause 5.1 a) compliance statement.
A source is written in Afterschool Pascal; the compiler has no mode to be put
into. The lexis is the dialect's, which is survivable only because the dialect
contains Extended Pascal (ADR-0117).

The decision was taken with the cost measured rather than estimated, and
ADR-0232 records all of it. What actually landed, against what was predicted:

- **The Extended Pascal corpus came through**, as predicted. Four cases went —
  the three type-inquiry refusals and `trap_substring`, each of which asserted
  that the *dialect's* answer was refused, and each with a positive counterpart
  under `tests/dialect/` already.
- **The ISO 7185 corpus did not survive intact**, as predicted, and the shape
  was slightly different: 42 `*_refused` cases (Annex B's grid, 21 constructs
  times two modes) and 28 `*_iso` mode gates were deleted outright, six
  `badparse` gates with them, and **nine sources were renamed** because a
  word-symbol took their identifier — `value` in seven, `only` in one, a
  function called `Value` in two. `verify/verify.py`'s generated program was a
  tenth. That rename is the cost in its most concrete form.
- **Five oracles retired and nothing replaced them**: the BSI suite (the only
  third-party corpus this project ever had), `difftest`, `dialect-containment`,
  `annex-b` and `reserved-words`. The gate count went 24 → 19 — and to 20 since, `fpc-differential` being the first added after v3 (ADR-0234).
- **And `src/` went with them**, which was not part of the proposal. With
  `difftest` and `annex_b.py` deleted it had no reader, and it was in no build
  chain — 16 936 lines of C++, and the last reason this build needed a C++
  compiler. That is written up in the [question this chapter left
  open](#the-question-this-chapter-left-open) below.

The alternative — make the dialect the *default* and keep the modes, which is
what Free Pascal does with `{$MODE ISO}` — was recommended and declined, on the
ground that it leaves the project presenting itself as a conformance vehicle
with a dialect attached, which is not what it is.

### 1. Split the compiler into §6.13 program-components — **done** ✔

The one proposal v3 did not take, taken the day after v3 shipped:
[ADR-0233](adr/0233-the-compiler-becomes-three-program-components.md), written
**Proposed** while the alternatives were still live, accepted two days later
without a word of the argument changing, and implemented the same day. The
compiler is `selfhost/aptypes.pas`, `selfhost/apfront.pas` and
`selfhost/compiler.pas`, and `selfhost/compiler.components` is the order.

Writing the record before the work changed the proposal twice, and doing the
work corrected the record twice. All four are in
[`doc/history.md`](history.md#the-compiler-becomes-three-program-components);
the two that matter to a reader of this file are that **the buffer argument was
false** — `--import` re-tokenises the whole imported file, so nothing about the
peak follows from splitting — and that the pool peak nevertheless **fell by
27%**, which the record predicted it would not. `buffer-headroom` measures all
three translations now and reports the worst of them, which is a better
question than it was asking before.

What the split was taken for is the linking blind spot, and that closed:
`doc/sop.md` §7's row is narrowed to the combinations the compiler's own
structure does not use, because every build now translates a module alone,
translates a module that imports another, and links the result.

### 2. Let the compiler be written in the dialect — **dissolved by §0** ✔

It is. `selfhost/compiler.std` said `extended`, and there is no such file and
no such mode: the compiler's own source is an Afterschool Pascal source by
construction, as every source now is.

The question was rejected twice before that. ADR-0190 refused it on the ground
that *"the fixed point holds only while the compiler is an Extended Pascal
source"*; ADR-0223 built the compiler a second time to arm ADR-0118's variant
guards and used that build as a *reader*, never as the product; ADR-0231 then
measured the sentence and found it false — the second build **is** a fixed
point, and it is the **same compiler**, byte-identical on 1025 sources. So the
objection had already narrowed to the seed before ADR-0232 arrived, and the
seed was refreshed in this release.

**What is left of it is an ordering discipline, not a question**: a dialect
feature must be expressible in what `seed/*.ll` accepts, or the seed is
refreshed first (ADR-0109). What the compiler now *may* use — `defer`, `T ! E`,
`owned ^T`, slices, `break`, `exit`, the generics, `type of` over a
variable-access — it does not yet use, and whether adopting any of them makes
this compiler better is the thing ADR-0109 wanted to learn and still has no
measurement of. That is worth a record when someone tries it, not a roadmap
entry.

### 3. Have the compiler report its own dispatch — ADR-0229, ADR-0230 ✔

`--dump-dispatch`, in two halves. ADR-0229 moved the case-statement half off
the Python source parser: the compiler writes every case-statement whose
selector is an enumeration, with the constants its labels name, the ones they
miss, and the constants no case names at all. The two readers were compared
before the old one was deleted — 60 sites, same routine, enumeration, ordinal,
`N of M` and missing constants on every one — and 85 lines of Pascal-parsing
regex went with it.

ADR-0230 moved the if-chain half, and `tests/checks/kind_exhaustive.py` now
reads **no Pascal at all**: 542 lines to 384. A chain is a *shape* and not a
node, so Sema records every if-statement with its else-part and every tag test
in a condition, and a head is an if that is no other's else-part. The dump
reports the **field** each chain reads, which is what selects a dispatch from a
lookahead — and that is where the regex turned out to have picked its scope by
accident: ADR-0221's "three enumerations qualify" described what a text match
could see, and the compiler finds 70 chains where the regex found 38.

**The limit the proposal stated is unchanged and a dump does not lift it**:
neither form judges whether an arm is *right*. `tyOptional: StaticThroughout :=
true` satisfies the gate and is wrong. This moved the oracle from a Python
parser to the compiler; it did not move it from a prompt to a proof.

### 4. Reconsider containment-by-position — **dissolved by §0**, and the rule kept ✔

This was the proposal §0 predicted it would dissolve, and it did, though not
quite in the way predicted.

The argument *against* withdrawing ADR-0140's rule was that containment buys
`dialect-containment` — the conformance corpus compiled a second way, with the
other mode as the oracle. That sweep is gone, so the argument is gone with it,
and `reserved-words` — the gate that asked whether this language reserves
exactly what Extended Pascal reserves — is not a question once there is one
list.

**The rule is kept anyway**, and the reason is better than the one it had. It
was stated as a constraint on a *mode*: the dialect must not disturb what the
conformance modes accept. It now protects something this language claims about
itself — that every Extended Pascal program is an Afterschool Pascal program
meaning the same thing. Reserving a word-symbol takes that spelling from every
such program that uses it as an identifier, which is exactly the 25-case cost
§0 paid once and deliberately. Paying it again casually is what the rule
forbids.

What did change is who enforces it: `reserved-words` did, and nothing does now.
ADR-0140's Status records that, and `.claude/skills/code-review` is where a new
spelling gets looked at. ADR-0177's `exit`, ADR-0178's `try` and ADR-0184's
unspelled feature remain the three shapes a reader should know before proposing
a fourth.

### What v3 must not touch — and did not

- **Textual `.ll` as the only backend.** ADR-0085 made it more load-bearing,
  not less: it is what lets a clone with no LLVM development files build the
  compiler. Untouched, and v3 went further — the build needs no C++ compiler
  either now.
- **ADR immutability.** Thirteen records were annotated at their Status with
  what ADR-0232 did to them; not one had its argument edited.
- **[`doc/sop.md`](sop.md) §7.** It grew: the front end has no second
  implementation, and there is no third-party corpus.
- **A green suite is not evidence; evidence is a named case that fails without
  the change.** This is the one v3 made *harder* to honour and more necessary
  to: with `difftest` gone, a golden regenerated after a change is agreed with
  by nothing else. `doc/sop.md` B4a says so in as many words.

### The question this chapter left open

`src/` — whether the second front end earned its cost. The chapter had no
answer and observed that the cost had never been counted. It has been:
**16 936 lines of C++, and the whole of the build's need for a C++ compiler**,
against a reader that ADR-0117 had frozen at the conformance surface and that
skipped every dialect source.

§0 answered it by removing the surface. With `difftest.sh` and `annex_b.py`
deleted, `src/` had no consumer at all; it was verified to be in no build chain
— `pascalc` builds with the binary absent, and all 730 cases pass — and it was
deleted. Reviving it would have meant first teaching it the language ADR-0117
deliberately kept it out of, and a second implementation of a language with no
external specification is two readings by one author, which is the one thing
`difftest` could never contradict.

What it *did* catch was drift between two ports of one reading, and that is the
loss. It is recorded in [`doc/sop.md`](sop.md) §7 as the largest blind spot on
that page, and [open question §1](roadmap.md#1-the-dialect-has-no-external-authority-and-every-gate-here-is-anchored-in-one)
is where it belongs from now on.

The fix for the *other* half of that question — that the independent readers
were not independent — was cheaper than any of the four proposals and was not a
v3 item at all, which is why it went first: **ADR-0228 did it.** Readers now
run out of process against a sandbox built outside the repository, with the
compiler's source comment-stripped, that last being the half missed for four
records. Asked whether it was given project documentation, a reader in the
repository names this project and its path; one in the sandbox answers no.


## What would make this practical to pick up

`doc/roadmap.md` opened this chapter on 2026-09-02 for someone working *with*
the compiler rather than on it. Its first row closed the next day.

### A runtime error names no position — closed (ADR-0293)

The row said sixty-eight trap messages carried no file or line and that the
fix was the compiler passing what it already held. Half right. The inline
checks -- subscript, subrange, nil, `case`, arithmetic -- do hold the node,
and pass the file, line and column as three arguments into the cold block.
The other half is raised *inside* the runtime, which knows nothing about the
source, and a call graph over `runtime/pasrt*.c` said that is **72 of the 127
routines the emitter calls, every `write` among them** through
`pas_check_open`. So every such call is bracketed: a store of a position
record's address into a thread-local word before it, a clear after -- the
clear being what makes a forgotten bracket report *no* position rather than
the previous call's. Three things the row could not have known: the position
has to trail the message, because five harnesses recognise a trap by its
prefix and the sanitizer gate tells this runtime's trap from UBSan's by
UBSan's position coming first; the path cannot pass through the 255-character
message buffer or the string pool, so the file is one constant per module;
and the seed calls the old two-word entry points, which stay as positionless
wrappers until the reseed rather than reading a file pointer out of a register
that never held one. The cost is size and not time -- the compiler's text
+28%, its compile of `apfront.pas` unchanged within noise -- and all 97
goldens gained a suffix and nothing else. Two cases hold it: two subscripts on
one line where only the second column is right, and a `**` whose operand is a
function that makes bracketed calls of its own.

### Tooling — closed (ADR-0300, ADR-0301)

The chapter's Tooling section held two rows and both were struck on
2026-09-03, which empties it. What each cost is not what the row said.

**`codeAction`** was the row that had already been costed: *the four warnings
each know the edit they want — add `protected`, delete the declaration, delete
the statement after the one that leaves*. Two of those three are right and the
third is the one that cannot be done: a variable-declaration's type-denoter
may carry defining-points of its own, `var c: (red, green)` declaring two
constants in the enclosing block (§6.4.2.3), so deleting an unused local's
declaration can delete names the rest of the block still uses. The fourth
warning, a function result written on one path and not another, has no
mechanical edit at all. So the answer is two of four, and the rule that
selects them is that the edit be decidable from what the compiler *reported*
and unable to change what the program does.

**And building it found the warning it acts on was wrong.** §6.7.3.1 puts
`protected` before the whole formal-parameter-section, and ADR-0283 reported
per parameter — so `var b, c: integer` with `b` written through was advised to
take a word that then refuses to compile. ADR-0283's own sentence, *`not
wasThreatened` is precisely the condition under which adding the word still
compiles*, is true of a parameter and false of a section, and no source in
this tree had a mixed section for any oracle to notice. The warning is now a
question about a section, reported once at the section's first token — which
is also the only position the edit can use. Twenty-four `.warn` goldens moved
by the width of `var `.

**`completion`** was *the row with a design in it*, and the roadmap named the
difficulty correctly: the outline gives the names in scope after a parse, but
what may follow a token is the parser's knowledge and `--dump-symbols` stops
before Sema. That sentence holds two questions. The one it points at —
member completion, what may follow a `.` — is not the parser's at all but the
*type* at the position, which is Sema's, and it is refused rather than
deferred. The other, what names are in scope here, is answered from the
outline's own dump filtered by two rules a row cannot state: the block that
declares a name must contain the position, and §6.2.2.9's order must put the
defining-point before it. The second is not a nicety — this compiler refuses a
body naming a variable declared after it, so the unfiltered list offers names
that do not compile.

Two things the compiler had to learn, and both were absences rather than
work. `--dump-symbols` reported **no formal parameter**, though its own
sentence is *every name a source declares*; nobody had noticed, because an
outline is not where a reader looks for one and a completion list inside a
body is nothing else. And the word-symbols and required identifiers had no
reader outside the lexer, so `--dump-words` writes them — walked from
`kwText`, from the outermost scope at the one moment it holds the required
identifiers and nothing the source declared, and from the twelve required
procedures `IsRequiredName` reads. ADR-0294 had refused a word-symbol table in
the server as *correct today and silently wrong on the day a forty-sixth is
reserved*; this is that refusal answered rather than repeated.

The server now answers fifteen methods, three of them notifications.

## What a daily program could not reach for, and now can

`doc/roadmap.md` carried a chapter of this name from version 2 until version
3.2.0, when the last row in it was struck. It is moved here whole, because
what it is now is a record of eight estimates and what trying them cost —
which is history's job and not the roadmap's.

Six of the eight were library gaps and two were absences in the language
itself. Every one is built. The part worth keeping is not the list but its
error rate: **two of the six rows said why they were blocked and both reasons
were wrong**, and the two language absences — the most carefully argued
entries on the page — each hid something a probe found in an afternoon. The
lesson the chapter drew for itself is the one to carry: *a row saying a
feature is blocked is a row nobody has tried, and trying is cheap.*

What follows is the chapter as it stood when the last row closed.

### The chapter as it stood

The chapter above is about what the *language* blocks. This one is about what
is simply not written yet, and it is here because a survey of it was asked for
and the answer turned out to be short and specific rather than vague. Nothing
in it needs a language feature; each is a module somebody has to write, which
is the cheap kind of gap and the kind this page should name rather than imply.

**All six are now written, and the survey's own claim held for every one of
them**: not one needed a language feature, TLS included — it binds through the
FFI that already existed, and the whole of what the compiler had to gain was
ADR-0263, a defect the probe walked into rather than a feature it needed. So
the chapter's opening claim held for all six, and **two of its stated reasons
did not**: the hash row named a constraint the dialect lacks and needed none
(ADR-0260), and the TLS row named ADR-0185 and a runtime dependency and needed
neither (ADR-0263, ADR-0264). Each probe took under half an hour against an
estimate that had stood for months. The lesson is not that the estimates were
careless — they were written by someone holding the same evidence — but that
**a row saying a feature is blocked is a row nobody has tried**, and trying is
cheap.

**This whole chapter is struck through now — the table, and the two absences
under it — and nothing replaced any of it.** The last thing the table named,
that `PasHttp` wrote to a socket and so spoke plain HTTP only, is done too
(ADR-0265). The two language absences went last and went differently: generic
constraints landed on a reason this page had already narrowed twice
(ADR-0266), and concurrency was **built to a design settled four increments
before a line of it was written** (ADR-0201, ADR-0268) — under an instruction
to build it rather than because ADR-0116's bar was met, which its own record
says in as many words.

So this section is a record and not a queue, and what it records about the
estimates in it is the part worth keeping. Six rows said something was
missing; two of them said *why* it was blocked and both reasons were wrong;
and the two language absences, the most carefully argued entries on the page,
each hid something a probe found in an afternoon — a category read off the
wrong predicate, and a share-nothing rule that a nested block's ordinary
scope walked straight through.

**What a daily program still cannot reach for is, as this is written, nothing
this page has thought of.** That is not the same as nothing. The next entry
will come from somebody writing a program rather than from somebody reading
this list, which is how every entry that closed well got here.

**Thirty-one modules exist** — eight conforming and twenty-three dialect,
listed by name in `README.md`'s module table. What a program written today reaches for
and does not find:

| Missing | What exists instead | Why it is not built |
| --- | --- | --- |
| ~~**JSON**~~ | **Done** — `lib/dialect/pasjson.pas` parses, navigates, builds and renders, and `tests/dialect/lib_json.pas` runs all four | It was the one gap here with a named client and it needed no language feature, as this row said. Two things it guessed wrong. A value is a variant record over the seven kinds — right — but a string is **bytes**, not AP 6.4.15's `utf8`: assignment to a text establishes normal form C, so round-tripping somebody's source file through it would edit their document, and `utf8` stops the program on ill-formed bytes where a parser must report. And the tree is plain pointers with `JsonFree`, not owned ones: AP 6.4.14.3 gives an owned pointer no copy, so `JsonMember(doc, 'params')` could not exist and navigation is the whole job. What it *did* need was ADR-0216 — it is the first module in the library to instantiate a generic imported from another, and until that fix the component linked to nothing |
| ~~**date and time**~~ | **Done** — `lib/dialect/pastime.pas`, and `tests/dialect/lib_time.pas` runs it | A serial day count both ways, signed arithmetic on it, day-of-week, an ISO 8601 form written and parsed, and a UTC offset shift. `TimeStamp` stays the currency, as this row expected: a second date type would mean a conversion at every call from a program that had asked the clock. **No C**, and the reason is the useful part — a local zone needs `struct tm`, which ADR-0185 refuses a library, and a `pasx_` route was declined twice over: the answer would be one no oracle here could contradict (a test could print it only by asking the same routine), and `GetTimeStamp` already samples the clock *in local time* on this processor. What a program lacked was arithmetic, not a wall clock. A zone beyond one stated offset is a transition database no module can carry |
| ~~**terminal control**~~ | **Done** — five `pasx_` routines and `lib/dialect/pasterm.pas` (ADR-0262) | Its shape was decided and held: a binding in `runtime/pasrt_posix.c` bounded by its headers, `<termios.h>` and `<sys/ioctl.h>` joining ADR-0186's catalogue. What the shape did not say is **where the saved settings live**, and that is the record: in the runtime, because a caller cannot hold a `struct termios` at all — which is the whole reason C is involved — and in *one slot* rather than a table, because a second `EnterRaw` would save the raw settings as the original and leave the user a shell with no echo. Restoring at exit is the runtime's for the same reason: raw mode is a property of the terminal, not of the process. Cursor and clearing stayed out of C, being escape sequences rather than syscalls. **What no test can assert** is raw mode itself — ctest has no terminal — so the case asserts the negative path and `doc/sop.md` §7 carries the rest |
| ~~**regular expressions**~~ | **Done** — `lib/dialect/pasregex.pas`, a Thompson NFA simulated by a Pike VM | This row said it was "the only one where the right answer is not obvious — a backtracking matcher and a DFA are different programs with different failure modes", and the answer turned out to follow from something this page already believes. **This project traps rather than degrades**: a subscript out of range, integer overflow and a `case` with no matching label all *stop the program*, and each is a bound. A backtracking matcher has no bound of that shape — against `a?a?a?a?aaaa` and its longer kin it does not fail, does not report and does not return — and **no oracle here can see that**, every gate comparing what a program printed and a program that has not finished having printed nothing. A failure mode this tree is structurally blind to is one it must not acquire. The bound is stated and asserted rather than believed: steps ≤ 2 × program × (subject + 2), with `RegexSteps` and `RegexLength` exported so a caller can check it. Back-references are refused outright, not being a regular language. A DFA is named in the module as what to reach for if this is ever measured and found wanting; its worst case moves into *space*, and it cannot report where a submatch began |
| ~~**HTTP**~~, and ~~**TLS is a module somebody has to write**~~ | **Both done** — `lib/dialect/pashttp.pas` over `PasNet`, and `lib/dialect/pastls.pas` over OpenSSL (ADR-0264) | HTTP was "a module over what exists", and is: request forming with validation, status line and field parsing, case-insensitive lookup, `Content-Length` and chunked, every overflow `errFull` and never a truncation. Two limits it *states* — a body is lines, `PasNet.ReadLine` being the only reader the library has; and chunked over CRLF data is `errSyntax` rather than a wrong body. Redirects are not followed, the hop count and whether `Authorization` survives a cross-origin hop being policy a module cannot be right about. **And TLS is where this row was wrong twice.** It said TLS "means binding a C library, which puts the *whole* of that library's surface behind ADR-0185's rule that a library may not declare a foreign struct", and a later revision added that the runtime would have to link it. Both were asserted without a probe and both are wrong: OpenSSL's API is opaque pointers throughout, which is AP 6.4.12's handle exactly, and the **program** links, not the runtime. What the module needed from the compiler was nothing; what the probe *found* was ADR-0263. **What it needed instead was a decision and a gate.** The decision: verification cannot be turned off — no flag, no mode, no second entry point — because the commonest way a TLS client comes to accept anything is a flag somebody set while debugging, and a self-signed certificate is its own trust anchor, so `ConnectTrusting` reaches a test server without a hole in the rule. The gate: six of the values handed to OpenSSL are **transcribed from headers**, each being a macro this language cannot reach, and `SSL_VERIFY_PEER` written as 0 would leave verification off with every case still green — so `tests/checks/tls.sh` compiles a C program against the real headers and diffs them, which is `foreign-layout`'s shape applied to numbers. **And the refactor this row named is done** (ADR-0265): `PasHttp`'s grammar is exported and has no transport under it, `Send` and `Receive` over a socket are twelve lines over it, and `lib/dialect/pashttps.pas` is twelve more over a TLS connection. The reason it is a second module and not a branch is the one this row gave — a module choosing between transports imports `PasTls`, and then every program using plain HTTP links OpenSSL. Nothing is left of this row |
| ~~**a hash of anything but a string**~~ | **Done** (ADR-0260) — `PasContainer`'s `Map` takes its key type as a schema argument | **And the reason this row gave was wrong.** It said a generic map waits on "a way to say that a key can be hashed and compared — the second being a constraint, and the dialect has none". It needs no constraint: §6.7.3.4 has admitted a procedural parameter since ISO 7185, `PasSort` has used exactly this shape since it was written *precisely so it never sees an element*, and a formal procedural parameter may be handed on as another generic routine's actual — which is the whole of what a hash table's internals need. A constraint would buy the two arguments per call, not the capability. Two features that landed for other reasons make even those cheap: the key's type is `type of m^.slots[1].key` (ADR-0215), read off the map rather than named again, and AP 6.7.3.10.4 infers the rest (ADR-0254). **It also uncovered a compiler defect** — `ForgetResolved` walked past a procedural parameter's own formal list, so a second instantiation read the first's types — which nothing could have found before, the omission being invisible unless a procedural parameter's type depends on the tuple. Found by writing the client, which is ADR-0116's whole argument |

**And two absences in the language rather than the library — both now built**,
which leaves this chapter with nothing open in it at all:

- ~~**Concurrency.**~~ **Built** (ADR-0268), and built as ADR-0201 designed it
  four increments earlier: `task`, `spawn`, `channel [n] of T`, `send` and
  `receive`, share-nothing, with no word-symbol reserved and every spelling in
  one of the three free positions that record itself listed. **ADR-0116's bar
  was not met and is not claimed to be** — nothing in this tree wants it, and
  the four times something looked as though it did, something cheaper answered
  and is recorded above. What the four-increment delay bought is that the
  design was settled before a line was written, and the two things that had to
  be discovered were discovered by probes rather than by argument: the formals
  rule is **not** the whole of share-nothing, because Pascal's scope rules let
  a nested block name an enclosing one's variables and four tasks incrementing
  one global printed the right answer three times out of three (AP 6.7.8.2);
  and the runtime's per-activation bookkeeping had to become thread-local,
  which **ThreadSanitizer** found on the first run of the first two-task
  program and which no golden could ever have held. That second one forced the
  first reseed outside a release, the arena's cursor being a name the emitted
  module carries. What is still not here: a task cannot be *given* a handle
  (AP 6.4.12.7's move exists and the argument block does not use it), there is
  no way to wait for one task, no select over several channels, and no
  timeout. See the concurrency row in
  [where the ideas come from](roadmap.md#where-the-ideas-come-from).
- ~~**Generics have no constraints**~~ — **done** (ADR-0266,
  AP 6.7.3.10.5), and the row is worth reading for how much smaller it got
  before it closed. The generic map was filed behind constraints and needed
  none (ADR-0260): a key's hash and equality are procedural parameters, which
  every Pascal has had. What was left was the *diagnostic* — a body that adds
  its `T` values was refused at the instantiation, in the generic's own
  source, three lines of it, and ADR-0259 had made the last of those three
  name the activation. So what landed is one line at the call instead:
  `function Sum(Elem: numeric type; a, b: Elem): Elem` refuses
  `Sum(Point, p, p)` where it stands, saying that `numeric` admits integer,
  int64, real, complex or a subrange of one. Four categories, `numeric`,
  `ordinal`, `ordered` and `equatable`, each a group of operators the language
  already defines; spelled between a parameter's colon and the word `type`,
  which reserves nothing (ADR-0140), so a program may still declare a variable
  called `ordered`. **It does not make a generic separately type-checked**:
  AP 6.7.3.10.2 still reads the block once per tuple, and a body that misuses
  a type its category admits is caught exactly where it was. Inference is
  **done** too (ADR-0254,
  AP 6.7.3.10.4): `Swap(i, j)` reads as well as `Swap(integer, i, j)` and
  means the same activation. The question this row carried — *what happens
  when two arguments imply different types* — turned out to dissolve rather
  than need an answer: the first determining position binds the parameter and
  every later actual is an ordinary actual of a formal that now has a type, so
  §6.4.6 judges it where it judges every other one and **no new diagnostic was
  needed for the conflict case at all**. `ValueOr(st, 'none')` is the case
  that decides it, `'none'` being assignment-compatible with the `string(8)`
  the first argument implied rather than a second opinion about it. What a
  category still cannot be is a program's own predicate, and nothing has asked
  for one.

---

## What would make this easier to work on

`doc/roadmap.md` carried a chapter of this name from version 3.1.0 until
version 3.2.0's successor, when the fifth and last of its items closed. It is
moved here whole, for the reason the chapter above was: a list with nothing
open in it is a record and not a queue.

It was the one chapter on that page proposed **without a client demanding
it** — every other entry there answers ADR-0116's test, and these five
answered a person rather than a program. The page said so at the time and
called it a weaker warrant. What the five closings say about that warrant is
worth more than the list:

**Four were built and the fifth had never been open.** The formatter
(ADR-0279, ADR-0280) was the largest and behaved like an ordinary feature. The
profile (ADR-0270, ADR-0271) found that the lexer cost five times the parser,
which nobody would have guessed, and that the change anyone reaches for first
was worth 2.6% where the one nobody thinks of was worth 31%. The warnings
(ADR-0272, ADR-0277, ADR-0278) found twelve dead declarations, five deliberate
dead statements and one `done` flag standing where an `else` belonged. The
four blind spots were closed by ADR-0261, ADR-0269, ADR-0274 and ADR-0275, and
the fuzzing one **found no crash**, which is the unusual outcome.

**The fifth is the one to carry.** *The suite is 262 seconds* was true of a
configuration nothing used: it was measured serially while CI had run
`-j"$(nproc)"` on every push since the workflow was written, and the answer
was a flag worth 3.4× (ADR-0281). The chapter opens by insisting that a figure
here is a reading with a date on it — and this figure had a date, had been
re-measured twice, and was still wrong, because nobody had checked whether the
*command* beside it was one anybody ran. A date on a number is not enough; the
number has to be of the thing being decided about.

**And two of the five items were re-scoped by their own measurement rather
than by an argument.** `--dump-uses --at line:col` was asked for and the
measurement closed it the other way — the flag saves no compiler time, and
narrowing the query would have cost ADR-0252's cache, measured at five hovers
going from 795 ms to 159 (ADR-0276). The `protected var` warning was probed,
found 81 real sites, and was **not built**, because §6.6.3.6's congruity makes
the fix illegal for a routine passed as a procedural parameter and no single
component can know whether an exported one ever is.

What follows is the chapter as it stood when the last item closed.

### The chapter as it stood


The chapter above is about what a *program* written in this language cannot
reach for. This one is about what someone *working on the compiler* does not
have, and it is separate because the two have never competed for the same
hours: every gate, oracle and sweep in this tree serves correctness, and
almost nothing serves the loop a person actually sits in.

Five items, in the order I would take them, and **all five are now closed** —
four by building something and the fifth by discovering that it had never been
open. What is left of the chapter is what each closing found, which is worth
more than the list was.

Every number below was measured on 2026-08-31, or on 2026-09-01 where the last
item re-took one, and the command that produced it is named — because the
first version of this chapter quoted seven figures taken incidentally while
building the language server and **six of them were wrong within two
releases**, the suite's duration by a factor of three. A figure here is a
reading with a date on it, and re-reading it is cheaper than trusting it.
**That rule is not enough on its own**, which is the last item's finding: its
figure had a date and was re-taken twice, and was still wrong, because what
was never checked was whether the *command* beside it was the one anybody ran.

- **There is a formatter now** (ADR-0279), and it was the largest gap by
  developer-time. `pascalc --format` writes a source back out with a layout of
  its own: the same tokens in the same order, the same comments in the same
  places, and nothing else the same.

  **The language server had done the hard half without meaning to.** ADR-0258
  makes the parser report where every statement begins and ends and ADR-0253
  does the same for every declaration, so the structure was emitted already;
  what was missing was *trivia*, the lexer consuming a comment and never making
  it a token. That is what the increment built, and the shape of it is the part
  worth carrying: **a position is recorded and never text.** The corpus holds
  1 881 326 characters of commentary against the 449 278 the pool has free, so
  this chapter's own warning was that trivia would go in the one array whose
  headroom is measured — and it goes in no array at all. Whatever wants the
  characters reads the source a second time through a cursor, which is also the
  only way to recover an *identifier's* text: the pool holds the folded
  spelling, and a formatter that lowercased every name would be worse than
  none.

  It is recorded **only when something asks** — `--format`, `--dump-trivia` and
  `--dump-limits` — so an ordinary compilation writes no table, checks no bound
  and cannot fail for a reason it could not fail for before.

  **The verification is the interesting half.** `format-check` makes three
  claims over every tracked source and the first is the whole semantic one: the
  token stream must be unchanged but for positions, and that is not a sample of
  what could go wrong, because the parser sees the token stream and nothing
  else. Two sources with the same token stream compile to the same program by
  construction. The comments must be unchanged word for word and still stand
  before the same tokens, which is the only claim that catches a dropped or
  reordered comment. And formatting the output again must return it byte for
  byte, which is the claim about the *rules* and not about a run of them. 774
  of 783 sources pass all three; the nine the lexer rejects have no token
  stream to preserve.

  What none of the three says is that the output is *well* laid out. There is
  no oracle for that, `tests/dumps/format.pas` is the substitute, and
  **nothing in this tree is formatted by it** — the tree has no agreed Pascal
  style and this does not create one.

  **The first of the three things it was meant to pay for is built**
  (ADR-0280): the server answers `textDocument/formatting` by running
  `--format` over the scratch file it already writes, and returns one edit over
  the whole document rather than a diff — the formatter's output is a whole
  file by construction and nothing in it says which part of the input any part
  came from. A source the lexer rejects is answered with no edits, which is
  what an editor expects of a formatter that could not read the file.

  Two remain. `textDocument/rangeFormatting` needs a formatter that can be
  asked about *part* of a file, which means telling the token-stream printer
  where to start its indent from — a question about the enclosing structure
  that only a parse can answer. And a `style:` gate for the Pascal of the kind
  `git clang-format` gives the C is a policy this tree has not chosen.

- **The compiler has been profiled once, and the answer was a surprise.**
  The baseline this item asked for is ADR-0270's `benchmark`, and the profile
  it produces needs no profiler: each `--dump-*` stops at the stage it names,
  so four measurements and three subtractions separate the stages. Over
  `selfhost/apfront.pas` — 24 206 lines, plus the 4 295 of ApTypes its
  translation reads — a 378 ms compile is

  | stage | ms | share | after ADR-0271 |
  | --- | --- | --- | --- |
  | lexing | 99 | 26.2% | 66 ms, 19.3% |
  | parsing | 19 | 5.1% | 19 ms, 5.5% |
  | Sema | 90 | 23.9% | 89 ms, 26.0% |
  | the code generator | 169 | 44.9% | 169 ms, 49.2% |

  **The lexer cost five times the parser**, which nobody would have guessed,
  and the fourth column is what came of measuring it. `LookupKeyword`
  recomputed the padded length of all forty-five word-symbols for every
  identifier in a source — a fact fixed when the table is built — and
  precomputing it took a third off lexing and 16% off a compile of
  `compiler.pas`. The **split** is the part to carry: the padding trim was 31%
  of lexing, and stopping the scan at the match, which is the change anyone
  reaches for first, was 2.6%. Guessing would have got that backwards.

  What the gate commits is *proportions* and not milliseconds, so a slow
  machine moves nothing; it catches a stage made about a third slower and says
  which one, and it cannot see a compiler slowed uniformly everywhere.

  **The other half of this item asked for `--dump-uses --at line:col`, and the
  measurement closed it the other way** (ADR-0276). Over `apfront.pas` the
  dump is 170 ms piped and 170 ms discarded — writing and transferring
  1 601 668 bytes is *within noise*, because the 170 ms is Sema and the flag
  stops there instead of running the code generator, which is why it is half
  of a 345 ms compile. So `--at` saves no compiler time at all.

  What it would save is the server's parse of 38 569 lines into 259-byte slots
  and the ~10 MB that holds. What it would **cost** is ADR-0252's cache: the
  dump is kept per document exactly so the second question is free, and a
  query narrowed to one position cannot be. This item's premise — *nobody
  chose that; it is what "dump everything" costs* — was wrong. It was chosen,
  and measured at five hovers on `apfront.pas` going from 795 ms to 159.

  If the memory becomes the complaint the answer is a tighter cache — the
  longest `use` line in this tree is 62 characters and each is held in 259
  bytes — and not a per-position query. **Measuring it found something else
  instead**: the server stopped on any document of a million bytes or more,
  and `selfhost/apfront.pas` is 992 056 bytes.

- **A diagnostic can now be something other than an error, and one is**
  (ADR-0272). `WarnAt` stands beside `ErrorAt` and the only difference is
  `errorSeen` — same format, same stream, same exit status — so the category
  *this compiles and is probably wrong* exists where it did not.

  The first is **a local variable declared and never used**, and it found
  twelve dead declarations in this compiler on its first run, six of them in
  one `var` line. Across the rest of the corpus it is 24 warnings in 11 files
  of 765, which is the volume that says a flag to turn warnings off has no
  caller yet.

  It also cost a sidecar and uncovered a hole. `name.warn` had to be invented
  because neither `.out` nor `.err` can hold a remark made by a *successful*
  compilation, and its second half — a case without one must produce **none** —
  is what stops a warning added later from appearing on dozens of green cases.
  The hole is `diagnostic-coverage`'s, and it is in the entry below.

  **The second is a statement after one that leaves** (ADR-0277), and it was
  the smallest of the four that remained: the other three are questions about
  what a *body* does over all its paths, and this one is a property of a
  statement-sequence. Five statements leave — `goto`, `halt`, `exit`, `break`
  and `continue` — and it is deliberately not a flow analysis, an if whose two
  arms both leave being a lattice over the whole tree rather than a test on a
  tag.

  It found **five dead statements in the 779 tracked sources**, in four files,
  and every one is deliberate: `tests/goto.pas`, `tests/dialect/exit.pas`,
  `tests/extended/required.pas` and `tests/dialect/components/exit_counter.pas`
  each exist in part to prove that what follows a transfer does not run. So it
  bought three `.warn` sidecars, which is the gate working, and no fix.

  What it found that was not dead code is **the hole this item's own first
  entry left**: no source under `tests/dumps/` warned at all, so dropping the
  `warnOn` guard from *either* warning left all 790 cases green.
  `tests/dumps/warnings.pas` is now a program the compiler would warn about
  twice, and its golden fails for either.

  **The third is a function that writes its result on one path and not
  another** (ADR-0278). §6.7.2 requires a function-block to write its result at
  least once and the compiler already reported a body that never did; nothing
  asked whether the one assignment stands where every path reaches it. A
  sequence answers yes as soon as one statement does, an if needs **both** arms,
  and a case needs every arm and the completer unless it has none — §6.9.3.5
  stops the program when no label matches, so a path that returns took an arm.
  A `goto`, §6.8.2.2's *nested* assignment and §6.7.2's
  result-variable-specification each silence it, and each is a case the walk
  cannot decide rather than one it decides in the program's favour.

  It found **one** thing in 779 sources and it was in this compiler:
  `ResolveRestricted` carried a `done: boolean` between two if-statements where
  the second was the first's `else`. Every path did write the result and the
  correlation between the flag and the assignments is not in the tree. Two more
  sites were found and answered by the analysis rather than by an exception —
  `repeat … until false`, which is never left by falling out of it, is now a
  yes; and a `for` with constant bounds is deliberately not folded, because
  doing that soundly needs a scan for `break` and one `.warn` sidecar is a
  cheaper true statement than a second analysis.

  **The fourth was measured and is not built.** A `var` parameter never written
  through would be spelled `protected var`, and the probe found 111 sites in 53
  files — of which §6.4.1's own `Protectable`, a predicate the compiler already
  owns, strikes 30, a file or a pointer being unprotectable, so without it the
  warning would have advised what the compiler refuses. Of the 81 left, 32 are
  in the compiler, the server and the library and every one is right. What
  stops it is that **the fix is not always legal and no component can tell**:
  §6.6.3.6's congruity compares the formal-parameter-lists with `protected` in
  them, so a routine passed as a procedural parameter cannot take the word —
  `selfhost/badsema/procparams.pas`'s `ByRef` is that case here — and whether
  an *exported* routine is ever passed that way is a whole-program question.
  The sound version warns only for a routine neither exported nor passed as a
  procedural actual in its own component, which needs warnings deferred to the
  end of a compilation rather than written where they are found; that is a
  change to ADR-0272's discipline and wants a record of its own.

  **One remains sayable and unsaid**, and it is the one this list already
  doubted: an unused import, which is *not* obviously a mistake here, §6.2.3.6
  commencing a supplying module before the program-block, so importing purely
  for a `to begin do` part is meaningful and the warning would need to know
  better.

- **Four blind spots, and all four are closed.** This bullet is struck
  through; what is left of it is the record of what each closing found, which
  is worth more than the list was:

  *A branch was invisible, and ADR-0274 closed it.* This item asked for "a
  counter per arm", and that was the wrong shape: the arms already have
  counters, being statements. The defect was the **identity** — one line — and
  it hid three ordinary constructs, not one. Two statements on a line collapse
  into a single counter; a decision with no else-part has nothing on its false
  side to count at all; and a short-circuit operator's right operand is an
  expression, so no statement counter for it exists in the first place.
  `--coverage` now emits a second counter on each edge of every decision the
  *source* writes — an if, a while, a repeat and each `and`/`or` — keyed on
  line **and column**.

  The denominator nobody knew is **5050 decisions, 10 100 directions, of which
  9247 are taken** — 91.6%, against 97.9% of statements. And the overlap is the
  number that says whether the instrument was worth building: **784 of the 853
  untaken directions sit on lines statement coverage calls covered**, and not
  one of those decisions was unreached. Every one was evaluated, and only ever
  went one way. 92% of what this finds, nothing else here could express.

  Two things were learned in the building and are worth carrying. The untaken
  direction needs a block **of its own** in three of the four cases — a while's
  exit is where `break` lands, a repeat's body is entered before the first test,
  a short-circuit's join is reached from the evaluated side — and sharing one
  gives a wrong answer that looks like a working instrument. And a ratchet
  cannot see a *miswired* counter: making both edges of an if report the same
  direction collapses the pair, drops the denominator from 10 100 to 6995 and
  reports an **improvement**. What catches that reads the IR rather than the
  sweep, and is the half of the gate that fails in both directions.

  *A dump's exit status was read by nothing, and ADR-0269 closed it.* The
  coverage sweep drove `--dump-all` over every source and read the lines
  reached, never the child's status, which is how `--dump-sema` crashed on
  every program declaring a fallible-type for three days and 714 green cases.
  `sweep()` now reports every invocation the compiler did not survive — a
  signal, or `runtime error:` on standard error, which is what separates a
  trap from the exit 1 a third of this corpus is written to produce — and
  mutating `Tokenize` to store 3 into a `1..2` names 1426 of 1435 invocations
  where the whole suite was green before. The row had named its own fix and
  sat for five records.

  *The third was that nothing runs the runtime under a sanitizer, and
  ADR-0261 closed it.* `sanitizers` is a ctest case and a CI job: the corpus
  again under AddressSanitizer, UndefinedBehaviorSanitizer and LeakSanitizer,
  over a second `libpasrt.a` built with the same flags — 286 programs clean.
  It is the most expensive gate here after the fixed point, at 49.8 s. **It
  had never passed on CI until 2026-08-30**, `debian:trixie` and
  `ubuntu:24.04` shipping a `clang` without compiler-rt, so every
  `-fsanitize=address` link failed and the harness counted 516 silent skips;
  its own floor caught it, `libclang-rt-dev` fixed it, and the harness now
  prints the first build failure rather than only a count.

  *Nothing fuzzed the front end, and ADR-0275 closed it.* Every corpus here is
  hand-written and so tests what someone thought of; a hand-written lexer and
  parser over **fixed buffers** (ADR-0012) is the canonical target for the
  other kind. `fuzz` truncates real sources at every byte, generates one input
  per fixed buffer and per depth limit, and mutates the corpus from a fixed
  seed — fixed, so that what runs in the suite is a regression corpus of
  hostile inputs and not a search, `--long` being the search.

  **It found no crash**, over 3128 inputs in the suite and 41 628 in a
  campaign, and a first fuzzing run finding nothing is the unusual outcome.
  What it did find were two things a generator sees and a person does not. An
  **argument standing in for a case**: `too many tokens` and `out of string
  space` were excluded from `diagnostic-coverage` as "capacity limits, not
  diagnostics about a program being compiled", and both carry a file, a line
  and a column — they had no golden because no case had ever reached one, and
  reaching one takes 300 KB of semicolons or 1.2 MB of distinct identifiers.
  And a **quadratic**: `Declare` scans the scope, so *n* declarations in one
  block cost *n²*, which is 14 seconds for 32 000 and about 80 for the 75 000
  `tokMax` admits. That one is a §7 row rather than a fix — it is a
  performance property, not a crash, and no block a person writes is near it.

- **The suite was never slow; the instructions were** (ADR-0281). This item
  said 262 seconds and named the three gates that were 60% of it, and every
  sentence of it was true of a configuration **nothing uses**. It was measured
  with `ctest --test-dir build --output-on-failure`, which is what `CLAUDE.md`,
  `README.md`, this file and four of the skills told a reader to run;
  `.github/workflows/ci.yml` has passed `-j"$(nproc)"` in every job since
  `a544d67` wrote the workflow on 2026-08-14. So the suite has been run in
  parallel on every push for the life of the workflow and serially by every
  person following the documentation, and nobody had compared the two.

  290 s serially, **86 s at `-j12`**, 93 s with `--schedule-random` on top —
  all 795 green in each, which is the answer to the question the item was
  really asking. The shuffled run is the one worth having: order is not a thing
  this suite depends on.

  **What makes it safe is not luck**, and two of the three mechanisms were put
  there by someone thinking about concurrency without saying so. Every harness
  here works in a directory it created for the run — 31 of the 48 call `mktemp
  -d`, `mkdtemp` or `TemporaryDirectory`, and the other 17 are read-only
  analysers. A port is asked for and not assumed: the socket cases `Listen(srv,
  'localhost', '0')` and `tls.sh` scans a range for one that will take a
  server. And `lsp/run.sh` gives each server its own `TMPDIR`, with a comment
  saying why. One harness did not hold the property and now does —
  `format_check.py`, ADR-0279's, the newest here, which is how a convention
  stops being one.

  **The obvious repair is a regression**, and that is the lesson rather than
  the number. Three gates are internally parallel with `os.cpu_count()` workers
  and declare nothing, so `-j12` oversubscribes twelvefold through each;
  declaring `PROCESSORS` was written, measured at **107 s against 86**, and
  reverted. The wall clock is set by `sanitizers` and `selfhost-codegen`, which
  are *internally serial* — the fixed point is six compilations of the compiler
  in a dependency chain — and the oversubscribing gates are exactly what keeps
  the other ten cores busy while those two run. The floor is about 71 s, being
  the two poles overlapping plus the five seconds `benchmark` spends alone
  because its answer is a duration. 86 is within 20% of a floor no scheduling
  change can move.

  So the item closes at a flag, and the thing it was least sure repaid the
  effort turned out to cost one line in seven documents. What it should have
  doubted was not the value of the work but **the measurement**: this chapter
  opens by saying that a figure here is a reading with a date on it, and this
  one had a date and the wrong command.

**What the list is not.** None of these is a language feature and none of them
changes what the compiler accepts, which is why they sit apart from every
other chapter on this page. They are also the first items here proposed
without a client demanding them — ADR-0116's test is a demand, and the demand
in each case is a person rather than a program. That is a weaker warrant than
this page usually requires, and it is stated rather than hidden.

### The three rows that came back, and how each closed

The chapter above was moved here when its fifth item closed, and three rows
were then written into the stub that replaced it. All three closed within one
release, and the way they closed is the chapter's own lesson met a third,
fourth and fifth time: **a row saying a feature is blocked is a row nobody has
tried.** Two of the three were built and the third talked the page out of
itself, which is the first time an attempt here answered *no*.

- **A warning for a `var` parameter never written through** — **built**
  (ADR-0283, the fourth warning). The row said §6.6.3.6's congruity makes the
  fix illegal for a routine passed as a procedural parameter, and that no one
  component can know whether an exported one ever is. Both are true, and
  neither blocks the warning: the answer is to *defer* it — record candidates
  in `CheckProcBody`, emit after `CheckMutualSupply` — which is one page of
  code. The estimate under it said 111 sites and 81 after `Protectable`, and
  the number turned out to be a **fixed point rather than a count**: §6.5.1
  exempts a protected formal from being threatened, so protecting one
  parameter stops its callers' arguments from being threatened and exposes the
  next layer. One pass over this tree reports 130 and seven passes report
  zero, having added `protected` **54 times**. A one-shot count under-reports
  by a factor of five. Every round rebuilt clean, which is the evidence the
  advice is right: the word is enforced, so a wrong claim is a compilation
  error and 54 were accepted.

- **`textDocument/rangeFormatting`** — **built** (ADR-0284), and the row was
  wrong about why it was hard. It said the printer had to be *told* where its
  indent begins, a question only a parse can answer. The printer accumulates
  that depth itself as it walks the token stream, so the lines before a range
  are walked with the sink closed and the depth on arrival is the depth the
  whole-file format would have. The whole feature is a gate on `FmtPut` and
  `FmtNewline`. What it also settled is a property the row had assumed: a
  range's *layout* cannot be compared with the whole file's, because a
  boundary inside a construct forces a break there — so the gate's claim is
  the semantic one, that the token stream on those lines is unchanged, and
  `tests/dumps/format_range.pas` pins the layout instead.

- **A `style:` gate for the Pascal** — **tried, measured and declined**
  (ADR-0285), and it stays in the roadmap because it is a decision rather than
  a closed item. What the attempt was worth is **five layout defects**, each
  of which preserves the token stream and so was invisible to `format-check`
  and to every other oracle here: a blank line inside a parenthesised list
  dropped the rest of it to column zero; a comment introducing an `else` took
  the indent of the arm above it, which in a tree this comment-dense is nearly
  every second branch; `^` was glued to what preceded it, right for a
  dereference and wrong for a pointer-type; `!` took a space on one side of a
  binary operator; and the empty statement after a case-label lost its space.
  All five are fixed and `tests/dumps/format.pas` holds all five shapes.
  **Fixing them did not shrink the reformat** — 24 490 lines to 25 070 —
  which is what settles the gate: the diff is a disagreement about style and
  not a list of bugs.

The stub as it stood, with the two rows above still struck in place, is the
version `doc/roadmap.md` carried between v3.2.0's successor and v3.4.0.

---

## What each landed feature left open

`doc/roadmap.md` carried a chapter of this name from the FFI increments until
2026-09-01. It was called *What blocks the library* first, and was renamed
when nothing was left of the list that named it: every row a survey of daily
needs had put there was struck, and what stood in their place was the residue
of the features that had closed them.

That residue is now struck too, and the chapter is moved here whole. What
replaced it in the roadmap is the residue of the **concurrency** increment
(ADR-0268) — three rows the record named itself rather than letting the
feature imply them — plus the one FFI shape that never found a client.

**Two of the chapter's rows closed after it was last read**, which is worth
marking because the page did not notice for two days. `to hand an owned value
to something else` said `take` is refused for a handle *in as many words*, and
ADR-0267 widened it: a handle is one word of the runtime's exactly as an owned
pointer is one word of the heap, and the reason neither may be copied is the
reason both need a move. The refusal was over-broad by one kind and nothing
had noticed because nothing had wanted it. And the concurrency row of
[Where the ideas come from](#the-concurrency-row-and-the-four-cheaper-answers)
was still reading **unblocked and unbuilt** when ADR-0268 had built it.

**What the chapter is worth keeping for is its prior**, arrived at over five
increments and stated last: *before recording that something waits on the
memory model, ask whether the address can be retired at the call.* Five times
running it could — ADR-0122, ADR-0123, ADR-0184, ADR-0187 and `getaddrinfo`'s
chained list — and twice the answer was not a language feature at all but a
`pasx_` routine doing the walking on the far side. The factory (ADR-0255) is
the first item where the prior does not apply, which is what makes it a prior
and not a rule: a factory's whole point is that the callee's answer *outlives*
the call.

### The chapter as it stood

**This chapter was called "What blocks the library" and is renamed**, because
nothing is left of the list that named it. Every row a survey of daily needs
put here has been struck, and the last of them went the way the two before it
did — a decision that looked like it needed the memory-safety model turned out
to need it for only part of its surface.

What stands below is a different thing: **what each landed feature left open
behind it**. The two things the handle opened, both since struck within two
days of being written down; the move a k-way merge would have liked; the
routine half of the schema's type discriminant. None is a gap a survey found —
each is a consequence of a feature landing, which is the shape to expect from
here on. This page empties faster than it fills, and a landed feature is both
the commonest way it fills and, one increment later, the commonest way a row
leaves it.

**One row here is a compiler item and not a library one**, and it is stated
under the move below rather than in a heading of its own, which is where
nobody will find it: `function Open(p): Stream ! ErrorCode` is refused by a
*representation* choice — a fallible-type's two arms share storage, as a
variant part's do — and changing that reaches four gates and the emitted
struct shape. It is the only thing on this page with a named cost.

~~A foreign struct the callee owns~~ is **done** (ADR-0187, AP 6.7.7.8): an
`external` function may answer an optional of a record, a null address is the
absent value, and any other address yields a **copy** made where the call
occurs. That is the whole of it, and choosing a copy is what kept the model out
of it — nothing holds the address, so there is no lifetime to reason about.
`readdir`, `gmtime` and `localtime` are declarable. What is still not
declarable is a member that is *itself* a pointer, so a chained list of structs
cannot be read by a Pascal program.

**The example this sentence used to give has been answered, and by the same
move that answered the four below it.** It said `getaddrinfo` waits, and on
the memory model rather than on a clause. `getaddrinfo` is *called* — in
`runtime/pasrt_posix.c`, behind `<netdb.h>`, one of the six headers that unit
is bounded by — and `PasNet` crosses a host and a service as **strings** at
both ends so that the chain never reaches Pascal at all (ADR-0203). `PasDir`
did the same thing first: a library may not declare `struct dirent` under
ADR-0185's fifth decision, so the runtime supplies the one member access
(ADR-0188). Twice now the answer has been *arrange for nothing to hold the
address*, which is this chapter's closing lesson applied before the row could
be believed.

So what is left of the row is a **shape without a client**: no program here
wants a chained struct badly enough to have been written, and the two that
looked as though they would were answered in C. By ADR-0116's rule that is not
a thing to build. What would move it is a probe — a program that wants such a
chain and cannot get it through a `pasx_` binding — and writing one is how the
four estimates below were found to be wrong.

**And a rule this page had not noticed cuts across all of it** (ADR-0188).
ADR-0187 is a *program*-level feature: a program knows what it was built for
and can have its field list checked by `foreign-layout`, and a **library**
cannot, ADR-0185's fifth decision being categorical. `struct dirent` differs on
glibc and macOS and POSIX does not fix its member order; `struct tm` is
standardised by ISO C and *that clause* does not fix its member order either.
So the set of structs `lib/` may declare is close to empty, and a module
wanting one asks the runtime — which is how `PasDir` was built, and why the row
below closed without using the record that unblocked it.

~~The struct with a layout~~ is **done** (ADR-0184, AP 6.7.7.6.2), and the
sentence that stood here — *crossing one needs the compiler and C to agree
about offsets, which nothing here does for a foreign type* — was wrong in the
direction this page has now been wrong in four times. Nothing had to be made
to agree: `RecordLayout` already *is* C's struct rule, so a record of
`struct stat`'s fields was 144 bytes at C's own offsets before anything was
written. The gap was permission, not arithmetic, and a record now crosses as a
`var` parameter. `struct sockaddr`, `struct stat` and `struct timespec` are
declarable; what a program still writes for itself is the field list, and
nothing checks it against the header.

Everything else a survey of daily needs found is closed. **`README.md`'s
module table is the one place to count the library** — one row each, checkable
against `ls lib lib/dialect`, and it is named here instead of a number because
this sentence carried one and it went stale three times. `lib/dialect/README.md` is not a second listing and should not be
read as one: it is the error-shape convention, and it names only the modules
that illustrate it. That survey (2026-08-23, against the thirteen modules that
then existed in total) named six gaps. Three needed no language change and closed the same day:
`PasFile` (after ADR-0172), `PasProcess`, `PasStrVec`. Of the three that needed one, the command line as a
list turned out to be a feature rather than a module (ADR-0173), the opaque
handle is ADR-0174, and the struct is ADR-0184 — so all six are closed, and
what remains above is the narrower half none of them named.

Why those last three were one item underneath: what cannot cross is **a pointer
to storage the callee owns whose contents are not characters**. Every foreign
type that crosses today is a scalar, a string copied at the call, or a slice the
caller owns (AP §6.7.7). ~~The opaque half~~ is **done** — `handle external
'closedir'` is a file variable for a foreign address, released where a file
closes (ADR-0174, AP 6.4.12) — and what it deliberately does not touch is
aliasing: a handle cannot be copied at all, so no two names reach one value.
~~The half whose contents have a shape~~ is **done too**, in both directions:
a record crosses as a `var` parameter, so `stat` fills a buffer this program
declared (ADR-0184), and comes back as an optional whose value is copied at
the call, so `readdir` answers one this program then owns (ADR-0187). ~~The
piece that needed the memory model~~ — storage the callee owns **and** whose
shape the program must read — turned out not to need it either, because the
copy retires the address at the end of the statement. What genuinely waits on
the model is narrower than any row here ever said: a struct **member** that is
a pointer, which is a second name for storage and cannot be copied away.

**The three rows that stood here, and how each closed:**

| A daily program wanted | How it went |
| --- | --- |
| ~~a directory listing~~ | **done** — `PasDir` (ADR-0188), and it went a way the row above did not predict. ADR-0187 makes `readdir` declarable by a *program*; a **library** may not declare `struct dirent` at all, ADR-0185's fifth decision holding and POSIX not even fixing the member order. So `opendir` and `closedir` are bound directly, the `DIR *` is a handle, and the runtime supplies the one member access. `PasProcess.CaptureLines('ls -1 dir', names)` is superseded |
| ~~a socket~~ | **done** — `PasNet` (ADR-0203), and it went a way this row did not predict. The row assumed the module would declare `sockaddr` and cross it as a `var` parameter; ADR-0185's fifth decision forbids a *library* from declaring any foreign struct, and sockets are the strongest case for that rule rather than an exception to it — `struct sockaddr` is not one struct but a family, and a program never declares the one it is really using. So both ends of every call are **strings**, a host and a service, and `getaddrinfo` decides what they mean: no address family, no port number, no byte order, and IPv6 without asking. A socket is a handle the runtime owns, closed by `s := nil` or by the block. One connection at a time, which is what `Wait` then closed |
| ~~creating a file through `PasIO`~~ | **done**, beside it rather than in it: `PasStream` opens a file through `fopen`, whose mode is a string and needs no header number, and owns the stream as a handle (ADR-0174). `PasIO` stays descriptor-only |

**And what the last of them opened as it closed** — one row, where two stood
for a day:

| A daily program wants | Why it waits |
| --- | --- |
| ~~a server that serves more than one client~~ | **done** — `PasNet.Wait` (ADR-0205), and it needed nothing from the language. The server was written before the feature and compiled: an array of handles is admitted, `Accept(srv, clients[k])` writes a connection into a slot through a `var` parameter, `clients[k] := nil` releases one, and a schema gives the array whatever length a program wants. What was missing was only *which of these can I read without blocking*, which is a library routine over `poll`. The set is built and thrown away inside one call rather than being an object, because an object would hold a second name for every socket in it and `clients[k] := nil` would dangle it — ADR-0187's rule a second time |
| **to hand an owned value to something else** | Of the three affine kinds only `owned ^T` moves. `take` is refused for a handle in as many words — *nothing else has a value one variable can stop holding* — and there is no move for a file at all (ADR-0182, AP 6.4.14 NOTE 5). This row lost its stated client the day after it was written: it was entered because a task cannot be given a socket, and the server turned out to need neither a task nor a move, a handle reaching its slot as the `var` parameter its producer writes through. So a **second client was written on purpose**, to find out what the row is worth rather than to wait for one — a k-way merge of sorted files, a binary heap of open streams ordered by the line each is showing, which is the textbook program whose data structure exists to exchange its elements. **It is writable today**, and the whole of what the missing move costs is one indirection: an `array [1..K]` of records each holding a `Stream` is admitted and readable, but the heap has to be over *positions* in it rather than over the records, so every comparison reads `src[heap[c]].head` and `Swap` exchanges integers. That is not a workaround but the ordinary shape here — `lib/passort.pas` sorts by `less(i, j)` and `swap(i, j)` and never sees an element, for the unrelated reason that this compiler has no generic *routines* — a schema may now be parameterised by a type (ADR-0209) and a routine over one may not be, which is the row below — and its own header names parallel arrays as a caller it expects. The one bug the probe carried lived in exactly that doubled subscript, which is one author in one sitting and is worth recording rather than deciding on. **So the row is real and small**: an ergonomic cost and not a wall, and by ADR-0116's rule it stays unbuilt, the program that wants the move having managed without it. The **factory** that would change the answer is a compiler item and has a section of its own below. |

**What building on the handle found.** Two modules were written over
AP 6.4.12 the day it landed, and each met one edge of the clause:

- ~~**There is no `h := nil`.**~~ **Done** (ADR-0202). It was one Sema arm and
  no lowering, exactly as this bullet predicted — `pas_handle_set` already
  released what the slot held, and `nil` is a null pointer, so the existing
  emission of the first form *is* the second when the value is null. What made
  it land was the second caller: `PasDir` wanted it on the day it was written,
  and both modules had been closing a stream by opening a path they knew would
  fail, for a refused system call and a stale `errno` apiece.
- ~~**A closer's result is discarded.**~~ **Done** (ADR-0206, AP 6.4.12.5).
  Where it goes turned out to be the obvious place once the question was
  asked properly: `release(h)` is a required function that releases and
  *answers*, and the reason no release could report before is that none of
  them is a statement. `PasProcess.Capture` loses the marker, the subshell
  and the reader's lookahead, and its golden passed unchanged with all of it
  removed — the strongest thing that can be said for a simplification.

**And what the type discriminant opened**, on the day it landed:

| A daily program wants | Why it waits |
| --- | --- |
| ~~to write a *growable* container once~~ | **Done** (ADR-0209, ADR-0211, ADR-0212, ADR-0213), and the module is `lib/dialect/pascontainer.pas`: one growable vector and one string-keyed map, over whatever element type a program names. A client writes one line per element type — `type IntVec = ^Vec(integer);` — and the module is written once. `tests/dialect/lib_container.pas` runs both containers over `integer` and over a record, growing each past its opening capacity more than once. **What it does not replace**: `PasVector`, `PasStrVec` and `PasMap` are ordinary Extended Pascal and stay, because generics are the dialect's and a conforming program must still have a vector and a map; and `PasList` stays because an owned pointer's domain may not be a schema (ADR-0181), so a generic chain would make the *program* declare the node and list types. **What writing it found**, both recorded: a generic body may call only what its clients can reach, since the instantiation is emitted in the client and a module's private routines are internal to its own object file (`doc/sop.md` §7, and the module exports two helpers no caller wants); and that a type argument a call passes is one the container's own type already knows, which `x: type of v^.a[1]` removes — **not** a conformance gap, as this row said for a day: §6.4.9's object is a variable-name and no more, so the refusal is the standard's (ADR-0214), and the dialect widening it is a feature (ADR-0215). Five of the module's headings have lost a type parameter; `VecGet` and `MapGet` keep theirs, because they return the element type and §6.7.1 makes a result-type a type-name. **A generic map keyed by anything but a string** is done too, and needed no constraint (ADR-0260) — see the hash row below |

### The factory — **done** (ADR-0255, ADR-0256)

**`function Open(p): Stream ! ErrorCode` was the one item on this page with a
named cost**, and it is written: AP 6.4.12.6 admits a handle as the result of a
function of this program, and AP 6.4.13.5 admits an affine *value* side to a
fallible-type and lays that record's two arms beside one another rather than
over one another. `tests/dialect/factory_handle.pas` and
`tests/dialect/factory_fallible.pas` are the cases.

**The estimate written here was wrong in both directions at once**, and that is
worth more than the feature. It said the change reaches `target-layout` and
`foreign-layout`, "gates that compare offsets, so both would move and both
would have to be re-argued rather than regenerated". Neither moved. Neither
holds an expected value — both compute from the compiler's own output on every
run — and neither read a source that declared a fallible-type at all, so there
was nothing to re-argue and nothing to see. `tests/checks/target_layout.pas`
declares one now, which is the fix for a gate that could not have watched this
shape.

And it said the item is "not a clause and not a Sema arm … a representation
change". The representation is the small half. What it did not name: the record
then contains something with no copy, so it needs an assignment rule of its own,
a *mandatory* in-place build at the call — a memcpy there is ADR-0150's double
free with a handle in place of a file — two walks taught to reach an arm, and a
decision about `try`, which is refused because it yields the value and an owned
value has none to yield.

**The bare half was as cheap as this page said.** A handle is `IsMemory`, so a
function answering one already receives the address of the variable its result
is to occupy; its own `Open := ExtFopen(...)` is AP 6.4.12.2's assignment made
through that address; and a factory over a factory emits no `pas_handle_set` at
all. Three claims, checked rather than trusted, all three true.

**The first mutation survived and the test is what changed.** Laying the arms
over one another again passed all 754 cases, because the case wrote a cause
only over a handle that had never been opened — where the corrupted bytes are
zero either way. A case that writes a cause over a *live* stream makes the same
mutation exit 139. A test of a representation is worth nothing until it stages
the corruption the representation prevents.

**The lesson from the FFI increments**, worth keeping for whatever replaces the
rows above: a decision that looks like it needs a model may need it for only
part of its surface, and the part that does not is usually worth taking first.
Four estimates in a row were wrong in that useful direction — ADR-0122 and
ADR-0123, then ADR-0184, whose item this page had described as needing the
compiler and C to agree about offsets when they already did, then ADR-0187,
whose item this page had called the place *where the memory-safety model
actually bites*. It did not bite there. It bites one level further in, at a
struct member that is a pointer, and the reason is worth stating in general:
**an ownership question is only a question while something holds the address.**
Each of the four was answered by arranging for nothing to.

**And the row that was left as the place it genuinely bites has since been
answered the same way**, which makes five — `getaddrinfo`'s chained list is
walked in `runtime/pasrt_posix.c` and `PasNet` crosses strings, exactly as
`PasDir` crosses a name rather than a `struct dirent`. The pattern is now
strong enough to state as a prior rather than as a tally: **before recording
that something waits on the memory model, ask whether the address can be
retired at the call.** Five times running it could, and twice the answer was
not a language feature at all but a `pasx_` routine that does the walking on
the far side.

**And the factory above is the first item where the prior does not apply**,
which is what makes it worth keeping as a prior rather than a rule. The whole
point of a factory is that the callee's answer **outlives the call** — the
address cannot be retired there, because retiring it is exactly what a factory
must not do. So the question the prior asks is still the right first question,
and "no" is now a possible answer with a case behind it. Where the answer is
no, expect the ownership rule the five easy ones did not need.

---

## The concurrency row and the four cheaper answers

`doc/roadmap.md`'s *Where the ideas come from* table had one cell that had
stopped being a cell. The concurrency row grew for five increments into an
essay — every time something looked as though it wanted a thread and something
cheaper answered instead, the answer was appended to it — and by the end it
was the longest passage on the page, inside a table, describing a row that
ADR-0268 had since closed.

It is moved here whole, because what it records is the most reusable thing on
that page: **measure the cost before naming the mechanism.** Four times the
sentence that looked expensive was not where the time went, and once the
route that looked cheap was the expensive one.

- **`select` for a socket server** (ADR-0205). ADR-0201 had named a socket
  module serving more than one client as the thing that would demand a
  concurrency construct, and said `select` was the cheaper answer to try
  first. ADR-0203 landed the module, ADR-0205 made it serve many, with `poll`
  and no construct at all. The trigger this row named came and went in two
  days.
- **A cache for the language server's hovers** (ADR-0252). Measured against
  `selfhost/apfront.pas` at 22 900 lines: one hover 159 ms, five sequential
  795 ms, five *pipelined* 800 ms — so pipelining bought nothing and the
  server is serial, as the row said. But the larger number was not concurrency
  at all: five hovers on unchanged text cost five compilations, and caching
  the answer against the document took 795 ms to **106**. What a reader
  actually pays fell 7.5× with no construct.
- **The `didChange` drain** (ADR-0257). The server drains the messages that
  have *arrived* — never waits for more, which would be a policy about a
  client's typing speed rather than a fact about the queue — and keeps only
  the last `didChange` per document, a keystroke carrying the whole file. Four
  queued edits: **780 ms to 340**, five `publishDiagnostics` to two, and the
  change a reader is waiting for compiled first rather than fourth.
- **And the measurement that reversed the shape of the argument.** What the
  drain cannot abandon is a compile already in flight — one compilation, about
  170 ms, once at the end of a burst. The cheapest route named for that needs
  the pipe unbuffered, because a `FILE *`'s buffer is libc's and neither ISO C
  nor POSIX will say how much it holds. Measured on the dump a hover actually
  reads, 1 555 350 bytes: **5 ms buffered, 621 ms unbuffered**. The
  cheap-looking route would cost 124 times what it could save, on the
  operation a reader performs most.

**ADR-0268 then built the construct anyway**, and the record says in as many
words that ADR-0116's bar is not met and is not claimed to be: what is there
has no caller in this tree. What it has instead is a design decided four
increments early and the discipline of building it exactly as decided. None of
the reasoning above is overturned by that; it is why the row is worth keeping.

### The row as it stood

Rust, Swift and Zig are the reference points, and they do not all fit equally:
Pascal's grain is value semantics, explicitness and a small orthogonal core,
which is close to Zig and Swift and further from Rust. Each borrowing is tied to
the open decision it would settle.

| Idea | From | Settles | Where it stands |
| --- | --- | --- | --- |
| Slices — a pointer and a length | Zig, Rust | bounds safety | **Done** (ADR-0125, ADR-0129) |
| Optionals, and no bare null | Swift, Rust | pointer safety | **Done** (ADR-0123); the check is localised to `^`, not eliminated |
| Scope-based release | ISO 7185, Rust's `Drop` | lifetime | **Done, and it was already here** (ADR-0151) — for a *declared* variable. A created one had no owner until ADR-0181 |
| ~~An owning pointer~~ | Rust's `Box` | lifetime, for the heap | **Done** (ADR-0181, AP 6.4.14): `owned ^T` disposes what it identifies when its own variable dies, and cannot be copied. Reached from the file variable rather than from Rust, and it decides nothing about aliasing because it admits no second name |
| ~~A move~~ | Rust's `mem::take` | what an affine type needs to be usable | **Done** (ADR-0182, AP 6.4.14.6): `take(v)` empties a variable and yields what it held, in the one position an owned value may be assigned. Found by writing the client: without it push-front and pop-front are each two copies, so an owned chain had no constant-time operation at all |
| Explicit allocator passing | Zig | part of memory safety | **Tried; does not survive contact** (ADR-0116) |
| ~~Error unions / `Result`~~ | Zig, Rust | error handling | **Done** (ADR-0176, AP 6.4.13): `T ! E` is the result record ADR-0120's convention described, written by the compiler with the field names fixed |
| ~~An early exit~~ | Turbo Pascal, Delphi, FPC | what propagation stands on | **Done** (ADR-0177, AP 6.7.5.9): `exit` terminates one activation, `exit(e)` assigns the result first. The first borrowing here whose source is another *Pascal* rather than another language, and the row below is the second |
| ~~An early loop exit~~ | Turbo Pascal, Delphi, FPC | nothing structural — an ergonomic gap | **Done** (ADR-0208, AP 6.7.5.10 and 6.7.5.11): `break` leaves the closest-containing repetitive-statement, `continue` completes the current iteration of it. Taken whole from the three dialects that have it, down to the spelling and to leaving *one* loop rather than a named one. It settles no open decision, which is what makes it the plainest case in this table of the argument [above](roadmap.md#1-the-dialect-has-no-external-authority-and-every-gate-here-is-anchored-in-one): a question the standards do not answer and three Pascals answer alike is one where novelty would be a cost with nothing to show for it. It cost two branches — the blocks were already there, and AP 6.9.3.11 NOTE 2 already said what an armed statement does when a sequence is left by a jump |
| ~~Propagation~~ | Zig's `try`, Rust's `?` | the rest of error handling | **Done** (ADR-0178, AP 6.8.9): `try(x)` yields the value or leaves the enclosing function with the cause. Spelled as a required function because no position would serve — see below |
| ~~`defer`~~ | Zig, Swift | resource safety | **Done** (ADR-0175, AP 6.9.3.11): `defer S` arms a statement, executed when the statement-sequence it stands in is completed or when the activation terminates. Zig's unit rather than Go's, because a per-activation defer runs a loop's `dispose(p)` once with the last `p` |
| Unicode-correct `String` | Swift | the text model | **Done**, entirely — ADR-0189 – ADR-0193, then ADR-0196 and ADR-0199; the row in [the goal's table](roadmap.md#the-goal-adr-0109) is what the increments were and what each cost, and this one is only about the borrowing. The grapheme as the unit and the refusal of an integer index are Swift's and are taken whole. Its *storage* is not: Swift's `String` is a reference-counted heap buffer, which is the construct ADR-0151 says forces the aliasing decision, so this is a value with a declared capacity instead — and that in turn is what makes normalise-on-construction affordable, which Swift cannot do and which buys a bytewise `=` |
| ARC | Swift | aliasing | **The question is withdrawn** (ADR-0201). ADR-0117's containment fixes what `^T` means, and ARC changes it — so the candidate cannot reach the only reference type an ISO program has |
| Ownership and borrowing | Rust | aliasing | **The same, and half of it is already here**: a `var` parameter of an owned value's referent is a borrow, and it cannot escape because there is no address-of and `new` is the only producer of a pointer. Not checked — *unformable*, which is stronger and free (ADR-0201) |
| Traits / protocols | Rust, Swift | abstraction | **Later**, and the reason given here has since become half-true rather than true. Schemata gave parametric types over a *value* (ADR-0039); ADR-0209 lets a discriminant name a **type**, so `Vec(T: type; cap: integer)` is a container written once. What that does not give is a routine over one — see [the row above](#what-each-landed-feature-left-open) — and abstraction over *behaviour* is a further thing again, which nothing has asked for |
| `comptime` | Zig | metaprogramming | **Later.** Constant-expressions everywhere (ADR-0054) is as far as anything needs |
| Actors / `Send`+`Sync` | Concurrent Pascal, Ada, Swift, Rust | concurrency | **Unblocked and unbuilt** (ADR-0201). It unblocks nothing, the two rows above having been answered without it; what it does is *end* the sentence the rest rests on — a borrow cannot outlive a call because the caller is not running during it. So the construct must be **share-nothing**, a task owning what it is given, and the lineage to read is Pascal's own rather than Rust's: Concurrent Pascal had `process` and `monitor` in 1975. Not built, for ADR-0116's reason — nothing here wants it. **This row named its trigger and the trigger came and went in two days.** ADR-0201 said "a socket module serving more than one client is what would demand it, and `select` is the cheaper answer to try first"; ADR-0203 landed the module and ADR-0205 made it serve many, with `poll` and no construct at all. The cheaper answer was tried first and was enough, which is what ADR-0201 asked for. What a thread would still buy is a **slow client not slowing the others** — a different sentence, and one no program here has yet said. **A program that would say it is now named**: the [language server](#the-chapter-as-it-closed), where a `didChange` arrives while a compile is in flight and a cancelled request has to stop something already running. **The candidate is now written and the row still does not move** (ADR-0236): `lsp/pasls.pas` exists, and it compiles *synchronously* — it writes the document to a file, waits for `pascalc`, publishes, and only then reads the next message. **And it has now been measured, which this row asserted without doing** (ADR-0252). Against `selfhost/apfront.pas` at 22 900 lines, driven by an independent client: one hover 159 ms, five sequential hovers 795 ms, five *pipelined* hovers 800 ms — so pipelining buys nothing and the server is serial, as this row said — and a `didChange` arriving behind work in flight waited **933 ms**. But the larger number was not concurrency at all: five hovers on unchanged text cost five compilations, and caching the answer against the document took that 795 ms to **106**. The cost a reader actually pays fell 7.5× with no construct. What is left is the 933 ms, and the *second* cheaper answer in front of it has now been costed rather than waved at. The sketch was: this server already has `PasNet.Wait` over `poll` (ADR-0205), so a `Capture` polling the child's pipe **and** standard input could abandon work a newer message has made stale, single-threaded, which is what most language servers do. **What stops it is ADR-0174's own decision.** `PasProcess.Pipe` is `handle external 'pclose'` — an *opaque* handle, which is what made binding `popen` safe and what means no program can get a descriptor out of one to poll. `Collect` reads with `fgetc` on that handle, so there is nothing pollable anywhere on the Pascal side. Three routes and only one is small: a `pasx_` routine that polls on the far side, where the runtime holds the `FILE *` and can `fileno` it — no new headers, `<stdio.h>` being ISO C — keeping the handle opaque, which is right; exposing the descriptor, which breaks the opacity that made the binding safe; or `fork`/`exec`/`pipe`/`waitpid`, which is a large new POSIX surface for one caller. Even the small route needs `Collect` restructured to read incrementally and a server that can decide what "stale" means and abandon a child, so it is *cheaper than a construct* and not cheap. It stays unbuilt under ADR-0116: what a reader actually pays fell 7.5× without it. This row has now been answered by a cheaper thing twice — `select` for the sockets, a cache for the hovers — and the rule it is teaching is worth more than the construct: **measure the cost before naming the mechanism**, because twice the expensive-looking sentence was not where the time went **A fourth cheaper answer has now landed and this row is closed for the foreseeable** (ADR-0257). The server drains the messages that have *arrived* -- never waits for more, which would be a policy about a client's typing speed rather than a fact about the queue -- and keeps only the last `didChange` per document, a keystroke carrying the whole file. Measured: four queued edits of `selfhost/apfront.pas`, **780 ms to 340**, five `publishDiagnostics` to two, and the change a reader is waiting for compiled first rather than fourth. No construct, no compiler change; `pasx_fd_ready`, `PasIO.FdReady` and `PasLsp.LspPending` are the whole of it, and `<poll.h>` was already catalogued. **And the remaining work now has a number against it rather than a sketch.** What the drain cannot abandon is a compile already in flight -- one compilation, about 170 ms, once at the end of a burst. The cheapest route named above needs the pipe unbuffered, because a `FILE *`'s buffer is libc's and neither ISO C nor POSIX will say how much it holds -- ADR-0205's decision 4 a third time, with no counter available. Measured on the dump a hover actually reads, 1 555 350 bytes: **5 ms buffered, 621 ms unbuffered**. The cheap-looking route would cost 124 times what it could save, on the operation a reader performs most; the correct route is the other one, moving the buffer into C as `struct pasx_socket` does, and it stays unbuilt under ADR-0116. So the rule this row teaches has a fourth confirmation and a new face: three times the expensive-looking sentence was not where the time went, and this time **the cheap-looking route was the expensive one** |

Two conclusions worth stating:

- **The cheap items are not the small ones.** `defer` and error unions between
  them cover most of what "daily practical development" means, and neither
  required settling the memory-safety fork. Both are done (ADR-0175,
  ADR-0176), and the second was cheaper than this table predicted: it was
  expected to be "the larger of the two — a type constructor over a type", and
  it turned out to need no new type at all. `T ! E` denotes an ordinary record
  with a flag on it, so the copy, the layout and ADR-0118's trap came free and
  **CodeGen was not touched**. The lesson is ADR-0122 and ADR-0123's, a third
  time: an estimate that assumes a feature needs its own machinery is worth
  probing before it is believed.

- **Error handling is finished**, and it took three records rather than one.
  `T ! E` says what a failure is (ADR-0176), `exit` is how a block is left
  (ADR-0177), and `try(x)` connects them (ADR-0178). The two questions this
  entry said `try` still had to answer both got answers worth keeping. *What
  must the enclosing result type be?* — nothing in particular: the cause has
  only to be assignable to it, which the assignment already decides, so a
  function answering the error type takes the cause directly and the question
  dissolves. *Is there a spelling a conforming program could not have
  written?* — **no**, and that is the finding. ADR-0176 had sketched `try X`
  by the rule that works for a statement; a factor may be a variable-access,
  so `try (x)`, `try [x]`, `try + x`, `try - x`, `try.f` and `try^` all mean
  something to a program that declares `try`. It is a required identifier
  instead, which is `exit`'s answer and now the commoner of the dialect's two
  spelling shapes.

- **`exit` cost less than the table above expected, and for the third time the
  reason was the same.** It is a branch to the epilogue every block already
  had, so the armed statements, the files and the result all came free — the
  same shape as ADR-0176's "no new type" and ADR-0123's before it. What was
  *not* free was a gate: `exit(e)` can only stand in a function-block, and
  `predicate-callers`'s probe program declared its subject as a procedure, so
  the position had to be given a function to live in. A gate that would have
  passed for the wrong reason is worth more attention than the feature was.
- **ARC and borrowing are not equally costly here**, and the difference is not
  only effort: borrowing would make ADR-0108's C++ mirror prohibitively
  expensive and likely force the decision to freeze it. ADR-0151 declines to
  decide on that — cost is a reason to prefer one, not evidence about which the
  language needs.

One option was **closing** as the language diverges — a third-party
differential can only ever check the ISO 7185 core, because nobody else
implements this dialect — and it was taken for that reason (ADR-0234). It
checks 103 of 244 cases with a golden today and will check fewer next
release.

---

## The four decisions the goal forced

ADR-0109 set the project's only remaining goal and named four decisions that
would have to be made to reach it. `doc/roadmap.md` carried them as a table
from then until 2026-09-01, when the last was answered and the table stopped
being a queue.

**Not one of the four decided the question its row was written to pose**, and
that — rather than the four answers — is what the table is kept for.

- **The memory-safety model** was posed as a fork: ARC or borrow-checking. It
  was answered in two halves and *neither half took the fork*. Lifetime turned
  out to be already here, being what a file variable has been since 1982
  (ADR-0151) — except that the sentence quantifies over a **variable**, and one
  created by `new` is held by nothing, which is what `owned ^T` fixed
  (ADR-0181). Aliasing was **withdrawn as posed** (ADR-0201): neither candidate
  can reach `^T`, ADR-0117's containment having fixed what an ISO program's
  only reference type means; the dialect's answer for the three affine kinds is
  refusal; and the one alias that does exist cannot escape, because Pascal has
  no address-of and `new` is the only producer of a pointer. **Unformable
  rather than checked**, which is stronger and free.
- **The text model** was offered a choice between *a wider character type or a
  text type*, and it was not a choice: widening `char` stops `set of char`
  compiling under ADR-0028's 256-value cap. What was built is a value with a
  declared capacity, normalised on construction.
- **The memory model** was recorded as unstarted and blocked on the safety
  model. The safety model narrowed it rather than unblocking it — ADR-0201's
  construct is share-nothing, so there is no shared mutable state for a memory
  model to be about — and then **building the construct answered what was
  left** (ADR-0268). What a value crossing between two threads guarantees is
  that it was copied.
- **How far the C++ reference front end follows** was answered by **deletion**
  (ADR-0232). It was frozen at the conformance surface, `difftest` skipped
  every dialect source, and when the surface went it had nothing left to
  compare.

The fourth is the only one that left a live consequence, and it is not in this
chapter: nothing now compares this front end with a second answer, which is
[the roadmap's open question §1](roadmap.md#1-the-dialect-has-no-external-authority-and-every-gate-here-is-anchored-in-one)
and `doc/sop.md` §7's largest entry.

### The table as it stood

**Four decisions the goal forces**, each to get its own record when it is
made — and **all four are now made**, three of them by discovery rather than by
design and the fourth by deleting the thing it was about. The table is kept
because how each was answered is the useful part; none of it is a queue:

| Decision | Where it stands |
| --- | --- |
| **The memory-safety model** | **Answered, in both halves and by discovery rather than by design** — four records, and not one of them decided the question the row was written to pose. *Lifetime* — an owned value is released when the variable holding it dies and cannot be copied out of it — was already here, being what a file variable has been since 1982 (ADR-0151). But that sentence quantifies over a *variable*, and a variable created by `new` is held by nothing: it exists in no activation, so nothing released what a heap record owned unless the program said `dispose`, and under a 64-descriptor limit a loop allocating one per iteration ran out at the 62nd. `owned ^T` gives such a variable an owner and closes it (ADR-0181, AP 6.4.14). The *aliasing* half — may a second name hold one owned value, and if so how: ARC, or borrowing — stood here for a long time as undecidable until the fork was **withdrawn as posed** (ADR-0201). Neither candidate can reach `^T`, ADR-0117's containment fixing what an ISO program's only reference type means; the dialect's answer for the three affine kinds is refusal, given three times, so there is no second name for either candidate to govern; and the one alias that does exist — a `var` parameter bound to an owned value's referent — cannot escape, because Pascal has no address-of and `new` is the only producer of a pointer. **Unformable rather than checked**, which is stronger and free, and silent if a future feature takes it away (`doc/sop.md` §7). What was left of the fork was exactly one thing — **two threads of control**, the only sentence that breaks *a borrow cannot outlive a call because the caller is not running during it* — and ADR-0268 built it in the shape ADR-0201 designed: share-nothing, and every task a block spawned joined before that block releases anything, which is what makes the sentence true again. **Answered in full**; the concurrency row of [Where the ideas come from](roadmap.md#where-the-ideas-come-from) is where it stands, and what it left open is [What each landed feature left open](#what-each-landed-feature-left-open). |
| **The text model** | **Done** (ADR-0189 – ADR-0193, ADR-0196, ADR-0199, AP 6.4.15). Nothing of the clause is left, and the row's own offer — *a wider character type or a text type* — turned out not to be a choice: widening `char` stops `set of char` compiling under ADR-0028's 256-value cap. What was built instead, what it cost, and the one argued-rather-than-measured decision in it — refusing an integer index — are in [`doc/history.md`](history.md#the-text-model). **That refusal has since had its first external test** (ADR-0237): LSP counts positions in UTF-16 code units, a fourth unit this page said nothing answers in, and the count never needed the index — a scalar below U+10000 is one code unit and one at or above it is two, so the conversion is a walk over the scalar view, unchanged |
| **The memory model** | **Answered by the construct rather than by a model** (ADR-0268). It could not be designed before the safety model, shared mutable state being where the two meet; the safety model narrowed it, ADR-0201's construct being share-nothing, and building that construct answered what was left. A task takes only transferable values and channels, may name only its own variables (AP 6.7.8.2), and is joined before the block that spawned it releases anything — so there is no shared mutable state for a memory model to be about, and what a value crossing between two threads guarantees is that it was *copied*. What is not claimed: `ThreadSanitizer` is the oracle this rests on and it is not a gate, and the missing join is caught by no case (`doc/sop.md` §7). |
| ~~**How far the C++ reference front end follows**~~ (ADR-0108) | **Answered by deletion** (ADR-0232). It was frozen at the conformance surface — `difftest` skipped every dialect source — and when the conformance surface went, `difftest` had nothing left to compare and `src/` had no reader. Both are gone. The question the row was really about survives as [open question §1](roadmap.md#1-the-dialect-has-no-external-authority-and-every-gate-here-is-anchored-in-one) and as `doc/sop.md` §7's largest entry: nothing now compares this front end with a second answer. |

---

## The first archive

`doc/roadmap.md`'s *What would make this practical to pick up* opened on
2026-09-02 with a row saying no release had ever carried a binary — `gh
release view v3.4.0 --json assets` answered `[]`, and so did every tag before
it — and guessed it at an afternoon, most of it the CI job. It closed the
next day (ADR-0296): a `v*` tag now attaches
`afterschool-pascal-<tag>-x86_64-linux.tar.gz` and an `aarch64-linux` one,
each with a `.sha256`, to its GitHub release, in the layout `install-layout`
already checked (ADR-0244), with `pascalc` linked statically and `clang`
still needed at use time because the compiler links nothing (ADR-0085).

Three things doing it found. **The CI job was the cheap half.** Every piece
was already in the tree — the install layout, the gate that drives it with
the environment emptied, an arm64 runner that had run the suite on every push
since ADR-0159, and a job that already ran only at a tag — and the workflow
is three jobs and three `gh` calls. What took the afternoon was the other
half: the logic went into `tools/release.sh` so that a `ctest` case could run
it on every push, because this tree had twice watched shell that only a tag
exercises fail at the tag (`seed_current.sh`, ADR-0282). **And running it found two defects the tag
would have met**: the first `--check` printed *checks out* and then `work:
unbound variable`, an `EXIT` trap naming a `local` that was gone by the time
it ran, so the check passed and left its temporary directory behind every
time; and the static check reported the static binary it was written for as
dynamic, because `ldd` exits 1 on one and `pipefail` made that the pipeline's
answer whatever `grep` found. **The mutation is the gate's own list**: an
archive with `lib/afterschool/` deleted and a fresh digest stops `--check`
with `install-layout: lib/afterschool/pastext.pas was not installed`, because
`--check` hands the unpacked prefix to `install_layout.sh --prefix` rather
than keeping a second list of what an archive holds.

The aarch64 archive is shipped, and the sentence the cross-platform chapter
kept — *works, not supported* — became *works and is shipped, not seeded*:
the archive is built from the x86-64 seed retargeted by `clang`, writes an
x86-64 header unless told otherwise, and has never been through
`llc-second-backend`. macOS stays a disabled matrix entry with the reason
beside it: nobody has built the compiler on one, and a platform is run before
it is shipped.

## The examples, and what writing them found

`doc/roadmap.md`'s chapter *What would make this practical to pick up* was
written on 2026-09-02 with four sections, and the row its last sentence
said to take first — *the examples are the one that pays twice* — closed the
next day (ADR-0295). It is moved here with what closing it cost, because the
row was a report about the tree and the tree no longer answers to it.

`examples/` holds twelve programs of a page each, every one a `ctest` case:
`hello_args`, `word_count`, `word_freq`, `dir_sizes`, `json_pretty`,
`parse_errors`, `owned_list`, `graphemes`, `pipeline_tasks`, `fetch_http`,
`c_function` and `defer_cleanup`. Seven resolve the library by an
`.importpath` sidecar rather than a `.components`, which makes them the first
cases to drive ADR-0244's resolver over the whole dialect library from
outside `tests/`, and seven sweeps that enumerate Pascal by root gained the
directory. Two harness defects came out of registering them: `heap_balance.py`
could not see a module reached by name, and its `--write` had dropped a
case that failed to run without a word.

**What writing them found is the part worth keeping**, and it is the
sentence the row above it in the roadmap kept making — the next finding
comes from somebody writing a program. Seven, all in ADR-0295 and now in the
roadmap's *Writing a daily program*: a task cannot close the channel
downstream of it and a program that tries deadlocks silently; a map lookup
is seven arguments, two of them types the call already knows; four of the
twelve programs collided with a library noun on their first draft, and one
of the four diagnostics named a type the source does not hold; an owned
pointer refuses `p := nil` without naming `dispose`; `PasJson` writes `0.75`
as `7.500000000000E-01`; a `MapKey` is 63 characters; and a program wanting
somewhere writable must ask `argcount` first. No compiler defect, no crash
and no wrong answer — which is itself a measurement, taken by the first
twelve programs anyone wrote here to be read rather than to pin a clause.

### The second of the seven, closed

- ~~**The library has not caught up with the language's inference, measured
  again.**~~ **Closed by ADR-0304 on 2026-09-03, and the reason the row gave
  was wrong.** As written: `MapGet(CountMap, integer, counts, w, 0, StrHash,
  StrEq)` is seven arguments for a lookup, two of them types the call already
  knows, *because a type appearing only in the result must be written and
  ADR-0254's rule is then all or nothing*.

  The clause after *because* did not survive the first probe. `MapGet`'s
  element type does not stand only in the result — `whenAbsent: Elem` is a
  value parameter and AP 6.7.3.10.4 a) reads it — so `MapGet(counts, w, 0,
  StrHash, StrEq)` had compiled since the day inference landed and nobody had
  written it. What said otherwise was `lib/dialect/pascontainer.pas`'s own
  header comment, and `examples/word_freq.pas` was written from the comment.
  That is ADR-0297's four-day gap met a second time in the same module, and
  the register's own lesson restated: **a row here is a report and not an
  estimate**, and this one was an estimate about a compiler nobody had asked.

  The row's *other* clause was right, for two routines and not for seven
  arguments: `VecGet`'s element type and `MapKeyAt`'s key type stand only in
  a result, §6.7.1 makes a result-type a type-name and not an actual, and
  all-or-nothing then made the caller write the determinable types too.
  ADR-0304 widened AP 6.7.3.10.4 to admit a **prefix** of the type arguments,
  the two forms ADR-0254 had becoming the ends of a range; both routines
  declare their undeterminable type parameter first; and `VecGet(JsonChars,
  char, b, i)` is `VecGet(char, b, i)` at fifteen call sites, eight of them in
  the language server. The example that measured it names one type and it is
  in the type-definition.

### The row as it stood

- **No program to read that is not a test.** There is no `examples/`
  directory. The programs in the tree that are not test cases are the
  compiler's three sources, thirty-one library modules and one language
  server — 50 690 lines, and not one of them is short enough to read over
  coffee. *What a daily program cannot reach for* says the next finding
  will come from somebody writing a program, and the last three defects
  closed here were found by probes of a few lines each (ADR-0290, ADR-0291,
  ADR-0292). A dozen complete programs of a page each — read a file, walk a
  directory, fetch a URL, parse JSON, spawn a task, bind a C function —
  would be the corpus that finds the next `JsonLine`, and it is the one row
  here that pays twice: every example is also a case, and a case that fails
  is a finding.

## The tour, and what writing it found

`doc/roadmap.md`'s chapter *What would make this practical to pick up* opened
on 2026-09-02 with three rows under *Getting it and learning it*. Two closed
the next day — the binary and the examples — and the third closed on
2026-09-03: [`doc/tour.md`](tour.md) is eleven sections of prose with short
programs in it, for a reader who knows Turbo Pascal and has never seen this
dialect. It is linked from the top of `README.md` and from that page's
Documentation section, and `examples/` is its other half, pointed at from six
of the eleven sections rather than inlined.

**No ADR.** A document that states what is already decided constrains nothing
and deviates from nothing, which is the bar `CLAUDE.md` sets for a record; the
two roadmap rows and the README link are the whole of what moved. The one
thing the tour *decides* is what a reader is told first, and it is written
down where a reader can disagree with it: what a compiler is and why it does
not link, then what is familiar, then modules — because everything after
section 3 imports something.

**Every fragment was compiled**, which is the discipline the examples row set
and the only one available: a tour is prose, and prose about a compiler is a
claim nothing else here can contradict. Nine complete programs were written
into a scratch directory and run through `tools/pascalcc` against the built
compiler and `lib/`: hello, a module and its client, strings, a text walk, a
fallible chain, an owned list, a generic vector, a generic map, two tasks and
a channel, and two `external` bindings. Three of the nine were wrong on the
first draft, and each was wrong in a way a reader would have hit.

**A source named with no directory finds no sibling module.** The module
section's whole point is that a program and its modules in one directory need
no manifest and no build order, which is ADR-0244's first search rule and a
sentence `README.md` already carried. `pascalcc sayhello.pas` answers *no
interface named 'greeting' has been exported*; `pascalcc ./sayhello.pas`
compiles. `SourceDir` scans back for a `/` and answers the empty string when
there is none, and `AddPath` deliberately drops an empty directory, an empty
entry in `AFTERSCHOOL_PASCAL_PATH` being a POSIX surprise nobody wants. So the
claim is true of every spelling but the one a person types, and **no oracle
here could have seen it**: every case is compiled by a harness that passes a
path — `install-layout` an absolute prefix, `import_by_name` an
`--import-path` — which is `long-path`'s argument and `stale-component`'s met
a third time. It was a roadmap row rather than a fix, because the tour's job
was to be written and the compiler change wanted a case of its own — and it
got one the same day (ADR-0308): `SourceDir` answers `./`, `bare-source-name`
is the gate, and the shape the finding leaves behind is that **two right
answers to two different questions can be wrong together**. Both comments
name their own reason correctly and neither can see the pair.

**The library is wordier than the language now requires, and its own header
says why in the past tense.** `lib/dialect/pascontainer.pas` opens with a
worked example writing `VecInit(IntVec, v, 8)`, `VecPush(IntVec, integer, v,
42)` and `VecFree(IntVec, v)`, and a paragraph headed *Why two type arguments
and not one* explaining that the second is redundant and waiting on §6.4.9.
Both have expired: `VecPush`'s signature now reads `x: type of v^.a[1]`, so
there is no second type argument to explain, and ADR-0254's inference means
`VecInit(v, 8)`, `VecPush(v, k * k)`, `VecLen(v)` and `VecFree(v)` all compile
with no types written at all — as do `MapInit`, `MapPut`, `MapHas`,
`MapCount` and `MapFree`. What still needs its types is `VecGet` and
`MapGet`, and for the reason the roadmap's *Writing a daily program* already
gives: the element type appears only in the *result*, nothing in the call
determines it, and inference is all-or-nothing. That is a sharper statement of
the finding than the row had — the complaint is not that the library is behind
the language everywhere, it is that one shape cannot infer and drags the rest
of its call with it. `examples/word_freq.pas` writes the redundant arguments
too.

**The tour is where the four warnings and the traps land in one paragraph
each**, and writing them found nothing wrong — which is worth recording,
because the three sections that pay a reader back fastest are the three
nobody had had to explain in ordinary words before: what an owned pointer is
*for* (it moves *who frees this* out of the reader's head and into the
declaration), when `try` is the wrong shape (it propagates by leaving the
routine, so it cannot stand where a program must still answer), and why a
task cannot close the channel downstream of it. The last is ADR-0295's first
finding, restated as a rule a reader follows rather than as a defect report.

### The row as it stood

- **No tour.** `doc/afterschool-pascal-spec.md` is an amendment in ISO
  numbering, `doc/adr/` is an audit trail, and `README.md`'s language section
  is a feature list 900 lines long. Nothing in the tree explains the dialect
  to a person who knows Turbo Pascal and wants an HTTP client by evening —
  what an owned pointer is *for*, when to reach for `T ! E` and when for an
  accessor, why a module's heading is its interface. The examples above are
  half of that document; the other half is prose that says why.

## The capacity is the caller's

Two rows of `doc/roadmap.md`'s *Writing a daily program*, closed on
2026-09-03. They arrived from different places -- one from ADR-0292's closing
warning, one from ADR-0295's third finding -- and each turned out to be two
halves with only one of them costing anything.

### What a program reads can be cut without a word -- closed (ADR-0305)

The row said a line longer than a number the program did not choose is lost
and nothing says so, and named a library half and a language half. The
library half was ADR-0291's mechanism applied one module over: `ReadLine`
takes `var line: string` and `ForEachLine` takes the buffer it reads through,
so the capacity is a variable the caller declared. Two callers moved and both
had been writing `FileLine` because the interface asked them to.

The language half said it *had not been probed*, and probing it took four
lines. `read(f, s)` stops at the capacity **or** at the line's end, whichever
comes first (ISO/IEC 10206:1991 §6.10.1 f)), so `eoln(f)` immediately
afterwards is false exactly when something was left over and `readln(f)` then
skips it. Nothing needed building, nothing is spelled, and no clause moved --
the finding is that the facility was documentable rather than missing, and it
is now documented at the routines that truncate. Two documents had walked past
it: ADR-0292 cites §6.10.1 for the truncation and does not read the sentence
beside it.

The alternative shape for `ForEachLine` was an integer capacity and a local
`string(cap)`, which §6.2.3.8 b) admits and which was probed and works. It was
rejected for ADR-0292's own reason -- a number at a call site is a counted
capacity and a variable's declaration is a derived one -- and because every
other reader in this library already takes the caller's string.

### Four of twelve examples collided with a library name -- closed (ADR-0306)

The compiler half was a real defect and a small one: `CheckCall` leaves
`intType` on a node whose call it could not resolve, which is the contract
CodeGen rests on, and the assignment rule then spelled that placeholder out as
though the program had written it. What hid it is that the placeholder is a
*real* type -- every existing golden reaching one of those four arms assigns
to an integer target, so `Assignable` said yes and the second message never
appeared. `nErrType` is the fix and `badFunc` (ADR-0054) is its precedent on
the other side of the same statement.

The naming half was decided the other way and is worth the paragraph. The
nouns are `Info`, `Dir`, `List`, `Parts` and `Stream`, every one the best word
for what it denotes; the collision is with a name the *caller* chose, so any
rename moves it rather than removing it. It is a compile-time error read in
the same second and answered in one word, and §6.11.2 already has `only` and
`qualified` for a caller who wants the short spelling kept. What was missing
was that nobody had written it down, so `README.md`'s library section names
the five and the three answers. ADR-0298 -- no two library modules export one
spelling -- is a different collision and does not reach this one.

### And one of the three smaller reports -- answered (ADR-0307)

An owned pointer refuses `p := nil` where a handle takes it as its release,
and ADR-0295 said the asymmetry had *no reason a reader can see*. It has one:
an owned pointer already has `dispose` and a handle has nothing else, so
admitting `nil` would give one operation two spellings, and admitting it as a
plain store would abandon what the variable identifies. So the language does
not change and the message does -- it names `dispose` -- and AP 6.4.14.6 gains
a NOTE saying why the two clauses differ. An asymmetry between two clauses is
either a reason or a defect, and it has to be written down as one of the two.

### And a second of them -- the bound was not the map's (ADR-0310)

ADR-0295's sixth finding said a `MapKey` is 63 characters, so a map keyed by
text from outside needs a guard, and filed itself as *a bound, recorded, not a
defect*. It was the wrong bound. The map has been generic over its key type
since ADR-0254, the ready-made `StrHash`/`StrEq` became schematic the day
before the finding was written (ADR-0290), and a three-line probe keys a map at
200 and puts a 130-character key in it. The 63 was `examples/word_freq.pas`
reaching for the ready-made key type and then guarding against the capacity
that type happens to have -- the program's own choice, reported as the
library's. It is the second time the claim has been made: `lsp/pasls.pas` held
its documents in a linearly searched vector for the same reason, and ADR-0290
struck that comment.

What was real is one step further in. A key type has a capacity whichever one
is chosen, and a program keyed by text from *outside* has to answer for a
length it did not choose -- in the caller's own argument list, where no library
routine can see it. So the library exports nothing new and states the rule
instead: size the key to a bound the program already has, guard against
`m^.slots[1].key.capacity` where it has none and say what is dropped, and never
clamp with `substr`, which turns two long keys sharing a prefix into one and is
the only one of the three shapes that gives a wrong answer. A `MapKeyMax`
helper was written out and rejected -- the language already answers it, and a
generic body reading `.capacity` would be meaningful for a string key alone.

`examples/word_freq.pas` is the shape-1 program and has no guard: one
`LineMax` is the line, the word and the key, and the distinct words moved out of
`PasStrVec` -- whose own 255 would have been a second capacity to guard --
into the generic vector sorted through `PasSort.SortIndexed`. Its golden did
not move. Writing the correction also found `doc/tour.md`'s generic fragment
uncompilable, its `VecGet(IntVec, integer, v, k)` predating ADR-0304's argument
order: ADR-0308's *a document can be an oracle*, arriving as the document being
the thing that was wrong.

### The fifth of the seven, closed (ADR-0309)

`PasJson` wrote `0.75` as `7.500000000000E-01`, and ADR-0295 put that spelling
in `examples/json_pretty.out` so the day it changed would be visible. It
changed on 2026-09-03, and the golden is where it was read back.

The writer now renders the value at a precision, hands what it built to
`readstr` and keeps the first spelling that returns the value it started from,
so the module converts nothing: both halves of the trip are the processor's
own. Two things about it are worth carrying. **The search starts at fifteen
digits rather than at one**, because stripping the trailing zeros off a
fifteen-digit rounding recovers every shorter spelling -- a normalised double
lies within a relative 1.1e-16 of the decimal that reads back as it, and half a
fifteenth-digit step is 5e-16 -- which turned 27 microseconds a number into
5.8. And **where the point goes is ECMAScript's rule with its citation**
rather than a threshold somebody picked, JSON being that language's notation.

What closing it found is a defect one layer over: the *reader* scales by a
decade at a time, so `JsonParse` of `1E+300` is not `1e300`. The old writer put
an exponent on every real, so the module had never been able to read its own
output back and nothing had said so. `tests/dialect/lib_json_number.pas` prints
it as a second column beside the claim, which makes the sixth finding from
somebody writing a program a finding from somebody testing one -- the same
sentence one step further along.

## What would make this easier to work on

The chapter of [`doc/roadmap.md`](roadmap.md) that carried what someone
working *on* this compiler needed, archived on 2026-09-03 when the last of its
eleven items stopped being work. Five stood in it originally and all five
closed; three more were added afterwards and closed too, two built and one
declined; and the last three were never tasks at all.

What is left of it is in three places, and nothing was lost in the move.

**A `style:` gate for the Pascal** — of the kind `git clang-format` gives the
C — was tried, measured and declined (ADR-0285). The mechanism is already
there, `format-check` formatting every source on every run and discarding the
result; what stops it is that the diff is a disagreement about style and not a
list of bugs. A full reformat of the implementation alone — `selfhost/`,
`lib/`, `lsp/`, 36 files — rewrites **25 070 lines** and grows the source
**6.8%**: 818 one-line `var` declarations split in two, 558 one-line
`begin … end` bodies expanded, 210 blank lines inserted between headings
written as a group. Fixing the five real layout defects the attempt found
moved that number **up**, 24 490 to 25 070, which is what settles it. It is a
decision for whoever maintains this source rather than a task, and the gap it
leaves is a row of [`doc/sop.md`](sop.md) §7.

**An aarch64 `benchmark` baseline** was blocked on hardware and not on a
decision, and is a row of `doc/sop.md` §7 for the same reason: the gate
abstains on aarch64 and on CI (ADR-0282), so no push is guarded by it, and a
baseline needs an *idle* aarch64 machine — the shared runner that exposed the
gap is the one place a baseline must not be taken.

**The three lessons stayed in the roadmap**, in the preamble that says how to
read it, because they are rules for the next row somebody adds rather than
history: a number needs a date *and* a command; a row saying a feature is
blocked is a row nobody has tried; and a reason written beside a declined item
is an estimate like any other, wherever it is written.

The chapter's own last finding is worth keeping beside them. Its lesson about
blocked rows was learned three times in succession and then a fourth time in a
document that was supposed to be immune — `doc/sop.md` §7, a register of what
is *not* checked, whose rows are meant to be uncomfortable. A row there said
nothing held ADR-0283's zero and gave a reason for declining a gate; the
reason was an estimate, and it was wrong by the same margin as the three
before it. **The rule does not exempt the document that states it.**

## A decimal is the language's to round

ADR-0314, closing the first item of ADR-0309's *What is not done* on the same
day it was written down.

**The finding is about which half of the trip had its own arithmetic.**
ADR-0309's writer renders the shortest spelling that reads back, and the way
it finds one is to render a candidate, read it back through the processor's own
reader, and keep the first that returns the value it started from — so the
writer had been consulting the language's converter all along. The reader had
not: it accumulated digits into a `real` and scaled by ten once per decade, so
a value was rounded as many times as its exponent had decades and a mantissa
past 2⁵³ was inexact before the scaling began. `parses=FALSE` on four of
sixteen values was therefore not a reader measured against a specification. It
was **two converters disagreeing, one of which was the language's**, and the
case could only ask the question because the writer had just been made honest.

**The fix was to stop computing rather than to compute better.** The scan is
untouched — it still validates RFC 8259 §6's grammar, which is stricter than
Pascal's — and what it produces now is a significand and a decimal exponent
written out as a real-literal, converted by `writestr` and `readstr` in two
lines. §6.9.5's required procedures are how a program hands a value to the
language's own number reading, and that reading is correctly rounded. The
module gets the answer without owning the arithmetic.

**The mutation is louder than the original defect.** Putting the
decade-at-a-time scaling back turns eight of the twenty-two round-trip columns
FALSE where the original defect turned four of sixteen — because six
adversarial values were added while fixing it, chosen for what the old
arithmetic could not have got right: two denormals, a value needing seventeen
digits *and* a large exponent, and the two integers either side of 2⁵³. A
defect found is a chance to make the case that found it sharper.

**What is not exact is written down.** At most forty significant digits are
kept and the rest move into the exponent; seventeen identify a double, so what
is dropped can only matter for a value built to sit within 10⁻²³ of a halfway
point. Keeping them all needs a string with no capacity and this language has
none.

The lesson had already been learned twice on this module and this is the third
time: **a library that needs an answer the language already gives should ask
the language.** ADR-0290's congruity rule and ADR-0310's key capacity were the
same shape — a module having taken on a decision that belonged one level down.

## The concurrency residue

All three rows ADR-0268 wrote about itself are closed, all on 2026-09-03, and
what stands is the part of the third the row itself had bundled into it. The
chapter they came from is still in
[`doc/roadmap.md`](roadmap.md#what-each-landed-feature-left-open); what is
here is what closing them found.

**A task could not close the channel downstream of it, and the program that
tried deadlocked in silence** — ADR-0295's finding 1, closed by ADR-0302 and
AP 6.4.16.4. The cause was a rule that is right about one question and was
answering another: a channel is a handle, a task's lent parameter is released
by a closer that drops the reference and does *not* close — a worker of a pool
must not close what its colleagues are draining — and that is the answer to
*this activation has finished with it* and the wrong answer to *close it*. So
the release a **program** writes now closes, in all three of its spellings,
and the release the end of a block performs is unchanged. The roadmap had
offered a compile-time refusal or a sentence in the spec; the third answer was
to make it work, on the argument that a stage closing its downstream channel
is not a mistake but the shape a pipeline has, and a silent deadlock is the
worst failure mode this language has.

**A channel could not carry a string**, which ADR-0268 had called *unclaimed
rather than done* — the distinction ADR-0080 exists to keep, and it earned its
keep here. `Transferable` admitted a `string(n)` and the reading was that the
implementation copied `esize` bytes, which is right. Writing the case showed
two things wrong at once: `send` chose its path with `IsStructured` and a
variable-string is `IsMemory` and not structured (ADR-0191's split, met a
third time), so the module did not assemble at all; and a string *value* is a
length and that many bytes, so it is shorter than the element it is going
into and copying the element's size out of it read past the arena. The store
is the ordinary assignment into a temporary of the element type now, which is
where padding and normalisation already live.

**A task could not be handed a handle** — ADR-0303, and the record worth
reading for how long a one-line gap can stand between three records each
naming it as somebody else's. ADR-0201 named it as the prerequisite for
concurrency; ADR-0267 built the move and said the position was the
construct's to widen; ADR-0268 built the construct and said the move existed
and the argument block did not use it. The whole of what was missing was that
position, and the change needed no new runtime routine at all.

**A task could not be waited on singly, and closing it cost a type and a
statement** — ADR-0312. The row read as three wants in one sentence and only
the first of them was about waiting; what it took was small because a handle
(AP 6.4.12) already had every rule a name for an activation needs — owned by
one variable, released when that variable ceases to exist, released early,
moved with `take`. So the task-type is a `tyHandle` with a flag, exactly as a
channel-type is a `tyHandle` with an element type, and `IsTask` is `IsHandle`
and that flag; nothing about release, about the move, about what may be
assigned or compared had to be decided a second time. The work that was not
free is in the runtime, and it is there because a *named* activation may be
joined from two places — `wait` on the variable, or the block's own join —
where `pthread_join` may be called once.

**Writing the client found two defects in the construct that was already
there**, neither of them reachable by anything in the corpus. A task with a
string or text **value parameter** emitted invalid IR: the argument-block
store chose its path with `IsStructured`, and a variable-string is `IsMemory`
and not structured, so it stored a global where a pointer belonged — ADR-0191's
split met a fourth time, and ADR-0302's own finding met one construct over.
The task wrapper then passed such a parameter as one aggregate, where a string
travels as a **pointer and a length** (ADR-0051, ADR-0115), so the call did not
match the callee's signature. Both had stood since the construct landed; what
had kept them invisible is that no program had spawned a task taking a string,
`send` having been the half somebody wanted first.

**And the block-end join now has a case that fails without it**, which is what
`doc/sop.md` §7 had carried a row about since ADR-0268. The oracle for a join
is weak for a reason worth stating: the obvious observation is a value the task
sent, and a channel has already synchronised that, so a test written the
obvious way stays green with the join deleted — which is exactly what
`tests/dialect/concurrency.pas` does. The discriminating observation had to sit
*outside* a channel. `tests/dialect/task_join.pas` spawns inside a procedure,
so the join is at that procedure's `end`; the task sleeps a second and writes
to a file it owns, which its block closes when the block ends; the program then
reads that file by name. Mutation says it works: with the block-end join
removed the new case fails and `concurrency.pas` stays green, exactly as the
row had predicted. What the case rests on is the task being deliberately slow
and not a construction that cannot race, and that is the honest description of
its margin.

**Waiting for whichever came first was a statement, and the runtime was the
whole of the work** — ADR-0313, AP 6.9.3.15, which closed the last of the four
rows. The language side is small: `select` opens a block whose arms are
`receive`, `send` and `after`, punctuated exactly as a case-statement is, with
`otherwise` for a program that will not wait at all and `ok := receive(c, v)`
for one that needs to tell a value from the close of a drained channel. Which
operation an arm performs is asked of the *symbol* and not of the spelling,
`send` and `receive` being required identifiers a program may declare its own
of — ADR-0087's rule met for the sixth time.

**There is no way to wait on several condition variables, and that decided the
design.** A selector waits on a single process-wide condition variable that
every channel operation broadcasts after it has changed something, then polls
its own channels again; the cost is a spurious wakeup for every unrelated
channel, and the alternative — a list of waiting selectors on every channel —
is more state in the one object two threads already share and buys nothing
until a program has many of each. What the design turns on is stated as an
**invariant** rather than an ordering: *no thread ever holds a channel's mutex
and the activity mutex at the same time.* A sender changes its channel,
releases it, and only then takes the activity mutex to broadcast; a selector
holds the activity mutex and takes channel mutexes one at a time beneath it.
The cycle that would deadlock has no first half, and that the selector holds
the activity mutex *across* its poll is what makes a wakeup impossible to
lose.

**The fairness test did not discriminate on its first writing, and that is the
finding.** Arms are tried from a rotating start, so a channel that is always
ready cannot starve the arm below it — a worker servicing a busy job queue
would otherwise never see its shutdown channel, which is the program the whole
construct exists for. The case written to pin it gave each of two channels
exactly as many values as the loop would take, and *trying the arms in written
order produces the same count*: the first arm supplies its two, empties, and
the second supplies the rest. The mutation survived a green case. It was
caught only by giving each channel more values than the loop takes, at which
point written order gives four and none where rotation gives two and two. A
fairness property needs a test where the unfair schedule cannot reach the same
answer, and "each arm won as often as the other" is not that test by itself.

**A timeout is killed by hanging, not by differing.** Making the runtime answer
the wrong index when a deadline expires does not change what the case prints —
it stops the case finishing. That is the honest signature for a construct
whose job is not to wait forever, and it is why the two deadlines in
`tests/dialect/select_contended.pas` are 2000 ms: they are not what is being
measured, they are there so that a defect losing a wakeup ends the program with
a wrong total instead of hanging until the harness kills it.

**Two gates refused to pass, and both were right.** `runtime-isoc` rejected
`clock_gettime` — the deadline is C11's `timespec_get(&ts, TIME_UTC)` now, so
the unit's bargain that one header beyond ISO C buys the whole construct is
intact. And `predicate-callers` refused until the select's send arm was added
to its table of positions: a send arm copies its value into the channel's
storage exactly as a send-statement does, so `Assignable` decides it, and
ADR-0058's sentence is that a permission granted in a shared predicate leaks
to every caller — **a new caller is a new leak until it is asked**.

**And the formatter had been indenting by an accident that no oracle could
see.** `pascalc --format` is token-driven: it takes a level on `begin`,
`record`, `repeat`, a case's `of` and `otherwise`, and gives one back on `end`
and `until`. `select` is spelled with no word-symbol (ADR-0140), so the
printer did not recognise it — but a select's `end` still gave a level back.
The depth therefore went **negative**, and every line after the first select
in a source was indented one level too far left. `format-check` was blind to
all of it, and structurally so: its three claims are about what the output
*contains*, and each held — the token stream unchanged but for positions, the
comments unchanged and before the same tokens, and re-formatting the
misindented output reproducing it byte for byte. ADR-0285's sentence that
there is no oracle for whether the output is *well* laid out turns out to cover
a correctness defect and not only a matter of taste. It was found by reading a
reformat by eye.

What stands is no longer a row. Three *shapes* outlive the four closed ones
and each is a question with an answer nobody has needed yet: a **channel of
handles**, so that a fixed pool of workers could take connections off a queue,
a task being givable a socket at the moment it starts and not afterwards; the
fact that an activation cannot **close a channel and then drain it**, all
three spellings of AP 6.4.16.4 emptying the handle variable as well as closing
the channel, so the close a select arm reports is always another activation's;
and **no timeout on `wait`**, which is a decision and not an omission, a wait
that gave up leaving a program holding a task-variable whose activation is
still running with no clause saying what that is.

## The release that checked itself

**v3.5.0, cut 2026-09-06**, and what is worth recording is not the release but
that four separate things were found by the act of cutting it — three by the
procedure's own steps and one by the only job that runs at a tag. Every one of
them had been true for days and no gate could see any of it.

**Step 2 says the build must be warning-free, and it was not.** Four
`-Wcomment` warnings had entered `runtime/pasrt.c` with ADR-0293's trap
positions: a comment naming `seed/*.ll` inside a `/* */` block, where the
path's own `/*` opens a comment inside a comment. `tests/checks/runtime_isoc.sh`
compiles that file five ways and **four of them carry `-Werror`**; pass 2 —
*and nothing else is non-standard* — had `-Wall -Wextra` and nothing else, so
it printed all four on every run and passed. `warning-free` (ADR-0286) is about
what the *Pascal* compiler has to say about this tree's Pascal and was never
going to see a C warning. The pass carries `-Werror` now.

**Step 3 says to read `-h` by hand**, because the `ctest` case for it asks
whether every flag is *listed* and cannot read the prose. Two lines were wrong.
`-o` carried a description of something else — *(the dialect: Extended Pascal
and what is added to it)* is what `--std` said, and ADR-0232 removed the flag
and left its second half attached to the option above it, so a reader was told
that `-o` names a dialect. And `--target=` named two machines where ADR-0325
admits three.

**Step 6 found the changelog was missing sixteen user-facing changes** —
everything from ADR-0312 onward, including the task type, `wait`, the
select-statement, i386, `clong`/`csize`, the protected owned parameter and all
four borrow fixes. The per-feature `docs:` commit moves a feature into README's
accepted block and had stopped keeping `CHANGELOG.md` beside it. Writing them
from the records is also where the value of checking against the corpus showed:
the select example written from ADR-0313's grammar had the wrong arm syntax,
and `tests/dialect/select_contended.pas` has the right one.

**And then the tag failed, correctly** (ADR-0347). `seed_current.sh` said the
committed seed is not what this source produces, and the difference was the
*directory*: ADR-0293 puts a trap's own source path into the emitted module, so
handing the compiler an absolute path put `/home/<user>/…` into all three seed
modules and made the check answer about where it ran. It had been true of every
seed since positions landed, eight releases earlier, because that check runs
only at a tag — and it cannot be a `ctest` case, the seed being legitimately
stale between releases. `seed-portable` now asks the cheap half on every push.

**The shape two of these share is the finding.** In one day, two harnesses
answered about the wrong machine: `llc_check.sh` compared x86-64 modules on an
ARM host and had **never passed** since ADR-0331 added it, because
`AFTERSCHOOL_PASCAL_TARGET` is read by `tools/pascalcc` and not by the compiler
the script drives directly (ADR-0345); and `seed_current.sh` compared a
directory. `doc/sop.md` §7's row for a harness ignoring an environment variable
now states it wider than that — a harness passing a path, a target or a flag
that is right where it was written and wrong where it runs.

**One of them decided a language question on the way out.** With the aarch64
job fixed, `target32` began disagreeing with itself: two cases failed on CI's
clang 19 and passed on clang 21, because the two compile `i386-pc-linux-gnu`
for `i686` and `pentium4` respectively, and an x87 register is eighty bits
wide. §6.7.6.3's `round` contradicts the clause defining it there, and D.32's
`sqr` error goes **undetected** — `sqr(-1e200)` being an ordinary finite number
in a register with a fifteen-bit exponent. An i386 this compiler emits for has
SSE2 (ADR-0346); what is given up is a Pentium III and earlier, and a missed
error condition on one target is not something a dialect aiming at modern
computing gets to have.

## The memory model, read against the goal

**A review on 2026-09-04 read the dialect's memory model against the goal
stated as *a Rust-flavoured Pascal*, and probed it rather than reading it.**
The finding was not that the design was missing a piece. It was that **the
pieces missing were not the ones the records said were missing** — ADR-0201
had withdrawn the aliasing fork as a question this language does not have, and
three of the four rows the review wrote were aliasing.

Three of those four rows closed within two days and are here as they stood.
The fourth — **a record has no `Drop`** — is still open, and is in
[`doc/roadmap.md`](roadmap.md#a-record-has-no-drop) with the rest of what is
not settled. What the three left standing is a sentence each rather than a
row, and those sentences are in the roadmap too; this chapter is the working
that produced them.

**The chapter's own lesson is about its cost cells.** Three of them were wrong
within two days of being written, each in the same shape — a count taken by
machine and the reason beside it written by hand. *And there is no third* was
an enumeration of the **names** an owned pointer has, offered as an
enumeration of the ways it can be **released**; *nothing known* priced a fix
at nothing when it had taken away every callback; and a table of nine pointer
types gave five of them a reason that probing found wrong. **A cost cell is a
report and not an estimate**, and the way to find out is to compile the
program rather than re-read the sentence.

### The three rows as they stood

#### 1. The borrow rule was enforced in one direction — closed 2026-09-04, reopened and closed again 2026-09-05

Rust's aliasing rule has two halves: a borrow may not outlive what it borrows,
**and** the owner may not be released while a borrow of it is live. ADR-0201
established the first — a `var` parameter bound to `o^` cannot escape, because
Pascal has no address-of and `new` is the only producer of a pointer — and
treated it as the whole rule. The second is unenforced, and AP 6.4.14.3 lists
three release points a callee can reach: `dispose`, `new`, and an assignment.

```pascal
procedure P(var o: op; var n: node);
begin dispose(o); n.v := 42; writeln('n.v = ', n.v) end;
...
new(q); q^.v := 1; P(q, q^)          { prints 42, exits 0 }
```

That is ADR-0201's own probe — `P(o, o)`, two `var` parameters bound to one
variable, pronounced safe — with `dispose` where the record wrote `take`.
Every oracle here agreed with it: `heap-balance` read 1/1 because the count is
honest, and a build under `AFTERSCHOOL_PASCAL_CFLAGS=-fsanitize=address`
reported nothing. **That second agreement was worth less than it looked**, and
three days later it was worth nothing at all: ADR-0342 established that clang's
sanitizer passes instrument only a function carrying the attribute and this
emitter wrote none, so AddressSanitizer had never looked at one line of
compiled Pascal — see [the oracles that were not
looking](#the-oracles-that-were-not-looking). Made observable, the write through the stale borrow lands in
an unrelated live variable — `dispose(g)`, then `new(h); h^.v := 111`, then
`n.v := 999`, and `h^.v` reads **999**. A third borrow form needs no call at
all: a with-statement's binding is a frame slot holding an address, so
`with q^ do begin dispose(q); v := 999 end` is the same defect inside one
block.

**Both forms are now refused** (ADR-0317, AP 6.4.14.7): the two
actual-parameters of one call, and a release under an open with-binding. What
the clause does *not* reach is the release the callee performs indirectly, and
that is Annex C.12 and a row of `doc/sop.md` §7 rather than an assumption.

**The cheap refusal does not close it, and shipped saying so.** Three
candidates were designed against this shape and the first was taken:

| Candidate | What it costs | Why it is not enough |
| --- | --- | --- |
| **taken**: refuse the call-site shape and the with-binding — the two forms one activation can be asked about | nothing; no program in this tree is refused, and the corpus carries five that must go on compiling | it is a narrowing and not a closure: the callee can reach the owner indirectly, `Bump(g^)` → `Clear` → `ClearIt(g)` → `dispose` of its own `var` parameter, and no local rule sees that |
| **also taken**, a day later: let the program say the callee will not release, by protecting the owner's formal parameter (ADR-0318) | nothing again, `protected` being a word §6.7.3.1 already had in that position | it is a *guarantee on request* and not a closure either — but where it is asked for it is complete, since a protected owned pointer refuses every release point and refuses being handed to anything unprotected |
| **release only in the block that declares the pointer** | sound under one thread — a declaring block is suspended for the whole life of any borrow | unaffordable, and measured: all **ten** of `PasList`'s exported routines take `var l: List` and **five** release through it, so the module could not be written |
| a **dynamic borrow flag**, Rust's `RefCell` and not its borrow checker | a word beside every owned-pointer variable and a check at three sites; the pair travels as two arguments, which is precedented (ADR-0030, ADR-0040, ADR-0051) | nothing — it is sound and complete, and it is a class A and C increment rather than a Sema patch |
| **also taken**, and it is what closed the row: refuse the borrow where it is *formed*, wherever the called block can **name** the owner (ADR-0319) | an owned structure held in a variable of the outermost block cannot be lent at all — 12 sites in this tree, every one of them a test written for the construct | nothing. 6.4.14.3 forbids copying the value, so an owned variable's only names are itself, a variable parameter bound to it, and a component of what contains it; the second is 6.4.14.7's activation-point and the first is scope, and there is no third |
| **and a third there was** (ADR-0326), found by probing the sentence to the left rather than reading it | `Runner(p^, Killer)` no longer compiles: a routine handed alongside a borrow may not name the owner | nothing known, and the residue is now an *argument* rather than an assertion — see below |
| **and the cost was larger than it read** (ADR-0332): the routine handed over may be a **formal**, whose defining-point is inside the block that declares the owner | none — it gives programs back. A block owning a variable could lend a borrow of it to nothing at all, the ordinary callback included | the argument is unchanged and one implementation of it was wrong; a formal is bound before its activation exists |

Real lifetimes are the fourth candidate and are unavailable: **a borrow here
is a parameter binding and not a value**, so there is nothing for a lifetime
to be written on.

**The sentence to carry out of this row** was *unformability is what protects
against escape and is exactly what makes invalidation invisible* — ADR-0201
reads the borrow's absence from the type system as strength, and it is strength
in one direction only. That still stands, for the escape half, which nothing
checks.

**The row was struck on 2026-09-04 and the strike was wrong**, which is the
part of this row worth reading. The claim in the last cell above — *and there
is no third* — was an enumeration of the **names** an owned pointer has,
offered as an enumeration of the ways it can be **released**. A block does not
have to name an owned variable to release it. It releases it by activating a
§6.7.3.4 procedural parameter that can, and a procedural parameter has been in
this language since ADR-0030:

```pascal
procedure Runner(var m: N; procedure k);      { names nothing of Holder's }
begin k; writeln(m.v:1) end;                  { m is disposed storage }
...
new(p); p^.v := 7; Runner(p^, Killer)         { printed garbage, exited 0 }
```

Both halves of AP 6.4.14.9 had it, and the only diagnostic was the fourth
warning suggesting `protected` — which does not help, protection stopping a
write where this is a read. ADR-0326 adds the paragraph and rewrites the NOTE,
and what stands in its place is an **argument** and not an assertion: a block
obtains a routine by scope or by being handed one, both are asked, and the two
meet at a single activation-point because that is where a borrow is formed. It
can be wrong the way its predecessor was, and the way to find out is to probe
it again.

**And the cost of closing it was mispriced in the same cell.** ADR-0326's row
said *nothing known*, and what it had taken away was every callback: `CanName`
answers from a defining-point, a formal's is inside the block that declares it,
and so a block that owns a variable could hand a borrow of it to no routine at
all — five sites, both paragraphs, and no case in the tree had the shape because
the rule was written and reviewed against programs whose procedural actual was a
*declared* routine. ADR-0332 is the fourth paragraph: a formal is bound before
its activation exists, so what is bound to it was denoted in a block whose
activation is a proper ancestor and cannot name this one's variables. The
lesson is the row above's, one column over — **a cost cell is a report and not
an estimate**, and this one was written from the programs that motivated the
rule rather than from the programs it reached.

**The invalidation half is closed**, and what it leaves is a different sentence.
Two records costed mechanisms for the residue — a call-graph summary and a
dynamic flag — and both were answering *may this release happen*. The
requirement is symmetric, so it can be enforced at either end, and the other end
is a question about **scope**: it costs nothing at run time and crosses a
program-component boundary in both directions. **A gap can be an artefact of
where the question is asked.** Annex C.12 is withdrawn, `doc/sop.md` §7's row is
struck, and what is left of this row is ADR-0201's original property — held by
construction, watched by nothing.

#### 2. The unsafe subset is the unmarked default

Rust marks its unsafe operations and makes them opt in. Here it is the other
way round:

```pascal
new(a); b := a; dispose(a); b^ := 5; writeln(b^)   { compiles clean, prints 5, exits 0 }
```

`^T` is the ordinary pointer — what every ISO program writes, what this
compiler is written with, and the unchecked one (ADR-0019, and the *one gap*
of [Known limitations](roadmap.md#known-limitations)). `owned ^T` is the safe form and
costs a word to say. ADR-0117's containment fixes what `^T` **means** and
settles nothing about what the compiler may **say**, so this row proposed a
fifth warning in ADR-0272's frame: a `new` of an ordinary `^T` whose variable
is never copied, where `owned` would have compiled.

**It was measured before it was written, and the measurement retired it —
and found something better than the warning would have.** Every ordinary
pointer type-definition outside the compiler was counted on 2026-09-04. There
were **nine**, and not one of them could take the word.

**That count was right and its table of reasons was wrong**, which probing it
later the same day found (ADR-0320). The table said five were refused for a
schema domain and four for value parameters. In fact `StrMap`, `IntVec` and
`StrVec` are themselves schemas, so `SMapPtr`, `IVecPtr` and `StrVecPtr`
belonged in the first row; and `JsonPtr`, put in the second, is refused before
any parameter is reached, because `JsonNode` has a **variant part**. Ten of
eleven — the count is eleven since `examples/arena_graph.pas` — were refused by
AP 6.4.14.2 and one by 6.4.14.3. The lesson is the one this page keeps
learning: a count taken by machine and a table of reasons written by hand are
two different measurements, and only the first was made.

**The table as it stands now**, after ADR-0320 narrowed 6.4.14.2 and each type
was compiled with the word to find out rather than reasoned about:

| Status | Which | Why |
| --- | --- | --- |
| **converted** | the two arenas in `examples/arena_graph.pas` | the block owns them; the `defer dispose` pair is gone and the example says so |
| legal, and **must not** be | `IVecPtr`, `SMapPtr`, `StrVecPtr` | `owned` is a dialect feature and these are in `lib/`, the conforming layer a reader can port to another Pascal (ADR-0120). Converting them would move three containers into `lib/dialect/` and out of reach of a conforming program |
| **converted** | `CountMap`, `WordVec` in `examples/word_freq.pas` | the module was unblocked by ADR-0323 and these two took the word; the two `Free` calls at the foot of that program are gone and the heap balance is the number it was |
| still refused, and **not** for the reason this row gave | `PathVec`, `DocMap` in `lsp/pasls.pas` | `PathVec` is a *field* of `Document` and `DocMap` holds `Document` values, so an owned `PathVec` makes the record affine and takes away the whole-record assignment the map is built on. AP 6.4.14.3 doing its job, and nothing to lift |
| still refused | `JsonPtr`, `JsonChars` | AP 6.4.14.2's other half: `JsonNode` is a tagged union, so its child pointers are fields of a variant part |

**That was the table's third error in two days**, and the shape of all three
is one: a count taken by machine, and the reason beside it written by hand.
This row said the four waited on `PasContainer`, that the module's routines
assign to the pointer, and that converting it was "a mechanical change,
`v := take(fresh)`, at about 22 sites". The count is **two** sites. The change
is not mechanical and was not about the sites at all: making them `take`
converts the module and *unconverts* every other client, because `take` is the
only operation in this language whose applicability is a property of the type
it is applied to, and `PasContainer` has both kinds of client in this tree.
That is ADR-0323, and it is a language amendment rather than a library edit —
AP 6.4.14 and AP 6.7.3.10 did not compose, and the module is the only thing
here written over both.

The compiler's own 34 are the second row again and harder: `nodePtr`,
`symPtr` and `typePtr` stand as a value parameter or a result 341, 156 and 198
times. A warning firing nowhere is what ADR-0116 rejects and what ADR-0272's
four already-shipped warnings each avoided by finding something on their first
run, so **it is not built**.

**What the count actually says is about the type and not about the warning.**
`owned ^T` has no client here not because nothing wants ownership, but
because **the only borrow this language had was an unprotected `var`
parameter**, and every container in `lib/` hands its handle to a *value*
parameter — `JsonKindOf(v: JsonPtr)`, `SMapGet(m: SMapPtr, …)`, `IVecLen(v:
IVecPtr)`. AP 6.4.14.3 forbids exactly that, so adopting the safe pointer means
rewriting every accessor to take `var` — and a plain `var` grants the caller's
ownership away, which collides with the rule of
[the row above](#1-the-borrow-rule-was-enforced-in-one-direction--closed-2026-09-04-reopened-and-closed-again-2026-09-05).

**That is settled, and it took two amendments rather than one** — and neither
was sufficient alone, which is why the row credited the first with the whole
job and was wrong.

**The borrow form was not missing** (ADR-0318, AP 6.4.14.8). §6.7.3.1's
`protected` is exactly a lend that may be read and not written, and an owned
pointer was excluded from it by §6.4.1 — whose stated reason, that a pointer
value can be copied out and disposed of through the copy, AP 6.4.14.3 had
already made false for this type. A handle-type had been protectable all along
on identical facts. `PasList`'s four read-only routines now take
`protected var l: List`, and the fourth warning found five more places for the
word in code written before there was one.

**And the schema domain was refused for a reason that reached further than it
does** (ADR-0320, AP 6.4.14.2). Releasing an owned variable means walking it,
and a schema's extents are read from a descriptor a frame holds and the heap has
not got — true, and true only where the variable holds something whose release
is more than giving the storage back. Where it holds nothing affine the release
*is* the deallocation, which `dispose` already performed. The condition is the
one the emitter was already asking to decide whether to walk.

**What is left of this row is a choice and not a blockage**, which is the third
thing this row has been wrong about. Nine of the eleven are legal as `owned ^T`
today. Two are converted. Three *must not* be, because they are the conforming
layer. Four wait on one module, and that module is where the question actually
lives: **should a general-purpose container own its storage?** An owned one
cannot be aliased, cannot be returned by a function, and must travel as a
variable parameter — which is right for a tree one block owns, and is a real
loss for a container callers pass around. `PasList` was written owned and has no
`Free`; `PasStrVec` was written indexed and has one. That the second kind exists
is not a gap.

So the facility is complete and its adoption is now a design question per
container rather than a restriction to lift — and it is a question a caller can
actually answer, which it was not until ADR-0323: `PasContainer` is now written
once for an owned type argument and an ordinary one, at two lines, and each
client chooses. The warning is still not built, and
the reason has changed twice: it is no longer that nothing *could* take the word,
nor that a rewrite is needed, but that taking it is sometimes the wrong answer —
and a warning cannot know which.

#### 3. There is no shared ownership; the release walk ended in a signal and no longer does — 2026-09-05

The dialect's answer to aliasing is refusal, given three times (ADR-0201), so
there is no `Rc` and no language-level arena, and an owned pointer admits no
back-pointer and no cursor. `PasList` states the consequence plainly — no
index, no tail pointer, every traversal recursive. What was not written down is
the failure mode. AP 6.4.14's NOTE 2 predicts it and this is the measurement,
taken again on 2026-09-04 with an 8 MB stack and narrowed:

| An owned chain of | On release, before ADR-0322 | after |
| --- | --- | --- |
| 200 000 nodes | clean, balance 0 | clean |
| 500 000 nodes | clean | clean |
| 1 000 000 nodes | `built 1000000` prints, **then exit 139** | clean, 35 ms, balance 0 |
| 8 000 000 nodes | the same | clean |

The boundary was between half a million and a million, and the message printing
first is what says it was the *release* and not the build: both were recursive,
and the build survives what the release did not, having no owned value to
release per frame.

It was the one capacity in this language that ended in a signal instead of a
diagnostic. ADR-0012's claim is that a full buffer is survivable **as a
diagnostic**, and the per-domain release routine was outside that claim: the
safe container's release path was the crash.

**It is a loop now, for a chain.** Where the domain has a field whose type is an
owned pointer to that same domain, the release empties that field, releases the
rest, disposes the variable and goes round again at what it took out — 6.4.14.6's
move written by the release rather than by a program, and the emptying is what
keeps the walk from releasing it twice. One frame, however long the chain.

**And a tree costs one frame as well** (ADR-0333, 2026-09-05). ADR-0322 left
*a tree still costs a frame per level* and priced it as the shape that does not
occur. Two programs written side by side say what the sentence hides:

| `Node = record v: integer; l, r: Own end`, 400 000 nodes | On release |
| --- | --- |
| `fresh^.l := take(head)` | clean, exit 0 |
| `fresh^.r := take(head)` | `built` prints, **then exit 139** |

The same program, differing in which of two identically typed fields it uses,
and nothing in either source says which one the release will walk. **A capacity
that moves when a declaration is reordered is worse than a bound**, and 400 000
is not a large tree. Every self-owned field is now emptied and pushed onto a
work list *threaded through the link fields of the nodes waiting on it* — no
allocation, and the one-field case emits exactly the code it did before.

What is left is stated rather than measured, which is the difference: a
self-owned pointer the domain does not hold **directly**, inside an array or a
sub-record component, has no link to thread; and a cycle of two domains is two
routines calling one another. Neither is reachable by writing a list or a tree.
The alternative — a depth counter and a diagnostic — is priced in ADR-0322: a
call per node released, on every program, to report a case that is now much
harder to reach. Two ways out, both Rust's —
reference counting, which then owes an answer about cycles; or the
arena-and-index shape, which is what a Rust programmer reaches for when the
data is not a tree and which **needs no language change at all**.

**The second is now written down**: `examples/arena_graph.pas`. One block holds
every node and the links are *indices* into it, which is precisely the thing an
owned pointer refuses — an index may be copied, compared and stored twice, and
it cannot dangle, because nothing it names is separately freed. The example
holds a graph with a cycle and with two arcs into one node, neither of which an
owner per node admits, and then a path of a million nodes: **18.8 MB peak RSS,
13 ms, walked by a loop and released by two calls to free**, where the owned
chain of that length dies at the end of its block.

Two costs came out of writing it, and both are in the file. **The arena cannot
itself be `owned`** — its type is a schema and AP 6.4.14.2 refuses that domain —
so it is an ordinary pointer whose release is written, which `defer` (ADR-0175)
is where. And **an index is unchecked in the way a pointer is not**: a subscript
is bounds-checked (ADR-0017), so an index outside the arena traps, but an index
into the *wrong* arena is an integer like any other and nothing here can see it.
That is the trade the shape makes, and it is the one Rust's arena crates make
too.

What is still open in this row is the first way out. Reference counting is
unbuilt, and nothing has asked for it: the arena covers the non-tree data, and
the release-depth crash has a documented shape to move to. **The crash itself
is unfixed** — a program that wants a chain of a million owned nodes still has
no diagnostic, only a signal.

**That last sentence was stale as the row was written, and it is worth leaving
in with the correction beside it**, because it is the chapter's own lesson
about cost cells arriving in a *residue* cell. ADR-0333 had already made the
chain and the tree cost one frame each, so what is left with no diagnostic is
the shape the work list cannot thread — a self-owned pointer the domain does
not hold directly, and a cycle of two domains. Neither is reachable by writing
a list or a tree, which is exactly why the sentence naming the reachable case
went unchallenged.

### The ordinary pointer, measured and kept

**Decided 2026-09-05: kept, and written down as the unchecked form** (ADR-0336).
The two ways out were measured rather than weighed. *Retire* fails on the
numbers: 41 ordinary-pointer type-definitions outside `tests/`, and **0 of 41**
convertible to `owned ^T` plus a borrow — three `lib/` containers are the
conforming layer ADR-0120 keeps portable, `JsonPtr` is refused by AP 6.4.14.2's
variant part, `DocMap` by AP 6.4.14.3, an owned field making `Document` affine
and killing the whole-record assignment the map is built on. The compiler's own
34 decide it: its node graph has back-edges and shared singletons rather than a
tree, its three pointer types stand in a value-parameter or result position 695
times, and it calls `dispose` **not once** — every textual hit in the three
components is a comment, a diagnostic string, the identifier `disposeValue` or
emitted `@pas_dispose` IR. It is arena-until-exit, so there is no lifetime for
an owner to model. And retiring would break containment outright:
`new(p); q := p; dispose(p)` is conforming Extended Pascal and ADR-0117 obliges
this dialect to accept it and mean the same. *Check* is admissible where it was
assumed not to be — no `^T` crosses AP 6.7.7.3 and no `@cstruct` record may
have a pointer field, so `foreign-layout` and ADR-0328 are untouched — and dies
instead on cost: ADR-0325 admits i386, so there are no spare address bits and a
generation must be a fat pointer re-baselining every offset `target-layout`
watches, or a side table costing a call per dereference; and soundness requires
`dispose` stop returning storage, so the checked pointer becomes the one that
leaks by design. With no caller asking, that is not a trade worth making.

## The last of the daily-program rows

*Writing a daily program* was the half of **What would make this practical to
pick up** that asked what a person writing an ordinary program runs into. Every
row in it closed, and each has its own chapter here — [what a program reads can
be cut without a word](#what-a-program-reads-can-be-cut-without-a-word----closed-adr-0305),
[the four examples that collided with a library
name](#four-of-twelve-examples-collided-with-a-library-name----closed-adr-0306),
[a JSON number that is the shortest one that reads
back](#the-fifth-of-the-seven-closed-adr-0309), [the bound that was not the
map's](#and-a-second-of-them----the-bound-was-not-the-maps-adr-0310), [a decimal
being the language's to round](#a-decimal-is-the-languages-to-round) and [the
concurrency residue](#the-concurrency-residue).

**The last of them is here because it has nowhere else to be**, and because
what it found is the chapter's own lesson stated a third time: a row saying a
feature is unavailable is worth less than the four lines that ask the compiler.

- ~~**Inference cannot read a type parameter through a whole array**, only
  through a slice-designator.~~ — **done** (ADR-0316), the day after it was
  written down, and **the row had the direction wrong**: it said AP 6.7.3.10.4
  c) was narrower than the parameter it describes, and the clause was right
  all along. It defers to 6.7.3.9.3 for what is admitted, and 6.7.3.9.3
  admits a whole array; it was `Determine` that asked `IsSlice(t)` and so
  read only what was already a slice. The clause is widened in the one place
  it needed to be — an array indexed by something other than an integer now
  determines and is then refused for its index-type, so the reader gets that
  message rather than being told to write a type argument first — and the
  fix reached two shapes nobody had asked for either, a schema-produced array
  and an array whose component is structured. The original row, for the
  record: `Determine`'s slice arm asks whether the
  *actual's* type is a slice, and an ordinary array's is not — the conversion
  happens at the call — so `Total(r)` against `function Total(T: type;
  protected var xs: array of T)` is refused with *nothing in this call says
  what 't' of 'total' is*, while `Total(r[1..3])`, `Total(digit, r)` and the
  non-generic `Plain(r)` over `protected var a: array of digit` all compile and
  run. The whole array **is** admitted where `array of T` stands; it is only
  AP 6.7.3.10.4 c) that is narrower than the parameter it describes, so
  ADR-0266's own example `procedure Sort(Elem: ordered type; var a: array of
  Elem)` cannot be activated by inference from an array. Found by probe while
  settling ADR-0315's open question, and **nothing in this tree had ever
  written that call** — `generic_infer`'s one slice activation passes a
  slice-designator — so no oracle here could have said so. That is ADR-0304's
  own lesson a third time: the row that says a feature is unavailable is worth
  less than the four lines that ask the compiler.

## A project is a convenience over a file

**A person who unpacks the release archive has `pascalc`, a library reachable
by name, and no answer to *where do I put things*.** `pascalcc new-project
<name>` — alias `new` — writes one, and `build`, `run` and `test` read what it
wrote (ADR-0348, 2026-09-06).

**The objection had to be answered before the feature could be written**,
because [`doc/tour.md`](tour.md#there-is-no-manifest-and-no-build-order-to-maintain)
has a section called *there is no manifest and no build order to maintain*. The
property that section claims is that the **import graph** is inferred:
`import greet;` finds `src/greet.pas` by name (ADR-0244), and no key in
`afterschool-pascal.toml` lists a module. What the file carries is what the
compiler cannot infer and a person carries in their head instead — which source
is the program, where the executable goes, the optimisation level, the target,
extra import paths, and the link flags. A program using `PasTls` had to know to
set `AFTERSCHOOL_PASCAL_LDFLAGS=-lssl -lcrypto`, and nothing told it so.

**The skeleton teaches the property rather than contradicting it**: `src/` is
where the import search already looks, so the generated module is imported with
no path and no declaration anywhere.

Three smaller decisions are worth keeping because each was decided rather than
defaulted. A subcommand is recognised as the **first** argument and nowhere
else, which is ADR-0140's rule for a command line one position over — a source
is `something.pas` and an object `something.o`, so a bare word in first position
is a shape no invocation has, and `pascalcc build.pas` still compiles that file.
The config reader is a strict TOML subset that **refuses what it does not
understand**, naming the line, because a misspelling in a build file is
otherwise found by the build being quietly wrong. And the four subcommands live
in the driver rather than in a program of their own, because `build` must live
where the compiling happens.

**What kept it from being decoration was three checks and one run.** `test`
exists so that `test/` means something; the link-flag key is proved in both
directions, `-lm` linking and a library that does not exist failing; and the
generated program is required to **run**, which is what caught the generated
module ending `end.` where a module's routine ends `end;` — reading the
generator did not catch it. `tests/checks/new_project.sh` is a harness because
no test case can be one: every case in the corpus is one `.pas` compiled where
it sits, and this asserts a directory the driver wrote and a config it read
back.

**And it moved a gate one dispatch over.** `producttest` derives its
documented-flag list from the *argument loop*, and a subcommand is a separate
dispatch before it, so a new one would have been undocumented and unasked —
exactly the defect that check exists for. It derives from the dispatch's own
arms now, so a fifth subcommand moves it without the check being edited.

## The oracles that were not looking

**Five gates landed in two days over one finding, and the finding is that this
project's oracles were measuring a quarter of it.** ADR-0342's audit had
already said the worst of it and the record had not been acted on; a coverage
review asked what is measured and the answer was **46 718 lines of 67 931**.

**The dumps a tool asks for had no corpus** (ADR-0349, 2026-09-06). It was
found by being asked what the MCP server is for: driving it to answer the
question, `outline` reported `lib/dialect/passortx.pas` as one line — which
reads exactly like a file that declares one thing. It was a crash.
`--dump-symbols` trapped on **any source containing a trait**, ADR-0338 having
put `nkTrait` and `nkImpl` into a block's declaration list where `DumpSymBlock`
read them through the procedure arm, which §6.5.3.3 makes an error and
ADR-0118's guard reported. 888 cases were green: `tests/dumps/` has one case per
flag over one small source apiece and both symbols cases predate the object
model, the coverage sweep passes `--dump-all` which is tokens, AST and Sema and
not this, and `lsp/sessions/` named `pasjson.pas`, `symbols_module.pas` and
`hello.pas` — so the server had never been asked about a trait, a task, a
channel, an owned pointer, an optional or a slice either. `tool-dumps` is the
mechanical answer: every tracked `.pas` through `--dump-symbols`,
`--dump-uses`, `--dump-words` and `--dump-imports`, requiring the compiler to
survive — ADR-0269's *did the compiler survive every invocation* asked of the
dumps.

**Its own first two runs found the harness rather than the compiler, and the
second is the lesson.** `git ls-files` quotes a path holding non-ASCII bytes and
`lsp/sessions/workspace/` has one named in Japanese, so eight invocations
"crashed" on a name that reached the compiler with literal quotes in it; `-z` is
not a nicety there. Then it enumerated **zero** sources on CI and its floor
caught it (ADR-0282's rule paying again): a CI container runs as a different
user than owns the checkout, so git refuses it outright — *detected dubious
ownership* — and `git ls-files` answered nothing, while locally it answered 881
and the gate passed. **A gate that reaches for git has to survive git
declining**; it is `find` over the roots with git as an optional ignore-filter
now, which is `variant_check.sh`'s shape, and it answers 883 sources and 3 532
invocations either way.

**Three quarters of the tree was measured by nothing** (ADR-0350, ADR-0351,
ADR-0352). `line_coverage.py` iterates the compiler's three program-components
and nothing else, so `lib/` (11 160 lines), `runtime/*.c` (5 551) and
`lsp/pasls.pas` (3 814) had no instrument at all:

| Gate | First reading | Cost |
| --- | --- | --- |
| `lib-coverage` | 2 165 / 2 554, 84.8% | 6.7 s |
| `runtime-coverage` | 2 342 / 2 778, 84.3% | 48 s |
| `lsp-coverage` | 1 303 / 1 396, 93.3% | 2.4 s |

**One problem, met three times, and the third statement of it is the useful
one.** `$PASCOV_LINES` records a bare line number and no file, so a program
linking six modules yields six sources' lines in one heap. `lib-coverage`
instruments exactly one module per link, which is `line_coverage.py`'s own
trick. That is not sufficient for the server: a **generic** routine's body is
emitted into the translation that activates it (AP 6.7.3.5), so eighteen
`PasContainer` bodies live in `pasls.ll` carrying `PasContainer`'s line numbers,
and read naively the answer is 1 474 / 1 376 — wrong in both halves, 48 lines
not being the server's and 30 of the server's own reading as covered because a
vector operation ran. `lsp-coverage` asks `--dump-symbols` which routines the
source declares, treats every other body as foreign, subtracts its lines from
both, and ratchets the 30 that collide *upward* as `ambiguous`, because a new
generic call site would otherwise shrink the denominator and read as an
improvement. **The same clause bites `lib-coverage` the other way round**: a
module whose routines are all generic contributes nothing to its own IR, so
`passortx` reports a denominator of **0** — which means *nothing measurable
here* and never *all covered*, and the run names such modules so the two cannot
be confused.

**`runtime-coverage` is the denominator the sanitizers were missing.** ADR-0342
established that ASan never instruments compiled Pascal, so `runtime/*.c` is not
part of what the four checkers watch — it is the whole of it, and an uncovered
line there is a line all four looked at zero times. It is a third **mode** of
`sanitize.sh` rather than a fourth copy of the corpus loop, for ADR-0327's
reason: the 120 lines that build a second runtime and link a case's components
are what must not be duplicated.

**Valgrind sees what the four sanitizers cannot** (ADR-0353). ADR-0342's
largest finding was that `new(p); q := p; dispose(p); q^ := 5` prints 5 and
exits 0 under a fully ASan-linked binary. The fix that record measured was an
attribute on every emitted function and it was not taken, fearing what it would
change; Valgrind needs no such decision, because it reads the binary. **377
programs, 0 flagged** — the corpus is memory-clean, which is a statement this
project had not been able to make before. It is a fourth mode of the same
harness and the only one that changes no build flag at all, and its detector
needed a third vocabulary: the existing arms match `==pid==ERROR:` and
`file:line:col: runtime error:`, and Valgrind writes `==pid== Invalid write of
size 4`, so without an arm for it the mode would have swept 377 programs and
reported every one clean. That is `format-check` sweeping an empty list
(ADR-0282) in a new place, and the arm was written before the result was
believed. It is the slowest gate here at 170 s and it sets the suite's wall
clock; ADR-0281's 86 seconds is history, and that is the price of the only
oracle this tree has ever had for the class.

**`require-consistency` caught the author's own omission**, which is what it is
for: `VALGRIND_REQUIRE` was read by `sanitize.sh` and set by no workflow, and
the gate said so in those words.

**And a line that runs when a thread loses a race cannot be held by a ratchet**
(ADR-0354). Made two-way like its siblings, `runtime-coverage` failed on CI at
once: 433 lines never run where the file said 436, nothing in the tree
different. Four measurements said 436 — this machine, clang 19 in a container,
the same pinned to two cores, the same on one core. The fifth, one core under a
busy loop, said 433 and named the unit: the `ETIMEDOUT` arm of `select` at
`runtime/pasrt_task.c:406-409`, reached only when the deadline beats the
receive. Gated against a loss, a faster box than the one that wrote the file
fails; gated against a gain, CI does. So `pasrt_task.c` and `pasrt_posix.c` —
the two units holding a wait with a deadline — print their delta and are not
compared, and `pasrt.c` and `pasrt_unicode.c` fail in both directions. **The
reported set is written down rather than derived**, so a comment mentioning
`poll()` cannot quietly ungate a unit, and every unit held both ways is checked
against its source for such a wait, so a `poll()` added to `pasrt.c` later fails
with a message rather than becoming a flaky number.

**The intermittent that was investigated alongside all this was not the
compiler; it was me** — `tests/extended/lib_strings.pas:10:53: unexpected
character '}'`, seen once in a sibling agent's coverage sweep. The position was
correct for the file, so nothing had been truncated; 400 parallel compilations
were clean; Valgrind found zero errors translating that file and all three
program-components. The transcript settled it: the sweep printed exactly one
error line and none at 6:18, where a backtick would have been reported first had
the comment been missed, so the comment had *ended early*. Nothing in the
committed file ends it there — but the file as `lib-coverage`'s mutation check
rewrites it does, every line matching `Reverse(` becoming `{ removed }`, and
line 6 of the leading comment contains `Reverse(s)`. The sweep read the tree
during the second the mutation held it. `tests/mutation/run.py` refuses to start
with uncommitted changes precisely so that this cannot happen; a mutation done
by hand bypasses it.

**And then the attribute ADR-0342 had measured and declined was taken**
(ADR-0358). Every function the emitter defines carries `#1`, and
`attributes #1 = { sanitize_address sanitize_thread }` is written beside `#0`'s
`returns_twice`. With compiled Pascal instrumented the corpus is **377 clean
under ASan, UBSan and LSan in 81 s** and the eleven concurrent programs are
clean under TSan in 8 s — so what the record had feared the corpus contained,
the corpus did not contain, and nobody had measured it. The attributes are inert
without the flag: a compilation that asks for no sanitizer emits four characters
more per function and one line more per module and behaves as it did.

**`sanitize.sh` proves its instrument before it sweeps**, which is the part
worth copying. In address mode it compiles a use-after-free through the same
driver, compiler and second runtime every case gets and requires the ASan
report; in thread mode, two tasks incrementing a global through a procedure
(AP 6.7.8.2 NOTE 3) and the TSan report. A compiler built from the previous
commit fails that step in both modes. **Seven define writers, all seven
attributed** — the first measurement attributed the routine emitter alone, and a
probe with no routines in it printed 5 under the result.

## The library asked the language for something

**`PasContainer`'s map keys itself with a trait** (ADR-0355, 2026-09-07), and
that is the shape ADR-0341 priced and no component in this tree had: a trait
declared in a module heading and used as the bound on a schema's type-valued
discriminant. `trait Key` — `Hash(k: Self)` and `Same(a, b: Self)` — binds the
map's key discriminant as `Map(K: Key; V: type; cap: integer)`, `MapPut`,
`MapGet`, `MapHas` and `MapDelete` lose the `StrHash, StrEq` pair, and
`FindSlot` and the rehash call `Hash` and `Same` with each call selecting the
client's implementation by the key's type (AP 6.7.10.2).

**The module cannot implement `Key` for its own `MapKey`**, which is ADR-0341's
rule doing its job, so every client writes the block — three in `lib_container`,
three in `lib_container_key`, one in `word_freq`, and the language server's URI
map. **Thirty-four argument pairs gone, every golden unchanged, all 32 LSP
sessions byte for byte**, and it is the first trait client that found no
compiler defect. `StrHash` and `StrEq` stay exported as what a string key's
implementation calls, being schematic over the capacity (ADR-0290).

**What it did find is a cascade, and closing it took a type flag** (ADR-0356).
A schema whose type-valued discriminant fails its bound produced `^integer` —
the placeholder every error path leaves — and `InstantiateGeneric` then re-read
every generic body against it and reported faults **located in the library**:
seven lines for one `MapInit`, a hundred for a client that put and got, all
after the one line that was the diagnostic. And `CheckCall`, handed nil by
`InstantiateGeneric`, fell through to the trait scope and the required
identifiers and wrote *unknown function 'bigger'* under the refusal that had
just spelled `bigger`; four goldens had carried that pair fifteen times since
generics landed, the procedure-statement path never having had it.
`typeRec.isErrType` is `nErrType`'s twin for a type (ADR-0306), read in
`InstantiateGeneric` before a category or a bound can be asked of `^integer`,
and `CheckCall` reads nil as *reported*. **Five goldens shrank and none gained a
line**, each removed line checked against the golden it left.

**And an outline called a task a procedure** (ADR-0357). `--dump-symbols` wrote
`procedure` for every `nkProcDecl` that was not a function, so an editor's
outline and the MCP `outline` tool drew a task as one. A task is started by
`spawn` and cannot be called — `CheckStmt` refuses a procedure-statement naming
one — so the old word sent a reader to the wrong construct. The vocabulary is
eleven words now; `pasls` maps `task` beside `function` for `SymbolKind` and
`CompletionItemKind`, the protocol having no nearer kind.

**v3.6.0 was cut on 2026-09-07**, and it is the first release whose headline is
a *library* change that breaks existing programs: every map call loses two
arguments. Minor, because the accepted language and the command line grew and
nothing they already accepted changed meaning.

## The 32-bit port, and the width it left

The roadmap's cross-platform chapter carried these two rows struck through for
two days, each with its whole body, and this is where the bodies went. What
stays there is what they left: s390x, Windows, and a macOS nobody has tried.
The measurement the port rests on is
[above](#cross-platform-support-measured), made on 2026-08-22.

### The two rows as they stood

#### 32-bit, which is the real work — done (ADR-0325)

Struck on 2026-09-05, and the row named **four** rules where there are seven. It had `LlSize` says
a pointer is 8, `tyProc` and `tySlice` are two pointers, and `tyFile`'s
alignment is 8; what it left out is `tyInt64`, `tyReal` and `tyHandle`, which
i386 aligns to 4 as well — the three a reader would not have caught, a wrong
alignment costing no diagnostic anywhere. `PtrSize` and `WordAlign` are the
two functions every one of the seven now asks, `--target=i386-pc-linux-gnu`
is admitted, and **573 of the 574 corpus sources build and run there** —
564 of 570 on the day the port landed, and the six became one when
ADR-0328 gave a foreign declaration a way to name a C integer of the
target's width. The gate prints its own denominator and it moves with the
corpus: `bash tests/checks/target32.sh`, 2026-09-05.

**Running it found two defects no arithmetic check here could see**, neither
in a layout rule and neither in a frame: `pas_select` indexed its arm array
with `sizeof` where the compiler strides `PAS_SELECT_ARM_SIZE` — one number
on an LP64 target and two on i386 — and the compiler wrote the arm's fourth
field at a literal 16, where i386 puts it at 12. `target-layout` passed with
both in place and `tests/dialect/select.pas` segfaulted, which is why
`target32` exists.

**And it left one question that only a release found: *which* i386.**
Nothing in the triple names a processor, and clang's default for it moved —
clang 19 compiles `i386-pc-linux-gnu` for `i686` and clang 21 for
`pentium4`. On the x87 an eighty-bit register makes §6.7.6.3's `round`
contradict the clause defining it, and — the one that decided it — D.32's
`sqr` error goes **undetected**, `sqr(-1e200)` being an ordinary finite
number in a register with a fifteen-bit exponent. **An i386 this compiler
emits for has SSE2** (ADR-0346): `tools/pascalcc` names `-march=pentium4`
for that triple and no other, and `doc/implementation-defined.md` §2.2 says
so where it answers what the real-type is. What is given up is a Pentium III
and earlier, which is the trade ADR-0109's own test settles.

**ADR-0129's `i64` at the foreign boundary was the second, independent
question**, and it read as still open here for as long as it took to write
the row below, which decides it the same day. Five of the six failures the
port catalogued were it: a declaration naming a C `long`, `size_t` or
`time_t` as `int64` is right on LP64 and four bytes too wide on i386, and
`strlen('hello')` answered 21474836485. The sixth was
`tests/index_span.pas`, which allocates 2 GB on purpose and is the one row
left.

#### How a foreign declaration should name a C `long` — decided (ADR-0328)

The question was ADR-0129's, and it was **decided** the same day it was measured (ADR-0328, AP 6.4.2.7). `clong` and
`csize` are required identifiers denoting `int64` or `integer` by target, and
**two rather than one** because the two widths are not the same question:
they agree on all three admitted targets and differ on Windows x64, which is
LLP64 and is the next target this chapter names. All five catalogued cases
pass and `tests/checks/target32_known.txt` is down to one row — the program
that allocates 2 GB on purpose.

Two things came out of it that a decision alone would not have. One of the
five was **not a declaration**: `pas_gettimestamp` wrote `now = (time_t)v`
and a truncated `LLONG_MAX` lands on 1969-12-31, a date the calendar accepts,
so a program asking for an unrepresentable instant was told it was valid. And
the portable narrowing is **two lines and not one** — admitting `trunc` of an
integer would have made it one, and would have withdrawn a conformance fix
taken deliberately from the validation suite's DEV158, in a commit about a
foreign boundary where nobody would look for it. `tests/trunc_integer.pas`
caught it in the same run.

**And a sixth was still there, invisible at the level the gate ran at**
(ADR-0334, 2026-09-05). `tests/dialect/int64_foreign.pas` declared C's `labs`
as taking an `int64` — the wrong ABI on every ILP32 target, and it had been
wrong since the file was written on 2026-08-19. `target32` swept it 570
sources at a time and passed, because at `-O2` the optimiser folds `labs` of
a constant away before the ABI matters; at `-O0` it answers
`-3028092405585415680`. **No job ran the combination** — `thirty-two-bit`
took the default `-O2`, and the `unoptimised` job has no 32-bit libc, so
`target32` skips inside it and ctest reads a skip as success. Two jobs, two
axes, and the cell where they cross was empty. The job runs the gate at both
levels now, and the general form of it is `doc/sop.md` §7's rather than this
page's.

### The width, a third time — closed (ADR-0364)

Twice above a foreign declaration naming `int64` for a C `long` was found by
running the corpus on i386 — five in the port's catalogue, and `labs` at
`-O0`. The third time no corpus could have found it, and that is the whole of
the record.

**`time` bound as `int64` answered 7682741216296735854** on CI's i386
container (ADR-0364's context), `time_t` being a `long` there and the high
word whatever the spare register held. On the machine that wrote the fix the
register happened to be clean: the wrong binding gave the right answer,
`target32` was green with the defect in it, and the mutation putting `int64`
back **survived**. A width defect at the boundary has no behavioural test on
any one host, which is the shape ADR-0325's own rows had missed — both of
those were found by a program *behaving* wrongly, and this one behaved
correctly everywhere but one container.

The audit that followed applied that one lens to every `external` in the
tree and found the same shape **nine more times**, none provable: `read` and
`write` answer `ssize_t`, `fflush` takes a pointer, and six OpenSSL bindings
are `long`s and pointers — all `int64`, and the TLS six unreachable even by
the container, since libssl cannot be built for i386 on CI at all. And one in
the **compiler**: the emitter widened a slice's count to `i64` on every target
(ADR-0129), where i386's `size_t` is `i32`. It worked there by cdecl's grace,
the callee reading the low word and stepping over the four bytes above it, and
`doc/sop.md` §7 had carried a row saying exactly that the widening was right
for a reason no program could exhibit — written for LP64, and falsified the
day a target that was not LP64 was admitted, without anyone re-reading it.

**What closed it is a catalogue and not a case** (`foreign-width`): every
heading ending in `external` under `lib/` and `lsp/` that names `int64` must
carry a row saying which C type is 64 bits everywhere — `ExtFileInfo`'s
`long long *` is the one such row — and the emitter's declaration is read
back from a probe compiled per admitted target, `ptr, i64` on the two LP64
targets and `ptr, i32` on i386. Both directions, and deterministic where the
corpus was a coin. The mutation that survived is killed on every host.

## After v3.6.0: a configuration file, and the boundary audited

Six records in one day, 2026-09-07, none of them a language change, and the
first four of them one thread.

**A NaN answers no to both questions** (ADR-0359). `PasJson`'s guard against a
value with no decimal spelling asked `x <> x`, which on this processor is
*ordered* not-equal and false for a NaN, so writing one stopped the program
inside the library with an index out of bounds. The guard asks `not (x = x)`
now, `RealToStr` moved to `PasText` where a second format could reach it, and
the question the record opens — whether `<>` on reals should be the negation
of `=` — is a `doc/sop.md` §7 row and not decided.

**A TOML document** (ADR-0360) is the thirty-third module: TOML v1.0.0 whole,
because a subset of a format is what `pascalcc`'s project reader had been and
what ADR-0361 replaced the next commit — `output = "build/demo#1"` had
silently built `build/demo`, and a one-element array holding a comma was three
malformed strings. `bin/apconfig` reads `afterschool-pascal.toml` over
`PasToml`, is built by the compiler the tree just produced, and writes
`key=value` for a `case` in the driver to read; the driver stayed a shell
script by decision.

**A command is words, not a line** (ADR-0362). Answering the `apconfig`
question found that `lsp/pasls.pas` assembled a shell command and quoted the
source path with apostrophes, so a file named `a'; touch PWNED; echo '.pas`
ran `touch PWNED` when an editor asked for its outline — proved by doing it,
over MCP, before the record was written. `PasProcess.Execute` and four
routines beside it carry an `ArgV` through `posix_spawnp` and no shell reads
them; the server was converted, `Run` stays for a line a person wrote, and the
`command-injection` gate holds both halves — that nothing runs, and that such
a file still compiles.

**A boundary answers; it does not stop** (ADR-0363). The `security-audit` run
over that change the same afternoon returned six findings, four of them older
than the routine they were found through: a path holding `chr(0)` stopped the
server on one request, `ExecuteToFile` followed a symbolic link and the
server's scratch files were composed at the top of `TMPDIR` under a guessable
name, no `Execute` had a deadline, a child inherited every open descriptor,
three `posix_spawn` file-action returns went unchecked, and a failed `fdopen`
dropped the output silently. One rule closed all six: a library routine that
takes a value from outside answers with a code, and the trap is for the
program's own mistakes. `Deadline`, `TemporaryDirectory` over `mkdtemp`,
`O_NOFOLLOW`, `FD_CLOEXEC` and the mode letter `e` on every `fopen` are the
mechanism; the project-wide audit that followed applied the rule to
**nineteen** routines across six modules, each of which had reached ADR-0122's
trap on a name holding `chr(0)`, and to the width above.

**What the day argues** is the sentence `doc/sop.md` §7 already carried: a
gate that prints a claim it never evaluated. Nothing here was found by an
oracle failing. The injection was found by reading a program while answering a
design question; the six findings by an audit commissioned on the change that
closed it; the width by one CI container with a dirty register; and the nine
bindings by applying that container's lens by hand to every declaration,
because no container could reach six of them. Each is now held by a gate whose
first act was to fail on the defect it was written for.

## The blind-spot register: the audits, and what closed

`doc/sop.md` §7 is the live register of what is not checked, and it was
compacted on 2026-09-07 to the open rows and a dated audit log. Everything it
had accumulated that is *settled* — every end-to-end audit with what each
found, every row struck as closed with the reason, and the list of gaps closed
before the register had rows — is here, verbatim, in the order it stood. The
open rows are still in `doc/sop.md`, each shortened to its claim; the record
each cites carries the working.

### The audits, as they were written

**Audited as a whole on 2026-08-25** (ADR-0197), for the first time in 57 rows — until
then it had only been appended to, which is the decay a register is supposed to
prevent happening to the register itself. Four rows had gone stale in a way
that mattered. Two ended "nothing is implemented yet", dating themselves from a
record whose feature had since shipped; one carried a citation count from
before four increments moved it; and one — the string-arena counter — said
"a fifth producer would have nothing looking for it" while **three** had
arrived and none had. Fixing that last one is the whole argument for reading
this file rather than only writing to it. Re-audit after a milestone, as
`docs-engineering` does for the rest of the documentation.

**Audited as a whole again on 2026-08-29**, after ADR-0243, ADR-0244 and
ADR-0245 landed in one batch. Five kinds of decay, and the two sharpest were
not in this register at all — which is the argument for reading the whole
documentation set on the same pass rather than only this file.

- **A table that had stopped being a table**, twice. `CLAUDE.md`'s gate list
  had the `runtime-isoc` row split in half by the `unicode-conformance` row
  wedged between its two pieces, and this file had a row broken across two
  lines; both render as a mangled row and an orphan paragraph. `CLAUDE.md` is
  loaded into *every* session before any work starts and the damage had
  survived however many readings since. **`markdown-tables` is the gate that
  answers it** — every row the width of its header, in 92 tables across 274
  files — and the class is why it is a gate rather than a proofread: a broken
  table renders as something that still looks like documentation.
- **And a third that the gate deliberately does not reach.** A cell held
  `grep -lic 'mutation\|mutant'` in a code span, and GFM turns `\|` into a
  literal `|` *everywhere*, code span included — so the command rendered as
  `'mutation|mutant'`, which under basic `grep` matches a pipe character rather
  than either word. The source was well formed and only the reader was misled;
  nothing can tell it from a cell that wants a literal pipe. It is rewritten
  without the alternation, and its counts had drifted too: 103 of 234 → 107 of
  246.
- **An arithmetic claim in prose, and it was false.** Two documents illustrated
  `MapKey`'s 63-character bound with a URI that is **44** characters and fits.
  The finding was true — one from this checkout's own `selfhost/` is 67 — and
  the illustration of it was not. That is the shape ADR-0072 named for clause
  numbers, met for a *number a reader could add up*: no oracle here checks
  arithmetic written in prose, and the wrong example had been copied into a
  second file.
- **Six counts quoted from a gate had moved.** `variant-check` 936 → 952
  sources and 2855 → 2935 guards; `target-layout` "four and a half thousand" →
  9320; `heap-balance` 7 of 29 → 5 of 39; `clause-citations` 9145 across 1505
  files → 9344 across 1537; `pending.txt` 187 → 188; and `procedure-coverage`
  679 of 681 → **629 of 631**, which had moved *down* and so could not have
  been explained away as growth. Every one was found by running the gate, which
  is the only way any of them is ever found.
- **A catalogue quoted as three where the gate says six.** `runtime-isoc`'s
  POSIX header list gained `<netdb.h>`, `<poll.h>` and `<sys/socket.h>` with
  ADR-0203 and ADR-0205, and the sentence naming it was never touched — a
  *porting cost* understated by half in the file a reader consults to learn it.
- **The `model-drift` CodeGen-region row met for a third and fourth time**, by
  ADR-0244 and ADR-0245. Both were driver and emitter work below the banner
  with no lowering in them, both needed the trailer, and one increment earlier
  in the same week was pushed without it. The row was right, and reading it is
  what put the trailer on these two.

**The numbers re-run on 2026-09-01, and only the numbers.** Not an end-to-end
read of every row — this was the narrower sweep the skill that governs these
audits names as its own structural blind spot: *step 2 audits what a document
says about the code, and a document quoting a gate is a different question.*
Every count in `CLAUDE.md`, this file, `README.md` and `doc/developer-guide.md`
that a gate reports was checked by **running the gate**, seventeen commits
after the last such sweep. Five had moved and one was simply wrong:

- `variant-check` 779 sources / 3144 guards → **785 / 3185**;
  `clause-citations` 9344 across 1537 files → **10 307 across 1661**;
  `format-check` 774 of 783 → **776 of 785**; `predicate-kinds` 39 predicates
  → **40**, and `doc/developer-guide.md` had it as **36**, two documents
  disagreeing about one gate's own answer.
- **`line-coverage`'s pair was not stale, it was miscast.** *784 of the 853
  directions never taken* is a **finding** ADR-0274 measured once, written in
  the present tense beside two ratchets that move with the corpus — which now
  answer 9747 of 10 608. It is now dated as a measurement, which is the repair;
  updating the numbers would have destroyed the finding.
- **And one claim that no arithmetic would have caught.** `CLAUDE.md` said
  every testable clause of the dialect spec is cited *but for the three AP
  5.5 d) names*. `run.py --coverage` says **114 of 118**, and the four are
  6.7.7.6.1, 6.11, 6.13.1 and 6.13.2 — a different count *and* a different
  identity, the last two being the clauses `stale-component` exists for and so
  held by a harness rather than by a scenario. The sentence had a specific,
  checkable, wrong referent, which is the shape ADR-0072 named for clause
  numbers met once more.

**A fourth shape, found on 2026-09-01 by trimming `doc/roadmap.md`, and it is
not a number.** The three audits above look for a claim that has drifted from
the code. This one is a claim that never met the code at all: **ADR-0266,
ADR-0267 and ADR-0268 had landed and reached no document outside their own
records.** Two of them closed roadmap rows that were still written as open --
*`take` is refused for a handle in as many words* (ADR-0267 widened it) and
the concurrency row reading **unblocked and unbuilt** (ADR-0268 built it) --
and ADR-0267 was in no README, no digest and no `CLAUDE.md` bullet. A fourth
claim, that the terminal binding an IDE needs is small and shaped and will be
built *whenever something asks for it*, had been built by ADR-0262. And
`doc/history.md`'s increment table had stopped counting seventeen increments
earlier while its preamble said *thirty so far*.

None of these is reachable by re-running a gate, which is what the audit above
does: a gate answers a question about the compiler, and these are documents
that were never told a decision was made. The distinguishing feature is that
each was found by reading a **record** and asking where else it should appear
-- the opposite direction from every other audit here, which starts from the
document.

**A gate could ask this and none does.** Every accepted ADR whose change moved
the accepted language should be named somewhere outside `doc/adr/`, and
`grep -l "ADR-0267" -- ':!doc/adr'` answers in one command. What makes it more
than a grep is deciding which records *must* appear -- a gate over all 286
would fail on every internal one -- and that is the design question rather
than the mechanism. Not built here; recorded so the next reader does not
conclude from four repairs that the class is closed.

**A fifth shape, found on 2026-09-01 by a `security-audit` pass: a gate that
prints a claim it never evaluated.** Not a stale number and not an untold
document -- a check whose *subject* is silently empty, so it passes by asking
nothing and says so in a sentence a reader takes for a measurement. Two of
them, in one afternoon, and both were green on every run since they were
written:

- **`runtime-isoc` never bounded the concurrency unit's headers.** Pass 5
  compared each `#include` against `$ISO_HEADERS` -- **a variable assigned
  nowhere in the script**, the other four passes spelling it `iso_headers` and
  holding base names *without* the `.h`. Under `set -u` the reference killed
  the subshell it stood in, so `task_extra` came back empty whatever the file
  included, and the summary went on calling `runtime/pasrt_task.c` *bounded by
  `<pthread.h>` alone* as a fact. Adding `<sys/mman.h>` to it left the gate
  **green and silent**; the only visible trace was one line of unread stderr.
  ADR-0186 makes that list the whole of what a port has to satisfy, so the
  claim was load-bearing and unchecked.
- **`sanitizers` could not link 47 of the cases it counted.** `pascalcc`
  translates every component `--dump-imports` reports *except* what the caller
  named with `--import` -- "its object is the caller's to supply" -- and this
  harness named them and supplied none, so every case with a `.components`
  sidecar failed at the **link** and was counted as a *skip*. The runtime's
  fourth translation unit was missing from the gate's own `libpasrt.a` too
  (ADR-0268 added `runtime/pasrt_task.c` after ADR-0261 wrote the list), so
  `tests/dialect/concurrency.pas` could not link either. 288 of 346 runnable
  programs were reaching the only memory-safety oracle here, and the whole of
  `lib/` and `lib/dialect/` was reaching it through **no case at all**. Both
  are repaired -- 288 clean becomes **334**, and the 187 remaining skips are
  exactly the 175 cases with no `.out` plus the 12 wanting file names on a
  command line. The argument is the mutation: under-allocating a channel's
  buffer by one element is an ASan heap-buffer-overflow the repaired gate
  **flags**, and that the gate as it stood **passed** -- 288 clean, 0 flagged,
  exit 0, with a heap overflow live in the runtime.

The shape is `format-check`'s (ADR-0282) met twice more, and the lesson is
narrower than "test the tests": **a gate that reports a count is checkable and
a gate that reports a property is not.** `sanitize.sh` prints its four
tallies, and the skip number had been 233 in plain sight for as long as the
gate existed. What no reader could see is that a skip meant *did not link*
rather than *has no `.out`*. A denominator a gate cannot fall below is the
cheap answer -- this one has a floor of 100 and 288 cleared it comfortably --
and the repair is to make the harness say **why** it skipped, since the three
reasons were one number and only two of them are honest. It now reports
`187 skipped (175 with no .out, 12 wanting file names, 0 unbuilt)`, and says
in words that a case which cannot be linked is coverage lost rather than a
case with nothing to run. **`unbuilt` is the number to read**: removing the
fourth translation unit again makes it 1 and prints the reason, where the old
tally moved from 233 to 234 and said nothing.

**A count is now stated in one place where it was stated in four.** The
language server's findings were *twenty-one, fifteen closed, six open* in this
file's sibling documents and *twenty-six, seventeen, nine* in the section that
is actually maintained. Rather than syncing four copies, three of them now
point at the one that is kept — a fact stated twice is a fact that will
disagree with itself, and this one had, in three places at the same snapshot.

**ADR-0233's rows, added on implementation** (2026-08-28). The compiler became
three §6.13 program-components, which **narrowed** the linking row below rather
than striking it and **closed** the diverse-double-compiling window for good.
It also moved eleven gates: every one that read "the compiler's source" or ran
the compiler over it was reading or measuring a third of a compiler the moment
the split landed, and every one of them now goes through
`tests/checks/components.py`. Two ways that failure was *silent* are worth
carrying forward, because neither is peculiar to this change:
`procedure-coverage` and `line-coverage` *degraded* to a **skip** when the
compiler could not translate its own source, so a break in them read as a
missing `clang` — and both were skipping on the day the split landed. **Fixed
on review**: the two now tell a skip (nothing on this machine to run with) from
a failure (the measurement is broken) and exit 1 for the second, which is what
every other gate here does. The second hazard stands, being a property of the
language: an exported routine's header appears **twice** — §6.11.1 puts it in
the module-heading and leaves the block repeating the name alone — so a regex
anchored on `^function Name(` matches an interface entry with no body and finds
nothing to read.

**ADR-0236's row, added and struck on 2026-08-29.** The language server is the
first program here that lives outside `tests/`, so it was briefly the first
thing in the tree that every corpus sweep was blind to at once. The row was
written saying the fix was a decision rather than a chore; it was a chore, and
the row now records what closing it cost and what it bought — which was nothing
for coverage and a real check for leaks. **Writing a row down is what got it
closed**, and it is the second time in two days that has happened here: the
`fpc-differential` gate shipped with a `*_REQUIRE` variable nothing set, was
declared as a row, and had a CI job the same afternoon.

**Audited again on 2026-08-28**, after version 3, over 67 rows. Six had gone
stale and the release is why five of them did — a register describing what is
*not* checked is exactly what a change that deletes five gates falsifies. Two
rows closed: case-exhaustiveness is no longer read over the source (ADR-0229,
ADR-0230 — and the row still said it was, having been rewritten around the
gate's other half while its own title stayed false), and the
mode-portability row is moot, its mechanism deleted rather than fixed. Three
carried a **count a gate answers** — 1019 sources, 2821 guards, 368 citations
across 331 scenarios — every one of them wrong, and every one of them checked
by running the gate rather than by reading the sentence, which is the only way
this shape is ever caught. One named `reserved_words.py` as the last gate
parsing the compiler's source, and that file is deleted; the shape it stood for
is not, so the row keeps it with ten live examples instead of one dead one.

**Read end to end a third time on 2026-08-28**, after ADR-0233 landed and
ADR-0234 was written — the same date as the audit above and a different tree,
which is itself the finding: two of the four stale rows below were falsified by
changes made *that day*, and a register re-read only after a milestone would
have carried them for weeks. What it found:

- **A row whose closing condition arrived.** "No third-party corpus" ended
  *there is no replacement and none is available*. `fpc-differential` is not a
  corpus and the title stands, but an external answer of some kind became
  available that morning. This is ADR-0197's third shape exactly, and the
  second time this register has been caught by it.
- **A closed row describing a sandbox that had changed underneath it.** The
  `langspec-audit` row said readers get the standards and *the BSI suite*;
  ADR-0232 removed the suite and `sandbox.sh` says so in a paragraph where the
  copy used to be. A struck-through row is still read — that is what struck
  through means here — so it goes stale like any other.
- **Two counts a gate answers.** `variant-check` says 936 sources where the row
  said 934, the split having added two; the guard count was right. And the
  mutation row's *two hundred records carry a mutation in their prose* is 103
  of 234 by the only grep that can be written for it, which is an upper bound.
  Both were checked by running the gate, which is the only way this shape is
  ever caught.
- **A row that was missing, which is the one worth the whole read.**
  `fpc-differential` shipped that morning with a `FPC_DIFFERENTIAL_REQUIRE`
  nothing set, so the only gate here answering the corpus with a second
  processor ran on one machine and no CI job. Every comparable skipping oracle
  had that covered years-equivalent ago. The row went in and was closed the
  same day by the job that installs `fpc`; it is kept struck below because
  what it records is that the gap was *shipped*.
- **One row verified rather than assumed**, and it is the one ADR-0197 was
  written about: the string-arena row says there are **eight** producers and
  that a ninth would have nothing looking for it. There are eight
  (`strTemps := strTemps + 1` in `selfhost/compiler.pas`). It is current, and
  it is the row most likely to be stale next.

**Read end to end a fourth time on 2026-09-06**, after v3.5.0 was cut. What it
found is ADR-0197's three shapes again, one of each, which is the argument for
doing this on a clock rather than after a change:

- **A row whose own closing condition had arrived and nobody had looked.** *A
  seed-built compiler's own traps name no position* ended *closes itself at the
  next reseed, when the wrappers can go*. The release reseeded — twice — and
  the seed now calls only the `_at` forms. The four wrappers in
  `runtime/pasrt.c` were dead code that had linked for eight days after they
  stopped being needed, and the person who met the condition was cutting a
  release and did not re-read this file. That is exactly why the shape is
  written down.
- **Three counts a gate answers, and one of them is the third time.**
  `variant-check` says 881 sources and 3531 guards where the row said 779 and
  2855; the specification suite is 513 citations across 417 scenarios with 133
  of 146 testable clauses cited, where the row said 360, 319 and 98 of 101 —
  and that row *already* says to run the gate rather than trust it, having gone
  stale twice before. It is now three. A row that warns about its own numbers
  does not stop them going stale; running the gate does.
- **A row that arrived twice in one day and was written both times.** The
  environment-variable row (ADR-0335) gained `llc_check.sh` (ADR-0345) and
  `seed_current.sh` (ADR-0347) as a second and third instance, and the row's
  statement widened with them: it is not about environment variables, it is
  about a harness passing a path, a target or a flag that is right where it was
  written and wrong where it runs.

Nothing else was found stale, and two rows were verified rather than assumed:
the string-arena row still says **eight** producers and there are eight, which
is the second audit running to make that check and the row ADR-0197 was written
about; and the `-O1`/`-O3` row is still a judgement nobody has revisited.

**Read end to end a fifth time on 2026-09-07**, the day after the fourth,
because six records landed in it and a register re-read only on a clock would
have carried what they falsified for a week. What it found is one row in the
shape ADR-0197 named and one it did not:

- **A row whose premise had been false for two days, and the closing record
  did not re-read it.** *A slice's foreign count is widened to `i64` and
  nothing can see that it is* argued the widening was right because every
  target zero-extends a 32-bit register write — true of x86-64 and aarch64,
  and this compiler admitted i386 on 2026-09-05 (ADR-0325), where `size_t` is
  32 bits and the widening is wrong by the ABI. ADR-0364 fixed the emitter
  and gated it without touching the row, which is the shape of the string-arena
  row again: the person meeting the condition is working on a feature. Struck
  below with the correction beside it.
- **Two rows narrowed by the same records and not by their authors.** The
  temporary-name race is `TemporaryPath`'s alone now that the server uses
  `mkdtemp` (ADR-0363); and the *external declaration against the function it
  names* row gained the one property ADR-0364 does hold — a scalar's width, as
  a catalogue — while its title stands.
- **And a comment and a document the records did not reach.** `lsp/pasls.pas`'s
  header still said the scratch file carried the process id and was left
  behind at exit, and `lsp/README.md` still gave `$TMPDIR/pasls-<pid>.pas` as
  the default and described the `.tmpdir` session as checking a file named
  for the pid — four paragraphs describing the mechanism ADR-0363 replaced
  *because it was a hazard*. ADR-0197's fourth shape: a record that reached no
  document outside itself, found by reading the record and asking where else
  it should appear.

- **And one the pass itself produced.** Rewriting that header comment two
  lines shorter moved `lsp-coverage` from 92 never run and 32 unmeasurable to
  91 and 30 — a comment, in a file where `--coverage` keys on the line. The
  comment was padded back to eleven lines so that a docs commit leaves every
  gate's output identical, which is this file's own rule; what it says about
  the gate is that its two counts are not a property of the program alone, and
  a ratchet that moves under a comment is one a reader should not read as a
  measurement to the unit.

Verified rather than assumed: the string-arena row still says **eight**
producers and there are eight, a third audit running; `runtime-coverage` still
reports `pasrt_posix.c` at 111 of 353 uncovered, the row's 68.6%, the new
`pasx_exec_*` lines being reached by `lib_process_execute`; and the `-O1`/`-O3`
row is still a judgement nobody has revisited.

**Read end to end a sixth time on 2026-09-09**, after v3.8.0 was published, and
**the register itself was clean**. Every row was current, including the four
written during the release increment; nothing had dated itself from a shipped
feature and no row named a closing condition that had since been met. What was
stale was everywhere else, which is the second audit to find that and is worth
stating as a shape of its own: **the register is re-read by whoever reads this
procedure, and a number quoted in a document is re-read by nobody.**

- **Six counts quoted from gates, none of them re-run since it was written.**
  `target32` answers 597 of 598 where README said 573 of 574; `valgrind-corpus`
  and `sanitizers` each sweep 389 programs where `CLAUDE.md` said 377 and 383;
  `thread-sanitizer` selects fifteen where it said eleven; `lib-coverage`
  measures 33 modules where two files said 32; and §7's own triage row said 51
  structural rows sharing a sentence and 340 testable rows carrying a title
  where the file has 144, 44 and 390, 204. Every one was found by running the
  gate and by nothing else, which is the rule `docs-engineering` states and the
  step it is structurally blind to.
- **An index row pointing at a filename that had been renamed.** `doc/adr/`'s
  index named `0374-a-windows-program-runs.md`; the record is
  `0374-windows-runs-and-is-deferred.md`, renamed when the decision became *and
  Windows is deferred*. Markdown renders a dead relative link exactly like a
  live one, so nothing here could see it. **It was written the same day**:
  `markdown-links` (ADR-0377) holds every relative link and every `#fragment`
  in a tracked document, the eight further dead links a sweep then found are
  repaired, and its anchor half found a ninth on its first run.
- **Two terms defined twice in one file.** `doc/glossary.md` carried a
  **Warning** and a **Trivia** entry in the dialect section and again in the
  pipeline section, and the two Warning entries already disagreed about
  whether there are four of them. A fact stated twice is a fact that will
  disagree with itself, and this one had begun to.
- **A document contradicting itself about a platform.** `doc/roadmap.md`'s
  summary line said macOS had "a release leg still disabled" while the row it
  linked to said ADR-0375 had enabled it; the same row said eight skips where
  the job's own comment enumerates nine, ADR-0369 having added one. The leg had
  by then run and shipped an archive.
- **A sentence left as a fragment by an edit.** The macOS row ended *"The leg
  that was disabled, which is three decisions rather than a run finding
  anything"* — a clause whose subject had been rewritten around it. Nothing
  here reads prose for sense, and nothing will.

Verified rather than assumed: the string-arena row still says **eight**
producers and there are eight, a fourth audit running.

**Read end to end a seventh time on 2026-09-10**, after the WebAssembly
increment and the editor's second milestone, and **the register was current
again** — the third time an audit has found every stale thing outside it. What
was stale:

- `doc/glossary.md`'s **Admitted target** entry said there were *five* and that
  *every one is POSIX*, where there are seven and two of them are not machines
  at all.
- The editor and the WebAssembly corpus had no entry in
  `doc/design-digest.md`, which is where a landed mechanism belongs.
- `tui/sessions/` was a corpus `doc/developer-guide.md` did not list.
- README's platform tiers stopped at macOS though a third tier runs on every
  push.
- `doc/roadmap.md` had no row for `tui/` at all, so open work read as absent.

One row here *had* had its own closing condition partly met —
`AFTERSCHOOL_PASCAL_*` and the harnesses that ignore what they are handed,
where ADR-0384 made exactly the judgement the row asked for, for one variable,
and gated it in both directions.

**Read end to end an eighth time on 2026-09-11**, before v3.11.0: **four stale
rows in 102, and one of them was the register's own most-warned-about shape
doing real damage.** *Nothing checks that a harness works only inside the
directory it made* ended with the words *every local parallel run now exercises
it* — a row naming its own closing condition, and wrong, because what wrote
outside its directory was not a harness. Every harness did work in a directory
it had made; the **program under test** was started with no `cwd` at all and
ran in the invoker's, so the one corpus case that names a file relatively raced
its own concurrent copy and failed on CI on three jobs across two pushes while
a local parallel run passed (ADR-0406). The row could not have been read as
covering that, and the sentence is why nobody tried.

The other three were counts a cut moved: `runtime`'s report-only units are
three since ADR-0405 and the register said two, `runtime-nonposix` bites one of
*five* units and the register said four, and the directory walk whose error
paths nothing can arrange is in a different file now. Every one of the four was
found by reading the row and none by a gate — `quoted-numbers` holds what a
*document* quotes, and a count written into a sentence in §7 is not catalogued
unless somebody catalogues it.

**Read end to end a ninth time on 2026-09-12**, after ADR-0411, and the first
audit asked for by name rather than taken on a clock: **two rows of 108 had
closed and neither had been struck, and three other documents carried one of
them as live.**

- **§6.4.3.3's region *is* asked of a constant occurrence.** `array [1..fred]`,
  `array [1..fred+1]`, `set of 1..fred` and `string(fred)` beside a field
  `fred` are all refused, with a message that names the region, and ADR-0134
  did it — saying so in the comment on `ErrorFieldNotA` and in
  `doc/implementation-defined.md` §6.1, which records the entry as the *last*
  one and closed. `CLAUDE.md` and one of `doc/design-digest.md`'s two bullets
  on the clause still said it was not asked, and the digest's own other bullet
  said it was fixed — a fact stated twice, disagreeing with itself, which is
  the shape ADR-0388 removed from a program and nothing removes from prose.
- **An `unreachable_diagnostics.txt` entry naming no message is caught**, and
  always was: `listed - uncovered` holds it whether the message was deleted or
  a golden now names it, and a probe entry is reported. What made the row read
  as open was the gate's own wording, which said *a golden now names it* about
  a message nobody can write; it now says which of the two happened.
- **A headline describing a closed defect.** The `tls` row led with
  the swallowed-diagnostics defect ADR-0366 had fixed six days earlier rather
  than with the gap it was recorded for.
- **A pair of counts neither current nor reproducible.** *204 of the 390
  testable triage rows carry the clause's title*: re-measured from
  `triage.tsv`, 44 of 144 structural rows share one sentence and 145 of 399
  testable rows carry no reason at all.

Every one of the four was found by reading a row and probing what it claimed,
and none by a gate. Chasing the last of them found a fifth thing outside the
register: three documents said **563 of 598** corpus programs run as
WebAssembly where the gate had been answering **570 of 605**, and
`quoted-numbers` has a row for each of those three sentences and had never
evaluated one — it reads the ctest log after the suite in the `test` job, and
`wasm32` needs a sysroot that job has not got, so it answers in a job of its
own and its rows come back *unchecked* every time.

The same audit, extended to the specification, found **two extensions of the
language with no clause**: `halt`'s exit status and the underscore in an
identifier, each carried in `doc/implementation-defined.md` §5 for as long as
it had existed, so a reader holding the specification did not know either was
legal. Both have clauses now (AP 6.7.5.7, AP 6.1.3), and writing the second
corrected it — the draft refused a leading `_` and `_` alone, and a probe found
the processor admits both.

### The rows struck as closed

| Blind spot | Consequence | Recorded |
| --- | --- | --- |
| ~~**A method-designator cannot name the method being declared, in one spelling of three**~~ — opened and closed 2026-09-12 (ADR-0415), one commit apart | Inside an implementation, `l^.next.Bump` as a statement and `l^.next.Deep(n)` as a call with arguments both reach the method currently being declared; `l^.next.Len` -- an expression with no arguments, which is ADR-0410's *husk* -- is refused with `no routine of that name is implemented for it`. Ordering is right in all three (a *later* method is refused by each), so what disagrees is only the self-reference. Nothing caught it: `tests/dialect/methods.pas` chains and recurses but never from inside the implementation being declared, and the corpus had no recursive container until `PasList`, which is written around it with the bare spelling `Len(l^.next)`. ADR-0412's lesson -- every one of the three shapes has to be taught the same fact -- reaching a fifth place, and **open**. **What closed it**: a routine joined its implementation's list *after* its body had been checked, so `MethodSym` could not answer for the routine being declared; the two lines are swapped. The row's own claim that two spellings worked was right and its reason was not — they resolved through the **scope**, §6.2.2.9 putting a routine's identifier in force in its own body, while `MethodSym` answered nil, so the husk was the one spelling reporting what was true. Kept struck rather than deleted because what it records is that ADR-0412's lesson had to be learned a fifth time, and because the row was **deleted rather than moved** when it was struck — this register's own convention, missed by the person who had just written the row | ADR-0410, ADR-0412, ADR-0415 |
| ~~**A jump record is 16-byte aligned on Win64 and this compiler puts it at an offset that is not**~~ — struck 2026-09-10 (ADR-0380), the platform dropped rather than the row closed | `_setjmp` there saves XMM6–15 with `movdqa`, an *aligned* store, and `%frame1 = type { ptr, [15 x i64], i32, [128 x i64] }` places the record at offset 136, which is 8 mod 16. Proven in isolation: a `jmp_buf` by hand at offset 16 works and at 136 faults at the same instruction. Aligning the frame is **not** the fix — `align 16` on every alloca and on the level-0 global leaves the field at +136 — so the record's `LlAlign` must move, and that moves frame offsets `target-layout` compares across six targets. It reaches no platform this project targets, Win64 being the only one whose `setjmp` demands it, and Windows is deferred (ADR-0374); it is here so a future port does not spend a day finding it again. **`PAS_JUMP_SIZE` is 1024 against a 256-byte `jmp_buf`**, so size is right and `target-sizes` has nothing to say — and it builds for Linux triples only | ADR-0016, ADR-0374 |
| ~~**`ExtFd`'s *meaning* is a platform's, and only a port can tell**~~ — struck 2026-09-10 (ADR-0380), the platform dropped rather than the row closed | Narrowed by ADR-0376, which now compares the two declarations of `pasx_socket_fd` and requires them to agree — that half is held. What is left is not a mismatch but a meaning: `PasNet` hands the number straight back to `pasx_socket_poll`, where it need only be a token both ends agree on, while `pastls.pas:470` hands it to OpenSSL's `SSL_set_fd`, where it must be what a foreign library thinks a socket is. On a platform whose socket is not a descriptor the second use breaks and nothing here can see it. **Every platform this project supports is POSIX and Windows is deferred (ADR-0374)**, so this is a port-time concern and it is written down for whoever takes one | ADR-0203, ADR-0264, ADR-0374, ADR-0376 |
| ~~**`lib-coverage` cannot measure a case that takes a program-parameter**~~ — closed 2026-09-10 (ADR-0378) | It ran every case as `[exe]` with `/dev/null` on standard input, where `run_test.py` hands every program two writable scratch paths and feeds it `<stem>.in`. So a case naming a program-parameter stopped at its first statement and one that reads reached nothing past its first `read` — and the lines were counted as **uncovered**, which reads as *no case in this corpus executes this* and meant *the sweep did not run the case*. Seven cases and three `.in` files: **70 statements** the corpus had been covering all along, 386 uncovered where the ratchet said 456, `paslsp.pas` alone going 71 to 20. The row named its own closing condition — *the fix is the sweep reading `run_test.py`'s argument convention* — which is ADR-0197's second shape, and it also had a **workaround case built on it**: `lib_fs_tempdir.pas` says in its own header comment that it exists because of this, which is the strongest form of a gap being mistaken for a fact. Re-ratcheting found a second defect in the same file: `instrumented` and every row's `n/M` were written and read by nothing, the header saying 3521 where the run measured 3556 — ADR-0354's decoration defect in a second gate the same week, and both totals are compared in both directions now | ADR-0350, ADR-0354, ADR-0363, ADR-0378 |
| ~~`langspec-audit`'s readers are **not isolated**~~ — closed by ADR-0228 | The harness injected `CLAUDE.md` — the reasoning for the clauses under audit included — before a reader's first turn, and it could not decline; all seven readers of the second run disclosed it, so a CONFIRMED verdict meant "no independent oracle contradicts it" and not "an uninfluenced reader agreed". Readers now run **out of process** against a sandbox built outside the repository, with the standards, a `pascalcc` and a **comment-stripped** compiler source and nothing else — the BSI suite was in it until ADR-0232, and `sandbox.sh` now carries a paragraph where the copy was, because 812 programs this compiler cannot compile would fail a reader for one reason having nothing to do with the clause under audit. Asked whether it was given project documentation, a reader in the repository names Afterschool Pascal and its path; one in the sandbox answers no. What is *not* closed: a reader is still a reader of the same family as the implementer, so a shared blind spot in reading English is untouched | ADR-0107, ADR-0228 |
| ~~**`lsp/` is outside every corpus sweep**~~ — closed the day it was written | `line-coverage`, `procedure-coverage`, `heap-balance`, `variant-check` and the `--dump-all` sweep were all globbed over `tests/`, and `lsp/pasls.pas` is not there — it lives in `lsp/` because a server has to be a binary an editor can be pointed at rather than one compiled into a temporary directory and thrown away (ADR-0236). The row said the fix was a decision between two shapes; **it was the first shape and it was four lines**. `coverage.py` gained a group, `variant_check.sh` gained a `find` root, and `build.sh` learned `AFTERSCHOOL_PASCAL_OPT` so the corpus-wide `-O0` sweep reaches a program whose whole shape is a loop (ADR-0102). `heap-balance` needed more than a root and is the one worth reading: the server has no `.out` and cannot have one, so `run_test.sh` cannot drive it and `lsp/run.sh` does — which meant that harness had to take `run_test.sh`'s care about `PASHEAP_BALANCE` **twice over**, since `pascalcc` builds the server and the server then starts `pascalc` once per document, and both are Pascal programs on this runtime whose allocations are not the server's. Without that the first measurement read 16 324 outstanding variables; with it, four sessions balance at 0 and `pasls` is a catalogue line. **What the coverage half bought is nothing, and that is the result**: 446 statements never run before and after, so the server reaches no compiler statement the corpus did not already. What is *not* closed is not peculiar to `lsp/` — nothing measures any corpus program's own statement coverage, `pascalc --coverage` notwithstanding, and `fpc-differential` and `diagnostic-coverage` do not reach it by construction rather than by omission | ADR-0236, ADR-0102, ADR-0183 |
| ~~**`fpc-differential` is run by no CI job**, so in practice it runs where someone has Free Pascal~~ — closed the same day it was opened | it skips 77 without `fpc`, which is right — `fpc` is not a documented dependency and must not become one. Every other gate here that skips is covered by a job that *refuses* to: `target-sizes` has `TARGET_SIZES_REQUIRE` set in two jobs and `unicode-conformance` has `UNICODE_CONFORMANCE_REQUIRE` in one, precisely so a skip cannot pass for a check. `FPC_DIFFERENTIAL_REQUIRE` exists and **nothing sets it**, so the second processor answers the corpus only on a machine that happens to have one — which today is the machine ADR-0234 was written on. The catalogue fails in both directions, so what is at risk is not a wrong entry but a **silent** one: a disagreement that appears or disappears between releases would be seen by whoever next runs it and by nobody else. The fix was a job that installs `fpc` and sets the variable, which is what the two rows above did for their oracles, and it exists: `a second processor answers the corpus`. The row is kept struck rather than deleted because what it records is that the gap was **shipped** — ADR-0234 landed with a `*_REQUIRE` nothing set, and it took reading this register end to end to notice. **It has happened three more times** (`target32`, `TLS_REQUIRE` since ADR-0264, and a `SANITIZE_REQUIRE` named by a comment and read by nothing), so ADR-0330 made it mechanical: `require-consistency` compares the variables the checks read against the variables the workflows set, in both directions, and its own mutation caught it matching a name in a *comment* — the same defect it exists to refuse | ADR-0234 |
| ~~Coverage is measured per **statement**, not per branch~~ — closed by ADR-0274 | `if c then a else b` on one line counted as covered when either arm ran, a decision with no else-part had nothing on its false side to count, and a short-circuit operator's right operand is an expression and had no counter at all. `--coverage` now emits a second counter on each edge of every decision the *source* writes — an if, a while, a repeat, and each `and`/`or` — keyed on line **and column**, and `line-coverage` gates a second ratchet over it. The census is the size of what was missing: **784 of the 853 directions never taken sit on lines statement coverage calls covered**, and every one of those decisions was reached and evaluated and only ever went one way. What does *not* close: a `for`'s test and every runtime check are outside the boundary on purpose, the first being generated from the bounds rather than written and the second being the compiler's branch rather than the program's; and a decision inside a schema's body is counted once however many tuples instantiate it, §6.4.7 re-emitting the body per tuple while the key is a source position — which is ADR-0104's own property, stated rather than found later | ADR-0104, ADR-0274 |
| ~~**Two gates flaked once each on 2026-09-06**~~ — the second is explained and closed 2026-09-07; the first stands | `fpc-differential` failed in a full run and passed on rerun and on a second full run, and that one is still unexplained. The second — `tests/extended/lib_strings.pas` failing with *unexpected character '}'* at 10:53 in a coverage sweep — **was not the compiler and not a short read.** It was this register's own author: the sweep was a sibling agent's, run in the working tree while `lib-coverage`'s mutation check rewrote every line of that file matching `Reverse(` or `Times(` to `{ removed }`, and line 6 of its leading comment contains `Reverse(s)`. A `}` on line 6 closes the comment there, lines 7–9 lex as identifiers, and the real closing `}` at 10:53 is the first and only error — which is exactly the one line the sweep printed, and is reproducible on demand by applying that regex and compiling. What ruled the compiler out along the way was worth having: the position was correct so nothing was truncated, 400 parallel compilations were clean, and Valgrind found zero errors translating that file and all three program-components. **The lesson is not new and was already written down**: `tests/mutation/run.py` refuses to start when a file a mutant names has uncommitted changes, precisely so a mutation never edits a tree something else is reading, and an ad-hoc mutation done by hand in the checkout bypassed that discipline while two agents swept the same tree. A mutation check belongs on a copy in scratch, or on a tree nothing else is running in | ADR-0207, ADR-0281, ADR-0353 |
| ~~Case-exhaustiveness is checked over the **source**, not by asking the compiler~~ — closed by ADR-0229 and ADR-0230 | This row closed in two halves and the second was written while the row still said the opposite. `kind-exhaustive` first grew from `typeKind` alone to every enumeration (ADR-0145), which closed the row that had stood here; what was left was the *oracle* -- it parsed `compiler.pas` and could ask the built compiler nothing. ADR-0229 moved the case-statements onto `--dump-dispatch` and ADR-0230 moved the chains, so it reads no Pascal at all and the question is put to the compiler. **What does not close with it** is that the gate still cannot judge whether an arm is *right*: `tyOptional: StaticThroughout := true` satisfies it and is wrong, and that belongs to the row about a predicate rather than to this one. Nor is a crash on a case-statement a question a program can be written to ask, the arm that is missing being the one no program reaches -- which is why the gate exists at all | ADR-0018, ADR-0124, ADR-0145, ADR-0229, ADR-0230 |
| ~~A **missing join** is not caught by any case~~ — closed by ADR-0312 | AP 6.9.3.12.1 joins every task a block spawned before releasing anything of that block's, and the emitter puts the join first in the epilogue. Removing it entirely left `tests/dialect/concurrency.pas` **green**: every task in it finishes before its block ends, so nothing observed the difference. The row said what would close it -- a task still running when its block ends *and* whose continued running is observable -- and called it a race to write deliberately; `tests/dialect/task_join.pas` is that program and it needed the new construct's client to be written before anybody wrote it. The spawn is inside a procedure, so the join is at that procedure's `end` and no statement in the program performs it; the task sleeps a second and writes to a stream it owns, which its block flushes and closes; the program then reads that file by name. **Mutation confirms it**: with the block-end join removed the new case fails and `concurrency.pas` stays green, exactly as this row predicted. Three things do **not** close with it. The oracle a channel offers is still the wrong one -- a value the task *sent* has already been synchronised, so any case written that way passes with the join deleted, and this row's replacement is one case and not a property of the corpus. The case's margin is a **one-second sleep** and not a construction that cannot race, so on a machine slow enough it could fail for the other reason. And the row below is untouched: AP 6.7.8.2's ban is still not transitive, and ThreadSanitizer over every concurrent program -- including the claim that a task record's join is claimed once when `wait` and the block's join both arrive -- is still run by hand and is still not a gate | ADR-0201, ADR-0268, ADR-0312 |
| ~~**The langspec-audit sandbox cannot run its own compiler**~~ — closed 2026-09-06 (ADR-0342), and the cause was not the sandbox | The 2026-09-06 run reproduced it exactly and named it: a `-p` reader has **nobody to approve a permission prompt**, so every Write and every Bash call is refused and the reader can only read. `--allowedTools` is the whole fix and the skill's launch line now carries it; the same run then returned four reports resting on 116, 73, 45 and 30 compiled probes, and three compiler defects came out of them. The second half of that run is worth as much: a subscription **session limit** refused four of six readers in one line of output that reads like a report (`You've hit your session limit`), so a word count is now the first thing the skill says to check. Neither is checked before readers are launched, which is the residue. The original row read as a fact about the sandbox and was a fact about the harness invoking it | ADR-0107, ADR-0228, ADR-0288, ADR-0342 |
| ~~**ThreadSanitizer is not a gate**~~ — closed 2026-09-05 (ADR-0327) | The concurrency construct's real oracle is TSan: it found the runtime's global handle list being unlinked by two threads on the *first run of the first program that spawned two tasks*, and then the string arena's cursor -- and neither is a defect any golden could hold, both orders producing the same output nearly always. It was run by hand. `sanitizers` (ADR-0261) builds the corpus under ASan and UBSan and does **not** build it under TSan, so a race introduced tomorrow has nothing watching for it. What would close it is a fourth pass in that harness over the cases that spawn, which is cheap and is not built. **Two changes have widened what it is being asked to watch and neither armed it.** ADR-0312 made the task record reference-counted and its join *claimed* under a mutex, so that `wait` and the block's own join -- whichever arrives first -- call `pthread_join` exactly once and the loser waits on a condition variable. ADR-0313 then added the select-statement, whose correctness is stated as an invariant about two mutexes: *no thread ever holds a channel's mutex and the activity mutex at the same time*, which is what makes the design deadlock-free and a wakeup impossible to lose. `tests/dialect/select_contended.pas` is the program to run TSan over -- four workers selecting on two shared channels while the program feeds both -- and its own oracle is a deterministic **total**, which is all a golden can be here: every value sent is received once and forwarded once, so the sum is the same however the schedule fell out. **A total cannot see an ordering defect**, and TSan remains the only thing that can. Eight concurrent programs were clean under it by hand on 2026-09-03, three runs each; nothing made that happen again. **`thread-sanitizer` is what does**, and it is the fourth pass this row asked for, arrived at as a *mode* of `sanitize.sh` rather than a second script: the 120 lines that translate a case's components and read its sidecars are the part that took the defects out — 47 cases were silently unlinked once — and a copy of them is a copy free to drift. ASan and TSan cannot be combined, clang refusing the pair, so it is a second invocation. **The corpus is chosen by what each source writes** and not from a list, so a concurrent program added later is swept without the gate being edited; eleven qualify today and all eleven are clean. Two things this row said are now measured rather than asserted: unlocking the store in `pas_chan_send` flags five of the eleven, which is the mutation that proves it watches; and moving `pas_select_turn++` outside the activity mutex flags **nothing**, which says the corpus contends on `select` less than `select_contended.pas`'s name suggests and is a gap of the corpus rather than of the gate. **And it is required in CI in the same commit**, the `sanitizers` job gaining a step that refuses a skip — this row's own lesson applied at the moment the gate landed rather than the third time. AP 6.7.8.2's ban is still not transitive, and that half of the row above is untouched | ADR-0261, ADR-0268, ADR-0312, ADR-0313, ADR-0327 |
| ~~**A seed-built compiler's own traps name no position**~~ -- closed 2026-09-06 by the v3.5.0 reseed | The seed called `pas_index_error(i32, i32)` and three siblings, kept as wrappers passing no position, so a trap *in* a seed-built compiler said where nothing. The row named its own closing condition -- *the next reseed, when the wrappers can go* -- which is ADR-0197's second shape and the reason it is written down here rather than left to whoever reseeds: the person meeting the condition is doing something else. The seed now calls only the `_at` forms (17 and 1 call sites), the four wrappers were dead and are deleted, and the read that found it was this register's own | ADR-0293, ADR-0197 |
| ~~A **dump's exit status** is read by nothing~~ — closed by ADR-0269 | `tests/checks/coverage.py` drove `--dump-all` over every source in the corpus and read the *lines reached*, and nothing read what the child did. So a compiler that **stopped** while dumping one — a case-statement with no matching label is a halt, ADR-0018 — wrote a short dump, was counted as having run, and said nothing. `--dump-sema` crashed on every program declaring a fallible-type for three days and 714 green cases; it surfaced only because a new branch in the same walker went unreached and `line-coverage` asked why. `sweep()` now reports every invocation the compiler did not survive and `procedure-coverage` fails on it — a **negative return code**, which is a signal, or `runtime error:` at the start of a line of *standard error*, which separates a trap from the exit 1 a third of this corpus is written to produce. Matching that text anywhere would match a dump of the compiler's own source, whose emitter carries the literal on standard output; `variant_check.sh` met that on its first run. Mutating `Tokenize` to store 3 into a `1..2` makes it name 1426 of 1435 invocations where the whole suite was green before. **This row named its own closing condition and then sat for five records**, which is ADR-0197's second shape exactly. What does not close: the *content* of a dump. A walker that writes the wrong thing without stopping is caught by `tests/dumps/`'s goldens for the shapes those cases have and by nothing else | ADR-0103, ADR-0104, ADR-0176, ADR-0269 |
| ~~A slice's foreign count is widened to `i64` and **nothing can see that it is**~~ — closed 2026-09-07 (ADR-0364), and the row was **wrong in its premise**: on i386 `size_t` is `i32`, so the widening was not *right for a reason no program can exhibit* but wrong by the ABI and working by cdecl's grace, and it had been since ADR-0325 admitted the target two days earlier while this row went on saying LP64 was the only architecture. The emitter asks `PtrSize` at both sites now, and `foreign-width` reads the declaration back from a probe per target — `ptr, i64` on LP64, `ptr, i32` on i386 — so the mutation this row said survives is killed. What the row said about a *behavioural* oracle stands and is the record's whole argument: the catalogue is the test because no case can be. | As it stood: ADR-0129 crosses a buffer as `(ptr, i64)` because every length this target's data path takes is a `size_t`. Dropping the `sext` and passing the count as an `i32` is a mutation that survives: x86-64 and aarch64 both zero the upper half of a register written 32 bits wide, and a slice's length is checked non-negative and cannot reach 2^31 without an array of two billion components. So the widening is right for a reason no program here can exhibit. Not worth a gate -- what would have to change is the architecture -- but it must not be read as covered, because the two tests that name the feature pass without it | ADR-0129, ADR-0128, ADR-0364 |
| ~~`target32` runs where a 32-bit libc happens to be, and **no CI job requires it**~~ — closed the same day it was opened | ADR-0325 admits `i386-pc-linux-gnu` and `tests/checks/target32.sh` builds a runtime for it and runs the whole corpus, catching what `target-layout` cannot — the two defects the port found were in neither a layout rule nor a frame, and that gate passed with `select` segfaulting. It skips 77 without a 32-bit libc, which is a separate package on most distributions, and `TARGET32_REQUIRE` existed with **nothing setting it** — precisely the shape the `fpc-differential` row above records as having been *shipped*. The `a pointer is four bytes` job installs the multiarch packages and sets the variable. **A job of its own rather than a step of `test`**, for `second-backend`'s reason: a 32-bit libc is not a documented dependency and adding it to the container every other job shares would make the documented list a lie. It carries a C probe before the build, so a package name that is wrong on some future image reddens with an obvious cause rather than as a Pascal failure. The row is kept struck rather than deleted because what it records is that the gap was **shipped**: the gate landed the same day with a `*_REQUIRE` nobody set, which is the second time that has happened here | ADR-0325 |
| ~~The aarch64 job runs the **suite**, not the other oracles~~ — narrowed 2026-09-05 (ADR-0331) | ADR-0159's CI job builds and runs the whole corpus natively on arm64, which is what turns the port from links into runs. `llc-second-backend` skipped there, so a miscompilation of the compiler that only an aarch64 backend produces had nothing looking for it — the corpus catches a compiler that is wrong and cannot catch one that is wrong *and* reproduces itself, both stages of `irtest.sh` coming from one binary and every golden having been written by it. **`second-backend-aarch64` is that oracle**, a job of its own so that `llvm` stays out of the container the documented build is checked in. It was recorded as a resource problem and was not one: the objection was against the *test* job's install line and never against a second job, and the arm64 runner was already in use. What stays deliberate is the SMT proofs, which are about the lowering *model* — the same Python file on either machine — and are required by the two x86-64 jobs. And since ADR-0296 a release ships an aarch64 archive built and suite-tested by that job, so what this row now records is the one oracle that still does not follow | ADR-0159, ADR-0296, ADR-0331 |
| ~~A module exporting an **undiscriminated schema** with a tagged variant is called portable~~ — moot since ADR-0232 | ADR-0137 locks a module whose interface reaches a record with a tagged variant-part, and ADR-0142 fixed the parameter walk that missed one route. A route still open: a module exporting `Box(n: integer) = record pad: array [1..n] of integer; case k: Sel of …` by *name*, undiscriminated, emits the dialect aliases and links into an Afterschool Pascal program, which AP §6.13.1 forbids. **No misbehaving program was built from it** — every way of giving the module something to write re-discriminates the schema and is caught, so it looks reachable only in combination with ADR-0142's defect, which is fixed. It was left alone because the fix belonged with a probe demonstrating the harm, and installing one on a forbidden-but-harmless link would have spent the meaning of the other seven combinations. **ADR-0232 dissolved it rather than fixing it**: `ComputeModePortable`, the alias and the mode in the linkage name are all deleted, every translation writes one tag, and there is no second language for a module to be wrongly called portable *to*. The rule it was an exception to survives as AP 6.13.1's NOTE 3, which is why this row is struck rather than removed | ADR-0137, ADR-0142, ADR-0232 |
| ~~**AddressSanitizer does not see compiled Pascal at all**~~ — closed twice on 2026-09-07: the *class* by ADR-0353, and the *instrument* by ADR-0358, which put `sanitize_address` and `sanitize_thread` on every emitted function, measured the corpus clean under both with compiled Pascal instrumented (377 under ASan at 81 s, 11 under TSan at 8 s), and made `sanitize.sh` refuse to sweep until a probe the sanitizer must report is reported. Kept for the record of how long it stood | The emitted IR carries no `sanitize_address` attribute, and clang's pass instruments only functions that do — so `AFTERSCHOOL_PASCAL_CFLAGS=-fsanitize=address` reaches the compilation of the `.ll` and changes nothing about the program's own loads and stores. A plain `new(p); q := p; dispose(p); q^ := 5` runs clean and prints 5 under a fully ASan-linked binary. `sanitizers` is honestly described — it asks whether the **runtime's own C** survives the suite, and it does that — but every argument of the form *ASan reports nothing* made about a **program's** behaviour is empty, and the row above makes one. The same holds of `thread-sanitizer` and of every TSan run this project has done by hand. **The fix is one attribute and was measured**: with `sanitize_address` on the emitted functions, that program reports the use-after-free with a stack trace. It is not taken, being a change to what every compilation emits and one that would redden the gate over whatever 383 corpus programs turn out to contain — which is a decision, and it has still never been put. **What changed is that it no longer has to be**: `valgrind-corpus` instruments nothing, reads the binary, reports that probe as an invalid write and an invalid read, and finds the corpus clean at 377 of 377 (ADR-0353). So the *class* is covered and the *speed* is not — ASan is orders of magnitude faster and could run where 170 seconds cannot. Every sentence above about what the four sanitizers watched was exactly true of them until ADR-0358. **Put, and taken**: the gate over 377 programs did not redden, so the cost the sentence above priced was nothing, and the speed is covered too | ADR-0261, ADR-0327, ADR-0342, ADR-0353, ADR-0358 |
| ~~A release of an owned pointer reached through a **further activation** is not detected under a borrow~~ — closed by ADR-0319, and the reason is worth more than the row was | AP 6.4.14.7 requires an owned pointer not to be released while something it owns is bound elsewhere, and this processor detects the two forms one activation can be asked about: the actual-parameters of one call, and a with-statement's own binding. What it cannot see is `Bump(g^)` → `Clear` → `ClearIt(g)` → `dispose` — the callee reaching the owner as a non-local, or being handed it by something other than the activation-point that made the borrow. **No local rule can**, which is why the cheap refusal was shipped as a narrowing and said so: closing it needs either a per-routine summary of the non-local owned pointers it may release, closed over the call graph and carrying across a program-component boundary the module-heading has no room for (§6.13.2), or a borrow flag beside the variable and a trap at the three release points — the second is sound, complete and survives separate compilation, and is a lowering rather than a rule. Every oracle here was green over the defect this row is the residue of: `heap-balance` counts `new=1 dispose=1` and is right, ASan reports nothing, and the corpus case for the construct exercised every borrow shape but this one. Annex C.12 was the clause's own entry and is withdrawn. **The row was an artefact of where the question was asked.** Both mechanisms it named — a per-routine summary closed over the call graph, or a dynamic borrow flag — answer *may this release happen*, and both are expensive for the reason it gives. AP 6.4.14.9 asks instead *may this borrow be formed*, which is a question about **scope**: a borrow is refused where the activated block can name the owner, and a block can name a variable of the outermost block or one declared in a block containing it. That is available where the program is translated and across a component boundary in both directions, and it needs no summary, no flag and no word of storage. What it costs is that an owned structure held in a variable of the outermost block cannot be lent at all — measured over the corpus before it was written: twelve such borrows, every one in a test written for the construct, none in `lib/` or `examples/` (ADR-0319). **The lesson is the one the row did not know it was carrying**: a gap can be an artefact of the question, and two records costed mechanisms for the wrong one before anybody re-read the requirement | ADR-0317, ADR-0201, ADR-0181, ADR-0318, ADR-0319 |
| ~~A generic's diagnostic **names the generic and not the call that asked for it**~~ | **Closed** (ADR-0261). One more diagnostic is reported at the activation's own position -- `this activation is what asked for that instantiation of 'add'` -- in the ordinary `file:line:col: error:` format, so every reader of a diagnostic already parses it. One per *tuple* and not per activation, which is AP 6.7.3.10.2 working: a second activation naming the same types finds the instantiation in the cache and has nothing new to report. A generic activating a generic produces one line per level, innermost first, which is the backtrace this row said the machinery for did not exist -- and it did not need to: the recursion already knows which activation it is inside. The row became a demand rather than a grumble when ADR-0254 landed, an inferred activation naming no type at all | ADR-0211, ADR-0254, ADR-0261 |
| ~~A **field selection** is answered by no dump, where a discriminant is~~ — closed by ADR-0247 | ADR-0246's `--dump-uses` reported every applied occurrence that resolves to a *symbol*, and a record field is a `fieldPtr`: `r.x` produced no line, while `v.cap` — a schema's discriminant, identical in the source — did. The asymmetry was visible in `tests/dumps/uses.dump` and explained nowhere in it. It cost **one integer**: §6.4.3.3 makes a record a region and gives every field-identifier a defining-point in it, and `fieldRec` was already recording `line` and `col` for a diagnostic (ADR-0045) — what was missing is which *file*, a record declared in an imported module having fields whose positions are that module's. §6.8.3.10's bare form answers the field too, not the with-statement that gave it a nearer defining-point. The row is struck rather than removed because the two rows beside it look alike and are not: each of those needs a fact nothing records, where this one needed a fact already recorded | ADR-0247, ADR-0246 |
| ~~An **interface** has a name and no position~~ — closed by ADR-0248 | `ifaceRec` held a name, an owner and its constituents, and never where the `export` clause was written, so §6.11.3's `M.x` hovered on `M` and jumped nowhere. An interface is found by *spelling* — `FindInterface` walks a list comparing the pool — so no question the compiler asks about one had ever needed a position. Three integers on that record, set at the one site §6.11.1 puts a defining-point. **The occurrence that mattered turned out not to be the qualifier**: `import Middle;` is where a module says where it gets things from and is the line a reader most wants to follow, and it was reported by nothing at all | ADR-0248, ADR-0246 |
| ~~A **defining** occurrence answers `null`, where an editor answers the declaration itself~~ — closed by ADR-0250 | ADR-0246's dump reported *applied* occurrences only, so a position on a `var` line or a procedure heading had no line over it. Every name a block declares is on the scope chain at that block's depth, so one walk after `CheckDeclarations` reports them all — after, because at `Declare` a variable has no type yet and the hover this is for would have shown `?`. **The half that is not a no-op** is §6.6.1's `forward` and §6.11.1's heading: the completing block is the same routine, so the name at the implementation resolves to the interface that promised it. The *interface's* own export-part followed in ADR-0251, along with a module's declarations — §6.11.1 puts them in a heading and §6.2.2.12 makes them the block's too, so the walk takes a boundary and each name is reported once | ADR-0251, ADR-0250, ADR-0246 |
| ~~A name inside a **schema's body** resolves in no file the dump can name~~ — closed by ADR-0249 | §6.4.7 keeps a schema's *syntax* and re-resolves the body once per distinct tuple, **where the type is written** — so `curFile` names the writer's file while the line and column being reported are the schema's, and for anything out of `lib/` those are two different files. ADR-0246 excluded productions for that and paid with `cap` in `array [1..cap]`, resolved nowhere else and so reported nowhere. What closed it is a fact that record created for another purpose: a schema is a symbol and a symbol carries `declFile`, so a production reports exactly when the schema is the document's own. The **negative** half is asserted rather than assumed — `tests/dumps/uses_module.pas` produces a schema declared in its component on every run, and the golden shows no line from that body, because a rule that silently reports nothing and one that correctly reports nothing look identical from outside | ADR-0249, ADR-0246 |
| ~~**Nothing fails when this tree's own source acquires an unprotected read-only `var` parameter**~~ -- closed by ADR-0286, and **the reason this row gave for declining a gate was wrong** | The gap was real: a `.warn` sidecar makes a *test case* fail, `selfhost/`, `lib/` and `lsp/` have no sidecars, and every harness that compiles them reads the exit status rather than what the compiler said -- so the build printed the warning and succeeded. What was wrong is the second sentence, *it is a fixed point rather than a count, so a gate would have to iterate to convergence*: iterating is what **reaching** zero needed, and *holding* zero needs one sweep. `warning-free` makes the broader claim instead of ADR-0283's narrow one, and it is cheaper -- the compiler is quiet on success, so **every implementation source must compile with nothing on either stream**, which covers all four warnings and every message added after them without matching a wording. Removing one `protected` leaves 798 of 798 green. Its second claim, that every source named as deliberately broken still is, found `selfhost/badsema/components/exporter.pas` on the first run | ADR-0283, ADR-0286 |
| ~~**A schema whose binding failed leaves `^integer`, and every generic body instantiated against it reports a fault located in the library**~~ -- closed by ADR-0356 the same day: the type carries the fact that it was refused, `InstantiateGeneric` checks no body against it, and `CheckCall` no longer reports `unknown function` under a refusal it has just read; five goldens lost fifteen cascade lines and `lib_container_bad_key.err` is the one line it was always about. The client's own direct uses of the placeholder still report, by decision | `BoundSchema` answers nil when a type-valued discriminant fails its bound, and the pointer-domain path turns nil into `intType` -- the placeholder every error path in Sema leaves, and the right one for a *value*. For a schema it is wrong in a way no node can say: `nErrType` (ADR-0306) lets an expression node keep the assignment check quiet, but a *type* carries no such flag, so `MapInit` instantiated against `^integer` reports `tag values are only for a pointer to a record with a variant part` and six `cannot select a field of a value of type integer`, all located in `pascontainer.pas`, after the one line that is the diagnostic; a client that also puts and gets reads a hundred. `tests/dialect/lib_container_bad_key.pas` pins the first line as the claim and the cascade as a record, kept to one call so the golden is eight lines. Closing it is a Sema change to what a failed binding produces -- a placeholder a type can be asked about -- and the case that names the fix is already there | ADR-0355, ADR-0356 |
| ~~**`--target=` admits no Darwin triple**~~ — closed 2026-09-09 by ADR-0372 | A program still built on macOS, clang overriding the module's header as it does for the aarch64 job — but nothing there could *believe* the header, so `llc-second-backend` and any `--dump-layout` claim were about a machine the module did not name. It outlasted three targets admitted for platforms this project does not run. `arm64-apple-macosx` and `x86_64-apple-macosx` are now the fifth and sixth, their datalayouts clang's own and each byte-identical to the Linux target of the same word size but for `m:o` against `m:e` — Mach-O mangling, not a size, so `target-layout`'s first claim holds by construction. **It also closed a macOS skip**: `setjmp-arity` had nothing to compare there, every admitted target being a Linux or a Windows triple with no Apple sysroot, and the host target is now comparable — so the arity of `_setjmp` is checked against Darwin's own header on the platform itself, which was the one fact about the target a Linux machine could not settle. What that gate needed first was a premise fix: it asked what ISO C's `setjmp` expands to, and on Darwin `setjmp` is a function with `_setjmp` beside it rather than a macro naming it | ADR-0156, ADR-0325, ADR-0371, ADR-0372 |
| ~~**Every target the tree compiles the runtime for is `*-linux-gnu`**~~ — closed 2026-09-09 by ADR-0369 | `target-sizes` builds `runtime/*.c` for nine triples and all nine are Linux, so the whole cross-platform apparatus here asked about word size and alignment and never about whether the headers are there at all; a POSIX call added to `runtime/pasrt.c` would have passed every gate in this repository. The row was written the day the Windows roadmap row was measured by hand against mingw-w64, and it said the measurement was itself a **floor** — a missing header is a fatal error, so compiling `pasrt_posix.c` reports `netdb.h` and stops, and *"the rest of its 1 177 lines was never reached"*. `runtime-nonposix` repeats the measurement on every push and closes the floor with it: each `#include <...>` is probed on its own, one one-line translation unit per header, so **seven** come back where the compile could only ever report one. What that bought is the finding, and it was not what the hand measurement implied — `pasrt_posix.c` names seventeen headers and **ten are present**, so what a non-POSIX target has not got is sockets, the terminal and `posix_spawn`, and not the directory walk, the file information or the file model; `<pthread.h>` is there too, so AP 6.4.16's channels are not what blocks a port. `pasrt_unicode.c` compiles clean, which is the whole of AP 6.4.15. Both claims fail in both directions, so closing a blocker is a commit that edits the catalogue. What does **not** close: the status is one bit per unit, so a unit blocked for a new reason while still blocked for an old one is invisible, and nothing links or runs a Windows binary — `-fsyntax-only` is the whole claim | ADR-0155, ADR-0161, ADR-0369 |
| ~~**`runtime-coverage`'s two totals are written and never compared**~~ — opened and closed 2026-09-09 | `uncovered` and `instrumented` at the head of `runtime_coverage.txt` were read only to check that *a* total was there, so they read as the file's headline claim and drifted: they said 431 of 2778 while the run measured 504 of 3116, and had done since before the change that noticed. They could not simply be gated, because they included `pasrt_posix.c` and `pasrt_task.c`, whose coverage is a property of how loaded the machine is — which is why ADR-0354 reports those two rather than gating them. The answer was to make the totals be *about the gated units*: over `pasrt.c` and `pasrt_unicode.c` the sum is as deterministic as its parts, so it is compared in both directions like they are, and it catches the one thing a per-unit row cannot — a line moving **between** two gated units while both counts stay put. 295 uncovered of 2192; the whole-runtime figure is still printed by the run | ADR-0351, ADR-0354 |

| ~~§6.4.3.3's region is not asked of a **constant** occurrence~~ — struck 2026-09-12, closed by ADR-0134 and never noticed | The row said `array [1..fred]` beside a field `fred` reads the constant, constant occurrences reaching the expression checker rather than type-denoter resolution. ADR-0112 had asked at every occurrence of a *type-name* and ADR-0134 added the constant one, saying so in the comment on `ErrorFieldNotA` — *three are asking for a type-name and the fourth for a constant* — and in `doc/implementation-defined.md` §6.1, which records the entry as the last one and closed. Four probes refuse it today: `array [1..fred]`, `array [1..fred+1]`, `set of 1..fred` and `string(fred)`, each with *'fred' is a field of this record type, so it does not name a constant here*. **What the row cost while it stood was three documents disagreeing**: `CLAUDE.md` and one of `doc/design-digest.md`'s two bullets on the clause repeated it as live, the digest's other bullet said it was fixed, and the register a reader is sent to said it was not | ADR-0098, ADR-0112, ADR-0134 |
| ~~An `unreachable_diagnostics.txt` entry that names **nothing** is ignored~~ — struck 2026-09-12; it had never been true, and the gate's own wording is why it read that way | The row said an entry matching no message is in neither set the gate computes, and *one line to fix and not built*. It is in one: `revived = listed - uncovered`, and a message that no longer exists is in `listed` and not in `uncovered`, so it is reported. A probe entry — `= 'this diagnostic does not exist anywhere` — fails the gate. What hid it is that the report said *listed as unreachable, but a golden now names it*, which is false of a message nobody can write, so a reader checking the row against the gate's output would have believed the row. The gate distinguishes the two now. **A row asserting a gap should be probed when it is written**, which is the same rule the SOP applies to a claim about the compiler (§4b) and had never been applied to a claim about a gate | ADR-0013, ADR-0273 |

### Closed before the register had rows

Kept, when it stood in `doc/sop.md`, because a register that only grows is a
register nobody trusts:

- *A `forward`-declared function could not name its own result.* §6.7.2 puts
  the result identifier's defining-point in "the block of the function-block,
  **if any**, associated with the identifier of the function-heading" — the same
  words the next paragraph uses of the formal-parameter-list, which has always
  reached a forward body. The asymmetry was literal: parameters bound from the
  *symbol*, the result variable from the *declaration node*, and a forward
  body's node carries no specification. §6.11.1 makes every exported function a
  `forward`, so this reached every module in `lib/`;
  `tests/extended/forward_resultvar.pas` is the case. It was recorded here as
  the first question for the next `langspec-audit` and did not need one.
- *The model-drift gate could not survive a force-push.* Its base resolution
  lived in the workflow's shell and asked `git rev-parse --verify`, which exits
  0 for a full 40-hex string without ever looking the object up — so the
  discarded SHA a force-push reports was waved through and the job died in
  `git diff` a line later (run 32131932455). The rule now lives in
  `model_drift.resolve_base`, one copy rather than one per caller, and
  `model-drift-base` is a `ctest` case over a repository built for the purpose.
  What is left of that gap is the row above.
- *And a second time, in the same file.* `seed-is-current` runs only at a
  release tag, so the fourteen lines of shell that were its whole check had
  nowhere to be exercised first — and they were written in bash, while a
  `run:` block in a container is `sh -e {0}`. The job died on a syntax error
  at the tag, having translated nothing (run 33178547669). The answer is
  ADR-0233's second commit and the same one as before: the check is
  `tests/checks/seed_current.sh`, run by hand at a release and by the job at
  the tag, so the text CI runs is the text a release ran. What is left is that
  a `run:` block still has no local exercise, and the way to keep one honest
  is to keep it to a line.
- *`-O0` was two cases wide.* The `unoptimised` CI job now runs the whole
  corpus at `-O0`, and `AFTERSCHOOL_PASCAL_OPT=-O0 ctest` does it locally. What
  is left of that gap is the first two rows above.
- *Four diagnostics counted but unenforced.* `tests/checks/unreachable_diagnostics.txt`
  is now a catalogue with an argument per entry, and the `diagnostic-coverage`
  case fails in both directions (§5).
- *Clause coverage had an untriaged denominator.* Every heading is classified
  testable, structural or not-implemented (`tests/spec/clauses/triage.tsv`), so
  the figure is counted against the **testable** clauses and not against the
  headings, and `spec-clause-traceability` gates it in both directions
  (ADR-0106). It was 14 of 207 testable rather than 14 of 292 headings when
  this was written and the file holds 467 rows now; no document pins the pair,
  because both move. What is left of that gap is the row above.
- *"§5 is an argument, not a number."* There is a number now —
  `procedure-coverage`, 554 of 556 when it was measured and 629 of 631 today —
  and the two rows above are what is left of
  that gap rather than the gap itself. Measuring it found the dumps: four
  documented flags whose thirty-one walker procedures were entered by no case
  at all, so nothing checked they did not crash (ADR-0103).

**A sixth shape, found on 2026-09-02 by ADR-0291: a constant the seed decides
rather than the source.** ADR-0126 recorded this for a fixed *buffer* — the
array that has to hold this source is the seed's, so raising the constant here
does not raise the one that matters — and it is not only true of buffers. It is
true of a constant that shapes a type the compiler **synthesises** and then
**uses on itself**. `BindingType` is the whole of that class today and cost an
out-of-cycle reseed: the compiler declares `b: BindingType` to read its own
arguments (ADR-0081), and that variable's layout was decided by whatever
compiled `compiler.pas` — the seed. `dateLen` and `timeLen` are *not* in it,
though they look alike: the compiler emits them into the program it compiles
and declares no `TimeStamp` of its own, so the value it uses is the one its own
source gave it.

Nothing checks it, and the failure is silent in the worst direction: the source
says 4096, every reader believes it, the suite is green, and the shipped
compiler behaves as though it still said 255 — while every program that
compiler *builds* gets the new number, which is what makes it look fixed. An
ordinary array bound written in the source does not have this property at all.
The two look identical in the source and differ in who evaluates them, so the
test to apply by hand, until something can apply it, is: **does this constant
shape a type this compiler synthesises and also declares a variable of?**

## The concurrency clauses, audited

On 2026-09-08 `langspec-audit` was run over AP 6.4.16, 6.7.8, 6.9.3.11 and
6.9.3.12 — the newest surface here, and the one whose records most often say a
limitation is *recorded as a shape rather than an omission*. Four readers were
launched into the sandbox ADR-0228 builds, each given the behaviour and not
the reasoning, and told to hunt for a legal program wrongly refused. The
disclosure question was asked of a throwaway reader in the sandbox and of one
in the repository: the sandbox reader saw nothing and the repository reader
listed the git log, so ADR-0107's isolation still holds.

Seven defects, in a surface every gate here called green throughout.

**The first is the one a working programmer hits immediately.** AP 6.7.8.2
admits a variable declared "in that task-declaration **or in a block within
it**", and the check compared a variable's owner with the task. So a procedure
declared inside a task was refused its own parameter and its own local, and a
task with a helper — which is to say a task of any size, and recursion in one
— could not be written. Three of the four readers reached it independently and
one reached it while auditing a different clause, which is the shape of
evidence a single reader cannot produce.

Two more were the same rule read from the other side. A task declared inside a
task **cleared** the rule rather than restoring it, so every statement of the
outer body after the inner declaration could name a global — the exact data
race NOTE 1 says the clause exists to refuse. And `writeln(output, x)` was
refused inside a task while `writeln(x)`, which writes the same variable, was
not: a rule about a spelling rather than about storage.

`forward` was accepted where the clause admits no directive at all. A
task-declaration was a syntax error in a module-block, so a library module
could not own its workers, and the diagnostic named nothing the programmer had
done.

**The sixth is where two clauses of this document contradicted each other.**
AP 6.9.3.12.1 requires every activation to be complete "before any variable of
that block is released" and its NOTE 2 names the block's deferred statements;
AP 6.9.3.11.2 a) executes an armed statement when its statement-sequence
completes, which for the block's own statement-part is *before* the epilogue
where the join stood. So `defer c := nil` beside a `spawn` closed a channel
the task was still sending on and the program died. The join now also happens
at that sequence's completion. A defer in a *nested* sequence is deliberately
not covered, and AP 6.9.3.11.2 NOTE 4 says so: it runs inside the block, and a
release written there is the release the program wrote where it wrote it.

**The seventh made the compiler emit a module LLVM refused.** Sema admits an
integer where a channel's component or a task's formal is real, and CodeGen
stored the value at the destination's type — so `send(c, 1)` on a channel of
real was accepted by the front end and refused by the assembler, with a
message about a file nobody wrote. 6.4.6 c)'s conversion had never been
emitted in either position, and no corpus program had ever written one.

Six cases and ten scenarios landed with the fixes; each case passes and fails
under the seed compiler, and the three riskiest fixes were mutated one at a
time with a named case killing each. Four readings came back genuinely
unsettled and took no scenario, a scenario asserting one of two defensible
readings being a coin-flip laundered into a citation. ADR-0365 has them.

## The first macOS run

`doc/roadmap.md` had called macOS the cheapest unknown here for as long as it
had a platform row, and the row said nobody had tried it. On 2026-09-08 an
advisory CI job tried it. **902 of 911 passed on the first attempt**, the
compiler built itself there, and five runs later the whole suite was green.

**Not one of the nine failures was in the compiler.** Every one was this tree
assuming Linux somewhere no oracle here could ask about, because every oracle
here had only ever run on Linux. That is the finding, and it is worth more
than the port.

Four were bash or GNU-utility specific. Three harnesses read a list with
`mapfile`, which is bash 4 — macOS ships bash 3.2, where it is not a command
at all and the array stays empty, so one gate reported a corpus of four
invocations rather than a missing builtin. `sanitize.sh` built its suppression
list with `declare -A`, and without associative arrays every later subscript
is evaluated as *arithmetic*: a name that is not a number is 0, so the list
would have applied to every case and the gate would have gone on passing. A
`case` inside `$( )` is mis-parsed by bash 3.2, which scans a command
substitution by counting parentheses, so the `)` closing a case pattern ends
the substitution early — three of those, and the first two hid the third. And
the stale-object diagnosis in the driver used `\|`, a GNU extension, so the
pattern added for ld64's spelling could not run on the platform it was for.

**Two were already in Python, which is why the lesson is not "use Python".**
`coverage.py` symbolised through `nm --defined-only` and a non-PIE link, and
arm64 macOS has neither; the shim now reports every address less its own
reference symbol, so a load slide cancels on both sides. `fuzz.py` set three
resource limits in one `preexec_fn`, and macOS defines the address-space limit
and refuses to set it — an exception there killed the sweep before it compiled
anything.

Three were in neither: a Linux-only path in three sources, which made two
handle-factory scenarios report an empty handle — a correct answer to a
question they did not mean to ask; an `errno` read after asking `strerror`
about a number it does not know, which POSIX lets set `errno` and macOS does;
and a socket written to exactly twice, two being Linux's answer read as though
it were every kernel's.

One failure was not a portability defect at all but a header convention:
`mkdtemp` and `O_NOFOLLOW` are both POSIX.1-2008, and Darwin still gates them
as the BSD extensions they were before 2008, so asking for exactly the
standard they belong to is what hid them.

**What it cost to learn was five CI round trips, one per hidden failure**, and
that is what `doc/roadmap.md`'s harness-language section points at: a lint over
every tracked script would have found the four bash ones on the first push
with no Mac at all. It is not built.

## The roadmap as it stood on 2026-09-07

`doc/roadmap.md` was compacted on 2026-09-07 to what is open and the rules
for adding to it — from 1447 lines to a few hundred — and this is the page as
it stood the moment before, verbatim, headings demoted one level. Everything
in it that was settled is here and nowhere else now: the object model's five
records read one by one, the concurrency residue with its three shapes, the
Known limitations chapter's history, the utilities table, the twenty-five
target measurement, the borrowings table row by row, and the open question
about external authority in full. The open rows the roadmap still carries are
each a sentence there and a paragraph here.

### Where development stands — 2026-09-07

**Released: v3.6.0**, the first release whose headline is a **library**
change that breaks existing programs: `PasContainer`'s map keys itself with a
trait, so every map call loses two arguments (ADR-0355). `CHANGELOG.md`'s
`Unreleased` holds the day after it — a TOML library and the project reader
rewritten over it, and a command injection in the language server found,
closed, audited and audited again (ADR-0359 – ADR-0364) — none of it a change
to the language. The compiler builds itself, stage 2 equals stage 3 in every
program-component, and the suite is 905 cases green at `-O2` and at `-O0`.

| | |
| --- | --- |
| **Open and ready to do** | the platforms, and only the platforms — **and 32-bit is no longer among them** (ADR-0325, ADR-0346). **macOS has never been tried** and the runtime's five non-ISO names are all there, which makes it the cheapest unknown on this page; **Windows** needs two hand-written `FILE*`-over-memory functions, `_access` for `access`, and an answer for MSVC's missing `_Complex`; **s390x** aligns `tySet` where nothing else does, 13 offsets. Everything else below is a decision, a measurement, or a resource |
| **Open and awaiting a decision** | the object model, and only it — ADR-0315 is `Proposed`, its increment B is built, and A and C are judged separately. **B now has a client that is not a test** (ADR-0355), which is the evidence the proposal asked for and the one thing it had been short of |
| **Open and awaiting a program** | [What a daily program still cannot reach for](#what-a-daily-program-still-cannot-reach-for), whose inventory is **empty** and whose lesson is what it keeps in its place. A row here is evidence from somebody writing a program, not an item from a list |
| **Open and unavailable** | the two rows under [Deferred](#deferred-insufficient-resources): no second front end, and no third-party corpus |
| **In progress** | nothing is half-built. The parts below hold no partially landed feature — a feature lands with its clause, its record and its case, or it does not land |

**What moved most recently is the boundary** — set out in
[`doc/history.md`](history.md#after-v360-a-configuration-file-and-the-boundary-audited),
because it is settled and this page is for what is not. A path an editor
handed `lsp/pasls.pas` could run a command (ADR-0362); the audit over the fix
returned six findings, four older than the fix (ADR-0363); and one CI container
with a dirty register showed that a foreign scalar bound at the wrong width has
**no behavioural oracle on any one host**, so the claim is now a catalogue
(ADR-0364). Nothing in it was found by an oracle failing.

**Before that, the oracles** — in
[`doc/history.md`](history.md#the-oracles-that-were-not-looking).
**In short**: a coverage review asked what is measured and the answer was
46 718 lines of 67 931, so `lib/`, `runtime/*.c` and `lsp/pasls.pas` gained
gates of their own; the dumps a tool asks for turned out to have no corpus, and
`--dump-symbols` to crash on any source containing a trait; Valgrind went in
and reported **377 programs, 0 flagged**, which is a statement this project had
not been able to make before; and then the attribute ADR-0342 measured and
declined was taken, so **the sanitizers see compiled Pascal for the first
time**. Each of those had been true for as long as the thing it watches has
existed, and every one of them was found by asking what an oracle covers rather
than by an oracle failing.

**And before that**, the memory model was struck as closed on 2026-09-04 and
corrected three times the day after. Three of its four rows are settled and
[the chapter](history.md#the-memory-model-read-against-the-goal) has the
working; what stands is [below](#memory-model-and-memory-safety). The lesson
that outlived it is about its own cost cells — three were wrong within two days,
each in the same shape, a count taken by machine with the reason beside it
written by hand. **A cost cell is a report and not an estimate.**

### How to read this

| Part | What it holds |
| --- | --- |
| [Where development stands](#where-development-stands--2026-09-07) | the one-screen answer, dated: what is released, what is open and awaiting a decision, what is awaiting a program, and what is unavailable |
| [The language](#the-language) | what the compiler accepts, and what it does not: the concurrency residue, the memory model measured against the goal it is named in, the object model whose middle increment is built and whose other two nobody has committed to, and the limitations a program meets |
| [The standard library](#the-standard-library) | the thirty-three modules — and **nothing open**, which is a finding and not an omission |
| [First-party utilities](#first-party-utilities) | everything outside the compiler: obtaining it, learning it, the editor's questions, packaging, and the platforms it runs on |
| [Deferred](#deferred-insufficient-resources) | the two rows whose blocker is a resource this project does not have, at the lowest priority there is — with the admission test they had to pass, and the candidate that failed it |
| [How this page is written](#how-this-page-is-written) | [the goal](#the-goal-adr-0109) and the test it sets, the rules for the next row somebody adds, where the ideas came from, the one structural risk no record can close, and the index of what this file used to carry |

**The three parts are new, and the chapters inside them are not.** This page
was arranged by *how a row was learned* — a chapter for what a feature left
behind it, a chapter for what writing a program found, a chapter for what
picking the language up needed. That grouping is what taught the lessons at
the end, and it is kept inside the parts rather than thrown away; what changed
is that a reader asking *what is open in the language* now has one place to
look. Two chapters split rather than moved. **What would make this practical
to pick up** gave its *Writing a daily program* section to the library and the
rest to the utilities. **The goal (ADR-0109)** gave its four areas to the two
parts that answer them — concurrency and memory safety to the language,
networking and internationalisation to the library — and kept its *test* and
its table at the end, among the rules, because *the four areas are answered
and that is not the goal met* is a rule about what may be written here and not
a status line.

**Read the parts in order the first time and by name after that.** They are
not equally full, and the shape of that is the state of the project: the
language has half a proposal and four shapes, the library has nothing, and the
utilities are down to the platforms — every other row in them was struck within
four days of being written, which is what moved most of this file into
[`doc/history.md`](history.md).
[Deferred](#deferred-insufficient-resources) is last because nothing in it is
available to do.

---

### The language

**What the compiler accepts.** Both standards were implemented and there is
one language now (ADR-0232), so nothing here is owed to a standard; a feature
in this part needs a reason of its own, and the four chapters below are the
four kinds of reason that have worked. A feature *left something behind* and
the record named it. A property the language *claims* was measured against the
goal it is named in and the claim turned out narrower than the record.
Somebody *asked* for something the language does not have. Or a program *met*
a limit and the limit is written down.

**Two of ADR-0109's four areas are answered here**, and both are properties of
the language rather than facilities beside it — a third, internationalisation,
is a clause of the language too and is listed under [the standard
library](#the-standard-library) because that is where a program meets it:

- **concurrent execution** — `task`, `spawn`, `channel [n] of T`, `send` and
  `receive`, reserving no word-symbol: share-nothing, only transferable values,
  channels and a **moved handle** cross (ADR-0303), and every task a block
  spawned is joined before that block releases anything (ADR-0268). Since
  2026-09-03 a program can also *steer* it: an activation has a name and a
  type — `task` is a handle-type and `spawn t := P(x)` binds one — `wait(t)`
  joins that one early (ADR-0312), and the **select-statement** waits until one
  of several channels can proceed, with `after N` to give up and `otherwise`
  not to wait at all (ADR-0313).
- **memory safety** — optionals and no bare null, slices carrying their
  bounds, scope-based release, `owned ^T` for a variable `new` created, and
  the move both affine kinds need (ADR-0123, ADR-0125, ADR-0151, ADR-0181,
  ADR-0182, ADR-0267) — and **most of Rust's model, arrived at without
  reading Rust**, which is also how the four things it was short of went
  unnoticed until they were probed for. Three of the four closed within two
  days of being written down; what is left of them is a sentence each.

Neither is finished in the sense that matters, and what each left behind it is
the first two sections below.

**Nothing in this part is scheduled.** The one proposal in it is still
`Proposed`: its middle increment is built and has shipped, and the other two
have no commitment behind them — which is said again where it stands.

**And nothing here is where a decision lives.** Every row in this part that is
decided or implemented is written up in `doc/afterschool-pascal-spec.md`, in
[`doc/implementation-defined.md`](implementation-defined.md), or in both;
[the rule](#how-this-page-is-written) says which takes what, and a row that
closes is not finished until it has gone there.

#### What each landed feature left open

Every row a survey of daily needs put here has been struck, and so has every
row the FFI and container increments left behind them. What stands here now is
the residue of the **concurrency** increment (2026-08-30), plus one shape that
has never found a client — and the prior the chapter arrived at, which is worth
more than any of the rows was.

**The chapter as it stood, with how each of its rows closed, is in
[`doc/history.md`](history.md#what-each-landed-feature-left-open).**

**What two threads of control left open** (ADR-0268, AP 6.7.8) is closed in
full, and the table is in
[`doc/history.md`](history.md#the-concurrency-residue) with what closing each
row found. Its four rows — to give a task a handle (ADR-0303), to wait for one
task (ADR-0312), to wait for whichever comes first (ADR-0313), and to send a
string (ADR-0302) — all closed on 2026-09-03, three of them named by ADR-0268
itself and the fourth by ADR-0295. **What the chapter is kept
for is what the closing rate says about the naming**: the record wrote its own
residue down rather than letting the feature imply it, and four rows that
closed in a day say the residue was named honestly. That is the shape to
expect from a feature record from here on.

**Three shapes stand behind the closed rows**, and none of them is a row
because none is a thing a program is waiting to be able to write — each is a
question with an answer nobody has needed yet.

- **A channel cannot carry a handle** (AP 6.7.8.1 NOTE 6, ADR-0302). A task
  may be *given* a socket at the moment it starts and cannot be sent one
  afterwards, so a fixed pool of workers taking connections off a queue is
  still unwritable. What would make it expressible is a rule about which
  activation owns a value sitting in a bounded queue.
- **An activation cannot close a channel and then drain it.** All three
  spellings of AP 6.4.16.4 — `release(c)`, `c := nil`, `c := take(d)` — empty
  the handle variable as well as closing the channel, so the close a `receive`
  or a select arm reports is always another activation's: the ordinary
  pipeline, a producer task closing what a consumer drains. It was met twice
  while ADR-0313 was written. Closing without releasing would be a new
  operation on a channel, and it is not built.
- **There is no timeout on `wait`**, and that one is a decision rather than an
  omission (ADR-0312, ADR-0313): a wait that gave up would leave a program
  holding a task-variable whose activation is still running, and no clause
  here says what that is.

**And one proposal, of which the middle increment is now built** (ADR-0315):
**methods and traits, without inheritance.** It is the first record in this tree that is *Proposed*
rather than *Accepted*. It is named here because it is what this feature's
residue turned into, and set out in full three sections down, in [The object
model (proposed)](#the-object-model-proposed). The evidence for it is this
project's own library: **139 of the exported names repeat their module's
noun** — `JsonMember`, `StreamOpenWrite`, `NetListen` — because §6.11.2 puts
every imported name into one scope and `export-unique` (ADR-0298) refuses a
collision, so the prefix is a receiver spelled by hand; and where a property
belongs to a *type*, the caller carried it instead — `MapPut(m, 'k', 1,
StrHash, StrEq)` was the shape, with **14 routine-valued parameters** across
two modules and **30 call sites** threading one pair through. **That half of
the evidence is collected**: since ADR-0355 the map's key implements `Key`, the
thirty sites name no pair, and what is left is `PasSort`'s two procedural
parameters and `PasFile`'s one, each taking a *routine* rather than standing
in for a property of a type. The prefix half stands. The denominator is the
gate's and moves: **490 exports across 32 modules** on 2026-09-07,
`python3 tests/checks/export_unique.py`; it read 486 when the numerator was
taken, 484 the day after and 489 the day after that.

The record proposes Rust's model and argues against Object Pascal's on four
grounds that are each about a decision already taken here, stages it in three,
and names what each stage costs — `dyn` being the only one that adds a
representation. **Its four open choices are settled**: all three stages, the
`impl` block, a receiver written out with its type, and one library module
rewritten as proof rather than a sweep.

**Increment B is built** — traits, implementations and the bound (ADR-0338 to
ADR-0341, AP 6.7.9). It is not the design ADR-0315 proposed for it, and the
correction is the interesting part: the bound belongs on the **schema's
discriminant**, where the client writes the type, because a routine over a
growable container takes a *pointer* to the schema and a pointer determines
nothing. ADR-0315's own payoff was unreachable from ADR-0315's own spelling.
Three further records exist because each corrected the one before it —
probing beat reading, building beat probing, and probing again beat the
obvious reading of how a trait reaches a client. **Increments A and C are not
built** and are judged separately; the question the record named as gating the
second stage does not arise, a bound being checked where the type is written
and not where inference chose one.

**And one shape with no client at all**, which is what is left of the FFI rows:
a struct **member** that is itself a pointer. A record crosses as a `var`
parameter (ADR-0184) and comes back as an optional copied at the call
(ADR-0187), so `stat`, `readdir`, `gmtime` and `localtime` are all reachable;
a *chained* list of structs is not, a member that is a pointer being a second
name for storage that cannot be copied away. No program here has wanted one
badly enough to be written, and the two that looked as though they would were
answered in C. By ADR-0116's rule that is not a thing to build; what would
move it is a probe that cannot get its chain through a `pasx_` binding.

**The prior this chapter arrived at, and the one thing to carry out of it:**
**before recording that something waits on the memory model, ask whether the
address can be retired at the call.** Five times running it could, and twice
the answer was not a language feature at all but a `pasx_` routine doing the
walking on the far side. The factory (ADR-0255, ADR-0256) is the first item
where it does not apply, which is what makes it a prior and not a rule — a
factory's whole point is that the callee's answer *outlives* the call. Where
the answer is no, expect the ownership rule the five easy ones did not need.

#### Memory model and memory safety

**ADR-0109 names memory safety as a property of the language, and the bullet at
the head of this part calls it answered.** It is answered in the sense every
row here demands: each mechanism has a record, a clause and a case. This
section is what is left of a review on **2026-09-04** that read the model
against the goal stated as *a Rust-flavoured Pascal* and **probed it rather
than reading it**. The finding was not that the design is missing a piece. It
was that **the pieces missing are not the ones the records say are missing** —
ADR-0201 withdrew the aliasing fork as a question this language does not have,
and three of the review's four rows were aliasing. Those three closed within
two days; the working is in
[`doc/history.md`](history.md#the-memory-model-read-against-the-goal) and what
stands here is what they left.

**What is already Rust's, and by what route.** The routes are the interesting
column: not one of these was taken from Rust, and two were here before anybody
looked.

| Rust | Here | How it arrived |
| --- | --- | --- |
| `Box<T>` | `owned ^T` (AP 6.4.14) | from the file variable and not from Rust (ADR-0181) |
| `Drop`, RAII | scope-based release | present since 1982, unnamed until ADR-0151 |
| a move, `mem::take` | `take` (AP 6.4.14.6, AP 6.4.12.7) | forced by writing `PasList`, not designed (ADR-0182, ADR-0267) |
| `&mut T` | a `var` parameter bound to `o^` | *unformable* rather than checked (ADR-0201) |
| `&T` | `protected var` (§6.7.3.1), and since 2026-09-04 over an owned pointer too | ISO's own word (ADR-0283, ADR-0318) |
| `Option<T>` | `?T` (AP 6.4.11) | ADR-0123 |
| `Result<T, E>` and `?` | `T ! E` and `try` (AP 6.4.13, AP 6.8.9) | ADR-0176, ADR-0178 |
| `&[T]` | `array of T` (AP 6.7.3.9) | ADR-0125 |
| `Send`, channels | `task`, `channel [n] of T` (AP 6.4.16, AP 6.4.17) | ADR-0268 |
| traits | `trait` / `impl … for`, as a **bound** (AP 6.7.9, AP 6.7.10) | ADR-0338 to ADR-0341 |
| lifetimes, `Rc`, `RefCell`, `unsafe` | **absent** | the rows below, and the three that closed |

**Three of the four rows are closed**, and the working is in
[`doc/history.md`](history.md#the-memory-model-read-against-the-goal): the
borrow rule enforced in one direction (closed 2026-09-04, reopened and closed
again the next day — ADR-0317, ADR-0318, ADR-0319, ADR-0326, ADR-0332), the
unsafe subset being the unmarked default (measured and retired — ADR-0320,
ADR-0323, ADR-0336), and the release walk that ended in a signal (ADR-0322,
ADR-0333). **What each left standing is a sentence and not a row**, and the
three sentences are what this section is now for:

- **The escape half of the borrow rule is held by construction and watched by
  nothing.** ADR-0201's *unformability is what protects against escape and is
  exactly what makes invalidation invisible* is strength in one direction only.
  The invalidation half is refused now, at the point a borrow is **formed**
  (ADR-0319) — but the escape half rests on there being no way to form the
  value at all, so a feature that ever gives the language one takes the
  property away silently. `doc/sop.md` §7 carries it.

- **A fifth warning — a `new` of an ordinary `^T` where `owned` would have
  compiled — is not built, and the reason has changed three times.** It is no
  longer that nothing *could* take the word, nor that a rewrite is needed, but
  that taking it is sometimes the wrong answer and a warning cannot know which:
  an owned container cannot be aliased, cannot be returned by a function and
  must travel as a variable parameter, which is right for a tree one block owns
  and a real loss for a container callers pass around (ADR-0337). The ordinary
  pointer itself is *kept* and written down as the unchecked form (ADR-0336);
  [Known limitations](#known-limitations) is where that stands.

- **A chain of a million owned nodes no longer ends in a signal, and a shape
  that is neither a chain nor a tree still can.** The release threads a work
  list through the link fields of the nodes waiting on it (ADR-0322,
  ADR-0333), so a list and a tree each cost one frame; a self-owned pointer the
  domain does not hold **directly** — inside an array or a sub-record component
  — has no link to thread, and a cycle of two domains is two routines calling
  one another. Neither is reachable by writing a list or a tree. Reference
  counting is the way out that is unbuilt, and nothing has asked for it: the
  arena-and-index shape needs no language change and is written down as
  `examples/arena_graph.pas`.

##### A record has no `Drop`

A handle names its closer in its own type — `handle external 'fclose'` — and
that is the only user code this language runs when a value dies. A record
owning something runs none, and `defer` is per *activation* rather than per
value (ADR-0175), so a type cannot maintain an invariant across its own
release.

**This row said "nothing has asked for it yet" and that was wrong**, in the
shape ADR-0116 already catches twice: a reason written by hand beside a row
and re-read by nobody. One thing has asked, precisely, and says so in its own
header — `PasTls.Connection` (`lib/dialect/pastls.pas`) wants `SSL_shutdown`
sent before its three handles are released, because without the close-notify
"the far end cannot then distinguish the end of the data from a connection
that was cut".

**What that asker wants is not a release, and the distinction is the finding.**
Every affine kind a record can own is *already* released from inside it: one
walk (`WalkFiles`) has a record branch that recurses on every field answering
`HoldsFile`, and the block epilogue, `dispose` and the generated `@ownrelN`
bodies are its four call sites. A record holding a file gets `pas_file_done`
per field; one holding foreign handles gets a `pas_handle_done` per field
against the closer named at entry; one holding an owned pointer gets
`@ownrelN`, recursively and worklist-driven since ADR-0333. And
`ContainsFile` already makes such a record affine. What a record cannot run is
an action *ordered before* the release, and the corpus has exactly one site
wanting one.

So the row stays open for a better reason than the one it gave: **one site is
below ADR-0116's own threshold for a design.** Should a second appear, the
cheapest shape is ADR-0290's — no spelling at all: a procedure declared in the
record's own scope taking the record as its sole `var` parameter, run by that
record branch before the field loop. It would add no affineness, such records
being affine already.

#### The object model (proposed)

**Increment B is built and increments A and C are not**, so what follows is
the record's own framing kept for the two that are still proposals. Read it
with ADR-0338 to ADR-0341 beside it: they are what B turned into, and each
corrects the one before.
[ADR-0315](adr/0315-methods-and-traits-without-inheritance.md) is the first
record in this tree with the status `Proposed`, and it was written that way on
purpose: the design was asked for on paper before any of it is implemented, so
that the shape could be argued about while the alternatives were still live.
Whether it is built is **not settled**. The two goals before this one —
bootstrapping, then conformance — were each finished before they were left, and
an area announced and abandoned would be the first thing on this page that was
neither.

##### What asked for it

Not a missing facility. Every program in `examples/` was written without an
object model, and the containers, the JSON reader and the language server are
all records with routines over them. What asked is the *second* clause of
ADR-0109's test — **can a program get it pleasantly** — measured on this tree's
own library:

- **179 exported names repeat their own module's noun, and increment A would
  retire 118 of them** — `JsonMember`, `StreamOpenWrite`, `NetListen`,
  `MapPut`. Out of **484** (`python3 tests/checks/export_unique.py`).
  **Retaken mechanically on 2026-09-05**, this page's own rule having called
  the previous `139` an estimate: the sweep reuses `export_unique.py`'s reader
  and asks two questions of each name — does it repeat the module's noun, and
  is it a routine whose *first formal's type* is a type the module exports,
  which is the only set a method can touch. The second is the number that
  matters, and it is **118 of 484, 24%**. The gap between the two is the
  finding: **59 of the repeats are types and constants** — `JsonPtr`,
  `JsonChars`, `ListItemMax`, `TlsHostMax` — which no method can ever remove,
  so they stay exported, stay prefixed, and the export surface a reader meets
  on `import` does not change at all. That is forced rather than chosen. §6.11.2 puts every imported name into one scope, so two modules
  may not export one spelling, and ADR-0298's `export-unique` gate refuses a
  collision outright. **The prefix is a receiver, spelled by hand, at every
  declaration and every call site**, and ADR-0306 renamed four examples' worth
  of them before anyone counted the rest.
- ~~**14 routine-valued parameters and 30 call sites** thread `StrHash, StrEq`
  through `lib/passort.pas` and `lib/dialect/pascontainer.pas`~~ — **the thirty
  are gone** (ADR-0355): the map's key implements `Key` and no call names the
  pair. Three routine-valued parameters remain, in `PasSort` and `PasFile`, and
  each takes a genuine routine rather than a property of a type.
- `lib/passort.pas` **never sees an element** — it sorts by `less(i, j)` and
  `swap(i, j)` — which is the *Traits / protocols* row of
  [Where the ideas come from](#where-the-ideas-come-from) said from the
  library's end.

##### The shape

**Rust's decomposition and not Object Pascal's**, and the difference is the
whole of the proposal: methods and traits without inheritance, so there is no
base class, no virtual by default, and no `is`/`as`. A method is an ordinary
routine whose first parameter is written out with its type — value,
`protected var` and `var` being what Rust spells `self`, `&self` and
`&mut self` — declared in an `impl T; … end;` block, and `x.M(a)` means
`M(x, a)`. Three increments:

| Increment | What it adds | What it retires |
| --- | --- | --- |
| **A. Methods** | the impl block, the receiver rule, `x.M(a)`, the type's own scope | the 139 prefixes. No new representation, no compatibility rule, no vtable, and CodeGen untouched — a method is an ordinary routine |
| **B. Traits, static** | the trait-type, `impl … for`, `Self`, and `T: Trait` bounds | the 14 routine parameters and 30 call sites. Resolved at instantiation, so still no vtable |
| **C. `dyn T`** | dynamic dispatch, permitted only as `owned ^dyn T` and as a var parameter | nothing — it is what a heterogeneous collection needs, and the first thing here that emits a vtable |

**A is not a prerequisite for B, and the record said it was** (2026-09-05).
ADR-0315's *Staging* table asserts "A is the prerequisite for B and B for C" in
one sentence with no argument under it, and the mechanism contradicts it.
`T: ordered` **compiles today**: AP 6.7.3.10.5 gives the type-parameter slot
four categories, recognised by `CatOfName` in `selfhost/apfront.pas` and
checked at the activation inside `InstantiateGeneric`. A trait bound is a
*fifth category in the identical slot, checked at the identical place*,
differing only in that the answer comes from a table of impls rather than from
a closed list of spellings. Increment A's three distinctive features are the
dot-call `x.M(a)`, the inherent `impl T;` block and method names living in the
type's scope, and **B uses none of them** — inside a bounded generic the call
is `Compare(a, b)`, resolved through the bound. What A and B genuinely share is
the `impl` keyword's position and its block grammar. B→C is real, a trait
object needing traits; A→B is not, and the record's own *Consequences* agree
without noticing, explaining the ordering as cheapest-evidence-first rather
than as a dependency.

**What that changes.** The measurement that passes ADR-0109's test is B's — 30
call sites and 14 routine parameters, a program's own text — and A's is 118
call-site spellings that block no program. With the toll booth gone, the two
are judged separately: B is the one to build, and A stands or falls on its
own.

**And B's own design did not survive being probed** (2026-09-05,
[ADR-0338](adr/0338-a-bound-belongs-where-the-type-is-written-down.md)).
ADR-0315 puts the bound on a routine's type parameter, and that cannot reach
PasContainer, where 30 of the call sites are: `Determine` has three arms --
`nkNamed`, `nkSchema` and `nkArray` -- and no pointer arm, 6.7.3.1's
parameter-form admitting no denoter to read a tuple out of, while the
container's routines must take the pointer because `MapPut` grows the map with
`new(m, bigger)`. Determined from the key instead, a string literal binds a type
per literal *length*, which is the failure `pascontainer.pas` already records.
**The bound belongs on the schema's discriminant** -- written `Map(K: Key;
V: type; cap: integer)` when it landed, one trait rather than `Hash + Eq`,
the language admitting one bound -- where the client writes the type down and
it is checked once. The 30 call sites did *not* stay unchanged, as this
paragraph predicted; each lost two arguments, which was the point (ADR-0355).

Two more findings came with it. The orphan rule contradicts the record's own
*What this does not do*, and taking either reading leaves `string(n)`
implementable by no component, since a type-name denotes an existing type object
and no component declared it -- so `impl` must be able to name a **schema**, or
increment B misses what a map is keyed by most of the time. And `T: Ord` is
ambiguous with an ordinary value parameter; the real slot is `T: Ord type`, the
parser already committing on that juxtaposition and merely refusing the name.

**Nothing was built at that point, and the record landing alone was the
point.** Each of the three was a contradiction of a design written without
probes, against a compiler that was there to be asked.

**Two of ADR-0338's own claims then failed the same way**
([ADR-0339](adr/0339-a-trait-heading-names-one-type-and-one-scope.md),
2026-09-05), which is the lesson holding for the record that stated it.
`Congruous` compares by type *identity*, so reusing it after substituting `Self`
works for a bare `self: Self` and not for `array of Self` -- 6.4.1 giving each
denoter that is not a type-name its own type object, so the trait's and the
impl's are two. `Self` is therefore admitted only as a whole parameter-form or
result-type, refused **at the trait-declaration**, because left to the impl the
message arrives once per implementation, in the wrong file, describing
procedural parameters to a reader who wrote none. `^Self` needs no rule at all:
6.7.3.1's parameter-form admits no pointer denoter, so it is unformable.

And a trait's routine names do collide, outright rather than as a catalogue
entry: 6.11.2 puts every imported name in one scope, and two modules exporting
`Compare` refuse the program with *'compare' is already declared in this
block*. The names a trait wants are the contested ones. The answer needed
nothing invented -- 6.11's `qualified` keeps both, probed -- but it is the
strongest argument yet for **increment A**, and not the one A is justified by:
`x.Compare(y)` resolves in the receiver's type scope and is the collision-free
form of what `qualified` here answers by hand. A is still not a prerequisite
for B; it is now something better, a reason of its own.

**And then building it found four more**
([ADR-0340](adr/0340-four-things-a-trait-heading-cannot-do.md), 2026-09-05),
which is the third turn of one wheel: ADR-0338 was written because probing beat
reading, ADR-0339 because a probe beat that record's own claims, and this
because **building beat probing**. A trait, an implementation and a dispatching
call now compile and run on the `traits-b` branch, which does not pass its
gates and is not for merging. All four findings are limits on what a trait
heading can say. It cannot name its receiver `self` -- 6.1.2 case-folds, so the
parameter name and the type name `Self` are one identifier, and every record
before this used `self: Self` as its example. Its routines cannot live in the
block's scope, two implementations of one trait each defining one spelling, so
they are declared in the implementation's own scope and reached by a
**trait-keyed** selection on the first actual's type -- which is not increment
A's per-type scope and is what keeps A out of B's way. It cannot be resolved
once, resolution annotating shared nodes so that the second impl reads the
first's types; it is re-parsed per implementation from its token position, as
AP 6.7.3.5 already re-reads a generic's body and for that clause's own reason.
And it cannot take a `protected var` receiver and serve a subrange: selection
does follow `Base()`, and then 6.6.3.3 refuses the call, a var parameter
requiring an actual of the same type. ADR-0315 asserts both halves of that last
one. The advice that falls out is that **a trait meant to serve subranges takes
its receiver by value**, which `Ord` and `Hash` both should.

**And separate translation was the question none of the three had asked**
([ADR-0341](adr/0341-a-trait-crosses-a-component-and-an-implementation-need-not.md),
2026-09-06). 6.13 has a client translate against the interface alone, so an
implementation written in a module-block is invisible to every importer -- and
the obvious reading, that this makes the feature useless in a library, is
wrong. A module may declare a trait in its interface, bind a schema's
discriminant with it there, and have its own routines dispatch to an
implementation **the client** wrote: probed at 93, the library's body reaching
the client's `Hash`. It works because such a routine is generic over its
pointer, and AP 6.7.3.5 re-reads a generic's body in the translation that
activates it -- the client's. That is the shape `PasContainer`'s routines
already have, so **the payoff needs no implementation to cross a boundary**.

One case remains and is **deferred rather than built**: a module shipping its
own implementation for its clients. The argument is ADR-0116's, not cost -- a
client writing one `impl Key for MapKey` block still removes `StrHash, StrEq`
from all 30 call sites, so the whole measured payoff survives without it --
and on 2026-09-07 it did (ADR-0355), every client of the map writing its own
block and every golden unchanged. Of
the two ways to build it, one does not exist: `NameForLinkage` derives a
cross-component name from the export-part, and separate translations share no
symbol table, so the per-impl-scope option collapses into the derived-name
option plus extra machinery. Reopening it has one candidate, not two.

Building it also found three defects reading had not. An implementation nested
in a procedure gave **a wrong answer with a zero exit status** -- 14 where the
answer was 106, the table being one unscoped list and the call passing whatever
frame it had. A module-heading did not interleave its declarations by written
position, so a trait was invisible to a schema declared above it in its own
interface. And a call that selected two implementations took the one declared
last, silently. All three are refused or fixed.

**And the first client found two more**
([ADR-0344](adr/0344-the-first-client-of-a-trait.md), 2026-09-06), which is
the fifth turn of the same wheel and the first one where the thing being used
was a library rather than a test. `lib/dialect/passortx.pas` sorts an
`array of T` by the element's own implementation, the trait declared in the
module and every implementation written by the client -- ADR-0341's shape,
exercised by something a program would import instead of by a probe. Writing
it took under an hour. The trait it wanted to declare was named `Ordered`,
because that is what the concept is called, and `ordered` is one of
AP 6.7.3.10.5's four category spellings, identified in a bound position by
spelling alone; the trait declared, implemented for two types, and reported at
the *call* that a record was not admitted by a category admitting "int64,
real, a string-type and utf8". It is refused at the declaration now. The
second finding is left alone: a local named `t` in a generic whose type
parameter is `T` **is** that type parameter, 6.1.2 folding case, which is
ADR-0340's `self`/`Self` collision one scope further in.

**Four factors were settled on 2026-09-03**, each against a real alternative:
all three increments are in scope including `dyn`; the declaration is a block
rather than a marker on each routine; the receiver is **written out with its
type** rather than implied; and one library module is rewritten as proof before
any judgement about the other thirty.

The argument that arrived *after* that choice is the best one for it: a trait
impl repeating only the routine's name is not new syntax at all —

```pascal
impl Ord for Point;
  function Compare;
  begin Compare := self.x - other.x end;
end;
```

— it is §6.7's own parameterless definition, the shape this compiler's source
writes **248 times** after a `forward`. A trait heading plays the part
`forward` plays.

##### What is settled, and what is not

**Settled.** The four factors above. And the one technical question that gated
increment B, settled by probe on 2026-09-04: a trait bound **cannot narrow
inference, because inference has no candidates to narrow** — `Determine` reads
one type off the first determining actual and `BindType` is first-wins, so
AP 6.7.3.10.5's category is checked *after* the tuple is built and a trait
bound takes that same position. Two things fell out of settling it. The
receiver is the determining position **for free**, being the first parameter.
And the tuple holds the actual's *own* type, so `1..9` is bound and not
`integer` — every existing category goes through `Base(t)` and none can tell a
subrange from its host, which makes a trait bound the first constraint that
could; the record decides the impl lookup **follows `Base()`**, so a subrange
takes its host's implementation and cannot carry one of its own.

**Not settled.** Whether to build **A or C** — B is built, and since
ADR-0355 it has a client that is not a test, which is the evidence the record
asked for and got a release out of. What increment A's one rewritten module
reads like is the evidence A waits on, and it is a different kind: B's payoff
was 30 call sites and 14 routine parameters, a program's own text, and A's is
118 call-site spellings that block no program. And what to do
about the one cost no gate will see: `x.M(a)` resolving in the type's scope
means a reader can no longer find a routine by grepping its name — `Put` will
be declared in a dozen impls. `--dump-uses` already answers *where is this name
declared* and the language server reads it, so the tooling is ready and a
person with `grep` is not. That is the feature working as intended, which is
why it is written down here rather than discovered later.

**A note on what to call it.** This section is not titled *a Rust-flavoured
Pascal dialect*, though the description is fair — eleven of the eighteen rows
in [Where the ideas come from](#where-the-ideas-come-from) are Rust or Rust and
somebody else, and slices, optionals, moves, owned pointers, `Result` and `?`
are all already here. That table **is** the Rust-flavour chapter, written per
borrowing and tied to the open decision each one settled, and a second section
under that name would say the same things with the discipline taken out. What
is new here is one proposal, so the chapter is named after the proposal.

#### Known limitations

Things that are wrong or absent today, listed so they are not rediscovered as
surprises. **Until 2026-09-02 this chapter was two lists headed by the two
standards**, and every entry in them was classified as a deviation from a
clause. ADR-0232 made that the wrong question — there is one language and no
clause governs it — and every fact the lists stated was already in
[`doc/implementation-defined.md`](implementation-defined.md), which is the
register of what this processor decides. What stays here is what is still
open in the dialect's own terms: one gap and three capacities. **The two
decisions this chapter carried are both taken** — what bindability is once no
clause fixes it to the variable-declaration, by ADR-0299 on 2026-09-04, and
`string(5)` as a parameter form by ADR-0324 on 2026-09-05. This sentence said
*two decisions* for a day after the first of them was taken, the body having
been updated to *one* and the summary above it not: a count in a heading and a
count in the prose under it are two measurements, which is the lesson this page
keeps re-learning one document at a time.

The chapter as it stood, with the two entries that had closed inside it, is
in [`doc/history.md`](history.md#the-known-limitations-chapter-as-it-stood-under-the-standards).

Six entries that stood here are the language's rule now and are looked up in
the register rather than here: an identifier may contain an underscore (§5);
`ExpDigits` is what C's `%E` writes (§2.3, E.13); §6.5.6's substring aliasing
rule is not enforced (§3, D.17); a variable created by `new(p, c1, …, cn)`
may be assigned or passed (§3, D.25); a textfile's last line need not end in a
terminator (§2.4); and a `char` is a byte, which ADR-0189 records *cannot*
change and answers with a type beside the string rather than underneath it
(§2.2, ADR-0191).

**One gap: an ordinary pointer can dangle.** `dispose(p)` stores nil into the
variable it was given, which turns the common form of use-after-dispose into
the nil trap, and does nothing for a second pointer to the same storage
(ADR-0019; the register's §3, D.4 and D.5). It is the aliasing half of the
memory-safety question, and ADR-0109 names memory safety as a property of the
language rather than a convention. The dialect's `owned ^T` sidesteps rather
than closes it: storage declared that way can have no second pointer, so
there is nothing to dangle, and §6.4.4's ordinary pointer is untouched —
ADR-0181 withdraws nothing.

**Decided 2026-09-05: kept, and written down as the unchecked form**
(ADR-0336). The two ways out were measured rather than weighed, and both fail:
*retire* on the numbers — 41 ordinary-pointer type-definitions outside `tests/`
and **0 of 41** convertible to `owned ^T` plus a borrow, the compiler's own 34
deciding it — and on containment, `new(p); q := p; dispose(p)` being conforming
Extended Pascal that ADR-0117 obliges this dialect to accept and mean the same;
*check* on cost, ADR-0325's i386 leaving no spare address bits and soundness
requiring `dispose` stop returning storage, so the checked pointer would be the
one that leaks by design. The measurement is in
[`doc/history.md`](history.md#the-memory-model-read-against-the-goal).

What is written down instead is the inversion, stated rather than glossed: the
safe subset is `owned ^T` with the non-escaping borrow, and §6.4.4's pointer is
the unchecked form containment requires be kept. Unlike Rust's `unsafe`, here
the unchecked form is the *unmarked default* and safety is opt-in and spelled —
a fact about containment rather than a lapse, and saying so is what keeps
ADR-0109's goal from reading as a claim the compiler does not meet. [Memory model and memory
safety](#memory-model-and-memory-safety) is where it stands beside the rest of
the model, and where the other half of the same question — an *owned* pointer
released while a borrow of it is live — is written down.

**Three capacities**, each a decision with a record and each a refusal or a
trap a program can meet:

| A program meets | Decided in |
| --- | --- |
| nesting deeper than 1000 levels is refused, and an operator chain is counted toward the same limit because it is flat for the parser and deep for everything after it | ADR-0020, ADR-0110; the register's §6 |
| a set's base type must have its values in 0..255, every set being one 256-bit word — so `set of integer` is refused, and so is `set of 1..m` for a bound the block evaluates, which cannot be checked against 0..255 before the program runs | ADR-0028, ADR-0133; §6 |
| string concatenation draws from an arena released at the end of every statement, so one *statement* holding more live string values than the arena holds is the limit, and both ways of exhausting it are reported | ADR-0111; §6 |

**And the one decision that had no record has one.** `string(5)` as a
parameter form (ADR-0171) is **decided and admitted** — AP 6.7.3.1.1 and AP
6.7.2.1, ADR-0324, moved to
[`doc/implementation-defined.md`](implementation-defined.md) §5 with the other
extensions that have a record. Probing it to write the clause found two things
this row had not: the **result-type** takes the form as well, which is the
position ADR-0215 wrote down as an open question and believed unwidened; and
the acceptance is exactly one production alternative, every other type-denoter
being refused in both positions. The count moved a third time in taking it —
16 sources and 22 parameters became 18 sources, 24 parameters and one
result-type, a scan that had not separated a parameter from a result never
having been asked to.

The adversarial audits that filled the old lists — five now, ADR-0162,
ADR-0167, ADR-0168, ADR-0171 and ADR-0342 — are [open question
§1](#1-the-dialect-has-no-external-authority-and-every-gate-here-is-anchored-in-one)'s
instrument, and that entry says when the next is worth running.

---

### The standard library

**Thirty-three modules, and nothing open.** That is the shortest part of this
page and it is a finding rather than an omission: the chapter that listed
library gaps struck the last of them at v3.2.0, and what replaced it is the
lesson about how those rows got there.

**The other two of ADR-0109's four areas are answered here**, and they are not
answered the same way — which is the one thing worth knowing before reading
the split as tidy:

- **networking** is a library facility outright. `PasNet`, where a socket is a
  handle and both ends are strings, so `getaddrinfo` decides what they mean
  and no program writes a byte order, with `NetWait` over `poll` and `PasTls`
  and `PasHttp`/`PasHttps` above it (ADR-0203, ADR-0205, ADR-0264, ADR-0265).
  No clause of the language mentions a socket.
- **internationalisation is a language rule with a library under it**, and is
  listed here because that is where a program meets it. AP 6.4.15 is a
  *clause* — UTF-8 in normal form C, an element is an extended grapheme
  cluster, an integer index refused — and `runtime/pasrt_unicode.c` is the
  tables it is decided by, judged against Unicode's own conformance files,
  the one oracle here nobody in this project wrote (ADR-0189 – ADR-0193,
  ADR-0196, ADR-0199). **So the four areas do not partition by these three
  parts**, and pretending they did would be the kind of tidiness this page's
  own lessons warn about.

**The library has now asked the language for something, which is the direction
this part had never run in.** `PasContainer`'s map was keyed by a caller
threading `StrHash, StrEq` through thirty call sites; it declares `trait Key`
and binds the key discriminant with it now, and every client writes the `impl`
block (ADR-0355). That is the object model's increment B earning its keep in a
module a program imports rather than in a test, and it is the only evidence
[the proposal](#the-object-model-proposed) had been short of. It is not a row
here, because nothing about the library is open as a result — but it is what a
row here would look like if one appeared.

**A row will appear here the way every good one did** — somebody writing a
program and finding it hard, not somebody reading a list. Two of that
chapter's eight rows said why they were blocked and both reasons were wrong,
which is why this part is kept open and empty rather than closed. **Two of the
four areas have been used in anger by something in this tree and two have
not**, and which two is a fact about this page's own error rate rather than
about the modules.

#### What a daily program still cannot reach for

**Nothing this page has thought of.** The chapter that stood here listed six
library gaps and two absences in the language itself, and version 3.2.0 struck
the last of them; it is in
[`doc/history.md`](history.md#what-a-daily-program-could-not-reach-for-and-now-can)
now, because a list with nothing open in it is a record rather than a queue.

That is not the same as *nothing*. It means the next entry will come from
somebody writing a program and finding it hard, rather than from somebody
reading this list — which is how every entry that closed well got here. Two of
the eight rows said why they were blocked and both reasons turned out to be
wrong, and the two most carefully argued entries each hid something a probe
found in an afternoon. A row here should be a report, not an estimate.

**Thirty-three modules exist** — eight conforming and twenty-five dialect,
listed by name in `README.md`'s module table. The newest is `PasToml`
(ADR-0360), and it is the shape the paragraph above describes: somebody wanted
to read a configuration file, which is a thing a daily program does and this
library could not.

#### Writing a daily program

**Every row closed**, and the chapter is in
[`doc/history.md`](history.md#the-last-of-the-daily-program-rows) with a
pointer to where each of them went. What a program reads can be cut without a
word (ADR-0305); concurrency was one row short and is not (ADR-0302, ADR-0303,
ADR-0312, ADR-0313); four of twelve examples collided with a library name on
their first draft, and the compiler defect under that was a placeholder type an
error path left behind (ADR-0306); `PasJson` rendered `0.75` as
`7.500000000000E-01` and its reader was not correctly rounded (ADR-0309,
ADR-0314); a `MapKey`'s 63 characters were never the map's bound (ADR-0310); an
owned pointer refusing `p := nil` has a reason and now names it (ADR-0307); and
inference could not read a type parameter through a whole array, which turned
out to be `Determine` and not the clause (ADR-0316).

**The prediction the chapter made about its own order was right**, which is
worth more than any single row: a single task's completion was the next thing
wanted and waiting for whichever came first was the one after it. What is not
worth carrying forward is any of the *reasons* it wrote beside a row — three of
them were wrong, and each was found by compiling four lines.

---

### First-party utilities

**Everything outside the compiler**, and it is down to one thing: which
machines it runs on. None of it is a language feature and none needs a
spelling — how the compiler is obtained, how it is learned, what an editor may
ask of it, how it is packaged — and every row but the platforms was struck
within four days of being written down.

The two parts above are for someone working *on* the compiler and on what it
compiles. **This one is for someone working with it**, and it was written on
2026-09-02 — as the chapter *What would make this practical to pick up*, whose
other half is now under [the standard
library](#writing-a-daily-program) — by asking what separates the tree as it
stands from a language a person picks up on a Tuesday and has a program
running by the afternoon. Every row was measured before it was written, and
the command is beside the number so that a reader can take it again; where a
cost is given it is a guess and says so, because [the language
part](#what-each-landed-feature-left-open) has three rows that were wrong
about exactly that.

ADR-0109's four areas are answered and both standards are complete, so what is
missing here is not what the compiler accepts but what surrounds it. The
struck rows are below as one table, each pointing at where its narrative went;
[`doc/history.md`](history.md) has what doing each of them found.

#### Getting it, learning it, and the editor's questions

**Every row of these three sections is struck**, and they are kept as one
because what is left of them is a single sentence: the things separating a
compiler from a language a person picks up on a Tuesday were cheap, and every
one was taken within four days of being written down.

| What was missing | Where it went |
| --- | --- |
| no release carried a binary | ADR-0296 — a `v*` tag attaches an `x86_64-linux` and an `aarch64-linux` archive, each checked the way `install-layout` checks a prefix before it is uploaded. [`doc/history.md`](history.md#the-first-archive) |
| no program to read that is not a test | ADR-0295 — `examples/` holds twelve programs of a page each, every one a case, and writing them found seven things. [`doc/history.md`](history.md#the-examples-and-what-writing-them-found) |
| no tour | [`doc/tour.md`](tour.md), eleven sections of prose with short programs in it, linked from the top of `README.md`. [`doc/history.md`](history.md#the-tour-and-what-writing-it-found) |
| a runtime error named no position | ADR-0293 — `… at file:line:col` after every trap message. [`doc/history.md`](history.md#a-runtime-error-names-no-position--closed-adr-0293) |
| a source named with no directory found no sibling module | ADR-0308, the day the tour that found it landed: `SourceDir` answered the empty string where the answer is `./`, and `AddPath` drops an empty directory on purpose. `bare-source-name` is the gate, and it has to be one because no test case can choose how it is named |
| no way to start a project except by hand | ADR-0348 — `pascalcc new-project <name>` writes `src/`, `test/`, a `.gitignore`, a README and `afterschool-pascal.toml`; `build`, `run` and `test` read it. [`doc/history.md`](history.md#a-project-is-a-convenience-over-a-file) |
| the server answered thirteen methods and none of them completed a name | ADR-0300, ADR-0301 — fifteen now. [`doc/history.md`](history.md#tooling--closed-adr-0300-adr-0301) |
| a user's own multi-module program already built itself and nothing said so | [`doc/tour.md`](tour.md#there-is-no-manifest-and-no-build-order-to-maintain), under a heading of its own — resolution is transitive, `--dump-imports` tells `pascalcc` what to translate, and there is no manifest and no order to maintain (ADR-0244) |

**Windows and macOS are the exception, and are in the [cross-platform
chapter](#what-is-left)** rather than repeated here. The one sentence worth
adding from this side: macOS is the cheapest unknown in the tree — the
runtime's five non-ISO names are all there — and a language nobody has run on a
laptop is not yet practical whatever else is true of it.

**What the chapter got right and what it got wrong** is the part worth keeping.
It asked for one row from each section to be taken first — a binary, a line in
every trap, `references`, and the examples — and all four went within a day,
which says the ranking was sound. What it got wrong is what [the language
part](#what-each-landed-feature-left-open) got wrong three times over: the
*reasons* written beside the rows. Every row that said why it was blocked was
cheaper than it claimed, and the row about a source named with no directory was
not a missing feature at all but two right answers to two different questions,
wrong together.


#### Cross-platform support

The repository is developed on x86-64 Linux and **built and tested on aarch64
on every push**, natively, from a seed whose header lines still say x86-64.
That port was measured rather than estimated (2026-08-22), and the lock turned
out to be three things for an LP64 little-endian target — two lines of emitted
text, one size constant, and a seed for the new host — of which the first two
are done (ADR-0155, ADR-0156, ADR-0157, ADR-0159). The measurements are in
[`doc/history.md`](history.md#cross-platform-support-measured); what follows is
what they leave.

**Where every target stands on layout**, from `target-layout`'s own comparison
run by hand over 25 targets rather than the two the compiler admits, on
2026-08-22, against the 4538 offsets there were that day. **Read the
proportions and not the absolute**: the denominator is every field of every
frame the compiler emits for its own source, so it moves with each declaration
added to any of the three program-components. **The gate prints its own count
and this sentence does not**, that number having been quoted here and gone
stale in two days: it said 4999 and the gate then said 8955. **And this
sentence went stale in its turn**, which is the argument rather than an
embarrassment -- 8955 stood here while `CLAUDE.md` said 9320 and the gate, run
on 2026-09-01, said **10 346**, and on 2026-09-05 it says **10 898**. Two
documents answered differently about one gate, neither was right, and the
number has moved twice since. Run it: `python3 tests/checks/target_layout.py`.

**The split is why, and not by adding a declaration.** A module emits the
frame *type* of every frame it can index, which includes the frames of the
modules it imports — a static link is walked across a module boundary and its
layout has to be spelled to do it — while the routines themselves are
`declare`d and defined once. So the three translations emit 85, 487 and 706
frame types against 710 functions defined in total: the counts are cumulative,
and the gate folds roughly 1.8 frames per frame there is. Harmless, the gate
comparing each against every target either way, and worth knowing before
reading the denominator as a measure of the compiler's size.

The comparison has no mode that reproduces itself, so the day it was taken is
part of what it says.

| target | offsets differing | |
| --- | --- | --- |
| aarch64, riscv64, powerpc64le, loongarch64, mips64el | 0 | LP64 little-endian |
| powerpc64, mips64, aarch64_be, sparcv9 | 0 | LP64 big-endian — endianness decides what a byte means, not where a field sits |
| x86_64 and arm64 apple-darwin; x86_64 and aarch64 windows | 0 | Mach-O and COFF agree |
| s390x | **13** | aligns `i256` to 8 where every other target says 16 — ADR-0028's shape exactly |
| i686, arm, riscv32, mipsel, powerpc, x32, … | 3858–3904 | **every 32-bit target** — and the offsets were the wrong measure of the work: 3858 offsets differ because **seven rules** do, which is what ADR-0325 cost |

##### What is left

- ~~**32-bit, which is the real work.**~~ — **done** (ADR-0325) on 2026-09-05,
  and the row had named four rules where there are seven. The port, the two
  defects no arithmetic check could see, and *which* i386 (ADR-0346) are in
  [`doc/history.md`](history.md#the-32-bit-port-and-the-width-it-left).
- ~~**How a foreign declaration should name a C `long`**~~ (ADR-0129) —
  **decided** the same day it was measured (ADR-0328, AP 6.4.2.7), and then
  found wrong **twice more** with the decision in place: `labs` at `-O0`
  (ADR-0334), and nine bindings plus the emitter's own slice count that no
  corpus on any one host could convict (ADR-0364), so `foreign-width` holds
  the claim as a catalogue. All three are in the same chapter of
  [`doc/history.md`](history.md#the-32-bit-port-and-the-width-it-left).

**The rest is small and specific.** s390x's `tySet` alignment (13 offsets;
`target-layout`'s second claim is what would catch it now — i386 does not have
that problem, `i128:128` being in its own datalayout). Windows: `fmemopen` and
`open_memstream` do not exist in the CRT, so `readstr` and `writestr` need two
hand-written `FILE*`-over-memory functions, `access` is `_access`, and MSVC
lacks the `_Complex` §6.7.6.2's functions are written in. **macOS needs none
of it** — the runtime's five non-ISO names are all there — and has never been
tried, which makes it the cheapest unknown in the chapter.

##### What is not claimed

**aarch64 works and is shipped; it is not seeded.** Since ADR-0296 every
release attaches an `aarch64-linux` archive, built and put through the whole
suite on an arm64 runner. What that archive does not claim is written in the
record and worth repeating: `seed/*.ll` is generated for x86-64 and
`seed/README.md`'s target lock stands, the compiler in the archive writes an
x86-64 header unless `--target=` or `AFTERSCHOOL_PASCAL_TARGET` says
otherwise (clang overrides it when it assembles, so a program is right and a
`pascalcc -S` file names the wrong machine), and CI establishes that the port
*works* — the seed retargets textually, the layout rules hold for a second
machine, the runtime's constants clear it — not that every oracle has run
there.

**Not every oracle follows.** `llc-second-backend` skips on the arm64 job, and
the SMT proofs are about the lowering *model*, the same file on either machine.
A miscompilation only an aarch64 backend produces has nothing looking for it
(`doc/sop.md` §7).

**The layout gate sees frames and nothing else.** A global's alignment, a string
constant's, and the ABI arguments travel by are outside it.

---

### Deferred: insufficient resources

**Lowest priority, and not a queue.** Everything else on this page is open
because nobody has decided it or nobody has done it. These two are open because
what they need is not a decision and not an afternoon: it is a resource this
project does not have, and no amount of prioritising conjures one. They are
here so that a reader can stop weighing them against work that is actually
available.

**The admission test, and it is strict on purpose.** A row belongs here only
when somebody has *shown* the blocker is a resource — not when it looks
expensive. That is the same rule the rest of this page is under: a row is a
report and not an estimate. It matters more here than anywhere, because
"insufficient resources" is the most comfortable reason there is to write
beside something, and the least likely to be re-examined.

**It has already caught one.** *A miscompilation only an aarch64 backend
produces has nothing looking for it* was written into this chapter and taken
straight out again: checking it found `llc-second-backend` skipping on arm64
for want of an `apt-get install llvm`, and the objection recorded against that
— `llvm` must stay out of the container the documented build is checked in
(ADR-0085) — turned out to be an objection to a step of the *test* job and not
to a job of its own. GitHub's arm64 runner was already in use by the job beside
it. It cost about thirty lines of CI (ADR-0331) and had been filed as a machine
nobody has.

#### 1. The front end has no second implementation

`difftest` compared `src/`'s tokens, AST and Sema against the Pascal
compiler's over every source in the tree, and ADR-0232 retired it with the
conformance surface it compared. So the whole front end is now guarded by
goldens that agree with whoever wrote them, plus `tests/spec/` for a
clause-shaped requirement. `doc/sop.md` §7 calls it **the largest blind spot on
that page**, and it is.

**What it needs is a second implementation, and that is a team-year.** But the
reason it is deferred rather than merely expensive is the second half, which
ADR-0232 already wrote down: *a second implementation of a language with no
external specification would be two readings by one author*, which is exactly
what `difftest` could never contradict either. What it did catch was drift
between two ports of one reading — real, and narrower than the gap it looks
like it closes.

So the cost is a team and the value is disputed, and both would have to change
before this is worth starting. `.claude/skills/langspec-audit/` is the
substitute already in use: independent readers given the behaviour and not the
reasoning, told to prove the compiler wrong from the standards text (ADR-0101).

#### 2. There is no third-party corpus

BSI's 812 programs were the only artefact here that nobody in this project
wrote, and they are ISO 7185: 25 of them use a word-symbol §6.1.2 reserves, so
this compiler cannot compile the suite at all (ADR-0232). Nothing replaces it,
and **nothing exists to acquire** — which is what puts this row here rather
than in a budget.

Two things narrow it and neither closes it. `unicode-conformance` is an oracle
nobody here wrote and covers one clause. `fpc-differential` (ADR-0234) is a
second *processor* rather than a corpus: it answers 103 of the 244 cases that
have a golden, reaches nothing in `tests/dialect/`, and shrinks with every
release as the dialect grows.

---

### How this page is written

**The goal, the rules, the lineage, and the one risk that is not a task.**
Nothing in this part is an item of work. The goal is here rather than at the
top because the useful half of it is a **test** — *does a program someone
would actually write today need it, and can it get it* — which governs what
may be written in the three parts above; the lessons are for whoever adds the
next row; the borrowings table records where each idea came from and what it
settled; the standing risk is read every time and finished never; and the
index at the end says where everything this file used to carry went.

#### The goal (ADR-0109)

**A Pascal you can get daily work done in**: a dialect and a standard core
library for networking, internationalisation, concurrent execution, and memory
safety as a property of the language rather than a convention.

Two goals came before this one — bootstrapping, then conformance — and both are
**finished**: the compiler compiles itself, and every clause of both standards
was implemented. **This is now the only goal**, and version 3 is what made that
literally true: ADR-0232 removed `--std` and the two conformance modes, so
there is one language and no mode to be put into. What the standards still are
is where this language came from — it contains Extended Pascal, so every clause
reading in this tree still describes it — and not an obligation it is under.

**All four of the areas ADR-0109 names now have an answer**, the last of them
on 2026-08-30. Each is set out in the part that answers it — the first two
under [the language](#the-language), the last two under [the standard
library](#the-standard-library) — and the table is kept whole here because it
is one claim and not four:

| Area | Where it is answered |
| --- | --- |
| networking | `PasNet` — a socket is a handle and both ends are strings, so `getaddrinfo` decides what they mean and no program writes a byte order — with `NetWait` over `poll`, and `PasTls` and `PasHttp`/`PasHttps` above it (ADR-0203, ADR-0205, ADR-0264, ADR-0265) |
| internationalisation | AP 6.4.15's text model: UTF-8 in normal form C, an element is an extended grapheme cluster, an integer index refused — and Unicode's own conformance files judge it, which is the one oracle here nobody in this project wrote (ADR-0189 – ADR-0193, ADR-0196, ADR-0199) |
| concurrent execution | `task`, `spawn`, `channel [n] of T`, `send` and `receive`, reserving no word-symbol: share-nothing, only transferable values and channels cross, and every task a block spawned is joined before that block releases anything (ADR-0268) |
| memory safety | Optionals and no bare null, slices carrying their bounds, scope-based release, `owned ^T` for a variable `new` created, and the move both affine kinds need (ADR-0123, ADR-0125, ADR-0151, ADR-0181, ADR-0182, ADR-0267) |

**A fifth area is proposed and ADR-0109 does not name it** — an **object
model**, which is a different shape from the four above: nothing is
unreachable without one, and every program in `examples/` was written without
it. It has a section of its own under [the language](#the-language) — [The
object model (proposed)](#the-object-model-proposed) — because it is a design
on paper with nothing built, and a table row here would read as a plan.

**That is not the goal met**, and the distinction is why this section sits
among the rules rather than at the top of the page. A facility that exists is
not a facility that is pleasant to use, and ADR-0109's test was never *does the
language have it* — no standard governs this language, so that question has no
asker — but **does a program someone would actually write today need it, and
can it get it**. What answers that is somebody writing a program and finding it
hard, which is what [What a daily program still cannot reach
for](#what-a-daily-program-still-cannot-reach-for) is waiting for and what [the
language server](history.md#the-language-server-and-the-bound-it-found-before-it-ran)
was written to produce. **So a row in any of the three parts is evidence from a
program and not an item from a list**, which is the same rule the three lessons
below give in three other ways.

**The four *decisions* the goal forced are all made too** — three of them by
discovery rather than by design, and the fourth by deleting the thing it was
about. Not one decided the question its row was written to pose, which is the
part worth reading: the table, with what each answer cost, is in
[`doc/history.md`](history.md#the-four-decisions-the-goal-forced).

**One thing outlived its row.** The C++ reference front end went (ADR-0232),
and with it the last comparison of this front end against a second answer —
which is [open question §1](#1-the-dialect-has-no-external-authority-and-every-gate-here-is-anchored-in-one)
two sections below, and `doc/sop.md` §7's largest entry, and is stated there
rather than here so that one fact does not come to disagree with itself.

What is already in hand and was not built for this: modules and separate
compilation (ADR-0053, ADR-0079) mean a library needs no new language
mechanism, and `runtime/pasrt.c` is where the outside world already enters.

**A decided or implemented thing in [the language](#the-language) belongs in
`doc/afterschool-pascal-spec.md`, in
[`doc/implementation-defined.md`](implementation-defined.md), or in both — and
a row here is not where it lives.** This page is a queue and those two are the
language: the specification says what the language *is*, clause by clause, and
the register says what this processor decides where a clause leaves it open.
So a row that closes is not finished when it is struck through; it is finished
when the thing it decided can be looked up by somebody who never read this
file. Which document takes it:

| What was decided | Where it goes |
| --- | --- |
| a rule of the language, or a consequence of one a reader would otherwise have to derive | a clause or a NOTE in `doc/afterschool-pascal-spec.md` |
| an answer this processor gives where a clause leaves it open, a capacity a program can meet, an error not reported, an extension, or a program accepted that the grammar it came from rejects | the matching section of `doc/implementation-defined.md` |
| a decision **not** to build something, where a reader would otherwise read the absence as an oversight | a NOTE beside the construct it was not given to |
| why it was decided, and what it cost | an ADR, and neither of the two above |

**The third row is the one that gets missed**, and it is the reason this rule
is written out. Three of the concurrency residue's standing shapes were
decisions — a channel cannot carry a handle, an activation cannot close a
channel and then drain it, and there is no timeout on `wait` — and only the
first was in the specification; the other two read as things nobody had got to
(AP 6.4.16.4 NOTE 5 and 6.9.3.14 NOTE 5 now say otherwise). A limitation that
is a decision and does not say so will be "fixed" by somebody eventually.

**And the check is a reader, not a gate.** `spec-clause-traceability` asks
whether a clause a scenario cites exists and whether the triage calls it
testable; nothing here asks whether a *decision* reached either document, and
nothing can — the question is whether a fact was written down, and only
somebody reading both can answer it. `doc/sop.md` §7 carries that gap.

**Three lessons govern how this page is written**, and they are here rather
than in the history because they are rules for the next row somebody adds.
They were learned by the chapter that used to stand between *What a daily
program cannot reach for* and *What would make this practical to pick up* --
the second of which is now split across the library and utilities parts --
**What would make this easier to work on**, archived to
[`doc/history.md`](history.md#what-would-make-this-easier-to-work-on) on
2026-09-03 when the last of its eleven items closed.

**A number needs a date *and* a command.** The suite item said 262 seconds,
and every word of it was true of a configuration nothing used: it was measured
serially while CI had run `-j"$(nproc)"` on every push since the workflow was
written. The figure had a date, had been re-measured twice after an earlier
round of six wrong figures, and was still wrong — so the rule this chapter
gave itself was not enough. What closed it was a flag worth 3.4× (ADR-0281).

**A row saying a feature is blocked is a row nobody has tried.** Three rows in
succession were settled by attempting them, and each had carried a stated
reason it could not be done. The `protected var` warning said §6.6.3.6's
congruity made the fix illegal — it does, and the answer is to defer the
diagnostic to the end of the component, which is one page of code (ADR-0283);
the estimate under it said 81 sites where the truth is a **fixed point**, one
pass reporting 130 and seven reporting zero. `textDocument/rangeFormatting`
said the printer had to be *told* where its indent begins, which only a parse
can answer; the printer accumulates that depth itself as it walks the token
stream, and the whole feature is a gate on two routines (ADR-0284).

**And the lesson is not about this page.** ADR-0286 is the third instance and
it was found in `doc/sop.md` §7, which is a register of what is *not* checked
and so is the one document here whose rows are supposed to be uncomfortable.
A row there said nothing holds ADR-0283's zero, and gave a reason for
declining a gate: the count is a fixed point rather than a number, so a gate
would have to iterate to convergence. Iterating is what **reaching** zero
needed; holding it needs one sweep. The gate is 1.2 seconds, and removing one
`protected` from the compiler's own source leaves 798 of 798 cases green — so
the row was right about the gap and wrong about the cost, which is the same
shape twice over. **A reason written beside a declined item is an estimate
like any other**, wherever it is written, and this page's own rule applies to
it: it is a report or it is a guess.

**An item can be re-scoped by measuring it rather than by arguing about it.**
`--dump-uses --at line:col` was asked for and the measurement closed it the
other way: the flag saves no compiler time, and narrowing the query would have
cost the per-document cache that took five hovers from 795 ms to 159
(ADR-0276).

Nothing here is a work queue with owners and dates. Where a decision has been
made it has an ADR; where it has not, that is the point of the entry.

#### Where the ideas come from

Rust, Swift and Zig are the reference points, and they do not all fit equally:
Pascal's grain is value semantics, explicitness and a small orthogonal core,
which is close to Zig and Swift and further from Rust. Each borrowing was tied
to the open decision it would settle, and **every row that named one has now
been settled** — the last of them by ADR-0268.

| Idea | From | Settles | Where it stands |
| --- | --- | --- | --- |
| Slices — a pointer and a length | Zig, Rust | bounds safety | **Done** (ADR-0125, ADR-0129) |
| Optionals, and no bare null | Swift, Rust | pointer safety | **Done** (ADR-0123); the check is localised to `^`, not eliminated |
| Scope-based release | ISO 7185, Rust's `Drop` | lifetime | **Done, and it was already here** (ADR-0151) — for a *declared* variable; a created one had no owner until ADR-0181 |
| An owning pointer | Rust's `Box` | lifetime, for the heap | **Done** (ADR-0181, AP 6.4.14). Reached from the file variable rather than from Rust, and it decides nothing about aliasing because it admits no second name |
| A move | Rust's `mem::take` | what an affine type needs to be usable | **Done** (ADR-0182, ADR-0267). Given to an owned pointer first, then **widened to a handle** when a task needed to be handed a socket; a file has no value for a variable to stop holding, so the refusal there is a decision and not a gap |
| Error unions / `Result` | Zig, Rust | error handling | **Done** (ADR-0176, AP 6.4.13), and it needed no new type: `T ! E` denotes an ordinary record with a flag on it, so the copy, the layout and ADR-0118's trap came free and CodeGen was not touched |
| Propagation | Zig's `try`, Rust's `?` | the rest of error handling | **Done** (ADR-0178, AP 6.8.9). A required identifier and not a position, because a factor may be a variable-access — `try (x)`, `try [x]`, `try.f` and `try^` all mean something to a program that declares `try` |
| An early exit | Turbo Pascal, Delphi, FPC | what propagation stands on | **Done** (ADR-0177, AP 6.7.5.9). The first borrowing here whose source is another *Pascal*, and a branch to the epilogue every block already had |
| An early loop exit | Turbo Pascal, Delphi, FPC | nothing structural — an ergonomic gap | **Done** (ADR-0208). Taken whole from the three dialects that have it, down to the spelling: a question the standards do not answer and three Pascals answer alike is one where novelty would be a cost with nothing to show for it |
| `defer` | Zig, Swift | resource safety | **Done** (ADR-0175, AP 6.9.3.11). Zig's unit rather than Go's, because a per-activation defer runs a loop's `dispose(p)` once with the last `p` |
| Unicode-correct `String` | Swift | the text model | **Done** (ADR-0189 – ADR-0193, ADR-0196, ADR-0199). The grapheme as the unit and the refused integer index are Swift's and taken whole; the *storage* is not — a value with a declared capacity rather than a reference-counted buffer, which is what makes normalise-on-construction affordable and buys a bytewise `=` |
| Explicit allocator passing | Zig | part of memory safety | **Tried; does not survive contact** (ADR-0116) |
| ARC | Swift | aliasing | **Withdrawn as posed** (ADR-0201): ADR-0117's containment fixes what `^T` means and ARC changes it, so the candidate cannot reach the only reference type an ISO program has |
| Ownership and borrowing | Rust | aliasing | **The same, and half of it was already here**: a `var` parameter bound to an owned value's referent is a borrow, and it cannot escape because there is no address-of and `new` is the only producer of a pointer. *Unformable* rather than checked (ADR-0201) |
| Actors / share-nothing tasks | Concurrent Pascal, Ada, Swift, Rust | concurrency | **Done** (ADR-0268), and it is the row this table was really about — the one sentence left of the aliasing fork, *two threads of control*. `task`, `spawn`, `channel [n] of T`, `send` and `receive`, reserving no word-symbol: a task takes only transferable values and channels, may name only its own variables, and every task a block spawned is joined before that block releases anything — which is what makes *a borrow cannot outlive the call* true again. The lineage read was Pascal's own: Concurrent Pascal had `process` and `monitor` in 1975. **Built without meeting ADR-0116's bar**, which the record says in as many words — nothing in this tree wants it, and the compiler is one thread and must stay so, the seed compiling it. What it left open is [above](#what-each-landed-feature-left-open) |
| Traits / protocols | Rust, Swift | abstraction | **Half done, and something has now asked for the other half.** Schemata gave parametric types over a *value* (ADR-0039); ADR-0209 lets a discriminant name a **type**, so a container is written once; ADR-0266 lets a type parameter say what it needs. What is absent is a generic *routine* over one — `lib/passort.pas` sorts by `less(i, j)` and `swap(i, j)` and never sees an element for exactly that reason. This row read *nothing has asked for* abstraction over **behaviour** until 2026-09-03, and [ADR-0315](adr/0315-methods-and-traits-without-inheritance.md) is what asked. **Both halves are now built, and the successor is written**: a trait bounds a schema's type-valued discriminant and a routine's type parameter, and `lib/dialect/passortx.pas` sorts an `array of T` by the element type's own `Sortable` (ADR-0338 to ADR-0341, ADR-0344, AP 6.7.9). `PasSort` stays, being conforming Extended Pascal, and its `SortIndexed` still answers for parallel arrays |
| `comptime` | Zig | metaprogramming | **Later.** Constant-expressions everywhere (ADR-0054) is as far as anything needs |

**The lesson this table is kept for**, drawn four times over and once against
itself: **measure the cost before naming the mechanism.** Three times the
expensive-looking sentence was not where the time went — `select` answered a
socket server where a thread was named, a cache took five hovers from 795 ms
to 106, and a `didChange` drain took four queued edits from 780 ms to 340 —
and once the *cheap-looking* route was the expensive one, polling an
unbuffered pipe measuring 621 ms against 5 on the operation a reader performs
most. The narrative is in
[`doc/history.md`](history.md#the-concurrency-row-and-the-four-cheaper-answers).

**And the other one: the cheap items are not the small ones.** `defer` and
error unions between them cover most of what "daily practical development"
means, and neither required settling the memory-safety fork. Four estimates in
a row — ADR-0122, ADR-0123, ADR-0176, ADR-0177 — assumed a feature would need
its own machinery and none of them did. Probe before believing an estimate of
that shape.

#### The open questions

Seven structural questions about the dialect and five items of *what is next*
used to stand here. **Eleven of the twelve are answered** — the table at the
end says where — and what each found on its first run is in
[`doc/history.md`](history.md#what-the-roadmap-answered). **One remains, and
it is not a task**: §1 is a standing risk no record can close, which is why it
is first — it is read every time and finished never. §2 was the last of the
tasks and is done (ADR-0234). §4 was opened and answered on one day, by the
route its own entry records: it is what was left when a limitation written
here turned out to be a misreading (ADR-0214, ADR-0215).

**Version 3 made §1 heavier and §2 more urgent**, which is the one thing to
know before reading them: ADR-0232 removed the conformance modes, and with
them the BSI suite and `difftest` — the whole of §1's second column and the
premise of §2. Neither entry gained a new problem; each lost what partly
covered it, and §2 was then taken *because* it was shrinking. It bought §1 a
row back, and not the two it lost.

##### 1. The dialect has no external authority, and every gate here is anchored in one

A standing **risk** rather than a task, and the one entry no record can close.

The table used to have three columns — ISO 7185, Extended Pascal, the dialect —
and the whole of what ADR-0232 did to this entry is collapse it into the last
one. The two struck rows went with the conformance modes they were about.

| | this language |
| --- | --- |
| ~~third-party corpus~~ | **—** (BSI, 812 programs, until ADR-0232) |
| ~~second implementation (`difftest`)~~ | **—** (`src/`, the refusal surface only, until ADR-0232) |
| clause-cited scenarios | yes (ADR-0135) |
| independent reading | [the spec](afterschool-pascal-spec.md), audited once (ADR-0144), by readers isolated since ADR-0228 |
| goldens, irtest, `llc`, `verify/` | yes |
| a published third-party answer | Unicode's own conformance files, for AP 6.4.15 alone (ADR-0189) |
| a second **processor** | Free Pascal under `-Miso`, over the 103 of 244 cases with a golden that it will compile — programs only, never `tests/dialect/` (ADR-0234) |

Every oracle in this repository bottoms out in *this project says X*, and no
oracle here can contradict a **reading** — which is how ADR-0072's set-packing
deviation survived in four documents and a purpose-written test. The remedy is
independent readers (`.claude/skills/langspec-audit/`), and its reach is
narrower than it was: an audit can check every claim the specification makes
*about* the standards — nine were wrong the first time — and cannot check a
requirement this language invents, where a reader can only ask whether the
processor agrees with the document.

**Both empty rows were partly filled once and are empty now**, which is the
thing to carry out of ADR-0232. The BSI suite is unavailable for two reasons
rather than one: it is ISO 7185, which this language is not, and 25 of its
programs use a word-symbol this language reserves, so the corpus cannot be
compiled here at all. `difftest` covered the conformance surface, and there is
none. A high citation fraction means the specification is young and was written
against a compiler someone could probe, not that this language is as well
checked as the conformance modes used to be.

**Two rows have grown since, and neither replaces what was lost.**
`fpc-differential` (ADR-0234) is a second *processor* rather than a second
corpus: it reaches 103 of the 244 cases with a golden, none of them in
`tests/dialect/`, and it is not an authority — it implements neither standard
completely, so a disagreement is a contradiction to be judged and not a
verdict. What it is worth is that a reading now has something that will
disagree with it out loud: three of its six clause-level disagreements
corroborate readings nothing here could challenge, ADR-0073's among them.

The other is `unicode-conformance` (ADR-0189,
ADR-0190) is a published answer nobody in this project wrote, checked against
20 034 normalisation cases and 766 segmentation cases — and it is the shape
worth looking for again: **a facility whose correctness some outside body has
already published**. It reaches exactly one clause. Where a future feature has
such a body — POSIX, the C ABI, Unicode, an RFC — taking its conformance data
into the tree buys more than any gate this project can write for itself.

Two authorities *are* available and should be used wherever they reach: **POSIX
and the C ABI** for anything FFI-facing (the slice's shape was the far side's
choice, ADR-0129), and the standards themselves wherever they answer the same
question differently — ISO 7185 §6.6.3.7's conformant array is the standard's
own answer to the slice's question, found only after the slice had landed
(ADR-0152). A new dialect feature should look for its authority before its
spelling.

**A third is the other Pascals**, and it is worth naming because this entry
reads as though there were none. Turbo Pascal, Delphi and Free Pascal are
*dialects* — none of them implements either standard completely, and each
answered questions these standards do not: an early `Exit`, `Break` and
`Continue`, `try..finally`, a string type that grows. **That list is not
hypothetical, and three of the five have since been taken off it** — `exit`
(ADR-0177), `defer` where those dialects have `try..finally` (ADR-0175), and
`break` and `continue` (ADR-0208) — each spelled the way a Pascal already
spells it, and each argued for in its own record on grounds of its own rather
than by citation. Where one of them has
already answered a question this dialect is asking, that answer is a reference
point: not because it is authoritative — it is not, and two of them disagree
with each other — but because a Pascal programmer arriving here already knows
it, and gratuitous novelty is a cost paid by every future reader.

**And the absence of an oracle is a fact about how a claim is checked, never a
reason not to make one.** This entry is a risk register, not a brake. Where no
authority answers, the dialect answers for itself — reasonably, in the
standards' own idiom, written down in the specification and pinned by a case
that fails without it. That is what every one of ADR-0117 onward did, and the
discipline that matters is internal: a named failing test, a mutation that
kills it, a clause that says what was meant. What this entry warns about is
narrower than it looks — that a *misreading of the two standards* is invisible
here — and it has nothing to say about a facility the dialect invents outright,
where there is no reading to get wrong.

**The instrument for the risk is the adversarial audit** — independent readers
given the behaviour and not the reasoning, told to prove the compiler wrong
from the standards' text. **Five have run** (ADR-0162, ADR-0167, ADR-0168,
ADR-0171, ADR-0342); the fifth was scoped to the memory model on 2026-09-06
and found **three real holes every gate here was green over**, which is what
the instrument exists for. It also found the largest thing in that record and
the one no reading was needed for: **AddressSanitizer had never instrumented
compiled Pascal**, the emitted IR carrying no `sanitize_address` attribute, so
every argument of the form *ASan reports nothing* made about a program's
behaviour was empty — until ADR-0358 put the attribute on every emitted
function, measured the corpus clean under it, and made the gate refuse to
sweep without first proving that it bites. The *Known limitations* chapter used to close with the
note that the next audit is worth running whenever that chapter has not moved
for a while, and the note belongs here, since a claim no test names is a claim
nothing checks.

##### 2, 3 and 4 — answered

A third-party differential (ADR-0234), mutation testing committed to the tree
(ADR-0207) and *should the dialect read a type off a component?* (ADR-0215)
were the other three questions this chapter carried. Each has a row in
[Answered, and where](#answered-and-where) and its narrative in
[`doc/history.md`](history.md#what-the-roadmap-answered). §1 above is the only
one left, and it is the one no record can close.

#### Answered, and where

Every question this file has carried and closed. The narrative of each — what
the survey found, what the estimate got wrong — is in
[`doc/history.md`](history.md#what-the-roadmap-answered); the decision is in
the record.

| Question | Answer | Record |
| --- | --- | --- |
| Does the dialect spend reserved words? | No: a feature is spelled where a conforming program could not have written it. The `reserved-words` gate that enforced it retired with the conformance modes; the rule stands, and now protects this language's own claim to accept every Extended Pascal program | ADR-0140, ADR-0232 |
| Does containment survive the link? | It did, except where the dialect would emit a check the other mode did not — and the mechanism went with the modes. A module's activation names still carry a fixed language tag, so an object from an older release is refused with a message rather than mislinked | ADR-0137, ADR-0119, ADR-0232 |
| Is containment witnessed by more than one program? | It was — the whole of `tests/extended/` compiled a second way, every run — until there was only one way to compile it. `tests/dialect/inherits_extended.pas` is what remains | ADR-0138, ADR-0232 |
| Are the dialect's pieces coherent? | Four result shapes, one rule in two questions; a boundary shape may be a parameter and not a result | ADR-0141, ADR-0149 |
| Do the conformance modes "stay exactly as they are"? | They did, until they were removed. What they accepted never moved for the dialect; then ADR-0232 removed the modes rather than the promise | ADR-0154, ADR-0232 |
| Memory safety: deferral or discovery? | Discovery, twice. Lifetime was already answered, by the file variable (ADR-0151); aliasing was too, by refusal for the three affine kinds and by a **borrow that cannot escape** for the rest — Pascal has no address-of, so no pointer can name what a `var` parameter refers to. What is left of the fork is two threads of control and nothing else | ADR-0151, ADR-0201 |
| A third-party differential | Free Pascal under `-Miso` over every case with a golden, catalogued by which clause decides each disagreement. No defect found here; six clause-level disagreements, all six decided here. It cannot reach the eight conforming `lib/` modules — FPC implements no Extended Pascal module — and it shrinks with every release | ADR-0234 |
| An oracle nobody here wrote | The BSI suite and `src/` as a reference front end — **both retired with the conformance modes they were about**. What is left is `unicode-conformance`, which is a published third-party answer for one clause | ADR-0086, ADR-0108, ADR-0189, ADR-0232 |
| Diverse double-compiling | Run once, 2026-08-18, identical outputs; `seed/ddc.sh`. **The window is closed**: `v0.1.0` has no `--import` and cannot read a compiler that is three program-components | `seed/README.md`, ADR-0233 |
| Should the compiler be one source file? | No, and it had not needed to be since ADR-0053. Three program-components, cut where the file order already was a topological order — 66 `forward` declarations, all inside one stage. The reason is the linking blind spot and not the buffers | ADR-0024, ADR-0233 |
| Conformant array parameters, and level 1 | Done, and the 51 BSI level-1 programs found nine defects in the first implementation | ADR-0153 |
| Can anything measure what the corpus reaches? | Three coverage gates and a clause-cited suite | ADR-0103 – ADR-0106 |
| Is what the corpus reaches what this project is *made* of? | No: 46 718 lines of 67 931 had an instrument. `lib/`, `runtime/*.c` and `lsp/pasls.pas` are measured now, the dumps have a corpus, and the sanitizers see compiled Pascal for the first time — [the chapter](history.md#the-oracles-that-were-not-looking) is what four gates in two days found | ADR-0342, ADR-0349 – ADR-0354, ADR-0358 |
| Is the memory model the one its records describe? | No, and not in the direction expected: three of a review's four rows closed within two days — the borrow rule's invalidation half is refused where a borrow is *formed*, the fifth warning was measured and retired, and the release walk that ended in a signal is a work list. The fourth, a record's `Drop`, is still open with exactly one asker. [The chapter](history.md#the-memory-model-read-against-the-goal) | ADR-0317 – ADR-0337 |
| What separates this from a language a person picks up on a Tuesday? | Eight rows, every one struck within four days of being written: an archive, a tour, twelve examples, a position in every trap message, a project skeleton, two more server methods, and two claims that were true of every spelling of the command but the one a person types | ADR-0293 – ADR-0308, ADR-0348 |
| Mutation testing, committed to the tree | One file per recorded mutation and a harness that runs them; not a `ctest` case, because it edits the tree. A register of demonstrations and not a measurement | ADR-0207 |
| Is the platform lock scoped? | Three things, two done at once and the third — 32-bit — on 2026-09-05, when the *offsets* turned out to be the wrong measure of it: seven rules, not four | ADR-0155 – ADR-0159, ADR-0325 |
| Is a foreign scalar the width of its C type? | Not by inspection: `time` as `int64` gave the right answer on every host but one CI container, and the mutation putting it back survived. `clong`/`csize` are the answer and `foreign-width` is what holds it, as a catalogue — [the chapter](history.md#the-32-bit-port-and-the-width-it-left) | ADR-0328, ADR-0364 |
| Can a conforming program learn that a file is missing? | `binding(f).bound` says whether it is there | ADR-0172 |
| Can a program get its arguments as a list? | `argcount` and `argument(k)`, required identifiers of the dialect | ADR-0173 |
| Can a foreign address be owned? | A handle-type: a file variable for it, released where a file closes | ADR-0174 |
| What is a character, once a byte is not one? | A grapheme cluster; text is UTF-8 in normal form C, in a value with a byte capacity, and `char` is left alone because it cannot widen | ADR-0189 |
| Should the dialect read a type off a component? | Yes: `type of` takes a whole variable-access, so a generic reads an element type off the container it was handed. The substring is the one access it must refuse, and a *result* type is where the widening stops | ADR-0215 |
| What did version 3 take, and what did it leave? | Four proposals: three became records and the fourth dissolved under the first. The one it left open was `src/` — whether the second front end earned its cost — and §0 answered that by removing the surface it was frozen at. The chapter is in [`doc/history.md`](history.md#version-3--what-it-took-and-what-it-left) | ADR-0229 – ADR-0233 |
| What did the language server demand? | Findings enough that the count is kept in one place and not four — [the chapter as it closed](history.md#the-chapter-as-it-closed), which had said twenty-one where that section said twenty-six. Five were **bounds**, each chosen by counting what the largest thing in the tree needed at the time, and the largest thing in the tree was a test case. All twenty-seven are closed and in [`doc/history.md`](history.md#the-language-servers-findings-as-they-were-recorded); the chapter as it closed, in the same place, keeps the count | ADR-0236 – ADR-0249 |
| Is this a conforming processor or a dialect? | A dialect. `--std` and the two conformance modes are removed, the clause 5.1 a) compliance statement withdrawn, and 25 of 172 ISO 7185 cases became inexpressible — a conforming ISO 7185 program with a field called `value` no longer compiles. Five oracles retired with the surface they asked about. It is what version 3 is named for | ADR-0232 |

## Windows, measured and then dropped

`doc/roadmap.md` carried one row about Windows, and it is here whole rather
than deleted. It was written on 2026-09-09 against a named toolchain and a
named runtime, and it is a **report**: five records measured what compiles,
what links, what runs and what faults, and ADR-0380 then dropped the platform
on 2026-09-10 — not because any of this turned out to be wrong, but because
what remained was a frame-layout change compared across every admitted target,
seven headers of winsock, and a `PasNet` question, for a platform nobody here
runs.

A contributor who wants Windows starts from this row. Everything in it was
measured rather than read, and the commands are in ADR-0374.

| Target | What it needs |
| --- | --- |
| **Windows** — **deferred (ADR-0374)** | **Measured against mingw-w64 rather than read, on 2026-09-09** (Debian's `x86_64-w64-mingw32-gcc` 16-win32, run under wine 10.0), and the row it replaces was wrong in both directions. Reproduce it with `x86_64-w64-mingw32-gcc -std=c11 -O2 -I runtime -c runtime/<unit>.c` — `pasrt_unicode.c` **compiles clean**, which is the whole of AP 6.4.15. What was real and is **closed**: `fmemopen` and `open_memstream`, absent there as in the MSVC CRT — ADR-0370 removed both, §6.7.5.5 needing an auxiliary `text` variable backed by memory and never a `FILE *`, so `pasrt.c` **compiles here** as of ADR-0373 and is three names from ISO C. What is real and **larger than this row said**: `_longjmp`. It is not a spelling. `setjmp(x)` expands to `_setjmp(x)` on glibc and to `_setjmp((x), frame)` on mingw — two arguments, through `__imp__setjmp` — because Win64 unwinds through SEH, and the emitted code calls `_setjmp` with one argument, which is a wrong arity and the class ADR-0121's row says nothing here checks. The signal mask is **not** the difference — the arity is — but it is a real cost, and a measurement first published here said otherwise: calling glibc's `setjmp` *symbol* costs **265.4 ns against `_setjmp`'s 2.4**, a `sigprocmask` syscall, where the earlier figure had compiled both arms to `_setjmp` because the macro expands to it. So emitting `setjmp` is not an available answer. What is left is a target-dependent call, and **it is done** (ADR-0371): `x86_64-w64-windows-gnu` is a fourth admitted target, the emitter writes `_setjmp(env, frame)` there with `llvm.frameaddress` supplying the second, and `setjmp-arity` compares the arity against clang's on every admitted target. `llc -mtriple=x86_64-w64-windows-gnu` assembles the module to COFF and `clang --target=x86_64-w64-mingw32` compiles it to an object whose one undefined symbol is `_setjmp`. **The runtime's half is closed too** (ADR-0373), and `runtime/pasrt.c` **compiles here**. mingw declares `longjmp` and never `_longjmp` — only `_longjmpex` for i386 and `__mingw_longjmp` for arm — and it is not a CRT question, being absent from the msvcrt and the UCRT sysroot alike. No portable spelling exists: `longjmp` after `_setjmp` works on glibc and would restore a mask on Darwin that was never saved. So `pasrt.c` holds **one preprocessor conditional**, the only one in the runtime, and `runtime-isoc` catalogues the set of them in both directions so a second is a decision rather than a habit. The tidier shape — the emitter writing the jump as it already writes `_setjmp` — waits on a reseed, the committed seed declaring and calling `@pas_jump_go`. A mingw-w64 *version* difference stops mattering with it: Ubuntu 24.04's declares `_longjmp` and Debian trixie's v14 does not, which is why the toolchain is pinned, and which no longer decides whether this unit compiles. What is **not**: `access` compiles and links against `<io.h>`, so that was an MSVC-only problem; `_Complex` is declared and implemented for all seven functions `pasrt.c` uses, and a probe built from that block compiles under this tree's own `-pedantic-errors -Werror`, links, runs, and agrees with glibc — `(1+1i)**2` differs in the last bits and mingw is the *more* accurate of the two, which `tests/extended/complex.pas` cannot see at `:6:3` anyway. `timespec_get`/`TIME_UTC` are `#ifdef _UCRT` in mingw's `<time.h>`, so they are a CRT choice and not a gap — **settled on 2026-09-09 against a real UCRT sysroot**, `mingw-w64-ucrt64-dev` having supplied the `include` this row once recorded as missing. Under it `__MSVCRT_VERSION__` is `0xE00` and the headers define `_UCRT` themselves, and `pasrt_task.c` compiles with no `-D` at all. `runtime-nonposix` carries the claim as a `crt _UCRT` row, both directions. **And the weight is somewhere nobody had costed**: `pasrt_posix.c` stops at `netdb.h`, and behind it are `sys/socket.h`, `poll.h`, `spawn.h`, `termios.h`, `sys/wait.h` and `sys/ioctl.h` — winsock2 with its own initialisation and error convention, `WSAPoll` for `poll`, and no `posix_spawn` for `PasProcess.Execute`. Fifteen call sites name a socket primitive. **That was a floor and is now a list** (ADR-0369): `runtime-nonposix` probes each `#include <...>` on its own, so seven come back where the compile reported one — `netdb.h`, `poll.h`, `spawn.h`, `sys/ioctl.h`, `sys/socket.h`, `sys/wait.h`, `termios.h`. **Ten of the seventeen it names are present**: `dirent.h`, `errno.h`, `fcntl.h`, `signal.h`, `stdio.h`, `stdlib.h`, `string.h`, `sys/stat.h`, `time.h`, `unistd.h`. So the directory walk, the file information and the file model are not what is missing — sockets, the terminal and `posix_spawn` are, and `<pthread.h>` is there, so AP 6.4.16's channels do not block a port either. **A program was built and run** under wine 10.0 on 2026-09-09, and that is what settled it: `tests/hello.pas` prints its golden, and `tests/goto_nonlocal` and `tests/goto_files` **fault** — `_setjmp` on Win64 saves XMM6–15 with an aligned `movdqa` and this compiler places the jump record at offset 136, which is 8 mod 16 (`doc/sop.md` §7, proven in isolation). Two more things running found that no compile check could: the runtime must be built by **clang**, mingw-gcc compiling `_Thread_local` to emulated TLS that the emitted module's native TLS cannot link against; and a Windows build writes **CRLF** where a POSIX one writes LF, which ISO 7185 leaves to the processor and which makes the corpus goldens not directly comparable. **So the platform is deferred**: a frame-layout change measured across six targets, plus seven headers and the `PasNet` question, is a body of work rather than a finish. What is kept costs a second a push — the six targets, the two units compiling, `runtime-nonposix` and `setjmp-arity`. Run `python3 tests/checks/runtime_nonposix.py` rather than quoting this |

**What changed on the day it was dropped**, so the row above is not read as
current: `x86_64-w64-windows-gnu` is no longer a target `--target=` admits;
the emitter's second `_setjmp` shape and its `llvm.frameaddress` went with it;
`CLongSize` lost its LLP64 arm; and `runtime/pasrt.c` names `_longjmp`
unconditionally, so it no longer compiles for mingw-w64 and
`nonposix_headers.txt` records that as `blocked` on purpose. The runtime holds
no preprocessor conditional again.

**Struck 2026-09-10 by ADR-0391** — *a row's colour is the first cell's, and
nothing checks that a row is one colour*. It named its own closing condition
(*"it becomes false the moment a panel overlaps a document row… what has to
change then is `PutRow` splitting a row into runs"*), which is ADR-0197's
second shape and the reason it was written down rather than left to whoever
built panels. What closed it is not the split but *where the split went*: done
in the shell it would have been unverifiable, `tui/run.py` linking `apide.pas`
and never running it, so the row would have widened from "a row is one colour"
to "how a row splits is unchecked". `RowRuns`/`RowRun` are the model's, a
session holds them, and the mutation that collapses them fails two goldens.

## WebAssembly, measured and then run

Windows was dropped on 2026-09-10 and `wasm32-wasi` took the slot the same
day. What that bought was not a platform but an **oracle**: the first target
here that is not POSIX and not a machine, and the first behavioural test of
what a program does when the answers cannot be inherited from Linux.

It arrived in four steps, and each corrected the one before it.

**ADR-0382 re-pointed the question.** `runtime-nonposix` had been asking
mingw-w64 whether the runtime's headers were there; the question was never
about Windows, so it asked wasi instead. Two units of the four compile —
`pasrt.c`, which is the language itself, and `pasrt_unicode.c` — and the other
two are blocked by two different kinds of thing: `pasrt_posix.c` by five
headers of seventeen, and `pasrt_task.c` by the target having no threads at
all, which is the whole task facility rather than a header.

**ADR-0383 admitted the target, and corrected a rule that had been wrong since
i386.** `WordAlign` had been answering two questions — what a pointer aligns
to, and what an eight-byte datum aligns to — and got away with it because
i386, the only ILP32 target, answers 4 to both. wasm32 is ILP32 with `i64:64`,
so `WideAlign` came out of it. `target-layout`'s second claim reported four
wrong numbers on the first run the target was admitted, which is exactly what
that claim was built for; a wrong alignment costs no diagnostic anywhere. The
gate's *first* claim then had to stop classing targets by word size — it had
put the two 32-bit targets together and called 337 correct offsets a
divergence.

**ADR-0385 ran the corpus**, which is ADR-0325's lesson one target further on:
both defects the i386 port found were in neither a layout rule nor a frame.
519 of 598 answered their golden. It found two things no other oracle here
could, and both were **wrong answers rather than failures to start** — a 64 KB
default stack that printed stray spaces into the middle of a line, and a
`SOURCE_DATE_EPOCH` that a WASI runtime does not pass on unless it is told to.

**ADR-0390 took the largest single cause.** 52 of the 79 failures were
`tmpfile`, which wasi declares and does not define. The runtime stopped calling
it and built §6.7.5.5's auxiliary file out of two other ISO C functions — C11
7.21.5.3's exclusive `fopen` mode, so composing a name is a retry and not a
race, and 7.21.4.1's `remove` on the open stream, which is `tmpfile`'s contract
exactly. **No preprocessor conditional was added**, so the runtime's catalogue
of them is still empty; the `#ifdef __wasi__` route would have reversed
ADR-0380, which dropped a *target* rather than keep one conditional, and it
would have put a different implementation of the language on wasi from the one
every oracle here tests. Thirteen of the 52 turned out to be behind a second
cause and moved rows rather than passing, which is the half a count hides.

**And the two abstentions are the part worth carrying forward.** Twice the
gate had to learn to say *I cannot take this measurement here* rather than
report a defect:

- **An LLVM that names `i128` for the target.** clang overrides the module's
  own `target datalayout` with its own for the `--target=` it is given
  (ADR-0156), so the two must agree about every modelled field. Debian trixie's
  clang 19 states no `i128:128` for wasm32 and clang 21 does, which aligns an
  i256 to 8 where the compiler computed 16 — a set inside a record laid out two
  ways, which is ADR-0028's own defect. `tests/sets_records.pas`, the case that
  decision exists for, was the single failure in 598 on that image. The CI job
  moved to `debian:testing`, later pinned by digest because `testing` rolls.
- **An engine that resolves a bare filename.** Two cases opened a scratch file
  beside themselves; wasmedge 0.16 answers a null handle where 0.17 answers a
  stream, given the same `--dir /:/`. They sat in the catalogue for a day as a
  limitation of the *port* while CI, on the newer engine, reported them
  passing — and **the gate found it by failing in the direction a catalogue is
  least expected to fail**, refusing to let progress go unrecorded. The fix the
  row proposed for itself was measured and was wrong: granting a preopen named
  `.` makes a relative path resolve and an absolute one stop, trading 27 cases
  for 2. So the gate probes the engine in C and abstains, and the committed
  numbers are one engine's.

**560 of 598 at v3.9.0**, and the 38 that remain are a port's work queue rather
than a defect list. `wasm64-wasi` joined on the layout claim alone (ADR-0386)
and cost nothing: every layout rule already had the arm an LP64 target needs,
so it took the default side of every condition and matched all 11 162 frame
offsets with nothing in the gate edited to admit it.

## The editor, un-withdrawn

`tui/` is the only thing here that was **withdrawn by decision and then
brought back**, and the nine days between are worth recording because the
second decision did not reverse the first.

It was proposed with the dialect's tooling chapter, carried for six increments
as *later, not struck*, and withdrawn on 2026-09-01 — not deferred and not
blocked. The reason recorded was *"the language server is the better tool for
what the IDE was wanted for"*, and that judgement is still true: `pasls`
answers eight questions about a document and is undisturbed.

**What un-withdrew it (ADR-0381) is that the withdrawal had weighed the wrong
thing.** The record itself named what was being given up — a *Pascal-lineage
answer key*, so that "this was easier in Turbo Pascal" becomes a finding rather
than a matter of taste — and under ADR-0109 a program someone actually wants to
write is the test a dialect feature has to pass. The other reason is that this
is a hobby project. Neither is a reason the first argument could weigh, and the
one blocker the withdrawal named — no terminal control — had been removed by
ADR-0262 two days *before* it was written.

**The decision that makes it testable is that the terminal is not in the
loop.** `ApEdit` takes a key as a value and answers a *screen* — rows by
columns with the cursor's cell — and touches no descriptor, so `tui/run.py`
replays a scripted session and diffs what was drawn byte for byte. ADR-0262 had
declined a pseudo-terminal binding on the grounds that a case needing one
becomes a test of the binding, and that argument has now been met three times:
for the drawing, for the prompts, and for `ncurses`.

Four increments in nine days, and each was a design question wearing a
feature's clothes:

- **Milestone one** (ADR-0381): open, edit, save, compile, land on the error.
  The goldens settled three things an argument would not have — that the
  message is about the *last* key, that `Left`/`From` beat `substr` at fourteen
  sites, and that the unknown-key message must carry the byte.
- **Milestone two** (ADR-0387): undo asks *what an edit is*. The buffer had
  been changed in place, so an edit existed only as the difference between two
  strings, which cannot say where the cursor was. An edit became one of four
  operations, and the four routines performing them became the only code that
  touches the buffer — so the journal is complete by construction. A prompt
  became a **mode of the model**, which is what lets a session drive a search.
- **Save-as** (ADR-0388): the editor had started fileless and Ctrl-S then
  advised a restart. Closing that also closed a defect two milestones old — the
  shell had kept a `path` beside the model's name, two copies of one fact, and
  save-as is exactly what makes two copies disagree.
- **Colour** (ADR-0389): `PasTerm` had gained colour *for the editor* and the
  editor could not express any of it, a capability built for a client with no
  way to reach it. A cell carries a **role** and not a colour, so the model
  names no terminal vocabulary, a golden holds `sssss` rather than SGR numbers,
  and a palette change touches no recorded screen. `ncurses` was asked about
  and declined in that record: it owns the screen, so drawing through it makes
  the drawing no longer a value anything can diff.

It ships as `afterschool` at v3.9.0 — a CMake target installed beside
`pascalc`, which is the answer to its own `build.py` header saying a server
needs a binary a *person* runs rather than one buried in a build tree.

## The editor's third increment, and three gates that were pointed too narrowly

The v3.10.0 release put display width, eight documents, horizontal scrolling
and a twenty-four-bit palette into `tui/` in one day. What followed was mostly
a reckoning with that speed, and the shape it took is worth keeping, because
the same thing went wrong three times in three different places.

**A question that was complete became incomplete when what it asks about grew
a second instance, and nothing changed at the moment it stopped being right.**

- **Quitting asked `EditDirty`** (ADR-0401), which answers about the document
  being *drawn*. Before ADR-0396 that was the whole editor. Afterwards it was
  a silent loss of work: type into `a.pas`, open a clean `b.pas` over it,
  press Ctrl-Q **once**, and the editor exits with no prompt, no message and
  status 0. ADR-0396's own consequences had recorded it as a gap — *quitting
  still asks about the document on screen only* — which undersold it by a
  wide margin, and the sentence is why nobody looked again. Measured under a
  pseudo-terminal rather than reasoned about.
- **`MenuKey` dispatched over `KeyKind` with a `case` and no `otherwise`**,
  which is the right shape — §6.9.3.5 makes an unmatched selector a trap, so a
  kind added later is a reported crash and not a swallowed key. ADR-0396 added
  `kkOpen` and `kkNextDoc` and did not revisit the arm, so F3 or F6 with the
  menu open stopped the shipped editor with `case: no label matches the
  selector`. Found by a probe while wiring a *different* key into the same
  tables.
- **`runtime/pasrt_posix.c` was one translation unit** holding everything
  needing a POSIX type, and `wasm32_known.txt` carried sixteen corpus cases
  under a heading that said `directories` (ADR-0405). The target has a
  perfectly good file system; `PasFs.Info`, `PasDir`'s walk and
  `PasIo.FdReady` were blocked by nothing but sharing a file with
  `posix_spawn`.

Each was correct as written. What the three have in common is that **no gate
could see any of them**, and two of the three had a gate that could have.

`kind-exhaustive` asks exactly the `MenuKey` question and answers it correctly
about any Pascal program — and had been handed the compiler's three components
and nothing else for the whole of its life (ADR-0404). Its corpus was a line
of code, so it stopped growing when the tree did. It sweeps five programs now,
and widening it moved 63 case-statements over 13 enumerations to 79 over 35.
Twelve sites and constants needed an argument and none of them was a defect;
**the defect was the commit before**, which is the evidence for the widening
rather than an absence of it.

`doc/sop.md` §7's oldest open row was the other. ADR-0389 split a cell's role
from its colour, ADR-0391 had `PutRow` split a row into runs, both promised a
register row and neither wrote one, and ADR-0393 closed the half that needed
no terminal. What was left is stated by a mutation: make `PutRow` take the
first run's role for the whole row — ADR-0391's own pre-state, and what the
comment in `Draw` still claimed was true — and twenty-one sessions and both
halves of the palette gate stay green. A shell painting a framed dialog in one
flat colour passed every oracle this project had. `tui/terminal.py` closes it
(ADR-0402) by driving the real editor under a pseudo-terminal, and two things
about how are the record: it is **not** the binding ADR-0262 declined twice,
the pseudo-terminal being Python's as `lsp/run.py`'s pipe is; and the
expectation is **derived** from the session golden's own run decomposition
rather than recorded, a golden of escape bytes being one that agrees with
whoever wrote it — which is exactly how `crPrompt` came to be drawn on no
screen at all.

**Replace was the increment's actual feature** and it needed the model to grow
(ADR-0403). ADR-0387 made an edit one of four operations with one journal
entry each, and had no notion of an *action* — a thing a person did — getting
away with it because every key a person presses is one operation. A
replacement is two and a replace-all is a great many. An entry may now say
`more`, which is a property of an entry and not a fifth operation, so the four
routines are still the only code that touches the buffer. Confirm-each was
**rejected rather than deferred**: what a person wants after a replace that
went wrong is to undo it, and an editor that can do that in one keystroke need
not have asked six times first.

Two defects were found by reading a CI failure instead of retrying it.

**A case ran in the invoker's working directory** and not its own (ADR-0406).
`CLAUDE.md` rests the parallel suite on *each harness works in a directory it
created for the run*, which was true of a harness's scratch files and false of
the program under test — started with no `cwd` at all. It costs nothing for
almost every case, the two scratch paths arriving as absolute arguments;
`lib_process_execute.pas` is the one that names a file relatively, and its own
closing comment had noticed half of it. The cleanup that keeps the tree clean
is also the race: two copies of the program in one directory, one `rm`ing
`victim.txt` while the other opens it. Eight failures in twenty concurrent
pairs before, none after. `doc/sop.md` §7's row about it had ended with the
words *every local parallel run now exercises it* — a row naming its own
closing condition, and wrong, which is the shape that register warns about
most and had not previously been caught doing real damage.

**A UTF-8 character may be split across two reads of a pseudo-terminal**, and
macOS found it where Linux did not: the new harness decoded each `os.read`
with `surrogateescape`, so a three-byte box character arriving in two pieces
became six escapes that never rejoined. A property of how the pty buffers and
not of anything either program did. Proved fixed by reading one byte at a
time, which splits every multi-byte character in the corpus.

## The roadmap, compacted again on 2026-09-11

[`doc/roadmap.md`](roadmap.md) says of itself that it is kept to what is open,
and four days after the cut of 2026-09-07 it had drifted again — not by
acquiring open rows but by keeping the narrative of rows as they closed. The
four chapters below are that narrative, moved here whole rather than deleted,
which is the same disposal the Windows row got.

### The Rust-flavoured map, as it stood

The memory model was reviewed against *a Rust-flavoured Pascal* on 2026-09-04
and the review's table stood on the roadmap until every row of it had an
answer. What each row routes to is the finding — three of the nine came from
Pascal's own 1982 vocabulary rather than from Rust, and only the last row is
still a sentence about something absent.

| Rust | Here | Route |
| --- | --- | --- |
| `Box<T>` | `owned ^T` (AP 6.4.14) | from the file variable, not from Rust (ADR-0181) |
| `Drop`, RAII | scope-based release | present since 1982, named by ADR-0151 |
| a move | `take` (AP 6.4.14.6, 6.4.12.7) | forced by writing `PasList` (ADR-0182, ADR-0267) |
| `&mut T` | a `var` parameter bound to `o^` | *unformable* rather than checked (ADR-0201) |
| `&T` | `protected var`, over an owned pointer too | ISO's own word (ADR-0283, ADR-0318) |
| `Option<T>`, `Result<T, E>`, `?` | `?T`, `T ! E`, `try` | ADR-0123, ADR-0176, ADR-0178 |
| `&[T]` | `array of T` | ADR-0125 |
| `Send`, channels | `task`, `channel [n] of T` | ADR-0268 |
| traits | `trait` / `impl … for`, as a bound | ADR-0338 – ADR-0341 |
| lifetimes, `Rc`, `RefCell`, `unsafe` | **absent** | three sentences, which are what the roadmap keeps |

### The macOS row, as it closed

macOS became a job that can fail on 2026-09-09 (ADR-0368), with 904 of the 912
cases of that day running and passing on arm64, `SANITIZE_REQUIRE` and
`UNICODE_CONFORMANCE_REQUIRE` set, and the remaining `*_REQUIRE` variables
naming tools the hosted runner has not got.

**Ten skips became nine, and two of the ten were not facts about macOS at
all.** `verify-lowering` skipped because z3 had been installed with `--user`,
which Homebrew's externally-managed Python refuses, and the step swallowed its
own failure — so the SMT rules had never run there at all; `unicode-conformance`
skipped because that job did not fetch the database. Both closed in `d8d925d`,
which is what makes the remaining list homogeneous, and the second bought a
reading the tree had never had: `runtime/pasrt_unicode.c` compiling under
`-pedantic-errors -Werror` on Apple clang with the committed tables regenerated
on a second platform. ADR-0369 then added a gate wanting a cross compiler this
runner has not got, which is why the count did not fall further.

**`--target=` admits both Darwin triples since ADR-0372**, so a module built
there names the machine it is for rather than relying on clang to override the
header — and `setjmp-arity` stopped skipping on that runner with them, the host
target having become comparable.

**The release leg is what closed the row** (ADR-0375): a `v*` tag ships an
`arm64-darwin` archive beside the two Linux ones. Apple has no static libc, so
that leg configures `APASCAL_STATIC_PASCALC=OFF` and does not set
`RELEASE_REQUIRE_STATIC`; what it asserts instead is a claim macOS can answer
and `ldd` never could — that the binary depends on nothing outside `/usr/lib`
and `/System`, which `otool -L` reports and every hosted runner's Homebrew
makes worth asking. It ran for the first time at `v3.8.0`. Nine failures got it
there and **not one was in the compiler** — every one was a harness assuming
Linux ([above](#the-first-macos-run)).

### wasm64, and what admitting it cost

`wasm64-wasi` is the seventh target (ADR-0386) — WebAssembly's memory64,
admitted on the layout claim alone, because no sysroot for it exists and there
is therefore nothing else to ask. It landed in a class with x86-64, aarch64 and
both Darwin triples, every frame offset matched theirs, and it cost **nothing**
in the layout rules: ADR-0325's generalisation spent a third time, and the first
time free. Nothing in `target-layout` was edited to admit it, which is the
claim the gate was built to make.

`wasm32-wasi`, admitted the same day (ADR-0383), paid for itself immediately in
the other direction: `target-layout` reported four wrong numbers on its first
run, `WordAlign` having answered two questions that i386 gave one answer to.

### What a helper is written in, and the one it left

The rule is ADR-0366's and the lint is ADR-0367's; what stood on the roadmap
was the argument, and it is worth keeping because the argument is what makes it
a decision rather than a preference.

**The portability boundary is the set of external programs a helper invokes,
not the language.** A Python script that runs `nm` is exactly as unportable as
a shell script that runs `sed`, which is what two of the nine macOS failures
were. So a harness is Python 3 *and* reaches for the standard library rather
than a subprocess — `pathlib`, `tempfile`, `difflib`, `re` in place of `find`,
`mktemp`, `diff`, `sed`. Invoking the toolchain is not what that forbids;
invoking a general-purpose Unix utility to do what the language can do is.

**A helper that ships to a user is written in Afterschool Pascal; a gate is
written in Python.** A gate must be able to fail *because the compiler is
broken*, so it cannot be written in the language under test. A shipped helper
has the opposite constraint, and the one thing present on the user's machine is
the compiler and runtime just installed there — `bin/apconfig` is the precedent
(ADR-0361).

**Nothing was converted wholesale, and a conversion is checkable.** These
scripts *are* this project's evidence, so a rewrite lands with two things and
neither is a green suite: byte-identical output from both versions on the
current tree, and that gate's own historical mutation re-run against the new
version, failing the same way. Thirty-one conversions carried it out.

**Why it was a decision**: macOS is a platform where a shell script *runs* and
differs in detail. Windows was one where there is no bash, no `sed`, no `nm`
and no `#!` line, so all 31 scripts did not run at all — each a blocker rather
than a bug, and a rule that converts them only when they are being edited never
reaches the stable ones. The collision the record named and left open is the
driver: `tools/pascalcc` is the product rather than a harness, and the decision
that it stays a shell script could not stand beside the Windows row. **Windows
was dropped on 2026-09-10** (ADR-0380), which settled that collision by
removing one side of it rather than by answering it — so the catalogue is still
one line of shell, and a target that is not POSIX is where the question comes
back.

### The proof ADR-0315 asked for, on 2026-09-12

ADR-0315 left one thing open: **rewrite a library module with methods and judge
the rest of the library from the result**. ADR-0410 built the construct,
ADR-0411 made an implementation cross a program-component, and both were
designed against probes and a corpus of purpose-written cases.
`lib/dialect/pasjson.pas` was the first real client, and it did not compile.

**Why it was the right module, and why nothing before it could have found
this.** PasJson has two types with routines — `JsonChars` and `JsonPtr` — and
they share three names: `Free`, `Len` and `At`. That is not an accident of
naming; it is the reason ADR-0315 wanted methods, §6.11.2 putting every
exported name into one scope so that two exported `Free`s cannot coexist. No
case in `tests/dialect/methods.pas` had two types with routines of one
spelling, because the person who wrote the corpus was the person who had just
designed the feature, and the shape did not occur to them.

Four defects, and each needed something the corpus did not have:

- **A name in scope shadowed the receiver.** AP 6.7.10.2 identified a routine
  from the first actual's type only where the identifier had *no defining-point
  in force* — right for `Len(x)` and wrong for `x.Len`. Inside `impl JsonPtr`'s
  own `Free`, `v^.text.Free` bound to `JsonPtr`'s `Free` and was refused on its
  argument type, one line after the routine it should have called. This is the
  one that is a *language* decision rather than a slip, and ADR-0412 takes it:
  the receiver decides, always.
- **A parameterless method statement took only a bare-name receiver.**
  `b.Free` was a statement; `v^.text.Free` and `arr[1].Free` were
  `expected ':=' in an assignment` — a message about an assignment nobody
  wrote.
- **A chain was not a statement.** `a.M(x).N(y);` parsed as an expression and
  the qualified-name path consumed `a.M(x)`, leaving `.N(y)` belonging to
  nothing.
- **A designator's type was not found in a variant part.** `QuietTypeOf`
  carried its own copy of `FindField` that walked the fixed field list only, so
  `v^.text` answered no type. A fact stated twice, and it disagreed with itself.

**And a fifth that is not about methods at all.** §6.9.4 b)'s threat never
reached a formal produced from a schema, so `protected var s: string` could be
passed to another routine's `var s: string` and written through there — §6.5.1's
protection defeated with no diagnostic — while ADR-0283's advice, which is
supposed to name *exactly* the condition under which adding the word still
compiles, was offered for parameters that could not take it. One missing call
with two faces. It had survived since ADR-0283 because that advice is never
given about an **exported** routine and every routine of the shape in this tree
was exported. A method is exported by nothing (AP 6.7.10.5), so PasJson's
`TextInto` was the first to be judged, and it was judged wrongly.
`tests/extended/schema_param.warn` lost two lines and
`tests/dialect/lib_unicode.warn` was deleted; each was checked by taking the
advice and watching the compiler refuse it.

**What the rewrite bought, measured.** The module exports 25 names where it
exported 50, and 540 call sites across eleven sources changed —
`JsonIntegerOr(JsonMember(p, 'line'), -1)` became
`p.Member('line').IntegerOr(-1)`, which is the dominant idiom of an LSP server
and 332 of those sites. Chaining is what made it a readability win rather than
a rename: a method-designator may be the receiver of another, which had always
worked and which AP 6.7.10.4 had not admitted, a function-designator being no
variable-access.

**The lesson is `doc/sop.md` §4a's, for the fourth time and by its largest
margin**: the library or binding for a feature is part of that feature's work
and not a tidying-up afterwards, because it is the cheapest enumerator of the
surface. The register gained the row that says no gate here can notice a thin
corpus, the corpus being what every gate measures against.

**The second library cost what a decided feature should, and that is the
result.** `PasToml` was rewritten the same way: 31 exported names where there
were 59, `doc.Path('server.port').IntegerOr(80)` where there was
`TomlIntegerOr(TomlPath(doc, 'server.port'), 80)`, and four clients —
`tools/apconfig.pas` among them, so the change reaches a program the build
installs. It found **no compiler defect and no clause to amend**. What it found
was two name clashes the compiler named on the first compile: the method `Path`
and its own parameter `path` are one name under §6.1.2, and a method must be
declared before it is used (§6.2.2.9), so the scanner moved above the renderer
that needs its `BareChar`. The three TOML cases answer their goldens unchanged,
which is the whole claim a refactor of this size can make, and two mutations
say the two `At`s are separately reached: an off-by-one in `TomlChars.At` moves
the byte readers and the rendered strings, and one in `TomlPtr.At` moves
`list=`, `nest[1][2]=` and `fruit[2].name=`, in the one case.

**A number moved for a reason worth writing down.** `lib-coverage` reports
`pastoml.pas` at 921 instrumented statements where it reported 928, and the
module's own statements did not change: the denominator is a set of *line
numbers*, `PasContainer`'s generic bodies are emitted in this translation
(AP 6.7.3.5) carrying their own file's line numbers, and 7 more of them now
collide with a line this module has a statement on. 928 − 14 = 921 − 7 = 914
both ways. It is the first time that artefact has moved a ratchet here, and it
is a property of the gate rather than of the module.

**What the two rewrites together say about the rest of the library.** The
method-shaped surface was measured — exported routines whose first parameter is
a type the module exports — and PasToml had the largest, 29 of 59, of which 28
became methods and `TomlParseChars` did not, a parse answering a document
rather than being an operation of a buffer. Next are
`lib/passtrvec.pas` (14 of 19), `lib/dialect/pasprocess.pas` (13 of 22),
`lib/dialect/pasregex.pas` (12 of 31), `lib/dialect/pashttp.pas` (12 of 38),
`lib/pasvector.pas` (12 of 15) and `lib/pasmap.pas` (11 of 16); `PasHttp` is
the urgent one, its `Header`, `HeaderOr`, `AddHeader` and `SetBody` being
*already* unprefixed in §6.11.2's one scope. `lib/dialect/pastime.pas` (2 of
35), `pasterm.pas` (1 of 29) and `pascontainer.pas` (0 of 31) have no receiver
to select from and are not candidates. Three probes settled what a reading
could not: a **handle** type carries an implementation, with a `var` or a
`protected var` receiver — a handle is protectable where a pointer is not — so
`PasProcess`, `PasNet`, `PasTls` and `PasFile` can have methods; a **required**
type carries one too, `impl TimeStamp` compiling and `t.Yr` answering; and
**two modules cannot both implement one type if a translation sees both**,
which is the reason a module must not give methods to a type it does not own.
That last one is a divergence not yet recorded: AP 6.7.10 says *at most one
inherent-implementation in a program-component* and the compiler enforces *at
most one visible in a translation*, refusing the second component even where it
does not import the first.

**Eight more modules, three of them at once, and the batch is what found the
rules.** `PasVector`, `PasMap`, `PasStrVec`, `PasRegex`, `PasProcess`,
`PasNet`, `PasTls` and `PasHttp` were converted in three independent passes.
With `PasJson` and `PasToml` the ten now export **157 names where they exported
284**, and the collisions §6.11.2 would have refused are the point of the
count: `Free`, `Len`, `At`, `Get`, `Put` and `Count` are spelled the same way in
every container here, and `Close`, `WriteText`, `WriteLine` and `ReadLine` the
same way on a socket and on a TLS connection.

**Five things stop a name simply losing its prefix**, and the compiler said so
each time rather than a convention being remembered. A **word-symbol** cannot
be a method name, so `IVecSet` and `SVecSet` are `Put` and `BeginRequest` and
`BeginResponse` are `BeginWrite` and `BeginRead`. A method and a **field** of
the receiver's record are one name — not just a method and a parameter, which
was PasToml's lesson — so `RegexFaultOf`, `RegexGroups` and `RegexSteps` are
`FaultOf`, `GroupCount` and `StepCount`. A receiver nothing writes through
wants `protected var`, and **ceasing to export a routine is what exposes
that**: ADR-0283 defers the advice for an exported routine, so nine receivers
and four client parameters took the word and `warning-free` would have failed
without it — a fixed point, as that record says. An **enumerated type can carry
an implementation**, probed, so `RegexFaultText` is `RegexFault`'s own `Text`.
And a **schema** cannot, there being nothing to select from until a discriminant
is chosen, which is why `NetWait` keeps its name.

**The fifth was a defect in the language, and it is the increment's finding.**
`lib/pasfile.pas` looked like the third-best candidate — nine of fourteen
exported names take a `FilePath` first — and `FilePath` is `string(255)`, a
production of 6.4.7's schema, which that clause **interns by its tuple**. So
`PasFile.FilePath` *is* `PasStrVec.StrItem`, *is* `PasJson.JsonName`, *is* every
`string(255)` anyone declares. An implementation for it would have handed ten
file routines to all of them, claimed by whichever component was translated
first, and a second module wanting one could not have had it. AP 6.7.10 refused
a schema and a subrange and said nothing about a production; it now refuses one
for the **inherent** form, and `tests/dialect/methods_errors.pas` holds the
refusal. The **trait** form is deliberately untouched — `impl Sortable for Name`
over a string-type of one's own is what that facility exists for, and
`traits.pas`, `lib_sortx` and `lib_container` all do it. The first attempt
refused both and broke those three cases, which is the mutation written down:
widen the refusal to the trait form and they fail while `methods_errors` still
passes.

**And the ownership rule turned out not to be one.** The plan for the network
batch assumed a module may not implement a type another module owns; probing
found that it may, and that the implementation is reachable from a client that
never asked for it. What is refused is a **second** implementation — so
`PasHttp`'s `Send`, `Receive` and `Exchange` and `PasHttps`'s three routines
keep their exported names because `PasNet` and `PasTls` implement `Socket` and
`Connection` themselves, and not because those modules own them. ADR-0413 is
that distinction: AP 6.7.10's *at most one in a program-component* was too
narrow to be a rule about meaning once ADR-0411 made an implementation reach a
module's clients, the clause now says *in a program*, and Annex E.15 records
that the processor enforces the stricter *visible in this translation* —
refusing a component whose sibling implements the same type though neither
imports the other.

**`tests/run_test.py` could not state any of that.** It bailed with a message
of its own when one of §6.13's components failed to translate and compared
nothing, so the one refusal that can only happen while translating a component
had no golden anywhere. It now compares against the case's `.err` when there is
one, `tests/dialect/impl_two_modules.pas` is the case, and reverting the harness
change is what makes it fail.

**What is left.** `PasFile` and `PasTime` (2 of 35), `PasTerm` (1 of 29) and
`PasContainer` (0 of 31, generic) are not candidates and now each have a reason
rather than a measurement. `PasNet.NetService` is the one judgement call left
open: its first parameter is a `Socket` and by the receiver test it is a method,
and it keeps its name because it answers for the socket's identity in the system
beside `NetAccept`.

**`NetService` and `PasContainer`, which are the two the batch left open.**
The first was a judgement call and went the way the rule says: `s.Service(port)`
takes a socket that already exists and asks it about itself, so it is a method,
and that its answer is about the socket's identity in the system rather than
about the stream of bytes through it is a fact about the *answer* and not about
how the routine is reached. `PasNet` exports 9 names where it exported 14, and
the receiver took `protected var` on the first compile — ADR-0283's fixed point
for the eleventh time in three days.

**`PasContainer` cannot be converted, and that is the facility rather than an
omission.** Two probes settle it. `impl Vec` is refused — *'vec' is not a type,
so it can have no routines of its own* — because `Vec` and `Map` are schemata
and there is nothing for AP 6.7.10.2 to select from until a discriminant is
chosen. And every routine is generic over the **pointer** type, declared
`VecPush(Ptr: type; var v: Ptr; …)`, so AP 6.7.10.4 would bind the receiver to
a parameter that wants a type: writing such a method and calling it through a
receiver gives *this argument of 'count' must name a type, because the parameter
it matches is declared 'type'*.

What it is instead is the **substrate** the converted containers call into.
`PasJson` declares `JsonChars = ^Vec(char)` and gives *that* an implementation
whose nine methods call `VecPush`, `VecLen` and the rest; `PasToml`,
`PasStrVec`, `PasVector` and `PasMap` do the same over their own pointer types.
Two probes found the rest of the shape: a **type-parameter may follow the
receiver**, so `function Count(var b: BoxPtr; Elem: type)` is reached as
`p.Count(char)`; and `type of b^.a[1]` takes the element type from the
receiver's own domain, so `procedure Push(var b: BoxPtr; x: type of b^.a[1])`
is reached as `p.Push('z')` with no type argument written at all. A module that
has a concrete type can therefore have methods that are generic in everything
but the receiver.

**And a claim in a source comment turned out to be false**, which is
`doc/sop.md` §4b caught by its own rule. `lib/dialect/pastoml.pas` said
`TomlChars` *is* the type `PasJson` calls `JsonChars`, 6.4.7 interning a schema
production per tuple, so a program holding both might pass one where the other
is asked for. A program importing both modules compiles and runs — each
buffer's methods dispatch to its own module — and the assignment is refused:
`cannot assign jsonchars to a variable of type tomlchars`. 6.4.7 interns the
*production* `Vec(char)`, so the two pointers share a domain; the pointer types
are two objects and ADR-0017's name equivalence keeps them apart. That is also
what lets each module carry an implementation for its own buffer without
meeting ADR-0413's one-implementation rule: one type, one implementation, and
these are two types.

**The library's method conversion is closed, and two of the three answers are
refusals.** Discussing what was left found that the 23 unconverted modules fall
into four groups, and that measuring them was worth more than converting them.

**The text and path modules keep their prefixes, by decision.** `PasStrings`
(10 of 10 receiver-shaped), `PasFile` (10), `PasFS` (9), `PasText` (8),
`PasEnv` (5), `PasParse` (2) and `PasIO` (2) are the most method-shaped surface
left in the library, and every one of them is refused by ADR-0413 because its
receiver is a `string(N)` or a `Fallible` production. That is not a limitation
to route around: **`string(255)` is a capacity and not an abstraction**.
`PasFile.FilePath`, `PasStrVec.StrItem` and `PasJson.JsonName` are all
`string(255)` and 6.4.7 makes them one type, so `impl FilePath` would put path
routines on a string-vector item and on every 255-character string a client
declares -- and would refuse that client an implementation for a
`Name = string(255)` of its own, from a library it merely imported. What would
change the answer is a **nominal type over a production**, which this language
has not got and which needs a reason of its own under ADR-0109. Recorded in
`lib/dialect/README.md` as settled rather than left open, so that the next
person to notice `s.TrimAll` is missing finds the argument instead of the gap.

**An alias was the hole nobody had looked for**, and ADR-0414 is what closed
it. The probes that found it are in that record; what is worth carrying is that
the **first rule written for it was wrong and the corpus said so in one run**.
Refusing every identifier whose definition does not *create* a type also
refuses `impl integer`, which ADR-0315 admitted on purpose and
`tests/dialect/methods.pas` has pinned ever since. The real distinction is
narrower than ownership: `impl Day` conceals what it claims, where
`impl integer` states it.

**Four modules were converted and the other nineteen have reasons.** `PasList`
(10 of 13, an owned pointer), `PasStream` (8 of 11, a handle), `PasLsp` (4 of
10, a record) and `PasDir` (3 of 7, a handle). Of the rest: seven are the
string group above; `PasTerm` and `PasUnicode` have subrange receivers
(`Colour = clBlack..clDefault`, `Scalar = 0..ScalarMax`) and a subrange takes
its host's implementation; `PasTime`'s `DayNumber = integer` is ADR-0414's own
case; `PasContainer` and `PasSortX` are generic and `PasContainer` is the
substrate the converted containers call into; and `PasMath`, `PasMathX`,
`PasOS`, `PasSort` and `PasHttps` have no receiver of their own making at all.
Every one of the nineteen now has a probed reason rather than a measurement,
which is the difference between a list and an argument.

**The four convertible modules, and what converting them found.** `PasList`
went 13 exported names to 3, `PasStream` 11 to 6, `PasLsp` 10 to 7 and `PasDir`
7 to 5; with the ten before them, fourteen modules export **177 names where
they exported 325**. `PasList` keeps no constructor at all -- a fresh variable
of an `owned ^` is an empty list already, which is the point of the form -- and
a `Stream`, a `Socket` and a TLS `Connection` now answer `WriteText`,
`WriteLine`, `ReadLine` and `Close` to the same four spellings.

Three of the measurements that chose them were wrong in the same direction, and
reading the sources is what caught it: *receiver-shaped* counted routines whose
first parameter is a type the module exports, and a routine that takes its
`Stream` or `Dir` as somewhere to **put** an answer is not a method.
`PasStream`'s three `StreamOpen`s, `PasDir`'s `OpenDir` and `PasLsp`'s
`LspOpen` are producers; `PasDir.ListDir` takes a `PathName` and was never a
candidate at all. The count that matters is not how many routines mention the
type but how many ask one about itself.

**A hazard in the rewriting script, for whoever reuses it.** Applying the
call-site rewriter to a fixed point double-rewrites a name that maps to itself:
`NextEntry(walk, nm)` became `walk.NextEntry(nm)` and then `walk.nm.NextEntry`.
It was caught reading the diff, not by a compile -- both spellings parse. A
mapping whose old and new spelling are the same needs one pass, not a fixed
point.

**`lib-coverage` moved again, and the measurement that settles it is better
than the one used before.** `paslsp.pas` reported 147 instrumented statements
and now reports 149. Counting the emitted counters rather than the distinct
lines answers it outright: **181 `pas_cov_hit` calls before and 181 after**, so
the module emits exactly the statements it did. What moved is the *distinct
line* count, because the file grew nineteen lines and two line numbers
belonging to generic bodies emitted in this translation (AP 6.7.3.5) stopped
falling beyond the end of the file. The gate's denominator is a set of line
numbers and a generic's lines are another file's; counting counters is immune
to it, and is what a future comparison should use.

**And a defect in the construct itself, found by writing a linked list.**
Inside an implementation, a method may be reached through a receiver in three
spellings, and one of the three cannot name the method currently being
declared:

| spelling | itself | an earlier method | a later method |
| --- | --- | --- | --- |
| statement, parameterless -- `l^.next.Bump` | works | works | refused |
| expression, with arguments -- `l^.next.Deep(n)` | works | works | refused |
| expression, parameterless -- `l^.next.Len` | **refused** | works | refused |

The ordering column is §6.2.2.9 and is right everywhere. The first column is
not: the same recursion is admitted as a statement and as a call with
arguments, and refused as a parameterless expression with `cannot select a
field of a value of type link, and no routine of that name is implemented for
it`. That is ADR-0410's three shapes again -- the husk, the qualified name and
the parser's with-arguments form -- and ADR-0412's lesson, that every one of
them has to be taught the same fact, reaching a fifth place. `PasList` is
written around it: inside an implementation a method's own name is in scope, so
`Len(l^.next)` compiles and is what the module uses. **Open, not decided.**

**And the defect the previous section left open was fixed the same day.** A
routine joined its implementation's list **after** its body had been checked,
so `MethodSym` could not answer for the routine being declared. The two
spellings that nevertheless worked did so by accident: `CheckCall` and
`CheckStmt` look the identifier up in the scope first, and §6.2.2.9 puts a
routine's own name in scope in its body, so the recursion resolved through the
scope while `MethodSym` answered nil. The husk asks `MethodSym` and nothing
else, so it was the one spelling reporting what was actually true.

Swapping the two lines is the whole fix, and the loop is the right place for it
rather than a pass that registers everything first: it appends one routine at a
time, so a *later* method is still not in the list while an earlier body is
checked, and §6.2.2.9's order goes on deciding. AP 6.7.10.4 gained NOTE 17a
saying so, because a method-designator reaches a routine by the receiver's
**type** rather than by the scope and could otherwise be read as making a whole
implementation available at once.

What is worth carrying is that the fix also removed the accident. The three
spellings now agree because they are told the same thing, not because two of
them had a second way to find out -- which is the difference between ADR-0412's
lesson being applied and being got away with. The register's row lasted one
commit.
