# ADR-0360: A TOML document

Date: 2026-09-07

## Status

Accepted. Adds `lib/dialect/pastoml.pas` and three cases; adds nothing to the
language and changes nothing that was there.

## Context

The library had a JSON module and no TOML one. `PasJson` was written because
this project had a named client for it — every Language Server Protocol message
is a JSON object — and TOML's client is the more ordinary one: **a program
reads its own configuration**, and the format people write a configuration in
today is TOML.

This tree already had the client before it had the module. `pascalcc
new-project` writes an `afterschool-pascal.toml` and `pascalcc build` reads it
(ADR-0348), through a strict subset parser written **in shell**, which is where
a format goes when the language being driven cannot read it. That reader is not
replaced by this and will not be: `tools/pascalcc` is a shell script by
ADR-0009, and a Pascal module cannot be called from it without a compiled
helper the driver would then have to find.

## Decision

**TOML v1.0.0 whole, not a subset.** Bare, quoted and dotted keys; basic,
literal and both multi-line string forms with their escapes and their two
trimming rules; decimal, hexadecimal, octal and binary integers with
underscores; floats with a fraction, an exponent, `inf` and `nan`; the four
date-time forms; arrays over several lines and with a trailing comma; inline
tables; tables; arrays of tables. Every redefinition the format forbids is
refused, with a position.

The argument for *whole* is that a configuration file is written by a person
against the specification and not against this parser. A subset that reads
what this project's own file happens to contain would be a module whose
failures are reported to somebody who did nothing wrong.

**The shape is `PasJson`'s, deliberately.** A value is a heap node, a document
is a tree, `TomlFree` disposes one and a program that forgets it leaks; a
string value is bytes in a growable `Vec(char)` and not AP 6.4.15's `utf8`,
because assignment to a text establishes Normalization Form C and a program
round-tripping somebody's file must not edit it; the result is a production of
`PasError.Fallible`. Those were argued once and are not re-argued here. What is
new is what TOML has and JSON has not.

**A date-time is §6.4.3.4's `TimeStamp` with a nanosecond and an offset beside
it.** `PasTime.ParseStamp` already reads three of the four forms and refuses
exactly the two things it has nowhere to put, so this module scans the lexical
shape, splits off the fraction and the zone, and hands the rest over. The
calendar — the 29th of February in an ordinary year — is spelled once in this
tree and is not repeated. The *spelling* is not borrowed: §6.7.6.9 makes
`date(t)`'s representation implementation-defined and TOML's is RFC 3339's, so
the renderer pads its own digits and a change to what this processor writes
cannot move what this module emits.

**An integer is `integer`.** The format asks a reader to handle the full range
of a signed 64-bit number; `integer` here is -maxint..maxint (ADR-0014). A
value outside it is `errRange` at its own position, and the overflow is
detected *before* the multiplication that would trap. `int64` is not in the
interface: `lib/dialect/README.md`'s second rule keeps a boundary shape out of
one, and a document is not a boundary.

**The redefinition rules are four booleans on a table node**, because they are
about *how* a table came to exist and not about whether it exists. `explicit`,
`closed`, `dotted` and `tabArray`. `Descend` takes a `forHeader` flag and the
two callers' rules are mirror images — a header may pass through a table
another header created implicitly and not through one a dotted key made; a
dotted key the other way round. This is the half of TOML that a lenient reader
gets wrong, and it is most of `tests/dialect/lib_toml_errors.pas`.

**The renderer's claim is the round trip and not fidelity.** Comments are not
in the tree, and a string comes back as a basic string however it was written.
What is guaranteed is that parsing the output and rendering again reproduces
it byte for byte, which `tests/dialect/lib_toml.pas` asserts — `format-check`'s
third claim (ADR-0284) one format over, and the property a program editing a
configuration depends on.

**A refusal carries a byte and `TomlPositionOf` turns it into a line.** A
routine and not a field, so that a caller which never fails never pays for the
scan, and so that a caller reporting a *warning* about a value it read gets the
same conversion.

## What this does not do

**It does not add anything to the language.** Nothing here needed a clause, a
spelling or a compiler change, which is what made it the next thing to write
rather than the next thing to argue about — `PasJson`'s sentence, and it held
again.

**It does not replace the driver's shell reader.** See above.

**It does not preserve a document.** A program that must edit somebody's file
in place is editing bytes and not a tree, and this is the wrong tool for it.

**It does not check that a string's bytes are well-formed UTF-8.** It checks
the grammar and the `\uXXXX` and `\UXXXXXXXX` escapes, refusing a surrogate,
and passes every other byte through unread. `PasUnicode.ToText` is where a
caller gets the other behaviour, where it can see it.

**It does not offer an `int64` reading**, so a document naming a value between
maxint and 2^63 is refused rather than read into a wider type. That is a real
narrowing of the format and it is stated at the routine and in the module
heading.

## Consequences

`lib/` is thirty-three modules, twenty-five of them dialect, thirteen of which
bind nothing. `README.md`'s module table, `lib/dialect/README.md`'s two counts
and the roadmap's are updated — and the README's binding paragraph was found
stale by three while doing it, having said *ten of the sixteen dialect modules*
when twelve of twenty-four bound.

Three cases: `lib_toml` reads one of everything and asserts the round trip,
`lib_toml_errors` holds twenty-six refusals with their positions and twelve
documents that must go on being accepted, and `lib_toml_build` builds a
document, reads it back, and meets the three `errFull` bounds. 91.2% of the
module's 928 statements are run by them.

**Writing it found a defect in `PasJson`**, which is ADR-0359 and landed
first: TOML has literals for `inf` and `nan`, so the second caller of ADR-0309's
shortest-real search is one that hands it the two values the first could not
spell — and the guard against them could never fire. The search moved to
`lib/pastext.pas` in the same change.

**Two defects in this module were found by its own cases and are worth
recording**, both in the shape a reviewer would not have seen. `Run` was a
function reporting through `ok` *and* answering whether it read any digits, and
callers wrote `ok := Run(false)`, which overwrote the refusal — `1_` was
accepted. And `inf` and `nan` are the only values in the format that do not
begin like what they are, so the value dispatcher fell through to *this is not
a value* for both until the two letters were admitted.
