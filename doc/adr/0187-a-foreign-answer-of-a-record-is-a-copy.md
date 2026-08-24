# 187. A foreign answer of a record is a copy

Date: 2026-08-25

## Status

Accepted. AP 6.7.7.8.

## Context

`doc/roadmap.md`'s "What blocks the library" list had one row left after
ADR-0184 admitted a record as a `var` parameter of an `external` heading: a
foreign routine that **answers** a struct. `readdir`, `gmtime`, `localtime`,
`getaddrinfo` — each of them hands back the address of storage it owns and
reuses between calls, and each of them hands back a null that is an ordinary
outcome and not a failure.

ADR-0122 refused every result that is an address, for a reason that was right
at the time: a returned `char *` may be null, `getenv` of a name that is not
set answers one in the ordinary course of things, and this language had nothing
to say "no value" in. ADR-0123 built that something — the optional-type — and
lifted the refusal *exactly* as far as a string with a capacity, because the
copy the call site makes needs somewhere of a known size to go.

The size was the whole of the condition, and after ADR-0184 a record has one.
`LlSize` answers for it, `RecordLayout` computes the offsets C computes, and
`foreign-layout` (ADR-0185) is how a program has that claim checked against the
real header. So the question this record settles is not *whether* a struct can
come back — that was answered by two earlier increments between them — but what
comes back **as**, and the answer had to be settled before any of `lib/` could
grow a directory listing.

## Decision

**The result type of an `external` declaration may be an optional of a record
that 6.7.7.6.2 admits, and what the program receives is a copy.**

A null address yields the absent value. Any other address yields a copy, made
where the call occurs, into the frame slot Sema already gives every call whose
result lives in memory. The copy is as long as the record occupies *here*.

Three things follow from that one sentence, and each was a decision:

**The conditions on the record are 6.7.7.6.2's, unchanged.** No variant part,
and every field `char`, `integer`, `int64`, `real`, a fixed array of one of
those, or a record of them. `BadForeignField` is called from a second site and
was not touched. The reason transfers exactly: what is copied is storage a C
compiler laid out, and a field whose representation this compiler invented is
not part of any such layout — a set is 256 bits, a string is a length beside a
buffer, a `boolean` has 254 byte patterns that are not values of it and nothing
runs `CheckedForSubrange` over what a routine this compiler did not translate
left behind.

**The copy is a copy, and that is the feature.** The callee's storage is the
callee's: `readdir` answers one static object per directory stream and
overwrites it on the next call. A view onto it would be a value of this
language whose contents change when the program does something unrelated, and
would hand ADR-0109's aliasing question to every program that lists a
directory. So the address is read once, at the call, and is dead by the end of
the statement — which is the same sentence ADR-0123 wrote about a `char *`, and
is why widening 6.7.7.8 leaves 6.7.7.9 c) exactly where it was. Nothing here
keeps an address.

**The length is the record's and not the struct's.** There is nothing the far
side could report, so the copy reads what the program declared. A record
declaring a *prefix* of the struct's members reads the prefix, which is how
`struct tm` is usable without naming the `char *` member glibc puts after the
nine that matter. A record larger than the struct reads storage the callee does
not own, and that is a requirement on the program in the same way and for the
same reason 6.7.7.9 c) is one.

The lowering is `pas_rec_take(dst, size, src)`, the mirror of ADR-0123's
`pas_cstr_take`: a guarded `memcpy` that answers whether there was a value. It
holds the same non-opinion — it is told where the value part of the optional is
and how many bytes go there, and the **flag is stored by CodeGen**, because the
layout of an optional is CodeGen's and no routine in the runtime may have a
second idea about it.

A record result *by value* stays refused, and gains a diagnostic of its own
saying so and naming the remedy. It was reaching the general "only `integer`,
`int64` and `real` cross the boundary", which is true and unhelpful: what the
program got wrong is the direction, not the type. How a struct is returned by
value is a fact about C's ABI — a register pair here, hidden caller storage
there — and ADR-0030 is the standing rule that nothing in this compiler may
depend on one.

## Consequences

`gmtime` and `localtime` are declarable, and `tests/dialect/foreign_optional_record.pas`
declares the first. `readdir` is declarable too, with the one wrinkle that
`d_reclen` is an `unsigned short` and this language has no 2-byte scalar: it is
spelled `array [1..2] of char`, which lands at the same offset and occupies the
same space, and the annotation of ADR-0185 will still check it.

The case has two halves for the reason `foreign_record.pas` does. The probe
half is `pasx_record_answer`, which answers one static object that every call
overwrites and fills every field from its argument, so calling it twice and
reading the *first* value back is what says the copy is a copy — an aliasing
view answers 2000 where a copy answers 1000. The real half is `gmtime`, which
is ISO C rather than POSIX, deterministic for a fixed `time_t`, and a prefix of
its own struct, so it exercises the paragraph above about length.

**Three diagnostics, and one of them is the discoverable one.** The result
position now reports a variant part and a bad field in its own words, and the
by-value record result names `?` as the remedy. That last is what turns a
refusal into a signpost: the chain a program follows is `function f: R` →
"write `?` before the record" → `function f: ?R` → and if `R` has a field that
cannot cross, the field is named.

**No `verify/` rule.** `lowering.py` models arithmetic, conversion and
comparison, and models neither ADR-0123's foreign optional nor this one; the
commit therefore carries `Model-unchanged:` rather than a model change, which
is the same answer ADR-0123 gave for the same reason.

**The mutations.** Four, killing two cases. Sema no longer reporting a variant
part in the result position → `foreign_record_errors` (and the fallback names
the *tag* as a field to change, which is the wrong advice, so the golden shows
the defect and not merely a difference). CodeGen copying a fixed 8 bytes
instead of `LlSize` → `foreign_optional_record`. The runtime answering 1 for a
null → `foreign_optional_record`, on `absent`. Sema not reporting the by-value
record result → `foreign_record_errors`.

## What this does not do

**It does not admit a struct by value, in either direction.** ADR-0030 stands
and this is the third increment to leave it standing.

**It does not check that the record is the struct.** That is ADR-0185's
question, and the answer there is a comment the program writes and a C compiler
judges. A result-position record is annotated the same way and checked by the
same gate — `foreign-layout` reads a type declaration and does not care where
the type is used. What the gate cannot check is a **prefix**, deliberately: it
compares a field-list against the whole struct, and a partial claim is one a C
compiler has no way to confirm. `tests/dialect/foreign_optional_record.pas`'s
`Tm` therefore carries no annotation, and what checks it is the calendar.

**It does not give the program the address.** There is no way to ask for one,
and 6.7.7.9 c) still says a result that is an address of callee-owned storage
is a requirement on the program that this processor cannot enforce — an `int64`
result carries an address on every target here and no processor can tell a
count from one.

**It does not touch ADR-0109's aliasing half.** That was the point of choosing
a copy. A view would have needed a lifetime, a lifetime would have needed the
model ADR-0151 defers, and the feature would have waited for it.

**It does not widen what a record field may be.** A `char *` member still has
no spelling, so `struct passwd` and `struct addrinfo` are still not fully
declarable. What is declarable is the prefix, and for `getaddrinfo` that is not
the useful part — a chained list of structs holding pointers is the shape
ADR-0109 exists for, and this clause does not reach it.

## Alternatives rejected

**A view onto the callee's storage, with a lifetime.** The honest version of
this needs the aliasing half of ADR-0151's memory-safety model, which is
undesigned. The dishonest version — a pointer the program may hold — is what
ADR-0122 refused and what 6.7.7.9 c) still names as the boundary of this
document.

**A branch at the call site instead of a runtime routine.** The emitter is
sequential and can write a branch, and `EmitTrapIf` does. But the shape wanted
here is exactly `pas_cstr_take`'s — answer whether there was a value, let
CodeGen store the flag — and writing it twice in two different forms would be
two ideas about one thing. One line of IR against six, and the runtime routine
is four lines of C that a reader can check by eye.

**Letting the far side report the length.** There is nothing to ask. C has no
runtime record of a struct's size at an address, and inventing a protocol for
one would make every declarable routine a routine written for this language.

**Requiring the record to be annotated.** `@cstruct` could have been made
mandatory in this position, on the argument that an unchecked layout claim in
the result direction is worse than in the parameter direction. It is not worse
— both copy the same bytes — and requiring it would have made the prefix
unwritable, since the gate has no way to check a partial claim. The annotation
stays what ADR-0185 made it: available, and a program's own decision.
