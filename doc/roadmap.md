# Roadmap

Where the compiler is, what is left before it can compile itself, and what is
deliberately not being done yet.

The ordering is not ISO 7185's chapter order. It is the order a *compiler* needs
its features in: procedures, then the data structures an AST is made of, then
the I/O that reads source and writes IR. ADR-0004 sets that priority; this file
tracks it.

## The three-stage build

```
stage 0   pascalc (C++)          — this repo, grown until it accepts the stage-1 source
stage 1   pascalc1 = stage0(compiler.pas)
stage 2   pascalc2 = pascalc1(compiler.pas)
stage 3   pascalc3 = pascalc2(compiler.pas)      require pascalc2 ≡ pascalc3 byte-for-byte
```

**The comparison now holds.** `selfhost/irtest.sh` runs all three stages under
ctest and requires stage 2 to equal stage 3; they are compared as IR rather than
as binaries, because IR is what the Pascal compiler emits (ADR-0025).

Stage 0 only has to be good enough to compile the Pascal-written compiler
*once*. It does not have to be fast, complete, or pleasant — which is why the
feature list below stops where it does rather than at full ISO coverage.

The stage-2 ≡ stage-3 comparison is the whole point: stage 2 is built by a
compiler that was itself built by C++, stage 3 by one built by Pascal. If the
bytes match, the Pascal source is a fixed point and stage 0 can be retired.

## The six bootstrap items (all done)

| # | Feature | State | Record |
| --- | --- | --- | --- |
| 1 | Procedures and functions | **done** — nested to any depth, recursive, value and `var` parameters, `forward` | [ADR-0016](adr/0016-nested-procedures-use-static-links.md) |
| 2 | Arrays and records | **done** — any ordinal index, multi-dimensional, `packed`, nested, `with`, bounds-checked | [ADR-0017](adr/0017-structured-types-use-name-equivalence.md) |
| 3 | Enumerations, subranges, `case` | **done**, with the variant records they unlock | [ADR-0018](adr/0018-ordinal-types-and-variant-records.md) |
| 4 | Pointers, `new`/`dispose` | **done**, with the forward-referenced domain that makes a recursive type possible | [ADR-0019](adr/0019-pointers-and-the-only-forward-reference.md) |
| 5 | Text files | **done** — `reset`, `rewrite`, `read`, `readln`, `eof`, `eoln`, and the buffer variable with `get`/`put` | [ADR-0021](adr/0021-text-files-keep-the-buffer-variable.md) |
| 6 | Character strings | **decided** — a length-plus-buffer record, no extension | [ADR-0012](adr/0012-character-strings-for-self-hosting.md) |

Items 1–4 mean the AST of a self-hosted compiler is now *expressible*: the node
kind is an enumeration, the node is a variant record, and the tree is heap
allocated through a recursive pointer type. `tests/pointers.pas` builds exactly
that shape as a proof by construction. Item 5 means it can now read its input
and write its output, so **every structural prerequisite for stage 1 is in
place**.

Item 6 is a decision rather than a feature, and it is now made, so **the
language is finished for bootstrap purposes**: what remains is writing the
Pascal, not growing what it is written in.

Alongside the language, 55 ctest cases — 52 Pascal programs, the verification
run, the differential test and the bootstrap — and 35 SMT rules, 27 of them for
all 2³² inputs, with no known gaps.

## Item 5 — text files (done)

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

## Item 6 — character strings (decided)

Settled as ADR-0012: a length-plus-buffer record in strict ISO Pascal, no
extension, ADR-0002's conformance untouched.

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

1. ~~**Port the lexer.**~~ **Done** (ADR-0022) — checked against the C++ lexer
   on every Pascal source in the tree by `selfhost/difftest.sh`, under ctest.
2. ~~**Port the parser and the AST.**~~ **Done** (ADR-0023) — the bootstrap
   constraints paid: the `NK` tag became a variant record's tag and `as<T>()`
   became the `case` that reads it, with no cleverness needed.
3. ~~**Port Sema**, including the type arena.~~ **Done** (ADR-0024) — and with
   it the stage-1 sources merged into one `selfhost/compiler.pas`, because ISO
   has no include mechanism and a third program would have carried a third copy
   of the lexer. It dumps every stage in one pass, against `--dump-all`; 207
   files agree stage for stage today.
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
  is restrictive, like the use-after-dispose gap above.
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
  ADR-0032), procedural parameters (ADR-0030) and non-text files (ADR-0031)
  were this group, and it is now empty — **ISO 7185 is complete**.
- **A set's base type must have its values in 0..255**, because every set is
  one 256-bit word. ISO 7185 §6.4.3.4 leaves the size to the implementation, so
  this is a permitted limit rather than a deviation — but `set of integer` is a
  legal program this compiler refuses (ADR-0028).
- **`packed set` is accepted and ignored.** There is nothing to pack: the
  representation is already one bit per member. §6.4.6 asks that compatible
  sets agree on packing, which is not checked, and here could only reject
  programs that would work.

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

**What is left of ISO 7185**, in the order they are likely to be taken:

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

**Extended Pascal, and it has begun.** ISO/IEC 10206:1991 is the second stage,
not an ad-hoc pile of extensions. ADR-0033 settled how it arrives: `--std`
selects the language per source, ISO 7185 stays the default, and
`tests/extended/` is the corpus. The two are *not* nested — Extended Pascal
reserves word-symbols a valid ISO 7185 program may use as identifiers, and the
stage-1 compiler is such a program.

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

**Every feature of the second standard gets a record**, including one like that
last that decides nothing a later feature has to live with. The point is not
that each was hard but that the language's growth reads end to end from
`doc/adr/`; a feature with a short record is then distinguishable from one that
was never written down.
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

  **Schemata are done.** What remains of §6.4 is the required schema `string`
  itself (§6.4.3.3), which is now expressible by hand but is its own type-class
  with a capacity, a truncating assignment, and comparison across unequal
  lengths.

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
    usable in an ordinary expression too and is therefore its own item.
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
    §6.13 asks for with a *should* rather than a *shall* and which would need
    an interface artefact this compiler does not define; a module variable
    with computed discriminants; and a module-parameter that is neither
    `input` nor `output`, which §6.11.1 NOTE 6 lets go unbound.
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
- Structured-value constructors and `readstr`/`writestr`. Each needs its own
  record.

  The list above is the one the README carries, and it is not the whole of
  what ISO/IEC 10206:1991 adds. Also absent, and each small enough that the
  cost is in the pair of compilers rather than in the design: `halt`, `card`,
  the symmetric difference `><`, `maxchar`/`minreal`/`maxreal`/`epsreal`, the
  two-argument `succ`/`pred`, zero field widths in `write`, `extend`, the time
  procedures, and set-member iteration.

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
  two because a `Symbol` has nowhere to keep the value.

**And the two things that are not features:**

- **Retire stage 0.** The Pascal compiler *is* a fixed point now, so this is
  available — but the C++ compiler is still what builds stage 1, still what the
  first three components are diffed against, and still the one `verify/` proves.
  Retiring it means giving up all three, and none of them has a replacement yet.
- **Keep the proofs alive across the port.** ADR-0025 made the decision the
  earlier version of this line asked for: the theorems stay attached to the C++
  model, and the Pascal generator is tied to it by *behaviour* — the golden
  files carry the traps and their messages, so a lowering that stopped checking
  fails `irtest.sh`. What that does not give is a proof for every input, which
  is what `verify/` gives the C++ one. Re-pointing the model at the Pascal
  source is the work that retiring stage 0 would require, and it is still the
  most fragile thing about the bootstrap.
