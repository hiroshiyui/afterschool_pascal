# ADR-0154: The dialect changes what a conformance mode says, not what it accepts

Date: 2026-08-21

## Status

Accepted. Answers `doc/roadmap.md` §6, the last open entry of that chapter, and
it is one sentence with a correction attached.

## Context

Four documents said some version of *the two conformance modes stay exactly as
they are* — `CLAUDE.md` twice, `doc/glossary.md`, `doc/roadmap.md` and
`doc/afterschool-pascal-spec.md` §5.3. It is the promise ADR-0109 made when the
dialect was proposed and it is the reason `--std=afterschool` exists as a third
mode rather than as a set of extensions to the second.

It is stronger than what is true, and §6 of the roadmap noticed:

> ADR-0121 requires `src/` to carry the *refusal* of `external`, and the message
> names the mode — so a program written for the dialect and compiled under
> `--std=extended` is told about the dialect.

`.claude/skills/release-engineering/` makes diagnostics part of the public
interface, alongside the accepted language and the command line. So a
diagnostic that mentions the dialect *is* a change to `--std=extended`, by this
project's own definition of what a release changes.

## Decision

**State the exact claim: the dialect does not change what a conformance mode
accepts; it does change what one of them says.**

That is unavoidable and is not a conformance question. §5.1 is about accepting
and rejecting, and the program is rejected either way — what differs is whether
the reason is *expected 'begin'* or *the `external` directive is a dialect
feature; compile with --std=afterschool*. The second is the useful message and
the first is what leaving `src/` alone produced, which ADR-0121 recorded as a
difftest failure rather than as an option.

Refusing to name the dialect would keep the stronger sentence true and make the
diagnostic worse, for a property no user has. Nobody is harmed by a compiler
that explains why a program was rejected; the sentence was written to promise
that a *conforming program* keeps its meaning, and that promise is untouched.

## Consequences

Four documents now say the exact thing. The wording is the same in each, so a
reader meeting it twice meets one claim: **what those two modes accept does not
move for the dialect; what they say may.**

### And the sentence had a second reader problem

`CLAUDE.md`'s version sat one paragraph from ADR-0109's goal, where a reader
takes it as a promise about the whole compiler rather than about the dialect.
ADR-0153 made that visible: ISO 7185 mode now accepts conformant array
parameters, so *the conformance modes stay exactly as they are* is false in a
second and much larger way — and that change has nothing to do with the
dialect. It is the standard's own level 1, taken deliberately.

So the corrected sentence names its subject: the accepted language of a
conformance mode moves only for a reason inside that mode's own standard.
Level 1 is such a reason. The dialect is not one.

### What it does not change

No code, no diagnostic, no test. The messages are what they were, `src/` still
carries the refusal, and `difftest`'s baseline is still empty. What changes is
that four documents stop over-promising, which is the whole of what §6 asked
for and the reason it was classified as *writing* rather than as work.
