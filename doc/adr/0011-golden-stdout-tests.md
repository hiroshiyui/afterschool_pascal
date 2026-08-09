# 11. Test by comparing program stdout

Date: 2026-08-09

## Status

Accepted

## Context

A compiler can be tested at several depths: unit tests over the lexer and
parser, golden-file comparison of emitted IR, or end-to-end execution of the
compiled program.

IR comparison is precise but brittle in a way that punishes exactly the work
this project does. Every improvement to codegen, and every LLVM version bump,
rewrites the expected output of every test, so the suite has to be regenerated
routinely — and a regenerated golden file is one nobody reads.

Unit tests over the front end are stable but check the middle of the pipeline
rather than the thing that matters: that the program does what Pascal says it
should.

## Decision

Each test is `tests/name.pas` with its expected stdout in `tests/name.out`.
`tests/run_test.sh` compiles it into a temporary directory, runs it, and diffs
against the expectation. A non-zero exit from either the compiler or the program
fails the test. CMake registers one CTest case per `.pas` file.

Tests are written to pin down *semantics*: the non-negative `mod`, the sign
binding to a whole term, `for` over `char`, field-width formatting.

## Consequences

Tests survive codegen changes and LLVM upgrades untouched, because they assert
what Pascal promises rather than which instructions were chosen. They are
readable as documentation — `tests/arith.pas` shows the mod rule better than a
paragraph does. And they exercise the whole chain including the runtime and the
link step, so a break anywhere is caught.

Localisation suffers: a failure says the output differed, not which pass was
wrong. Acceptable while the compiler is small, and `--emit-llvm` is a good first
step when it happens.

Cases are registered by a `file(GLOB)` at configure time, so **adding a test
requires re-running `cmake`**. A glob at build time would be worse in the usual
way — silently stale on other people's machines.

Two gaps this leaves. Programs that should *fail* to compile are not covered,
and diagnostics are a real part of the interface; that wants a companion form
where the expectation is a compiler error. And nothing yet tests stdin, which
arrives with `read`/`readln`.
