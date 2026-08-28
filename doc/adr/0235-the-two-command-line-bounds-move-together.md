# 235. The two command-line bounds move together

Date: 2026-08-29

## Status

Accepted, 2026-08-29.

It supersedes nothing. It finishes what
[ADR-0158](0158-one-more-program-parameter-than-the-limit.md) declined —
*"it does not revisit `maxImports`"* — and closes the limitation
[ADR-0114](0114-the-standard-library-begins-in-what-is-already-conforming.md)
recorded about the library: *"a library of more than eight modules cannot be
used whole."*

## Context

`maxImports` was 8 and `argMax` was 24, and both numbers were arrived at the
same way: someone counted what the largest thing in the tree needed and left a
little over.

That worked while the largest thing in the tree was a test case.
`tests/dialect/lib_os.pas` has four program-components, which is eight
`--import` words, and eight is what `maxImports` was set to. ADR-0158 had
already caught the *argument* half of this failing badly — twelve arguments was
exactly what that case needed, so ADR-0156's `--target=` pushed a correct
command line off the end and the compiler blamed the last argument that
arrived rather than the first that did not — and raised `argMax` to 24 while
saying in as many words that it did not revisit the other number. Nothing had
asked.

`lsp/pasls.pas` asked
([ADR-0236](0236-the-language-server-begins.md)). Its import chain is **ten
modules**, and none of them is a convenience:

    PasError  PasFS  PasIO  PasEnv  PasStrVec
    PasProcess  PasContainer  PasJson  PasLsp  PasLspDiag

`PasIO` needs `PasFS` for a path type, `PasJson` needs `PasContainer` for the
vector that makes a string value unbounded, `PasProcess` needs `PasStrVec`;
the server itself needs `PasProcess` to invoke the compiler, `PasEnv` to find
it, and the three protocol modules to speak. Ten is the floor and not a
choice. The compiler answered

    pascalc: more than 8 --import arguments

which is ADR-0110's rule working exactly as intended — the limit reported
rather than truncating — and it is still a program that could not be compiled.

**The two bounds are one bound.** An import costs *two* words of the command
line, so `maxImports` is only real as far as `argMax` can express it. Raising
`maxImports` alone would have moved the refusal from a message naming the
imports to a message naming the arguments, which is a worse diagnostic for the
same failure.

## Decision

`maxImports` becomes **32** and `argMax` becomes **72**, and the second is
*derived* from the first rather than counted again:

    32 imports x 2 words                            = 64
    --target=, a --dump flag, --coverage             =  3
    the source, `-o`, its file name                  =  3
                                                      --
                                                       70, and two over

The derivation is written into the comment on `argMax` in
`selfhost/aptypes.pas`, because the failure mode this record exists to prevent
is someone raising one number and not the other.

`argMax` is a program-parameter list and the list is written out — §6.5.1 gives
a program-parameter the bindability that is bindable and §6.7.6.8's NOTE 2 makes
`binding(argk)` report argument *k*, but a program-parameter is a name and not
a subscript (ADR-0081). So the cost is literal: 48 more declarations and 48
more arms of `Arg`'s case-statement, plus `argOver` where it was.

## Consequences

- **A program may now import the whole library.** There are 25 modules in
  `lib/` as this is written and `maxImports` is 32, which is the first time
  that sentence has been true. ADR-0114's paragraph is struck.
- **The compiler is 96 lines longer and none of them is interesting.** The
  heading, the declarations and the case arms are three lists of the same
  names. That is what a fixed program-parameter list costs, and it is the price
  ADR-0081 accepted for reading a command line at all.
- **Two harnesses count in terms of the bound and had to move with it.**
  `selfhost/producttest.sh` builds a command line of `argMax` words and one of
  `argMax + 1` and asserts both outcomes, so both counts changed;
  `tests/checks/coverage.py` fills a command line to exactly `argMax` so that
  every arm of `Arg` is reached, and without that update 48 arms would have
  been reported unreached — which is `line-coverage`'s ratchet doing its job
  and would have been a true finding about an untested change.
- **It is still a fixed bound and it will still be met.** 32 modules is a
  library and not a program's appetite; a program that imports 33 gets a
  message rather than a truncation, which is ADR-0110's rule and all that was
  ever promised. The next raise costs another 48 declarations, and at some
  point the answer is a flag that names a file of imports rather than a longer
  list — `selfhost/compiler.components` is already that shape for the build.
  Not now: nothing has asked for 33.
- **The seed is stale until the next release.** Two constants changed, so the
  IR changed, and `seed-is-current` compares them byte for byte at a tag.
  That is the ordinary state of the tree between releases (ADR-0085).

## Alternatives considered

- **Raise `maxImports` alone.** Rejected above: the refusal moves to the
  argument count and the diagnostic gets worse.
- **Reduce the server's imports.** There is nothing to reduce. Every module in
  the chain is there because another one names a type from it.
- **`--imports=file`, one path per line.** One argument for any number of
  modules, and it is the shape `selfhost/compiler.components` already has for
  the build. Deferred rather than rejected: it is a new flag, a new file
  format and a new set of diagnostics, and what asked for it was a program
  needing *ten* imports rather than an unbounded number. When 33 arrives this
  is the answer.
