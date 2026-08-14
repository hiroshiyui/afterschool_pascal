# Roadmap

Where the compiler is, how it got there, and what is deliberately not being
done yet.

**The bootstrap has closed** — the compiler compiles itself and stage 2 equals
stage 3 — so the question this file used to answer, what is left before it can
compile itself, is answered. What it tracks now is the second standard.

Two orderings, and the second replaced the first. During the bootstrap it was
not ISO 7185's chapter order but the order a *compiler* needs its features in:
procedures, then the data structures an AST is made of, then the I/O that reads
source and writes IR (ADR-0004). That priority expired when the language
finished being a means to an end: since then a feature needs no reason beyond
the standard having it, ISO 7185 was completed on those grounds, and
ISO/IEC 10206:1991 is being worked through the same way.

**Where things are.** Everything above "What is next" is now history: both
standards are complete, the sweeps have been run, and the bootstrap stands on
its own. The live work is that last section, and most of it is not about the
language.

- [The three-stage build](#the-three-stage-build)
- [The six bootstrap items](#the-six-bootstrap-items-all-done) — with
  [text files](#item-5--text-files-done) and
  [character strings](#item-6--character-strings-decided) written out
- [Stage 1](#stage-1-done) — the port, and
  [what it taught](#what-the-port-taught)
- [Known limitations](#known-limitations) —
  [ISO 7185](#under-iso-7185) and
  [ISO/IEC 10206:1991](#under-isoiec-102061991)
- [Beyond self-hosting](#beyond-self-hosting) —
  [what ISO 7185 had left](#what-iso-7185-had-left)
- [Stage 2 — ISO/IEC 10206:1991](#stage-2--isoiec-102061991) —
  [how it arrives](#how-the-second-standard-arrives),
  [the features](#the-features-in-the-order-they-landed),
  [what is left](#what-is-left)
- [Conformance sweeps](#conformance-sweeps) — what was checked rather than
  asserted, and what that found
- [The two things that were not features](#the-two-things-that-were-not-features)
- [What is next](#what-is-next) — the oracle that was given up, and the five
  other things worth doing

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

Alongside the language, 435 ctest cases — the Pascal programs of `tests/` and
`tests/extended/`, the error-path corpus of `selfhost/badparse/` and
`selfhost/badsema/`, the verification run, the bootstrap and the product check —
and 43 SMT rules, 27 of them for all 2³² inputs and 16 at bounded
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

## Known limitations

Things that are wrong or absent today, listed so they are not rediscovered as
surprises.

### Under ISO 7185

- **Nesting deeper than 1000 levels is rejected** (ADR-0020). The limit bounds
  the *tree*, not the parser's call depth — the distinction matters because a
  30 000-term `a+b+c+...` chain parses iteratively and used to segfault in
  *Sema*, two stages after the parser survived it. The bound protects all four
  recursive walkers (parser, Sema, CodeGen, the AST destructor) with an order
  of magnitude of headroom against the tightest measured crash point, ~19 000
  levels on an 8 MiB stack. The cost: legal machine-generated programs with
  chains beyond 1000 terms are refused.
- **A variable created by `new(p, c1, ..., cn)` may still be assigned or
  passed.** ISO 7185 §6.6.5.3 forbids it, because the unselected variants do
  not exist; detecting it needs the pointer's *value* to carry which form
  created it, and nothing tracks that (ADR-0027). Permissive where the standard
  is restrictive, like the use-after-dispose gap below.
- **Use-after-dispose through a second pointer is undetected.** `dispose(p)`
  sets `p` to nil, which converts the common form into the nil trap, and that is
  all it does. No proof in this repository claims more.
- **`readln` at an unterminated last line** stops rather than failing, where
  ISO calls reading past end-of-file an error. Files whose last line has no
  terminator are common enough to be worth the deviation; `readln` with nothing
  left at all still fails (ADR-0021).
- **Characters are bytes, and the locale is never consulted.** `char` is
  0..255, so UTF-8 passes through unchanged but a multi-byte character is
  several `char` values. That is a deliberate non-decision: encoding is the
  program's business. It does mean a Pascal-hosted lexer sees bytes, which is
  fine while the language it lexes is ASCII.
- **Not implemented at all:** nothing. Sets (ADR-0028), `goto` (ADR-0029 and
  ADR-0032), procedural parameters (ADR-0030), non-text files (ADR-0031), the
  transfer procedures with `page` (ADR-0067) and §6.3's string constant
  (ADR-0068) were this group, and it is now empty — **ISO 7185 is complete**.
  The last four are worth a sentence, because they arrived the same way twice.
  §6.6.5.4's `pack`/`unpack` and §6.9.5's `page` were *missed*, not declined,
  and three documents asserted completeness while they were absent; a
  documentation audit found them by compiling a probe. `const s = 'hello'` was
  then found the same way, hours after the `iso-7185-done` tag had been moved
  to the commit that fixed the first three. No program in the corpus had ever
  written any of them, so every oracle agreed. What makes the claim true now is
  `tests/transfer.pas`, `tests/page.pas`, `tests/stringconst.pas` and the cases
  beside them — not the implementations.
- **A set's base type must have its values in 0..255**, because every set is
  one 256-bit word. ISO 7185 §6.4.3.4 leaves the size to the implementation, so
  this is a permitted limit rather than a deviation — but `set of integer` is a
  legal program this compiler refuses (ADR-0028).
- **Set compatibility ignores packing.** §6.4.5 c) makes two set-types
  compatible only if both are `packed` or neither is, and only the base types
  are compared here. Accepting `packed set` is not the deviation — §6.4.3 makes
  a set-type a structured-type, so `packed` may precede one — and the earlier
  wording of this entry named the wrong thing. The representation is one bit
  per member either way, so the check could only reject programs that work, and
  the standard does not say what packing a *set-constructor* has, so requiring
  agreement would make `s := [1]` depend on how `s` was declared (ADR-0072).
- **An identifier may contain an underscore**, where §6.1.3 makes one `letter {
  letter | digit }`. It is how a name that would collide with a word-symbol is
  spelled — `label_`, `set_`, `packed_` — and how a test program takes the name
  of its file: thirteen identifiers in `selfhost/compiler.pas` and the program
  headers of forty-three test programs (ADR-0072).

### Under ISO/IEC 10206:1991

Four more, each stated in the record that made it:

- **String concatenation draws from a ring.** A string value is a pointer and a
  length (ADR-0051), so only `+` makes characters that did not exist; they come
  from a fixed buffer in the runtime. One *statement* concatenating more than
  the ring holds is the limit, and it is stated rather than silently wrong.
- **ExpDigits is not a fixed number** (ADR-0064). §6.10.3.4.1 makes it one
  implementation-defined value; here it is what C's `%E` writes — two digits,
  or three past 1e100 — so a representation stays exactly ActWidth wide while
  that width depends on the exponent. A conforming processor pads `E+00` to
  `E+000`.
- **A direct-access file's length bound is not checked** (ADR-0050). §6.4.3.6
  makes `file [1..10] of T` at most ten components; this one will hold eleven.
  The index type is used for the position's *type* and its lower bound, not as
  a capacity.
- **§6.5.6's substring aliasing rule is not enforced** (ADR-0057), for the same
  reason ADR-0027's is: it is a property of values at run time, and nothing
  tracks it.

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
  - It **retires ISO 7185's equal-length rule** and the trap `9b72539` added
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
  and nothing below is aimed at that.

## What is next

Both standards are complete and every sweep above has been run, so only the
third item below is a language feature. Three of the other four are about
**oracles** — what could still be wrong with nothing here to say so — and they
come first because v1.0.0 gave up the strongest oracle this project had and
nothing has replaced it. The fifth is the platform lock.

Nothing here is scheduled. This section exists so that the reasons are written
down while they are still live, which is ADR-0001's rule applied to work that
has not started.

### 1. An oracle nobody here wrote

ADR-0085 states the cost and no entry has answered it. `selfhost/difftest.sh`
compared two independent implementations over 436 sources; what remains — the
435 cases, the stage-2/stage-3 fixed point, and 43 SMT rules — all share one
implementation, and **a golden cannot disagree with the program that wrote
it**. The defects difftest caught were exactly the ones every other oracle
agreed about: a builtin's enumerator one apart (ADR-0059), a comment-delimiter
rule implemented wrongly in *both* compilers (ADR-0073), a diagnostic that
named two types identically and explained nothing (ADR-0074).

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
  - Two entries the suite *reports* are not enforced either, and the document
    now says so: an undefined pointer is usually nil here, because a level-0
    activation record is a global (ADR-0053), so the nil checks catch D.4 and
    D.24 for the shape where the variable was never assigned and catch neither
    where the pointer is stale. A check that coincides with a rule is not that
    rule being enforced, and a green run of those two programs must not be read
    as one.
- **A third-party differential.** FPC under `-Miso`, or p5, over the ISO 7185
  half of `tests/`. Not a second implementation to maintain: a second *answer*,
  on programs that already exist. Still worth doing — the suite is a *fixed*
  corpus from 1982, where difftest compared every source in this tree and grew
  with the language.
- **Mutation testing, committed to the tree.** It has found something every
  time it has been run here — the six occasions listed under "Stage 1", and
  ADR-0065's two mutants that changed the compiler rather than the tests — and
  it exists only as prose in those records. Two things it needs, both learned
  the expensive way: a wall-clock and output-size limit per mutant, because a
  looping mutant fills the disk before anything notices; and a restore that
  does **not** preserve mtime, or the mutated binary stays in the build tree
  and the next control run reads as a broken feature.

### 2. Diverse double-compiling, while it is still possible

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

### 3. Conformant array parameters, and level 1

The one language feature here, and the only work that would change the
compliance level `doc/implementation-defined.md` states.

That document's §1 declares **level 0**, which is a complying level rather than
a gap: ISO 7185 clause 5.1 a) defines it as clause 6 without §6.6.3.6 e),
§6.6.3.7 and §6.6.3.8. Accepting those three makes a level 1 processor.

Most of the mechanism is already here. ADR-0040's schematic formal parameter is
a descriptor beside the address — bounds that travel with the actual — which is
what a conformant array parameter needs and is why one compiled body can serve
every extent. What is genuinely new is §6.6.3.7's congruity rules for
conformant array schemas, which are not ADR-0030's rules for procedural
parameters however alike the two read.

Worth knowing before starting: a schematic formal already covers this ground in
Extended Pascal, so the feature buys **conformance and not expressiveness**.

### 4. Nothing can currently measure what the corpus reaches

`gcov` went out with `src/`. CLAUDE.md still says *"don't assume the corpus
reaches a branch — count it"* and lists six times that counting found
something, but there is no longer a tool that can count: `selfhost/compiler.pas`
is compiled by a compiler with no instrumentation, and the `code-review`
skill's entire coverage step is a `gcov` recipe against files that do not
exist.

The cheap version costs an afternoon and covers the case this project keeps
hitting: extract every diagnostic message literal from `compiler.pas` and look
for each one in the 157 `.err` goldens. That answers "Sema reached 48 of its 85
messages" mechanically and on every run, which is the exact question that has
turned something up every time it has been asked. The expensive version is a
`--coverage` flag in the code generator emitting counters, which is a feature
in its own right and would want a record.

### 5. The platform lock has a scoped way out

`seed/README.md` states the cost — the repository is x86-64 Linux only, and
porting needs a working compiler on the new target first. A `--target=` option
would turn that into "porting needs a cross-assembler": the triple and the
datalayout are already written out as text (ADR-0028), so the emitter's half is
small.

What needs investigating rather than promising is everything *else* that
assumes the target — `fileSize` against `PAS_FILE_SIZE`, the pointer width the
frame layouts are computed with, and `LlSize`/`LlAlign`. This has an honest
chance of "more is baked in than it looks", and should be scoped as an
investigation rather than as a feature.

### What continuous integration does and does not check

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
is absent, which is right for a checkout and wrong for CI — 435 tests would
report green with the 43 rules never run. It asserts z3 is importable before it
configures, so a green bar means the proofs ran.
