# Afterschool Pascal

**A specification of the dialect selected by `--std=afterschool`, written as an
amendment to ISO/IEC 10206:1991.**

| | |
| --- | --- |
| Status | Draft. Normative for this repository; see 5. |
| Applies to | `pascalc --std=afterschool`, version 1.5.0 |
| Amends | ISO/IEC 10206:1991 (Extended Pascal) |
| Governing records | ADR-0117 – ADR-0132, ADR-0135 |

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

ISO 7185 and ISO/IEC 10206:1991 are complete in this processor and are not
affected by anything in this document. They are the two modes with an external
specification (see 5.3). Nothing here changes what either **accepts**; 6.7.7.1
does change what `--std=extended` **says**, its refusal of the `external`
directive naming this dialect, which is a diagnostic and not an acceptance.

The dialect is the third mode. It **contains** Extended Pascal: every program
that conforms to ISO/IEC 10206:1991 is an Afterschool Pascal program with the
same meaning (6.0.1). Everything specified here is therefore an *addition*,
and this document is organised as a list of the clauses of ISO/IEC 10206:1991
that the dialect changes or extends.

---

## 1 Scope

This document specifies the programming language Afterschool Pascal, by
reference to ISO/IEC 10206:1991 and by stating the differences.

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
  languages this document and ISO/IEC 10206:1991 specify, not part of either
  (Annex D is informative);
- i) any representation, storage layout or calling convention, except where a
  requirement of 6.7.7 is stated in terms of one;
- j) anything about ISO 7185 or ISO/IEC 10206:1991 conformance, which is
  `doc/implementation-defined.md`'s subject.

## 2 Normative references

- **ISO/IEC 10206:1991**, *Information technology — Programming languages —
  Extended Pascal*. Incorporated in whole (6.0.1).
- **ISO 7185:1990**, *Programming languages — Pascal*. Referenced for context
  only; the dialect does not contain it (5.3, and ADR-0033 for why the two
  standards do not nest).
- **ISO/IEC 9899**, *Programming languages — C*, and **POSIX.1**. Referenced by
  6.7.7, which describes a boundary whose far side those documents specify.
  They are the only external authority this dialect has for any decision, and
  6.7.7.4 names the one place it was used.

## 3 Definitions

The definitions of ISO/IEC 10206:1991 clause 3 apply. In addition:

**3.1 dialect**: the language specified by this document.

**3.2 conformance mode**: `--std=iso7185` or `--std=extended`. Neither is
affected by this document.

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
paraphrased in this project's own words, which is `tests/spec/README.md`'s rule
and the same position `tests/bsi/README.md` takes. The copies under
`doc/vendor/` are not committed and their notice forbids inclusion in another
product.

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

Nothing in this document changes what `--std=iso7185` or `--std=extended`
accepts, or what either means by a program it accepts. Each feature specified
here is refused under both, with a diagnostic naming the dialect where the
construct is one the mode can recognise (Annex B). `tests/extended/` and
`tests/` are what hold that, and `tests/dialect/inherits_extended.pas` holds
6.0.1.

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
  `@afterschool:<clause>`, and 46 of this document's 48 testable clauses are
  cited by at least one scenario; the clause table those citations are checked
  against is **generated from these headings**, so a renamed clause fails the
  traceability gate rather than drifting. 6.13.1 is the one not cited — it needs
  two program-components and a link, and that harness compiles a single program.

  This rule was added after a) to c) and is numbered after them for that
  reason: ADR-0135 cites 5.5 a) by letter, and renumbering would have made an
  immutable record wrong.

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

The dialect shall be selected by `--std=afterschool`. A source is written in
one language and the option says which; there is no directive, comment or
in-source form that selects it.

### 6.1 Lexical tokens

#### 6.1.2 Special-symbols [extended]

The special-symbol `?` is added, and shall occur only as specified in 6.4.11.

**No word-symbol is added.** The word-symbols of Afterschool Pascal shall be
exactly those of ISO/IEC 10206:1991 §6.1.2, and this document shall add none.

NOTE 1 — `?` is a character neither standard admits in any position outside a
character-string (§6.1.9) or a commentary (§6.1.10) — not in an identifier, not
as an operator, and not among ISO/IEC 10206:1991 §6.1.11's lexical
alternatives. Taking it therefore costs the lexis nothing: no
program that compiled before compiles differently, and both conformance modes
report it as an unrecognised character exactly as they did (ADR-0123).

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

NOTE 5 — `tests/checks/reserved_words.py` enforces the second paragraph
directly, asking of every spelling the processor's lexer knows whether a
program may use it as a variable name, and requiring `--std=extended` and
`--std=afterschool` to give the same answer.

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
undetected. Both conformance modes leave this one undetected, conformingly.

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
6.4.3.4 applies, and the variant-part shall behave as it does under the
conformance modes.

NOTE — **This is a hole in the guarantee and is stated rather than hidden.**
There is no tag-field to make authoritative and nothing to check against, so
such a record is an unchecked union in the dialect exactly as in the standard.
Refusing it in the dialect would break 6.0.1; synthesising a hidden tag-field
would change the record's representation and wants its own record (ADR-0118).
It appears in Annex C.

**6.4.3.4.6 Assignment to the tag-field.** A program may assign to a tag-field
directly, and the value assigned shall determine the active variant from that
point. This is unchanged from ISO/IEC 10206:1991.

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

There shall be exactly one form of assignment to a variable of a handle-type:
an assignment-statement whose expression is a function-designator of an
external-declaration (6.7.7) whose result type is the same type. The variable
shall first release the value it holds, if any, and then hold the value the
function answered; a null answer leaves it empty. A function-designator whose
result type is a handle-type shall appear in no other position.

A handle-type shall not be a value of any other kind of assignment, of any
other relational operator, of a value parameter of a routine that is not an
external-declaration, or of a function result that is not an
external-declaration's; and a structured-type having a component of a
handle-type shall be subject to the same restrictions, exactly as
ISO/IEC 10206:1991 §6.4.6 a) and §6.8.3.5 treat a type having a file-type
component.

NOTE — Those are the file variable's restrictions, reached through the same
predicate: §6.4.6 a)'s "permissible as the component-type of a file-type"
excludes a handle as it excludes a file, for the same reason — there is no
copy, the storage and the value being one object.

**6.4.12.3 Release.** The value a variable of a handle-type holds shall be
released by calling the routine 6.4.12.1 names with it, at the first of:
termination of the activation in which the variable exists, including
termination by a `goto` (§6.9.2.4) or `halt` (§6.7.5.7); `dispose` of a
variable containing it; and the assignment 6.4.12.2 describes. A variable
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

### 6.5 Declarations and denotations of variables

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

Where it denotes a variable of a string-type, §6.5.6 is unchanged and `a[i..j]`
shall denote a substring.

Which construct is denoted shall be determined by the type of the variable
preceding `[`, and by nothing else.

NOTE 1 — The syntax is therefore unchanged; §6.5.6 already provides it. This is
"ask the symbol, not the syntax", which this repository has now reached for
seven times.

NOTE 2 — In a conformance mode `a[i..j]` remains available only for a string,
and the diagnostic is unchanged. The dialect's reading of the designator is
gated on the mode for that reason (ADR-0125).

NOTE 3 — The string-type exclusion is not a special case; it is what containment
requires. A `packed array [1..n] of char` is a string-type (§6.4.3.3.2) *and* an
array with an integer index-type, so without the first paragraph's exclusion
both readings would apply to it — and the slice reading would take `s[1..3]`
away from every ISO/IEC 10206:1991 program that writes one, which is exactly
what a dialect containing that standard may not do. The first draft of this
clause omitted the exclusion and said the opposite of what the processor does;
the processor was right. Recorded in Annex E.

### 6.7 Procedure and function declarations

#### 6.7.3 Parameters

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

**6.7.7.6 Variable parameters.** The type of a variable parameter of an
external-declaration shall be `integer`, `int64` or `real`, and what crosses
shall be the address of the actual. The rules of §6.7.3.3 apply to the actual
unchanged.

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
(6.4.11) whose component is a **variable-string-type** (ISO/IEC 10206:1991
§6.4.3.3.3).

NOTE — The first draft of this clause said "a string-type having a capacity",
which excludes nothing: §6.4.3.3.2 gives a fixed-string-type a capacity too —
"the capacity of a fixed-string-type shall be the largest value of its
index-type" — so the phrase used a defined term against its definition. What is
meant, and what the processor does, is the variable-string-type: `?string(10)`
is admitted and `?packed array [1..8] of char` is refused, because the length a
foreign routine's answer turns out to have is not known when the call is
written (ADR-0144).

Where the result type is an optional-type, a null address shall yield the absent
value, and any other address shall yield a copy, made where the call occurs, of
the NUL-terminated value it addresses. It shall be an error for that value to
exceed the capacity (Annex A.5, and it is §6.4.6's error rather than one added
here).

NOTE 1 — **No address obtained from a foreign routine becomes a value of this
language.** What the program holds is a string of its own, with its own
lifetime, and the address is dead by the end of the statement. That is why the
capacity is required: the copy needs somewhere of a known size to go.

NOTE 2 — A bare `string` result is refused, and the diagnostic names the remedy.
A `?integer` result is refused because C has no null integer for it to mean.

**6.7.7.9 What shall not cross.** An external-declaration shall not have:

- a) a parameter or result of any type not named in 6.7.7.3, 6.7.7.6, 6.7.7.7
  or 6.7.7.8;
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
shall contain no goto-statement, no label, and no defer-statement.

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

#### 6.13.1 Program-components shall agree where the language differs [added]

A program-component translated under `--std=afterschool` shall be linked only
with components that were translated under `--std=afterschool`, **or** whose
interfaces expose nothing this document requires a check against.

A module's interface **exposes nothing checked** when no type reachable from it
— through a field, an array component, a file component, a pointer domain or a
parameter — is a record-type having a variant-part with a tag-field (6.4.3.4).
Such a module may be translated under `--std=extended` and linked into an
Afterschool Pascal program.

The converse shall not hold: a module translated under `--std=afterschool`
shall not be linked into a program translated under a conformance mode, whatever
its interface exposes.

NOTE 1 — The requirement is enforced at the link, by the language forming part
of the name of a module's activation procedures — a name §6.13 already requires
the components to agree on. A module that exposes nothing checked emits those
names under both spellings. Nothing in a source can misstate any of it: the
names come from the translation that is happening, not from an option, a
sidecar or a claim (ADR-0119, ADR-0137).

NOTE 4 — The asymmetry in the third paragraph is deliberate. A module in this
dialect may declare `external` routines (6.7.7) and is therefore not a
conforming program-component; admitting one into a program that claims a
conformance mode would put a component outside both standards inside it. The
direction that was worth opening is the other one, where `lib/`'s modules are
ordinary Extended Pascal and the language that contains Extended Pascal could
not use them.

NOTE 2 — This is not tidiness. 6.4.3.4's two requirements are a pair, and
§6.13's separate translation would otherwise let them be split across
components: the surviving half would check a tag the other half never set, and
would answer *safe* for an unsafe access — worse than the documented hole it
replaced, which is how the requirement came to be written. It is also the whole
of what the first paragraph's exception is measured against: where no check can
be emitted, no pair can be split.

NOTE 3 — `lib/`'s six modules expose nothing checked and are usable from either
language. `lib/dialect/`'s are not usable from a conforming program, and the
third paragraph is what says so — for most of them the first paragraph would
say it too, their result records (Annex D) being variant-parts with a
tag-field, but `PasError` exports only an error code and a text type and would
otherwise be portable. The two directories remain two for the reason Annex D
gives; what has changed is that the duplication runs in one direction rather
than both.

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
| A.7 | an empty handle is lent to a foreign routine | 6.4.12.4 | `the handle is empty, and a foreign routine may not be lent it` |

Indexing a slice out of range (6.7.3.9.5 b) is reported by the array-index error
ISO 7185 and ISO/IEC 10206:1991 already have, against the slice's own bounds.

## Annex B (informative) — Refusal under the conformance modes

Each construct this document adds is refused under `--std=iso7185` and
`--std=extended`, and this annex records how, because it is a conformance
question even though the feature is not (5.3).

**The two modes do not always say the same thing**, which this annex claimed
they did until the rows were probed rather than read: ISO 7185 has no substring
notation at all, so its parser stops at the `..` where Extended Pascal parses
the construct and Sema refuses it. One column became two.

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

Only the first names the dialect. That is not an oversight: ADR-0140's rule is
that a dialect construct is spelled in a *position* where a conforming program
could not have written it, so seven of the eight are refused by machinery that
predates the dialect and has nothing to say about it. `external` is the
exception because §6.1.4 makes a directive an ordinary identifier in the one
position it may occupy, so nothing but a rule about the mode can refuse it
(ADR-0154).

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

**C.5 No second implementation compares any of this.** `src/` is frozen at the
conformance surface, so `selfhost/difftest.sh` skips a dialect source and counts
the skip. The oracles that do reach it are the goldens in `tests/dialect/`,
`selfhost/irtest.sh`, and `verify/` for any lowering with a rule (ADR-0117).

**C.6 No third-party corpus reaches it.** The BSI suite is ISO 7185 and fixed.

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
