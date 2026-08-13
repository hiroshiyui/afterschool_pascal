# 75. A constant may be nil

Date: 2026-08-13

## Status

Accepted.

## Decision

**`nil` is a constant-expression.** ISO/IEC 10206:1991 §6.7.1 makes it an
`unsigned-constant`, so it is a primary and therefore an expression; §6.8.2
makes a constant-expression any expression that is nonvarying, and nonvarying
is defined as containing no applied occurrence of a variable-identifier, a
schema-discriminant, a bound-identifier, a field-designator-identifier, a
non-static type-name or a program-block-level function-identifier. `nil`
contains no identifier at all. So `const q = nil` is a program the standard
has, and this compiler refused it in both languages.

ISO 7185 §6.3's `constant` is `[ sign ] ( unsigned-number |
constant-identifier ) | character-string`, which has no `nil` in it, so that
half of the refusal was right. The fold is therefore gated on the standard
inside the folder, which is where ADR-0054 gates `Binary` and `Call`, and for
the reason that record gives: the ISO 7185 diagnostic is then unchanged,
because the expression still fails to fold and the caller still says what it
always said.

**The constant keeps the literal's own type, and that is the whole of why the
feature is one arm of one `case`.** §6.4.4's NOTE 2 says the token "does not
have a single type, but assumes a suitable pointer-type to satisfy the
assignment-compatibility rules, or the compatibility rules for operators, if
possible" — which is ADR-0019's nil-type, a pointer with a null domain,
assignable to every pointer-type with nothing assignable to it. One `q`
therefore serves `^integer` and `^char` alike, and nothing outside the folder
had to learn that a constant can be a pointer: assignment, comparison, a value
parameter, §6.6's initial state, a `nil` component of a §6.8.7
structured-value-constructor and §6.8.8's selection of one all work with no
rule of their own.

## Consequences

**The refusal was found by reading Annex A and had been recorded as
outstanding since.** It came out of ADR-0071's production-by-production sweep,
where it was the one finding that did not fit that record's shape — that sweep
was about the *grammar* admitting a construct, and this is §6.8.2's semantic
rule admitting one. It went into `doc/roadmap.md` rather than into the commit,
which is the only reason it survived two more conformance rounds. No corpus
program had ever written it, so every oracle agreed with a compiler that was
wrong: ADR-0067's failure mode, for the fourth time.

**The dump prints the word, not the field.** A pointer constant is `nil` and
can be nothing else, so `symRef` answers `const nil` rather than `intVal` —
which the fold never writes. That is exactly the care the memory case beside
it already takes, and it takes it because the two compilers first disagreed
over a field one of them had not filled in (ADR-0068). Asserting that both
would happen to zero it is the kind of claim `difftest.sh` exists to refuse to
take on trust, and the mutation confirms it: removing the line from the C++
alone makes two files disagree.

**`nil^` acquired a way of being written, and its message was wrong.** The
deref check has always refused the nil-type — there is no domain to name — but
it did so through the general message, "only a pointer can be dereferenced,
found nil", which contradicts itself. §6.4.4 gives a pointer-type one
nil-value and a set of identifying-values, and NOTE 1 draws the consequence:
"Since the nil-value is not an identifying-value, it does not identify a
variable." `nil^` is a pointer with nothing on the other end, not something
that is not a pointer, and the message says so now. Only the `integer` case
had ever been pinned, in `tests/type_errors.err`; a bare `nil^` is not
something a program writes, and until a constant could be `nil` there was no
other way to write one.

That is ADR-0074's lesson in its third form. That record found a message that
*reported* a rule without explaining it; this one is a message that names the
wrong rule, and neither is visible to an oracle that compares two compilers
against each other or a compiler against its own past output.

**Five refusals are pinned and none of them is new.** `new(q)`, `dispose(q)`
and `write(q)` each want a pointer *variable* or a writable type, and a
subrange bound and a case label each want an ordinal constant — where a
constant is now what they want, and an ordinal one is not what this is.
`tests/extended/constnil_errors.pas` exists to record that a constant reaching
four positions no constant had reached needed no rule of its own in any of
them.

### What this does not do

**It does not make a pointer constant anything but `nil`.** §6.4.4 makes every
other value of a pointer-type an identifying-value created by `new`, so there
is no other pointer a constant-expression could name — which is what lets the
dump print a word instead of a value.

**It does not lift ADR-0054's other three refusals.** A real-, set- or
string-valued *operation* still does not fold, for the reasons that record
gives: a real constant is carried as the characters that were written and
never converted, and building characters or a set in the compiler would have
to give the same answer in both of them.
