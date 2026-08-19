# 128. An integer wider than the compiler's own

Date: 2026-08-19

## Status

Accepted. The other half of the data path ADR-0125 named.

## Context

ADR-0125 shipped the slice and closed with a probe rather than a prediction.
`clang` on this target:

    declare i64 @read(i32, ptr, i64)
    declare i64 @write(i32, ptr, i64)
    declare i64 @recv(i32, ptr, i64, i32)

Every length is a `size_t` and every one of them **answers** an `ssize_t`. A
slice could cross with an `i64` length — the compiler generates that word —
but the result could not be received, this language's `integer` being `i32`
with nothing wider. So the data path needs two things and ADR-0125 was one of
them.

It is also the first dialect feature whose *own* constraint is the compiler
rather than the standard. `selfhost/compiler.pas` is written in this language,
so its integers are 32 bits: there is no value of a 64-bit type anywhere in the
compiler to fold with, compare, or store in a constant.

## Decision

**`int64` is a numeric type and not an ordinal one, and a value of it is
carried as the text that was written.**

Both halves of that sentence are one answer to the constraint above.

**The text.** ADR-0025 decided that a real literal reaches the IR as its source
characters, because LLVM's assembler is the `strtod` and this compiler has no
floating-point type. The same sentence is true of a 64-bit integer one clause
later, so the same answer is taken: `tkInt64` carries the digits, `nkInt64`
carries them, `maxint64` is a required constant whose value is the nineteen
characters `9223372036854775807`, and `EmitInt64Text` writes them out. Nothing
is converted, so nothing can be converted wrongly. `Int64TooLarge` compares
*text* against the limit — leading zeros dropped, then length, then character
by character — for the reason ADR-0022 gave about the lexer's own overflow
check and one step further: neither side is a number this compiler could hold.

**Not an ordinal.** `IsOrdinal` answers no, and the thirteen refusals in
`tests/dialect/int64_types.pas` follow from that one line: no case label, no
array index, no subrange bound, no set base, no `for` control variable, no
`succ`, `pred`, `ord`, `odd`, `chr`, no `in`. Not one message was written for
this type. That is refusal by construction, which this repository has preferred
since ADR-0058 — and here it is also *forced*, because every one of those
constructs needs the compiler to hold the value.

**It answers where `real` answers.** `IsNumeric` gains it, so the arithmetic
operators, the relational operators, `abs`, `sqr` and the widenings pick it up
by the rules already written. `integer` widens to `int64` and `int64` widens to
`real`, in the same line §6.4.6 c) already writes for complex: the widening is
exact and the narrowing does not exist.

**`trunc` is the narrowing, and the only one.** §6.6.6.3's words are "the value
of x truncated to an integer", and an int64 above maxint has no integer to be
truncated to — which is that clause's own error condition. Making it implicit
would put an unwritten run-time check under an ordinary assignment; making it a
new required identifier would spend a name for a meaning a standard one already
has.

**One emitter, two widths.** `PutIntWidth` and `PutIntMin` take the width and
every checked emitter takes it from them, so the checked add, the div guard and
the mod adjustment exist once. Two copies of a checked multiply is two places
for a check to go missing from.

**`verify/` proves the wide lowering by running the rules it already had.** The
model was written generic in the width — `traps_add(l, r)` asks `l.size()` —
so `WIDE = (32, 64)` proves the emitted code at its real width rather than a
second family of rules restating the first. Five rules carry it. The narrowing
is genuinely new lowering and gets two rules of its own; the multiplication
rules stay `BOUNDED`, where the construction argument was already the one being
made.

## Consequences

**The type crosses the foreign boundary**, which is the point. `ForeignType`
gains it as a value parameter, a `var` parameter and a **function result**, and
the admission test is ADR-0121's: `clang` passes an `i64` with no parameter
attribute, as it does an `i32` and a `double`.

**Nothing about the two conformance modes moved.** `int64` is a required
type-identifier under `--std=afterschool` only, and a decimal literal above
maxint is the error it always was under the other two.
`tests/extended/int64_is_free.pas` declares a type, a variable and a function
of that name under `--std=extended`; §6.1.3 then makes the same declaration
legal under the dialect, which `inherits_extended.pas` writes.

**The lexis cost something, for the first time in four increments.** ADR-0121
found a directive, ADR-0123 a character no standard admits, ADR-0125 a
combination of two reserved words — three routes to a free spelling. There is
no free spelling for a *type*: `int64` is an identifier, and it is available
only because §6.2.2.10 makes a required identifier shadowable rather than
reserved. That is a weaker kind of free, and it is the reason the containment
test grew a paragraph.

**One statement of the compiler became unreachable.** `WriteTypeName`'s
`tyInt64` arm cannot be entered: `RequiredType` gives the singleton its alias,
and the alias is what a diagnostic prints. The arm must exist all the same —
`kind-exhaustive` is right that a missing one is a crash — so the line-coverage
ratchet moves by one, with this as the argument. Several arms of that same
case-statement were already in the 450 for the same reason.

### What this does not do

**A buffer still does not cross the boundary.** Both halves now exist —
ADR-0125's slice and this type — so it is unblocked rather than done, and the
shape is a decision of its own: a slice can cross as its address alone, with
the program passing the count, or as the pair `(ptr, i64)`, which is exactly
what `read`, `write`, `recv`, `send` and `memcpy` take in that order. The
second is more useful and assumes a convention; the first assumes nothing and
puts the count in the program's hands. That belongs in its own record.

**`read` does not take one.** §6.9.1's read of an integer takes the longest
prefix that *is* a number and gives back two characters (ADR-0076), and
extending that to a second width is runtime work this increment did not do.
`write` needed nothing: `pas_write_int` has taken an `i64` since it was
written, and the integer path was widening into it already. The asymmetry is in
`doc/implementation-defined.md`.

**No 64-bit arithmetic is folded.** `const c = 5000000000` names the digits and
nothing more; `const c = maxint64 - 1` is not a constant-expression here,
because the folder holds an `integer`. A program that wants a computed wide
constant computes it at run time.

**`round` is not extended**, there being nothing to round, and no `read`,
`succ`, `pred` or `ord` — see above. `pow` with an int64 base works and its
*exponent* is still an integer, which is §6.8.3.2's own asymmetry rather than
one added here.

**The seed was not refreshed for it.** ADR-0126 raised `tokMax` four commits
earlier and the seed already accepts this source; had it not, the seed would
have had to move first, which is the constraint ADR-0109 puts on the order
dialect features land in.

## Alternatives rejected

**Spell it as a subrange.** `type long = -9223372036854775808..9223372036854775807`
is how a standard Pascal says "an integer type of this size", and a processor
may choose the representation. It cannot be written here: the bounds are
literals, and a literal has to pass through a compiler whose integers are 32
bits. The same wall that made the text-carrying decision makes this spelling
unavailable.

**Two 32-bit halves in the compiler, so that 64-bit constants fold.** It buys
`const` declarations, case labels and array bounds of the wide type, and it
costs a hand-written 64-bit add, subtract, multiply, divide, remainder and
comparison inside `selfhost/compiler.pas` — arithmetic with no proof behind it,
in the one program whose bugs are inherited by everything it builds. The
constant-folding it buys is worth less than the risk it takes.

**Make `integer` 64 bits.** It is the smallest diff and the largest change:
`maxint` is in both standards, every conformance mode would move, every golden
would move, and ADR-0117's containment would be broken by the dialect meaning
something different by a word Extended Pascal defines.

**An implicit narrowing to `integer`, checked.** Every other language with two
integer widths does this. It puts a trap under an assignment the source does
not mark, where every other narrowing in this language is written down —
`trunc`, `chr`, a subrange store. The refusal is two lines in `Assignable` and
the diagnostic already existed.
