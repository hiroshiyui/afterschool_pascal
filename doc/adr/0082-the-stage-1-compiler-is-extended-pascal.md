# 82. The stage-1 compiler is written in Extended Pascal

Date: 2026-08-14

## Status

Accepted.

## Context

ADR-0033 made the standard a property of the source, and gave
`selfhost/compiler.pas` as the example of why the two languages cannot be
nested: "Extended Pascal reserves word-symbols a valid ISO 7185 program may use
as identifiers, and `selfhost/compiler.pas` has a field named `value`". That
sentence has been quoted in CLAUDE.md and the roadmap ever since as the reason
the stage-1 compiler is an ISO 7185 source.

It was never a *decision*. It was an observation about one identifier.

ADR-0081 made it matter. A program can read its own command line only through
§6.5.1's bindability and §6.7.6.8's `binding`, both of which are
ISO/IEC 10206:1991 — so an ISO 7185 source cannot take a flag, and
`build/bin/pascalc` was stuck with four positional files while `pascalc-s0` had
`--std`, `-o` and `--import`.

## Decision

**`selfhost/compiler.pas` is an Extended Pascal source.** Two identifiers
collided with §6.1.2's word-symbol list — `value` (134 occurrences) and
`bindable` (2) — and both take the trailing underscore this codebase already
uses for exactly this collision (`label_`, `set_`, `packed_`, 41 occurrences
before this change).

**The rename was applied by token position, not by text.** Both words appear
throughout the file in comments, in diagnostics and in the keyword tables the
compiler matches against, and none of those may change: `pascalc-s0
--dump-tokens` gives the line and column of every *identifier* token, and an
underscore was inserted after each. Doing it with a text substitution would
have rewritten the string literal `'value'` that the lexer compares against, in
a way no test could distinguish from a correct rename until something failed.

**The conversion is provably meaning-preserving.** Before the harnesses were
touched, the source compiled clean under both standards, and both the token
stream and the *annotated Sema tree* were byte-identical:

```
diff <(pascalc-s0 --dump-sema compiler.pas) \
     <(pascalc-s0 --std=extended --dump-sema compiler.pas)     # no output
```

That is a stronger statement than "it still builds". Identical Sema output means
identical input to CodeGen, so the compiled compiler cannot differ — and it is
the only form of evidence available, two standards not being comparable by
running one program.

**A source says which standard it is in with a `name.std` sidecar.** ADR-0033
made the *directory* the signal and ADR-0034 showed how easily that goes wrong;
`selfhost/` is neither `tests/` nor `tests/extended/`, and hard-coding the one
filename in three harnesses would be three places to forget. `compiler.std`
holds one word, beside the `name.in`, `name.epoch` and `name.components`
conventions those harnesses already read. CMake writes `--std=extended` out
instead, because it would have to read the file at configure time and a build
system that silently changed language when a file changed is worse than one
that says what it means.

## Consequences

**Stage 2 still equals stage 3**, which is the only evidence that mattered: the
compiler compiles itself in the new language and reaches the same fixed point.
435 sources still agree stage for stage between the two compilers, and 352
programs still behave as their golden output says.

**The bootstrap now depends on the Extended Pascal implementation.** It did not
before. That is the real cost of this record, and it is paid in exchange for a
compiler that can be given a command line — the two are the same decision.

**The largest ISO 7185 program in the corpus is no longer this one.** While the
source compiles under both standards that costs nothing, and the diff above is
the proof; the moment it calls `binding` it stops being an ISO 7185 program at
all, and that coverage does not come back. What remains for ISO 7185 is
`tests/`, which is where the language's rules are pinned anyway — but the
biggest, most varied Pascal in the repository has moved to the other standard,
and no oracle will report that as a loss.

### What this does not do

**It does not change what the compiler accepts.** `--std=iso7185` is still the
default and still what `tests/` is compiled with. Which language the compiler is
*written* in and which it *accepts* were always independent; this record is
about the first only.

**It does not use any Extended Pascal feature yet.** The source is Extended
Pascal by declaration and by two renamed identifiers, and by nothing else — that
is what let the conversion be checked by a diff. Everything this unlocks arrives
after it.
