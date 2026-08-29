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
| [The dialect, increment by increment](#the-dialect-increment-by-increment) | thirty of them, [indexed](#the-increments-at-a-glance) |
| [What the roadmap answered](#what-the-roadmap-answered) | the questions that page carried and closed, and what each found on its first run |
| [Cross-platform support](#cross-platform-support-measured) | what the x86-64 lock turned out to be, measured over twenty-five targets |
| [The text model](#the-text-model) | AP 6.4.15 in four increments, and where its oracle story ends |
| [The oracles turned on themselves](#the-oracles-turned-on-themselves) | eight gates that check another gate's blind spot, five of them checking a *document* |

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

### The increments at a glance

Thirty so far. What each one *is*, for someone who wants to use it, is in
[README's "What it adds so far"](../README.md#what-it-adds-so-far); the
sections below are why each was built in that order and what building it
found. Nine of the thirty — 1, 2, 4, 11, 12, 13, 23, 26 and 27 — are library
work rather than language work, and several of those found a compiler defect
nothing else in the tree could reach, which is a theme the sections return
to. One of the thirty, 24, built nothing at all: it is here because it is the
last word on the question ADR-0151 deferred, and because withdrawing a
question is a thing that happens to a language and has to be recorded
somewhere.

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
[the roadmap](roadmap.md#what-blocks-the-library) is not solved — an FFI is
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

The roadmap's cross-platform chapter keeps what is still open — 32-bit, and
the small specific things — and a summary of what the lock turned out to be.
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
moved out of `doc/roadmap.md` as each entry closed — fifteen of the
twenty-one, each with what closing it found. Six are still open and stay
there; a finding recorded and left is a finding wasted, which is what the
register is for.

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

The shape of the whole list is the argument for the chapter. **Five of the
twenty-one are bounds** — 8 imports, 24 arguments, a 63-character key, a
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
element type, because they *return* it and §6.7.1 makes a result-type a
`type-name`:

```
result-type = type-name .
```

So `function VecGet(…): type of v^.a[1]` is unwritable in the dialect too. That
is a second production and wants the same argument made again about a different
clause; it is not carried here as an open question, because nothing is waiting
on it — the two-parameter form works and reads fine.

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

