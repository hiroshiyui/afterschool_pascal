# ADR-0123: An optional is a type, and it is how a pointer comes back

## Status

Accepted. The third increment of ADR-0109's foreign-function interface, and the
first of its four open decisions to be settled — though only the narrow one.
ADR-0122 refused every result that is an address and named what it was waiting
for: "a returned `char *` may be null, and null is not an error … What is
missing is an optional type, which is one of ADR-0109's four open decisions and
is the *pointer safety* row of the roadmap's table — not the memory-safety
row."

This record supplies that type and lifts the refusal exactly that far. The
memory-safety decision stays open and is not touched.

## Context

Two things arrive together here and only one of them is about C.

**A foreign function that answers a pointer may answer a null one.** `getenv`
of a name that is not set does, and it is not a failure: nothing went wrong and
there is nothing to report. ADR-0122 could do neither of the two things
available to it — trapping would stop a program on a value the C library
returns on purpose, and answering the empty string would conflate "not set"
with "set to nothing" — so it refused the whole direction. That refusal is what
kept `errno`, `strerror`, `setlocale` and every name-answering call out of
reach, and with them locales and most of what a socket needs.

**And the language has no way to say "there may be nothing here".** Every
fallible thing built so far invents its own: ADR-0120's result record carries a
reason as well as a value, `lib/pasmap.pas`'s `MapGet` takes a `whenAbsent`
argument, `lib/pastext.pas`'s `TryParseInt` writes through a `var` and answers
a boolean. Absence with *no* reason is the commonest case of all and the one
with the least support — and ADR-0120's shape cannot serve it, for a reason
that record states itself: its safety comes from the payload being what sets
the tag, and an arm with no payload has nothing to set it with. That is exactly
why `lib/dialect/pasfs.pas` answers a bare `ErrorCode`.

### What Pascal already has, and what it does not

`nil` exists and §6.4.4 already gives it the right *meaning*: a pointer value
that identifies no variable, with NOTE 1 drawing the consequence that `nil^` is
not a dereference of a non-pointer but "a pointer with nothing on the other
end". ADR-0019 checks every dereference at run time. So the machinery for "a
value that may not be there, checked when it is asked for" is built and
familiar.

What is missing is the *type*: `^T` is the only thing that may be `nil`, and it
brings indirection and a heap with it. A program that wants "an integer, or
nothing" has to allocate one.

### The one thing this must not do

ADR-0117 makes the dialect *contain* Extended Pascal, and
`tests/dialect/inherits_extended.pas` pins it: everything Extended Pascal
accepts, the dialect accepts and means the same thing. So making `^T`
non-nullable — the Rust and Swift answer, and the reason those languages can
say "no bare null" — is unavailable here. It would change the meaning of a
conforming program. The optional has to be an *addition*.

## Decision

### 1. `?T` is a type, and `?` costs the lexis nothing

`?` is a character neither standard admits anywhere at all — not in an
identifier, not as an operator, not among §6.1.9's alternative
representations — so the dialect can take it and no program that compiled stops
compiling. That is ADR-0121's property (a directive reserves nothing) obtained a
second way, and it is why the reference front end needed no teaching:
`--std=extended` already says `unexpected character '?'`, in those words, and
difftest agrees without a line changing in `src/`.

The denoter takes a whole type-denoter and not a name, which is where it parts
from `^T`. §6.4.4 makes a pointer's domain a type-*identifier* so that a type
may name itself and close a cycle; an optional has no cycle to close, because it
*contains* its T rather than pointing at it — a type that were its own optional
could have no size.

### 2. `nil` is the absent value, and `= nil` is the test

```pascal
type OptName = ?string(16);
var n: OptName;
begin
  n := nil;                          { absent }
  n := 'hello';                      { present, by ordinary assignment }
  if n <> nil then writeln(n^)
end
```

No new identifier and no new operator. `nil` already means "nothing here", and
reusing it means a reader who knows §6.4.4 knows this. An optional compares
with `nil` and with nothing else — not even with another optional of its own
type, because that would need T's own equality and T may be a record or an
array, which have none.

### 3. `o^` is the only way to the value, and it is checked

Spelled like a dereference because it is the same question, and it traps for
the same reason ADR-0019's does. Reading an absent optional stops the program
with `this optional has no value`.

**That is the guarantee, stated the other way round: a `T` that is not optional
can never be absent.** The check is not elided by a guard —
`if o <> nil then o^` still emits it — which is flow-sensitive narrowing and a
Sema this record does not build; `doc/sop.md` §7 carries it. Swift's `!` traps
too, and the value of the type is not that the trap is impossible but that it
is *localised* to the places the source says `^`.

### 4. Assignment goes one way, and that is the whole of the type discipline

`?T` is assignable from `nil` and from anything assignable to `T`. **Nothing is
assignable from a `?T`.** Two lines in `Assignable`, and everything else falls
out of them: `n := o` is refused, `o + 1` is refused by the arithmetic rule that
already existed, `writeln(o)` by the write rule, `o < nil` by the ordering rule.

Refusal by construction, which this repository prefers to an enumerated list
(CLAUDE.md): of the twelve refusals in `tests/dialect/optional_types.pas`, four
are written out and eight are diagnostics that were already there.

### 5. It is name-equivalent, like every other structured type

Two variables separately declared `?integer` have two types, exactly as two
separately declared `array [1..3] of integer` do (ADR-0017). No exception is
made. A wrapper type invites one — it looks like it should be identified by
what it wraps — and the answer is that the language already tells its users to
name a type they intend to share, and one rule is better than two.

### 6. The representation is a flag and the value, and it travels by address

`{ i32, T }`. `IsStructured` answers yes, which is what grants whole-variable
copying and makes a value parameter a copy, a function result a memory result
and an assignment a memcpy; five call sites, all of them the ones that meant
"copied whole" already.

The value is stored **before** the flag. That matters: storing a string longer
than its capacity is §6.4.6's error and stops the program, so writing the value
first means no optional is ever marked present over storage a store did not
finish writing.

### 7. A foreign function may return `?S`, where S is a string with a capacity

```pascal
type EnvText = string(4096);
     OptEnvText = ?EnvText;
function getenv(name: string): OptEnvText; external 'getenv';
```

Null is absence. Non-null is copied at the call site into the result slot, so
**no C pointer ever becomes a Pascal value** — what the program holds is a
string of its own, with its own lifetime, and the pointer is dead by the end of
the statement.

The capacity is required because the copy needs somewhere of a known size to
go, and it is a real check: a value longer than the capacity is an error
reported in §6.4.6's words, by the same `pas_str_store_var` an ordinary
assignment uses. It is the same rule; only the distance the value travelled
differs.

`pas_cstr_take` does the copy and **answers** the flag rather than writing it,
so the layout of an optional stays entirely in CodeGen and no runtime routine
holds a second opinion about it.

### 8. `?integer` does not come back, and neither does a bare string

C has no null integer, so there is nothing for a `?integer` result to mean. And
a bare `string` result is still refused — with a message that now names the
remedy, since there is one.

## Consequences

- **`lib/dialect/pasenv.pas` is what it buys**, and the distinction it can draw
  is the point: `Lookup` of an unset name answers `nil`, of a name set to the
  empty string answers a present value of length zero, and a caller can tell
  them apart. No previous shape in this repository could.
- **`putenv` is refused by the module rather than bound**, and this is the
  first time `doc/sop.md` §7's registered blind spot has decided an interface.
  `putenv` keeps the pointer it is handed and the environment refers to it
  forever; this compiler's string arena reclaims that storage at the end of the
  statement. `setenv` copies, so `Define` is safe in a way `putenv` could not be
  made safe.
- **A latent gap in ADR-0122 was found by writing this**, and fixed here:
  `function setenv(name, val: string; …)` was refused, because §6.7.3.3's
  "one formal-parameter-section is one parameter-form, so every actual brings
  the same tuple" was being applied to a foreign heading. A foreign `string`
  formal is not a schematic formal and has no tuple, so the clause is not about
  it — but `tests/dialect/foreign_string.pas` had only ever passed `strcmp` two
  actuals of equal length, so nothing had asked. `strcmp('b', 'ab')` would have
  been refused since ADR-0122 landed.
- **`errno` is still out of reach**, so `lib/dialect/pasfs.pas` still answers
  one category. It is `*__errno_location()` — an `int *`, not a `char *` — and
  a returned pointer to a *variable* is a different question from a returned
  string, because nothing is copied and the lifetime is real. It is also, on
  every C library, a macro rather than a function, which no FFI can bind.
- **`verify/` gets no rule.** The lowering is a flag store, a flag load and a
  GEP; a rule stating "the flag is 1 after storing a value" would restate the
  emitted text, which ADR-0013 says dilutes "no known gaps". The commit carries
  a `Model-unchanged:` trailer.
- **difftest sees the refusal and nothing else.** `?` outside the dialect is a
  lexical error both front ends already report identically, so
  `tests/extended/optional_refused.pas` is compared rather than skipped — the
  first dialect feature whose refusal needed no change to `src/` at all, where
  ADR-0121's `external` needed six lines.
- **The BSI suite does not see it**, being ISO 7185 and fixed.

## What this does not do

- **No flow-sensitive narrowing.** `if o <> nil then o^` still checks. Swift's
  `if let` and Rust's `match` bind a new name of the unwrapped type; that is a
  dataflow in Sema and a second name-binding form in the grammar, and it is a
  feature of its own.
- **No optional pointers, and `^T` is unchanged.** `?^node` is expressible and
  means "maybe a pointer, which may itself be nil" — two checks, honestly. The
  dialect does **not** make `^T` non-nullable, and cannot: ADR-0117's
  containment means an Extended Pascal program has to keep meaning what it
  meant.
- **No `??T`**, and no optional of a file: one flag answers for a value, two
  answer for each other, and a file is never a value at all (ADR-0021).
- **No returned pointer other than a string.** `?integer` from C has no
  meaning, a returned pointer to a *variable* is a lifetime question this record
  did not open, and a returned struct needs a layout agreement nothing here can
  check.
- **No `errno`**, per the consequence above, so `lib/dialect/pasfs.pas` is
  unchanged and still cannot say *why*.
- **Nothing about the memory-safety model.** ADR-0109's decision is still open.
  What this settles is the *pointer safety* row of `doc/roadmap.md`'s table, and
  it settles it for values the program owns — not for anything reached through a
  foreign pointer that outlives a call.
