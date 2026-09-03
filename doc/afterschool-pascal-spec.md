# Afterschool Pascal

**The specification of the Afterschool Pascal programming language**, written
by reference to ISO/IEC 10206:1991 and by stating the differences.

| | |
| --- | --- |
| Status | Draft. Normative for this repository; see 5. |
| Applies to | `pascalc`, every program it accepts |
| Normative reference | ISO/IEC 10206:1991 (Extended Pascal) |
| Governing records | ADR-0117 – ADR-0132, ADR-0135, ADR-0232 |

Since ADR-0232 there is one language and the processor has no mode: `pascalc`
compiles Afterschool Pascal, and this document says what that is.

---

## Foreword

This document is not an International Standard and is not issued by any
standards body. It imitates the structure of the two standards this project
implements so that a reader holding ISO/IEC 10206:1991 finds each addition at
the address of the clause it modifies. The imitation is of *structure and
register only*; no text of either standard appears here, and none may
(see 4.4).

The dialect existed before this document. Thirteen increments landed between
ADR-0114 and ADR-0132, each recorded as a decision with its alternatives and
its cost. What was missing was a statement of the resulting language as a
language — one that a reader could check the compiler against without reading
the compiler. ADR-0135 records why that gap mattered and why it is closed this
way.

## Introduction

ISO 7185 and ISO/IEC 10206:1991 were both implemented completely by this
processor, and until ADR-0232 each was selectable as a mode with an external
specification (see 5.3). There are no modes now, and no external specification
applies to anything this processor accepts.

What survives of them is the containment, and it is the reason this document
can be short: the language **contains** Extended Pascal, so every program that
conforms to ISO/IEC 10206:1991 is an Afterschool Pascal program with the same
meaning (6.0.1). Everything specified here is therefore an *addition*,
and this document is organised as a list of the clauses of ISO/IEC 10206:1991
that the dialect changes or extends.

---

## 1 Scope

This document specifies the programming language Afterschool Pascal. It is
**the** specification of that language: since ADR-0232 no standard governs it,
and the processor has no mode in which some other document applies.

It is written *by reference to* ISO/IEC 10206:1991 and by stating the
differences, and that remains the most economical form — the language contains
Extended Pascal, so the reference imports a complete and precise description of
the greater part of it. What changed with ADR-0232 is the status of the
reference: ISO/IEC 10206:1991 is a **normative reference**, in the ordinary
sense that a specification may be written in terms of another document, and no
longer an obligation this processor is under. Clause 2 says which edition.

It specifies:

- a) the additional lexical tokens (6.1);
- b) the additional types and the operations on them (6.4);
- c) the additional parameter form (6.7.3.9);
- d) the detection of one class of error that ISO/IEC 10206:1991 permits to go
  undetected (6.4.3.4);
- e) the interface to routines not translated by this processor (6.7.7);
- f) the requirement that the components of one program agree on the language
  (6.13.1);
- g) the errors this dialect detects and the actions it takes (Annex A).

It does **not** specify:

- h) the library. `lib/` and `lib/dialect/` are programs written in the
  language this document specifies, not part of it (Annex D is informative);
- i) any representation, storage layout or calling convention, except where a
  requirement of 6.7.7 is stated in terms of one.

**A note on what this document used to say.** Item j) here read *"anything
about ISO 7185 or ISO/IEC 10206:1991 conformance, which is
`doc/implementation-defined.md`'s subject"*, and Annex B tabulated what each
conformance mode said about each dialect construct. ADR-0232 removed the modes
and withdrew the clause 5.1 a) compliance statement, so there is no conformance
to be outside the scope of: this document's subject is now the whole of the
language. Annex B is retained as history and marked accordingly.

## 2 Normative references

- **ISO/IEC 10206:1991**, *Information technology — Programming languages —
  Extended Pascal*. Incorporated in whole (6.0.1).
- **ISO 7185:1990**, *Programming languages — Pascal*. Referenced for context
  only; the dialect does not contain it (5.3, and ADR-0033 for why the two
  standards do not nest).
- **ISO/IEC 9899**, *Programming languages — C*, and **POSIX.1**. Referenced by
  6.7.7, which describes a boundary whose far side those documents specify.
  They were the only external authority this dialect had for any decision until
  6.4.15 was written, and 6.7.7.4 names the one place they were used.
- **ISO/IEC 10646** and **The Unicode Standard**, with its Annex #15
  (*Unicode Normalization Forms*) and Annex #29 (*Unicode Text Segmentation*).
  Referenced by 6.4.15, which specifies a type whose values and whose element
  boundaries those documents define. The version in force is
  implementation-defined and is stated by the processor (6.4.15.12).

  These are the **second** external authority this dialect has, and the only
  one accompanied by machine-readable conformance data: the two properties
  6.4.15 rests on are each published with a test file, so what a text-type does
  is settled by a document written elsewhere rather than by a reading taken
  here (ADR-0189, and ADR-0086 for the argument).

## 3 Definitions

The definitions of ISO/IEC 10206:1991 clause 3 apply. In addition:

**3.1 dialect**: the language specified by this document.

**3.2 conformance mode**: *historical*. Until ADR-0232 the processor had two
modes, `--std=iso7185` and `--std=extended`, in which this document did not
apply. There are none now; the term survives only where Annex B and Annex E
record what those modes did.

**3.3 active variant**: of a variant-part having a tag-field, the variant whose
case-constant-list contains the current value of the tag-field (6.4.3.4).

**3.4 absent**: of a value of an optional-type, the state denoted by `nil`
(6.4.11).

**3.5 slice**: a parameter denoting a sequence of components of an array
belonging to the calling activation, together with the number of those
components (6.7.3.9).

**3.6 foreign procedure, foreign function**: one whose block is not translated
by this processor (6.7.7).

**3.7 unchecked**: of a requirement, one this processor states but does not
enforce, and cannot. Every occurrence is listed in Annex C.

## 4 Definitional conventions

**4.1 Clause numbering.** A clause of this document carries the number of the
clause of ISO/IEC 10206:1991 that it modifies. Where the dialect adds a
subclause to an existing clause, it takes the next number free in that clause —
so 6.4.11 is new because ISO/IEC 10206:1991 clause 6.4 ends at 6.4.10, and
6.7.3.9 is new because its clause 6.7.3 ends at 6.7.3.8.

**4.2 Citation.** A clause of this document is cited **AP §6.4.11**, and a
clause of a standard is cited as that standard's, unprefixed, as everywhere
else in this repository. In `tests/spec/` the tag is `@afterschool:6.4.11`.
A bare `§6.4.11` in any document here means ISO/IEC 10206:1991 or ISO 7185 as
its context says, never this one.

**4.3 Status of a clause.** Each carries one of:

- **[unchanged]** — the clause of ISO/IEC 10206:1991 applies as written and is
  listed only because a reader would look for it here;
- **[extended]** — it applies, with the addition stated;
- **[added]** — there is no such clause in ISO/IEC 10206:1991.

**4.4 Quotation.** No text of ISO 7185 or ISO/IEC 10206:1991 appears in this
document. Where a requirement of one is relevant it is cited by number and
paraphrased in this project's own words, which is `tests/spec/README.md`'s
rule. The copies under `doc/vendor/` are not committed and their notice forbids
inclusion in another product.

**4.5 Verbal forms.** *Shall* states a requirement on a program or on the
processor. *Should* states a recommendation. *May* states a permission. A
requirement this processor does not enforce says so and appears in Annex C; a
requirement stated without such a note is one a probe demonstrates.

## 5 Compliance

### 5.1 Processors

A processor complies with this document when it accepts every program this
document and ISO/IEC 10206:1991 admit, gives each the meaning stated, and
detects the errors of Annex A.

**There is exactly one such processor and it is this one.** That is the honest
statement and it is the whole difference between this document and the two it
amends: a standard is a specification several implementations are measured
against, and this is a specification of one implementation, written down so
that it can be measured against something other than itself.

### 5.2 Programs

A program complies when it uses only the features this document and
ISO/IEC 10206:1991 specify, and when its every execution is free of the errors
listed in ISO/IEC 10206:1991 and in Annex A.

### 5.3 Effect on the conformance modes

*Historical.* This clause required that nothing in this document change what
`--std=iso7185` or `--std=extended` accepted, and that every feature specified
here be refused under both with a diagnostic naming the dialect. It was the
containment guarantee, and `dialect-containment` was the sweep that held it —
the whole of `tests/extended/` compiled a second way and required to behave
identically.

ADR-0232 removed the modes, so the requirement has no subject: there is no
other language for this one to leave undisturbed. What it protected is not
lost but absorbed — the language *contains* Extended Pascal, which is why an
Extended Pascal program compiles unchanged and means the same thing, and that
is now a property of the single language rather than a relation between two.

`tests/dialect/inherits_extended.pas` is retained as the readable statement of
it.

### 5.4 Stability

**This document carries no stability promise.** ADR-0117 declined to invent
versioning before there was anything to stabilise and this does not reverse it:
what is added is that the language at a given version is now *written down*, so
a change to it is visible as a change to this document rather than only as a
change to a compiler. A program requiring fixed behaviour should pin a compiler
version. When stability is promised it will be by a record that says so.

### 5.5 How this document is kept true

Three rules, and the first is the one that matters:

- **a) It is derived from the decision records and verified by probe, never
  from the compiler's source.** A specification written by describing an
  implementation agrees with that implementation by construction and can
  contradict nothing — which is the closed loop ADR-0072's set-packing
  deviation survived inside for four documents and a purpose-written test. Every
  requirement here was written from ADR-0117 – ADR-0132, then a program was
  compiled to find out what the processor does.
- **b) A disagreement between this document and the processor is a defect in
  one of them, and neither is presumed right.** Writing this document found one
  (Annex E).
- **c) A disagreement between this document and an ADR is resolved in favour of
  this document.** ADRs are immutable (ADR-0001) and state what was decided
  when they were written; this states what the language is now. Annex E lists
  every such divergence found.
- **d) Its clauses are cited by scenarios that run.** `tests/spec/` takes
  `@afterschool:<clause>`, and every testable clause of this document is cited
  by at least one scenario but for three; the clause table those citations are
  checked against is **generated from these headings**, so a renamed clause
  fails the traceability gate rather than drifting. The three are 6.13.1 and
  6.11, which each need two program-components and a link where that harness
  compiles a single program, and 6.7.7.6.1, a rule about which record-types
  cross a boundary that the `foreign-layout` gate checks instead. They are
  named rather than counted: a count moves whenever the triage does, and this
  one had been stale through four increments before anybody read it.

  A clause a scenario may **not** cite is one the triage calls `structural` or
  `not-implemented`, and the gate fails on a citation of either. That is what
  held 5.6 while 6.4.15 was written and unbuilt: the whole of it was
  `not-implemented`, so no scenario could assert the text model worked while it
  did not. It works now, nothing here is marked, and 5.6's mechanism is
  vacuous — which is the state it expects to be in between one feature designed
  ahead of its implementation and the next.

  This rule was added after a) to c) and is numbered after them for that
  reason: ADR-0135 cites 5.5 a) by letter, and renumbering would have made an
  immutable record wrong.

### 5.6 A requirement stated ahead of the processor

A clause of this document may state a requirement the processor does not yet
meet at all, rather than one it states and does not check (Annex C). Such a
clause shall be marked **[not yet implemented]** in its heading, and every
clause it contains shall be classified `not-implemented` in
`tests/spec/clauses/triage.tsv`, which makes the traceability gate **refuse** a
scenario citing it — so the document cannot come to claim, through a passing
test, that the feature is there.

The marker and the classification are **compared**, both ways (ADR-0195). A
clause triaged that way with no marker over it would read as though the
processor met it; a clause marked and left `testable` would sit in the pending
queue as ordinary work. One truth in two places with one of them read is what
ADR-0144 found a gate green over, and this is that shape in a document.

5.1 is read accordingly: a processor complies when it accepts every program
this document admits **other than by such a clause**. The list is found by
searching for the marker and **is currently empty**: 6.4.15 was the whole of
it, and the three increments that built the text model took it off a piece at
a time (ADR-0190 – ADR-0192).

An empty list is the state this sub-clause expects to be in. It exists so that
a design may be written down before it is built, which is where the expensive
mistakes are; ADR-0191 records one such clause that was wrong and was found to
be wrong only when someone implemented it.

NOTE — This is deliberately not the shape Annex C has. Annex C entries are
requirements the processor accepts programs under and does not enforce, which
is a soundness gap; this is a feature that is designed, argued and not built,
which is a schedule. Conflating them would let the second hide in the first.
The alternative — leaving a decided design out of this document until it is
implemented — was rejected because the design is the expensive half and the
place a reader looks for what a type means is the clause about that type
(ADR-0189).

---

## 6 Requirements

### 6.0 Relationship to ISO/IEC 10206:1991 [added]

#### 6.0.1 Containment

Every program that conforms to ISO/IEC 10206:1991 shall be an Afterschool
Pascal program, and shall have the meaning ISO/IEC 10206:1991 gives it.

This is the property every clause below is an addition *to*, and it is the one
a new feature may not disturb. It is not a consequence of the design; it is a
constraint on it, and `tests/dialect/inherits_extended.pas` is the program that
holds it.

NOTE — The two conformance modes do not nest in each other, because
ISO/IEC 10206:1991 §6.1.2 reserves word-symbols that a conforming ISO 7185
program may use as identifiers. No such force applies here, the dialect being
this project's own, so it simply contains the standard it amends (ADR-0117).

#### 6.0.2 Selection

There is nothing to select. A source is written in Afterschool Pascal, and the
processor has no option, directive or comment that chooses a language
(ADR-0232).

This clause required `--std=afterschool` until then, and the sentence it
carried — *"a source is written in one language and the option says which"* —
is now true with the option removed rather than because of it.

### 6.1 Lexical tokens

#### 6.1.2 Special-symbols [extended]

The special-symbol `?` is added, and shall occur only as specified in 6.4.11.

**No word-symbol is added.** The word-symbols of Afterschool Pascal shall be
exactly those of ISO/IEC 10206:1991 §6.1.2, and this document shall add none.

NOTE 1 — `?` is a character neither standard admits in any position outside a
character-string (§6.1.9) or a commentary (§6.1.10) — not in an identifier, not
as an operator, and not among ISO/IEC 10206:1991 §6.1.11's lexical
alternatives. Taking it therefore costs the lexis nothing: no
program that compiled before compiles differently, and the two conformance
modes that existed when it was taken each reported it as an unrecognised
character exactly as they had (ADR-0123).

NOTE 2 — The second paragraph is a requirement on this document rather than on
a program, and it is what makes 6.0.1's containment possible. A word-symbol is
the one addition that cannot be made compatibly: reserving a spelling takes it
away from every conforming program that uses it as an identifier, which is how
ISO 7185 and ISO/IEC 10206:1991 came to be non-nested and is the reason a
source is written in one of them rather than compiled in a mode (ADR-0033).

NOTE 3 — What this document does instead is spell each addition in a position
where a conforming program could not have written it. `external` is an
identifier in the directive position (6.1.4), `array of` is two word-symbols in
a juxtaposition that was a syntax error (6.7.3.9.1), `?` is a character no
program could spell, and `int64` is a defining-point in a scope §6.2.2.5 lets any
program shadow (6.4.2.6) — §6.2.2.5 being the clause that excludes an enclosing
region's defining-point where an enclosed one repeats the spelling. §6.1.3 says
only that an identifier may not spell a word-symbol and that a required
identifier has special significance; it is the right citation for *not
reserved* and the wrong one for *shadowable*. The test a new spelling shall satisfy is whether a
conforming program could have written that spelling **in that position**;
where it could, the spelling is a word-symbol however it is implemented.

NOTE 4 — For a statement, that test is answerable with one token of lookahead.
A statement-initial identifier in ISO/IEC 10206:1991 is followed by exactly one
of `(`, `:=`, `[`, `.`, `^`, or a token that ends a statement — `;`, `end`,
`else`, `until` or **`otherwise`**, the last five because §6.9.2.1 admits an
empty statement and §6.9.3.5 makes the separator before a
case-statement-completer optional. A statement form whose second token is none
of those cannot collide with a conforming program.

The list is five tokens and the first draft of this NOTE gave four, omitting
`otherwise`; the processor's own empty-statement follow-set had the same four,
so `case i of 1: otherwise s end` — a legal program — was refused. Both are
corrected. The test the token is compared against is a **token** and not a
spelling: §6.1.11 makes `(.` the token `[`, so a reading of this NOTE over
characters would miss it. A program that takes the name for its own keeps the name
and loses the statement form within that scope, which is the direction this
document requires: the addition yields to the standard it contains (ADR-0140).

NOTE 5 — *historical.* `tests/checks/reserved_words.py` enforced the second
paragraph directly until ADR-0232, asking of every spelling the processor's
lexer knew whether a program might use it as a variable name, and requiring the
Extended Pascal mode and the dialect to give the same answer. With one language
there is nothing to compare against, and the requirement stands on this clause
alone.

#### 6.1.4 Remote-directives [extended]

The directive `external` is added, and shall occur only as specified in
6.7.7.

`external` is spelled as §6.1.4's own NOTE spells it, and it is **not** a
word-symbol: a program may still use `external` as an identifier everywhere
else.

It is **not** a remote-directive, and 6.7.7.1 is where it is defined. §6.1.4's
production is `remote-directive = directive .` and a directive is one
identifier-shaped token, while an external-directive is two — the word and a
mandatory character-string (6.7.7.2). So 6.7.7.1 adds an alternative to
`procedure-declaration` and `function-declaration` rather than a second
remote-directive, which is what its own grammar line says. The first draft of
this clause called it a remote-directive and attributed to §6.1.4's production
an authorisation it does not give (ADR-0144).

NOTE 1 — §6.1.4 carries a NOTE anticipating this extension by name: it
observes that many processors provide a remote-directive spelled `external`
to say that the block belonging to a heading lies outside the program-block,
usually in a library. The dialect's `external` is that extension, and the
spelling is the standard's rather than this project's.

NOTE 2 — The same NOTE recommends that a processor providing the extension
enforce Extended Pascal's type-compatibility rules across the boundary. **This
processor does not, and cannot** — see 6.7.7.8 and Annex C.1. The recommendation
is recorded here because a reader holding the standard will expect it to have
been followed.

NOTE 3 — §6.1.5's NOTE anticipates a differently-placed `external`: an
*interface*-directive, making a whole module's block foreign. The dialect does
not provide that one. The two are not alternatives — a module-level `external`
would describe a translation unit, and 6.7.7 describes a single routine — and a
reader should not read one for the other.

### 6.2 Blocks, scopes, activations, and states

#### 6.2.2 Scopes [extended]

The required identifiers `int64` and `maxint64` are added (6.4.2.6), in the
region ISO/IEC 10206:1991 §6.2.2.10 places the required identifiers in: one
enclosing the program.

They are therefore **shadowable and not reserved**. A program declaring its own
`int64` takes that spelling for its own use, exactly as it may for `integer`.
§6.1.3 is what makes them *not reserved* — "no identifier shall have the same
spelling as any word-symbol", and these are identifiers — and §6.2.2.5 is what
makes them *shadowable*, by excluding an enclosing region's defining-point
wherever an enclosed region repeats the spelling.

NOTE 1 — This is the one addition in this document that takes a spelling away
from a program that does not shadow it, and it is why 6.0.1's test carries a
paragraph for it rather than being left alone (ADR-0128).

NOTE 2 — ISO/IEC 10206:1991 §3.3 defines an **extension** as a modification to
clause 6 "that does not invalidate any program complying with this
International Standard … except by prohibiting the use of one or more
particular spellings of identifiers". A required identifier is therefore an
extension in that standard's own terms, and the exception in §3.3's sentence is
exactly this one. It is the citation NOTE 1's caution wants: what a conforming
program loses is a spelling it must in any case have declared, since it could
not have used `int64` undeclared.

### 6.4 Types and schemata

#### 6.4.2 Simple-types

##### 6.4.2.6 The type int64 [added]

**6.4.2.6.1 Values.** `int64` shall denote a signed integer type whose values
are `-maxint64 .. maxint64`, which is one short of the range representable in
64 bits two's complement: as with `integer` and `maxint`, the most negative
representable value is not a value of the type, so negation cannot overflow.
`maxint64` shall denote its greatest value, `9223372036854775807`.

**6.4.2.6.2 It is numeric and it is not ordinal.** `int64` shall be a numeric
type wherever ISO/IEC 10206:1991 admits one — the arithmetic operators, the
relational operators, `abs`, `sqr`, and the widenings. It shall **not** be an
ordinal type.

It follows, with no rule of its own for any of them, that a value of `int64`
shall not be a case-constant, an array index, a bound of a subrange, the base
type of a set, the control-variable of a for-statement, or an operand of `succ`,
`pred`, `ord`, `odd`, `chr` or `in`.

NOTE 1 — Refusal by construction rather than by enumeration is this project's
preference (ADR-0058) and here it is also forced: every one of those
constructs requires the processor to hold the value, and this processor cannot
(6.4.2.6.5).

NOTE 2 — Each of those contexts reports the message it has always reported for
a type that is not ordinal; not one was written for `int64` (ADR-0136). Until
that record the refusal was a **crash** rather than a diagnostic wherever the
program reached the context with a literal rather than with the type name, and
Annex E.5 keeps the account.

**6.4.2.6.3 Widening.** `integer` shall be assignment-compatible with `int64`,
and `int64` with `real`, in the manner ISO/IEC 10206:1991 §6.4.6 c) already
states for `integer` and `real`. Each widening is exact.

**6.4.2.6.4 Narrowing.** There shall be exactly one narrowing and it shall be
written: `trunc` applied to a value of `int64` yields a value of `integer`, and
is an error when that value exceeds the range of `integer` — which is
§6.7.6.3's own error condition for `trunc`, not one added here.

NOTE — An implicit narrowing would put an unwritten run-time check under an
ordinary assignment; a new required identifier would spend a name for a meaning
a standard one already has (ADR-0128).

**6.4.2.6.5 Denotation, and it is not a constant.** A value of `int64` shall be
denoted by an unsigned-integer whose value exceeds `maxint`.

**No expression of type `int64` is a constant** in the sense of §6.3, and none
is a constant-expression in the sense of §6.8.2. A constant-definition whose
value has that type shall be refused, and the diagnostic shall name the type
and the remedy rather than describing the expression as not constant — which of
a literal would not be true (ADR-0136).

It follows that a value of `int64` shall not be written where §6.3's constant
or §6.8.2's constant-expression is required, whether or not that position also
requires an ordinal.

NOTE — This is a restriction of *this processor* stated as a requirement on a
program, and it is the one place in this document where that is done. The
reason is 5.1's: the processor is written in the language it translates, and
its own `integer` is 32 bits, so there is no value of `int64` anywhere in it to
fold with. A value is carried as the text that was written, all the way into
the emitted code — which is ADR-0025's answer for a real literal, one clause
later and for the same sentence.

**6.4.2.6.6 Input and output.** `read` and `write` shall accept a value of
`int64`, taking for `read` the longest prefix that is a number, as
ISO/IEC 10206:1991 §6.10.1 requires for `integer`.

#### 6.4.3 Structured-types

##### 6.4.3.4 Record-types [extended]

ISO/IEC 10206:1991 §6.5.3.3 makes it an *error* to access a field of a variant
other than the active one, and §3.2 permits a processor to leave an error
undetected. A conforming processor may therefore leave this one undetected, and
this one did, under both of the modes it used to have.

**In the dialect it shall be detected**, by the following two requirements.

**6.4.3.4.1 Activation.** Assigning to a field of a variant shall make that
variant the active one. Where the variant's case-constant-list contains exactly
one case-constant, the tag-field shall be set to it as part of the assignment.

**6.4.3.4.2 Reading an inactive variant.** Accessing a field of a variant that
is not the active one shall be an error, and this processor shall detect it and
terminate the program (Annex A.1).

**6.4.3.4.3 Nested variant-parts.** Where a variant-part is contained in a
variant of another, a field shall be accessible only when every tag-field on
the path from the record to the field selects the variant containing the next.
An assignment reaching such a field shall set every tag-field on that path.

**6.4.3.4.4 A variant-part whose case-constant-list is not a singleton.** Where
the list contains more than one case-constant, an assignment to a field of that
variant shall **not** set the tag-field; the access shall instead be checked
against the tag-field's current value, as a read is.

NOTE — Two labels give the assignment no value to choose between. The rule is
therefore weaker for such a variant and the program shall assign the tag-field
itself.

**6.4.3.4.5 A variant-part with no tag-field.** Where a variant-part has no
tag-field — which ISO/IEC 10206:1991 §6.4.3.4 permits — no requirement of
6.4.3.4 applies, and the variant-part shall behave as ISO/IEC 10206:1991
requires and no more.

NOTE — **This is a hole in the guarantee and is stated rather than hidden.**
There is no tag-field to make authoritative and nothing to check against, so
such a record is an unchecked union in the dialect exactly as in the standard.
Refusing it in the dialect would break 6.0.1; synthesising a hidden tag-field
would change the record's representation and wants its own record (ADR-0118).
It appears in Annex C.

**6.4.3.4.6 Assignment to the tag-field.** A program may assign to a tag-field
directly, and the value assigned shall determine the active variant from that
point. This is unchanged from ISO/IEC 10206:1991.

**6.4.3.4.7 A third field of BindingType [added].** ISO/IEC 10206:1991
§6.4.3.4 requires the record-type denoted by `BindingType` to have fields
associated with the required field-identifiers `name` and `bound`, and its
NOTE 7 permits a processor to provide additional fields as an extension. The
dialect requires one:

There shall be a field associated with the required field-identifier
`writable`, of the type denoted by `Boolean`. Where the file-variable is bound
to an external entity, the value of that field shall be true if and only if the
entity could be opened for writing at the time `binding` was applied. Where the
file-variable is not bound to an external entity, the value shall be false.

NOTE — The field is a report about a moment and not an undertaking, exactly as
`bound` is: an external entity that exists when `binding` is applied may be
gone when `reset` is applied, and one that could be opened for writing then may
not be when `rewrite` is applied. A processor is not required to detect a
condition that arises between the two.

NOTE — §6.7.5.6's NOTE 2 offers `bound` as the way to test a binding, which
serves a program that is about to read: it may ask whether there is anything to
read. A program that is about to *write* had no such question. §6.7.5.2 defines
`rewrite` and `extend` by post-assertions and says that those "imply
corresponding activities on the external entities, if any, to which the
file-variables are bound", leaving those activities implementation-defined
(§5.1 c), E.15) — so what a processor does when the external entity cannot be
created is its own to decide, and terminating the program is a permitted
choice. This processor makes that choice (Annex A.1). The field is what lets a
program avoid it.

##### 6.4.4 Pointer-types [extended]

**6.4.4.1 A domain that binds type discriminants [added].** Where the
domain-type of a new-pointer-type is a schema-name whose schema has
type-valued discriminants (6.4.7.1), the domain-type may be followed by an
actual-type-discriminant-part:

    domain-type = type-name | schema-name [ '(' type-name { ',' type-name } ')' ] .

There shall be exactly as many type-names as the schema has type-valued
discriminants, and each shall denote a type. They shall bind the type-valued
discriminants of that schema, in the order the schema declares them.

The ordinal discriminants of the schema shall remain undetermined by the
domain-type, and shall be determined for each variable created by 6.7.5.3's
`new`, as they are for a domain-type that is a schema-name alone.

NOTE 1 — The spelling is a position, as every construct of this dialect is
(Annex D). ISO/IEC 10206:1991 6.4.4 makes a domain-type a type-name or a
schema-name and admits nothing after either, so a parenthesis here is a
juxtaposition no conforming program can write.

NOTE 2 — Only the type discriminants are written, and this is the whole
purpose of the construct. What the types decide is the *layout* of the
identified variable, which a pointer-type must know; what the ordinal
discriminants decide is its *extent*, which `new` may vary from one created
variable to the next. `^Vec(integer)` is therefore what a schema of one
ordinal discriminant already is, with the component type chosen — and a
routine over it may create, copy and dispose variables of every capacity, for
whichever type the domain named.

NOTE 3 — Which is what a **growable container written once** requires, and
what it could not have. A schema with a type discriminant may not be a
parameter-form (6.7.3.7.1) and may not be a domain-type alone (6.4.7.1), so a
generic routine could reach a container of fixed capacity and no other. This
is the construct that makes `new(p, larger)` writable in a routine that does
not know the element type.

**6.4.4.2 Type identity [added].** Two domain-types naming the same schema
with the same type-names shall determine the same type. 6.4.1's rule is
unchanged and governs the pointer-types themselves: each type-denoter that is
not a type-name denotes its own type, so two variables declared
`^Vec(integer)` separately have two types, exactly as two declared `^integer`
separately do.

##### 6.4.11 Optional-types [added]

**6.4.11.1 The denoter.**

    optional-type = '?' type-denoter .

An optional-type shall denote a type whose values are the values of its
component type together with one further value, **absent**.

The component is a whole type-denoter and not merely a type-identifier, which
is where an optional-type differs from ISO/IEC 10206:1991 §6.4.4's pointer-type.

NOTE — §6.4.4 requires a type-identifier so that a type may name itself and
close a cycle. An optional-type has no cycle to close: it *contains* its
component rather than identifying a variable of it, and a type that were its
own optional could have no size.

**6.4.11.2 The component shall be neither an optional-type nor a file-type.**
`?(?T)` and `?text` shall be refused.

NOTE 1 — One flag answers for a value; two would answer for each other. And a
file is never a value (ISO 7185 §6.4.6 a), ISO/IEC 10206:1991 §6.4.6 a)), so
there is nothing for the flag to be absent from.

NOTE 2 — Neither restriction reaches a **pointer-type**, and `?^T` is
therefore admitted although it has two absent values that are not the same
value: where `q` is `nil` and `op := q`, `op = nil` is false and `op^ = nil` is
true. The redundancy is the program's rather than the language's — a pointer is
`nil` only because something assigned `nil`, and *no pointer was given* and *a
pointer was given and it points nowhere* are two facts. The two checks compose
in the order written, the optional's trapping before the dereference is
reached. It is admitted rather than refused, and named here rather than left to
be discovered, because `nil` then means two things in one expression and a
mistaken count of `^` changes which check applies (ADR-0149).

NOTE 3 — Neither restriction reaches a structured type **containing** a file
either, and it does not need to: such a type is not assignment-compatible with
itself (ISO 7185 §6.4.6 a) with §6.4.3.5), so an optional of one can hold
nothing but `nil` (ADR-0150).

**6.4.11.3 nil.** The value `nil` shall denote the absent value of any
optional-type. `nil` is unchanged in every other respect, including as the
value of a pointer-type (§6.4.4).

**6.4.11.4 The test.** A value of an optional-type shall be comparable with
`nil`, using `=` and `<>`, and with nothing else — not with another value of
its own type.

NOTE — Comparing two optionals would require the component type's own equality,
and a component may be a record-type or an array-type, for which
ISO/IEC 10206:1991 defines none.

**6.4.11.5 Access to the value.**

    optional-value-access = optional-variable '^' .

`o^` shall denote the value of `o`, and shall be the only means of access to it.
Where `o` is absent, it shall be an error, and this processor shall detect it
and terminate the program (Annex A.2).

The check shall be made at every occurrence of `^`, and shall not be omitted on
account of a preceding test.

NOTE 1 — The spelling is §6.4.4's dereference because it is the same question,
and it traps for the same reason §6.5.4's does.

NOTE 2 — **The guarantee is the contrapositive**: a value whose type is not an
optional-type can never be absent. What the type buys is not that the error is
impossible but that it is *localised* to the places the program writes `^`.
Narrowing by flow — recognising that `if o <> nil then o^` cannot fail — is not
performed, and is in Annex C.

**6.4.11.6 Assignment.** An optional-type shall be assignment-compatible from
`nil` and from every type assignment-compatible with its component type.
**No type shall be assignment-compatible from an optional-type.**

It follows, with no rule of its own for any of them, that a value of an
optional-type shall not be an operand of an arithmetic or relational operator
other than as 6.4.11.4 permits, shall not be a write-parameter, and shall not be
assigned to a variable of its component type.

**6.4.11.7 Type identity.** An optional-type shall be a **new-type** in the
sense of ISO/IEC 10206:1991 §6.4.1, and specifically a new-structured-type, so
that clause's rule reaches it: two separately written `?integer` denote two
types.

NOTE — §6.4.1's distinctness sentence is stated of a *new-type*, not of "a
type-denoter that is not a type-name", and the difference is not pedantic: a
discriminated-schema is a type-denoter that is not a type-name and two
occurrences of `string(10)` denote the **same** type, §6.4.7 being carved out
of the rule. The first draft of this clause cited §6.4.1 without saying that an
optional-type is a new-type, which left the grammar with no production
admitting `?T` anywhere and the rule with nothing to attach to (ADR-0144). No exception is made for an optional-type on
account of its resembling a wrapper.

#### 6.4.12 Handle-types [added]

A handle-type denotes a type whose value is an address of storage that a
foreign routine (6.7.7) owns and whose contents this language does not
describe — a `FILE *`, a `DIR *` — together with the foreign routine that
releases that storage. A variable of a handle-type **owns** what it holds:
the value is released when the variable ceases to exist and cannot be copied
out of it (ADR-0151, ADR-0174).

**6.4.12.1 The denoter.**

    handle-type = 'handle' 'external' character-string .

The character-string shall be the foreign name (6.7.7.2) of the routine that
releases a value of the type, and the rules of 6.7.7.2 and 6.7.7.10 apply to
it: it shall not be empty and shall not be a name this processor emits. The
routine shall take one argument, the value, and its result, if any, shall be
ignored.

Neither `handle` nor `external` is a word-symbol. A program in which `handle`
denotes something of its own keeps that meaning in every other position
(ADR-0140); what no conforming program can write is a type-identifier
followed by an identifier and a character-string where a type-denoter ends,
and that is the position this denoter occupies.

A handle-type shall be a **new-type** in the sense of ISO/IEC 10206:1991
§6.4.1, as an optional-type is (6.4.11.7): two separately written denoters
denote two types.

**6.4.12.2 Values and variables.** A variable of a handle-type shall be
**empty** when its block is activated, and shall be empty again whenever the
value it held has been released.

The value `nil` shall denote the empty state of every handle-type. A handle
shall be comparable with `nil` by `=` and `<>` and with nothing else, the
comparison asking whether the variable is empty.

There shall be exactly three forms of assignment to a variable of a
handle-type; the third is 6.4.12.7's and is stated there.

The first is an assignment-statement whose expression is a
function-designator of an external-declaration (6.7.7) whose result type is
the same type. The variable shall first release the value it holds, if any,
and then hold the value the function answered; a null answer leaves it empty.
A function-designator whose result type is a handle-type shall appear in no
other position.

The second is an assignment-statement whose expression is `nil`. The variable
shall release the value it holds, if any, and shall be empty.

NOTE 1 — The second form assigns no *value*: `nil` denotes the empty state and
is not a value of the type, which is why the sentence above already admits it
on the right of `=`. What it gives a program is the release, before the
variable's own lifetime ends. Without it a library closing a stream early had
to assign the answer of a call it knew would fail — `fopen` of the empty path —
for a refused system call, a stale `errno` and a diagnostic naming the wrong
path. `PasStream.Close` and `PasDir.Close` each did that.

NOTE 2 — "Function-designator" is the whole construct and not one spelling of
it: §6.8.5 makes the actual-parameter-list optional, so a parameterless
external-declaration written as a bare identifier is one. Both sentences reach
it. This is stated because a processor implemented the two sentences from two
node kinds and reached only the written-out spelling with either — the
assignment refused `t := make`, and the restriction let it stand anywhere at
all, which is a value nothing owns and therefore a leak (ADR-0179, ADR-0180).

A handle-type shall not be a value of any other kind of assignment, of any
other relational operator, of a value parameter of a routine that is not an
external-declaration, or of a function result that is not an
external-declaration's; and a structured-type having a component of a
handle-type shall be subject to the same restrictions, exactly as
ISO/IEC 10206:1991 §6.4.6 a) and §6.8.3.5 treat a type having a file-type
component.

NOTE 3 — Those are the file variable's restrictions, reached through the same
predicate: §6.4.6 a)'s "permissible as the component-type of a file-type"
excludes a handle as it excludes a file, for the same reason — there is no
copy, the storage and the value being one object.

**6.4.12.3 Release.** The value a variable of a handle-type holds shall be
released by calling the routine 6.4.12.1 names with it, at the first of:
termination of the activation in which the variable exists, including
termination by a `goto` (§6.9.2.4) or `halt` (§6.7.5.7); `dispose` of a
variable containing it; and either assignment 6.4.12.2 describes. A variable
shall release a value at most once.

**6.4.12.4 Crossing the boundary.** A handle-type shall be the result type of
an external-declaration (6.7.7.8), and the null address shall answer the empty
state. A handle-type shall be the type of a value parameter of an
external-declaration (6.7.7.3), the actual-parameter shall be a variable of
that type, and what crosses shall be the value the variable holds — the
variable **lends** it and goes on owning it. It shall be an error for a
variable lent in this way to be empty (Annex A.7). A handle-type shall not be
the type of a variable parameter of an external-declaration.

NOTE 1 — A handle answered by a foreign routine has exactly one place to go,
the variable that will own it, which is why 6.4.12.2 confines the
function-designator to the right side of that assignment: anywhere else there
is nothing to release it, and the address would be held by no one.

NOTE 2 — The one property a C routine cannot be given is NULL where it expects
a stream; it does not report, it dereferences. That is why the empty handle is
an error at the lend rather than a value the far side is left to discover.

NOTE 3 — A handle may be a variable parameter of a routine of this language
(§6.7.3.3), which binds to the variable and not to the value, and may be a
component of a record or an array, which then owns it. What a handle may not
be is a second name for one value: no two variables hold one handle, which is
the whole of what makes 6.4.12.3's "at most once" keepable, and it is the half
of the memory-safety model ADR-0151 calls *lifetime*. The other half,
*aliasing*, is untouched: a handle cannot be stored where two variables could
reach it, because it cannot be copied at all.

NOTE 4 — `tests/dialect/foreign_int64_handle.pas` stands: an `int64` still
carries an address through 6.7.7.8, and this clause takes nothing from that
door. What it adds is a type through which the address is owned, and Annex C.7
is the register of what the other door still costs.

**6.4.12.5 The release-function.** `release` shall be a required identifier
denoting a function whose one actual-parameter shall be a variable-access of a
handle-type. Its activation shall release (6.4.12.3) the value that variable
holds, if any, and shall yield the value the routine 6.4.12.1 names answered.
The variable shall be empty afterwards.

It shall not be an error for the variable to be empty when the function is
activated; the function shall then yield zero and the variable shall remain
empty.

The result type shall be `integer`.

The actual-parameter shall be **threatened** in the sense of
ISO/IEC 10206:1991 §6.9.4 a).

NOTE 1 — Every other release in 6.4.12.3 discards what the closer answered,
and there is nowhere for it to go: a release on the way out of a block, or by
a `goto`, has no statement left to report to. This is that statement. What a
closer answers is not decoration — `pclose` answers a child's wait status and
`fclose` reports a flush that failed — so without this clause a program could
own a foreign resource and never learn whether letting go of it worked
(ADR-0206).

NOTE 2 — This is 6.4.14.6's `take` with the position rule removed, and the
difference is the reason there is none. What `take` yields is an owned value
that must land in a variable of its own type or be held by no one; what this
yields is an `integer`. A function-designator may therefore stand wherever an
integer may be written.

NOTE 3 — The variable being empty afterwards is what keeps 6.4.12.3's "at most
once" without anyone counting: the block's own release finds nothing to do.

**6.4.12.6 The factory [added].** A handle-type shall be the result type of a
function-declaration that is not an external-declaration.

A function-block of such a function shall contain no assignment to the
function-identifier or to its result-variable other than the two 6.4.12.2
admits: `nil`, or a function-designator of a function whose result type is the
same handle-type.

For each activation of such a function, the variable to which the
function-designator's value is assigned shall be the variable that the
assignments within its function-block establish; and 6.4.12.2's requirement
that the value be released before it is stored shall be met by that variable.

NOTE 1 — The value is therefore never held anywhere but in the variable that
will own it. A function answering a handle already receives the address of the
variable its result is to occupy, that type being one whose values do not
travel in a register, and the assignment inside the function-block is
6.4.12.2's assignment made through that address. There is no temporary to
release and no moment at which two names identify one resource, which is what
the last sentence of 6.4.12.2 exists to prevent.

NOTE 2 — And a function whose block assigns its result from another such
function passes the address on unchanged, so the property holds at any depth.

NOTE 3 — The result type shall be a handle-type and not a type having a
component of one, which 6.7.2's own restriction continues to refuse: a handle
result has exactly one destination and its address can be given to the
function, and a structured result has no such destination for each of its
components.

NOTE 4 — Answering `nil` is what makes the construct usable rather than a
regression. A producer that could not report a failure would be worse than the
`var` parameter and status code it replaces, and 6.4.12.2's second form is
already the empty state written as a value. Where a reason for the failure is
wanted as well, 6.4.13's fallible-type is the shape — and 6.4.13.1 does not
admit a handle as its value-type, so that remains unavailable.
Before this clause a program wanting a closer's result had to call the closer
itself through 6.4.12.4's lend, which leaves the variable owning an address
already released and the block closing it a second time.

NOTE 4 — Yielding zero for an empty variable is the assignment of `nil`
(6.4.12.2) rather than `dispose` of nil (ISO/IEC 10206:1991 §6.7.5.3): a
program that released nothing has nothing to be told about. A caller that must
distinguish "closed, and the closer said zero" from "there was nothing to
close" has the variable itself to ask, before.

**6.4.12.7 The move [added].** An assignment-statement whose expression is
`take` (6.4.14.6) applied to a variable-access of the same handle-type shall be
the third form of 6.4.12.2's assignment.

The variable named by the actual-parameter shall be emptied, and shall be
emptied **before** the target variable releases the value it holds. The target
shall then hold the value the actual-parameter's variable held, which shall be
the empty state where it held none.

`take` shall be applicable to a variable of a handle-type and of an
owned-pointer-type (6.4.14.6) and to no other type. It shall not be applicable
to a file-variable.

NOTE 1 — 6.4.14.6 admitted `take` for an owned pointer alone, and the reason
given there was that nothing else has a value one variable can stop holding.
That was written of the three affine kinds together and is true of only one of
them. A handle is one word the processor holds on the program's behalf, exactly
as an owned pointer is one word of the heap; a **file-variable** is neither,
being several storage units the processor is holding, and there is no value in
one for a variable to stop holding. So the rule is stated over the two kinds
rather than over affineness, which would reach the file.

NOTE 2 — The order in the second paragraph is the whole of what makes a
self-move work. `h := take(h)` empties the variable, so the release finds
nothing and the value returns where it was; releasing first would close the
very handle being moved. It is 6.4.14.6's own order stated for this type, and
that clause's reason — a target reached through the source must not be built
into a cycle nothing owns — applies unchanged.

NOTE 3 — What this clause buys is that a handle may **leave** the variable that
owns it without being released, which no other construct permits: 6.4.12.4's
lending crosses a value for the duration of a call and leaves the ownership
where it was. A routine may therefore be handed a variable to fill and another
to empty, and at no moment do two variables hold one value.

NOTE 4 — It is a prerequisite of a construct that does not exist when this
clause is written: a task cannot be **given** a socket or a stream until a
handle can move. It is stated separately because it is a rule about handles and
is complete without one (ADR-0201, ADR-0267).

#### 6.4.13 Fallible-types [added]

A fallible-type denotes a value that is either an outcome of one type or a
reason it is not, and says which. It is the shape ISO/IEC 10206:1991 gives no
name to and that a program otherwise writes out per payload type (ADR-0120,
ADR-0176).

**6.4.13.1 The denoter.**

    fallible-type = type-denoter '!' type-denoter .

The type-denoter before the `!` is the **value-type** and the one after it the
**cause-type**. Neither shall be a fallible-type, and neither shall be or
contain a file-type (§6.4.3.5) or a handle-type (6.4.12).

`!` shall not be a word-symbol; it is a character neither ISO 7185 nor
ISO/IEC 10206:1991 admits in any position outside a string or a comment, so no
conforming program can contain one, so taking it costs the lexis nothing
(ADR-0140, and 6.4.11's `?` for the same reason).

A fallible-type shall be a **new-type** in the sense of ISO/IEC 10206:1991
§6.4.1, as an optional-type and a handle-type are: two separately written
denoters denote two types.

**6.4.13.2 What it denotes.** A fallible-type shall denote the record-type

    record case ok: boolean of true: (val: T); false: (cause: E) end

where T is the value-type and E the cause-type, and it shall be that type in
every respect this document does not amend: it is a record-type, it has that
type's representation, and 6.4.3.4's requirement that a read of a field of an
inactive variant be detected applies to it unchanged.

NOTE 1 — That is the whole of the type's semantics, and it is deliberate. The
tag being authoritative is 6.4.3.4's rule, not a new one; the copy, the value
parameter, the function result and the layout are the record's.

NOTE 2 — The field-identifiers are this language's and not the program's, and
a program cannot choose others. `value` is a word-symbol of
ISO/IEC 10206:1991 §6.1.2 and could not have been one of them.

**6.4.13.3 Assignment.** A value of the value-type and a value of the
cause-type shall each be assignment-compatible with the fallible-type, and the
assignment shall be equivalent to an assignment to `val` or to `cause`
respectively — so the outcome is decided by which type the value has, and the
tag by 6.4.3.4's own rule.

Where a value is assignment-compatible with **both** types, the assignment
shall be an error detected by the processor: it names no outcome. Assignment
to `val` or to `cause` is unaffected, and is how such a type is used.

Nothing other than the two types and the fallible-type itself shall be
assignment-compatible with a fallible-type, and a fallible-type shall be
assignment-compatible with nothing but its own type.

**6.4.13.4 The tag.** `ok` shall not be threatened (§6.9.4): it shall not be
assigned to, read into, or passed as a variable parameter. It shall be
readable.

NOTE 3 — This is the one requirement here that is not the record's. A record a
*program* declares may have its tag assigned, and 6.4.3.4 honours it — the arm
changes and a later read of the other arm is detected. For this type that
would claim an outcome no assignment wrote, and the next read of `val` would
yield the storage rather than being detected.

NOTE 4 — Propagation is 6.8.9's try-expression, which takes the value of a
fallible-type and leaves the enclosing function where it is a cause. It needed
an early exit, which neither standard has, and so arrived after 6.7.5.9
(ADR-0176, ADR-0177, ADR-0178).

**6.4.13.5 An affine value-type [added].** The value-type of a fallible-type
may be a type that is or contains a file-type (§6.4.3.5), a handle-type
(6.4.12) or an owned-pointer-type (6.4.14). The cause-type shall not be.

For a fallible-type whose value-type is such a type, the storage of the two
variants shall not overlap; and for every other fallible-type, and for every
other record-type, 6.4.3.4's storage requirements apply unchanged.

A variable of such a fallible-type shall be assigned only:

  a) a value of its value-type, in the form 6.4.13.3 admits, where 6.4.12.2 or
     6.4.14.6 admits that value in an assignment to a variable of the
     value-type; or

  b) a value of its cause-type, in the form 6.4.13.3 admits; or

  c) the value of a function-designator of a function whose result type is
     that same fallible-type.

For the last of these, the value shall be established in the variable assigned
to, and no other variable of that type shall be established by that
activation.

It shall be an error for the operand of a try-expression (6.8.9) to possess
such a type.

NOTE 1 — This is what makes `function Open(p: Path): Stream ! ErrorCode`
writable, which is the shape every producer in a library of this language
wants and the one that was refused. A factory answering only 6.4.12.2's `nil`
would say that something went wrong and never what, which is worse than the
variable-and-status-code it replaces.

NOTE 2 — The arms of a variant-part share storage, and that is why 6.4.3.4
refuses a file in one: the storage of a file is its own, and a value written
into the other variant would overwrite part of it while the activation still
holds it. Laying the two variants of *this* record beside one another removes
the sharing and with it the reason for the refusal. Nothing else about the
type changes — the tag is still authoritative, 6.4.3.4.2's detection of a read
of an inactive variant applies unchanged, and every fallible-type whose
value-type is not affine has exactly the representation it had.

NOTE 3 — The cause-type is refused for the reason the value-type is admitted.
A cause is carried out of a function by 6.8.9's try-expression, which is a
copy, and an affine value has none. The same sentence is why a
try-expression's operand may not possess this type: 6.8.9.4 makes the
expression denote the *value*, and denoting an owned value would be copying
it. A program tests `ok` instead, which is what it would do with the handle in
any case.

NOTE 4 — c) is 6.4.12.6's factory one clause out, and requires the same thing
of the processor: the function is given the address of the variable its result
is to occupy, and what its own block establishes is established there. There
is no copy at the assignment and no moment at which two variables identify one
resource.

#### 6.4.14 Owned-pointer-types [added]

An owned-pointer-type denotes a type whose values identify variables created by
`new` (§6.7.5.3), and whose variable **owns** the variable it identifies: that
variable is disposed when the pointer's own variable ceases to exist, and the
value cannot be copied. It is 6.4.12's ownership applied to storage this
language allocates rather than to an address a foreign routine owns, and it is
what gives a created variable an owner at all — a variable created by `new` and
identified by an ordinary pointer-type (§6.4.4) exists in no activation, so
6.4.12.3's release list reaches nothing of it and a program that does not
dispose it never releases what it holds (ADR-0181).

**6.4.14.1 The denoter.**

    owned-pointer-type = 'owned' '^' type-identifier .

`owned` shall not be a word-symbol. A type-denoter is complete after a
type-identifier, so no conforming program can write `^` in the position
following one, and the two tokens together are a juxtaposition the conformance
modes reject as a syntax error — 6.4.12.1's test and 6.7.3.9's, asked of the
juxtaposition rather than of a spelling (ADR-0140).

The domain shall be a type-identifier and not a type-denoter, for §6.4.4's own
reason: the name may be one whose defining-point is later in the same
type-definition-part, which is what lets a type own a variable of its own type.

**6.4.14.2 Restrictions on the domain and on the container.** The domain shall
not be a schema-name (§6.4.7). An owned-pointer-type shall not be, nor be
contained by, the type of a field of a variant-part (§6.4.3.4).

**6.4.14.3 Ownership.** A value of an owned-pointer-type shall not be copied. It
follows from §6.4.6 a) and this clause that such a type, and any type
containing one, shall not be the type of an assignment's target or source, of a
value parameter, of a function result, or of an operand of a relational operator
other than as 6.4.14.4 admits.

The variable a value identifies shall be disposed, and every value owned within
it released, at the first of: termination of the activation in which the
pointer's variable exists, including termination by a `goto` (§6.9.2.4) or
`halt` (§6.7.5.7); `dispose` of a variable containing the pointer's variable;
`new` applied to the pointer's variable; `dispose` applied to it; and an
assignment to it (6.4.14.6). A variable shall be disposed at most once.

A variable of an owned-pointer-type shall have the value `nil` on the
commencement of the activation in which it exists, and on the creation of a
variable containing it.

**6.4.14.4 Comparison.** A value of an owned-pointer-type shall be an operand of
`=` and `<>` only, and the other operand shall be `nil`.

**6.4.14.5 Type identity.** An owned-pointer-type shall be a **new-type** in the
sense of ISO/IEC 10206:1991 §6.4.1, as 6.4.11, 6.4.12 and 6.4.13 are: two
separately written `owned ^T` denote two types, and a program that lends one to
a routine shall declare a type-identifier for it.

**6.4.14.6 Move.** `take` shall be a required identifier denoting a function of
one actual-parameter, which shall be a variable-access of an owned-pointer-type
and shall not be threatened (§6.9.4). The function-designator shall stand only
as the whole right side of an assignment-statement whose target is a
variable-access of the same type, or as an actual-parameter of a
spawn-statement (6.9.3.12) corresponding to a formal parameter of a
handle-type (6.7.8.1); it shall be the only value of an owned-pointer-type an
assignment-statement admits.

The assignment shall, in this order: obtain the value the actual-parameter's
variable holds; make that variable empty; release the value the target holds
(6.4.14.3); and make the target hold the obtained value.

NOTE 1 — The order is normative and not an implementation's convenience. Where
the target is a variable-access reached *through* the actual-parameter's
variable — `p^.next := take(p)` — obtaining and emptying first makes the target
undefined, so the assignment attempts a dereference of `nil` and the error of
§6.5.4 is reported. Any other order would make the identified variable its own
successor, held by no variable and reachable by no release.

NOTE 2 — `n := take(n^.next)` is therefore a complete removal of the first
element of a chain: the actual-parameter is the identified variable's own
field, so releasing what the target held disposes that variable alone, its
successor having been emptied out of it, and the successor becomes the target's
value.

NOTE 3 — Without this clause an owned-pointer chain admits insertion and
removal at its far end only, both by recursion, and no operation at all in
constant time: `n := fresh` and `fresh^.next := n` are each a copy, which
6.4.14.3 forbids. That was found by writing a list over 6.4.14 and is why this
clause exists (ADR-0182).

NOTE 4 — `take` of an empty variable is empty and is not an error. A move that
moves nothing is the assignment of `nil` this type otherwise has no spelling
for, and 6.4.14.3's release still applies to what the target held.

NOTE 5 — The operation of this clause applies to a handle-type as well, and
6.4.12.7 is where it is stated: what is written there is this clause read one
type over, and the two are one rule (ADR-0267). The second position named
above is a handle's alone — nothing spawns with an owned pointer, an owned
pointer not being transferable (6.4.16.3) and not being a handle (ADR-0302).

NOTE 6 — The second position is the only place in this language where an
affine value leaves a variable other than by an assignment, and it is admitted
for the reason the assignment is: what the actual-parameter's variable held is
obtained and the variable made empty *before* the activation the value crosses
into is commenced, so at no moment do two activations hold one value. A copy
in that position would leave two owners and two releases, which is what
6.4.12.3 exists to prevent.

NOTE 6 — `nil` is not admitted, and the asymmetry with 6.4.12.2 — where a
handle-type variable *is* assigned `nil`, and that assignment is its release —
is deliberate rather than an omission. An owned pointer already has a statement
that releases it, `dispose` (§6.7.5.3), and a handle has none; admitting `nil`
here would give one operation two spellings, and admitting it as a plain store
would leave the identified variable held by no variable, which 6.4.14.3
forbids. A processor is therefore expected to name `dispose` where it reports
this (ADR-0307).

NOTE 1 — What an owned pointer may be is a variable parameter (§6.7.3.3), which
binds to the variable and not to the value, and a component of a record or an
array, which then owns it. Those two are the whole of how a program reaches what
it owns: a list is traversed by a recursive procedure taking `var` and not by a
loop assigning a second pointer, because a second pointer is a copy. This is
6.4.12's NOTE 3 with one addition — a handle cannot be reached through a
container it owns, and this can, which is why 6.4.14.3's release is recursive
and the handle's is not.

NOTE 2 — The release is a generated routine per domain type, not straight-line
code at each release point: a type may own a variable of its own type, so the
depth is the program's and not the translation's. A list long enough will
therefore exhaust the stack on release, as it would on any recursive traversal.

NOTE 3 — This clause settles nothing about *aliasing*, and is available for that
reason. ADR-0151 divides the memory-safety model into lifetime and aliasing and
records that the second becomes decidable only at the first construct admitting
two live names for one owned value. An owned pointer admits none — it cannot be
copied at all — so it extends the lifetime half to the heap without deciding
between ARC and borrowing, which is 6.4.12's move a second time.

NOTE 4 — 6.4.14.3's release on termination by a `goto` or a `halt` is the one
requirement of this clause this processor does not fully meet: it releases every
file and handle inside the owned variable and does not dispose the storage.
Annex C.11 is the entry, and ADR-0181 has why the alternative was declined.

NOTE 5 — An ordinary pointer-type (§6.4.4) is unchanged, and `dispose` of one
goes on being what a program says. This clause adds a type; it withdraws
nothing, and 6.4.4's use-after-dispose through a second pointer stays what
ADR-0019 made it.

#### 6.4.15 Text-types [added]

A text-type denotes a type whose values are bounded sequences of bytes
constituting well-formed UTF-8 in Unicode Normalization Form C, and whose
**elements** are the extended grapheme clusters those bytes represent. It is
what a program holds when it means the characters of a text rather than the
octets carrying them; ISO/IEC 10206:1991 §6.4.3.3's string-types remain what a
program holds when it means the octets, and are unchanged (ADR-0189).

This clause is implemented in full (ADR-0189 – ADR-0192): what it states is
what the processor does.

**6.4.15.1 The denoter.** `utf8` shall be a required identifier denoting a
schema (§6.4.7) of one discriminant, whose identifier shall be `capacity`, as
the required schema `string` has.

    text-type = 'utf8' '(' discriminant ')' .

The discriminant shall be of an integer-type and shall be greater than zero. It
shall be the capacity of a value of the type **in bytes**, and not in elements:
an element is a sequence of scalar values of no fixed length, so a capacity
counted in elements would not determine the storage a variable occupies.

`utf8` shall not be a word-symbol, and a program declaring an identifier with
that spelling shall be admitted, §6.1.3 and §6.2.2.10 placing the required
identifier in a scope enclosing the program (ADR-0140).

**6.4.15.2 The invariant.** The bytes a value of a text-type comprises shall be
well-formed UTF-8, and shall be in Normalization Form C as
ISO/IEC 10646 and the Unicode Standard Annex #15 define it. Every operation
this clause admits shall preserve that, and no operation shall be admitted
which does not.

NOTE 1 — The invariant is on construction rather than on use, and that is what
makes 6.4.15.6's equality byte equality. See NOTE 6.

**6.4.15.3 The element sequence.** The elements of a value of a text-type shall
be the extended grapheme clusters its bytes represent, as Unicode Standard
Annex #29 defines them, in order.

The **type** of an element shall be a text-type. An extended grapheme cluster
comprises one or more scalar values and has no upper bound in the general case,
so it is not a value of a simple type: it has no ordinal, and `ord`, `succ`,
`pred`, `chr` and a case-statement selector shall not be applied to it.

NOTE 2 — This is the structural consequence of the unit and it reaches
everywhere. There is no character type in this model; the smallest thing a
program can hold is a text of one element, and the control variable of
6.4.15.9's iteration is therefore a text.

**6.4.15.4 Type identity.** A text-type shall be the type a schema produces
(§6.4.7), and two occurrences of `utf8` with equal discriminants shall denote
the same type.

NOTE 3 — This is `string`'s rule and not the new-type rule 6.4.11.7, 6.4.12.1,
6.4.13 and 6.4.14.5 each state for the four preceding added types. Those are
constructed at their denoter and have no name to equate; a text-type is
produced by a schema, and the schema is what its identity comes from.

**6.4.15.5 Assignment and conversion.**

A text-type shall be assignment-compatible from a text-type, from a string-type
(§6.4.3.3) and from the char-type. A variable-string-type (§6.4.3.3.3) shall be
assignment-compatible from a text-type.

Where the value assigned is not of a text-type, its bytes shall be validated
and converted to Normalization Form C where the assignment occurs. It shall be
an **error** (Annex A) if they are not well-formed UTF-8, and an error if the
converted value does not fit the capacity of the target. Where the value is of
a text-type the second error alone applies, 6.4.15.2 having established the
first already.

NOTE 4 — Ill-formed input is an *error* and not a violation, and the assignment
is admitted rather than refused. That is §6.4.6's own model for a constrained
type and ISO 7185's for a subrange: `x := n` into a `1..10` is a legal
assignment that stops the program when the value is out of range, and a text's
invariant is a constraint on the value like any other. It is also what makes
this type usable before a library exists to fill one — the alternative,
refusing every assignment that could fail and routing each through a fallible
function, would leave a text able to hold nothing but character-strings.

NOTE 5 — This clause said the opposite until the type was implemented, and
Annex E.12 records the change. The refusal was argued from "invalid input from
the outside world is not an error in the program", which is true and is not a
reason to refuse an assignment: it is a reason for a program that expects
invalid input to use a conversion that reports instead, and that conversion
remains what 6.4.13's fallible-type is for.

NOTE 6 — The target is confined to a *variable*-string in the other direction
because a fixed-string-type would want §6.4.6's padding to a length, and a
length in characters is a question a text does not answer.

NOTE 7 — There is therefore exactly one door into a text value, and every
reader past it may assume 6.4.15.2. That is what lets 6.4.15.6 compare bytes.

**6.4.15.6 Comparison.** The relational operators of §6.8.3.5 shall be
applicable to two operands of text-types, and to one operand of a text-type and
one character-string, and shall compare the byte sequences of the operands
lexicographically as unsigned values.

A text-type and a string-type shall not be operands of one relational operator.

NOTE 6 — `=` over text-types is therefore **canonical equivalence**, and this
is the whole benefit of 6.4.15.2's invariant. `'é'` written as one scalar and
`'é'` written as a base character and a combining acute accent are one value of
a text-type and compare equal, where the corresponding string-types differ in
length and in every byte after the first. Nothing is decoded at the comparison.

NOTE 7 — The order the other four operators give is by scalar value and is
**not a collation**. It is total, stable and independent of any locale, and it
sorts `Z` before `a`; it says nothing about where `ä` belongs in any language.
A collation requires locale data this language does not have and does not
consult (ADR-0189).

NOTE 8 — A text-type and a string-type are kept apart here for the reason they
are kept apart in 6.4.15.5: one is normalised and the other is not, so a
comparison between them would answer a question neither operand's type asks.

**6.4.15.7 Concatenation.** The string operator `+` of §6.8.3.6 shall be
applicable where either operand is of a text-type and the other is of a
text-type or is a character-string, and shall yield a text-type.

The result shall be the Normalization Form C of the concatenation of the
operands' scalar sequences, and **not** the concatenation of their bytes.

The type of the result shall be a text-type having no capacity, as
§6.8.3.6's canonical-string-type has none: what `+` yields shall fit any
target, and 6.4.15.5's store is where the capacity is checked.

A *string* operand shall be refused, for 6.4.15.6's reason: one operand in
normal form and one not would need a conversion, and this operator has nowhere
to report that it failed.

NOTE 9 — The distinction is normative and is not an optimisation the processor
may take back. Normalization Form C is not preserved by concatenation: where
the left operand ends in a base character and the right begins with a combining
mark, the two compose across the join, and appending the bytes would yield a
value violating 6.4.15.2 and unequal to the value the same text written whole
would have. An implementation may examine only the neighbourhood of the join,
each operand being normalised already.

**6.4.15.8 Enquiries.** `length` (§6.7.6.7) applied to a value of a text-type
shall yield the number of its elements. The schema-discriminant `capacity`
(§6.8.4) of a text-type shall yield the number of **bytes** the type's values
may comprise.

NOTE 10 — `length` counts elements and `capacity` counts bytes, so the two are
in different units and `length(t) <= t.capacity` is true but not tight. That is
a property of the model rather than an inconsistency: a text of one element may
occupy any number of bytes. A program needing the byte count holds the bytes,
which is what a string-type is for.

NOTE 11 — `length` over a text-type is not required to be, and in this
processor is not, an operation of constant time.

**6.4.15.9 Access to the elements.** A text-type shall not be an array-type. An
indexed-variable (§6.5.3.2) and a substring-variable (§6.5.6) shall not be
formed from a variable of a text-type, and `substr` and `index` (§6.7.6.7)
shall not be applied to one.

The elements shall be reached by iteration. The set-member-iteration of
§6.9.3.9.3 shall admit an expression of a text-type where it admits a
set-expression, and the control-variable shall then be of a text-type and shall
take the value of each element of the operand in turn. It shall be an error if
an element does not fit the capacity of the control-variable.

    for g in t do ...

NOTE 12 — The refusal of an integer index is the substance of this clause and
not an omission. Three sequences are present in one value — bytes, scalar
values and elements — and an integer names a position in one of them, so an
index would have to choose, silently, which; and an index over the elements
cannot be a constant-time operation over this representation. An index that is
neither what the reader expects nor cheap is the defect the type is introduced
to remove, and offering it in the syntax every Pascal program already uses for
a string would guarantee it went unnoticed.

NOTE 13 — Iteration by type rather than by a new syntax follows the rule that
a construct is distinguished by asking the symbol and not the parser: the
operand's type is what selects between §6.9.3.9.3's set-member-iteration and
this, and no word-symbol is reserved (ADR-0140).

**6.4.15.10 Writing.** A value of a text-type shall be a write-parameter of a
textfile, and the bytes written shall be the value's bytes. Where a field-width
is present the value shall be padded on the left with spaces to that number of
**elements**, and shall not be truncated.

NOTE 14 — The width is in elements and is therefore not the number of columns
a display device gives the value: a character of East Asian wide width occupies
two and a combining mark occupies none. Display width is a further property of
the Unicode Character Database this language does not provide (ADR-0189).

**6.4.15.11 Read.** A value of a text-type shall not be a read-parameter.

NOTE 15 — Reading yields bytes, whose validity is not the program's to
guarantee, so the conversion belongs where a failure can be reported —
6.4.15.5's fallible function, applied to what was read into a string-type.

**6.4.15.12 The version of the Unicode Standard.** The version of the Unicode
Standard and of ISO/IEC 10646 whose data determines Normalization Form C
(6.4.15.2) and the extent of an extended grapheme cluster (6.4.15.3) shall be
implementation-defined, and the processor shall state it.

NOTE 16 — A processor is not required to track the current version. It is
required to say which one it is, because the elements of a value and the
equality of two values both move with it, and a program whose behaviour depends
on that is entitled to know what it was compiled against.

NOTE 17 — The two properties this clause rests on are each published with a
conformance file — `GraphemeBreakTest.txt` and `NormalizationTest.txt` — so
this is the one area of this language whose correctness is settled by an oracle
written by neither this processor's author nor its specification's. ADR-0086's
argument for the BSI suite, in the place it is needed most.

#### 6.4.7 Schemata [extended]

**6.4.7.1 Type-valued discriminants [added].** A discriminant-specification
shall admit the word-symbol `type` where ISO/IEC 10206:1991 §6.4.7 requires an
ordinal-type-name:

    discriminant-specification = identifier-list ':'
                                 ( ordinal-type-name | 'type' ) .

Each identifier of such a discriminant-specification shall denote, throughout
the schema's type-denoter, the type named by the corresponding
actual-discriminant of the tuple the type is produced with (§6.4.8). The
corresponding actual-discriminant shall be a type-name and shall not be an
expression.

The domain of a schema having a type-valued discriminant shall be the set of
tuples whose component in that position is a type. Two tuples shall have equal
components in such a position when, and only when, they name the **same type**
in the sense of ISO/IEC 10206:1991 §6.4.1 — so two occurrences of `Vec(T, 4)`
denote the same type exactly when the two occurrences of `T` do, and two
type-denoters written alike but separately denote two types and produce two.

A schema-name denoting a schema that has a type-valued discriminant shall not
be a parameter-form (§6.7.3.2); a parameter of such a schema's type shall be
written with its actual-discriminant-part.

`type` shall not become a required identifier, an ordinary identifier, or a
word-symbol of the dialect that it is not already of ISO 7185 §6.1.2 and
ISO/IEC 10206:1991 §6.1.2. It is admitted in one position and is a word-symbol
of both standards there and everywhere else.

NOTE 1 — A schema parameterises a type by a *value* in ISO/IEC 10206:1991,
which is what makes `list of T` unsayable there and what a library here has
been paying for: `PasVector` holds integers, `PasStrVec` and `PasList` hold
strings, `PasMap` maps a string to an integer, and `PasSort` avoids the
question entirely by taking two procedural parameters and never seeing an
element. Four of those are one data structure written once per element type.

NOTE 2 — This clause parameterises a *type* and not a routine. A schematic
formal parameter (§6.7.3.2) reads its discriminants from a descriptor the
actual brings, which is what lets one compiled body serve every tuple; a type
is not something a descriptor can carry, since the body's layout differs for
each. So a routine generic in `T` has to be translated once per `T`, and that
is a separate construct with its own clause: 6.7.3.10's type parameter, whose
6.7.3.10.2 states the per-tuple translation this note says is required. A
routine over a *schema* still names the types it is over — but 6.7.3.10.4 lets
the activation leave them out where the other actuals determine them.

NOTE 3 — The spelling is a *position* and not a word (ADR-0140): §6.4.7
requires a type-identifier there and `type` is a word-symbol of both standards,
so no conforming program can have written it in that place. Annex B records
that the two conformance modes refuse it differently — ISO 7185 has no schema
at all and stops at the formal-discriminant-part, where Extended Pascal parses
the schema and stops at the word-symbol.

#### 6.4.5 Compatible types [extended]

Two slices (6.7.3.9) shall be compatible when their component types are the same
type. Their lengths shall not be required to agree.

NOTE — This does not qualify ADR-0017's name equivalence, which is a rule about
types a program can write. A slice type has no name, cannot be declared, and is
constructed afresh at each designator, so there is nothing to name-equate; and
the extent is exactly what a slice exists not to fix.

#### 6.4.6 Assignment-compatibility [extended]

Extended by 6.4.2.6.3 (`int64`) and 6.4.11.6 (optional-types).

No value shall be assignment-compatible with a slice (6.7.3.9), and a slice
shall not be assignment-compatible with any type.

NOTE 1 — Like 6.8.3.5, this is a restriction that exists because 6.4.5 is an
extension. ISO/IEC 10206:1991 §6.4.6's six alternatives reach a slice through
none of them — it is not ordinal, not a set, not a string-type or the char-type,
and two slices are never the same type — so this states what that clause already
implies, in the one place a reader will look for it.

It is stated rather than left implied because the processor did not enforce it:
`p := r` between two slice formals was accepted and copied descriptor-sized
bytes between the two arrays' *contents*, writing outside the shorter one and
exiting 0 (ADR-0143).

NOTE 2 — A slice reaches its callee by 6.7.3.9.3, which is a rule about
parameters and not about assignment. Nothing else in this document gives a
slice a way to travel.

#### 6.4.9 Type-inquiry [extended]

The type-inquiry-object shall be extended to a variable-access:

```
type-inquiry-object = variable-access .
```

The type denoted by a type-inquiry shall be the type possessed by the
variable-access contained by the type-inquiry.

The variable-access shall not be evaluated, and no expression contained by it
shall be evaluated.

The type-inquiry-object shall denote a variable-access and not a
function-access (ISO/IEC 10206:1991 §6.8.6) or a constant-access (§6.8.8).

The type denoted shall not be the canonical-string-type (§6.4.3.3.1).

NOTE 1 — ISO/IEC 10206:1991 §6.4.9's object is `variable-name |
parameter-identifier`, and §6.5.1's variable-name is `[
imported-interface-identifier '.' ] variable-identifier` — a name. The other
five variable-accesses are outside that clause, so this is an extension and not
a correction; a conformance mode refuses each of them and names this mode
(Annex B).

NOTE 2 — The restriction of §6.4.9 on a parameter-identifier applies to the
*root* of the variable-access, which is a name exactly as that clause's own
object is. So does ISO/IEC 10206:1991 §6.7.3.1's prohibition on an applied
occurrence of the parameter-identifier: `x: type of x^.f` names x.

NOTE 3 — The type of an indexed-variable does not depend on the index, so
requiring the object not to be evaluated costs nothing. An expression contained
by the object is still subject to every rule about its own well-formedness; it
is checked and never computed.

NOTE 4 — The canonical-string-type is excluded because no variable may possess
it: it is a value with no capacity (§6.4.3.3.1), and the only variable-access
that possesses one is a substring-variable (§6.5.6). Naming the string itself
is what a program wants there.

NOTE 5 — A slice-type (6.7.3.9) and the type of a schematic formal parameter
are each refused as the type an inquiry denotes, and neither is reachable
through a selector: a slice may be written only as a formal parameter's own
type-denoter (6.7.3.9.2), and a type with no discriminant tuple belongs to a
formal parameter. So `type of s` over `array of integer` is refused and `type
of s[1]` is `integer`, which is the extension working rather than an
inconsistency.

NOTE 6 — This clause is what lets a routine parameterised by a type (6.7.3.5)
read an element type off the container it was given, instead of being handed
the same type twice. `lib/dialect/pascontainer.pas` is the caller.

#### 6.4.16 Channel-types [added]

A channel-type denotes a bounded queue of values that two activations running
concurrently may both name, and it is the **only** such thing in this language
(ADR-0201, ADR-0268).

**6.4.16.1 The denoter.**

    channel-type = 'channel' '[' constant-expression ']' 'of' type-denoter .

Neither `channel` nor the bracketed capacity is a word-symbol. A type-denoter
that is an identifier is a type-name, and no type-name may be followed by `[` —
a schema production takes `(` and `array` is a word-symbol — so the
juxtaposition is one no conforming program can have written in this position
(6.1.10, ADR-0140). A program declaring a type named `channel` writes
`channel = …` and `var c: channel;`, whose second token is `=` or `;`, and is
untouched.

The constant-expression shall be an ordinal constant greater than zero. It is
the number of values the channel holds before a send waits.

**6.4.16.2 A channel is a handle.** A channel-type shall be a handle-type
(6.4.12) whose releasing routine is this processor's. Everything 6.4.12 says of
a handle shall hold of a channel: it has no copy, it is released when the
variable holding it ceases to exist, `release` (6.4.12.5) releases it earlier,
and it may be compared with `nil` and with nothing else.

NOTE 1 — A kind of its own was considered and refused. Everything a channel
needs from the language is what a handle already has, so a second kind would be
a parallel mechanism where a field does — and every routine that asks a
question about a handle would have had to be taught a second answer.

NOTE 2 — Unlike every other handle, a channel-variable does **not** start
empty: its capacity is part of its type, so there is nothing left for an
assignment to decide and no birth for a program to write. That is why
`channel [8] of integer` is a declaration rather than a constructor, and it is
the one place 6.4.12.2's "shall be empty when its block is activated" does not
apply.

**6.4.16.3 What a channel may carry.** The component type shall be
**transferable**: it shall contain no pointer-type, no file-type, no
handle-type, no owned-pointer-type, no slice and no procedural type, at any
depth.

NOTE 1 — What crosses between two activations is a *value*, and a value holding a
reference is a name for something the other side does not own. The rule is
asked structurally rather than of the kind, because a record of records of
pointers is as unsendable as a pointer.

NOTE 2 — A fixed-capacity string-type (ISO/IEC 10206:1991 §6.4.3.3) and a
text-type (6.4.15) are transferable: each is a length beside a buffer, both in
the value, so what the reader receives shares nothing with what the sender
sent.

**6.4.16.4 Releasing a channel [added].** Releasing (6.4.12.3) a channel by a
release the program has written — the release-function (6.4.12.5), or an
assignment-statement whose target is the variable holding it (6.4.12.2,
6.4.12.7) — shall **close** the channel: no further value
shall be sent, every activation waiting on it shall be resumed, and a receive
that finds it empty shall report the close (6.9.3.13.2).

Releasing a channel by the ceasing to exist of the variable holding it shall
close the channel where that variable is not a formal parameter of a
task-declaration (6.7.8), and shall not close it where it is.

NOTE 1 — The two paragraphs answer two different questions, and reading the
second as the whole rule is what made a pipeline unwritable. *This activation
has finished with the channel* is what the end of a task's block says, and a
task of a pool that has run out of work must not close the channel its
colleagues are still draining — so the second paragraph is right. *Close it*
is what a program writing `release(c)` says, and before this clause that
statement did nothing at all: the reference count went down, the channel
stayed open, and every activation downstream waited for ever with no error
reported anywhere (ADR-0295 finding 1, ADR-0302).

NOTE 2 — The first paragraph is therefore not an exception to 6.4.12.3 but a
statement about what releasing a *channel* releases. A handle's value is the
object, and closing is the observable half of letting go of one that several
activations hold.

NOTE 3 — A task that closes a channel it was given cannot destroy it.
6.9.3.12.1 makes the block that spawned the task complete that task before
releasing any of its own variables, so a variable of the spawning block still
holds the channel throughout; where no such variable does, the task is the
last activation holding it and there is nothing left to protect.

NOTE 4 — The spellings of the program's own release mean one thing, which is
why they are named together: `release(c)`, `c := nil` and `c := take(d)` each
release what `c` held, and a rule that separated them would be a rule about
syntax rather than about the channel.

#### 6.4.17 The task-type [added]

The task-type denotes one activation of a task-declaration (6.7.8). A variable
of the task-type names the activation a spawn-statement (6.9.3.12) commenced,
so that a program may wait for that one activation (6.9.3.14) rather than for
every activation its block commenced (6.9.3.12.1).

**6.4.17.1 The denoter.** `task` shall be a required type-identifier denoting
the task-type.

It is not a word-symbol. It is a name in the scope enclosing the
program-block (§6.2.2.10), so a program that declares `task` for itself keeps
that meaning (§6.1.3) — `int64`'s route and not `channel`'s (ADR-0128,
ADR-0140).

There shall be **one** task-type and not one per denoter. `task` is the whole
of the denoter, so there is nothing for 6.4.12.1's new-type rule to
distinguish: two variables written `t, u: task` are of one type, and so are
two written in different blocks.

NOTE 1 — The identifier occurs in two positions and they do not interact. In a
declaration-part it introduces a task-declaration (6.7.8), which is a position
where an identifier is a syntax error in both standards; in a type-denoter it
denotes this type. A program that declares its own `task` shadows the *type*
and does not thereby recover the declaration-part position, which 6.7.8
already stated is not a program's to spell.

NOTE 2 — The type needed no spelling beyond a name, so none was invented. A
channel-type (6.4.16.1) had to be spelled by juxtaposition because its
capacity and its component type are part of it; a task-type carries nothing,
and 6.4.12.1's own denoter names a foreign closer this type does not have.

**6.4.17.2 A task is a handle.** The task-type shall be a handle-type
(6.4.12) whose releasing routine is this processor's. Everything 6.4.12 says
of a handle shall hold of a task: a task-variable shall be empty when its
block is activated, shall hold at most one activation, shall be released when
the variable ceases to exist (6.4.12.3), may be released earlier by the
release-function (6.4.12.5) or by an assignment of `nil`, may be **moved**
(6.4.12.7), and may be compared with `nil` and with nothing else. It shall not
be assigned from another task-variable, shall not be a value parameter of a
routine that is not a task-declaration (6.7.8.1), and shall not be a function
result.

There shall be three forms of assignment to a task-variable: the second form
of the spawn-statement (6.9.3.12), which is this type's producer; `nil`; and
the move (6.4.12.7). 6.4.12.2's first form requires an external-declaration
and reaches nothing here, an activation of a task being this program's.

A task-variable may be a component of an array or of a record, as any handle
may be, and may be a formal parameter of a task-declaration, a task-type being
a handle-type and 6.7.8.1 admitting one.

NOTE 1 — A kind of its own was refused for 6.4.16.2's reason, one type further
on. Everything this type needs from the language — no copy, release at the end
of the block, an early release, the move, affinity — is what a handle already
is, and a second mechanism would be a parallel one where a flag does.

NOTE 2 — An array of task-variables is what makes a pool of workers writable:
`spawn ws[i] := Worker(jobs)` in one loop and `wait(ws[i])` in another.
Nothing was added for it — an array of handles was already admissible, and it
is why 6.9.3.12's second form takes a variable-access and not a name.

NOTE 3 — A task-variable moved into a task is a task waiting for a task, and
the move is what keeps it safe: at no moment do two activations name one
activation, so the claim 6.9.3.14 rests on is the affine model unchanged.

**6.4.17.3 Releasing a task.** Releasing (6.4.12.3) the value a task-variable
holds shall not wait for the activation. The variable shall cease to name it;
the activation shall remain one the block commenced, and 6.9.3.12.1 shall
still require it to be complete before that block's activation ends.

NOTE 1 — This is what releasing a *channel* is not (6.4.16.4), and the
asymmetry is the design rather than an inconsistency. A channel no activation
holds is of no use to anybody, so a release the program wrote closes it; an
activation is not made pointless by nothing naming it, and stopping one is not
something this language can do at all.

NOTE 2 — A task-variable assigned twice therefore names the second activation
and leaves the first to the block's join. That is a program that spawns more
activations than it waits for, and it is not an error; a program that wants to
wait for both writes an array (NOTE 2 of 6.4.17.2).

NOTE 3 — The release **cannot** be where the join happens, and the reason is
an ordering. 6.9.3.12.1 requires every activation to be complete before *any*
variable of the block is released, and the release of one handle is not
ordered against the release of another — so a task-variable that joined as it
was released would join at a moment no clause fixes, after some of the block's
files and handles had already been closed under a task still running
(ADR-0312).

### 6.5 Declarations and denotations of variables

#### 6.5.1 Variable-declarations [extended]

Every variable that possesses a file-type shall possess the bindability that
is bindable, whether or not the type-denoter from which it takes its type
contains the word-symbol `bindable`. This shall hold of every variable-access
that denotes a file: an entire-variable, a component-variable (6.5.3), an
identified-variable (6.5.4), a variable denoted by the formal parameter of a
variable-parameter-specification (6.7.3.3), and a variable a module exports
(6.11).

The bindability of a variable that does not possess a file-type shall be as
ISO/IEC 10206:1991 §6.5.1 gives it: bindable if its type-denoter contains
`bindable`, and nonbindable otherwise. 6.9.3.9.1 shall refuse a bindable
variable as a control-variable and 6.4.3.4 shall keep one out of a
variant-denoter, whatever its type. What it would mean to bind such a variable
to an external entity is not defined by this document: the required procedures
`bind` and `unbind` (§6.7.5.6) and the required function `binding` (§6.7.6.8)
shall each require a variable-access that possesses a file-type, and a
processor shall report an activation of one whose variable-access does not.

NOTE 1 — §6.7.5.6 makes the file case the conditional one: *"If the
variable-access f possesses a file-type, it shall be a dynamic-violation if
the variable does not possess the bindability that is bindable."* Under this
clause a file variable always possesses it, so the dynamic-violation cannot
occur and the processor makes no check; §6.7.6.8 says the same of `binding`
and the same follows. The *"otherwise"* branch of both sentences presupposes a
non-file bindable variable and this clause declines to give one a meaning,
which is the one restriction it states and the reason it is stated here rather
than left to a processor.

NOTE 2 — §6.7.3.3 requires a formal variable parameter to *"possess the
bindability that is possessed by the actual-parameter"*, and its NOTE 1 makes
that determined dynamically. For a file both are bindable, so nothing travels
with the parameter and nothing is checked at the call; §6.7.6.8's own example
`procedure bindfile(var f: text)` is a program of this dialect, and was refused
before this clause. A conforming processor of ISO/IEC 10206:1991 would carry
the bindability of the actual with every `var` file parameter and check it at
run time, which is what this clause makes unnecessary (ADR-0299).

NOTE 3 — The word `bindable` remains accepted wherever §6.4.1 admits it. On a
type-denoter denoting a file-type it denotes nothing the type does not already,
so every ISO/IEC 10206:1991 program keeps its meaning (6.0.1). What changes is
which programs are accepted: a program the standard requires to be rejected
because `bind`, `unbind` or `binding` is applied to a file variable whose
type-denoter does not say `bindable` is accepted here — including one whose
file is reached through a pointer, which the processor had never refused and
`doc/implementation-defined.md` §6.1 carried as its one known such program
until this clause made it the rule.

NOTE 4 — §6.5.3.1 makes the components of a string nonbindable and §6.5.5 a
buffer-variable; neither is a file (§6.4.3.6 admits no file component), so each
is refused by the file-type requirement of the paragraph above, and the
nonbindability adds nothing a processor has to ask.

NOTE 5 — Nothing is spelled. This is a rule about what a position the language
already has admits, as 6.7.7.6.1's record at an `external` heading and
6.7.3.6's schematic string formal are, and there is no second place for the
truth to live (ADR-0140, ADR-0299).

#### 6.5.3 Component-variables [extended]

##### 6.5.3.2 Indexed-variables [extended]

Where the array-variable is a slice, the index-expression shall be of an integer
type, and its value shall be in the closed range 1 to the slice's length
(6.7.3.9.4). Otherwise this clause is unchanged.

#### 6.5.6 Substring-variables [extended]

Where the variable preceding `[` denotes an array that is **not** of a
string-type and whose index-type is an integer type, `a[i..j]` shall denote a
slice of that array (6.7.3.9.3) rather than the substring ISO/IEC 10206:1991
§6.5.6 gives a string.

Where it denotes a variable of a string-type, `a[i..j]` shall denote a
substring, and §6.5.6 is unchanged but for its error conditions, which shall be
as follows. It shall be an error if the string-variable of the substring-variable
is undefined, or if the value of the first index-expression is less than 1, or
if the value of the second index-expression is greater than the length of the
value of the string-variable, or if the value of the second index-expression is
less than one less than the value of the first index-expression.

Where the value of the second index-expression is one less than the value of the
first, the substring-variable shall denote a variable of a fixed-string-type of
capacity 0, whose value is the null-string (§6.4.3.3.1).

Which construct is denoted shall be determined by the type of the variable
preceding `[`, and by nothing else.

NOTE 1 — The syntax is therefore unchanged; §6.5.6 already provides it. This is
"ask the symbol, not the syntax", which this repository has now reached for
seven times.

NOTE 2 — While there were conformance modes, `a[i..j]` remained available in
one only for a string, with the diagnostic unchanged, and the dialect's reading
of the designator was gated on the mode for that reason (ADR-0125). ADR-0232
removed the gate with the modes; the reading above is now the only one, which
is why the exclusion this clause states has to be stated rather than inherited.

NOTE 3 — The string-type exclusion is not a special case; it is what containment
requires. A `packed array [1..n] of char` is a string-type (§6.4.3.3.2) *and* an
array with an integer index-type, so without the first paragraph's exclusion
both readings would apply to it — and the slice reading would take `s[1..3]`
away from every ISO/IEC 10206:1991 program that writes one, which is exactly
what a dialect containing that standard may not do. The first draft of this
clause omitted the exclusion and said the opposite of what the processor does;
the processor was right. Recorded in Annex E.

NOTE 4 — The amended error conditions differ from §6.5.6's in one value and no
more. §6.5.6 states them as "an index-expression … less than 1 or greater than
the length … or … the first index-expression … greater than the second"; here
the first index-expression may equal one plus the length, the second may be one
less than the first, and every other combination is an error as before. In
particular `s[4..2]` remains an error, so a transposed pair of indices is still
reported.

NOTE 5 — Nothing else in §6.5.6 changes. The capacity is still "one plus the
value of the second index-expression minus the value of the first", which for
the admitted case is 0 — the clause's own arithmetic already yields the empty
substring and only the prohibition stood in the way.

NOTE 6 — This admits no program that ISO/IEC 10206:1991 accepts and gives it a
different meaning. §3.1 of that standard defines an error as "a violation by a
program of the requirements of this International Standard that a processor is
permitted to leave undetected", so a program writing `s[i..i-1]` is erroneous
and not a program the standard accepts. Containment (5.4) is a claim about the
programs it accepts.

NOTE 7 — The reason is consistency with two constructs that already answer this
question the other way. §6.7.6.7's required function `substr(s, i, 0)` yields
the null-string, and a slice `a[i..i-1]` is the empty slice (6.7.3.9.5) — so
before this clause `s[i..i-1]` was the only bracketed range in the dialect that
could not be empty, and the one whose emptiness a writer would reach for most.
Two library modules written in this dialect got it wrong in the same week;
ADR-0219 records both.

NOTE 8 — A conformance mode reports the error as before and there is therefore
no row for this clause in Annex B, which records refusals of *constructs*. The
construct is one ISO/IEC 10206:1991 has; what the dialect changes is when using
it is an error.

### 6.7 Procedure and function declarations

#### 6.7.3 Parameters

##### 6.7.3.6 Parameter list congruity [extended]

**6.7.3.6.1 A schematic string value formal.** Two formal-parameter-sections
shall also match if all of the following are true.

a) Both are value-parameter-specifications containing the same number of
   parameters, and either both contain `protected` or neither contains
   `protected`.

b) The parameter-form of the section in the formal-parameter-list of the
   procedure or function denoted by the actual-parameter is a schema-name
   denoting the string schema (ISO/IEC 10206:1991 §6.4.3.3).

c) The parameter-form of the corresponding section in the formal-parameter-list
   of the procedural-parameter-specification or the functional-parameter-
   specification denotes a type produced from that schema.

**6.7.3.6.2 The addition is not symmetric.** 6.7.3.6.1 with b) and c)
exchanged shall not match. Where the two are exchanged, the matching of
ISO/IEC 10206:1991 §6.7.3.6 alone shall decide.

**6.7.3.6.3 Orientation of c) and d).** Where ISO/IEC 10206:1991 §6.7.3.6 c)
or d) requires the formal-parameter-lists of two procedure-headings or
function-headings to be congruous, the list belonging to the procedure or
function denoted by the actual-parameter shall take the position of the
procedural-parameter-specification's list, and that list shall take the
position of the actual-parameter's.

NOTE 1 — 6.7.3.6.2 is the whole of the safety argument. A schematic formal
receives a value of whatever length it is handed and gives its own local
variable that length, so it can stand in for any capacity. A formal naming a
produced type has a fixed capacity, and a caller bound by 6.7.3.6.1's
schema-name form is bound by nothing — the first longer actual would be
§6.4.6's error at run time. The permission therefore runs one way only.

NOTE 2 — The string schema is named in b), rather than any schema, because it
is the only one whose values carry what the schematic form requires. §6.4.3.3.3
makes a string value a length and that many components, so a value parameter of
`string(n)` and one of `string` are alike in what the actual supplies. For every
other schema the tuple is a property of the type: where it is written the actual
supplies nothing, and where it is not the actual supplies the discriminants, so
the two forms are not alike and no permission is given.

NOTE 3 — Value parameters are named in a), rather than variable parameters as
well, for the reason ISO/IEC 10206:1991 §6.7.3.3 already draws the same line:
a variable parameter binds to storage rather than taking a value, so there is
no value from which a length could be taken.

NOTE 4 — 6.7.3.6.3 states an orientation that ISO/IEC 10206:1991 leaves
unstated because it does not need it: congruity there is a symmetric relation,
so the two lists may be compared either way round. 6.7.3.6.1 makes the relation
directional, and one level in the direction reverses — a body holding the
procedural parameter builds a routine to the *specification's* inner heading and
passes it to the actual, which invokes it through its **own**. So the routine
being passed, at that level, is the specification's, which is what 6.7.3.6.3
says.

NOTE 5 — This clause only ever admits more: a formal-parameter-list pair
congruous under ISO/IEC 10206:1991 §6.7.3.6 remains so, and no program that
conforms to that standard changes meaning.

##### 6.7.3.9 Slice parameters [added]

**6.7.3.9.1 The denoter.**

    slice-parameter-type = 'array' 'of' type-denoter .

NOTE 1 — Both words are already word-symbols in both standards; it is the
*combination* that is free, §6.4.3.2 requiring a bracketed index-type. So
`array of T` is a syntax error in ISO 7185 and in ISO/IEC 10206:1991 alike, and
the lexis costs nothing (ADR-0125).

NOTE 2 — **A standard answers this question and answers it differently.**
ISO 7185 §6.6.3.7's conformant array parameter is a formal parameter whose
bounds travel with the actual, which is what 6.7.3.9 is for, and
ISO/IEC 10206:1991's schematic formal (§6.7.3.1, and ADR-0040 here) is a third
member of the same family. Three deliberate differences, and each is argued
where it is stated rather than here: a conformant array parameter **preserves**
the actual's own bounds where a slice renumbers from 1 (6.7.3.9.4); it takes a
whole array where a slice may denote any contiguous run of one (6.7.3.9.3); and
it exists in a value form as well as a variable form, where a slice is a borrow
only (6.7.3.9.3). Congruity is the fourth: §6.6.3.7 gives conformant array
schemas congruity rules of their own, and the dialect uses compatibility
(6.4.5), which is what ADR-0139 and ADR-0143 were each about.

This NOTE exists because `doc/roadmap.md` §2 said the dialect has no external
authority for anything but the foreign boundary, and that was not true of its
largest feature (ADR-0152). A processor accepting §6.6.3.7 would be a level 1
processor; this one declares level 0, which is a complying level.

**6.7.3.9.2 Where it may be written.** A slice-parameter-type shall be written
as the type of a formal parameter and nowhere else. It shall not be the
type-denoter of a type-definition, of a variable-declaration, of a record's
field, of an array's component, of a function's result, or of another
slice-parameter-type.

A slice-parameter-type shall not be the type denoted by a type-inquiry
(ISO/IEC 10206:1991 §6.4.9).

NOTE 1 — This is stronger than "a slice may not be a variable", and the list of
positions is discharged by one test — but not the test the first draft of this
clause named. It argued that *a type that cannot be named cannot be created
anywhere the list might have missed*, and §6.4.9 names it: `type of a` denotes
the type its object possesses, and that clause's own worked example is a `var`
parameter with a local variable declared from it. Every position listed above
was reachable through that one denoter. The paragraph before this NOTE is the
test the argument wanted (ADR-0143).

NOTE 2 — A type-inquiry is the only denoter that can produce a slice type
without writing `array of`, which is why one sentence closes the family.

**6.7.3.9.3 Parameter kind, and the actual.** A slice parameter shall be a
variable parameter (§6.7.3.3) or a protected variable parameter — `protected`
being an optional prefix of §6.7.3.3's variable-parameter-specification. It
shall **not** be a value parameter.

The actual shall be a variable denoting an array whose index-type is an integer
type, a slice of one written `a[i..j]`, or another slice.

NOTE — A slice is a view of storage the calling activation owns; a value
parameter is a copy, which is a thing the language can already express by
passing a schematic array by value. The protected form is the read-only
borrow, and needs nothing new: §6.9.4's threat rules apply unchanged.

**6.7.3.9.4 Index domain and length.** The components of a slice shall be
indexed from 1, whatever the bounds of the array it views. `length` applied to
a slice shall yield the number of its components.

NOTE — Every sequence-like thing in this language is indexed from 1: §6.4.3.3.1
gives a string that index-domain, and §6.7.6.7's `substr` yields one indexed
from 1 however far into the string it was taken. This differs from the open
array of other Pascal dialects, which is indexed from 0, and the divergence is
chosen: it fails loudly, a habitual `s[0]` being a bounds error on the first
access rather than a quiet displacement.

**6.7.3.9.5 Bounds.** Two requirements, and the second is not the first
repeated:

- a) where a slice is **taken**, `a[i..j]` shall satisfy `i >= lo`, `j <= hi`
  and `j >= i - 1`, where `lo` and `hi` are the bounds of `a`. It is an error
  otherwise (Annex A.3). `j = i - 1` denotes the empty slice and is not an
  error;
- b) where a slice is **indexed**, 6.5.3.2 applies, against 1 and the slice's
  own length.

NOTE — The callee cannot see where its slice came from, and its length is the
only bound in scope. That the two bounds always describe the same storage is the
property the parameter form exists for, and it is what a pointer and a
separately-passed count cannot promise.

**6.7.3.10 The type parameter [added].** A formal-parameter-section may be a
**type-parameter-specification**:

    type-parameter-specification = identifier-list ':' 'type' .

The identifiers of an identifier-list of a type-parameter-specification shall
each have a defining-point as a type-identifier for the region that is the
formal-parameter-list closest-containing it and for the region that is the
block of the procedure-block or function-block, if any, associated with the
procedure-heading or function-heading closest-containing it.

A procedure-declaration or function-declaration whose formal-parameter-list
contains a type-parameter-specification shall be a **generic** declaration.

NOTE 1 — The spelling is a position and not a word-symbol, as every construct
of this dialect is (Annex D). 6.7.3.1 already admits `type` as the first
word-symbol of a type-inquiry (6.4.8), and a type-inquiry is `type` followed by
`of` and nothing else — so `type` followed by anything else is a juxtaposition
no conforming program can write. It is the spelling 6.4.7.1 gives a
type-valued discriminant, in the other place where a type may be a parameter.

**6.7.3.10.1 The actual.** In an activation of a generic routine, the
actual-parameter matching a type-parameter-specification shall be a
type-identifier. The types so named, in the order the type parameters are
written, shall be the **type-argument-tuple** of that activation.

It shall be an error for an actual-parameter matching a
type-parameter-specification to denote anything other than a type.

**6.7.3.10.2 Instantiation.** A generic declaration shall denote no single
procedure or function. For each distinct type-argument-tuple with which a
generic routine is activated, the processor shall produce one procedure or
function, whose formal-parameter-list and result type are those of the generic
declaration with each type parameter denoting the corresponding type of the
tuple, and whose block is the block of the generic declaration.

Two activations whose type-argument-tuples are the same shall activate the same
procedure or function.

NOTE 2 — Which makes a recursive activation of a generic routine terminate:
the tuple is the same, so it reaches the routine already being produced rather
than asking for another. It is 6.4.7's rule for a schema's productions, said
for a routine — and for the same reason, since a type parameter is what a
discriminant cannot be (6.7.3.7.1 passes discriminants in the actual, and a
type is not a value that can travel there).

NOTE 3 — A generic declaration activated by nothing produces nothing, and its
block is therefore never subjected to the requirements of this document. A
generic routine is checked once for each tuple a program actually asks for.

**6.7.3.10.3 What a type parameter is not.** A type parameter shall occupy no
position in the actual-parameter-list of the produced procedure or function,
and 6.7.3.6's congruence shall be determined over the remaining
formal-parameter-sections.

NOTE 4 — It has already done its work by the time the produced routine exists:
it chose which routine that is. What is passed at the activation is what
6.7.3.1 admits, and a type is not among those things in any of the three
languages this document is written against.

**6.7.3.10.4 Inferred type arguments [added].** Let *n* be the number of type
parameters of a generic declaration, *m* the number of its formal-parameters,
and *a* the number of actual-parameters of an activation of it; and let *k* be
*a* - (*m* - *n*).

An activation of a generic routine shall write an actual-parameter for every
formal-parameter that is not a type parameter, and shall write one, in that
type parameter's own position, for each of the first *k* type parameters and
for no other type parameter; it shall be an error to write any other
actual-parameter-list. The type parameters for which an actual-parameter is so
written shall be the **written type arguments** of the activation.

Where *k* is less than zero or greater than *n*, or where *k* is less than *n*
and the actual-parameter occupying the position of the (*k* + 1)th type
parameter, if there is one in that position, denotes a type, the activation
shall be one to which 6.7.3.10.1 applies and the type-argument-tuple shall be
as that sub-clause gives it. Otherwise the activation shall be an **inferred
activation**.

For an inferred activation each written type argument shall determine the type
parameter in whose position it is written, as the type it denotes; and the
remaining type parameters shall be determined from the actual-parameters of
the formal-parameters that are not type parameters, taking each in the order
it is written and reading it against the parameter-form of the formal-parameter
it matches, as follows.

  a) Where the parameter-form is a type-identifier having a defining-point as a
     type parameter of that generic declaration, that type parameter shall be
     determined as the type possessed by the actual-parameter.

  b) Where the parameter-form is a schema-name followed by an
     actual-discriminant-part, and the type possessed by the actual-parameter
     is a type produced from that schema, each actual-discriminant that is a
     type-identifier having a defining-point as a type parameter of that
     generic declaration shall determine that type parameter as the
     corresponding component of the type-argument-tuple of that type.

  c) Where the parameter-form is a slice-parameter-type (6.7.3.9.1), and the
     type possessed by the actual-parameter is an array-type or a slice-type,
     the type-denoter after `of` shall be read against the component type of
     that type.

  d) Otherwise the formal-parameter shall determine nothing.

A type parameter shall be determined by the first actual-parameter that
determines it, and a later one shall not redetermine it; a written type
argument determines before any other actual-parameter is read. It shall be an
error for a type parameter of an inferred activation to be determined by no
actual-parameter.

The type-argument-tuple of an inferred activation shall be the types so
determined, in the order the type parameters are written; and 6.7.3.10.2 shall
then apply to it unchanged.

NOTE 5 — So two activations writing the same types, by whatever mixture of
written and determined type arguments, are one activation of one produced
routine and not two: they name the same tuple, and 6.7.3.10.2 makes the tuple
the identity.

NOTE 6 — Each length of actual-parameter-list admits exactly one value of *k*,
so a well-formed activation is never ambiguous by arity, and the written type
arguments being a prefix of the type parameters is what makes that so. The
further condition on the (*k* + 1)th type parameter's position is what
distinguishes an inferred activation from one that is short of an
actual-parameter, and it is decidable because an actual-parameter that denotes
a type cannot denote a value. An activation from which a type argument has
been omitted in error is therefore not always refused: where the remaining
type parameters are determined and every actual-parameter is compatible with
the formal-parameter it then matches, it is a well-formed inferred activation
of a routine other than the one intended.

NOTE 7 — A later actual-parameter does not redetermine, and so cannot conflict.
Once a type parameter is determined the formal-parameters that mention it have
types, and every remaining actual-parameter is subject to 6.7.3.1 and 6.4.6 as
any other actual-parameter is. An activation whose second actual-parameter
possesses a type merely assignment-compatible with the first's is therefore
well-formed, and one whose second actual-parameter is not is refused where any
other mismatch is refused.

NOTE 8 — Clause c) is deliberately wider than 6.7.3.9.3, which admits an
array only where its index-type is an integer type. An array indexed
otherwise therefore determines the type parameter and is then refused as the
actual-parameter it is, by the rule about slice actuals; were it excluded
here, the type parameter would be determined by no actual-parameter and the
error reported would be that one, so the reader would have to write a type
argument before the error about the array appeared. What clause c) requires is
only that there be a component type to read, and an array-type has one
whatever its index-type. A variable-string is not an array-type and has no
component type in this sense, so it determines nothing here, and 6.7.3.9.3
does not admit one either.

NOTE 9 — A type parameter occurring only in the result type is determined by
no actual-parameter, 6.7.1 making a result type a type-identifier and not an
actual-parameter. Such a type parameter is written by every activation.

NOTE 10 — A generic declaration writing its undeterminable type parameters
first is therefore one whose activations write those and no others. This is
why 6.7.3.10.2's produced routine is reached by a prefix and not by a
selection: the declaration chooses, once, which of its type parameters an
activation has to name.

**6.7.3.10.5 The category of a type parameter [added].** A
type-parameter-specification may be preceded, within the
formal-parameter-section, by a **type-parameter-category**:

    type-parameter-specification = identifier-list ':'
                                   [ type-parameter-category ] 'type' .
    type-parameter-category      = 'numeric' | 'ordinal'
                                 | 'ordered' | 'equatable' .

The identifiers `numeric`, `ordinal`, `ordered` and `equatable` occurring as a
type-parameter-category shall have no defining-point and shall be identified by
their spelling in that position only. It shall be an error for any other
identifier to occur in that position; the error shall be reported.

Where a type parameter is written with a type-parameter-category, it shall be
an error for the corresponding component of the type-argument-tuple of an
activation of that generic routine to be a type not admitted by the category;
the error shall be reported at the activation. The categories admit:

  a) `numeric`, the types the dyadic arithmetic operators of 6.8.3.2 accept:
     the integer-types, the real-type, the complex-type, and any subrange-type
     whose host-type is one of them;

  b) `ordinal`, the ordinal-types of 6.4.2.2, and no other type. `int64` is
     not among them, 6.4.2.6.2 making it a numeric type that is not an
     ordinal-type;

  c) `ordered`, the types the operators `<`, `<=`, `>` and `>=` of 6.8.3.5
     accept on both operands: every type admitted by `ordinal`, and
     `int64`, the real-type, the string-types of 6.4.3.3 and the text-type of
     6.4.15;

  d) `equatable`, the types the operators `=` and `<>` of 6.8.3.5 accept on
     both operands: every type admitted by `ordered`, and the complex-type,
     the set-types, and the pointer-types that are not owned-pointer-types
     (6.4.14).

Where an activation is an inferred activation (6.7.3.10.4), the error shall be
attributed to the actual-parameter that determined the type parameter.

NOTE 9 — A category constrains the *activation* and does not make the generic
declaration's block separately subject to the requirements of this document.
6.7.3.10.2 is unchanged: the block is read once for each distinct
type-argument-tuple, and a block that misuses a type its category admits is
refused there, as it was before. What a category moves is the diagnostic for
the block that misuses a type its category does **not** admit, from the
generic's own source to the call that asked for it.

NOTE 10 — The four spellings are recognised between the `:` of a
formal-parameter-section and the word-symbol `type`, and nowhere else. A
parameter-form is one type-identifier, schema-name or type-inquiry, and what
may follow one is `;` or `)`, so an identifier followed by the word-symbol
`type` is a juxtaposition no program of the languages this document is written
against could contain. The category therefore reserves nothing and puts
nothing in any region, and a program may go on declaring a type, a variable, a
field or a routine of each of the four names.

NOTE 11 — The set is closed. A category is a name for a group of operators
this document already gives, so admitting an arbitrary predicate would be
admitting a second type system; where a requirement on a type parameter is not
one of these four, 6.7.3.10.2 remains the mechanism and the diagnostic is the
body's.

NOTE 12 — A formal-discriminant of 6.4.7.1 takes no category. A schema's
type-valued discriminant is written where a *type-denoter* is being built and
not where a routine is being activated, so there is no activation for a
refusal to be attributed to.

#### 6.7.5 Required procedures [extended]

**6.7.5.9 The exit procedure [added].** The required procedure-identifier
`exit` shall be a control procedure. It shall terminate the activation of the
block in which the procedure-statement occurs, and shall be written in either
of two forms:

    exit
    exit ( expression )

The block is the one whose statement-part contains the procedure-statement, and
never an enclosing one: an `exit` in a procedure nested in another leaves the
nested procedure.

The second form shall be written only where that block is a function-block. The
expression shall be assignment-compatible with the result type, and the
assignment shall be performed before the activation is terminated. It shall be
equivalent in every respect to an assignment to the function's result — in
particular, where the result type is a fallible-type (6.4.13), the arm is
chosen as 6.4.13.3 chooses it.

The termination is the termination of an activation and not of the program, so:

a) an armed statement (6.9.3.11.2 b) shall be executed;

b) a file (§6.7.5) or handle (6.4.12) the block owns shall be closed;

c) the value of a function shall be taken from its result variable;

d) where the block is the main-program-block, the program shall terminate as
   it does at the end of that block — so the finalization-part of every module
   that supplied it shall be activated (§6.2.3.6) and the termination shall be
   normal.

An exit-statement shall discharge §6.7.2's requirement that a function-block
contain at least one assignment to the function-identifier, and, where a
result-variable-specification was written, its requirement that at least one
statement threaten the result variable. It shall not be a defining-point of
either spelling and shall not be written for a block that is not a
function-block.

`exit` shall not be a word-symbol; §6.1.3's shadowing is what keeps it out of
the way of a program that declares its own (ADR-0140), exactly as for `int64`
(6.4.2.6) and the program-argument functions (6.7.6.10).

NOTE 1 — Leaving a statement-sequence by an exit-statement does not complete
it, so what that sequence armed waits for 6.9.3.11.2 b) rather than a); the
statement is executed late rather than not at all, which is 6.9.3.11's NOTE 2
about the goto-statement, for the same reason.

NOTE 2 — A module-block's activation does not terminate when its
module-initialization does. §6.2.3.6 keeps it live until after the
main-program-block has terminated, so an exit-statement in a
module-initialization terminates the initialization, and a statement armed
there is executed at the end of the finalization.

NOTE 3 — 6.9.3.11.3 forbids an exit-statement in a deferred statement, for the
reason it forbids a goto-statement: a deferred statement is executed in the
block's runner as well as where its sequence is completed, and the runner is
not the activation an exit-statement would terminate.

NOTE 4 — This is the fifth construct the two conformance modes see and refuse
(Annex B), and the second — after `external` — for which the refusal is not
what a program meant by the name: `exit` is spelled in a position a program
of ISO/IEC 10206:1991 could have written, and what makes it the dialect's is
that the identifier is nobody's there. So a conforming program that declares
`exit` keeps it, and one that does not is told it named an unknown procedure.

NOTE 5 — Neither standard has an early exit; every widely used Pascal dialect
does, and spells it `Exit` (ADR-0177). Nothing here gives a value to an
exit-statement or lets one leave more than one activation.

**6.7.5.10 The break procedure [added].** The required procedure-identifier
`break` shall be a control procedure. It shall be written in one form:

    break

It shall terminate the execution of the repetitive-statement (§6.9.3.9) that
closest-contains the procedure-statement, and execution shall continue with the
statement following that repetitive-statement.

The repetitive-statement shall be one of the block in which the
procedure-statement occurs, and never one of an enclosing block: a `break` in a
procedure nested in another leaves a loop of the nested procedure, and where
that procedure has none it shall be an error detected before the program is
executed.

`break` shall not be a word-symbol; §6.1.3's shadowing is what keeps it out of
the way of a program that declares its own, exactly as for `exit` (6.7.5.9).

NOTE 1 — The repetitive-statement is the closest-containing one and there is no
form that leaves more than one. A program leaving two loops at once writes a
goto-statement, which both standards have and which this document does not
change.

NOTE 2 — Leaving a statement-sequence by a break-statement does not complete
it, so what that sequence armed waits for 6.9.3.11.2 b) rather than a); the
statement is executed late rather than not at all. This is 6.7.5.9's NOTE 1 and
6.9.3.11's NOTE 2, for the third time and the same reason.

NOTE 3 — A for-statement terminated by a break-statement is likewise not
completed, so ISO 7185 §6.8.3.9's requirement that the control-variable be
undefined after the for-statement is completed does not apply to it, and the
control-variable retains the value it had when the break-statement was
executed. Nothing here requires that of an implementation whose control-variable
is completed normally.

NOTE 4 — 6.9.3.11.3 does not forbid a break-statement in a deferred statement,
and the omission is deliberate. A deferred statement is executed where its own
sequence is completed and again in the block's runner, so the repetitive-
statements enclosing the defer-statement enclose neither execution — but one
written *within* the deferred statement encloses both. So the requirement above
is the whole rule: `defer break` names no repetitive-statement of either and is
refused by it, while `defer while c do break` means what it says.

**6.7.5.11 The continue procedure [added].** The required procedure-identifier
`continue` shall be a control procedure. It shall be written in one form:

    continue

It shall terminate the execution of the current iteration of the
repetitive-statement (§6.9.3.9) that closest-contains the procedure-statement.
Execution shall continue at the point at which that repetitive-statement
determines whether a further iteration is to be performed, which is:

a) for a while-statement (§6.9.3.6), the evaluation of its Boolean expression;

b) for a repeat-statement (§6.9.3.7), the evaluation of its Boolean expression,
   which follows the statement-sequence;

c) for a for-statement (§6.9.3.9) in the form ISO 7185 §6.8.3.9 gives it, the
   determination of whether the control-variable has attained the final-value,
   before it is incremented or decremented;

d) for a for-statement in ISO/IEC 10206:1991 §6.9.3.9.3's form over a set, and
   for 6.4.15's form over a text, the selection of the next member or element.

The requirements 6.7.5.10 states about the block, about shadowing, and about a
deferred statement shall apply to `continue` unchanged.

NOTE 1 — c) is why this clause enumerates the forms rather than saying "the
beginning of the repetitive-statement". A for-statement tests the
control-variable against the final-value *after* its statement and steps only
where it has not been attained, so continuing at the beginning would execute the
statement again with the same value and never terminate.

NOTE 2 — Neither standard has either of these two procedures; every widely used
Pascal dialect has both, and spells them `Break` and `Continue` (ADR-0208).
They are 6.7.5.9's borrowing from the same source and were taken for the same
reason: a Pascal programmer arriving here already knows them, and a language
whose only early exit from a loop is a goto-statement is one people write a
Boolean flag in instead.

#### 6.7.6 Required functions [extended]

`length` shall accept a slice (6.7.3.9.4), extending the required function
ISO/IEC 10206:1991 §6.7.6.7 gives a string.

NOTE — A slice and a string are the same shape; two spellings for one question
would be the invention.

**6.7.6.10 Program-argument functions [added].** The required
function-identifiers `argcount` and `argument` shall be program-argument
functions.

`argcount` shall yield a value of integer-type: the number of arguments the
program was activated with, not counting the name the program was activated
under. The function-designator shall have no actual-parameter-list.

`argument(k)`, for an expression `k` of integer-type, shall yield a value of
the canonical-string-type: the `k`-th argument. It shall be an error if the
value of `k` is not in the closed interval 1 to `argcount` (Annex A.6).

The arguments are the sequence ISO/IEC 10206:1991 §6.12 binds the program's
file-type program-parameters to, in that order, so that for a program whose
program-parameters other than `input` and `output` are `p1` … `pn`, each
bound, `binding(pk).name` and `argument(k)` denote the same character-string.

NOTE 1 — §6.12 gives a program its arguments one program-parameter each and
`binding(f).bound` as the only way to count them (E.19, ADR-0081). A program
wanting a list declares as many file variables as it may be given, opens none
of them, and stops at the first unbound — which is how `pascalc` itself reads
its command line, and is the shape this clause exists to spare a program.
Neither mechanism disturbs the other: a program may use both.

NOTE 2 — Both are required identifiers and §6.1.3 makes each shadowable, so a
program of the contained standard that declares its own `argument`, or its
own `argcount` — a variable, even — keeps it (ADR-0117). `argcount` is the
third name, after `eof` and `eoln`, that a program may call with no parameter
list at all, and the bare spelling is a call exactly when the identifier's
nearest defining-point is the required one: the question is asked of the
symbol and not of the syntax, which is what lets a declaration of the
program's win.

NOTE 3 — The value of `argument(k)` is a value and not a variable: the
characters belong to the activation and outlive every statement, so no
storage of the program's is taken for them (ADR-0111). ADR-0173.

#### 6.7.7 External-declarations [added]

**6.7.7.1 The directive.**

    procedure-declaration = ... | procedure-heading ';' external-directive .
    function-declaration  = ... | function-heading  ';' external-directive .
    external-directive    = 'external' character-string .

An external-declaration shall declare a procedure or function whose block is
not translated by this processor. The character-string shall be the name by
which that routine is known to the linker.

**6.7.7.2 The foreign name is required and is not derived.** There shall be no
form of external-directive without a character-string, and the name shall not
be derived from the procedure-identifier or function-identifier.

NOTE — Identifiers in this language are case-folded (§6.1.3) and the names a
linker matches are not. Deriving one from the other is a silently lossy mapping
onto a name that is matched exactly: `getaddrinfo` would work by luck and
`LZ4_compress` would not, and nothing would say so before the link. Requiring
the string also makes the boundary greppable, which is the whole of the safety
this clause claims.

**6.7.7.3 Value parameters.** The type of a value parameter of an
external-declaration shall be `integer`, `int64`, `real`, `string`, or a
handle-type (6.4.12.4).

**6.7.7.4 The types are exact, not based.** A subrange-type, an
enumerated-type, `char`, `boolean` and every other type shall be refused, and
shall be refused although §6.4.2.4 makes a subrange answer for its host
everywhere else in this language.

NOTE — The rule has to hold in both directions or it is a rule with a side, and
a rule with a side is the kind that is misremembered. Passing a subrange out
would be sound; receiving one back is not, because the value arrives from a
routine that made no promise about the bounds and there is nothing for
§6.4.2.4's check to apply to. `char` and `boolean` are refused for a sharper
version of the same reason: C passes them with a parameter attribute this
processor would have to agree with, and `boolean` has 254 byte patterns that
are not values of it. `integer`, `int64` and `real` are exactly the types this
target's C compiler passes with no parameter attribute at all, which was
established by probe and not by reasoning (ADR-0121).

**6.7.7.5 String arguments.** A value parameter of type `string` shall denote,
on the far side, the address of a NUL-terminated copy of the actual's value.

The formal shall be spelled `string`, with no capacity and no fixed size. The
actual may be any string expression, including a value of `char`, which
§6.4.3.3.1 gives length 1.

It shall be an error for the value to contain a NUL character (Annex A.4).

NOTE 1 — `string` here is **not** a schematic formal, and this is the one thing
a reader must not carry over. Everywhere else in this language `s: string` is a
schema parameter whose actual must be a variable, because its capacity is read
from a descriptor (ADR-0040). At this boundary there is no descriptor, no
discriminant and no callee prologue, so what crosses is the value.

NOTE 2 — A capacity on the formal would be a promise nothing on the far side
keeps. A C string's length is in-band; that is what makes this the one
structured value that can cross without a second word.

NOTE 3 — The NUL error is the one safety property this clause *adds*. C cannot
represent such a string, so there is no image to hand over, and passing the
prefix would silently rename a path or shorten a command.

**6.7.7.6 Variable parameters.** What crosses for a variable parameter of an
external-declaration shall be the address of the actual, and the rules of
§6.7.3.3 shall apply to the actual unchanged. Its type shall be as 6.7.7.6.1
and 6.7.7.6.2 admit.

**6.7.7.6.1 Scalar variable parameters.** The type of a variable parameter of
an external-declaration may be `integer`, `int64` or `real`.

**6.7.7.6.2 Record variable parameters.** The type of a variable parameter of
an external-declaration may be a record-type having no variant-part, every
field of which is of a type that is

- a) `char`, `integer`, `int64` or `real`;
- b) an array-type, of any number of dimensions, whose component-type
  satisfies a); or
- c) a record-type satisfying this clause.

NOTE 1 — What makes this sound is that the layout this processor computes for
such a record is the layout C computes for the corresponding struct. Each
field is placed at the next offset that is a multiple of its own alignment,
the record's alignment is the greatest of its fields', and the record's size
is rounded up to that. Nothing is computed here *for* C; the rule admits
exactly those fields whose representation is not this processor's own
invention (ADR-0184).

NOTE 2 — The list in a) is 6.7.7.7's component list and is that list for
6.7.7.7's reason: the callee writes through the address, and a type having a
byte pattern that is not a value of it cannot be admitted. `char` has none.
`boolean`, an enumerated-type and a subrange-type each have many, and §6.4.6's
check has nothing to apply to a value a routine this processor did not
translate left behind.

NOTE 3 — A variant-part is refused because the storage an arm is laid over is
of this processor's choosing and a C union is not laid out from it, and
because a tag-field has no member for it to correspond to. A program wanting
`struct sockaddr_storage` shall declare the arm it means, as b) admits.

NOTE 4 — A field's size is always known, §6.4.3.3 refusing a field whose
extent a discriminant decides, so no requirement about bounds is stated here.

NOTE 5 — A record-type admitted by this clause may be packed, and packing has
no effect on what crosses. This processor's layout does not depend on it
(ISO 7185 §6.4.3.1 permitting that, and `doc/implementation-defined.md`
recording it), so a packed record crosses at the offsets C computes for a
struct that is *not* packed. **`packed` is therefore not a way to spell C's
`__attribute__((packed))`**, and a program needing a struct C packs cannot
declare one here.

NOTE 6 — **That the fields declared are the fields the foreign struct has, in
that order and with that padding, is a requirement on the program and this
processor does not enforce it, nor can it.** It is a claim of the same kind as
the signature of every external-declaration (6.7.7.8, C.1). What this clause
removes is the arithmetic: a program states fields and never offsets.

**6.7.7.6.3 A record shall not cross by value.** A value parameter of an
external-declaration shall not be of a record-type, and neither shall the
result type of one.

NOTE — How a struct is copied into a call and out of one is a property of the
C implementation's procedure-calling convention. Every argument at this
boundary corresponds to a separate scalar so that no part of this processor
need have an opinion about that convention (ADR-0030), and admitting a record
by value would give it one. The diagnostic names the remedy, that remedy being
6.7.7.6.2.

**6.7.7.7 Slice parameters.** A variable parameter of an external-declaration
may be a slice (6.7.3.9), and its component type shall be `char`, `integer`,
`int64` or `real`.

A slice shall cross as **two** arguments: the address of its first component,
then its length. This is the only place in this language where one formal
parameter does not correspond to one argument.

NOTE 1 — `char` is admitted as a component although 6.7.7.4 refuses it by
value, and the two are consistent: 6.7.7.4's objection is to the register
convention, which a component in memory does not use, and `char` has no byte
pattern that is not a value of it. That property — not "a byte is a byte" — is
what makes a component safe for a routine this processor did not translate to
write into. Every other candidate lacks it, which is why the component list is
6.7.7.4's list plus `char` and nothing more.

NOTE 2 — The order, address then length, is the order `read`, `write`, `recv`,
`send` and `snprintf` take. **This is the one decision in this document with an
external authority behind it** (clause 2): the far side chose the shape. A
routine taking the length first, or taking two buffers governed by one length,
cannot be declared with a slice at all, and there is no escape hatch — a bare
address without a length is what 6.7.7.9 refuses.

NOTE 3 — The consequence worth stating positively: the length the far side
receives is one this processor computed from the designator and checked against
the array (6.7.3.9.5). A program cannot spell a buffer overrun here, which is
the opposite of what an interface of this kind usually does to a safety
property.

**6.7.7.8 Function results.** The result type of an external-declaration shall
be `integer`, `int64`, `real`, a handle-type (6.4.12.4), or an optional-type
(6.4.11) whose component is either a **variable-string-type**
(ISO/IEC 10206:1991 §6.4.3.3.3) or a record-type admitted by 6.7.7.6.2.

Where the result type is an optional-type, a null address shall yield the absent
value, and any other address shall yield a copy, made where the call occurs, of
the value it addresses. Where the component is a variable-string-type, that
value shall be the NUL-terminated string the address designates, and it shall be
an error for it to exceed the capacity (Annex A.5, and it is §6.4.6's error
rather than one added here). Where the component is a record-type, that value
shall be as many contiguous storage units as the record-type occupies.

NOTE 1 — The first draft of this clause said "a string-type having a capacity",
which excludes nothing: §6.4.3.3.2 gives a fixed-string-type a capacity too —
"the capacity of a fixed-string-type shall be the largest value of its
index-type" — so the phrase used a defined term against its definition. What is
meant, and what the processor does, is the variable-string-type: `?string(10)`
is admitted and `?packed array [1..8] of char` is refused, because the length a
foreign routine's answer turns out to have is not known when the call is
written (ADR-0144).

NOTE 2 — **No address obtained from a foreign routine becomes a value of this
language.** What the program holds is a value of its own, with its own lifetime,
and the address is dead by the end of the statement. That is why a size is
required of both components: the copy needs somewhere of a known size to go, and
for the string that somewhere is the capacity while for the record it is the
type itself.

NOTE 3 — The record-type is 6.7.7.6.2's, and the conditions are that clause's
unchanged, because they are asked for the same reason: what is copied is storage
a C compiler laid out, and a field whose representation this processor invented
is not part of any such layout. What 6.7.7.6.2 leaves to the program — that the
field-list *is* the member list of the struct — this clause leaves to the
program in the same way, and 6.7.7.6.2's `@cstruct` annotation is how a program
may have it checked.

NOTE 4 — The quantity copied is what the record-type occupies **here**, not
anything the far side reports, there being nothing it could report. A
record-type declaring a *prefix* of the struct's members therefore copies that
prefix, which is how `struct tm` is read without naming the `char *` member
glibc puts after the nine that matter — where those nine are the first nine and
are in that order, which ISO C 7.27.1 does not require and every implementation
does. A record-type occupying more than the struct reads storage the callee
does not own; that is a requirement on the program, in the same way and for the
same reason 6.7.7.9 c) is.

NOTE 4a — A prefix is a claim about a platform, and this clause admits it
because a *program* is entitled to make one: it knows what it was compiled for,
and 6.7.7.6.2's annotation is how it may have the claim checked. A separately
translated component intended for machines its author cannot build for is not
so entitled, and that is a rule about libraries rather than about this clause
(ADR-0188).

NOTE 5 — A bare `string` result is refused, and the diagnostic names the remedy.
A record-type result is refused for a different reason and the diagnostic names
the same remedy: how a struct is returned *by value* is a fact about C's ABI,
which this processor may not depend on (ADR-0030), so what crosses is an
address. A `?integer` result is refused because C has no null integer for it to
mean.

NOTE 6 — This clause is what makes `readdir`, `gmtime` and `localtime`
declarable. Each answers the address of storage it owns and reuses between
calls, and each answers a null that is an ordinary outcome and not a failure.
The copy is what ends the program's involvement with that storage, which is why
widening this clause leaves 6.7.7.9 c) exactly where it was: nothing here keeps
the address (ADR-0187).

**6.7.7.9 What shall not cross.** An external-declaration shall not have:

- a) a parameter or result of any type not named in 6.7.7.3, 6.7.7.6.1,
  6.7.7.6.2, 6.7.7.7 or 6.7.7.8;
- b) a procedural or functional parameter (§6.7.3.4, §6.7.3.5). What would
  cross is a code address *and* the activation it runs under, and the far side
  takes one word. The second half has no image in C at all, so this is not a
  narrowness a later clause widens by admitting one more type: a callback is a
  different feature;
- c) a result that is an address of storage the callee owns, other than as
  6.7.7.8 admits. This is where this document stops and ADR-0109's
  memory-safety model begins — precisely, a pointer to storage the callee owns
  whose contents are not characters.

NOTE — **c) is a requirement on the program and this processor does not enforce
it, nor can it.** 6.7.7.8 admits an `int64` result, an address fits in one on
every target this processor has, and no processor can tell a count from an
address. So `function ExtOpendir(path: string): int64; external 'opendir'` is
accepted, and what it yields is a `DIR *` that copies freely and that 6.4.2.6.2
makes the operand of every arithmetic operator, deliberately. Annex C.7, and
ADR-0151 for why the memory-safety model this clause defers to does not in fact
begin here.

**6.7.7.10 Reserved foreign names.** The character-string of an
external-directive shall not be a name this processor itself emits.

A name is reserved when it contains `.`, when it begins `pas_`, when it is a
letter `p` or `s` followed only by digits, or when it is `main` or `_setjmp`.

NOTE 1 — The requirement exists because the emitted module declares those names
and a linker's assembler refuses a redeclared global however identical the two
declarations are — so without this the program would be refused by a diagnostic
naming a file nobody wrote.

NOTE 2 — Nothing else in the C library is reserved. In particular `hypot`,
`atan2` and `atan` are **available** to a program: they were reserved when
ADR-0121 landed, and the processor has since taken private names for its own
uses of them. This is one of the divergences from an ADR that writing this
document found, and it is in Annex E.

NOTE 3 — The routines a program may bind in this processor's own runtime are
spelled `pasx_`, are never emitted, and are therefore never reserved. `pas_` is
what the processor emits; `pasx_` is what a program may name (ADR-0131).

**6.7.7.11 One declaration per linker symbol.** Within one program-component,
no two external-declarations shall have the same character-string.

The character-strings are compared exactly. Identifiers in this language are
case-folded (§6.1.3) and a character-string is not one, so `'ABS'` and `'abs'`
are different names and neither is a second declaration of the other.

NOTE 1 — This is 6.7.7.10 from the other side. There the collision is between a
foreign name and one the processor emits; here it is between two foreign names,
and the consequence is the same — two declarations of one global, which a
linker's assembler refuses with a diagnostic naming a file the program's author
never wrote.

NOTE 2 — The requirement is a refusal rather than a rule that the two
declarations agree, and that is deliberate. Nothing in this dialect checks an
external-declaration against the routine it names (6.7.7.8, C.1), so a second
declaration is a second unchecked claim about one symbol and gives a program
nothing that calling the first one does not. Were the processor instead to
emit one declaration for the two, a program declaring `'abs'` once as
`integer -> integer` and once as `real -> real` would translate, link and be
undefined, which is worse than being refused.

NOTE 3 — The restriction is per program-component. Two modules of one program
may each declare the same foreign name; §6.13 translates them separately, each
emits its own declaration, and the linker resolves both to one symbol.

**6.7.8 Task-declarations [added].**

    task-declaration = 'task' identifier formal-parameter-list? ';' block .

A task-declaration shall declare a procedure whose activation may be commenced
only by a spawn-statement (6.9.3.12), and a procedure-statement shall not
commence one. It shall not have a directive; in particular it shall not be an
external-declaration (6.7.7), a task's block being this program's.

`task` is not a word-symbol. A declaration-part admits only `label`, `const`,
`type`, `var`, `procedure`, `function` and `begin`, every one of them a
word-symbol, so an identifier in this position is already a syntax error in
both standards and the dialect may spell what it likes with one (ADR-0140). The
second token is required to be an identifier as well, so a program that has
written `task` alone gets the diagnostic it got before.

**6.7.8.1 What may cross into a task.** Every formal parameter of a
task-declaration shall be a value parameter, and its type shall be
transferable (6.4.16.3), a channel-type, or a handle-type (6.4.12).

It shall not be a variable parameter, and it shall not be a procedural or
functional parameter (§6.7.3.4, §6.7.3.5).

A formal parameter of a handle-type that is not a channel-type shall be
**moved** into the task: the corresponding actual-parameter shall be `take`
(6.4.14.6) applied to a variable-access of that same handle-type. The
variable shall be made empty before the activation is commenced, and the
formal parameter shall hold the value the variable held; the value shall be
released (6.4.12.3) when the activation of the task-declaration's block
ends.

NOTE 1 — **This clause is where share-nothing is enforced, and it is the whole
of it.** A task's body cannot name a variable of the activation that spawned
it except through a formal: this language has no address-of operator, `new` is
the only producer of a pointer, and 6.4.16.3 keeps a pointer out of a channel.
So a rule about formal parameters is a rule about everything a task can reach.

NOTE 2 — A variable parameter would be a second name for a variable of another
activation, running at the same time — the escaping alias this language has
never had (ADR-0201). A procedural parameter would carry the activation it runs
under, which is another task's.

NOTE 3 — A channel is the exception and is the only one. What crosses is the
one word the channel is, and the variable the value arrives in takes a
reference to it, so the two activations name one object — which is what a
channel is for, and it is safe because that object is the only one in this
language with a lock in it.

NOTE 4 — A handle that is not a channel is **moved** where a channel is lent,
and the difference is the whole of what makes each safe. A channel is the one
object two activations may name, and it is safe because it is the only object
in this language with a lock in it; a stream or a socket has no lock, so what
crosses is ownership and not a second name. `take` is required as the
*spelling* rather than inferred, so a reader of the spawn-statement can see
that the variable beside it is empty from that point on (ADR-0302).

NOTE 5 — The value is released when the task's block ends, which is the
ordinary rule for a handle-variable and needs no clause of its own. The
activation that spawned the task no longer holds the value, so 6.9.3.12.1's
join is not what keeps this correct — it is what keeps the *channel* case
correct. Nothing here releases a handle twice, because at no moment do two
variables hold it.

NOTE 6 — A handle-type is not transferable (6.4.16.3), so a channel cannot
carry one. A task may be given a socket; it may not be *sent* one. What would
make sending one expressible is a rule about which activation owns a value in
a bounded queue, and no program here has wanted it (ADR-0302).

NOTE 7 — The task-type (6.4.17) is a handle-type, so the second sentence of
this clause already admits it and it is moved in as any other handle is: a
task may be given a task, and waits for it (6.9.3.14) as the block that
spawned both would have. Nothing was added for this, and saying so is the
point — the rule is the one already written, asked of one more type.

**6.7.8.2 What a task's body may name.** A variable-access occurring in the
block of a task-declaration, or in the block of any procedure or function
declared within it, shall denote a variable declared in that task-declaration
or in a block within it.

NOTE 1 — 6.7.8.1 is not the whole rule, and believing it was is a mistake this
document records rather than hides. Pascal's scope rules let a block name a
variable of an enclosing block, and a program's own variables enclose every
block in it — so two activations of a task incrementing one global is a data
race that a rule about *formal parameters* cannot see. This clause is where it
is refused.

NOTE 2 — The rule is asked of the variable's **owner** and reaches nothing
else: a constant, a type, a routine, a required identifier and a channel handed
in as a parameter all remain nameable. What a task may not have is a second
name for storage another activation may be writing.

NOTE 3 — It is **not** transitive. A task may call a procedure declared outside
it, and that procedure may name whatever its own scope admits — so a task can
still reach a global through a call. Closing that needs a whole-program walk
over the call graph, which this processor does not do, and it is recorded as
unchecked rather than claimed (`doc/sop.md` §7).

### 6.8 Expressions [extended]

#### 6.8.3 Operators [extended]

##### 6.8.3.5 Relational operators [extended]

Neither operand of a relational-operator shall be a slice (6.7.3.9).

NOTE 1 — This is a restriction and not an extension, and it exists because
6.4.5 above is one. The relational operators of ISO/IEC 10206:1991 §6.8.3.5
require compatible operands, so making two slices compatible — which 6.4.5 does
for the sake of parameter passing — would otherwise admit `a[1..2] = a[3..4]`
by a rule written for something else entirely. §6.8.3.5 gives an array no
relational operators at all, and a slice is an array's components with the
extent taken out, so there is nothing for this amendment to have extended.

NOTE 2 — The restriction is on either operand rather than on both, there being
no type on the other side that would make the comparison mean something.

NOTE 3 — A slice whose component-type is `char` is not a string-type: it is
unpacked, and its length is not in its type. So the padded comparison
§6.8.3.5 gives two string-types does not reach it either.

NOTE 4 — Should a comparison of slices ever be wanted, it needs a rule for
operands of unequal length, which this feature deliberately does not have —
6.7.3.9.5's NOTE says the callee cannot see where its slice came from. That
rule belongs here before it belongs in a processor (ADR-0139).

#### 6.8.9 Try-expressions [added]

A try-expression yields the outcome of a fallible value (6.4.13) where there is
one, and where there is not it leaves the enclosing function with the cause.

**6.8.9.1 The spelling.**

    try-expression = 'try' '(' expression ')' .

`try` shall be a required function-identifier, and shall not be a word-symbol;
§6.1.3's shadowing is what keeps it out of the way of a program that declares
its own, as for `exit` (6.7.5.9) and `int64` (6.4.2.6).

NOTE 1 — The parentheses are required, and they are not decoration. `try X`,
with X an expression, is not a spelling this language could have taken: a
factor may be a variable-access, so a conforming program that declares `try`
may write `try (x)`, `try [x]`, `try + x`, `try - x`, `try.f` and `try^`, and
each means something there. Only an operand beginning with an identifier, a
number, a character-string, `nil` or `not` would have been unambiguous — which
is not a rule about a construct but a rule about six of its operands. So the
test 6.9.3.11 applies to a statement (ADR-0140) does not transfer to a factor,
and this is the second construct to take a required identifier because no
position would serve.

**6.8.9.2 The operand.** The expression shall be of a fallible-type (6.4.13).
The try-expression shall possess that type's value-type.

**6.8.9.3 Where it may occur.** A try-expression shall occur only within a
function-block, and the cause-type of its operand shall be assignment-
compatible with the result-type of that block.

NOTE 2 — The result-type is not required to be a fallible-type. Where it is,
6.4.13.3's shorthand makes the assignment set the cause; where it is the
cause-type itself, the cause is assigned directly; where it is neither, the
program is refused by the requirement above. All three follow from the
assignment 6.8.9.4 b) makes, and none of them is a rule of its own.

**6.8.9.4 What it denotes.** The expression shall be evaluated once. Then

a) where the value is an outcome, the try-expression shall yield that outcome;

b) otherwise the cause shall be assigned to the result of the enclosing
   function, and the activation of that function-block shall be terminated —
   both as 6.7.5.9's `exit ( expression )` does them.

NOTE 3 — Because b) is that clause, everything terminating an activation
entails is that clause's: an armed statement (6.9.3.11.2 b) is executed, a
file or handle the block owns is closed, and the value of the function is
taken from its result variable. A try-expression written in a function nested
in another terminates the nested one and nothing else, 6.7.5.9's block being
the one the construct occurs in.

NOTE 4 — "Evaluated once" is what distinguishes this from the three field
accesses it is otherwise equivalent to. `try(f(x))` calls f once; the
expansion a reader writes for it — `if f(x).ok then f(x).val else …` — calls
it three times, and where f has an effect that is a different program.

**6.8.9.5 What it discharges.** A try-expression shall discharge §6.7.2's
requirement that a function-block contain at least one assignment to the
function-identifier, and, where a result-variable-specification was written,
its requirement that at least one statement threaten the result variable — as
an exit-statement does (6.7.5.9), and for the same reason: it assigns the
result.

NOTE 5 — It discharges those requirements on every path, and makes the
assignment on one. A function whose only assignment to its result is a
try-expression's therefore has no value where its operand yielded an outcome.
That is not detected; Annex C records it beside 6.7.5.9's own case.

NOTE 6 — 6.9.3.11.3 forbids a try-expression in a deferred statement, for the
reason it forbids an exit-statement.

NOTE 7 — Neither standard has propagation and no Pascal does; the construct is
Zig's `try` and Rust's `?` (ADR-0178), and it is spelled as a required function
because that is how Pascal spells an operation on a value.

### 6.9 Statements [extended]

#### 6.9.3.11 Defer-statements [added]

A defer-statement **arms** a statement, which is then executed when the block
leaves the region it was armed in — so that a program may write what undoes an
action beside the action, rather than at every place control can leave
(ADR-0175).

    defer-statement = 'defer' statement .

`defer` shall not be a word-symbol. A statement beginning with an identifier
in a program of ISO/IEC 10206:1991 can continue only as a designator (`:=`,
`[`, `.` or `^`), as a procedure-statement with an actual-parameter-list
(`(`), or not at all — a token that terminates a statement, which by §6.9.2.1
is any of `;`, `end`, `else`, `until` and `otherwise`. A defer-statement is
the case where the token after the identifier is none of those, which is
ADR-0140's test asked of that position. A program in which `defer` denotes
something of its own keeps that meaning in every position such a program could
have written it in.

**6.9.3.11.1 Arming.** Executing a defer-statement arms its statement.
Executing a defer-statement whose statement is already armed shall have no
further effect.

**6.9.3.11.2 Execution.** An armed statement shall be disarmed and executed at
the first of:

a) the completion of the statement-sequence in which the defer-statement
   occurs — the statement-sequence of a compound-statement (§6.9.3.2), of a
   repeat-statement (§6.9.3.7), or of a case-statement-completer (§6.9.3.5);

b) the termination of the activation of the block in which the defer-statement
   occurs, including termination by a goto-statement leaving that block
   (§6.9.2.4) and by `halt` (§6.7.5.7).

Where more than one statement of one statement-sequence is armed, they shall be
executed in the reverse of the order in which their defer-statements are
written.

Armed statements shall be executed before any file (§6.7.5) or handle (6.4.12)
the block owns is closed, and before the value of a function is taken from its
result variable.

**6.9.3.11.3 What a deferred statement may not contain.** A deferred statement
shall contain no goto-statement, no label, no defer-statement, no
exit-statement (6.7.5.9) and no try-expression (6.8.9).

The last two are restrictions later clauses add, and they are written into this
one so that it is the whole list. 6.7.5.9's first draft left them apart — its
NOTE 3 said this clause forbids an exit-statement while this clause said
nothing of the kind, so a processor reading only the numbered requirements
would have been right to allow one.

NOTE 1 — A branch of an if-statement, the body of a while- or for-statement,
the body of a with-statement and a case-list-element are each a *statement* and
not a statement-sequence (§6.9.3), so a defer-statement written directly in one
is armed in the enclosing sequence and not in the branch. Where a loop body is
a compound-statement, which is how one is usually written, the sequence is
completed once per iteration and what that iteration armed is executed there —
with the values that iteration had, since 6.9.3.11.2 executes the statement and
does not evaluate anything at the moment of arming.

NOTE 2 — Leaving a statement-sequence by a goto-statement does not complete it,
so what it armed waits for b). The statement is executed late rather than not
at all, and 6.9.3.11.1's "no further effect" is what keeps a backward
goto-statement over a defer-statement from arming twice.

NOTE 3 — 6.9.3.11.3 is a consequence of the lowering and is stated here so that
it is a requirement rather than a discovery. A processor may execute a deferred
statement in more than one place — this one emits it where its sequence is
completed and again in a routine the run-time system calls for b) — so a label
in one denotes more than one statement, and a goto-statement in one has no
target in the activation that would run it.

NOTE 4 — Nothing here gives a deferred statement a value or an outcome. A
deferred statement that fails fails where it stands; there is no exception in
this language for it to raise, and 6.9.3.11.2 gives it nothing to report to.

NOTE 5 — An armed statement is not executed when the program is terminated by
an error being detected (§3.2, Annex A), because such a termination is not the
termination of an activation.

#### 6.9.3.12 Spawn-statements [added]

    spawn-statement = 'spawn' [ variable-access ':=' ] procedure-identifier
                      actual-parameter-list? .

The procedure-identifier shall denote a task (6.7.8). Executing a
spawn-statement shall commence an activation of that task which proceeds
concurrently with the statement following, and shall not wait for it.

The actual parameters shall be evaluated, and each value copied, before the
activation commences. An actual-parameter corresponding to a formal parameter
of a handle-type that is not a channel-type shall be `take` (6.4.14.6) applied
to a variable-access of that type, and what is copied shall be the value that
variable held, the variable being made empty (6.7.8.1).

**The second form names the activation [added].** Where a variable-access and
`:=` stand between `spawn` and the procedure-identifier, the variable-access
shall denote a variable of the task-type (6.4.17). The activation shall be
commenced exactly as the first form commences it, and the variable shall then
hold that activation. The value the variable held, if any, shall be released
(6.4.17.3) first, and the variable shall be **threatened** in the sense of
ISO/IEC 10206:1991 §6.9.4 a), as the variable-access of an
assignment-statement is.

`spawn` is not a word-symbol, and the position is `defer`'s (6.9.3.11): a
statement beginning with an identifier can continue only as a designator, as a
call, or not at all, so an identifier after the name is a token no conforming
program can have written there. `spawn;`, `spawn(x)` and `spawn := 3` all
remain what a program that declared `spawn` meant by them.

NOTE 1 — The two forms are one statement and not two, which is why the join
(6.9.3.12.1) says nothing about them. Naming an activation adds a way to
reach it and takes it out of nothing: the block commenced it, so the block
completes it.

NOTE 2 — The forms are told apart with no symbol table and no backtracking
over anything the parser has built. A procedure-identifier is followed by `(`
or by a terminator and never by a selector, so a scan from the identifier
after `spawn` — through a selector's brackets, dots and arrows — reaches `:=`
in the second form and reaches something else in the first. `spawn P(x)`,
`spawn P` and `spawn P;` are read exactly as they were, and `spawn := 3` and
`spawn(x)` still belong to a program that declared its own `spawn`.

NOTE 3 — It is a variable-access and not an identifier because
`spawn ws[i] := Worker(jobs)` is the statement a pool of workers is written
with (6.4.17.2 NOTE 2). Threatening it is what makes a `for` control-variable
(§6.8.3.9) and a protected parameter (§6.7.3.1) refused there, which is the
answer an assignment would have given and is the same rule rather than a
second one.

**6.9.3.12.1 The join.** Every activation a block commenced shall be complete
before that block's activation ends, and before any variable of that block is
released.

NOTE 1 — **This is the whole safety argument of the construct.** A task's body
is reached through a static link into the spawning activation's storage, and it
holds a reference to whatever channels it was given. ADR-0201 observed that
every alias in this language is safe *because* there is one thread of control —
a variable parameter cannot outlive the call, because the caller is not running
during it — and named two threads of control as the one thing that breaks that
sentence. The join is what makes it true again.

NOTE 2 — The order in the second sentence is not tidiness. The block's
deferred statements (6.9.3.11) run statements of the block, and releasing its
handles closes what a task may still be using, so both must happen after the
join and not before.

NOTE 3 — A spawn-statement shall not be a deferred statement (6.9.3.11.3),
because a deferred statement is executed when the statement-sequence it stands
in is completed, which is after the join: such a task would be joined by
nothing.

#### 6.9.3.13 The channel operations [added]

**6.9.3.13.1 send.** The required procedure-identifier `send` shall take a
channel-variable and an expression assignable to the channel's component type.
The value shall be copied into the channel. Where the channel is full the
activation shall wait until it is not; where the channel has been closed
(6.4.16.4) it shall be an error.

**6.9.3.13.2 receive.** The required function-identifier `receive` shall take a
channel-variable and a variable of the channel's component type, and shall
yield a value of type `boolean`. Where a value is available it shall be
written into the variable and the result shall be *true*. Where the channel is
empty the activation shall wait; where it is empty and has been closed
(6.4.16.4) the result shall be *false* and the variable shall not be written.

The variable shall be threatened (§6.9.4) as `read`'s is.

NOTE 1 — One is a procedure and the other a function, and the asymmetry is the
design. A send either happens or the program has lost track of who is
listening, which is a fault of the kind this language stops for (Annex A). A
receive has an ordinary second outcome — the channel is closed and drained —
and that outcome *is* the loop condition a reader wants: `while receive(c, v)
do` reads as what it does, where a procedure would need a flag beside it.

NOTE 2 — A closed channel is drained before the close is reported, so the
values still in flight when a program closes a channel are delivered. That is
what makes closing a job channel the way to tell a pool of workers that there
is no more work — and, since 6.4.16.4, what makes a pipeline of tasks each
closing the channel downstream of it terminate.

NOTE 3 — Both are required identifiers, so a program that declares its own
`send` or `receive` keeps it (§6.1.3), which is `int64`'s and `exit`'s route
(ADR-0128, ADR-0177).

NOTE 4 — These two are the operations a select-arm performs (6.9.3.15), and
that clause restates neither. What it adds is the *waiting*: which of several
channels an activation waits on, and what happens when none of them is ready.
A send and a receive written in a select-arm mean what this clause says they
mean, including the error a closed channel is.

#### 6.9.3.14 wait [added]

The required procedure-identifier `wait` shall take one actual-parameter,
which shall be a variable-access of the task-type (6.4.17). The activation
executing the statement shall not proceed past it until the activation the
variable holds is complete.

Where that activation is already complete, and where the variable has been
waited for before, the statement shall have no effect.

It shall be an error (Annex A.7) for the variable to be empty.

NOTE 1 — Waiting for one task and joining all of them are the same statement
asked twice, and that is the whole of what makes this clause safe. `wait` does
not take the activation out of the set 6.9.3.12.1's join walks; it completes it
earlier, so the join then finds it complete and returns at once. So naming an
activation weakens nothing: every alias argument this language rests on —
ADR-0201's *a borrow cannot outlive the call* above all — is an argument about
the join, and the join is untouched.

NOTE 2 — The empty variable is an error rather than a statement with no
effect, which is `send`'s treatment of a closed channel (6.9.3.13.1) and is
chosen for the same reason. A variable a program forgot to spawn into would
otherwise read as an activation that has already finished, and a program would
be told that work was done which was never started. It is Annex A.7's error
and not one of its own: the task-variable is **lent** exactly as 6.4.12.4
lends a handle, and the error is the one that already stands there.

NOTE 3 — Waiting twice is *not* an error, and the asymmetry with NOTE 2 is
deliberate. An emptied variable never held an activation, while a variable
waited for twice held one and the answer is known — which is what lets a
program `wait` in a loop it may leave and again on the way out, and what lets
the block's own join arrive after a `wait` the program wrote.

NOTE 4 — `wait` is a procedure and not a function, there being no result to
answer: a task yields no value, and what it computed comes back through a
channel (6.4.16). A program that wants an answer as well as a completion
writes both, and the two are ordered by 6.4.16.4's close rather than by this
statement.

NOTE 5 — There is no timeout and no way to ask whether an activation is
complete without waiting for it. Each is a construct of its own and neither is
implied by this one; they are recorded as open (ADR-0312) rather than
half-answered by a `wait` that could give up, which would leave a program
holding a task-variable whose activation is still running and no clause
saying what that means.

NOTE 6 — `wait` is a required identifier, so a program that declares its own
`wait` keeps it (§6.1.3), which is `send`'s and `exit`'s route (ADR-0128,
ADR-0177).

#### 6.9.3.15 The select-statement [added]

    select-statement = 'select' select-arm { ';' select-arm }
                       [ [ ';' ] 'otherwise' statement-sequence ] 'end' .
    select-arm       = channel-arm | timeout-arm .
    channel-arm      = [ variable-access ':=' ] identifier
                       actual-parameter-list ':' statement .
    timeout-arm      = 'after' expression ':' statement .

A select-statement shall wait until one of its channel-arms can proceed, shall
perform that arm's operation, and shall then execute that arm's statement. It
shall perform the operation of one arm and execute the statement of that arm
and of no other.

A select-statement shall have at least one channel-arm and at most one
timeout-arm, and shall not have both a timeout-arm and an otherwise part.

`select` is not a word-symbol, and the position is `defer`'s (6.9.3.11) and
`spawn`'s (6.9.3.12): a statement beginning with an identifier can continue
only as a designator, as a call, or not at all, and a select-statement's first
arm always begins with an identifier — `receive`, `send`, `after`, or the
variable of `ok := receive(c, v)`. So `select;`, `select(x)` and `select := 3`
all remain what a program that declared `select` meant by them.

NOTE 1 — The shape and the punctuation are the case-statement's (§6.9.3.5):
arms separated by `;`, an optional `otherwise` last whose separator is itself
optional, and `end` to close. What differs is that an arm's head is an
operation rather than a list of case-constants, and that the arm which is
executed is chosen by what has happened elsewhere rather than by a value the
statement computed.

NOTE 2 — This is the statement a program that must service a job queue *and*
notice a shutdown signal is written with. Without it the two have to be folded
into one channel, which is a program writing a discriminated union because the
language would not let it wait for two things (ADR-0312, ADR-0313).

**6.9.3.15.1 The arms.** The identifier of a channel-arm shall denote the
required procedure-identifier `send` (6.9.3.13.1) or the required
function-identifier `receive` (6.9.3.13.2), and the actual-parameter-list
shall be the one that clause gives to the operation. Where the identifier has
a defining-point in the program (§6.1.3), the arm shall be refused.

A channel-arm whose identifier denotes `receive` may be written with a
variable-access and `:=` before it. That variable-access shall possess the
type `boolean` and shall be **threatened** in the sense of ISO/IEC 10206:1991
§6.9.4 a), as the variable receiving the value is. Where the arm proceeds, the
variable shall be assigned the value 6.9.3.13.2 gives the function: *true*
where a value was delivered, and *false* where the channel had been closed
(6.4.16.4) and drained.

A channel-arm can proceed

a) where its identifier denotes `receive`, when a value is available, and when
   the channel has been closed and drained; and

b) where its identifier denotes `send`, when the channel is not full.

Sending on a channel that has been closed shall be 6.9.3.13.1's error wherever
it is written, and shall not be an arm that cannot proceed.

It shall be an error (Annex A.8) for the channel-variable of an arm to be
empty.

NOTE 1 — Which operation an arm performs is decided by the **symbol** and not
by the spelling, which is ADR-0087's recurring rule. `send` and `receive` are
required identifiers, so a program may declare its own (§6.1.3); an arm naming
one the program declared is naming a routine that cannot be waited on, and is
refused rather than quietly meaning the required operation.

NOTE 2 — That a drained closed channel lets a `receive` arm proceed is what
terminates a select over channels that have all closed. It is 6.9.3.13.2's own
second outcome and not a rule of this clause, and the boolean written before
`:=` is how a program tells the two apart — which is what makes `while ok do
select … ok := receive(jobs, j): …` a drain loop rather than a program waiting
for something that cannot arrive.

NOTE 3 — An activation cannot close a channel and then drain it: all three
spellings of a release the program wrote (6.4.16.4) empty the variable holding
the channel as well as closing it. So the close a select reports is always one
performed by *another* activation — the ordinary pipeline shape, a producer
task closing what a consumer drains. Closing without releasing would be an
operation of its own and this document defines none (ADR-0313).

NOTE 4 — An empty channel-variable is an error and not an arm that waits for
ever, which is `send`'s and `receive`'s treatment of one and is chosen for
their reason: a variable a program forgot to give a channel to would otherwise
read as a channel on which nothing has happened yet.

**6.9.3.15.2 What is evaluated, and when.** Each channel-arm's
channel-variable, the variable a `receive` arm writes, and the expression a
`send` arm sends shall each be evaluated once, where the select-statement
stands, before the statement waits. The value of a `send` arm's expression
shall be retained until that arm proceeds or the statement gives up
(6.9.3.15.4).

NOTE — A select-statement may look at its arms many times before one of them
proceeds, and how many times is a fact about the execution of other
activations. An actual that was evaluated on each look would make that number
observable, so it is evaluated once; and the value a `send` arm holds is
therefore the value the expression had where the statement was written and not
where the send happened.

**6.9.3.15.3 Which arm proceeds.** Where more than one channel-arm can
proceed, which one does so is not determined by the order in which the arms
are written, and a program shall not depend upon it.

NOTE — Trying the arms in written order is what this clause exists to forbid.
A channel that is always ready would then starve every arm below it, and the
arm below is the shutdown signal of the very program NOTE 2 of 6.9.3.15
describes: a worker servicing a busy job queue would never look at it. The
processor rotates the arm it looks at first, so that over *n* executions each
arm is looked at first once (ADR-0313).

**6.9.3.15.4 Giving up.** The expression of a timeout-arm shall be of an
integer-type and shall denote a number of milliseconds. It shall be evaluated
once, where the select-statement stands. Where no channel-arm has proceeded
before that many milliseconds have elapsed, the select-statement shall proceed
no further with its channel-arms and shall execute the statement of the
timeout-arm. It shall be an error (Annex A.9) for the value of the expression
to be negative.

Where a select-statement has an otherwise part it shall not wait: the
channel-arms shall be looked at once and, where none of them can proceed, the
statement-sequence of the otherwise part shall be executed.

NOTE 1 — `otherwise` is a deadline of zero, which is why a select-statement
may have a timeout-arm or an otherwise part and not both. Two ways of saying
*give up after this long* in one statement is a contradiction and not a
refinement, and refusing it says so where a rule choosing the earlier of the
two would have hidden it.

NOTE 2 — `after` is the one spelling this construct reserves, and it reserves
it **inside a select-statement and nowhere else**. No conforming program can
be inside one at all, so the word costs nothing outside these brackets
(ADR-0140). Making it a required identifier instead was rejected: `after(x):
S` would then be a channel-arm in a program that had declared its own `after`
and a timeout-arm in every other, which is a construct whose meaning depends
on a declaration the reader of the arm cannot see (ADR-0313).

NOTE 3 — The deadline is a wall-clock delay in milliseconds and nothing finer,
and it bounds the *select-statement* and not any other construct. There is
still no timeout on a `send` (6.9.3.13.1), on a `receive` (6.9.3.13.2) or on a
`wait` (6.9.3.14); the last is refused for 6.9.3.14 NOTE 5's reason, a task
not being a channel and a `wait` that gave up leaving a program holding a
task-variable whose activation is still running.

### 6.10 Input and output [extended]

Extended by 6.4.2.6.6. No other change.

### 6.11 Modules [extended]

A module shall be translated under a language 6.13.1 permits it to be linked
with, which is not in general the same language as every other
program-component: 6.13.1 grants an exception this clause must not withdraw.

NOTE — The first draft of this clause said "the same language as every
program-component it is linked with", which is strictly stronger than 6.13.1
and forbids exactly the case ADR-0137 exists for and `lib/` depends on — a
conforming module whose interface exposes nothing checked, linked into an
Afterschool Pascal program. The processor obeys 6.13.1 and so violated the
letter of this clause. It was found by an audit, and by a route worth recording:
the clause was classified `structural` in `tests/spec/clauses/triage.tsv`, and a
`structural` clause may carry no scenario — so its requirement was unfalsifiable
by construction while contradicting a `testable` one (ADR-0144).

### 6.13 Programs

#### 6.13.1 Program-components shall be of one language [added]

Every program-component shall be a component of Afterschool Pascal, and a
program-component shall be linked only with components translated by a
processor implementing this document.

NOTE 1 — There is nothing here for a source to state and nothing for a
processor to decide (6.0.2). The requirement is about *objects*: a component
translated by some earlier processor of some other language is a file this
document says nothing about, and linking it is outside this specification
however well the names happen to match.

NOTE 2 — It is enforced at the link. ADR-0119 decided that the language forms
part of the name of a module's activation procedures — a name §6.13 already
requires the components to agree on — and ADR-0232 decided that there is one
language, so the two records together leave that part of the name with a single
value. Two components a conforming processor translates therefore cannot
disagree about it, and an object left over from a processor that admitted more
than one language leaves the symbol undefined, which a reader can be told about
rather than linking and disagreeing about 6.4.3.4. A probe demonstrates the
requirement: a module translated separately and linked into a program that
imports it resolves, and the same program linked against no object at all names
the missing activation procedure (ADR-0119, ADR-0232).

NOTE 3 — *historical.* This clause required considerably more until ADR-0232,
and what it required is worth keeping legible, because 6.4.3.4's two
requirements are a pair and §6.13's separate translation is exactly what could
split them across components: the surviving half would check a tag the other
half never set, and would answer *safe* for an unsafe access — worse than the
documented hole it replaced. While there were two conformance modes, a
component translated under `--std=extended` emitted no such check, so the
clause forbade the mixture — and then had to admit it back for the one case
`lib/` depends on, a module whose interface **exposed nothing checked**,
meaning no type reachable from it through a field, an array component, a file
component, a pointer domain or a parameter was a record-type with a tagged
variant-part (ADR-0137). The exception was asymmetric: a dialect module may
declare `external` routines (6.7.7) and so could not go the other way, into a
program claiming conformance.

With one language the split cannot occur: every component is translated by a
processor implementing 6.4.3.4, so every half of every pair is emitted. The
requirement was not relaxed, it was dissolved — which is a different thing, and
the reason this NOTE says how it used to be met.

NOTE 4 — `lib/` and `lib/dialect/` remain two directories, and no longer for
this reason. The first holds modules a *conforming* processor could also
translate; the second holds modules that need this document. Nothing in this
clause distinguishes them any more, and Annex D gives the reason they are still
apart.

#### 6.13.2 Program-components shall agree about the interfaces they share [added]

A program-component shall be linked only with components translated against
the same module-heading for every interface they both name.

NOTE 1 — As with 6.13.1 there is nothing here for a source to state. §6.11.1
makes a module-heading the whole of what a client may depend on, and §6.13
translates the components separately, so two translations may read two
different headings for one module and agree about every *name* in them. The
requirement is about objects and is met at the link.

NOTE 2 — It is enforced the way 6.13.1 is, and deliberately: a digest of the
module-heading's tokens forms part of the name of that module's activation
procedures, which §6.13 already requires the components to agree on. A program
calls that name once for every module it activates (§6.2.3.6), so a component
translated against a different heading leaves the symbol undefined and cannot
reach an executable (ADR-0245).

NOTE 3 — The digest is of *tokens*, so a heading that differs only in comment,
spelling of a separator or layout is the same heading for the purpose of this
clause, and a change confined to a module-block is not a change to a heading at
all. This is a requirement about interfaces and not about files; a processor
that refused every object whose source had been edited would satisfy the words
and be useless.

NOTE 4 — What this clause costs when it is not met is why it is stated. A
module-heading declaring `record a, b: integer` and one declaring
`record tag: integer; a, b: integer` name the same type, the same fields and
the same procedures, so a program built against the second and linked against
an object built from the first resolves every symbol, runs, and reads a field
from an offset the other component never wrote. The processor's own probe
measured it: `a=11 b=22` written and `a=11 b=0` read back, with a zero exit
status and no diagnostic from the translator, the driver or the linker
(`tests/checks/stale_component.sh`).

NOTE 5 — No interface artefact is defined by this document, and this clause is
what stands in place of one. A processor that wrote a compiled interface file
would have a second artefact to keep in step with the source; the requirement
here is met without one, because the heading a translation read is the only
thing the digest is over.

---

## Annex A (normative) — Errors this dialect detects

Each is an error in the sense of ISO/IEC 10206:1991 §3.2 that the conformance
modes leave undetected or that arises only from a construct this document adds.
Detection terminates the program with a non-zero status and a message on the
standard error stream.

| | Error | Clause | Message |
| --- | --- | --- | --- |
| A.1 | a field of an inactive variant is accessed | 6.4.3.4.2 | `variant: the tag selects another arm` |
| A.2 | the value of an absent optional is accessed | 6.4.11.5 | `this optional has no value` |
| A.3 | a slice is taken outside the array's bounds | 6.7.3.9.5 a) | `slice: [i..j] is not within a sequence of n components` |
| A.4 | a string crossing to a foreign routine contains NUL | 6.7.7.5 | `a string crossing to a foreign routine contains a NUL character` |
| A.5 | a foreign string result exceeds the capacity | 6.7.7.8 | `a string of length n does not fit a capacity of c` |
| A.6 | `argument(k)` with `k` outside 1..`argcount` | 6.7.6.10 | `argument k is not in 1..n` |
| A.7 | an empty handle is lent to a foreign routine | 6.4.12.4, 6.9.3.14 | `the handle is empty, and a foreign routine may not be lent it` |
| A.8 | a select-arm names an empty channel-variable | 6.9.3.15.1 | `a select arm names an empty channel variable` |
| A.9 | a select-statement is given a negative delay | 6.9.3.15.4 | `a select statement cannot wait for a negative time` |

Indexing a slice out of range (6.7.3.9.5 b) is reported by the array-index error
ISO 7185 and ISO/IEC 10206:1991 already have, against the slice's own bounds.

Waiting (6.9.3.14) on an empty task-variable is A.7's error and carries A.7's
message: the variable is lent as 6.4.12.4 lends a handle, and a second message
would be a second name for one condition.

A.8 is **not** A.7's error, though both are an empty handle. A.7 is about a
handle *lent to a foreign routine* (6.4.12.4), and nothing foreign is reached
here; what a reader of A.8 needs told is which arm of the select-statement was
written against a variable holding no channel. A `send` (6.9.3.13.1) or a
`receive` (6.9.3.13.2) written outside a select-statement reports the same
condition in its own words for the same reason.

## Annex B (historical) — Refusal under the conformance modes

**This annex describes a processor that no longer exists.** ADR-0232 removed
`--std` and the two conformance modes, so there is no mode in which any of the
constructs below is refused: they are the language. It is retained because it
is the only place that records, construct by construct, what each conformance
mode said about the dialect — which is the evidence the `annex-b` gate checked
on every run until that gate was retired with its subject.

Read it as history. Nothing in it is a requirement of this document, and the
messages it quotes are no longer emitted.

What follows is the annex as it stood.

Each construct this document adds was refused under `--std=iso7185` and
`--std=extended`, and this annex records how, because it was a conformance
question even though the feature was not (5.3).

**The two modes do not always say the same thing**, which this annex claimed
they did until the rows were probed rather than read: ISO 7185 has no substring
notation at all, so its parser stops at the `..` where Extended Pascal parses
the construct and Sema refuses it. One column became two.

`utf8` is the second such row and differs for the same kind of reason. It is a
required *schema* identifier, and ISO 7185 has no discriminated schema at all —
so that mode stops at the syntax, where Extended Pascal parses it and finds no
schema of that name. A row whose two columns agree is the common case and not
the rule.

| Case | Construct | `--std=iso7185` says | `--std=extended` says |
| --- | --- | --- | --- |
| `foreign` | `external` | `the 'external' directive is an Afterschool Pascal feature` | `the 'external' directive is an Afterschool Pascal feature` |
| `optional` | `?` | `unexpected character '?'` | `unexpected character '?'` |
| `slice` | `array of T` | `a parameter's type must be a type name or a conformant array schema` | `a parameter's type must be a type name or a conformant array schema` |
| `substring` | `a[i..j]` over an array | `expected ']' after a subscript, found '..'` | `only a string can have a substring taken of it` |
| `int64` | `int64` | `unknown type 'int64'` | `unknown type 'int64'` |
| `argument` | `argcount`, `argument(k)` | `unknown function 'argument'` | `unknown function 'argument'` |
| `handle` | `handle external '…'` | `expected ';' after a type definition, found identifier` | `expected ';' after a type definition, found identifier` |
| `defer` | `defer S` | `expected 'end' at the end of a compound statement, found identifier` | `expected 'end' at the end of a compound statement, found identifier` |
| `fallible` | `T ! E` | `unexpected character '!'` | `unexpected character '!'` |
| `exit` | `exit`, `exit(e)` | `unknown procedure 'exit'` | `unknown procedure 'exit'` |
| `try` | `try(x)` | `unknown function 'try'` | `unknown function 'try'` |
| `break` | `break` | `unknown procedure 'break'` | `unknown procedure 'break'` |
| `continue` | `continue` | `unknown procedure 'continue'` | `unknown procedure 'continue'` |
| `owned` | `owned ^T` | `expected ';' after a variable declaration, found '^'` | `expected ';' after a variable declaration, found '^'` |
| `take` | `take(v)` | `unknown function 'take'` | `unknown function 'take'` |
| `release` | `release(h)` | `unknown function 'release'` | `unknown function 'release'` |
| `typedisc` | `T: type` in a schema | `a schema is an Extended Pascal feature; compile with --std=extended` | `the type of a discriminant must be an ordinal type name` |
| `typeparam` | `T: type` in a formal-parameter-list | `a type-inquiry is an Extended Pascal feature; compile with --std=extended` | `a type parameter is an Afterschool Pascal feature; compile with --std=afterschool` |
| `ptrtypedisc` | `^Vec(integer)` | `a pointer domain with type arguments is an Afterschool Pascal feature; compile with --std=afterschool` | `a pointer domain with type arguments is an Afterschool Pascal feature; compile with --std=afterschool` |
| `typeinquiry` | `type of a[1]` | `a type-inquiry is an Extended Pascal feature; compile with --std=extended` | `a type-inquiry over a component of a variable is an Afterschool Pascal feature; compile with --std=afterschool` |
| `utf8` | `utf8(n)` | `a discriminated schema is an Extended Pascal feature; compile with --std=extended` | `unknown schema 'utf8'` |

Only the first names the dialect. That is not an oversight: ADR-0140's rule is
that a dialect construct is spelled in a *position* where a conforming program
could not have written it, so most of these are refused by machinery that
predates the dialect and has nothing to say about it. `external` is the
exception because §6.1.4 makes a directive an ordinary identifier in the one
position it may occupy, so nothing but a rule about the mode can refuse it
(ADR-0154).

`int64`, `argument`, `exit`, `break`, `continue`, `try` and `take` are a third
shape and not a
fourth: each is a required *identifier* rather than a position, so a
conformance mode refuses it by not having it — the name is nobody's there, and the message says
so. The shape is now as common as the position rule it was once the exception
to, and 6.8.9's NOTE 1 says why the last of them could not have used a
position: the test that distinguishes a statement does not transfer to a
factor.

**This table is checked.** The `Case` column names a pair of test cases,
`tests/<case>_refused_iso.pas` and
`tests/extended/<case>_refused.pas`, and the
`annex-b` gate requires each to exist, to be refused, and for its golden to
contain the message this table states. It fails in both directions: a row with
no cases, and a `*_refused` case naming no row. So a sixth dialect construct
cannot be added with a row here and no case, or with cases and no row.

The reference front end in `src/` carries these refusals although it implements
no dialect feature, because what a conformance mode says about a program is
part of the surface that must not regress (ADR-0117, ADR-0121). Since the cases
are ordinary `.pas` files under `tests/`, `selfhost/difftest.sh` compares the
two front ends on every one of them — which is the only place the dialect
reaches a second implementation at all, `difftest` skipping a dialect source by
directory.

## Annex C (informative) — What this processor does not check

Every entry is a requirement stated in this document or in a document it cites,
which this processor does not enforce. `doc/sop.md` §7 is the live register;
this annex is the part of it belonging to the dialect.

**C.1 No foreign signature is checked at all.** Neither the number of arguments,
nor their types, nor the result type is compared against the routine actually
named. §6.1.4's NOTE recommends enforcing type compatibility across the
boundary (6.1.4 NOTE 2) and this processor does not: it has no declaration of
the far side to check against, having no way to read one. The emitted
declaration is documentary — a mutation giving it the wrong arity assembles,
links and runs (ADR-0121, ADR-0129).

**C.2 A variant-part with no tag-field is unchecked** (6.4.3.4.5).

**C.3 An optional's check is not narrowed by a preceding test** (6.4.11.5
NOTE 2).

**C.4 Nothing checks that a foreign routine respects a slice's length**, or that
it does not retain an address after returning. Both are promises; what is
claimed is that the number handed over is correct (6.7.7.7 NOTE 3).

**C.5 No second implementation compares any of this**, and since ADR-0232 none
compares anything else either. `src/` was a reference front end frozen at the
conformance surface, so `selfhost/difftest.sh` skipped a dialect source and
counted the skip; the surface was withdrawn and both were deleted. The entry is
therefore stronger than when it was written: what was true of the dialect alone
is now true of the whole front end. The oracles that do reach a dialect source
are the goldens in `tests/dialect/`, `selfhost/irtest.sh`, and `verify/` for
any lowering with a rule (ADR-0117, ADR-0232).

**C.6 No third-party corpus reaches it, and no third-party processor either.**
The BSI Pascal Validation Suite was ISO 7185 and fixed, and it is gone: 25 of
its 812 programs use a word-symbol 6.1.2 reserves, so this compiler cannot
compile the corpus at all (ADR-0232). A second *processor* was added instead —
`fpc-differential` runs Free Pascal over every case in `tests/` and
`tests/extended/` that has a golden (ADR-0234) — and it does not touch this
document: nobody else implements this language, so `tests/dialect/` is compared
by nothing. That is the entry, and it is the one thing here that no gate can
ever discharge.

**C.7 A result that is an address is forbidden and not refused** (6.7.7.9 c)).
The clause states the requirement; 6.7.7.8's `int64` is a door through it that
cannot be shut without withdrawing the type `read` and `write` were given it
for. Every property an owned handle would have is therefore absent rather than
pending: it copies, arithmetic on it is legal, and releasing it twice is
whatever the far side does about that — for `closedir`, an abort.
`tests/dialect/foreign_int64_handle.pas` is the program, kept as a gap that
fails in both directions (ADR-0151). **Since 6.4.12 there is a type through
which such an address is owned instead** (ADR-0174), and a program that wants
the properties listed absent here writes a handle-type; this entry is what the
`int64` door still costs a program that uses it, and the door stays open
because `read` and `write` answer through it.

**C.8 An armed statement is not executed when an error is detected**
(6.9.3.11.2 b), Annex A). Terminating the program because an error was detected
is not the termination of an activation, and this processor runs no deferred
statement on that path: it writes the message and stops. A program whose
release matters on the error path has nothing here to write it with, there
being no exception in this language to catch (ADR-0175).

**C.9 A function that exits without a result is not detected** (6.7.5.9). An
exit-statement discharges §6.7.2's requirement that the block *contain* an
assignment to the result, which is a syntactic requirement and the one the
standard states; whether the assignment was **executed** on the path the exit
took is not asked. `function f: integer; begin if c then exit; f := 1 end`
yields whatever the result storage held when `c` was true. This is the same
omission as for a block that falls off its end without having assigned, which
this processor does not detect either — nor did either conformance mode while
they existed — and it is ISO 7185 §6.6.2's own error rather than a violation
(ADR-0177).

**C.10 A function whose only assignment to its result is a try-expression's is
not detected** (6.8.9.5). This is C.9 reached by the other door and is worth
its own entry because the omission is easier to write by accident: 6.8.9.5
discharges §6.7.2 on every path and 6.8.9.4 b) makes the assignment on one, so
`function f: R; begin n := try(g) end` has a result only where g failed. A
processor could ask this and none here does; the analysis is the same dataflow
C.3 declines for the optional (ADR-0178).

**C.11 An owned pointer's storage is not given back on a non-local `goto` or a
`halt`** (6.4.14.3). What *is* released is every file and handle inside the
variable the pointer owns: those are registered with the runtime individually
when the variable is created, and the runtime's unwind walks them. What is not
released is the block itself, so what a `goto` out of the activation abandons is
memory and not a resource — and on `halt` the process is ending in any case.
The requirement stands as 6.4.14.3 writes it; closing it means a runtime
registry and a per-block release runner, which is 6.9.3.11's shape, and
ADR-0181 declined that against what it buys. `doc/sop.md` §7 carries it.

## Annex D (informative) — The library

`lib/` is written in ISO/IEC 10206:1991 and may be used by any conforming
program. `lib/dialect/` is written in the language this document specifies, and
by 6.13.1 may be used only by a program in that language.

Neither is part of this specification. They are listed because 6.13.1's
consequence — that the two layers cannot import one another and therefore
duplicate — is a cost of a requirement stated here, and a reader is entitled to
see where it is paid.

## Annex E (informative) — Divergences found while writing this document

By 5.5 c) this document is the current statement and an ADR is the historical
one. Each entry below is a place where writing this from the records and then
probing found the two disagreeing.

**E.1 `hypot`, `atan2` and `atan` are no longer reserved foreign names.**
ADR-0121's consequences state that a program cannot name them, because the
emitted module declared them for `complex`. The processor has since taken
`pas_`-prefixed names for those uses and the bare spellings are free; a program
binding `hypot` compiles and runs. `README.md` records the current position
correctly. `doc/roadmap.md` stated the retired one in the present tense and is
corrected in the change that adds this document. 6.7.7.10 NOTE 2 states the
rule as it now is.

**E.2 An optional may not contain an optional.** ADR-0123 does not state this;
the processor refuses it, with a message of its own. Recorded here as 6.4.11.2,
which is a requirement the ADR would have had to state and did not.

**E.3 `int64` crosses the foreign boundary in all three positions.** ADR-0121
admitted `integer` and `real`; ADR-0128 added `int64` as a value parameter, a
variable parameter and a result. 6.7.7.3, 6.7.7.6 and 6.7.7.8 state the union,
which no single record does.

**E.4 A slice's component list is not the foreign type list.** It is that list
plus `char` (6.7.7.7), for the reason ADR-0129 gives. Stated here because a
reader assembling the rule from ADR-0121 alone would get it wrong in both
directions.

**E.5 A wide literal where a constant is required stopped the processor.**
**Found here, fixed by ADR-0136.** Writing an unsigned-integer greater than
`maxint` in a constant-definition, a subrange bound, an array's index-type, a
set's base-type, a case-constant, or an operand of a constant-expression
terminated the processor with

    runtime error: case: no label matches the selector

which was a case-statement in the processor's own source having no arm for the
wide literal (§6.9.3.5's error, which ADR-0018 makes stop the program).

It was dialect-only — both conformance modes reject such a literal in the
lexis — and it did not arise in an expression context, where
`writeln(5000000000)` and an assignment to a variable of `int64` were always
correct.

**Why no oracle here could see it** is worth keeping: `tests/dialect/int64_types.pas`
writes the *type name* and `maxint64` in every one of those positions, and both
of those fold — `maxint64` is a constant-identifier whose folded type is
`int64`, so each position reported its own ordinal message. A **literal** above
`maxint` is a different node, and no case in the corpus had ever written one
where a constant was required. Every gate was green, and the defect was found
by probing a requirement of this document (5.5 a) rather than by any of them.

ADR-0136 settled the language question the defect exposed — whether such a
constant is refused or admitted — in favour of refusing it, and 6.4.2.6.5 now
states it. `tests/dialect/int64_const.pas` is the case.

**E.6 A string-type is sliced as a substring, and the first draft of 6.5.6
said otherwise.** ADR-0125's rule is "an array whose index-type is an integer
type", and a `packed array [1..n] of char` is one — so as first written this
document made `s[1..3]` a slice for exactly the variables ISO/IEC 10206:1991
gives a substring. The processor does not do that: it asks whether the variable
has a string-type first, and only then whether it is a sliceable array. The
processor is right and the document was wrong, because the slice reading would
take a substring away from every conforming program that writes one, which is
what 6.0.1's containment forbids. 6.5.6 now states the exclusion and NOTE 3
gives the reason.

Found by ADR-0138's containment sweep — not directly, since a conforming
program cannot spell a slice, but by following the one case in 228 that the
sweep reports as divergent.

**E.7 Two slices are compatible and were comparable.** 6.4.5's compatibility is
for parameter passing; the relational operators ask compatibility, so
`a[1..2] = a[3..4]` was accepted and lowered to invalid IR. **Found here,
fixed by ADR-0139**, and 6.8.3.5 now states the restriction. Unlike E.5 this
was not a divergence between a record and the processor — no record said
anything about it either way, which is the failure mode a specification exists
to close: a rule nobody wrote down is a rule nobody can check.

**E.8 A slice was assignable, and 6.4.9 could name its type.** Two defects with
one root: 6.4.5's compatibility is asked by more callers than the clause was
written for. `p := r` between two slice formals copied descriptor-sized bytes
between the arrays' contents and wrote outside the shorter one, exit 0; and
6.7.3.9.2's NOTE argued that a slice type has no name while
ISO/IEC 10206:1991 §6.4.9's `type of` supplies one, which made every position
that clause forbids reachable. **Found by two independent readers of a
specification audit, fixed by ADR-0143**, and 6.4.6 and 6.7.3.9.2 now state
both.

Unlike E.5 and E.7 this is a divergence between the document's *reasoning* and
the processor rather than between its requirements and the processor: the
requirement in 6.7.3.9.2 was right and unenforced, and its NOTE explained why
enforcement was unnecessary. A NOTE is informative and cannot be wrong about
what is required; it can be wrong about why, and this one was.

**E.9 Nine citation and wording defects, found by an audit of this document
against the standards it amends.** None changed what the processor does; each
would have misled a reader holding the standard, which is the one thing this
document exists to prevent. All are corrected in place and listed here because
5.5 c) makes this document the current statement and the record the historical
one.

| Clause | Was | Is |
| --- | --- | --- |
| 6.1.2 NOTE 1 | `?` admitted "in no position" | in none **outside a character-string (§6.1.9) or a commentary (§6.1.10)** |
| 6.1.2 NOTE 3, 6.2.2 | §6.1.3 makes a required identifier shadowable | §6.1.3 makes it **not reserved**; §6.2.2.5 makes it **shadowable** |
| 6.1.2 NOTE 4 | the empty statement is §6.8.1; four following tokens | §6.9.2.1; **five**, `otherwise` being the fifth |
| 6.1.4 | `external` is a remote-directive | a **directive**; an external-directive is two tokens and §6.1.4's production admits one, so 6.7.7.1 adds an alternative to procedure-declaration |
| 6.2.2 NOTE 2 | *(absent)* | §3.3's definition of **extension**, whose one exception is a spelling of an identifier — the citation the caution wanted |
| 6.4.2.6.1 | `int64` holds every value representable in 64 bits | `-maxint64 .. maxint64`, one short, as `integer` is of `maxint` |
| 6.4.11.7 | §6.4.1 makes two `?integer` distinct | §6.4.1's rule is stated of a **new-type**, so the clause now says an optional-type is one |
| 6.7.7.8 | an optional of "a string-type having a capacity" | a **variable-string-type**; §6.4.3.3.2 gives a fixed-string-type a capacity too, so the phrase excluded nothing |
| 6.11 | a module is translated under the same language as every component | under a language **6.13.1 permits**, 6.13.1 granting an exception 6.11 must not withdraw |

The last is the one with a consequence beyond a reader. 6.11 as written forbade
exactly the case ADR-0137 exists for and `lib/` depends on, so the processor
violated its letter while obeying 6.13.1 — and the clause was classified
`structural`, which makes a requirement unfalsifiable by construction, since no
scenario may cite one. It and 6.4.3.4 are re-triaged `testable`; 6.4.3.4 now has
the two scenarios its opening sentence always deserved.

**E.10 6.9.3.11.3 forbade three things and was cited as forbidding four.**
6.7.5.9's NOTE 3 said "6.9.3.11.3 forbids an exit-statement in a deferred
statement"; 6.9.3.11.3 listed a goto-statement, a label and a defer-statement,
and said nothing about an exit-statement. The processor refused one, so what
diverged was the document from itself: a reader implementing only the numbered
requirements would have been right to allow it, and a reader following the
NOTE would have found no requirement behind the citation.

Found while writing 6.8.9, which had to say the same thing about a
try-expression and had nowhere to say it. 6.9.3.11.3 now lists all five, and
the two later clauses cite it rather than the other way about — which is the
shape a restriction a later clause adds should always have had.

This is the first divergence here between two clauses of *this* document
rather than between it and a standard, and the mechanism that let it through
is worth naming: a NOTE may cite, and nothing checks that what it cites says
what it claims. `clause-citations` asks only whether a number names a clause
at all, and 6.9.3.11.3 exists.

**E.11 6.4.15.5 refused an assignment a Pascal type has no business
refusing.** As first written, a text-type was assignment-compatible from a
character-string and from a constant `char` and from nothing else: a
string-type was refused, on the argument that the conversion may fail and that
"invalid input from the outside world is not an error in the program", so it
belonged in a function answering a fallible-type.

The argument is sound and the conclusion did not follow. §6.4.6 admits
assignments that can fail all the time — every store into a subrange is one,
and ISO 7185 has made an out-of-range store an error since 1982 (ADR-0018). A
text's invariant is a constraint on the value of exactly that kind, so the
assignment is admitted and the failure is an error. What the fallible
conversion is *for* is a program that expects invalid input and must not stop;
that is a different requirement and 6.4.13 still serves it.

**Found by implementing the clause** (ADR-0191), and it is the first divergence
here found that way rather than by an audit or by a probe. What made it visible
was writing the increment's own tests: under the clause as written, a text
could be filled from a literal and from another text and from nothing else, so
every test was a test about literals. A type whose only source is a literal is
a type nobody would reach for, and the document had said so without noticing.

**E.12 6.4.15.5 also over-specified *when* the conversion happens.** It
required the bytes to be "converted to Normalization Form C by the processor
**before the program is executed**". That is not implementable here and the
reason is a fact about this compiler rather than about the language:
`selfhost/compiler.pas` is an Extended Pascal source (ADR-0082), `external` is
refused there, and so the compiler cannot reach the Unicode tables at all
(ADR-0190). The conversion is emitted and happens where the assignment does.

The clause now says "where the assignment occurs" and says nothing about
translation time, which is the honest form: *when* a required conversion
happens is not a property a program can observe, and stating it bought
nothing but a requirement no processor here could meet.

## Annex F (informative) — Where each requirement was decided

| Clause | Record |
| --- | --- |
| 6.0.1, 6.0.2, 5.3 | ADR-0117 |
| 6.4.3.4 | ADR-0118 |
| 6.13.1, 6.11 | ADR-0119 |
| Annex D | ADR-0120 |
| 6.1.4, 6.7.7.1 – 6.7.7.4, 6.7.7.10 | ADR-0121 |
| 6.7.7.5, 6.7.7.6, 6.7.7.9 | ADR-0122 |
| 6.4.11 | ADR-0123 |
| 6.4.5, 6.5.6, 6.7.3.9, 6.7.6 | ADR-0125 |
| 6.2.2, 6.4.2.6 | ADR-0128 |
| 6.7.7.7 | ADR-0129 |
| 6.7.7.10 NOTE 3 | ADR-0131 |
| 6.7.7.8, 6.7.7.9 c) | ADR-0132 |
| 4, 5.5, Annex E | ADR-0135 |
| 6.5.6 NOTE 3, Annex E.6 | ADR-0138 |
| 6.8.3.5, Annex E.7 | ADR-0139 |
| 6.13.1 (the walk) | ADR-0142 |
| 6.4.6, 6.7.3.9.2, Annex E.8 | ADR-0143 |
| 6.7.5.3, 6.10.2, Annex E.9 | ADR-0144 |
| 6.7.6.10, Annex A.6 | ADR-0173 |
| 6.4.12, 6.7.7.3, 6.7.7.8, Annex A.7, Annex C.7 | ADR-0174 |
| 6.9.3.11, Annex C.8 | ADR-0175 |
| 6.4.13 | ADR-0176 |
| 6.7.5.9, Annex C.9 | ADR-0177 |
| 6.8.9, 6.9.3.11.3, Annex C.10 | ADR-0178 |
| 6.4.12.2 NOTE 1 | ADR-0180 |
| 6.4.14, Annex B `owned`, Annex C.11 | ADR-0181 |
| 6.4.14.6, Annex B `take` | ADR-0182 |
| 6.7.7.6.1 – 6.7.7.6.3 | ADR-0184 |
| 6.7.7.8 (the record component) | ADR-0187 |
| 5.6, 6.4.15 | ADR-0189 |
| 6.4.15.5, 6.4.15.6, 6.4.15.8, 6.4.15.10, Annex B `utf8`, Annex E.11, Annex E.12 | ADR-0191 |
| 6.4.15.7, 6.4.15.9 (the iteration) | ADR-0192 |
| 6.5.1 | ADR-0299 |
| 6.4.17, 6.9.3.12 (the second form), 6.9.3.14 | ADR-0312 |
| 6.9.3.15, 6.9.3.13 NOTE 4, Annex A.8, Annex A.9 | ADR-0313 |
