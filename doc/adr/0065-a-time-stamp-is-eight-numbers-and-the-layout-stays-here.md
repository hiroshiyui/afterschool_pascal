# 65. A time stamp is eight numbers, and the layout stays here

Date: 2026-08-12

## Status

Accepted.

## Context

ISO/IEC 10206:1991 §6.7.5.8 has one required procedure:

> `GetTimeStamp(t)` — The variable-access t shall possess the type denoted by
> the required type-identifier TimeStamp. The procedure shall attribute to the
> variable denoted by t either a value whose field DateValid represents the
> value true and whose fields day, month, and year represent the current date
> under the Gregorian calendar ... or a value whose field DateValid represents
> the value false and whose fields day, month, and year represent the date
> `January 1, 1'.

§6.7.6.9 adds two functions over the same record, and §6.4.3.4 defines it:

> There shall be a record-type designated packed and denoted by the required
> type-identifier TimeStamp. For each of the required field-identifiers
> DateValid, TimeValid, year, month, day, hour, minute, and second, there shall
> be an associated required field of the record-type, and that field shall have
> a type denoted by the type-denoter Boolean, Boolean, integer, 1..12, 1..31,
> 0..23, 0..59, and 0..59, respectively.

This is the last feature on README's list, and the only one in either standard
that reads something outside the program which is not a file.

## Decision

**The record's layout never crosses to the runtime, in either direction.**
`pas_gettimestamp` samples the clock and `pas_timestamp_field(k)` hands the
parts back one at a time; the compiler makes the eight stores itself, through
the same getelementptrs a field selection would use. `date` and `time` are
given three integers rather than the record.

The obvious alternative — pass the runtime a pointer to the record, or eight
field addresses — was rejected for **ADR-0030's reason**. A Boolean field is an
`i1`, and how an `i1` sits in memory is precisely the sort of fact neither
backend is allowed to depend on. Under this split nothing outside `llvmType`
has an opinion about the representation, and the C signatures mention only
`int`.

**§6.4.3.4's field order is the interface, and three places follow it.** Sema
builds the record in that order; CodeGen's `GetTimeStamp` loops over the
record's own field list rather than a written-out one, but its `date`/`time`
arm still names 2 and 5 as where the year and the hour begin; and the runtime
numbers its slots the same way. They cannot be reduced to one: the runtime has
no view of the record, and CodeGen is forbidden to look a field up by name —
the Sema→CodeGen contract (ADR-0008) is that CodeGen never inspects names, so a
literal index is the right shape rather than a shortcut.

What makes that safe is not care but a test. `timestamp_fixed.pas` gives every
field a different small number, so any disagreement between the three — a
swapped pair, a shifted base, a field list walked in another order — changes
its output. Without it the agreement was unchecked, which the mutation results
below say plainly.

**The six subranges do most of the enforcement.** A program that stores 13 into
`month` traps at the store like any other subrange (ADR-0018), which is what
leaves §6.7.6.9's error condition small enough to be one function: what a
subrange cannot say is that February has no 30th, and that is all `pas_date`
checks beyond the year. `year` is the one field of a TimeStamp whose type does
not bound it, being `integer`, which is why the year check exists at all.

**No `checkedForSubrange` on the stores.** Every value the runtime can return
is inside the field's bounds by construction: §6.7.5.8 fixes the fallbacks at
`January 1, 1` and midnight, and a calendar supplies no month 13. A check there
would be one no program could make fail — the same argument ADR-0044 made for
its dynamic-violation, and the reason `verify/` gained nothing here either.

There is one place a calendar *does* supply an out-of-range number, and it is
the second; the clamp below is what keeps this paragraph true, rather than the
two being independent decisions.

**§6.9.4 f) is a call site ADR-0046 could not have.** That record said every
entry on §6.9.4's list of what threatens a variable "is a place this compiler
had already decided the argument was a variable, so each check sits beside an
existing `isDesignator` test". Entry f) names `GetTimeStamp`, which did not
exist then — so this is the first threat-check written for a procedure rather
than found beside one. It still sits beside the `isDesignator` test, and the
wording is `checkNotThreatened`'s, unchanged.

**`date` and `time` are pure, and are therefore nonvarying.** The clock is read
by `GetTimeStamp`; these two are functions of the record and of nothing else,
so `nonvarying` needed no case — a call whose arguments are nonvarying already
answers true, and a call on a *variable* stamp already answers false because
the variable does. §6.6's initial-state specifier can therefore contain
`date(k)` for a constant stamp, which is right rather than incidental.

**Both results are fixed-width, so a length is a constant.** §6.7.6.9 gives
each "an implementation-defined length" — one length for the implementation,
not one per value — so `date` is ten characters of `YYYY-MM-DD` and `time` is
eight of `HH:MM:SS`, ISO 8601 in both cases. A string value is a pointer and a
length (ADR-0051), so only the pointer costs a call and the length is written
into the IR. That is the division `pas_str_concat` already made, where §6.8.3.6
fixes the length and the runtime returns only the bytes.

**The year's range comes from that decision and nowhere else.** `year` is an
`integer` and four digits cannot spell every one of those, so §6.7.6.9's "error
if ... not a valid calendar date" is read here to include a year this
representation cannot write: 1..9999. Refusing it is what keeps the length
fixed, and the alternative — a length that varies with the year — is the thing
the clause's singular "length" rules out.

## Consequences

**CodeGen has a case; Sema has the type.** The whole feature is one arm in
`emitStdProc`, one in `emitString`, one predefined record, and four runtime
functions. `verify/` gained nothing: there is no new arithmetic, and the two
error conditions are calendar facts rather than lowering rules — the case
ADR-0013 says to cross-check rather than prove.

**`TimeStamp` is the second required record**, and it needed none of what the
first did. ADR-0052 gave `binding(f)` a hidden frame slot because it is a
function returning a record; `GetTimeStamp` is a *procedure* and writes into a
variable the program already has, so the mechanism was not reached. The two
required records are also the only ones a program cannot write for itself:
ADR-0017's name equivalence means an identical declaration is a different type,
which `tests/extended/timestamp_errors.pas` shows with a record spelled out
field for field from NOTE 4.

**All four names are required identifiers**, so a program may declare its own
and win (§6.1.3) — and these are the ones most likely to collide, `date` and
`time` being ordinary English. `tests/extended/timestamp_redeclared.pas`
declares all four. That is also why the feature **reserves nothing**: the word
symbols were already complete before it landed.

**The feature is tested from four sides**, and each one exists because the
others could not reach something. `tests/extended/timestamp.pas` runs against
the real clock and asserts only what §6.7.5.8 promises of every moment — either
the flag is true and the fields are a date, or it is false and they are
`January 1, 1`. `timestamp_fixed.pas` fixes the instant and names every field.
`timestamp_invalid.pas` takes the second arm of that disjunction, which nothing
else executes. `timestamp_badepoch.pas` takes the fallback to the clock. The
paragraphs below are why none of the four is redundant, and every one of them
was written because a mutant survived the ones already there.

**"Current" is defined from `SOURCE_DATE_EPOCH` when that is set, and mutation
testing is what forced the decision.** Changing `tm_mon + 1` to `tm_mon` —
January numbered zero — survived every oracle. The reason is worth stating,
because it is not a thin corpus: **no program knows what day it is except by
asking the same function**, so a test can assert only what is true of every
moment, and an off-by-one in any field is true of almost every moment. Month
`tm_mon` names a different but perfectly real month eleven times in twelve. So
does a year, day, hour, minute or second one out.

The first attempt was to call `date(t)` on a freshly filled stamp, since
§6.7.6.9 makes an invalid date an error. It catches a month of *zero* — which
happens in January — and the handful of month-ends where the shifted month is
too short. About a tenth of the year. A test that depends on the day it runs
is not a test.

What settles it is that §6.7.5.8 leaves the meaning of "current" to the
implementation (D.36, D.37), so this implementation defines it as **the instant
`SOURCE_DATE_EPOCH` names when it holds one, and the system clock otherwise** —
the reproducible-builds convention, read as UTC because the point of fixing an
instant is that the answer not vary with the machine's zone. That is a
conforming definition, it is one users have independent reason to want, and it
is the only thing that lets a golden file name a date at all.

`tests/extended/timestamp_fixed.pas` is then an ordinary golden test over
2001-02-03 04:05:06, chosen so every field holds a different small number and
no two can be swapped unnoticed. It kills all three mutants — the month, a
minute reading the second, and the fixed instant read as local time — and it is
the only test that would notice §6.4.3.4's field order being walked in any
other. The harnesses learned one convention apiece, `name.epoch`, beside the
`name.in` they already had.

**An unconvertible epoch takes §6.7.5.8's other arm, and finding that out
changed the code.** The clause offers two answers, and the second — DateValid
false, the fields reading `January 1, 1` — exists for a processor that cannot
tell what day it is. On a working machine the clock does not fail, so nothing
had ever executed it; `timestamp.pas` can only check the disjunction, and
always checks it on whichever side was taken.

Defining "current" from a variable is what makes the other side reachable. A
count of seconds can be large enough to parse and still name no calendar date,
and the first implementation of this then fell through to the system clock —
so a program with the variable *set* answered with the wall clock and varied
from run to run, which is precisely what setting it is supposed to prevent. The
runtime now consults the clock only when no instant was named at all: a named
one the calendar cannot express is a date the processor cannot determine, which
is the arm's own case. `tests/extended/timestamp_invalid.pas` is that program,
and it is the only case that fixes the fallback fields — including the fallback
*year*, the one field of the eight a reader is most likely to take for
arbitrary.

**An ill-formed epoch falls back, and that needed a case of its own.** Defining
"current" from a variable makes the *parse* of that variable part of the
definition, and C's `strtoll` answers 0 for a word it cannot read at all — so a
conversion that never asks whether it consumed the whole word does not fall
back to the clock, it quietly claims 1970-01-01 for every program on the
machine. A wrong answer rather than a refused one, which is the kind a corpus
is least likely to notice, and mutation testing is again what said so.
`tests/extended/timestamp_badepoch.pas` sets the variable to a word and asserts
only that the year is not 1970 — the real clock being the only other place it
could have come from. So the definition has three answers and a case apiece:
`timestamp_fixed.pas` says a well-formed epoch is obeyed, `timestamp_invalid.pas`
says one that names no date gives the standard's fallbacks, and this one says an
ill-formed one is ignored. None of the three implies another. An *empty* setting
falls back through the `*fixed` test beside it, following the convention that
an empty value means unset; no case reaches that one, and the two guards are
genuinely independent — an empty string parses as 0 with nothing left over, so
the whole-word test admits it and only the emptiness test does not.

`tests/extended/timestamp.pas` keeps its live-clock assertions, because what it
tests is now the other half: that whatever the real clock says satisfies
§6.7.5.8's promise.

**A leap second is clamped, and the clamp is what makes the paragraph above
true.** `tm_sec` reaches 60 on a platform that reports leap seconds, and 60 is
not a value of `second`'s subrange. The three things that could be done with it
are not equally bad. Trapping stops a correct program at a moment it had no
control over. Storing it unchecked — which is what these stores do, by the
decision two paragraphs up — leaves a value in a `0..59` field that the field's
own type says cannot be there, and `time(t)` then writes `:60`; that is the
worst of the three, because nothing reports it. Clamping is the third, and the
second is reported as 59. §6.4.3.4 NOTE 5 lets a processor add a field for leap
seconds; this one has not.

So "every value the runtime can return is inside the field's bounds" is not a
fact about calendars. It is a fact about this one function, and the clamp is
the line that makes it one. The two decisions read as independent and are not,
which is worth stating because removing the clamp looks like tidying away a
defensive line that no test needs.

**No test reaches the clamp, and none can.** A leap second is not a value a
POSIX `time_t` can name, so the `SOURCE_DATE_EPOCH` path cannot produce one at
all; only `localtime` on a machine configured with a leap-second-aware zone
can, at an instant nobody can schedule a suite around. Mutation testing is what
established that rather than a reading of the code — removing the clamp
survives every oracle here. The gap is stated rather than closed: the only
thing that would close it is a way to hand the runtime a `struct tm` from
outside, and test-only machinery in `pasrt.c` would cost more than the gap.

**The tally, and what it is worth.** Thirty mutants over the runtime, both code
generators, both Sema paths and the two harnesses; twenty-eight are caught.
Four of the tests here exist because of it, and — more to the point — *two of
the changes to the code itself* do: the whole-word check on the epoch, and
sending an unconvertible instant to §6.7.5.8's invalid arm instead of to the
clock. Both were wrong answers rather than refused ones, and a corpus of golden
files is structurally poor at noticing those.

Of the two that survive, one is a gap and one is not:

- **The leap-second clamp**, above: unreachable here, stated rather than
  closed.
- **The Pascal backend's `trunc` for the two Boolean fields.** Emitting
  `store i32` into an `i1` field is *behaviourally* equivalent, and not by
  accident: the record is `{ i1, i1, i32, ... }`, so the over-wide store lands
  on two bytes of padding plus the first byte of `year`, and the very next
  iteration stores `year` over it. The eight fields are written in ascending
  order, which makes every field but the last self-repairing this way, and the
  last one is an `i32` already. It is an equivalent mutant, not a missing test:
  the emitted text differs and no observable behaviour does. Worth recording
  because the *reason* is fragile — reorder those eight stores and the same
  mutation stops being equivalent — and because a reader who finds this by
  running a mutation harness should not go looking for the test that would kill
  it.

### What this does not do

**No time zone is reported**, because §6.4.3.4 gives no field for one and
NOTE 5's extra fields are optional. The system-clock answer is therefore local
civil time with nothing saying which locality, and a `SOURCE_DATE_EPOCH` answer
is UTC — a difference the record above explains and the type cannot express.

**The two valid-flags move together.** Nothing here can determine the date
without also determining the time — a clock that cannot be read and an instant
the calendar cannot express both supply neither — so a value with a valid date
and an invalid time cannot arise, although the standard allows one.

**`date` of a stamp `GetTimeStamp` never wrote can still fail**, and that is
the intent: the fields are ordinary and a program may assign them, so
February 30th is reachable and §6.7.6.9 calls it an error.
`tests/extended/trap_date.pas` is that program.
