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
- **Schemata**, the core of the standard: parameterised types, and what
  `string(n)` is built on. Everything larger composes with it.
- **`string`.** ADR-0012 chose the length-plus-buffer record partly because the
  project had not committed to this standard; it now has, so that reason has
  expired. Its *finding* has not — a compiler reads text in and writes text out
  — so this should be settled by measuring stage-1 code again, the way it was
  settled the first time, and not by taste.
- **Modules**, `bind`/`unbind`, direct-access files, complex numbers,
  `protected`, initial-state specifiers. Each needs its own record.

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
