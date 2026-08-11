# 51. A string value is a pointer and a length

Date: 2026-08-11

## Status

Accepted. It retires ISO 7185's equal-length requirement on string comparison,
which ADR-0042's follow-up fix had just finished making precise.

## Context

ISO/IEC 10206:1991 §6.4.3.3.1: "A string-type shall be a fixed-string-type or a
variable-string-type or the required type designated canonical-string-type."

§6.4.3.3.3: "There shall be a schema that is denoted by the required
schema-identifier `string`. The schema `string` shall have one formal
discriminant denoted by the required discriminant-identifier `capacity`, which
shall possess the integer-type." Each value of one "shall be a string-type
value with a length less than or equal to the capacity".

ADR-0012 chose a length-plus-buffer record over a string type, on evidence
gathered by measuring this compiler's own source. ADR-0045 then made exactly
that shape expressible from a schema and said the type was "its own feature".
This is that feature.

## Decision

**A string *value* is a pointer and a length — two scalars that travel
separately.** That is the third time this project has reached for the same
shape: ADR-0030's procedural pair, ADR-0049's complex, and now this, each for
the same reason — nothing may depend on how a two-word value is passed, because
one backend builds an `llvm::Module` and the other prints text.

Everything else follows from it.

**`substr` and `trim` copy nothing.** They are a pointer into the string they
came from and a shorter length. §6.7.6.7 defines them as values, and under this
representation a value costs nothing to make.

**Only `+` makes characters that did not exist**, and it takes them from a ring
in the runtime. A string value's life is one expression evaluation, so a ring is
the right shape: the space is reused as soon as the statement that made the
value is done with it. What it cannot survive is a single *statement* that
concatenates more than the ring holds, and that is stated as an implementation
limit rather than being silently wrong.

**A variable-string is stored as its length in front of its characters** — the
`{ i32, [cap x i8] }` that ADR-0045's flexible-array-member record already
described. So a `string(n)` whose capacity arrives with an actual needs nothing
new from `dynSize`, and `procedure p(var s: string)` is ADR-0040's descriptor
with the capacity as its one discriminant.

**The required schema has no body**, and that is what makes it required rather
than a definition: `produceFromSchema` builds a `TypeKind::String` from the
tuple instead of resolving a denoter. §6.4.8's intern table then gives
`string(6)` written twice one type, exactly as it does for every other schema.

**The canonical-string-type is that kind with a negative capacity.** It has no
storage, so it has no capacity to exceed — which is precisely why §6.4.6 checks
a value's *length* against the destination's capacity and not the other way
round. No type-denoter produces one, so no variable has it.

**A literal is its own characters and its own length, before anything else.**
That is one line in `emitString` and it has to come first: `''` is the
null-string §6.1.9 allows and §6.4.3.3.1 names, it has the canonical type, and
reading a length in front of characters that are not there is what happens
without it. Both compilers had that bug for the length of one test run.

**§6.4.6's assignment is three rules and one error.** A short value is padded
with spaces into a fixed string, kept at its own length in a variable one, and
becomes one character in a char; a value longer than the capacity is an
**error**, checked where the value is. So a string assignment is a runtime
operation and not a memcpy, which is why `isStructured()` deliberately excludes
a variable-string — the same exclusion, for the same reason, that a file has.

**Two comparisons, and they must not be unified.** §6.8.3.5's operators pad the
shorter operand with spaces; §6.7.6.7's `EQ`/`LT` family compares lengths as
well as characters. The standard's own NOTE 3 says "LT(a,b) could be false and
a<b true", and `tests/extended/string.pas` prints both answers side by side.

## Consequences

**ISO 7185's equal-length rule is retired**, and with it the trap ADR-0042's
follow-up fix (`9b72539`) had added. Under §6.8.3.5 two strings of different
lengths compare rather than failing, so `trap_schema_string.pas` no longer
describes the language and is now `schema_string_compare.pas`, which shows the
padding instead. What that trap protected has not gone away — the defect was a
*length* computed from placeholder bounds, and a padded comparison needs both
lengths to be right just as much as an equal-length one did. The evidence moved
from a program that stops to a program that answers.

**Nothing about the feature is lexical.** `string`, `length`, `substr`, `trim`,
`eq` and the rest are required *identifiers*, so a program may declare its own —
`tests/string_redeclared.pas` is one that does. The single exception is `''`:
§6.1.9 spells a character-string with *zero or more* elements where ISO 7185
requires one before the repetition, so the two languages differ over two
apostrophes and nothing else.

**`write`, `read` and indexing needed one clause each.** §6.10.3.1 has ISO
7185's list with "a string-type" in place of the packed char array; §6.10.1 a)
does the same for `read`; §6.4.3.3.3 NOTE 1 indexes a variable-string as an
array, with the bound being the **length** and not the capacity, because the
index-domain belongs to the value.

**`verify/` gained nothing**, for the fifth record running. There is no
arithmetic here to prove: the comparison is a loop over characters and the
capacity check is one inequality, both stated in the runtime in the same words
the standard uses.

**Thirty-one mutations across both compilers and the runtime, all caught but
one.** Six escaped first and were given tests: an out-of-range `substr`, a
string index past the *length* (which is inside the capacity, and so a case an
array test cannot stand in for), and a bare `string` denoter under ISO 7185 —
the last being the only thing that distinguishes a compiler which installed the
required schema anyway, since the discriminated form is refused by the parser
before any question about the name arises.

The one that still escapes is instructive rather than benign: removing the
literal branch from the C++ `emitString` changes nothing observable, because
only `''` reaches the branch that would differ and reading four bytes at a
one-byte global picks up the linker's zero padding — the right answer, by
accident. The *Pascal* backend catches the same mutation, and that is what says
the branch is load-bearing rather than defensive: the two backends agree on the
answer only because both compute it, not because either could get away without.

## What this does not do

**A substring-variable is not an lvalue.** §6.5.6 makes `s[i..j]` denote a
*variable* of a new fixed-string-type, so `s[2..4] := 'abc'` is legal Extended
Pascal and is refused here. Under this representation the read-only form is
free and the writable one needs an aliasing slice that assignment can reach —
a different mechanism, and the one §6.5.6's "it shall be an error to alter the
length of a string while a reference to a substring exists" is written for.
`substr` covers the reading half.

**`readstr` and `writestr` are absent** (§6.7.5.5). Both are defined as an
auxiliary text file — "equivalent to `rewrite(f); writeln(f, e); reset(f);
read(f, v)`" — so they need a text file over a string buffer, which is a
runtime facility rather than a compiler one.

**A function may not return a string.** §6.7.2 makes a result-type a type-name,
and this compiler restricts results to a simple type or a pointer; a
variable-string is neither. `substr` and `trim` return canonical values, which
is where the standard puts string-valued results anyway.

**§6.10.3.6's zero and truncating field widths are not honoured.** A string is
written by ISO 7185's `pas_write_str`, which pads but does not truncate and
writes the whole value at width 0. Zero field widths are a separate item on the
roadmap and would change ISO 7185's output as well, so they are not smuggled in
here.
