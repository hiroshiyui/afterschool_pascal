# 4. Self-hosting is the near-term goal

Date: 2026-08-09

## Status

Accepted

## Context

Afterschool Pascal should be written in Afterschool Pascal. This was set as the
short-term goal while milestone 1 was being built, early enough to shape the
design rather than be retrofitted into it.

Self-hosting is not a feature that gets added at the end. It decides which
language features matter, in what order, and it constrains how the stage-0
compiler may be written — because every construct used in the C++ compiler is a
construct whose Pascal equivalent must eventually exist and work.

## Decision

Treat self-hosting as the organising goal. Concretely:

* Language features are prioritised by what a compiler is written in, not by
  the order of the standard. Dependency order: procedures and functions with
  nesting and `var` parameters; arrays and records; enumerations, subranges and
  `case`; pointers with `new`/`dispose`; text files; character strings.
* Stage 0 (the C++ compiler) only has to be good enough to compile the stage-1
  Pascal source once. It is not the deliverable.
* The bootstrap is the classic three-stage build, and its success criterion is a
  fixpoint:

  ```
  stage1 = stage0(compiler.pas)
  stage2 = stage1(compiler.pas)
  stage3 = stage2(compiler.pas)      require stage2 ≡ stage3, byte for byte
  ```

  stage1 and stage2 differ legitimately — different compilers built them — but
  stage2 and stage3 were both built by a compiler compiled from the same source,
  so any difference is a bug.

## Consequences

Feature work has an ordering with a reason behind it, and "is this needed for
the bootstrap?" becomes a usable prioritisation question.

Stage 0 is now constrained in how it may be written, which is ADR-0005, and in
what backend it must keep working, which is ADR-0006. Both look like
over-engineering if this record is not read first.

Before stage 1 there is a useful checkpoint: once both compilers exist, they
should produce equivalent IR for every file in `tests/`. That catches divergence
while it is still one feature wide.

Note the standard bootstrap caveat: from stage 1 onward, the binary is built by
a binary. Trusting it means trusting the chain, not just the source.
