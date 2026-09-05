# ADR-0328: A C integer is the target's width

Date: 2026-09-05

## Status

Accepted. Adds AP 6.4.2.7. Closes `doc/roadmap.md`'s foreign-boundary row, which
ADR-0129 opened and ADR-0325 measured. Does **not** reopen the
`trunc(integer)` refusal `tests/trunc_integer.pas` pins, and says why.

## Context

ADR-0325 admitted a 32-bit target and catalogued six corpus programs that do
not run there. Five were one cause, and the roadmap had already named it as *a
decision rather than a lowering*:

    strlen('hello') = 21474836485

A declaration says `function strlen(s: string): int64`, which is right on an
LP64 target and four bytes too wide on i386. The low half is 5 and the high
half is whatever the register held. `readlink` is `ssize_t` and traps in
`trunc`; `struct timespec` is a `time_t` beside a `long` and its fields land in
the wrong places — the source of `tests/dialect/foreign_record.pas` says *a
`time_t` beside a `long` on every target* and then declares two `int64`,
because there was nothing else to write.

This language has `integer` at 32 bits and `int64` at 64 and no way to say *the
target's word*. That is what a foreign declaration needs.

## Decision

**Two required identifiers, `clong` and `csize`**, each denoting one of the two
integer types this language already has, chosen by the target: `clong` is the
type a C `long` fits and `csize` the type a C `size_t` fits. On x86-64 and
aarch64 both are `int64`; on i386 both are `integer`.

**Two and not one**, and the measurement is why. They agree on every admitted
target and differ on Windows x64, which is LLP64 — a 32-bit `long` beside a
64-bit pointer, confirmed with `_Static_assert` against clang before the names
were chosen. Windows is named in the cross-platform chapter, so one identifier
would have been correct for the three targets that exist and silently wrong for
the first one planned.

**They introduce no type.** Each denotes `integer` or `int64`, so no predicate
gains a case, no dispatch gains an arm, `verify/lowering.py` is untouched and
CodeGen never hears of them. `RequiredType` is the whole of the compiler change,
and `CLongSize` is a third target function beside `PtrSize` and `WordAlign`.

## What the corpus said, twice

**Five catalogued cases now pass, and `target32` is what said so.** The
catalogue fails in both directions, so removing the language obstacle made the
gate red with *five catalogued case(s) now pass — say why and take the row
out*. That is the mechanism ADR-0183 built for a heap balance doing what it was
built for, one gate over. `tests/checks/target32_known.txt` is down to one row,
and that row is a program allocating 2 GB on purpose.

**And one of the five was not a declaration at all.**
`tests/extended/timestamp_invalid.pas` sets `SOURCE_DATE_EPOCH` to `LLONG_MAX`
and expects the date to be rejected. `pas_gettimestamp` wrote `now = (time_t)v`
and asked `gmtime`; on a 32-bit `time_t` that truncation lands on 1969-12-31,
which the calendar accepts — so a program asking for an instant no
representation can hold was told the date was valid. The fix is the round trip,
`(long long)now == v`, which on a 64-bit target is true by construction and
costs nothing. No language change could have found that; running the corpus
did.

## The narrowing, and the refusal that was not reopened

A program that receives a `csize` and wants an `integer` must narrow. `trunc`
is that narrowing for `int64` (AP 6.4.2.6.4) and is **refused** for `integer` —
§6.7.6.3 requires a real, and `tests/trunc_integer.pas` exists to pin that,
from the validation suite's DEV158. So `trunc(MyLength(s))` compiles on x86-64
and is refused on i386, which is exactly the target-specific program these
identifiers exist to prevent.

**Admitting `trunc` of an integer was written, and then reverted.** It is one
line, it satisfies AP 6.0.1, and it makes the narrowing portable — and it
withdraws a conformance fix somebody took deliberately, in a commit about a
foreign boundary, where nobody would look for it. The suite found it
immediately, which is the case doing its job; the decision not to take it
anyway is the point of this section.

What a program writes instead is the widening and then the narrowing:

    var n: int64;
    n := ExtReadlink(path, buf);
    r := t[1..trunc(n)]

Two lines on every target, and each step is a rule that already existed —
§6.4.6 c)'s widening, which is the identity where `csize` is already `int64`,
and 6.4.2.6.4's checked narrowing. `lib/dialect/pasfs.pas` was already written
that way and needed no change at all.

## Consequences

**Two spellings leave 6.2.2.10's region**, and `tests/dialect/inherits_extended.pas`
witnesses that §6.1.3 gives them back — shadowed as a *variable*, which is the
harder half, the parser having to read the name as an ordinary identifier.
`--dump-words` reports both, which is that dump walking the outermost scope
rather than holding a list (ADR-0301).

**`time_t` and `off_t` ride on `clong`** and are not required to. On all three
admitted targets they are that width; a C library representing a time in 64
bits beside a 32-bit `long` is expressible only by naming `int64`, and AP
6.4.2.7.1 NOTE 4 says so rather than leaving a reader to find out.

**`csize` covers four C types** — `size_t`, `ssize_t`, `ptrdiff_t`, `intptr_t`
— because they are one width on every admitted target. NOTE 3 records that a
target distinguishing them is a measurement to be taken before it is admitted,
which is ADR-0156's discipline and not a new rule.

## What this does not do

**It does not add a C type system.** A declaration still names Pascal types;
these two are Pascal types whose choice is the target's. `int`, `short`,
`unsigned` and the rest are unaffected — `integer` is C's `int` on every target
here, and nothing measured says otherwise.

**It does not make the FFI safe.** A wrong width is now *expressible* as right;
nothing checks that a declaration names the type the C header does.
`foreign-layout` (ADR-0185) checks a record's fields against a real header and
is the only thing here that can, and it does not reach a function signature —
`doc/sop.md` §7's row above it is unchanged.

**It does not narrow implicitly.** ADR-0128's argument stands: an implicit
narrowing puts an unwritten run-time check under an ordinary assignment.

## Alternatives rejected

**One identifier, pointer-sized.** Four of the five cases, and wrong for C's
`long` on the first target the plan names.

**No identifier — require a `pasx_` wrapper for every varying type.** It is
already the rule for `lib/` (ADR-0185), and extending it everywhere means the
FFI cannot call `strlen`. A dialect whose FFI cannot call the C library is not
one ADR-0109 would recognise.

**A distinct type kind whose representation is the target's but whose range is
64 bits**, converting at the foreign boundary. It reads better for a program —
one type, `trunc` always available — and it fails at a record: `struct
timespec` needs a *field* of four bytes on i386, so the representation must
vary anyway, and then the kind buys a predicate, a dispatch arm and a lowering
for the benefit of one narrowing.
