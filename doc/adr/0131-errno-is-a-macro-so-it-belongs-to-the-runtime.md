# ADR-0131: `errno` is a macro, so it belongs to the runtime

## Status

Accepted. `lib/dialect/pasos.pas` and one routine in `runtime/pasrt.c`.

It closes the "cannot say why" wall ADR-0122, ADR-0129 and ADR-0130 each
recorded. It does **not** open the returned-pointer question those records
were waiting on, and §"What this does not do" says why it did not have to.

## Context

Three records in a row closed by saying the same thing: a binding module
answers `errIO` and cannot say which failure it was, because `errno` is out of
reach. `doc/roadmap.md` had it as the cheapest thing left on the far side of
the FFI wall, and `lib/dialect/pasfs.pas` and `lib/dialect/pasio.pas` both
carried a paragraph apologising for it.

**Every one of those records gave the wrong reason.** They said glibc spells
`errno` as `*__errno_location()`, a function returning `int *`, and that a
returned pointer is what ADR-0122 does not admit. That is true, and it is a
detail of one C library. The reason that matters is in the language C
specifies: **`errno` is a macro**. It expands to an lvalue and has no linker
symbol. No foreign-function interface can bind it — not this one, and not a
better one, and not one with a header parser, since a header parser would read
the macro and still have nothing to call.

So this was never blocked on ADR-0109's memory-safety model. It was blocked on
a misdiagnosis, and the thing it was actually waiting for is the oldest
mechanism in this repository.

## Decision

**`runtime/pasrt.c` answers it**, in one function, because that file is where
anything not expressible in the emitted IR has always gone.

```c
int pasx_errno(void) { return errno; }
```

**The prefix is the decision.** `ReservedForeignName` refuses the whole `pas_`
prefix, so a program cannot write `external 'pas_errno'` — and that refusal is
right, because `pas_` names are ones the emitted module already declares and
LLVM will not take a second declaration of a global. A routine the emitter
never names is not that hazard. So the runtime gains a second surface:

- **`pas_`** — what the compiler emits calls to. Reserved, and
  `tests/checks/foreign_reserved.py` keeps the predicate a mirror of the
  emitter in both directions.
- **`pasx_`** — what a Pascal *program* may bind by name. Never emitted, never
  reserved, and `external 'pasx_errno'` is how it is reached.

The split is what keeps `ReservedForeignName` a mirror of the **emitter**
rather than of the archive, which is the property that gate exists to hold.

**`PasOS` is the module**, and it offers the number and the sentence and not a
classification:

```pascal
function LastErrorNumber: integer;
function ErrorNumberText(n: integer): SysText;
function LastErrorText: SysText;
```

`strerror` needed no new mechanism at all — it answers a `char *`, and
ADR-0123's optional string is how one of those already comes back, with the
copy made at the call site.

**It does not map a number onto `ErrorCode`**, and refusing to is the policy
`lib/dialect/pasfs.pas` set over `access`'s `R_OK`: ENOENT is 2 and EACCES is
13 in a header this compiler cannot read, and a number a module cannot check
does not go in. So the division of labour is that a binding module gives the
**code**, which is PasError's closed set and is what a `case` covers
(§6.4.3.3 with ADR-0096), and this one gives the **sentence**, which nothing
here classifies.

## Consequences

### What it buys

`tests/dialect/lib_os.pas` is the demonstration and it is one line of the
golden: two failures, one `errIO` apiece, and *No such file or directory*
against *Not a directory*. Every module in `lib/dialect/` gains that, with no
change to any of them.

The capacity is 128 characters, which is not arbitrary: ADR-0123 makes a value
exceeding an optional string's capacity an error in §6.4.6's words, so a short
capacity would turn a diagnostic message into a **trap**. libc's longest is
under 60.

### What it costs

**The value is stale by construction.** Nothing clears `errno` on success and
any intervening library call may set it, so `LastErrorText` is meaningful only
in the statement after the one that failed. That is C's contract and this does
not improve on it; the module says so and there is no mechanism that could
enforce it.

**`ErrorNumberText`'s null guard is unreachable from a test.** POSIX specifies
`strerror` to answer a sentence for every number, including one it does not
know, so the `m = nil` arm is defensive and no case here enters it. It answers
a sentence of its own rather than an empty string, so a caller that somehow
reached it prints something. Registered rather than claimed as covered — the
second such branch in two increments, after `WriteAll`'s retry.

**A `pasx_` routine is a foreign call with all of an FFI's blind spots.**
Nothing checks the signature (ADR-0121), so a program writing
`function e(x: integer): integer; external 'pasx_errno'` gets undefined
behaviour with no diagnostic, exactly as it would against libc. The runtime is
not privileged here; it is simply another archive on the link line.

### What it does not do

- **It does not admit a returned pointer.** `pasx_errno` answers an `int` and
  `strerror` answers a `char *` that ADR-0123 already handled. ADR-0109's
  memory-safety model is untouched, and the returned-pointer question is
  exactly where ADR-0122 left it.
- **It does not classify.** No `ErrorCode` is derived from a number, for the
  reason above. A caller that needs to branch on "the file was not there"
  specifically still cannot.
- **It does not clear `errno`.** The POSIX idiom for a call whose failure
  return is also a valid value — set it to zero first, then test — is not
  expressible, and no routine in `lib/dialect/` needs it.
- **It is not a licence to move things into the runtime.** `pasx_` exists for
  what is *categorically* unbindable, and a macro is that. The opposite move —
  taking a `pas_` name and exposing it — is what ADR-0121 already refused when
  it put `atan`, `atan2` and `hypot` into the runtime precisely so a program
  could have the libc spellings.

## Alternatives rejected

**Binding `__errno_location` and dereferencing the result.** It is a glibc
symbol and not C, so it is wrong on musl-with-a-different-spelling and on
anything else; and it needs a returned pointer to become a Pascal value, which
is the thing three records have refused. The macro argument makes this not
merely unportable but beside the point.

**Making `errno` a required identifier of the dialect.** ADR-0128 spent a
spelling that way for `int64` and had to write a paragraph into
`tests/dialect/inherits_extended.pas` for it, because §6.2.2.10 puts a required
identifier in a scope enclosing the program. Spending one for a POSIX detail
would be a bad trade, and it would put an operating system's error numbering
into the *language* rather than into a module.

**Exempting a name from `ReservedForeignName`'s `pas_` rule.** It would have
worked and it would have made the predicate a list of exceptions rather than a
statement about what the emitter writes — which is the property
`foreign-reserved` checks and the reason that gate can fail in both
directions. A second prefix costs nothing and keeps the rule a rule.
