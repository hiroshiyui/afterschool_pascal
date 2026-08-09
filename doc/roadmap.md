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

Stage 0 only has to be good enough to compile the Pascal-written compiler
*once*. It does not have to be fast, complete, or pleasant — which is why the
feature list below stops where it does rather than at full ISO coverage.

The stage-2 ≡ stage-3 comparison is the whole point: stage 2 is built by a
compiler that was itself built by C++, stage 3 by one built by Pascal. If the
bytes match, the Pascal source is a fixed point and stage 0 can be retired.

## Where stage 0 is now (milestone 6)

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

Alongside the language, 34 ctest cases — 32 Pascal programs, the verification
run, and the differential test — and 31 SMT rules, 27 of them for all 2³²
inputs, with no known gaps.

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

## Next: writing stage 1

Nothing in the language is now blocking. In rough order:

1. ~~**Port the lexer.**~~ **Done** (ADR-0022) — checked against the C++ lexer
   on every Pascal source in the tree by `selfhost/difftest.sh`, under ctest.
2. ~~**Port the parser and the AST.**~~ **Done** (ADR-0023) — the bootstrap
   constraints paid: the `NK` tag became a variant record's tag and `as<T>()`
   became the `case` that reads it, with no cleverness needed.
3. ~~**Port Sema**, including the type arena.~~ **Done** (ADR-0024) — and with
   it the stage-1 sources merged into one `selfhost/compiler.pas`, because ISO
   has no include mechanism and a third program would have carried a third copy
   of the lexer. It dumps every stage in one pass, against `--dump-all`. 173
   files agree stage for stage.
4. **Port CodeGen against textual IR.** ADR-0006's path. The C++ backend keeps
   using the LLVM API; the Pascal one prints `.ll` and hands it to `llc` or
   `clang`. Binding the LLVM-C API from Pascal is possible later and is not on
   the critical path.

**Differential testing is the checkpoint**, and it comes before stage 1 is
declared working: once both compilers exist, they should produce equivalent IR
for every file in `tests/`. A disagreement is a bug in one of them, found
cheaply, rather than a byte mismatch at stage 3 with nothing to bisect. The
three components ported so far already work this way, and each later one is
merged into the same program and dumped in the same pass rather than getting a
harness of its own.

The harness is only worth what its corpus reaches, and that has to be
*counted*, not assumed. Twice now a whole branch was found uncompared: no file
contained a tab, so the lexer's control-character class was never exercised
(ADR-0022), and no file produced a parser diagnostic, so all 43 message
contexts and 61 token spellings were unchecked (ADR-0023). Sema reached 48 of
its 85 messages before `badsema/` was written, and three mutations survived the
suite until the corpus was extended (ADR-0024). Every one of these was found by
mutating the Pascal source and noticing that nothing went red.

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

And four from Sema (ADR-0024):

- **A selector may follow only a variable-access** (§6.5.1), so `Base(t)^.kind`
  cannot be written at all and every predicate takes a local first.
- **A check computed in a wider type has to be rearranged.** `hi - lo` over the
  whole integer type is `2*maxint`. This is the second such rewrite, so it is
  now a pattern to expect rather than a surprise.
- **`||` short-circuits, and the C++ relies on it** — a port that evaluated
  both subrange bounds would report a different number of errors.
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
- **A variant part nested inside a variant is rejected.** Deliberate, and
  documented in ADR-0018. ISO allows it; nothing the compiler's own source needs
  requires it.
- **`new(p, c1, ..., cn)` is rejected.** The variant-selecting form. This
  compiler always allocates the whole record, which is safe but is not the
  feature §6.6.5.3 describes (ADR-0019).
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
- **An empty statement before `else` is rejected**, though ISO 7185 §6.8.1
  allows a statement to be empty anywhere. Found while porting Sema, where the
  C++ writes `continue`; the condition was folded into the following test
  instead. Nothing needs it, but it is a deviation, not a design choice.
- **Not implemented at all:** sets, `goto`, procedural and functional
  parameters, and non-text files. None of them is on the path to stage 1. Sets
  would be the most useful of the four for a compiler (character classes,
  follow sets) and are the likeliest to be added opportunistically.

## Beyond self-hosting

Nothing here is scheduled, and none of it should start before stage 3 compares
equal.

- **Retire stage 0.** Once the Pascal compiler is a fixed point, the C++ source
  becomes a historical artefact rather than a maintained one.
- **The rest of ISO 7185**, driven by a conformance suite rather than by what
  the compiler's own source happens to use.
- **Keep the proofs alive across the port.** `verify/lowering.py` models
  `codegen.cpp`; when codegen is rewritten in Pascal, the model has to follow it
  or the catalogue silently starts describing a compiler that no longer exists.
  This is the single most fragile thing about the bootstrap, and it deserves a
  decision of its own before the port reaches CodeGen.
