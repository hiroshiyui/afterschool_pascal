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

## Where stage 0 is now (milestone 5)

| # | Feature | State | Record |
| --- | --- | --- | --- |
| 1 | Procedures and functions | **done** — nested to any depth, recursive, value and `var` parameters, `forward` | [ADR-0016](adr/0016-nested-procedures-use-static-links.md) |
| 2 | Arrays and records | **done** — any ordinal index, multi-dimensional, `packed`, nested, `with`, bounds-checked | [ADR-0017](adr/0017-structured-types-use-name-equivalence.md) |
| 3 | Enumerations, subranges, `case` | **done**, with the variant records they unlock | [ADR-0018](adr/0018-ordinal-types-and-variant-records.md) |
| 4 | Pointers, `new`/`dispose` | **done**, with the forward-referenced domain that makes a recursive type possible | [ADR-0019](adr/0019-pointers-and-the-only-forward-reference.md) |
| 5 | Text files | **next** | — |
| 6 | Character strings | open question | [ADR-0012](adr/0012-character-strings-for-self-hosting.md) (Proposed) |

Items 1–4 mean the AST of a self-hosted compiler is now *expressible*: the node
kind is an enumeration, the node is a variant record, and the tree is heap
allocated through a recursive pointer type. `tests/pointers.pas` builds exactly
that shape as a proof by construction.

Alongside the language, 25 ctest cases — 24 Pascal programs plus the
verification run — and 29 SMT rules, 25 of them for all 2³² inputs, with no
known gaps.

## Item 5 — text files

`reset`, `rewrite`, `read`, `readln`, `write` to a file, `eof`, `eoln`, and the
`file of char` type behind `text`. This is the last *structural* item: without
it the compiler cannot read its input or write its output, and with it the
stage-1 source can be written.

What makes it more than plumbing:

- **`text` is a file *variable*, not a handle.** ISO gives a file variable a
  buffer variable `f^` and defines `read` in terms of it. `get`/`put` and `f^`
  are the primitive operations; `read` and `write` are defined on top. Whether
  to implement the primitives honestly or to define only the derived forms is
  the first decision, and the answer affects what a Pascal-hosted lexer can be
  written against.
- **`program P(input, output)`** — the program parameters finally have to mean
  something. Today they are parsed and ignored.
- **`eoln` and the line structure.** ISO's file model has lines terminated by a
  component that reads as a space; the mapping onto a POSIX byte stream is where
  most Pascal implementations quietly differ from the standard, and the
  difference should be recorded rather than absorbed.
- **Runtime, not IR.** Almost all of it belongs in `runtime/pasrt.c` behind the
  ADR-0007 boundary, and almost none of it wants an SMT rule — file behaviour is
  a state property, not an arithmetic lowering. Expect this item to be carried
  by golden tests plus a sanitiser run, the same way pointers were.

## Item 6 — character strings

The one place ADR-0002 (conform to ISO 7185) and ADR-0004 (self-host) genuinely
conflict. ISO has no string type: only string literals and
`packed array [1..n] of char`, where the length is part of the type, so a
procedure taking a name cannot take a longer one.

A compiler is unusually string-heavy — identifiers, keyword tables, literals
lifted from the source, diagnostics, and under ADR-0006 the whole emitted IR as
generated text.

[ADR-0012](adr/0012-character-strings-for-self-hosting.md) lays out the three
options (a length-plus-buffer record, a documented `string` extension, or
ISO 10206 strings) and currently *recommends* the first without deciding. It is
still `Proposed` on purpose: the requirement should come from real stage-1 code
rather than from a guess.

**This has to be settled before the stage-1 source is written, not during.**
Nothing before item 5 depends on the answer; everything after it does.

## After item 6: writing stage 1

In rough order, once the language is sufficient:

1. **Port the lexer.** Smallest self-contained stage, exercises strings and text
   files immediately, and its output can be diffed against the C++ lexer's on
   every file in `tests/`.
2. **Port the parser and the AST.** The AST is where the bootstrap constraints
   were paying rent all along — the `NK` tag becomes a variant record's tag and
   `as<T>()` becomes the `case` that reads it.
3. **Port Sema**, including the type arena. `Type` is already shaped for a
   variant record: a pointer's domain deliberately shares `elem` with an array's
   component type.
4. **Port CodeGen against textual IR.** ADR-0006's path. The C++ backend keeps
   using the LLVM API; the Pascal one prints `.ll` and hands it to `llc` or
   `clang`. Binding the LLVM-C API from Pascal is possible later and is not on
   the critical path.

**Differential testing is the checkpoint**, and it comes before stage 1 is
declared working: once both compilers exist, they should produce equivalent IR
for every file in `tests/`. A disagreement is a bug in one of them, found
cheaply, rather than a byte mismatch at stage 3 with nothing to bisect.

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
