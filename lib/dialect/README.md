# `lib/dialect/` — how a routine says it may have failed

These sixteen modules use constructs no standard Pascal has, and **thirteen**
of them are the only part of this repository that reaches outside the program: the
environment, the file system, file descriptors, `errno`, and the C functions
behind them. `pascontainer`, `pasjson` and `paslsp` are the three that do not —
they are pure computation over what the other thirteen hand them, here because
they are dialect-only for ADR-0119's reason and not because they touch
anything. The rule below is about the thirteen.

They were built one at a time, each demanded by the boundary rather than
designed, and they arrived with **four** ways of reporting a failure. This file
is the rule that turned out to be behind them, written down after the fact and
checked against every exported routine. It is here rather than in `doc/` because
the reader who needs it is the one adding a module.

## The rule

Two questions decide the shape. They are asked in this order and they do not
overlap.

**1. Is there a value to return?**

No — the routine acts on the world and either succeeds or does not:

```pascal
function Remove(path: PathName): ErrorCode;
```

**`ErrorCode`.** `errNone` is success. Thirty-one exported routines take this
shape: `Define`, `Undefine`, `Remove`, `Rename`, `MakeDirectory`,
`RemoveDirectory`, `Close`, `WriteAll`, `WriteText`, `PasStream`'s `OpenRead`,
`OpenWrite`, `OpenAppend`, `WriteText`, `WriteLine` and `Flush`, `PasDir`'s
`Open`, `Next` and `List`, `PasUnicode`'s `ToText`, `Fold`, `Upper` and
`Lower`, and `PasNet`'s `Connect`, `Listen`, `Accept`, `Service`, `WriteText`,
`WriteLine`, `ReadLine` and `Wait` — the four `Open`s included, because the stream or
directory they answer goes into the `var` parameter and what is left to return
is whether the world refused.

`PasDir.Next` is the one that uses more than two of the six codes, and it is
worth reading as the shape rather than as an exception: `errNone` with a name,
`errAbsent` at the end of the directory, `errFull` for a name too long for the
string it was going into, `errIO` for a refusal. Each is that code's own gloss
applied unchanged — which is the argument for a small closed set, since a
routine with four outcomes needed no type of its own.

**2. Then: can the value be missing for a reason the caller could act on?**

No — absence is an ordinary answer and there is nothing more to say about it:

```pascal
function Lookup(name: EnvText): OptEnvText;   { OptEnvText = ?EnvText }
```

**An optional, `?T`.** An environment variable that is not set has not failed;
it is not set, and no code would tell the caller anything the `nil` does not.
*Absence is not a failure* is the slogan, and this is the arm it is about.

Yes — the caller may want to branch on why, or report it:

```pascal
function WorkingDirectory = r: PathResult;
```

**A fallible type**, `T ! E` (AP 6.4.13) — which *is* that result record, with
the field names fixed by the language, so the shape is no longer a convention
each module copies:

```pascal
PathResult = PathName ! ErrorCode;
```

ADR-0118 makes its tag authoritative: reading `r.val` when `r.ok` is false
stops the program, so the discipline is not something the caller may forget.
**The three field names are `ok`, `val` and `cause` in every module.** Twelve
exported routines: `WorkingDirectory`, `LinkTarget`, `OpenRead`, `ReadInto`,
`WriteFrom`, `ParseInt`, `Log10`, `Log2`, `FMod`, `Run`, `Capture`,
`CaptureLines`.

Before AP 6.4.13 each module declared its own record and named the two arms
itself, and the names drifted: the failing side was `code` in four modules,
`openCode` in `PasIO` and `reason` in `PasProcess` — where `code` was the
*success* payload. `r.code` meant two things in one library. That is what a
language type removes and a convention could not.

## And one shape that is not about failure at all

```pascal
function Exists(path: PathName): boolean;
```

**A question about the world** answers `boolean`. `Exists`, `Defined`, `Failed`,
`AtEnd` and `ReadLine` are questions, not operations: there is no failure
distinct from the answer, and giving one an `ErrorCode` would invent a third
state the caller would have to handle for nothing. `ReadLine` is the one that
looks like an operation, and its `false` means *nothing more*, which is the
answer and not a refusal.

## Two conveniences, and their names are fixed

- **`XOr(r, whenBad)`** takes a result and a default, for a caller who has a
  sensible answer and does not want to branch: `LookupOr`, `PathOr`, `CountOr`,
  `IntOr`, `RealOr`. Always the result first and the default second.
- **`ResultText(r)`** renders a result as a sentence, for a caller composing a
  message. `PasError.ErrorText` does the same for a bare code, and it answers
  for `errNone` too, so a routine that formats unconditionally needs no special
  case.

## The second rule: a boundary shape may be a parameter, not a result

The rule above decides the *shape of an answer*. This one decides which shapes
may not be one at all, and it comes from ADR-0149's survey of the three pairs
the dialect has that nearly overlap:

| Pair | The owned shape | The other shape | What the other shape says |
| --- | --- | --- | --- |
| absence | `^T` | `?T` | there may be no value |
| sequences | `string(n)`, `packed array [1..n] of char` | `array of T` | the sequence belongs to the caller |
| numbers | `integer` | `int64` | the number came from outside |

The right-hand shape in each row exists because something **outside the block**
had to be described: a foreign function may answer null, a buffer belongs to
whoever lent it, the kernel says `ssize_t`. A parameter is where that is exactly
right — passing a slice *is* the caller's ownership written down. A result has
no owner, so a boundary shape there is the boundary leaking into your interface.

**Convert at the first opportunity**, which is what the thirteen already
do:

- `o^` after a `= nil` test, and the value copied out — `PasEnv.LookupOr`,
  `PasFS.WorkingDirectory`, `PasOS.ErrorNumberText`. There is not one pointer
  type in this directory; every `^` here is an optional access.
- a whole-array assignment from a `packed array [1..n] of char` into a
  `string(n)` — `PasFS.PathBuffer` is packed for exactly this, and it is the one
  type that is both a string-type and a slice actual. A `string(n)` is
  **refused** as a slice actual, which keeps `length` meaning one thing on both
  sides of a call.
- `trunc`, with an argument for why it cannot reject — `PasIO.Counted` narrows
  `read`'s `ssize_t` and says why the value is already in range. No exported
  routine in this directory mentions `int64`.

The language enforces two-thirds of this for you: a slice result is a syntax
error (AP §6.7.3.9.2) and no `int64` expression is a constant (AP §6.4.2.6.5).
Only the optional can be written as a result, and that is not an oversight —
it is the *absence is not a failure* arm of the first rule, and what `Lookup`
returns is a `?string`, a value, and not a foreign pointer wearing a flag.

## The third rule: an owned value is filled, never returned

A handle (AP 6.4.12) cannot be a Pascal function's result and cannot be
copied, so a routine that produces one takes the variable that will own it as
a `var` parameter and fills it:

```pascal
function OpenWrite(var s: Stream; path: PathName): ErrorCode;
```

The caller declares the `Stream`, the module assigns it from the external
function — the one assignment the type has — and the block the caller
declared it in is what closes it. `s <> nil` asks whether it is open and is
the whole of what a caller can ask. This is not a shape chosen over the
others; it is the only one the type admits, and it is why `PasStream`'s
`Open`s answer an `ErrorCode` where `PasIO.OpenRead` answers a result record
carrying the descriptor. A module that keeps its handle private — `PasProcess`
with its `Pipe` — shows nothing of this and answers the result record as
before.

## What the rules do not cover, and you should know before relying on them

**A failure the boundary cannot report.** `PasEnv.Lookup` binds C's `getenv`,
which returns a pointer to a string of a length nobody stated. The conversion
into `EnvText` is where the length is discovered, and a value longer than
`MaxValue` **stops the program**:

```
runtime error: a string of length 5000 does not fit a capacity of 4096
```

That is a third outcome the optional cannot express, and it is not an oversight
in the rule — it is a place the rule cannot be applied. `PasFS` faces the same
question and answers it, because `getcwd` is *lent a buffer* and can report
`ERANGE`, which becomes `errFull`; `getenv` cannot be asked how long its answer
is before it is copied, and the dialect has no result form that would hold an
unmeasured one (`?string` without a capacity is not a result type).

So: **where a boundary cannot report a failure, say so at the routine.** The
alternative is a truncation nothing reports, which is worse, and that choice is
`PasEnv`'s own and deliberate. `PasOS.ErrorNumberText` has the same shape
against `strerror` and is unreachable in practice rather than guarded.

**Nothing checks any of this.** Both rules are conventions, not gates: a new
module returning a result record with a tag spelled `success` would compile,
link and pass every test in this repository, and so would one answering an
`int64`.
