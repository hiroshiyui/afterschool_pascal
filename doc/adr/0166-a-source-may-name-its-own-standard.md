# 166. A source may name its own standard

Date: 2026-08-22

## Status

Accepted, and **retired by
[ADR-0232](0232-afterschool-pascal-is-the-language.md)**. `{ @std:iso7185 }`
is an ordinary comment again, and the 99 lines that read it before the lexer
ran are deleted, along with the four probes in `tests/checks/stdannot/`.

## Context

ADR-0165 moved the default to Extended Pascal and left a gap it names in its
own consequences: an unflagged source is now assumed to be a language most
files here are *not* written in, and the standard is a property of the source
(ADR-0033) that the source had no way to state.

The repository already answered this **out of band**, three times over.
`selfhost/compiler.std` is a file holding one word, beside a source outside
`tests/extended/`. `tests/dumps/` takes a `name.std` sidecar. `foo.components`
takes an optional second field naming a standard. Each is a second file that
can be lost, renamed, or copied away from the source it describes — and the
two harnesses ADR-0165 broke were broken for exactly the reason a sidecar does
not fix: a file that must be compiled a particular way could not say so.

## Decision

**A comment before the program heading may contain `@std:` and a standard's
name.** `@std:iso7185`, `@std:extended`, `@std:afterschool`.

**It is read before `Tokenize`, and by a scan of its own.** The standard
decides the lexis — §6.1.2 makes `value` a word-symbol in Extended Pascal and
an ordinary identifier in ISO 7185 — so by the time there are tokens the
question has been answered. That rules out a token-level feature, and it is
why `ReadStdAnnotation` walks characters instead of reusing
`SkipTriviaAndComments`, which belongs to a lexer already told which language
it is reading.

**Only the header counts.** The scan stops at the first character that is
neither a separator nor part of a comment. A file cannot change language
halfway, and a `@std:` appearing in prose further down cannot reach back and
retarget the file. `tests/checks/stdannot/late.pas` pins that by *failing*.

**An explicit `--std=` wins, and a disagreement is not reported.** A harness
naming a standard means it: §6.13's components are translated under a standard
the *program* chooses (ADR-0137) and `run_test.sh` passes one on every file, so
a conflict is the flag being more specific rather than a mistake. That is why
`stdFromFlag` exists — `--std=extended` and the default leave `langStd`
identical, so nothing else could tell them apart.

**A misspelt name is an error.** An annotation that silently did nothing would
compile a file under a standard its author had written down that it was not.

**`tools/pascalcc` stopped having a default.** It held one and passed
`--std=` on every invocation, which looks like the more explicit thing to do
and made this feature unreachable through the script everyone compiles with:
the compiler reads the annotation only when no flag was written. The default
now lives in exactly one place, and the driver passes through what it was
given, as it does with every other flag.

## Consequences

**It changes what neither conformance mode accepts.** A comment is a comment in
both standards; what the annotation selects is *which language the file is
in*, which clause 1.2 c) of ISO/IEC 10206:1991 puts outside the standard
altogether — "the method of activating the program-block or the set of commands
used to control the environment in which an Extended Pascal program is
transformed". It is the in-band spelling of `--std=`, not a language feature,
and it is available in all three modes rather than being the dialect's.

**Nothing under `tests/` can test it**, and that is not a gap in the tests but
a property of the feature: every harness there passes `--std=` derived from the
directory, and the annotation is read only when no flag was given. So the
probes live in `tests/checks/stdannot/`, `selfhost/producttest.sh` asserts each
of the five behaviours, and `tests/checks/coverage.py` drives them with no flag
— the only way the scan runs at all. The change adds **zero** unreached
statements; both coverage gates pass with the ratchet untouched.

Mutation: deleting the header rule — letting the scan run past the first token
— is killed by `producttest`'s "a @std: annotation past the first token took
effect".

### What this does not do

**It does not replace the sidecars.** `selfhost/compiler.std`, `name.std` and
`foo.components`' second field all still work and are still what the harnesses
read. Migrating them is a separate change, and `compiler.pas` is the
interesting case: it would become a source that states its own standard, which
is what this record is ultimately for.

**`src/` does not implement it.** The reference front end is only ever driven
by `difftest.sh`, which passes `--std=` explicitly on every file, so the
annotation is never read on either side and no divergence is possible. If
difftest ever compiles a file without a flag, this becomes a real gap;
`doc/sop.md` §7 carries it.

**It reads one annotation.** A second `@std:` in the same header is ignored
rather than reported — a file states its language once, and a later line is
prose about it.
