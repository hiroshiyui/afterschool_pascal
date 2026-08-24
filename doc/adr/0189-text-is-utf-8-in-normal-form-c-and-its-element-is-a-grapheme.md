# 189. Text is UTF-8 in normal form C, and its element is a grapheme

Date: 2026-08-25

## Status

Accepted. AP 6.4.15, and **specified ahead of the processor** — AP 5.6 and the
`not-implemented` rows in `tests/spec/clauses/triage.tsv` are what say so, and
what refuse a scenario claiming otherwise until the increments below land.

## Context

ADR-0109 named internationalisation as one of the four things a practical
Pascal needs and `doc/roadmap.md` has carried the entry unchanged since:
*"Unstarted. `char` is a byte and nothing consults the locale … the largest
thing on this page that no record has touched, and the one a 'practical Pascal'
would be judged on first."* Eleven records have been written past it.

What the processor does today, probed rather than recalled:

    var s: string(32);
    s := 'héllo 日本';
    length(s) = 13          { bytes; the reader sees nine characters }
    ord(s[2]) = 195         { the first byte of é }

That is not a defect and no record proposes changing it. `doc/roadmap.md`'s
known-limitation entry, `doc/implementation-defined.md` E.1 and README all say
the same thing in the same words — a `char` is one octet, UTF-8 passes through,
encoding is the program's business. The question this record answers is what a
program should hold *instead* when the encoding is not its business.

**One thing is forced before any preference is expressed: `char` cannot
widen.** ADR-0117 makes the dialect contain Extended Pascal — everything that
standard accepts, the dialect accepts and means the same thing — and ADR-0138
sweeps the whole of `tests/extended/` a second way to hold it. Widening `char`
would change `ord`, change what `packed array [1..n] of char` occupies, and,
decisively, stop `set of char` compiling at all, ADR-0028 capping a set's base
type at 256 values. So the roadmap's own sentence offered a choice that does not
exist: it is not "a wider character type **or** a text type distinct from
§6.4.3.3's strings". It is the second, and the first is unavailable.

Two more are near-forced once the type is new. It is stored as **UTF-8**,
because every boundary this repository already has is bytes — `text` files,
`external` parameters (ADR-0121), `PasFS`, `PasDir`, `PasStream` — and any
other internal encoding converts at all of them. And it is a **value with a
declared capacity**, not a heap object, because the reference-counted string
Swift actually implements needs the aliasing half of the memory model, which
ADR-0151 records as undecidable on the evidence in hand and ADR-0181 declined
to force.

What was genuinely open was the **unit**: what one element of a text is.

## Decision

**A text value is a bounded buffer of well-formed UTF-8 in Normalization Form
C, and its element sequence is extended grapheme clusters.** It is spelled
`utf8(n)`, where `n` is a capacity in **bytes**; the count of elements is a
different number from the capacity and is computed rather than stored.

Six things follow, and the first two are the ones that decide the rest.

**The element of a text is a text.** A grapheme cluster is a sequence of scalar
values of unbounded length — a base character and any number of combining marks
— so it is not an ordinal, has no `ord`, and cannot be a `char` or any widening
of one. Swift reached the same place and calls the result `Character`; here it
is a `utf8(k)` for whatever `k` the program declared. This is the structural
consequence of choosing the grapheme over the scalar and it propagates
everywhere: the control variable of an iteration is a text, a
one-element text is what a program compares against, and there is no simple
type anywhere in the model.

**Normalisation happens on construction, not on comparison, so `=` is byte
equality.** A value entering a text is validated and converted to NFC where it
enters; two texts are equal exactly when their bytes are equal; and because
both are NFC, byte equality *is* canonical equivalence — `'é'` and
`'e' + U+0301` are one value and compare equal, which is the property the
grapheme unit exists to give. The alternative, normalising at each comparison,
was rejected below and the reason is worth carrying: a type whose equal values
may have unequal bytes cannot be a key in `lib/pasmap.pas`, cannot be hashed
stably, and pays the table cost at every comparison instead of once.

**Choosing graphemes over scalars costs one table, not two.** This is the
answer to the obvious objection that the cheapest model needs no Unicode data
at all. It is true that scalar decoding is pure arithmetic — but a scalar model
whose `=` is bytewise calls two identical-looking strings unequal, and a scalar
model whose `=` is canonical needs the normalisation tables anyway. So the
normalisation data is owed by any model with a defensible equality, and what
the grapheme unit adds on top is the UAX #29 break property and nothing else.
The choice is therefore much cheaper than it looks, and the scalar model much
less cheap.

**The bytes and the text are two types with two jobs, and neither is a
conversion of convenience.** `string(n)` round-trips exactly and is what a
program holds when it is moving bytes it did not author — a filename from
`PasDir`, a payload, a file it will write back. `utf8(n)` is what a program
holds when it means the *characters*, and it is normalised, so it does not
round-trip. Conversion from a `string` **can fail** — the bytes may not be
well-formed — so it is a function answering a fallible type (AP 6.4.13) and not
an assignment-compatibility: §6.4.6's assignment has no way to report a failure
except a trap, and invalid input from the outside world is not an error in the
program. A *literal* converts implicitly, because the compiler validates and
normalises it at translation time and an ill-formed one is a violation rather
than an error.

**There is no integer index.** `t[i]` and `t[i..j]` are refused. No integer
index is meaningful at more than one of the three levels at once, and an O(1)
index over graphemes cannot exist over UTF-8 storage; offering one that is
silently O(n) and silently byte-based is the trap the type is being introduced
to remove. Swift's decision, for Swift's reason.

**Spelled as a required schema identifier, reserving nothing.** `utf8` is a
required identifier in a scope enclosing the program (§6.2.2.10), shadowable by
any program that declares its own (§6.1.3) — ADR-0140's second shape, the one
`int64`, `argcount`, `exit`, `try` and `take` use, and not the juxtaposition
shape of `array of`, `handle external` and `owned ^T`. It is a **schema**
(§6.4.7) rather than a plain type-name so that `utf8(n)` reads exactly as
`string(n)` does and so that a formal parameter may be schematic; its type
identity is therefore the schema intern table's (ADR-0039) and *not* the
new-type rule AP 6.4.11 – 6.4.14 each state. Two separately written `utf8(64)`
are one type, as two `string(64)` are.

### The external oracle

The tables are generated from the Unicode Character Database and committed with
a version lock and a refresh script, which is `seed/`'s shape (ADR-0085) and
for `seed/`'s reason: a build that fetches is a build that can fail offline and
a table that is regenerated per commit is churn nobody reads.

The part worth stating separately is that **this feature arrives with an oracle
nobody here wrote.** `GraphemeBreakTest.txt` and `NormalizationTest.txt` are
part of the UCD: thousands of cases between them, each an input and the answer,
published by a body with no interest in this compiler. That is ADR-0086's
argument for the BSI suite applied to the one area of this language where a
misreading is otherwise invisible — segmentation and normalisation are exactly
the kind of thing every oracle here would agree about, all of them being
downstream of one author's reading. It is the strongest reason to prefer this
model over one whose correctness is a matter of local opinion.

The Unicode version is implementation-defined and the processor states it; a
processor is not required to be at the current version, but is required to say
which it is.

## Consequences

**Nothing lands in this change but the decision.** AP 6.4.15 is written and its
clauses are triaged `not-implemented`, which makes `spec-clause-traceability`
refuse a scenario citing any of them until the feature exists. AP 5.6 is the
compliance hook that keeps 5.1 true while that is so, and it is written to be
reusable — this will not be the last requirement stated ahead of the processor.
No Annex B row is added: that annex is gated, each row requiring a pair of
`*_refused` cases whose goldens contain the message it states, and there is no
refusal to test until there is a construct to refuse.

**Four increments, in this order**, each landing on its own and each with
something that fails without it:

1. **The tables and the runtime primitives.** Generated C, its own file
   (`runtime/pasrt.c` is hand-styled and a generated table does not belong in
   it), and a gate running the two UCD conformance files. No language change,
   so it is testable in isolation and it is where the risk is.
2. **The type**: the denoter, assignment, comparison, `length`, `capacity`,
   and `write`. This is where `tests/dialect/inherits_extended.pas` gains its
   paragraph — a required identifier takes a spelling from every program that
   does not shadow one, so containment needs the witness ADR-0128 wrote for
   `int64`.
3. **Iteration and concatenation**: `for g in t`, and `+` with the
   re-normalisation AP 6.4.15.7 requires at the join.
4. **`PasUnicode`**, the library: the scalar view, the byte count, case
   mapping, case folding, and grapheme-indexed slicing. The library is where
   everything O(n) goes, which is most of it.

**The headroom is not a constraint.** `--dump-limits` reports the compiler at
556169 of 1000000 string-pool characters and 161659 of 300000 tokens, so
ADR-0126 and ADR-0148's ceiling — the one that has twice failed as a *build*
rather than as a diagnostic — has room for a feature this size without an
out-of-cycle reseed.

**It decides nothing about aliasing.** A text is a value with a declared
capacity, copied by assignment like a `string(n)`, so ADR-0151's criterion —
the first construct admitting two live names for one owned value — is not met
and the fork stays open. That is ADR-0174's and ADR-0181's move a third time,
and it is why this was available before the memory model.

**`char` and `string(n)` are untouched, in all three modes.** This record adds
a type; it withdraws nothing, and `doc/implementation-defined.md` E.1 goes on
saying what it says. A program that wants bytes goes on getting bytes.

## What this does not do

**No collation.** `<` compares by scalar value over NFC, which is a total,
stable, documented order and is not a linguistic one: it sorts `Z` before `a`
and says nothing about where `ä` belongs in Swedish. A collation needs CLDR
data, a locale and a tailoring mechanism, which is a larger project than this
one and has no client yet. Swift's `<` is likewise not a collation.

**No normal form but C.** NFD, NFKC and NFKD are not provided. NFC is what
interchange uses and what the invariant is stated in; the compatibility forms
lose information and want a client before they get tables.

**No display width.** A field width pads by grapheme count, which is not the
number of terminal columns a value occupies: a wide CJK character is two
columns and a combining mark is none. East Asian Width is another table and
another decision.

**No locale, anywhere.** Case mapping in increment 4 is the unconditional
Unicode mapping; the locale-sensitive rules — Turkish dotless *i* is the famous
one — are declined. Nothing in this language consults an environment variable
to decide what a program means, and this record does not start.

**No word, line or sentence segmentation, and no regular expressions.** UAX #29
has three more boundary kinds than the one used here and they are not provided.

**No `read` into a text.** Reading is bytes and the conversion can fail, so a
program reads a `string` and converts, which is where the failure has somewhere
to be reported. This is the same reasoning that makes conversion a fallible
function rather than an assignment.

**It does not make a `char` a character.** After all four increments a program
still has a byte type called `char`, and a one-character string literal is
still a `char` when it is one byte and a string when it is more. That is
Extended Pascal's rule and containment keeps it.

## Alternatives rejected

**A wider `char`.** The roadmap offered it and it is not available: `set of
char` stops compiling under ADR-0028's 256-value cap, which breaks ADR-0117's
containment outright. Recorded as rejected rather than omitted because the
roadmap sentence proposing it stood for eleven records and a reader will
otherwise wonder what became of it.

**UTF-32 storage — a packed array of scalars.** `t[i]` becomes O(1) and reads
like every other Pascal array, with no opaque index and no library needed to
walk it, which is the most *Pascal-looking* of the options. Rejected because it
converts at every boundary this repository already has, costs four bytes per
ASCII character, and still does not deliver a grapheme — `é` spelled with a
combining mark is two elements however wide they are. That last point is the
one that settles it: a fixed-width element buys O(1) indexing of the wrong
thing. Swift 5's move to UTF-8 storage was off a different fixed-width
representation, UTF-16, for the boundary-conversion reason rather than this
one.

**The scalar as the unit.** Cheaper by one table and the argument above is why
that is a smaller saving than it appears: any equality worth having needs the
normalisation data, and the break property is the only thing the grapheme adds.
It also produces a model that is incoherent at the seam a user sees first —
`Count` agreeing on two spellings of `é` while `=` denies they are the same.

**Bytes with a validity invariant only** — `string(n)` plus a promise that its
contents are well-formed. It is the smallest possible move and buys the
invariant and nothing else: indexing stays byte-wise, `length` stays bytes,
`=` stays byte equality over unnormalised input. Not a text model.

**Normalising at comparison rather than at construction.** Preserves the input
bytes, so a text round-trips. Rejected because it makes `=` cost a table walk,
makes two equal values have unequal bytes — which disqualifies a text as a
`pasmap` key and as anything hashed — and does not actually preserve the bytes
that matter, since `+` must renormalise at the join in either design. The
round-tripping job belongs to `string(n)`, which does it perfectly.

**A library over `string(n)`, with no language change.** This was the shape
ADR-0114 argued for and the one this repository has reached for repeatedly —
and it is where increment 4 still goes. It cannot carry the model, for two
reasons: a library cannot enforce an invariant on a type it did not introduce,
nothing preventing a caller from assigning raw bytes into the `string` it hands
back; and equality must be the language's `=` or every program that compares
two texts with the operator it already knows gets the wrong answer silently.

**A heap text with reference counting**, which is what Swift's `String`
actually is. It would remove the capacity from the type and the "does it fit"
error with it. Rejected because a shared mutable buffer is precisely the
construct ADR-0151 says forces the aliasing decision, and taking that decision
to get a string type would be deciding the memory model as a side effect of
deciding the text model.
