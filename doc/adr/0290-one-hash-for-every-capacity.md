# 290. One hash for every capacity

Date: 2026-09-02

## Status

Accepted, 2026-09-02. *The client conversion this record defers under
Consequences was made the same day; `lsp/pasls.pas`'s document store is
`PasContainer`'s map, and `doc/roadmap.md`'s entry carries what it cost.*

## Context

`doc/roadmap.md`'s "The program that would judge the language" exists to find
what writing a large client demanded of the dialect, and it carried this as an
open finding: *"`PasContainer`'s map cannot key on a URI. `MapKey` is 63
characters and `file:///…/apfront.pas` is 69, so the document store is a vector
searched linearly."*

**The finding named the wrong thing.** `PasContainer`'s map has been
`Map(K: type; V: type; cap: integer)` since ADR-0254 and is generic over its
key; a probe keys one on a 200-character string and stores a 69-character URI
in it. What is not generic is the **ready-made hash**. `StrHash` and `StrEq`
were declared over `MapKey = string(63)`, `MapPut` requires
`function hash(k: type of m^.slots[1].key): integer`, and
ISO/IEC 10206:1991 §6.7.3.6 makes a procedural parameter's congruity exact — so
a map keyed on anything but `string(63)` got the pair refused, and its client
wrote its own.

`lsp/pasls.pas` read that refusal as the *map's* bound and kept its documents
in a linearly searched vector, with a comment saying why. So the cost of the
gap is measured rather than supposed: one client, one workaround, and a
roadmap entry that has been wrong since ADR-0254 made the map generic.

§6.7.3.6 a) 4) offers three ways two value-parameter-sections match, and every
one of them names **both** headings: both parameter-forms a schema-name, or
both a type-name of the same type, or both a type-name produced from the same
schema. A schema-name against a type produced from it is in none of them.

## Decision

Extend congruity: **a schematic `string` value formal in the heading of the
routine being passed matches a value formal whose parameter-form denotes a
type produced from that schema.** AP 6.7.3.6.

`lib/dialect/pascontainer.pas`'s `StrHash` and `StrEq` become schematic, so the
ready-made pair serves a map keyed at any capacity and no client writes one
again.

**It needs no spelling**, which makes it the third feature here to need none —
after ADR-0184's record at an `external` heading and ADR-0240's `writable`. It
is a rule about what is admitted at a position the language already has, so
ADR-0140's test does not apply to it and there is no second place for the truth
to live.

### Three restrictions, each measured rather than preferred

**The string schema, and no other.** A string is the one schema whose values
carry what the schematic form needs: §6.4.3.3.3 makes a value a length and that
many characters, so a value parameter of `string(200)` and one of `string` are
both a pointer and a length (ADR-0051, ADR-0115) and the two headings call the
same way. The emitted signatures are identical — `(ptr %link, ptr %a0, i32 %a1)`
for each. Every other schema is not alike: `Box(5)` is `(ptr %link, ptr %a0)`
against `Box`'s `(ptr %link, ptr %a0, i32 %a1)`, because its tuple is a property
of the type and is passed only where the type does not state it. Admitting
those would be a call through the wrong signature.

**Value parameters, and not variable ones.** Measured the same way:
`var key: string(200)` is `(ptr %a0)` and `var key: string` is
`(ptr %a0, i32 %a1)`. The boundary coincides exactly with the one
`StringValueFormal` already draws for its own reason — §6.7.3.3's
variable-parameter clause has no paragraph taking a capacity from the value,
there being no value.

**One direction only.** The reverse hands a routine whose slot holds 63
characters to a caller bound by nothing, and the first longer actual is
§6.4.6's store error at run time.

### And congruity acquired an orientation

§6.7.3.6 c) and d) require two inner formal-parameter-lists to be congruous,
and the standard may compare them either way round because its relation is
symmetric. This one is not, so the orientation had to be decided and it
**reverses** one level in: a body holding the procedural parameter builds a
routine to the *specification's* inner heading and hands it to the actual,
which invokes it through its own — so the routine being passed, at that level,
is the specification's. `Congruous` swaps its arguments in the recursion. This
was invisible before the rule had a direction.

## Consequences

**A finding recorded and left is a finding wasted, and one recorded wrongly is
worse.** This entry sat in the roadmap through eleven increments naming a
limitation the library did not have, and a client was built around it. What
found the truth was not a test but a probe written to check the sentence — the
same method that corrected this chapter's `T ! E` entry, and the second time
in that chapter that the answer was *the language could do it and the
convenience layer could not*.

**What is not done, with its cost.** The general widening — any schema, not
just `string` — is declined and the measurement is why: it would require a
fixed-tuple schema value parameter to pass its discriminants like the
schematic form, which is an extra argument at every call of every schema
parameter in every program, to remove boilerplate from one. That is a lowering
change (`verify/lowering.py` would move with it) bought for an ergonomic gain,
and the ratio is wrong. `selfhost/badsema/congruity_edges.pas` refuses `Box`
with the rest of the boundary, so the decision is pinned rather than merely
recorded.

**The client is not converted here.** `lsp/pasls.pas` can now key its document
store on a URI with the ready-made pair, and that change belongs with the
roadmap correction rather than with the language rule — a handful of open
documents is what an editor has, so the map is not measurably faster than the
vector and the reason to make the change is that the comment explaining the
vector is now false.
