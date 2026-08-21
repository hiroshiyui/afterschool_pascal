# `lib/dialect/` — how a routine says it may have failed

These seven modules are written in `--std=afterschool` and are the only part of
this repository that reaches outside the program: the environment, the file
system, file descriptors, `errno`, and the C functions behind them.

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

**`ErrorCode`.** `errNone` is success. Nine exported routines take this shape:
`Define`, `Undefine`, `Remove`, `Rename`, `MakeDirectory`, `RemoveDirectory`,
`Close`, `WriteAll`, `WriteText`.

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

```pascal
PathResult = record
  case ok: boolean of
    true:  (path: PathName);
    false: (code: ErrorCode)
  end;
```

**A result record**, and ADR-0118 makes its tag authoritative: reading `r.path`
when `r.ok` is false stops the program, so the discipline is not a convention
the caller may forget. **The tag is spelled `ok` in every result record here**
and the payload carries each record's own name. Nine exported routines:
`WorkingDirectory`, `LinkTarget`, `OpenRead`, `ReadInto`, `WriteFrom`,
`ParseInt`, `Log10`, `Log2`, `FMod`.

## And one shape that is not about failure at all

```pascal
function Exists(path: PathName): boolean;
```

**A question about the world** answers `boolean`. `Exists`, `Defined`, `Failed`
and `AtEnd` are questions, not operations: there is no failure distinct from the
answer, and giving one an `ErrorCode` would invent a third state the caller
would have to handle for nothing.

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

**Convert at the first opportunity**, which is what these seven modules already
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
