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

## What the rule does not cover, and you should know before relying on it

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

**Nothing checks any of this.** The rule is a convention, not a gate: a new
module returning a result record with a tag spelled `success` would compile,
link and pass every test in this repository.
