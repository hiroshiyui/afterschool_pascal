# `lib/dialect/` — how a routine says it may have failed

These **twenty-three** modules use constructs no standard Pascal has, and
**twelve** of them are the only part of this repository that reaches outside
the program: the environment, the file system, file descriptors, the terminal,
`errno`, TLS, and the C functions behind them. Counted by what they *bind* — an
`external` declaration naming a foreign symbol — which is the line that
matters here, since the rule below is about how a foreign failure is reported:
`pasdir`, `pasenv`, `pasfs`, `pasio`, `pasmathx`, `pasnet`, `pasos`,
`pasprocess`, `passtream`, `pasterm`, `pastls`, `pasunicode`.

`pastls` is the one whose far side is neither the C library nor this project's
runtime: it binds OpenSSL, and a program importing it links `-lssl -lcrypto`
while every other program links neither. That is why the binding is here and
not in `runtime/pasrt_posix.c` — the runtime links nothing, and a `pasx_` for
this would make every program in the tree depend on a cryptography library
(ADR-0264).

The other eleven are pure computation over what those hand them, here because
they are dialect-only for ADR-0119's reason and not because they touch
anything: `pascontainer`, `paserror`, `pashttp`, `pashttps`, `pasjson`,
`paslist`, `paslsp`, `paslspdiag`, `pasparse`, `pasregex`, `pastime`.
`pashttp` is the one worth a second look — a network client that binds
nothing, because `PasNet` holds the socket and HTTP is a grammar over it, and
since ADR-0265 that grammar is *exported* so a transport is a caller of it
rather than a branch inside it. `pashttps` is that made concrete: the same
grammar over `PasTls`, twenty-four lines, binding nothing itself.

The rule below is about the eleven.

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

**`ErrorCode`.** `errNone` is success. Thirty-six exported routines take this
shape: `Define`, `Undefine`, `Remove`, `Rename`, `MakeDirectory`,
`RemoveDirectory`, `Close`, `WriteAll`, `WriteText`, `PasStream`'s `StreamOpenRead`,
`StreamOpenWrite`, `StreamOpenAppend`, `StreamWriteText`, `StreamWriteLine` and `StreamFlush`, `PasDir`'s
`OpenDir`, `NextEntry` and `ListDir`, `PasUnicode`'s `ToText`, `Fold`, `Upper` and
`Lower`, and `PasNet`'s `NetConnect`, `NetListen`, `NetAccept`, `NetService`, `NetWriteText`,
`NetWriteLine`, `NetReadLine` and `NetWait` — the four `Open`s included, because the stream or
directory they answer goes into the `var` parameter and what is left to return
is whether the world refused.

`PasDir.NextEntry` is the one that uses more than two of the six codes, and it is
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
each module copies — and, since ADR-0297, always a production of `PasError`'s
one schema, so that every module's result type is the same type where the
value type is:

```pascal
PathResult = Fallible(PathName);    { PasError: Fallible(T: type) = T ! ErrorCode }
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
`AtEnd` and `StreamReadLine` are questions, not operations: there is no failure
distinct from the answer, and giving one an `ErrorCode` would invent a third
state the caller would have to handle for nothing. `StreamReadLine` is the one that
looks like an operation, and its `false` means *nothing more*, which is the
answer and not a refusal.

The same reasoning admits a bare number where the call it wraps cannot fail.
`PasProcess.ProcessId` is `getpid`, of which POSIX says *"shall always be
successful and no return value is reserved to indicate an error"* — so a
`RunResult` around it would be a `cause` field no caller could ever read. Check
the specification before taking this route; it is the narrow case, and every
other call in these modules can fail.

## Two conveniences, and their names are fixed

- **`ValueOr(r, whenBad)`** takes a result and a default, for a caller who
  has a sensible answer and does not want to branch. One routine, in
  `PasError`, generic over the result's value type and inferred at the call
  (AP 6.7.3.10.4) — which is why every result type here is a production of
  `PasError.Fallible`, `IntResult = Fallible(integer)` and the rest, and why a
  new one must be too: a type written `T ! ErrorCode` on its own is a type
  `ValueOr` cannot take (ADR-0297). The four per-type accessors it replaced —
  `IntOr`, `PathOr`, `CountOr`, `RealOr` — are gone. `LookupOr` is the same
  shape over an absent variable, which is not a failure, and stands. Always
  the result first and the default second.
- **`<Result>Text(r)`** — `IntResultText`, `CountResultText` — renders a result
  as a sentence, for a caller composing a message. Named for the result type
  and not `ResultText` alone, because two modules exporting one spelling is
  what `export-unique` refuses (ADR-0298). `PasError.ErrorText` does the same for a bare code, and it answers
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

**Convert at the first opportunity**, which is what the eleven already
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
`StreamOpen`s answer an `ErrorCode` where `PasIO.OpenRead` answers a result record
carrying the descriptor. `TlsConnect` is the same shape one level up: what
it fills is a **record** of three handles -- a socket, a context and a session
-- which is affine for the same reason a single handle is, and which the
declaring block releases in one go. A module that keeps its handle private — `PasProcess`
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
