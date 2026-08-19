# Roadmap

Where the compiler is, how it got there, and what is deliberately not being
done yet.

## The goal, restated (ADR-0109)

**A Pascal you can get daily work done in**: a dialect and a standard core
library for networking, internationalisation (l10n/i18n/m17n), concurrent
execution, and memory safety as a property of the language rather than a
convention.

Everything below this section was written under the two goals that came before
it — bootstrapping, then conformance — and both are **finished**. The compiler
compiles itself, ISO 7185 is complete, and ISO/IEC 10206:1991 is complete to its
last clause. That history is kept because it explains why the compiler has the
shape it has, and because the conformance modes it produced are not going away:
`--std=iso7185` and `--std=extended` stay exactly as they are, and the dialect
is a third mode beside them (ADR-0033's construction, used a third time).

Four decisions this forces, none of them yet made, each to get its own record:

- **The memory-safety model.** ADR-0019 says use-after-`dispose` is not
  detected; "memory safety first" is incompatible with that sentence. Checked
  pointers with regions, ownership and borrowing, or a tracing collector differ
  in what a pointer *means*. The most expensive decision here to reverse.
- **The text model.** `char` is a byte and nothing consults the locale
  (documented, deliberate). Real i18n needs a wider character type or a text
  type distinct from §6.4.3.3's strings.
- **The memory model.** Pascal has none, and concurrency cannot be specified
  without one. It must be designed *with* the safety model, because shared
  mutable state is where the two meet.
- **How far the C++ reference front end follows** (ADR-0108). It came back one
  commit before this goal changed, on the reasoning that the language was
  finished and slow-changing. Freezing it at the conformance surface is the
  obvious answer and is not the decided one.

What is already in hand and was not built for this: **modules and separate
compilation** (ADR-0053, ADR-0079) mean a standard library needs no new language
mechanism to exist, and `runtime/pasrt.c` is where the outside world already
enters. Those two are most of a library's scaffolding, finished and tested.

### The first increment (done)

`lib/` exists (ADR-0114): three modules — `PasStrings`, `PasSort`, `PasMath` —
in ordinary Extended Pascal, translated as §6.13 program-components and imported
by path. **No compiler change and no third `--std`**, which is the point: a
library module is a §6.11 module, so nothing about what either conformance mode
accepts moved.

It **qualifies the ordering below.** "FFI comes first" is true of the
outward-facing half — sockets, clocks, locales — and was never true of the
inward-facing one, and building that first bought three facts about this
language that no amount of design would have produced:

- **A string argument had to be a variable**, which was the biggest obstacle to
  a usable library and was *conformance* work rather than dialect work. It is
  **fixed** (ADR-0115), in the change after the one that found it: the library
  is what turned a limitation recorded from the compiler's side into one a
  caller could feel.
- **A `forward`-declared function lost its result-variable-specification**, and
  §6.11.1 makes every exported function a `forward` — so an exported function
  accumulated into a local. It was a defect, and is **fixed** (`ab8d125`):
  §6.7.2 puts the result identifier in the block of "the function-block, if
  any", the same words the next paragraph uses of the formal-parameter-list,
  which had always reached a forward body. Recorded as a reading nobody had
  taken and settled by taking it.
- **No generics is survivable by phrasing algorithms over positions.**
  `SortIndexed` takes `less(i, j)` and `swap(i, j)` and never sees an element,
  so one body sorts an array, several parallel arrays, or anything else the
  caller's closures reach.

What it did **not** do: no install location, no resolution by name, no
containers, and nothing touching the operating system.

### The second increment (done)

`PasVector`, `PasMap` and `PasText` (ADR-0116) — a growable sequence, a
string-keyed dictionary, and the splitting, joining and parsing that turns one
string into several and back. Still no compiler change *in the increment*,
though it exposed one: a schema whose component contains a variable-string
stopped the compiler outright, and no program in the corpus had ever written
one, so every oracle agreed it worked. That is the third defect a library has
found and the first that was a crash.

It bought three more facts, and one of them **corrects the table below**:

- **A container cannot use the positions trick.** `SortIndexed` never sees an
  element, so it needs no element type; a container *holds* them, so their type
  is part of its layout. `PasVector` holds integers and the documented answer
  for another element type is to copy the file. This is where "no generics"
  actually bites, and it bites libraries harder than programs.
- **Explicit allocator passing does not survive contact** — the row below,
  rewritten. It was the cheapest thing on the list and is now behind the FFI
  with everything else.
- **A library may not halt**, which is a sharper constraint than it sounds.
  §6.9.1's read of an integer is an *error* when the text is not a number and
  stops the program (ADR-0076), so nothing built on `readstr` can offer "parse
  this if it is a number" — `TryParseInt` inspects the characters itself. The
  same rule decides that `VecNew` clamps a bad capacity and that `MapGet` takes
  a default rather than reporting. **This is the strongest argument yet for
  sum types with payloads**: every routine that can fail currently invents its
  own ad-hoc shape, and there are already two.

What it still did **not** do: no install location, no resolution by name, no
error-handling convention, no second element type, and nothing touching the
operating system.

### The third increment: the dialect opened, and closed a hole it opened

`--std=afterschool` (ADR-0117) and its first feature, a variant tag that cannot
lie (ADR-0118). Both were built against the argument above — a library may not
halt, so every routine that can fail invents its own shape — and neither
changed what the conformance modes accept.

It bought one more fact, and it was found by probing rather than by reasoning:

- **A safety rule emitted at the access belongs to a compilation unit, not to a
  type.** ADR-0118's two rules are a pair, and §6.13's separate translation let
  them be split across program-components built under different modes. The
  surviving half then ran its check against a tag the other half never stored
  and *passed* the access — a check answering `safe` for an unsafe read, which
  is worse than the documented gap it replaced. ADR-0119 refuses the mixture at
  the link.

  It also **decides the next question rather than leaving it open**: a library
  cannot be a dialect layer under conformance-mode callers. If a dialect
  library is wanted it is dialect all the way down — separate modules, dialect
  callers — and `lib/` as it stands is Extended Pascal and stays usable by any
  conforming program. That is not the decision ADR-0118 parked; it is the
  removal of the option that would have been unsafe.

### The fourth increment: the library grew a second layer

`lib/dialect/` (ADR-0120) — the result shape, and the answer to the finding the
first three increments kept producing. A fallible routine answers one record
carrying the value or the reason, the tag is set by writing the payload, and a
caller who does not check traps instead of reading a stale value.

It settles the question ADR-0118 parked, and it settles it *against* rewriting
`lib/`: those modules are the only Pascal here a reader can take away to another
ISO/IEC 10206:1991 processor, which is worth more than the safety, and making
the dialect's first user its only user would have been the wrong shape for
something that has to earn its keep against a specification.

Two facts came out of building it, and both are about the wall rather than the
feature:

- **A result shape cannot be a library type.** With no generics the payload type
  is part of the layout, so each producing module declares its own record and
  what is shared is `ErrorCode` and the spelling of the tag. ADR-0116 hit the
  same wall from the container side; twice from different directions is worth
  recording before anyone proposes generics as a convenience.
- **Two layers duplicate, and there is no way around it.** `ParseInt` trims its
  own input because ADR-0119 will not link `PasText` into a dialect program.
  That is the containment being enforced rather than promised, and the cost is
  paid in copies.

It also turned up a defect nothing in the corpus could reach: a module imported
and *not used* was activated and never declared, so the program did not build.
Present since ADR-0053. Every `--import` in the tree had used what it named,
which is the shape of gap this project keeps finding — a claim no program writes
is a claim nothing checks.

### The fifth increment: the enabler, in its narrowest form

`external` (ADR-0121), under `--std=afterschool` only. Everything above needs
to call code this compiler did not emit, and until this the only route was a
hand-written `pas_*` primitive in `runtime/pasrt.c` — right for the twenty-odd
things the standards require, and no way to reach a socket.

The blocker recorded one increment ago is what made it possible: a syscall
wrapper is a routine that can fail, and ADR-0120 gave the language a shape to
say so in. The blocker recorded *below* is not solved — an FFI is a hole in
every safety property, and the memory-safety model is still open — so the
boundary is made **lexically visible** instead, which is the answer the table
below already said was most likely to fit. A directive prejudges nothing.

Three facts came out of it, and two are about how little is checked:

- **The type mapping is an ABI question and was probed, not reasoned.**
  `integer` and `real` cross, and they are exactly the two `clang` passes with
  no parameter attribute — a `char` is `i8 signext` and disagrees with
  §6.4.2.2's 0..255 about the sign bit, a `bool` is `i1 zeroext` as a `_Bool`.
  Two rows of a four-row table, and the other two are the next increment.
- **The `declare` is not the ABI; the call site is.** Giving the foreign
  declaration a static link it does not have assembles, links and runs
  correctly — LLVM does not check a *direct* call against the declaration under
  opaque pointers. So nothing anywhere checks a foreign signature, which is
  what an FFI is without a header parser.
- **A foreign name can collide with one the compiler emits**, and LLVM answers
  with an error about a file nobody wrote. Refused as a diagnostic now, and
  `hypot` and `atan2` are unavailable to a program because `complex` uses them
  — the one place the rule bites something a user would want.

What it does **not** do is the whole of what comes next: no pointers, no
strings, no `var` parameters, no callbacks, no way to name a library. Every one
of sockets, locales and clocks needs the first two.

### The sixth increment: the pointer, on the side that has no lifetime

ADR-0122, and it is the increment this file said might have to be designed
together with the memory-safety model. It was not, and the reason is a
distinction the sentence below already contained: *a pointer* outlives the
call, and **an argument does not**.

A `var` actual and a string actual are storage the caller owns and outlives, so
the lifetime is settled before any model is chosen. A returned `char *` is the
callee's or nobody's, and is blocked twice — once on ownership, and nearer than
that on **null**, which `getenv` answers in the ordinary course of things and
which needs the *optional type* row of the table below rather than the
memory-safety row. So an address crosses only as an argument.

`string` in an `external` heading means `const char *` and is not a schematic
formal; the copy goes in ADR-0111's arena, which already had exactly the
lifetime wanted for reasons that had nothing to do with C. That is why the
increment is small. A NUL inside the value traps, which is the one safety
property it adds rather than makes visible.

Two things it deliberately did not take:

- **A buffer** — `var b: packed array of char`, what `read` and `snprintf`
  want. Not a lifetime objection: it is a pointer *and* a length, and the
  length is not in-band the way a C string's is. That is the **slices** row of
  the table below, and it is a language decision. Admitting it here would
  invent a fifth spelling of the two-scalar shape at the one place nothing can
  check it.
- **A callback.** The static link is the half of a procedural value with no
  image at all in C, and a Pascal procedure without one is a different feature.

And one thing it could not: **`errno`**. glibc spells it
`*__errno_location()`, so it is a pointer result, so `lib/dialect/pasfs.pas`
answers `errIO` for every failure and cannot say which. The first thing the
next increment buys is the ability to say which.

### The seventh increment: the type null needed

ADR-0123, and it is the first of ADR-0109's four open decisions to be settled —
the **optional** row of the table below, not the memory-safety row. `?T` is a
value of T or nothing; `nil` is the absent value, `= nil` the test, and `o^` the
only way to a value, checked exactly as §6.4.4's dereference already is.

It is here because the increment before it stopped at a wall that was not about
memory at all. A returned `char *` may be null, and null is not a failure —
`getenv` of a name that is not set answers it on purpose — so trapping would
stop a program on a normal answer and the empty string would conflate "not set"
with "set to nothing". The language simply had no way to say "there may be
nothing here", and every fallible thing built so far had invented its own:
ADR-0120's record carries a *reason* as well, `MapGet` takes a `whenAbsent`
argument, `TryParseInt` writes through a `var`. Absence with no reason is the
commonest case and had the least support.

Four things are worth carrying forward:

- **The lexis cost nothing, again, and by a different route.** `?` is a
  character neither standard admits anywhere, so nothing that compiled stops
  compiling and the reference front end needed **no** teaching at all — it
  already said `unexpected character '?'`, where ADR-0121's `external` needed
  six lines in `src/`. A syntax made of a character no standard uses is cheaper
  than one made of an identifier.
- **The guarantee is the refusal, not the check.** Nothing is assignable *from*
  an optional — two lines in `Assignable` — so a `T` that is not optional can
  never be absent, and eight of the twelve refusals in the test file come from
  diagnostics that already existed. Refusal by construction paid here more than
  anywhere since ADR-0058.
- **No C pointer becomes a Pascal value.** The copy is made at the call site, so
  the program holds a string of its own and the pointer is dead by the end of
  the statement. The capacity is required and is §6.4.6's check, in §6.4.6's
  words.
- **The blind spot decided an interface.** `lib/dialect/pasenv.pas` refuses to
  bind `putenv`, which keeps the pointer it is handed — the hazard
  `doc/sop.md` §7 records against ADR-0122 — and binds `setenv`, which copies.
  That is the first time a registered gap has changed what gets built rather
  than only being written down beside it.

And writing it found a defect ADR-0122 had shipped: two `string` parameters in
one group of an `external` heading were held to §6.7.3.3's one-tuple rule,
which is not about them. `strcmp('b', 'ab')` had been refused since that
increment, and nothing asked because every call in the corpus passed actuals of
equal length.

### The eighth increment: the bounds travel with the pointer

ADR-0125, and it is the **slices** row of the table below — "a pointer and a
length; excellent, and already the house style" — which this file predicted
correctly and for the right reason.

It was deferred to by name: ADR-0122 refused a buffer at the foreign boundary
because "it is a pointer *and* a length, and the length is not in-band … that
is the slices row, and it is a language decision, not an FFI one." So it was
built as a language decision, and it has a reason that does not mention C at
all: Extended Pascal gives a string a substring and gives an array nothing.

Three things it confirms about how this dialect grows:

- **The lexis has now cost nothing three times, by three different routes.** A
  directive (ADR-0121), a character no standard admits (ADR-0123), and a
  *combination* of two reserved words that no standard's grammar allows —
  §6.4.3.2 requires a bracketed index-type, so `array of T` is a syntax error
  in both. Looking for the spelling a standard has already left free is the
  cheapest design move available here.
- **"Ask the symbol, not the syntax" paid for most of the increment.**
  `a[i..j]` is §6.5.6's substring designator and was already parsed; only the
  base's *type* decides which construct it is. The parser was not touched for
  it.
- **Confining a feature to an argument worked a third time.** ADR-0122 found
  that an argument has no lifetime question; a slice that cannot be stored in a
  variable, a field or a result cannot outlive the array it views. Three
  increments have now taken that shape, and it is worth stating as a pattern:
  where a feature's danger is *lifetime*, confining it to an argument removes
  the danger without deciding anything about ownership.

And a probe reshaped what comes next. `clang` on this target:

    declare i64 @read(i32, ptr, i64)
    declare i64 @write(i32, ptr, i64)
    declare i64 @recv(i32, ptr, i64, i32)

Every length is `size_t` and every one of them *answers* `ssize_t`. A slice
could cross with an `i64` length without difficulty, the compiler generating
that word — but the result cannot be received, this language's `integer` being
`i32` with nothing wider. **So the data path needs two things and this is one
of them**; shipping the buffer argument alone would have put a knowingly wrong
ABI in the tree for a call that cannot say how many bytes it moved.

### The ninth increment: the half the probe named

ADR-0128, and it is the increment ADR-0125's closing probe wrote the
specification for. `clang` on this target declares `read`, `write` and `recv`
as taking an `i64` length and *answering* `ssize_t`; a slice could cross with
that length, and the result could not be received. `int64` is the half that
answers.

It is the first dialect feature whose constraint is the **compiler** rather
than a standard, and the constraint decided the design twice over.
`selfhost/compiler.pas` is written in this language, so its own integers are 32
bits: there is no value of the wide type anywhere in the compiler to fold with,
compare, or put in a constant.

- **So a value is carried as text**, all the way into the IR. That is ADR-0025's
  answer for a real literal, arrived at again one clause later and for the same
  sentence: LLVM's assembler is what reads the digits, and nothing this compiler
  converts can be converted wrongly. `Int64TooLarge` compares *text* against the
  limit, because neither side of that comparison is a number it could hold.
- **And it is numeric rather than ordinal**, which is one line — `IsOrdinal`
  answers no — and thirteen refusals that needed no message of their own. Every
  construct that refuses it is one that needs the compiler to *hold* the value,
  so the line is forced as well as preferred.
- **`verify/` proved the wide lowering by running the rules it already had.**
  The model was written generic in the width, so `WIDE = (32, 64)` establishes
  the emitted code at its real width rather than a second family of rules
  restating the first. Worth recording as a property of how that catalogue was
  built: a model written symbolically pays a second time, years later, for a
  type nobody had in mind.

**The lexis cost something, for the first time in four increments.** A
directive, a character no standard admits, a combination of two reserved words
— three routes to a free spelling, and there is no fourth for a *type*.
`int64` is an identifier, available only because §6.2.2.10 makes a required
identifier shadowable rather than reserved. That is a weaker kind of free, and
it is why the containment test grew a paragraph rather than being left alone.

### The tenth increment: the shape decision, and it had no mechanism left

ADR-0129, and it is the first increment here whose whole content was a choice
between two things that both worked. The entry that stood in this place named
them: a slice crossing as its address alone, with the program passing the
count, or as the pair `(ptr, i64)`. It went to the pair, and the reason is not
the one this file gave.

This file said the pair was "more useful and assumes a convention" and that the
address alone "assumes nothing and puts the count in the program's hands". That
second half was the wrong way round. **Putting the count in the program's hands
is the C hazard**, and it is the one ADR-0122 refused to reintroduce at the one
place nothing can check anything: a length travelling separately from its
pointer is a length nothing relates to the storage. `PosixRead` has two
parameters where `read(2)` has three, and the count C receives is one the
compiler computed from the designator and checked against the array. A buffer
overrun is not something a caller can spell.

Three things came out of building it:

- **A rule with a side gets read twice.** ADR-0121 admitted a type by testing
  it rather than `Base(t)`, and argued it as *passing a subrange is sound,
  returning one is not*. A slice is storage the callee **writes**, so every
  component sits on the returning side of that argument — which decided the
  component list without a new principle. `char` then came in for the mirror
  reason: it is refused *by value* over `i8 signext`, an objection about the
  register convention, and in memory the type has no bit pattern that is not a
  value of it. That property — and not "a byte is a byte" — is what makes a
  component safe for a routine this compiler did not emit to write into.
- **Two mutations survived, and both are ADR-0121's registered gap seen
  again.** Writing `ptr` where `ptr, i64` belongs, so the declaration and the
  call disagree about *arity*, assembles and runs; so does dropping the `sext`
  and passing the count as an `i32`. The first is the gap recorded for
  parameter types, now confirmed for arity — the `declare` is documentary. The
  second is right for a reason no program here can exhibit, both target
  architectures zeroing the upper half of a 32-bit register write. Both are in
  `doc/sop.md` §7 rather than claimed as covered.
- **The prediction this file made about slices held a second time.** The
  "already the house style" row was written about a language feature; the same
  two words are now what an operating system takes, with no adapter between
  them. That is the sixth thing here travelling as two scalars and the first
  where the far side chose the shape.

### The eleventh increment: the library, and the streak that ended

ADR-0130 and `lib/dialect/pasio.pas` — descriptor I/O on ADR-0129's buffer,
answered the way every fallible thing in the second layer answers. It closes
the entry that stood here.

**Its result is that there was no result**, and that is what the record is for.
Four library increments in a row found a compiler defect nothing else could
see — ADR-0114 a string argument that had to be a variable, ADR-0116 a schema
holding a variable-string that stopped the compiler outright and a `forward`
function that lost its result variable, ADR-0120 a module imported and not
used that never linked. This one found nothing, and not for want of asking: a
slice reached `write` from a global, a record field, a schema-bounded array, an
enclosing procedure's local through the static chain, a `with` binding, a `var`
parameter sliced by two expressions, a slice of a slice, an empty slice and an
`array of int64`. Every one behaved.

The narrow reading is the right one. ADR-0129's feature is built out of
ADR-0125's, which arrived with a corpus, and confining it to an argument kept
it away from everything that has a lifetime. It says nothing about the rest of
the FFI: the two mutations ADR-0129 recorded as surviving still survive.

What the library *did* find is about the library, and both were caught by
mutation rather than by running it:

- **`AtEnd`'s first conjunct is load-bearing and was untested.** `r.ok and
  (r.count = 0)` is safe because `and` short-circuits, so `r.count` is never
  read on a result whose tag says there is none. Dropping `r.ok` passed the
  whole suite until a case asked `AtEnd` of a *failed* result — then it traps
  with *variant: the tag selects another arm*. ADR-0118's rule and §6.7.2's
  short-circuit holding each other up, and invisible along the successful path.
- **`WriteAll`'s retry branch cannot be reached from a test here.** A short
  write needs a descriptor that takes fewer bytes than it was handed; a regular
  file never does and a pipe blocks rather than truncating. Its failing exit is
  covered, the retry is not, and that is written down rather than left.

### The twelfth increment: the wall was a misdiagnosis

ADR-0131, and it closes the entry that stood here — the one three records in a
row had closed by naming. **The reason every one of them gave was wrong.**

They said `errno` is unreachable because glibc spells it
`*__errno_location()`, a function returning `int *`, and a returned pointer is
what ADR-0122 does not admit. True, and a detail of one C library. The reason
that matters is in the language: **C specifies `errno` as a macro.** It has no
linker symbol, so no foreign-function interface can bind it — not this one,
not a better one, not one with a header parser, which would read the macro and
still have nothing to call. So it was never blocked on ADR-0109's
memory-safety model at all, and the thing it was waiting for is the oldest
mechanism here: `runtime/pasrt.c`, which is where anything not expressible in
the emitted IR has always gone.

Three things worth carrying forward:

- **The runtime now has two surfaces, and the prefix is the decision.**
  `ReservedForeignName` refuses the whole `pas_` prefix and is right to — those
  are names the emitted module declares, and LLVM will not take a second
  declaration. A routine the emitter *never* names is not that hazard, so it
  gets `pasx_` and a program binds it. That keeps the predicate a mirror of the
  emitter rather than a list of exceptions, which is the property
  `foreign-reserved` fails in both directions to hold.
- **`strerror` needed nothing.** It answers a `char *` and ADR-0123's optional
  string already receives one, with the copy made at the call site. The half of
  this increment that looked hardest was already paid for.
- **A wall recorded three times is worth re-deriving once.** Each record
  restated its predecessor's reason rather than the clause behind it, and the
  restatement was cheaper to believe than to check. The same shape as
  ADR-0067's `pack` and `page`: three documents asserting something no probe
  had been written for.

### The thirteenth increment: half of "every returned pointer" was never blocked

ADR-0132, and like the increment before it the finding is that a recorded
blocker was one sentence covering two unlike things.

"Every returned pointer that is not a string" ran together **a pointer to
storage the callee owns** — `getenv`'s, `strerror`'s, where whose it is and
how long it lives are real questions ADR-0123 answered by copying at the call
site — and **a pointer to storage the caller just lent it**. `getcwd` answers
the buffer it was handed, or null. There is no ownership question in that at
all: the storage is the caller's, it outlives the call by construction, and
the pointer is a success flag with an address attached.

So `WorkingDirectory` and `LinkTarget` needed **no compiler change and no new
mechanism**. Three things already in the tree met: ADR-0129's slice lends the
buffer and supplies two C arguments from one formal, ADR-0123's optional
receives `getcwd`'s result, ADR-0128's `int64` receives `readlink`'s
`ssize_t`.

That is the same distinction ADR-0122 drew for the argument side — "a pointer
outlives the call, and an argument does not" — applied to a result that is an
argument coming home. **Three increments in a row have now found that a
decision described as needing the memory-safety model needed it for only part
of its surface**, which this file already wrote down once as a lesson and has
now had to learn a third time.

One thing it adds to the register rather than to the language:

- **Binding a C interface produces guards for cases the platform cannot
  currently produce.** `LinkTarget` reports `errFull` when `readlink` fills the
  buffer exactly, because there is no terminator and truncation cannot be told
  from a target that just fits — and that arm is unreachable, `MaxPath` being
  Linux's `PATH_MAX` and the kernel refusing to create a longer target. Third
  in three increments, after `WriteAll`'s retry and `ErrorNumberText`'s null.
  They are correct to write and impossible to test from here; the honest
  treatment is to say which branch and why, not to delete the guard so the
  coverage reads better.

### What is still blocked on it

**A pointer to storage the callee owns whose contents are not characters**, and
it is now two things rather than a category:

- **An opaque handle** — `DIR *` from `opendir`, `FILE *` from `fopen`. No
  layout has to be agreed; it is a token to hand back. What it needs is a
  *lifetime*, and Pascal has a precedent worth using: a file variable is a
  handle whose lifetime a block manages, and ADR-0021 and ADR-0032 already
  close files at block exit and on a non-local `goto`. This is the cheapest
  thing left and the first that genuinely touches ADR-0109's open decision.
- **A struct with a layout** — `struct sockaddr`, `struct stat`. Unlike a
  handle this needs the compiler and C to agree about offsets, which nothing
  here does for a foreign type. It is what stands between here and a socket.

**Creating a file**, which is not a language question at all — `O_WRONLY`,
`O_CREAT` and `O_TRUNC` are header numbers, and the policy PasFS set and PasIO
kept is that a number the module cannot check does not go in. What would lift
it is something that reads a C header, which is a different project.

**The rest of the FFI**, and the ordering has not changed — it is the narrowness
that moved, not the position.

Three things this file expected to make it cheap did, and are spent:

- **The calling convention already existed.** The compiler emits textual LLVM
  IR and already called C functions by name with C types — every `write` is
  one — so what was missing was a language surface and not a mechanism.
- **The grammar already had the shape.** ISO 7185 §6.1.4 and
  ISO/IEC 10206:1991 §6.1.4 make `forward` a **directive**, an identifier in
  the one position it may occupy, and ADR-0053 had noted that §6.1.5's
  `interface` and §6.1.6's `implementation` are directives too. `external` cost
  the lexis nothing, exactly as predicted.
- **Modules gave it somewhere to live** (ADR-0053, ADR-0079). A binding is a
  module that exports Pascal and keeps the directive to itself, and nothing
  about separate compilation changed. `lib/dialect/pasmathx.pas` is the first.

**The real work is still the type mapping**, and two rows of it are done. What
a C `char *`, `size_t` or struct pointer is in Pascal — and which Pascal types
may cross at all — is the whole of what stands between here and a socket, and
it cannot be settled the way `integer` and `real` were, by observing that the
ABI needs no attribute. A pointer crossing the boundary is the memory-safety
question in its smallest form:

- **It is a hole in every safety property the goal asks for.** A foreign call
  can do anything. ADR-0121 answered that for a *call* by making the boundary
  lexically visible — Rust's and Zig's answer, and the one this table already
  said was likeliest to fit — and that answer does not extend to a pointer,
  which outlives the call.

  **The paragraph above expected the next increment and the memory-safety model
  to be designed together, and they were not.** ADR-0122 found that the
  argument side of the boundary has no lifetime question on it at all — the
  caller owns the storage and outlives the call — so half of what was blocked
  here was never blocked on a model. ADR-0123 then took the other half's
  nearest blocker, which was **null** rather than ownership, and a *string*
  now comes back: the copy is made at the call site, so nothing the program
  holds is a foreign pointer.

  What is left is every returned pointer that is not a string — a buffer, a
  struct, and `errno`, which is `*__errno_location()` and a macro besides. Two
  estimates in a row were wrong in the same useful direction, and the lesson is
  worth keeping for the rows below: **a decision that looks like it needs a
  model may need the model for only part of its surface**, and the part that
  does not is usually worth taking first.

### Where the ideas come from

Rust, Swift and Zig are the reference points, and the honest position is that
they do not all fit equally. Pascal's grain is value semantics, explicitness and
a small orthogonal core; that is close to Zig and Swift and further from Rust.
Each borrowing below is tied to the open decision it would settle.

| Idea | From | Settles | Fit here |
| --- | --- | --- | --- |
| **Slices — a pointer and a length** | Zig, Rust | bounds safety | **Done** (ADR-0125), and the prediction held: `array of T` is that shape a fifth time and needed no new mechanism. What the row did not anticipate is how much of it §6.5.6 had already paid for — `a[i..j]` is the substring designator, and only the base's type tells the two apart, so the parser was untouched. Argument-only, so bounds safety is settled without the memory-safety decision. **ADR-0129 then carried it across the foreign boundary**, where the same two words are what `read`, `write`, `recv` and `send` take — the first time the far side of a design chose the shape rather than this project choosing it |
| **Explicit allocator passing** | Zig | part of memory safety | **Tried, and it does not survive contact** (ADR-0116). An allocator *record* is not expressible — a record field may not have a procedure type, neither standard having general procedure types. A per-type allocator *parameter* is, and compiles; but `new` is the only origin of a typed pointer and there is no pointer arithmetic or cast, so it can only recycle blocks `new` produced rather than carve one into several. And the capacity it serves is unchecked: a pool asked for 9 may return a block of 4, whose own discriminant then answers `p^.cap`. Not unsafe — the bounds check reads the served block — but the central contract is unenforced. **This needs the FFI too**, which moves it from "cheapest on the list" to behind the same gate as everything else |
| **`defer`** | Zig, Swift | resource safety | **Good.** Pascal has no early return, so a block already has one exit and the epilogue is already where files close (ADR-0021, ADR-0032). `defer` generalises a mechanism that exists |
| **Error unions / `Result`** | Zig, Rust | error handling | **Good, and the biggest practical gap.** Pascal has *no* error handling — no exceptions, no result convention. It needs sum types with payloads, which variant records nearly are. Independent of the memory-safety fork, so it can proceed while that is open |
| **Optionals, and no bare null** | Swift, Rust | pointer safety | **Done, and half of the description was wrong** (ADR-0123). `?T` exists, `nil` is its absent value and `o^` is the only way to a value. What it does *not* do is make the check a type question instead of a run-time one: `o^` still traps, as Swift's `!` does, and flow-sensitive narrowing (`if let`) is a Sema this has not built. What the type gives is that a `T` which is not optional can never be absent, so the check is **localised** to where the source writes `^` rather than eliminated. And "no bare null" is unavailable in the second half of its name: ADR-0117's containment means `^T` has to go on meaning what Extended Pascal says it means |
| **Unicode-correct `String`** | Swift | the text model | **The model to copy.** Swift's is the best-considered answer to "what is a character" in any mainstream language, and the question is exactly the one ADR-0109 leaves open |
| **ARC** | Swift | memory safety | **Plausible.** Needs retain/release in CodeGen and a runtime, but no borrow checker, no lifetime inference, and stays self-hostable and cheap to mirror in `src/` |
| **Ownership and borrowing** | Rust | memory safety | **Strongest guarantee, worst fit.** Lifetime inference is a large Sema, the most expensive thing here to mirror in the C++ front end (ADR-0108), and the furthest from anything recognisably Pascal |
| **Traits / protocols** | Rust, Swift | abstraction | **Later.** Schemata already give parametric types (ADR-0039); this is the next layer, not the first |
| **`comptime`** | Zig | metaprogramming | **Later.** ADR-0054 gave the language constant-expressions everywhere; `comptime` is a much larger idea and nothing yet needs it |
| **Actors / `Send`+`Sync`** | Swift, Rust | concurrency | **Blocked**, and rightly: it cannot be designed before the memory model, and the memory model cannot be designed before the safety model |

Two conclusions worth stating rather than leaving implicit:

- **The cheap items are not the small ones.** Slices, an allocator convention,
  `defer` and error unions between them cover most of what "daily practical
  development" means, and none requires settling the memory-safety fork.
- **ARC and borrowing are not equally costly here**, and the difference is not
  only implementation effort. Borrowing would make ADR-0108's C++ mirror
  prohibitively expensive and would likely force the decision to freeze it —
  so the safety choice and the oracle question are the same question asked
  twice.

One option **closes** as the language diverges: a third-party differential (FPC
under `-Miso`, or p5) can only ever check the ISO 7185 core, because nobody else
implements this dialect. Worth spending while it is still worth anything.

**The bootstrap has closed** — the compiler compiles itself and stage 2 equals
stage 3 — so the question this file used to answer, what is left before it can
compile itself, is answered. What it tracks now is the second standard.

Two orderings, and the second replaced the first. During the bootstrap it was
not ISO 7185's chapter order but the order a *compiler* needs its features in:
procedures, then the data structures an AST is made of, then the I/O that reads
source and writes IR (ADR-0004). That priority expired when the language
finished being a means to an end: since then a feature needs no reason beyond
the standard having it, ISO 7185 was completed on those grounds, and
ISO/IEC 10206:1991 is being worked through the same way.

**Where things are.** Everything above "What is next" is now history: both
standards are complete, the sweeps have been run, and the bootstrap stands on
its own. The live work is that last section, and most of it is not about the
language.

- [The three-stage build](#the-three-stage-build)
- [The six bootstrap items](#the-six-bootstrap-items-all-done) — with
  [text files](#item-5--text-files-done) and
  [character strings](#item-6--character-strings-decided) written out
- [Stage 1](#stage-1-done) — the port, and
  [what it taught](#what-the-port-taught)
- [Known limitations](#known-limitations) —
  [ISO 7185](#under-iso-7185) and
  [ISO/IEC 10206:1991](#under-isoiec-102061991)
- [Beyond self-hosting](#beyond-self-hosting) —
  [what ISO 7185 had left](#what-iso-7185-had-left)
- [Stage 2 — ISO/IEC 10206:1991](#stage-2--isoiec-102061991) —
  [how it arrives](#how-the-second-standard-arrives),
  [the features](#the-features-in-the-order-they-landed),
  [what is left](#what-is-left)
- [Conformance sweeps](#conformance-sweeps) — what was checked rather than
  asserted, and what that found
- [The two things that were not features](#the-two-things-that-were-not-features)
- [What is next](#what-is-next) — the oracle that was given up, and the four
  other things worth doing; measuring what the corpus reaches is done

## The three-stage build

```
seed      seed/pascalc.ll        — a working compiler, in IR, committed here
stage 1   pascalc1 = seed(compiler.pas)        this is build/bin/pascalc
stage 2   pascalc2 = pascalc1(compiler.pas)
stage 3   pascalc3 = pascalc2(compiler.pas)      require pascalc2 ≡ pascalc3 byte-for-byte
```

**The comparison now holds.** `selfhost/irtest.sh` runs all three stages under
ctest and requires stage 2 to equal stage 3; they are compared as IR rather than
as binaries, because IR is what the Pascal compiler emits (ADR-0025).

Stage 0 only had to be good enough to compile the Pascal-written compiler
*once*, which is why the feature list grew in the order it did rather than the
standard's. For as long as it existed, both compilers grew together — a feature
landed in C++ and in `selfhost/compiler.pas` in the same commit, because the
differential test compared them on every file in the tree. **That is what
retiring it ended** (ADR-0085): a feature is now written once.

The stage-2 ≡ stage-3 comparison is the whole point, and it does not depend on
what started the chain: stage 2 is built by a compiler the seed built, stage 3
by one that stage 2 built, and both come from the same source. The bytes match,
so the Pascal source is a fixed point.

## The six bootstrap items (all done)

| # | Feature | State | Record |
| --- | --- | --- | --- |
| 1 | Procedures and functions | **done** — nested to any depth, recursive, value and `var` parameters, `forward` | [ADR-0016](adr/0016-nested-procedures-use-static-links.md) |
| 2 | Arrays and records | **done** — any ordinal index, multi-dimensional, `packed`, nested, `with`, bounds-checked | [ADR-0017](adr/0017-structured-types-use-name-equivalence.md) |
| 3 | Enumerations, subranges, `case` | **done**, with the variant records they unlock | [ADR-0018](adr/0018-ordinal-types-and-variant-records.md) |
| 4 | Pointers, `new`/`dispose` | **done**, with the forward-referenced domain that makes a recursive type possible | [ADR-0019](adr/0019-pointers-and-the-only-forward-reference.md) |
| 5 | Text files | **done** — `reset`, `rewrite`, `read`, `readln`, `eof`, `eoln`, and the buffer variable with `get`/`put` | [ADR-0021](adr/0021-text-files-keep-the-buffer-variable.md) |
| 6 | Character strings | **decided** — a length-plus-buffer record, no extension; the `string` type arrived later, with the second standard | [ADR-0012](adr/0012-character-strings-for-self-hosting.md), [ADR-0051](adr/0051-a-string-value-is-a-pointer-and-a-length.md) |

Items 1–4 mean the AST of a self-hosted compiler is now *expressible*: the node
kind is an enumeration, the node is a variant record, and the tree is heap
allocated through a recursive pointer type. `tests/pointers.pas` builds exactly
that shape as a proof by construction. Item 5 means it can now read its input
and write its output, so **every structural prerequisite for stage 1 is in
place**.

Item 6 is a decision rather than a feature, and it is now made, so **the
language was finished for bootstrap purposes** at that point: what remained was
writing the Pascal, not growing what it is written in. That writing is done
too — see "Stage 1", below — and everything since has been conformance.

Alongside the language, 550 ctest cases — the Pascal programs of `tests/` and
`tests/extended/`, the error-path corpus of `selfhost/badparse/` and
`selfhost/badsema/`, the verification run, the bootstrap and the product check —
and 44 SMT rules, 28 of them for all 2³² inputs and 16 at bounded
width, with no known gaps.

### Item 5 — text files (done)

Delivered as ADR-0021. The two decisions worth remembering:

- **The buffer variable is real.** `f^`, `get` and `put` exist, and `read` and
  `write` are derived from them in the runtime the way ISO 7185 §6.6.5.2
  derives them. The apparently redundant primitive is one character of
  lookahead, which is exactly what the lexer at the head of the port is written
  against.
- **Program parameters bind to the command line**, in the order written, with
  `input` and `output` as the standard streams. §6.10 leaves the binding to the
  implementation, so this is the kind of choice that becomes folklore unless it
  is written down.

Two SMT rules came with it, both about `pas_read_int`'s digit accumulator —
the one place the file code computes a number that could be computed wrongly.
Everything else about files is a state property and is covered by tests, one of
which (`files_scratch.pas`, three thousand scratch files) fails by exhausting
the descriptor table if block exit ever stops closing files.

### Item 6 — character strings (decided)

Settled as ADR-0012: a length-plus-buffer record in strict ISO Pascal, no
extension, ADR-0002's conformance untouched. That record named the one thing
that would expire the decision — committing to Extended Pascal, which defines a
`string` type of its own — and it has since expired: ADR-0051 landed §6.4.3.3's
required schema. What follows is why the record shape was still right for a
compiler written in ISO 7185, which is what `selfhost/compiler.pas` is.

What settled it was measuring the existing compiler rather than reasoning about
the language. The record's own earlier warning — that strict ISO would cost
"every line that touches text" — turned out to be **wrong**:

- A compiler *reads text in and writes text out*; it rarely manipulates it. Of
  164 string concatenations in the C++ source, nearly all build a diagnostic or
  an LLVM label, and both are written — so in Pascal they become `write` calls
  and need no string to exist at all.
- Exactly one function returns a built-up string (`Type::name()`), and its
  Pascal form writes directly instead, which is what a text-emitting backend
  wants anyway.
- Diagnostics are never sorted, so a message can be written the moment it is
  produced and never stored.
- What must be stored is bounded and small: identifiers, the literals of the
  program being compiled, and about sixty padded entries in fixed tables.

`tests/bootstrap_strings.pas` is the evidence rather than an illustration —
the record, the lexer's accumulate-a-word loop, keyword matching against padded
literals, a symbol table interning by comparison, and IR emission — compiling
and running against the compiler as it stands.

## Stage 1 (done)

Nothing in the language was blocking, and these went in this order:

1. ~~**Port the lexer.**~~ **Done** (ADR-0022) — checked *at the time* against
   the C++ lexer on every Pascal source in the tree by `selfhost/difftest.sh`.
   Both are gone (ADR-0085), which is why that record is the one marked
   superseded: its decision was "not against a golden file", and goldens are
   what pin the lexer now.
2. ~~**Port the parser and the AST.**~~ **Done** (ADR-0023) — the bootstrap
   constraints paid: the `NK` tag became a variant record's tag and `as<T>()`
   became the `case` that reads it, with no cleverness needed.
3. ~~**Port Sema**, including the type arena.~~ **Done** (ADR-0024) — and with
   it the stage-1 sources merged into one `selfhost/compiler.pas`, because ISO
   has no include mechanism and a third program would have carried a third copy
   of the lexer. It dumps every stage in one pass, against `--dump-all`; 434
   files agree stage for stage today — every `.pas` in the tree, which is what
   the number tracks and why it moves with the corpus rather than with the
   port.
4. ~~**Port CodeGen against textual IR.**~~ **Done** (ADR-0025) — ADR-0006's
   path. The C++ backend still uses the LLVM API; the Pascal one prints `.ll`
   and `clang` assembles and links it. Binding the LLVM-C API from Pascal
   remains possible and remains off the critical path.

**Stage 1 is complete, and the bootstrap closes**: the compiler compiles itself,
and stage 2 and stage 3 are identical.

**Differential testing was the checkpoint**, and it did come before stage 1 was
declared working: the first three components are compared against the C++ ones
stage for stage, on every file in the tree, and each was merged into the same
program and dumped in the same pass rather than getting a harness of its own.
The fourth could not be — two backends' assembler text is not comparable, since
LLVM's printer is not a specification — so it is checked against the golden
output of the programs it builds instead, and then against itself.

The harness is only worth what its corpus reaches, and that has to be
*counted*, not assumed. **Every time it has been counted, something turned out
to be uncompared.** No file contained a tab, so the lexer's control-character
class was never exercised (ADR-0022). No file produced a parser diagnostic, so
all 43 message contexts and 61 token spellings were unchecked (ADR-0023). Sema
reached 48 of its 85 messages before `badsema/` was written (ADR-0024). Then
sets (ADR-0028), congruity (ADR-0030), non-text files (ADR-0031) and the
non-local goto (ADR-0032) each had mutations survive a green suite until their
corpus was extended. Every one was found by mutating the source and noticing
that nothing went red.

Those records disagree about *which* time it was — two of them say "the fourth"
and two say "the sixth". That is what a running tally across records that are
immutable once accepted does, and it is why the count is not kept here either:
the number was never the point, and the list above is.

### What the port taught

Three things the lexer port learned, which the next components will meet again
(ADR-0022):

- ISO's file model gives **one** character of lookahead and the lexer needs
  **three**, so a window over the buffer variable is unavoidable.
- The overflow check must precede the multiply: this compiler traps rather than
  wrapping (ADR-0014), so the C++ habit of converting in a wider type and
  comparing afterwards is not available to its own source.
- Pascal has no early return and no way to discard a function result, which
  changes how guards and character-consuming helpers are shaped.

Four more from the parser (ADR-0023):

- **A vector becomes a sibling list**, and the one place it shows is where the
  C++ walks a vector *backwards* (`with a, b do S`), which a list cannot.
- **The one exception becomes a flag.** No exceptions, and no `goto` in this
  compiler, so `aborted` is tested by every loop — where a forgotten test is an
  infinite loop rather than a wrong answer.
- **Field identifiers must be distinct across every variant** (§6.4.3.3), so
  the arms of the node type cannot all call their operand `base`.
- **Reading a function's own name is a call** (§6.8.2.2), so a node under
  construction cannot live in the result variable. `f^.field := v` compiles and
  recurses forever; only `new(f)` is caught.

And four from CodeGen (ADR-0025), before four from Sema:

- **The oracle changes when the output stops being a data structure.** A tree
  can be dumped in a format both sides write; a *program* can only be run.
- **Writing text instead of building a module made the port smaller.** No
  instruction list is needed, because the C++ builder never returns to a block
  it has left; and no named types are needed, because opaque pointers make
  every Pascal type non-recursive when printed.
- **The real literal never needed converting.** Carried as source text it goes
  straight into the IR, and LLVM's assembler is the `strtod` — the same
  correctly-rounded conversion the C++ side gets from its own. Three records
  deferred a conversion that turned out to be unnecessary.
- **The layout rules have to be written out**, because there is no DataLayout to
  ask. They are needed in only two places, and the one number that cannot be
  derived — the size of a file variable — is checked against `pasrt.h` by the
  harness.

And four from Sema (ADR-0024):

- **A selector may follow only a variable-access** (§6.5.1), so `Base(t)^.kind`
  cannot be written at all and every predicate takes a local first.
- **A check computed in a wider type has to be rearranged.** `hi - lo` over the
  whole integer type is `2*maxint`. This is the second such rewrite, so it is
  now a pattern to expect rather than a surprise.
- **`||` short-circuits, and the C++ relies on it** — a port that evaluated
  both subrange bounds would report a different number of errors.
- **`continue` has no Pascal equivalent**, and the nearest thing — an empty
  statement before the `else` — was rejected by this compiler until the
  conformance fix that followed the port. ISO 7185 §6.8.1 always allowed it.
- **A string-valued helper is worth designing away.** One hidden name was built
  from a type name; renaming it to use the frame slot removed the only reason
  the Pascal Sema would have needed a string-building `Type::name()`.

## Known limitations

Things that are wrong or absent today, listed so they are not rediscovered as
surprises.

### Under ISO 7185

- **Nesting deeper than 1000 levels is rejected** (ADR-0020). The limit bounds
  the *tree*, not the parser's call depth — the distinction matters because a
  30 000-term `a+b+c+...` chain parses iteratively and used to segfault in
  *Sema*, two stages after the parser survived it. The bound protects all four
  recursive walkers (parser, Sema, CodeGen, the AST destructor) with an order
  of magnitude of headroom against the tightest measured crash point, ~19 000
  levels on an 8 MiB stack. The cost: legal machine-generated programs with
  chains beyond 1000 terms are refused. Since ADR-0110 a **block** is one of
  the levels it counts, which it always should have been — so 999 remain inside
  the program's own, and nested declarations past the bound reach this
  diagnostic instead of running the scope stack off its end.
- **A variable created by `new(p, c1, ..., cn)` may still be assigned or
  passed.** ISO 7185 §6.6.5.3 forbids it, because the unselected variants do
  not exist; detecting it needs the pointer's *value* to carry which form
  created it, and nothing tracks that (ADR-0027). Permissive where the standard
  is restrictive, like the use-after-dispose gap below.
- **Use-after-dispose through a second pointer is undetected.** `dispose(p)`
  sets `p` to nil, which converts the common form into the nil trap, and that is
  all it does. No proof in this repository claims more.
- **`readln` at an unterminated last line** stops rather than failing, where
  ISO calls reading past end-of-file an error. Files whose last line has no
  terminator are common enough to be worth the deviation; `readln` with nothing
  left at all still fails (ADR-0021).
- **Characters are bytes, and the locale is never consulted.** `char` is
  0..255, so UTF-8 passes through unchanged but a multi-byte character is
  several `char` values. That is a deliberate non-decision: encoding is the
  program's business. It does mean a Pascal-hosted lexer sees bytes, which is
  fine while the language it lexes is ASCII.
- **Not implemented at all:** nothing. Sets (ADR-0028), `goto` (ADR-0029 and
  ADR-0032), procedural parameters (ADR-0030), non-text files (ADR-0031), the
  transfer procedures with `page` (ADR-0067) and §6.3's string constant
  (ADR-0068) were this group, and it is now empty — **ISO 7185 is complete**.
  The last four are worth a sentence, because they arrived the same way twice.
  §6.6.5.4's `pack`/`unpack` and §6.9.5's `page` were *missed*, not declined,
  and three documents asserted completeness while they were absent; a
  documentation audit found them by compiling a probe. `const s = 'hello'` was
  then found the same way, hours after the `iso-7185-done` tag had been moved
  to the commit that fixed the first three. No program in the corpus had ever
  written any of them, so every oracle agreed. What makes the claim true now is
  `tests/transfer.pas`, `tests/page.pas`, `tests/stringconst.pas` and the cases
  beside them — not the implementations.
- **A set's base type must have its values in 0..255**, because every set is
  one 256-bit word. ISO 7185 §6.4.3.4 leaves the size to the implementation, so
  this is a permitted limit rather than a deviation — but `set of integer` is a
  legal program this compiler refuses (ADR-0028).
- **An identifier may contain an underscore**, where §6.1.3 makes one `letter {
  letter | digit }`. It is how a name that would collide with a word-symbol is
  spelled — `label_`, `set_`, `packed_` — and how a test program takes the name
  of its file: thirteen identifiers in `selfhost/compiler.pas` and the program
  headers of forty-three test programs (ADR-0072).

### Under ISO/IEC 10206:1991

Five more, each stated in the record that made it. A sixth was listed here for
exactly one commit and is **fixed**: a variable-string may now be a value
parameter (ADR-0115), so a string argument may be a literal, another function's
result or a string of any capacity. It is worth a sentence because of how it was
found — ADR-0052 recorded the refusal from the *compiler's* side and no document
carried its cost to a **caller** until a library was built on it, at which point
`StartsWith(s, 'Hello')` not compiling stopped looking like a house style and
started looking like what it was.

- **String concatenation draws from an arena.** A string value is a pointer and
  a length (ADR-0051), so only `+` makes characters that did not exist; they
  come from a fixed buffer in the runtime. One *statement* holding more live
  string values than the arena holds is the limit.
  - It was a **ring**, and the sentence here used to end "stated rather than
    silently wrong". That was the reverse of the truth: a wrap wrote one live
    value over another, so `a + a = b + b` over two 512K strings compared a
    buffer with itself, printed EQUAL and exited 0. ADR-0111 made it a stack
    whose end CodeGen supplies — a release emitted after any statement that
    took storage — and both ways of exhausting it are reported now.
- **A subrange whose bounds are not constants is refused as a set's base
  type.** `set of 1..m` inside a procedure is legal under §6.2.3.8 b) and is
  refused. Every set here is one 256-bit word whose base type must have its
  values in 0..255 (ADR-0028), and a bound the block evaluates cannot be
  checked against that before the program runs — so it is the limit
  `set of integer` already states, reached by a different route.
  - **Everything else in the entry that stood here is fixed**, over five
    records. `type t = array [1..m] of integer` and `type t = vector(m)` work
    since ADR-0127 — a type's descriptor belongs to the **block**, so it is
    evaluated once and every variable of the type shares the discriminant
    symbols rather than a copy of their values; that was ADR-0107's independent
    reading's finding most likely to break a real program. The *bare* subrange
    — `var x: 1..m`, `type t = 1..m`, `array [1..m] of 1..m` — works since
    ADR-0133, which did the one thing ADR-0127 named: the range check at a
    store reads the descriptor the way the subscript check always has. And a
    **record's field** and a **file's component** work since ADR-0134, a record
    being no kind of block. **There is no longer a conformance defect that is
    known and unfixed.**
  - Worth carrying forward from how those two went. ADR-0133's fix was three
    lines of check and three *other* things that had been true only because the
    shape was unreachable — `DynamicExtent` answering yes for a subrange, and
    the anonymous schema ADR-0113 hangs on such a type being read as §6.4.8's
    by `Assignable` and by the assignment lowering. **A device that borrows a
    language concept's representation will be read as that concept**, and the
    misreading is invisible until something outside the device's original shape
    reaches it. ADR-0134's was the opposite lesson: the reason ADR-0133 gave
    for refusing a record field **named the check rather than the obstacle**,
    and the first attempt to admit it without that check silently miscompiled a
    program — so a register entry is worth re-reading for what its reason is
    actually saying.
- **ExpDigits is not a fixed number** (ADR-0064). §6.10.3.4.1 makes it one
  implementation-defined value; here it is what C's `%E` writes — two digits,
  or three past 1e100 — so a representation stays exactly ActWidth wide while
  that width depends on the exponent. A conforming processor pads `E+00` to
  `E+000`.
- **A direct-access file's length bound is not checked** (ADR-0050). §6.4.3.6
  makes `file [1..10] of T` at most ten components; this one will hold eleven.
  The index type is used for the position's *type* and its lower bound, not as
  a capacity.
- **§6.5.6's substring aliasing rule is not enforced** (ADR-0057), for the same
  reason ADR-0027's is: it is a property of values at run time, and nothing
  tracks it.

## Beyond self-hosting

Stage 3 compares equal, so this is the live section. The order was settled as
**finish base ISO 7185 first, and only then take on ISO/IEC 10206:1991
(Extended Pascal)** — and the first half of that is done, so the second has
begun (ADR-0033).

That ordering is what decides whether a feature is in scope. Anything ISO 7185
has is worth adding on conformance grounds alone, even where nothing in this
compiler's own source needs it — which was the bar during the bootstrap and is
no longer. Anything the standard lacks waits, and should then be taken from
Extended Pascal's spelling rather than invented here.

### What ISO 7185 had left

In the order they were taken — nothing is left now, and each entry says what
the feature turned out to cost:

- ~~**Sets.**~~ Done (ADR-0028): one 256-bit word, with the base type bounded
  at 0..255 under the latitude §6.4.3.4 gives.
- ~~**`goto` and labels.**~~ Done: the local form (ADR-0029), where §6.8.1's
  restriction turned out to be one prefix test on statement paths, and then the
  non-local one (ADR-0032) — a jump record in the *target's* activation record,
  reached through the static chain. The part that was not small is the one
  ADR-0029 predicted: the abandoned blocks' files, which have to be found
  dynamically because a procedural parameter can be called from a block that is
  not on the jumping procedure's static chain.
- ~~**Procedural and functional parameters.**~~ Done (ADR-0030): the value is
  the pair `{code, static link}`, so a passed procedure runs in the scope it
  was *declared* in. It is the first thing here that makes an activation
  record's address outlive the call that made it — safe only because the
  language gives no way to store the pair.
- ~~**Non-text files.**~~ Done (ADR-0031): a `file of T` is the text-file
  machine with the component size and the line structure made into two
  constants the runtime is told. `text` stays a type of its own, because
  §6.4.3.5 makes it one and only it has lines.

## Stage 2 — ISO/IEC 10206:1991

### How the second standard arrives

**Extended Pascal has begun.** It is the second stage, not an ad-hoc pile of
extensions. ADR-0033 settled how it arrives: `--std` selects the language per
source, ISO 7185 stays the default, and `tests/extended/` is the corpus. The
two are *not* nested — Extended Pascal reserves word-symbols a valid ISO 7185
program may use as identifiers, and the stage-1 compiler is such a program.

### The features, in the order they landed

**Every feature of the second standard gets a record**, including ones that
decide nothing a later feature has to live with. The point is not that each was
hard but that the language's growth reads end to end from `doc/adr/`; a feature
with a short record is then distinguishable from one that was never written
down. The list below is in that order — ADR number, which is also the order
they landed — rather than in the standard's.

- ~~**`otherwise`.**~~ Done (ADR-0033), in the case statement. It retires
  ADR-0018's "ISO 7185 has no `else` and none is invented": the standard has
  one now, and the lowering is unchanged — an otherwise-part is what the
  default block of the same switch holds.
- ~~**`otherwise` in a variant part.**~~ Done (ADR-0034). The same word in a
  record's `case`, and it turned out to touch neither the variant layout of
  ADR-0018 nor the paths of ADR-0026: the completer is an arm with no labels,
  and nothing in the layout ever reads a label. The one place that does is
  `new(p, c)`, where an unclaimed tag value now selects it.
- ~~**Case-constant ranges.**~~ Done (ADR-0035). `1..9` wherever a case
  constant may appear, in a case statement and in a variant alike, because
  Extended Pascal generalised the constant *list* and both name it. A range is
  tested rather than expanded, so `1..maxint` costs two comparisons.
- ~~**Non-decimal literals.**~~ Done (ADR-0036). `base#extended-digits` for any
  base in 2..36, with letters as the digits above nine (§6.1.5). Purely
  lexical: what the parser receives is an integer literal, so no rule anywhere
  later knows the difference. Two things worth remembering — the digit sequence
  is *maximal*, so `16#ffand` is one ill-formed number, and the overflow is
  caught *while accumulating*, because the Pascal lexer has no wider type to
  convert in and then compare.
- ~~**`pow` and `**`.**~~ Done (ADR-0037). Exponentiation, and with it the one
  precedence level Extended Pascal adds that ISO 7185 has not — so this is the
  first feature to change the shape of the expression grammar: every factor is
  now a primary, and a factor is a primary with an optional operator and
  another primary. `**` always yields a real and `pow` yields the type of its
  left operand, which is why the standard has two. Integer `pow` traps on
  overflow because it *is* repeated multiplication, and the proof rules reach
  into `runtime/pasrt.c` for the first time to say the check fires exactly when
  the exact power leaves the type.
- ~~**`and_then`/`or_else`**~~ Done (ADR-0038), and **the standard spells them
  `and then` and `or else`** — two words apiece, no underscore. Each is one
  word-symbol per §6.1.2, so the lexer joins two tokens rather than looking a
  spelling up, and the feature reserves nothing: all four of its words are
  already reserved in ISO 7185. It was indeed small, but not for the reason
  written here: the parser change was trivial and the *lexical* question — what
  may sit between the two words — was the one that needed deciding.
- ~~**Schemata**~~ Done, over seven records (ADR-0039 to ADR-0045). `vector(n:
  integer) = array [1..n] of real` and `vector(3)` work, and §6.4.8's identity
  rule — one tuple one type, distinct tuples distinct types — is an intern
  table rather than a comparison, so `assignable` gained no case at all. A
  discriminated schema produces an *ordinary* type, which is why codegen
  needed one line (for `v.n`) and the proof rules needed none.

  Six halves were left after the first record, and all six are now done:
  - ~~**A schematic formal parameter**~~ Done (ADR-0040). `procedure p(var v:
    vector)`. The bounds come from the actual, so they travel: a descriptor
    beside the address, the shape ADR-0030 already uses for a procedural
    parameter. It is the first array here whose extent is not known at compile
    time, which is what turned a size into emitted arithmetic. The proof rules
    needed nothing added, because the array rule was already quantified over
    its bounds.
  - ~~**Discriminants that are not constants**~~ Done (ADR-0041). `var s:
    vector(n)` — §6.2.3.2 evaluates them when the block is entered, so the
    variable's size is not known until then. It needed almost no new
    machinery: such a variable is ADR-0040's descriptor with the tuple
    *computed* on entry rather than brought by a caller. What it did need is
    the two checks ADR-0040 could argue away — a discriminant outside its own
    type, and a tuple that leaves an index range empty — because "the tuple
    was checked where the type was produced" only holds if every tuple is.
  - ~~**Assignment between two schematic types**~~ Done (ADR-0042), and it is
    the clause rather than a third mechanism: §6.4.6 a) is "the same type",
    §6.4.8 makes one schema with one tuple one type, and §6.4.6 d) says what
    happens when the tuples are not both known — a **dynamic-violation**,
    which §6.1's f) lets a processor report either at preparation time or
    during execution. So `vector(3) := vector(4)` stays a diagnostic and the
    generic case becomes one `icmp` per discriminant. Sema decides only that
    both types came from one schema; everything else was already written.
  - ~~**A schema as the domain of a pointer**~~ Done (ADR-0043). §6.4.4's
    domain-type may be a bare schema-name, and §6.7.5.3's `new(p, d1, ..., ds)`
    gives the tuple. The created variable has no activation record, so its
    tuple is a **header in front of it** and the pointer denotes the variable
    rather than the block — which is what leaves everything else a pointer does
    untouched. The header is rounded to 16 so `malloc`'s alignment survives to
    the variable; a corpus with no set component let a rounding of 8 pass every
    test until one was written.
  - ~~**A discriminant as a variant-selector**~~ Done (ADR-0044). §6.4.3.4's
    variant-selector may be a discriminant-identifier, so which arm of a
    variant part is live is fixed by the tuple rather than stored. The selector
    is then **not a field**, which is the whole design: it has no storage, the
    layout is a tagless `case T of`, codegen and `verify/` are untouched, and
    §6.4.3.4's dynamic-violation cannot be committed because no designator
    denotes the selector. What it costs is one flag saying a symbol is a bound
    discriminant — the *kind* cannot answer, because a constant production
    binds them as ordinary constants.
  - ~~**A schematic formal whose discriminants reach past an array**~~ Done
    (ADR-0045). A record may hold a dynamically bounded array as its **last**
    field — the shape `string` has, a length beside a buffer whose capacity is
    the discriminant. Only last, and no variant part, because both a later
    field and a variant part's shared block sit at an offset nothing can
    compute; the record's layout is therefore entirely static and only its
    *size* is dynamic, which is what `dynSize` already existed to say. LLVM had
    the representation already: a dynamically bounded array is `[0 x T]`, so
    such a record is a flexible-array-member struct and every field access is
    the getelementptr it always was.

  **Schemata are done**, and what they unblocked was the required schema
  `string` itself (§6.4.3.3) — expressible by hand once ADR-0045 landed, but
  its own type-class with a capacity, a truncating assignment and comparison
  across unequal lengths. It arrived as ADR-0051, below.

  And one **defect**, found while the assignment was being written and fixed
  on its own: a schema producing a `packed array [1..n] of char` produces a
  *string* type, and both of the things a string type can do read a length.
  Both read it from `Type::length()`, which is `hi - lo + 1` — on bounds that
  are discriminants that is arithmetic on placeholders, so every comparison
  answered `true` and every `write` printed nothing. No oracle saw it because
  the corpus had no schema producing a string; the length is now computed where
  the bounds are, and the equal-length requirement §6.7.2.5 makes is checked
  there too. It is the second time a wrong answer has hidden behind a
  plausible-looking number — the first was `hi - lo` over the whole integer
  type during the Sema port — and both were found by asking what a *number*
  meant rather than by a failing test.
- ~~**Protected parameters.**~~ Done (ADR-0046). §6.7.3.1's `protected`, and
  the first Extended Pascal feature here that adds no way to write anything
  down — it removes one. The enforcement is §6.5.1's one sentence, "no
  statement shall threaten a variable-access closest-containing a protected
  variable-identifier", and §6.9.4's list of what threatens one turned out to
  name only places this compiler had already decided the argument was a
  variable, so every check sits beside an existing test. Two things worth
  remembering: protection **forwards** — a protected parameter may be passed to
  another protected one, and without that clause the word would be unusable —
  and `new(p)` needs no check at all, because §6.4.1 makes a pointer
  unprotectable and so nothing that reaches `new` can be protected.
- ~~**Type-inquiry.**~~ Done (ADR-0047). §6.4.9's `type of x`, the only
  type-denoter that names a *variable*. It resolves to the `Type *` that
  variable already holds and builds nothing — which is not a shortcut but what
  the clause asks for: under ADR-0017's name equivalence a type-inquiry that
  built a type alike the original could not be assigned from it, and that is
  the one thing anybody writes one for. It reserves nothing, both of its words
  being ISO 7185 word-symbols already, and its parameter form needed no new
  lookup because a scope is pushed before the formals are built. Refused: a
  parameter naming itself (§6.7.3.1), and an object that is a schematic formal,
  whose bounds are in a descriptor a second name would have to share.
- ~~**Initial-state specifiers.**~~ Done (ADR-0048). §6.6's `value`, and the
  record's title is the design: the specifier belongs to the *type-denoter*, so
  a type-name hands it on to every variable of that type, and §6.2.3.5
  attributes it at every *activation* rather than once — a recursive
  procedure's local is created in its initial state on each call. It is a
  prologue beside the two that were already there, and `emitStore` does the
  storing, so both backends and `verify/` needed nothing new.
  - **Nonvarying (§6.8.2) is a question about what an expression reads**, not
    about what the compiler can fold: §6.6's own examples include `ord(red)`
    and `polar(exp(1.0), pi)`, so what survives the test is *computed* at block
    entry rather than folded into a constant.
  - **The parser decides where the word attaches, and only one reading
    parses.** `set of 1..9 value [2]` has one place for it and a recursive
    denoter would have taken it for the base type — so the three permitted
    positions parse the specifier and every nested denoter stops before the
    word. That is what makes §6.6 NOTE 3's `array [1..8] of char value '*'`
    the type error the note says it is.
  - **The first reserved word to cost the corpus something**: an existing test
    had a record field named `value`. ADR-0033's reason for making the standard
    a property of the source, made concrete.
  - A component-value may only be an **expression** here; §6.8.7's array-values
    and record-values are the structured-value-constructor feature, which is
    usable in an ordinary expression too and is therefore its own item. That
    deferral is closed by ADR-0061, below.
- ~~**Complex numbers.**~~ Done (ADR-0049). §6.4.2.2 e) makes `complex` a
  **simple** type, and that one word decides the feature: a complex is a value,
  assigned with a store and passed in a register, exactly where a set is
  (ADR-0028) and nowhere near the by-address machinery of ADR-0017.
  - **The representation is `<2 x double>`, a vector and not a struct**, for
    ADR-0030's reason: nothing may depend on how a struct is passed between
    the two backends. Only three functions know it is rectangular, which is
    what makes §6.4.2.2's NOTE 4 free to honour.
  - The arithmetic is inline; only the six transcendentals go to the runtime,
    and each is **two calls**, one per part — the same trade ADR-0030 made, so
    that no complex-shaped value ever crosses the C boundary.
  - **The first feature gated in Sema rather than in the lexer.** `complex`,
    `cmplx`, `re` and the rest are required *identifiers*, not word-symbols: a
    valid ISO 7185 program may declare them, and `tests/complex_redeclared.pas`
    is one that does. Sema had to learn which standard it is checking.
  - `abs` and `arg` of a complex yield a **real** — the two places table 2's
    result kind does not follow its operand — and §6.8.3.5 gives complex only
    `=` and `<>`, there being no order to give the other four.
- ~~**Direct-access files.**~~ Done (ADR-0050). §6.4.3.6's `file [T] of C`, and
  the record's title is the design: ADR-0031 made a `file of T` the text-file
  machine with two constants changed, and this makes a direct-access file that
  machine with **one number** added. `struct pas_file` gained one flag.
  - **Counted in components, never bytes**, because that is the unit the
    index-type gives — and the **lower bound is folded in the compiler**, so
    the runtime never sees an ordinal. `SeekRead(f, 'c')` on a
    `file ['a'..'z'] of T` arrives as 2, the same division of labour ADR-0017
    gave indexing.
  - `position` and `LastPosition` return a value of the **index type**, which
    is the whole reason that type is kept rather than checked and discarded.
  - **Seeking one past the end is legal** — that is the append position, and
    §6.7.5.2's pre-assertion says so.
  - **Update mode has exactly one door**, `SeekUpdate`, because §6.7.5.2 gives
    `reset` and `rewrite` no direct-access variant. What it buys is `update`:
    write the buffer back and *do not advance*.
  - The lookahead of ADR-0021 became observable for the first time: after a
    fill the stream is one component ahead of the program, so `position`,
    `update` and a mid-file `put` all have to step back.
- ~~**`string`.**~~ Done (ADR-0051). ADR-0012 chose the length-plus-buffer
  record partly because the project had not committed to this standard; it now
  has, so that reason expired, and ADR-0045 had already made the shape
  expressible. The record's title is the design: **a string value is a pointer
  and a length**, two scalars that travel separately — the third time this
  project has reached for ADR-0030's shape, and for the same reason each time.
  - **`substr` and `trim` copy nothing**: a value costs nothing to make under
    that representation. Only `+` makes characters that did not exist, and it
    takes them from a ring in the runtime, whose one limit — a single
    *statement* concatenating more than the ring holds — is stated rather than
    silently wrong.
  - **The required schema has no body**, which is what makes it required: the
    production builds the type instead of resolving a denoter, and §6.4.8's
    intern table then treats it like any other schema. A schematic formal
    `var s: string` is ADR-0040's descriptor with the capacity as its one
    discriminant.
  - **The canonical-string-type is that kind with a negative capacity** — no
    storage, so no capacity to exceed, which is exactly why §6.4.6 checks a
    value's length against the *destination's* capacity.
  - **Two comparisons that must not be unified**: §6.8.3.5's operators pad the
    shorter operand with spaces, §6.7.6.7's `EQ`/`LT` family compares lengths
    too. The standard's NOTE 3 says so outright, and the test prints both
    answers side by side.
  - It **retires ISO 7185's equal-length rule** and the trap `158549b` added
    with it. What that trap protected has not gone away — the defect was a
    length computed from placeholder bounds — so the evidence moved from a
    program that stops to one that answers.
  - Deferred and stated: substring *variables* (§6.5.6's `s[i..j]` as an
    assignment target), `readstr`/`writestr` (§6.7.5.5, which need a text file
    over a string buffer), a string-valued function result, and §6.10.3.6's
    zero and truncating field widths.
- ~~**Binding.**~~ Done (ADR-0052). §6.7.5.6's `bind`/`unbind`, §6.7.6.8's
  `binding` and §6.4.3.4's `BindingType`. It is the feature the string type
  unblocked: `BindingType.name` has "an implementation-defined
  variable-string-type", and there was none to give it before ADR-0051.
  - **The external entity is a file name**, which is the one thing ISO 7185
    could not express: §6.10 binds the program parameters *before* the program
    starts. A bound file is a program parameter that named itself, so `reset`,
    `rewrite` and `extend` needed no change — `pas_external` simply gained a
    third answer.
  - **`bindable` belongs to the type-denoter**, so a type-name hands it on
    (§6.4.1) — which is what makes `type btext = bindable text` the way to
    write a bindable *parameter*, since `text` never is.
  - **`binding(f)` is built in a hidden frame slot**, the mechanism a `with`
    binding uses: it is the only required function returning a record, and the
    call then *is* a designator, so a whole-record assignment and a value
    parameter both work with no case anywhere.
  - It found a real disagreement between the backends: the Pascal `LlSize` for
    a string was unrounded, so a record's field after one fell outside a
    whole-record copy. `irtest` caught it as a wrong answer, which is what
    that harness exists for — two backends can agree on every dump and still
    disagree about a number no dump prints.
- ~~**Modules.**~~ Done (ADR-0053). §6.11's module-declaration and §6.13's
  program-components, and with it the last of the eight features the README
  listed. It is the only one that changes what a *program* is.
  - **A level-0 activation record is a global**, and that one sentence is the
    whole of the code generator's share. A module has exactly one activation
    (§6.2.3.6) that must outlive the function commencing it, and the main
    program is in the same position — so `addressOf` asks a symbol's *owner*
    rather than its level, which is the only way an imported variable can be
    reached at all.
  - **Written order is a legal activation order and no sort produced it.**
    §6.2.2.9 already puts a module-heading before everything that imports its
    interface, so a supplier is textually first — exactly §6.2.3.6's
    condition. Finalizations run in reverse. Two modules can still supply each
    other through a *split* module, and §6.11.1 then forbids an
    initialization- or finalization-part in either — the one rule here that
    needs a reachability check rather than the text's order.
  - **An interface is a table, not a scope** (§6.2.2.2), a heading in a
    module-heading is `forward` under another name (§6.11.1), and a qualified
    name is told from a field selection by the *symbol* — three places where
    the feature reused a mechanism rather than adding one.
  - Five word-symbols, not seven: §6.1.5 and §6.1.6 make `interface` and
    `implementation` directives, which are identifiers exactly as `forward`
    is.
  - Deferred and stated: **separate compilation of program-components**, which
    §6.13 asks for with a *should* rather than a *shall* and which was thought
    to need an interface artefact this compiler does not define — ADR-0079
    found the artefact was the module-heading and did it; a module variable
    with computed discriminants; and a module-parameter that is neither
    `input` nor `output`, which §6.11.1 NOTE 6 lets go unbound.
- ~~**Constant-expressions.**~~ Done (ADR-0054). §6.8.2's
  `constant-expression = expression`, which replaces ISO 7185 §6.3's and
  §6.4.2.4's one-token `constant` in every position that asked for one. The
  feature is one function: `evalConst` already served the constant definition
  and `evalOrdinal` — a wrapper on it — already served subrange bounds, array
  bounds, case labels, variant labels and a schema's discriminants, so adding
  the expression grammar to that one place opened all six at once and no
  caller changed except to say less. The parser changed in exactly one spot:
  a bound is no longer two tokens from the `..`, so telling a subrange from a
  type name is a scan for a `..` at bracket depth zero, and only under
  `--std=extended`. Refused and stated: real-, set- and string-valued
  constant-expressions — the first because ADR-0025 carries a real literal as
  its source text and neither compiler has a float to fold with, the other
  two because a `Symbol` has nowhere to keep the value. ADR-0068 gave it
  somewhere for a string, so what is refused there is now the *operation*
  rather than the value: `const s = 'ab'` folds and `const t = 'a' + 'b'`
  does not.
- ~~**Structured function result types.**~~ Done (ADR-0055). §6.7.2, both
  halves of it: a function may return anything that is not, and does not
  contain, a file and is not bindable, and a result-variable-specification
  (`function mk(a, b: integer) = r: point`) gives the result a name. The two
  arrive together because §6.8.2.2 makes every *read* of a function identifier
  a recursive call, so without a name a structured result could be assigned
  whole and never built a field at a time. The result travels in storage the
  *caller* supplies — ADR-0052's hidden frame slot, generalised — and the
  callee binds the incoming address exactly as a `var` parameter does, which
  is why assignment, copying, subscripting and field selection over a result
  all needed nothing. It found a real bug in `selfhost/compiler.pas` the day
  it landed: `ParseTypeDenoter` assigned a *sibling* function's result and
  never its own, which five oracles had not noticed.
- ~~**Function-accesses.**~~ Done (ADR-0056). §6.8.6: a call may carry
  selectors, so `mk(7, 8).y`, `scale(10)[2]` and `alloc(3)^` are expressions.
  It is the smallest feature in this list and the record's title says why —
  **a parser change**, one function in each compiler, with Sema and CodeGen
  told nothing. That is ADR-0055's dividend: a result living in memory already
  travels in caller-supplied storage, so a call in that position already
  yields an address.
  - **§6.8.6's NOTE was already written**, as `Sema::isDesignator` answering
    `false` for a call. An actual var parameter and a `read` target are two of
    its call sites; an assignment's target and a `with`'s record are refused
    one level earlier by the grammar, because §6.5.1's variable-accesses do
    not include a record-function-access. Four refusals, no new rule.
  - **§6.8.6.4 is the exception and it is a variable**, so `alloc(3)^.x := 1`
    is legal and a statement beginning with a name and arguments is no longer
    certainly a procedure-statement. Telling them apart is a scan to the
    *matching* `)` — the second bracket-depth walk this parser has needed.
  - The ISO 7185 gate could not be tested with a record result: §6.6.2 refuses
    that first, so the program would pass whatever the parser did. It returns
    a **pointer** instead. ADR-0054 found the same fault in
    `constexpr_iso.pas`; this time it was recognised before it landed.
  - Deferred with §6.5.6: **§6.8.6.5's substring-function-access**, because
    `parseSelectors` is now shared and would learn `[i..j]` once for both.
- ~~**Substring variables.**~~ Done (ADR-0057). §6.5.6's `s[i..j]` as a
  variable, and §6.8.6.5's substring of a function-access with it — one node,
  because §6.5.1 makes the first a variable-access and the second a value and
  the *base* is the whole difference, which `isDesignator` was already asking.
  It closes ADR-0056's deferral in the place that record named.
  - **The capacity is never a compile-time number and never needs to be.**
    §6.5.6 calls the result "a new fixed-string-type" of capacity `hi - lo + 1`;
    this compiler gives it the canonical-string-type, which under ADR-0051 is a
    pointer and a length. The only rule that reads a capacity is the store, and
    the store reads it at run time from the same subtraction.
  - **Writing one is the fixed-string store, unchanged**: §6.4.6 already pads a
    shorter value with spaces and refuses a longer one.
  - **The bounds check could not be shared with `substr`'s**, and the reason is
    exactly one program: `substr(s, 3, 0)` is the null-string and legal, while
    `s[3..2]` is an error — the two conditions agree everywhere except at the
    empty case, which is where a shared check would have been wrong in silence.
  - The Pascal port met §6.4.3.3's rule that field identifiers are distinct
    across every variant — the first new node kind since ADR-0023 recorded it,
    and it collided at once.
- ~~**Restricted types.**~~ Done (ADR-0058). §6.4.2.5's `restricted T`, the
  feature whose point is a type-name exported without its structure. The
  record's title is the design: a **type kind**, so every predicate answers
  `false` and each forbidden operation refuses it through the diagnostic it
  already had. Seven diagnostics in the negative test and six were written for
  other features.
  - **`isStructured` and `isMemory` are the only predicates that see through**,
    because how a value travels is not an operation the program performs.
  - **The comparison is the one refusal written down**, and only because
    §6.4.2.5's assignment rule had to teach `assignable` about restricted
    types — a relational operator asks `assignable`, so the permission leaked.
    A shared predicate's new permission reaches every caller of it.
  - It is the **first word-symbol too long for the Pascal keyword table**:
    `kwLit` is nine wide and `restricted` is ten. Recognised beside the table
    rather than repadding 188 literals, and printed in the token dump beside
    the two-word symbols, which are in no table either.
- ~~**Five required things.**~~ Done (ADR-0059). `maxchar` (§6.4.2.2 d)),
  `halt` (§6.7.5.7), `card` (§6.7.6.3), the two-argument `succ`/`pred`
  (§6.7.6.4) and the set symmetric difference `><` (§6.8.3.4) — each too small
  to be a feature and too separate to be part of one.
  - **`><` is decided in the lexer**, because under ISO 7185 the two characters
    can only be `>` followed by `<`, which no expression admits: joining them
    there would turn one clear diagnostic into a cascade. ADR-0036's argument
    again.
  - **`succ(x, k)` widens to i32 before it checks.** The one-argument form
    tests one end and steps; `ord(x) + k` may leave the type in either
    direction and by any amount, so the sum must not wrap before it is looked
    at.
  - **`halt` closes the open files through the same list ADR-0032 walks**,
    because a halt leaves every block without running its epilogue and "still
    open" and "abandoned" are the same set once nothing further will run.
  - Two enumerators had to be *placed* rather than written where they read
    best: the AST dump prints a builtin as its ordinal, so both compilers must
    agree on the index. `difftest` caught each as a number one apart.
- ~~**readstr and writestr.**~~ Done (ADR-0060). §6.7.5.5's two string
  transfer procedures, and the deferral ADR-0051 named: they need a text file
  over a string buffer, and now they have one.
  - **The standard defines them as file operations, and so does this
    compiler.** `fmemopen` and `open_memstream` give the runtime an ordinary
    `struct pas_file` with no external entity behind it, so every
    `pas_read_*` and `pas_write_*` primitive is reused *unchanged* — a field
    width, the spelling of a real and where a string read stops all mean what
    §6.10 says, because they are the same code.
  - **writestr's error condition was already emitted.** "eoln(f) is false upon
    completion" is false exactly when more was written than the destination
    holds, which is §6.4.6's capacity check every string store already makes.
  - The characters readstr reads from are **copied**, so `readstr(e, i, e)`
    reads into the variable it reads from; and the auxiliary file is
    heap-allocated per statement, so a writestr may appear in the
    write-parameters of another.
  - Both are parsed *by name*, as `read` and `write` are. That was a stated
    deviation — under `--std=extended` a program could not declare its own,
    where §6.7.5.5 makes them required identifiers — and ADR-0087 retired it
    by leaving the parser only the statement's shape and giving Sema the
    question of what the name denotes.
- ~~**Structured-value constructors.**~~ Done (ADR-0061). §6.8.7's array-value
  and record-value, and the initial-state form ADR-0048 deferred.
  - **A structured value is built, not computed.** An array and a record have
    no register form (ADR-0017), so the components are stored into the storage
    the value will occupy and the expression's value is that address — the
    hidden frame slot ADR-0055 gives a memory-living result at the top of an
    expression, the component itself for a nested value, and the destination
    for an assignment or an initial state.
  - **Three of the four productions were already here.** A selector is a
    case-constant-list (ADR-0035), a field-list-value corresponds to a
    field-list and an arm's is one too (ADR-0026), and a component-value is
    what `emitStore` already does — so a subrange component is range-checked
    and a string component padded by code written for something else.
  - **The completer is filled in first and the elements written over it**, so
    §6.8.7.2 b)'s "each component not mapped to by an element" needs no
    complement computed; and a component-value is emitted **once** however
    many components it is for, then copied.
  - **`[a: 1]` cannot be told apart by the parser**: it is an array-value when
    `a` is a constant and a record-value when it is a field name. Both are
    parsed as expressions and Sema decides from the type, which is the third
    bracket-depth lookahead scan in this parser.
  - Not done, and stated: §6.8.7.4's set-value (a set is a value and needs
    none of this machinery, and `sieve[2,3]` cannot be told from `a[2,3]`
    without the symbol), §6.8.8's constant-accesses — which that record calls
    "structured constants" — and a value of a dynamically bounded type. The
    first landed as ADR-0066, below.
- ~~**§6.8.7.4's set-value.**~~ Done (ADR-0066). The third form of §6.8.7.1's
  structured-value-constructor, and four lines of standard:
  `set-value = set-constructor`, so `digits[1, 3]` is `[1, 3]` with a type name
  in front and what the name adds is a **type**.
  - **The reason it was deferred is the reason it works.** ADR-0061 refused it
    because `sieve[2, 3]` cannot be told from `a[2, 3]` without the symbol —
    so the symbol is what tells them apart, in Sema, where ADR-0053 already
    parts a qualified name from a field selection and ADR-0044 a
    variant-selector from a tag-type. The parser builds a subscript spine and
    Sema walks down its base links to the root to ask what the name denotes.
  - **The spine carries the answer instead of being rewritten**, which is
    `FieldExpr::qualified`'s shape and forced by the same thing: the checker
    takes a raw pointer and cannot replace the node its parent holds.
  - **It makes a check ADR-0028 called impossible.** That record says
    `checkedForSetBase` is the check "a set constructor cannot make for itself,
    because a constructor does not know what it is being assigned to" — and a
    set-value knows, so §6.8.7.4's assignment-compatibility rule is that check
    moved to the constructor. `digits[i]` traps with no assignment in sight.
  - **One rule was given up in the parser and taken back in Sema**: a comma may
    now follow a range in brackets, because a set-value's members are a list
    and a substring's range is not, and the flag saying one followed is what
    keeps `s[1..3, 2]` from quietly meaning `s[1..3][2]` for a string.
  - It reserves nothing, and `verify/` gained nothing — no new arithmetic, and
    the one error condition is an existing check at a second call site.
- ~~**The three required real constants.**~~ Done (ADR-0062). §6.4.2.2 b)'s
  `minreal`, `maxreal` and `epsreal`, and the deferral three records had made.
  - **The text was always the mechanism.** ADR-0025 carries a real as the
    characters that were written and this compiler has no floating-point type,
    so what was missing was never a conversion — it was somewhere to put
    twenty-two characters. Each constant is the shortest decimal that
    round-trips to the binary64 value it names, spelled identically in both
    compilers.
  - Required *identifiers*, so shadowable; CodeGen and `verify/` untouched.
  - The test asserts the clause's property (`1.0 + epsreal > 1.0` and
    `1.0 + epsreal / 2.0 = 1.0`), not the printed digits.
  - A real-valued *constant-expression* is still refused (ADR-0054): these are
    values a symbol holds, not values an operator can produce.
- ~~**Set-member iteration.**~~ Done (ADR-0063). §6.9.3.9.3's `for v in s do`,
  the second of the two iteration-clauses §6.9.3.9.1 splits the for-statement
  into.
  - **A walk over the bits.** A set is one 256-bit word (ADR-0028), so the
    lowering is a counter over the base type's ordinals and the same bit test
    the `in` operator emits.
  - **Clamped to 0..255**, because a set *constructor* infers `set of integer`
    from `[1, 2]` and that type's ordinal range is −maxint..maxint. The first
    run scanned two billion values.
  - Three obligations came free: the set is a *value*, so evaluating it before
    the loop is evaluating it once; D.96's error is the store's existing range
    check; and the counter cannot overflow, so the sequence form's
    stop-before-stepping care is unnecessary rather than omitted.
  - Reserves nothing — `in` is already an ISO 7185 word-symbol.
- ~~**Zero field widths in `write`.**~~ Done (ADR-0064). §6.10.3.1 lowers the
  least width from one to zero, and every subclause under it then says what
  zero writes.
  - **Three different answers**: nothing for a string, a char or a Boolean;
    the digits for an integer, since §6.10.3.3 b) applies whenever the width
    is under IntDigits + 1; a full representation for a real, since both real
    forms clamp.
  - **The bound is checked in the compiler**, because which number is least is
    what the standard decides and the runtime is never told which language it
    was compiled for — and because `-1` has to stay usable as the "no width
    given" sentinel.
  - It **fixed two conformance gaps that predate Extended Pascal**:
    §6.10.3.6's truncation of a string written narrower than its length, which
    is ISO 7185 §6.9.3.6's rule word for word, and §6.10.3.4.1's DecPlaces
    derivation, which the runtime replaced with a hard-coded six.
  - Stated deviation: ExpDigits is not a fixed number.
- ~~**The time procedures.**~~ Done (ADR-0065). §6.7.5.8's `GetTimeStamp` and
  §6.7.6.9's `date` and `time`, over §6.4.3.4's packed `TimeStamp` — the only
  feature in either standard that reads something outside the program which is
  not a file.
  - **A time stamp is eight numbers, and the layout stays in the compiler.**
    The clock is sampled once and read field by field, so what crosses to the
    runtime is integers; passing the record was rejected for ADR-0030's
    reason, a Boolean field being an `i1`. §6.4.3.4's field order is then
    agreed in **three** places — Sema's record, CodeGen's `date`/`time` base
    indices, and the runtime's slot numbering — and cannot be reduced to one,
    since the runtime has no view of the record and ADR-0008 forbids CodeGen
    to look a field up by name. A test that gives every field a different
    small number is what holds them together.
  - **The subranges do most of the enforcement** (ADR-0018), which is what
    leaves §6.7.6.9's error condition small enough to be one function:
    February the 30th, and a year the fixed-width representation cannot
    write. `year` is the one field of a TimeStamp whose type does not bound
    it.
  - **§6.9.4 f) is the entry on that list ADR-0046 could not have a call site
    for**, its procedure not existing yet — the only place that record's "each
    check sits beside an existing `isDesignator` test" had to be written
    rather than found.
  - It **reserves nothing**, all four names being required identifiers; and
    `verify/` gained nothing, the two errors being calendar facts rather than
    lowering rules.
  - **The clock had to be made fixable before anything could test it.**
    Mutation testing found that `tm_mon` written unadjusted survives every
    oracle: no program knows what day it is except by asking the same
    function, so a test can assert only what holds at every moment, and an
    off-by-one holds at almost every moment. §6.7.5.8 leaves "current"
    implementation-defined, so it is now `SOURCE_DATE_EPOCH` when that is set
    — read as UTC — and the system clock otherwise. The harnesses gained a
    `name.epoch` convention beside `name.in`, and the eight fields have a
    golden file.
  - **Two of the thirty mutants changed the code rather than the tests**,
    which is the part worth remembering. An epoch is now rejected unless the
    conversion consumes the whole word, because C's `strtoll` answers 0 for a
    word it cannot read and would have dated every program 1970-01-01; and an
    epoch that parses but names no calendar date now takes §6.7.5.8's
    **invalid arm** rather than falling through to the clock, since answering
    a *set* variable with the wall clock made the output vary run to run. Both
    were wrong answers rather than refused ones, which a corpus of golden
    files is structurally poor at noticing. The second also made the standard's
    `DateValid` false arm reachable, and it had never once executed.
    Counting what the corpus reaches has now turned something up every time it
    has been done.

- ~~**§6.8.8's constant-accesses.**~~ Done (ADR-0069), and with them the
  structured constants ADR-0061 deferred and ADR-0068 half-unblocked. A
  constant-access is `isDesignator`'s shape with a constant at the bottom of
  it, so CodeGen and `verify/` gained nothing at all: the spine is the one the
  parser already built, and D.88 to D.91 are the array, string and substring
  bounds already proved. What the feature is *for* is §6.8.8.1's NOTE — `c[i]`
  denotes a different value on each iteration, so a constant-access is a
  run-time read — while a constant index makes it a constant, which is what
  §6.3.2's own `column1 = BlankCard[1]` needs.
  - A structured constant is a **global filled by a prologue**, not an LLVM
    aggregate initializer: printing one would need record padding, variant arms
    and 256-bit sets spelled as text in *both* backends, and ADR-0025's
    emitter has `LlSize`/`LlAlign` and no struct-literal printer.
  - It forced the **declaration parts to be read in written order**, which
    §6.2.1 has always required of Extended Pascal and Sema had never done —
    a conformance fix in its own right, since `const first = red` after a type
    part has no structured constant in it.

### What is left

**Nothing.**

- ~~**Separate compilation of program-components.**~~ Done (ADR-0079). §6.13's
  one sentence, and the last item on this list. ADR-0053 deferred it because it
  "would need an interface artefact this compiler does not define"; the artefact
  turned out to be the **module-heading**, which §6.11.1 already makes the whole
  of what a module exports and which is written in Pascal — so `--import` reads
  another component's *source* and no second file format exists.
  - **Nothing numbered may cross a component boundary**, which is what the
    feature actually cost. A procedure was named with a counter from this
    translation's walk and a variable with a frame index, and a frame's layout
    is decided by the module-*block* — the half a separate translation does not
    have. Each exported slot now carries an external name beside the record,
    which stays internal: `nm` on a component is its interface.
  - **The two compilers' objects are interchangeable.** A module translated by
    `selfhost/compiler.pas` linked against a program translated by the C++
    compiler,
    which is a sharper statement than either passing its own tests.
  - The stage-1 compiler takes the other components as one more program
    parameter, **concatenated** — ADR-0033's constraint for the third time —
    and that costs nothing to define, a sequence of program-components being
    exactly what a source file already is.

**With the time procedures the required procedures and functions are
complete**, with §6.8.8 the grammar is too, and with §6.13 the last *should*
is answered — so no production, required identifier, required type, lexical
rule or clause of ISO/IEC 10206:1991 is outstanding.

## Conformance sweeps

**That last sentence has been checked rather than asserted.** Each sweep below
took a bounded list — a grammar, a set of restrictions, an annex — and put a
compiled program against every entry, which is what ADR-0067 asks for before
any claim of completeness. Two ran in each direction: what the standard has and
this compiler refused, and what it accepts and no standard has.

Every sweep found something, and the finding always had the same shape: no
program in the corpus had written the construct, so all five oracles agreed
with a compiler that was wrong. That is the reason this section exists as a
list of dated sweeps rather than as a claim of conformance.

### Annex A, forwards: what the grammar admits and the compiler refused

ADR-0071. Every one of Annex A's 274 productions was probed with a compiled
program and also looked for in the corpus. It held for 268 of them; five were
constructs the standard admits and this compiler refused — `char + char`, a
qualified name in four type positions and in a subrange bound, a schema's
second name, a `with` over a type produced from a schema, and the `;` after a
variant-part-value — and one, `array [1..4] of file of integer`, was a segfault
(ADR-0070).

The sweep left two lists behind: ~30 accepted-but-unexercised forms, and the
implementation-defined choices of Annexes E and F, most of which had no
document. Both are taken up below.

### Annex A, backwards: what the compiler accepted and neither standard has

ADR-0072: fifteen ISO 7185 restrictions probed, six unenforced. Three are now
checked — an empty argument list, the order of a block's declaration parts, and
selecting from a constant — two are the deliberate deviations listed under
"Known limitations", and one was a fault in the probe rather than in the
compiler, `writeln(5:0)` being accepted and then trapped, which §6.1 f)
permits. Three ISO programs in the corpus were themselves out of order, which
is why nothing had failed.

### The unexercised forms, and the document clause 5.1 requires

ADR-0073 wrote the document — the compliance level, all 80 Annex E and F
entries, and the errors that go unreported — and writing it found two bugs,
since answering an entry meant compiling a probe for it.

**ADR-0076 is the other list.** Working through it found two things that were
not merely unchecked but wrong: a number read took a character more than §6.9.1
allows — `7..9` read as 7 and swallowed a point, so a program reading input
that looks like Pascal source would have lost the `..` — and §6.1.9's `(.` and
`.)` were never provided, which that clause requires of every processor whose
character set has the characters. Five more claims are now pinned by programs
rather than asserted, including `maxreal` and `minreal`, whose printed text was
checked only to thirteen significant digits in either compiler. The list is
shorter, not empty.

### Annex D: the errors the standard enumerates

ADR-0077. Annex D lists all sixty errors clause 6 defines, which makes it the
same kind of bounded checklist Annex A's productions were — and one nobody had
put a program against. Six were answered with a value instead: `ln` of a number
that is not positive, `sqrt` of a negative one, `x/y` with a zero divisor for
real *and* for complex, `i mod j` with j negative, and `dispose` of nil. None
was in the list of errors this processor leaves unreported, so each was
undocumented as well as unchecked, against a README that has said "ISO error
conditions trap" since ADR-0014.

`mod` is the one to remember: Sema's folder had always refused a constant
divisor that is not positive, with a comment saying the emitted code followed
the same rule. It did not — `const c = 5 mod -3` was a diagnostic and the same
expression over a variable computed 1. The compiler disagreeing with itself is
the sharpest form this section's shape takes.

**The second Annex D is the newer language's, and it was almost clean**
(ADR-0078). ISO/IEC 10206:1991 lists a hundred and five errors — the same sixty
plus the ones its features brought — and exactly one of the forty-five it adds
was unreported: `sqr` of a real that overflows, which is in the first annex too
(D.32). Everything else probed stopped the program already.

Six of sixty against one of forty-five is the interesting number, and the
difference is not the standards but when the code was written. Every Extended
Pascal feature here arrived with a record that had to say what it did *not* do,
and an error condition is the first thing that question turns up. ISO 7185's
arithmetic predates the practice, so `sqrt`, `ln`, real `/` and `mod` were
written when the only question was whether they computed the right answer. That
is the first time one of these sweeps has produced evidence about the method
rather than about the compiler.

The same sweep found the one §6.8.3.9 restriction that had never been checked:
a control variable must be declared in the block closest-containing the `for`
statement, so a procedure looping over the program's `i` is not a program
either standard has. Nothing in the corpus wrote one — including
`selfhost/compiler.pas`, whose 274 `for` statements all obey it already.

### Annex C: the required identifiers

ADR-0080, and the sweep that had never been run. Annex C enumerates all 94
required identifiers with the clause defining each, and every one was probed
with a program that *uses it* — compiled, run, and its answer checked. **All 94
pass**, and so do the three required directives. It is the first sweep here to
find nothing, which is the first evidence that the corpus has caught up with
the standard rather than a wasted afternoon.

It was run because the claim above — no required identifier outstanding — was
the one part of it backed by a reading rather than by probes, and because that
is the list that failed before: `pack`, `unpack` and `page` were missing from
ISO 7185 while three documents said otherwise, their names present in
`isRequiredName` and nowhere else. `tests/extended/required_identifiers.pas`
is what the sweep left behind, so the claim is now a test.

**The sweep's own first design would have passed a compiler that was wrong.**
It asked whether a name *resolves* and required two probes to agree before
reporting a gap, so a parse error in one masked the other — ADR-0034's fault,
two rejections compared and passing. "Is the name in scope" is not what a
required identifier means, which is precisely what `pack` and `page` had
already demonstrated.

### Refusals found by reading the clause rather than by probing

Two more constructs the standards have and this compiler rejected. Both are
rules a *syntactically valid* program passes, so the grammar sweep could not
have reached the first at all — and did reach the second, wrote it down here as
outstanding, and left it for two more rounds.

**A program-parameter that does not possess a file-type** (ADR-0074). Neither
standard restricts the list to files — §6.10 makes the binding of a non-file one
implementation-*dependent* and §6.12 drops the distinction — and the refusal's
message asserted a rule neither has. It is accepted now, bound to nothing and
consuming no argument. The same record adds §6.4.1's reason to the five
messages that name two types, which had been printing one spelling twice.

**`const q = nil`** (ADR-0075), rejected under both standards. ISO 7185 §6.3's
constant has no `nil`, so that half was right; ISO/IEC 10206:1991 §6.7.1 makes
it an unsigned-constant and §6.8.2 admits any nonvarying expression, so that
half was a gap — and being written down here rather than fixed is the only
reason it survived two more conformance rounds. §6.4.4's NOTE 2 gives the
token the type every pointer assignment accepts, so nothing outside the folder
changed. It also gave `nil^` a way of being written and so exposed a message
that named the wrong rule: the nil-value "does not identify a variable"
(NOTE 1), which is not the same complaint as "not a pointer".

### The validation suite's DEVIANCE category

**Twenty-nine programs the suite ran that a conforming processor must refuse,
and every one is refused now.** ADR-0086 fetched the BSI suite and catalogued
what this compiler did with all 812; twenty-seven `DEVIANCE` programs ran to
completion and two more printed PASS. Each was triaged to a clause, then fixed —
nine records, ADR-0089 to ADR-0099.

The shape of what it found is the point, not the count:

- **Six were one predicate.** §6.4.3.2 designates a string-type by four
  properties at once and `IsCharArray` asked two of them, so an array whose
  lower bound was not 1, or whose components were a *subrange* of char, was a
  string — and §6.9.3.6 gives a whole-array write the same rule (ADR-0090).
- **Five were a rule whose machinery already existed.** ADR-0046 built §6.9.4's
  threat list for protected parameters; §6.8.3.9's control-variable rule needed
  the same call sites to answer yes for a second reason (ADR-0089).
- **Two retired a deviation this repository had argued for and got wrong.**
  ADR-0072 declined §6.4.5 c)'s set-packing rule because "the standard does not
  say what packing a set-constructor has". §6.7.1 says exactly that, in a
  sentence both standards carry verbatim, and the claim had been copied into
  three documents and a test written to hold the compiler to it (ADR-0093).
- **One needed the ceiling raised.** The compiler interns every identifier and
  literal it reads, without deduplication, and sat 74 characters under
  `poolMax`; adding diagnostics broke the build with its own out-of-space
  message. The seed carried the old bound, so the fix was a bump plus an
  out-of-cycle reseed (ADR-0095).

**Three programs in this tree were wrong, and one was ours.** Two wrote `case
integer of` with two labels — legal only if every integer is named — while
testing something else entirely. `tests/extended/bindprogparam.pas` passed a
component of a packed `BindingType` by reference, illegal from the day ADR-0052
wrote it, twice, with every oracle agreeing.

**And the suite is not a replacement for reading the clause.** §6.6.3.3's packed
rule has two readings — the immediate container, or every container on the
designator — and §6.4.3.1 settles it: packing does not propagate inward. All 812
programs are silent on the difference; only the test written for it fails the
wrong reading (ADR-0099). That is ADR-0067's rule where it costs the most.

### The lexis is complete

**ADR-0033's caveat has expired.** That record said a word-symbol is reserved
only when the feature needing it lands, so until the list was empty
`--std=extended` would accept some programs a conforming processor rejects.
§6.1.2's word-symbol list adds thirteen to ISO 7185's — `and then`, `bindable`,
`export`, `import`, `module`, `only`, `or else`, `otherwise`, `pow`,
`protected`, `qualified`, `restricted`, `value` — and all thirteen are now
reserved, the first and seventh by the lexer joining two tokens (ADR-0038) and
the rest from a table. Nothing on the list above needs a fourteenth: the time
procedures are required *identifiers*, which §6.1.3 makes shadowable rather
than reserved. So the lexis is complete even though the language is not.

## The two things that were not features

Neither is a language feature, and both are now settled — the first against
itself, a few hours after being decided the other way. See below.

- **Retire stage 0 — done** (ADR-0085). `src/` and `selfhost/difftest.sh` are
  gone, `seed/pascalc.ll` builds the compiler, and a tree with no C++ compiler
  and no LLVM development files passes all 435 cases, reaches the
  stage-2/stage-3 fixed point and proves all 43 rules.

  **This entry decided the opposite a few hours earlier, and the record of why
  is worth more than the correction.** It weighed the loss of `difftest.sh` and
  of `verify/`'s subject against "a capability the fixed point already
  provides", and concluded there was nothing to gain. The gain it missed was not
  a capability: **every language feature shipped twice**, in C++ and in Pascal,
  in the same commit, and halving the cost of every future feature is the whole
  argument. A record framed around capabilities could not see it.

  The three parts this entry listed as open are all closed by it. A seed is
  committed and refreshed at release tags. The proofs were re-pointed at the
  Pascal backend, which needed no change to the model — `lowering.py` describes
  an emitted instruction sequence, not a compiler's internals — and are now tied
  to the compiler by `--crosscheck` and the 66 `trap_*.pas` goldens rather than
  by C++ a person could read. And the driver landed as ADR-0083.

  What was given up is stated where it belongs, in ADR-0085: a differential
  oracle over 436 sources, replaced by goldens that cannot disagree with the
  program that wrote them; and a repository that is now x86-64 Linux only,
  because a seed carries a target triple.

- **Keep the proofs alive across the port.** ADR-0025 made the decision the
  earlier version of this line asked for: the theorems stay attached to the C++
  model, and the Pascal generator is tied to it by *behaviour* — the golden
  files carry the traps and their messages, so a lowering that stopped checking
  fails `irtest.sh`.

  **Stage 0 was retired without re-pointing the model, and that was the right
  call.** `lowering.py` describes an emitted instruction sequence rather than
  any compiler's internals, so it transferred unchanged (ADR-0085). What it no
  longer has is a reader: the two backends were *measured* emitting different
  instruction counts for the same program, so the model could be checked
  against C++ line by line and cannot be checked against the Pascal emitter
  that way. The tie is now `--crosscheck`'s 44 adversarial values at `-O0` and
  `-O2` and the 66 `trap_*.pas` goldens — which is the tie ADR-0013 always
  specified, and is behavioural rather than structural. A rule can still drift
  from the emitter it claims to model without any of the 435 cases noticing,
  and nothing below is aimed at that.

## What is next

Both standards are complete and every sweep above has been run, so only the
third item below is a language feature. Two of the others are about **oracles**
— what could still be wrong with nothing here to say so — and they come first
because v1.0.0 gave up the strongest oracle this project had and nothing has
replaced it. The fifth is the platform lock.

**The fourth is done**, and is left in place rather than deleted because what it
found is the argument for the two above it: every one of those measurements
turned something up on its first run, which is what an unasked question looks
like from the outside.

Nothing here is scheduled. This section exists so that the reasons are written
down while they are still live, which is ADR-0001's rule applied to work that
has not started.

### 1. An oracle nobody here wrote

ADR-0085 stated the cost, and **two entries have since answered it** — this
section is kept because the reasoning is what justifies the third candidate
below, which is still open.

`selfhost/difftest.sh` compared two independent implementations over 436
sources; what ADR-0085 left — the 435 cases, the stage-2/stage-3 fixed point,
and 43 SMT rules — all shared one implementation, and **a golden cannot
disagree with the program that wrote it**. The defects difftest caught were
exactly the ones every other oracle agreed about: a builtin's enumerator one
apart (ADR-0059), a comment-delimiter rule implemented wrongly in *both*
compilers (ADR-0073), a diagnostic that named two types identically and
explained nothing (ADR-0074).

Both restorations have now paid. The BSI suite found three defects on its first
run (below), and the returned front end found a **dump defect in the product**
that no golden could have: `pascalc` padded twice for a redefined `write`,
once for the husk node and once for the call it looks through, so a `proccall`
printed two levels deeper than its own arguments. Copying that into `src/`
would have closed four files and been ADR-0073's failure exactly — two
compilers wrong the same way, difftest agreeing happily —
so the Pascal was fixed and `tests/dumps/redefine_family.pas` pins it.

Three candidates, cheapest first, and not exclusive:

- ~~**The Pascal Validation Suite**~~ **Done** (ADR-0086). The BSI suite,
  version 5.7, 812 programs — fetched rather than committed, because BSI grants
  use and not redistribution, and pinned to one upstream commit so a red bar
  cannot be a corpus edit. `tests/bsi/expected.tsv` records what the compiler
  does with every one and fails on any difference **in either direction**, which
  is `verify/`'s rule for a `KNOWN_GAP` that starts holding.
  - **It found three defects on the first run**, all of which the goldens, the
    fixed point and the 43 proofs agreed were correct: `succ`/`pred` running
    out at a *subrange's* bounds rather than its host's (§6.6.6.4 with §6.7.1),
    the `for` bounds being range-checked when the loop does not execute
    (§6.8.3.9), and a program being unable to redefine `write` (§6.6.4.1). The
    first was wrong in `tests/trap_succ_subrange.pas`'s own comment and in
    CLAUDE.md as well as in the compiler — which is exactly the shape ADR-0085
    said nothing left here could catch.
  - **All three are fixed**, the third by ADR-0087, which also retired
    ADR-0060's deviation on `readstr`/`writestr` and found a check that had
    never been reachable. CONF116 is the only one of the 812 whose verdict has
    moved since, and the catalogue is what said so.
  - **Level 0 is now confirmed from outside**: all 51 `LEVEL1` programs are
    rejected, as the suite requires of a processor without conformant array
    parameters. The first claim in `doc/implementation-defined.md` §1 that
    something other than this project has checked.
  - ~~Outstanding from it: **28 undetected errors against that document's
    twelve**~~ **Done.** The two numbers were never comparable — 28 is a count
    of *programs* and the document's rows are *rules* — so the reconciliation
    was done against Annex D itself, which both sides can be keyed to. The 28
    programs name fifteen distinct entries, of which
    `doc/implementation-defined.md` §3 had eight: D.5, D.6, D.12, D.13, D.19,
    D.27, D.30 and D.48 were missing, each unenforced since the feature it
    belongs to landed. Every ERROR row of `tests/bsi/expected.tsv` now carries
    its Annex D number, so the section is regenerable rather than asserted, and
    D.59 — the one entry the suite has no program for — was probed by hand and
    is reported.
  - The largest of the accepted-but-should-be-rejected group is closed:
    §6.2.2.9's rule that a defining-point precedes every applied occurrence in
    its region was nine programs, and five are now refused (ADR-0088). The
    other four turn on a required identifier being recognised by *name* rather
    than being a symbol — ADR-0087's seam from the other side. Declaring the
    required identifiers as symbols in an outermost scope would close those
    four, §6.2.2.10 for required *types* (`type integer = char` is accepted and
    then ignored), and the rest of ADR-0087's own deferral, in one change. That
    is the next thing worth doing here.
  - Two entries the suite *reports* are not enforced either, and the document
    now says so: an undefined pointer is usually nil here, because a level-0
    activation record is a global (ADR-0053), so the nil checks catch D.4 and
    D.24 for the shape where the variable was never assigned and catch neither
    where the pointer is stale. A check that coincides with a rule is not that
    rule being enforced, and a green run of those two programs must not be read
    as one.
- ~~**The reference front end**~~ **Done** (ADR-0108). `src/` came back as
  `pascalc-s0` — lexer, parser and Sema, no code generator — so
  `selfhost/difftest.sh` compares tokens, AST and Sema over every source in the
  tree again. It arrived red at **89 of 731** files, the drift of twenty-four
  Sema commits, and the baseline is **now empty** over 732: every one of those
  rules was ported into `src/`, one commit per rule naming its clause. Eleven
  BSI CONFORM programs came back with them, CONF027 and CONF116 among them.
  - **It is a `ctest` case and an ordinary regression gate**, so any file the
    baseline names is a disagreement the change under review introduced.
  - What it still cannot do is contradict a **reading**: both sides are written
    by one author from one reading, which is why the candidate below is not
    struck through.
- **A third-party differential.** FPC under `-Miso`, or p5, over the ISO 7185
  half of `tests/`. Not a second implementation to maintain: a second *answer*,
  on programs that already exist. **The only candidate here that would
  contradict a misreading** — the BSI suite is a *fixed* corpus from 1982, and
  difftest compares this project against itself.
- **Mutation testing, committed to the tree.** It has found something every
  time it has been run here — the six occasions listed under "Stage 1", and
  ADR-0065's two mutants that changed the compiler rather than the tests — and
  it exists only as prose in those records. Two things it needs, both learned
  the expensive way: a wall-clock and output-size limit per mutant, because a
  looping mutant fills the disk before anything notices; and a restore that
  does **not** preserve mtime, or the mutated binary stays in the build tree
  and the next control run reads as a broken feature.

### 2. ~~Diverse double-compiling, while it is still possible~~ Done

**Run on 2026-08-18 at commit `ef49570`, and it passed.** The two outputs were
identical — 7,024,210 bytes, sha256 `399b9cdc…` — so a compiler reached through
LLVM's code generator and one reached through the seed translate
`selfhost/compiler.pas` to the same text. `seed/ddc.sh` is the procedure, and
`seed/README.md` holds the dated statement with what it does and does not
establish; the short version of the latter is that `v0.1.0` is this project's
own earlier compiler, so the implementations are diverse but not independently
authored.

The window was still open, which was not certain — the four steps below are kept
because they are the argument, and because `ddc.sh` reports the day they stop
working as a *skip* saying so rather than as a failure.

ADR-0085's sharpest cost is that provenance became "a chain rather than an
inspection": the first compiler now comes from a committed artefact whose only
warrant is this repository's history. That is answerable **once**, by David A.
Wheeler's diverse double-compiling, and `v0.1.0` still holds the second
implementation it needs.

1. Build `pascalc-s0` from `src/` at `v0.1.0`.
2. Have it translate today's `selfhost/compiler.pas` — call the result **A**.
3. Have `seed/pascalc.ll` build a compiler the ordinary way — call it **B**.
4. Have A and B each translate `compiler.pas`, and compare *those* outputs.

They must be identical, because both are the Pascal backend running on one
source, while the compilers that produced them came from unrelated
implementations. A and B cannot be compared to each other — ADR-0025 settled
that two backends' assembler text is not comparable — which is exactly why the
comparison is made one stage further on.

**The window closes on its own**, and nothing will announce it: it works only
while the v0.1.0 C++ compiler still accepts `compiler.pas`, and every feature
the compiler starts *using* risks ending that. Worth doing now and recording
the result in `seed/README.md` even if it never runs again — a dated statement
that the seed carried nothing the C++ compiler did not is worth more than the
ability to repeat it.

### 3. Conformant array parameters, and level 1

The one language feature here, and the only work that would change the
compliance level `doc/implementation-defined.md` states.

That document's §1 declares **level 0**, which is a complying level rather than
a gap: ISO 7185 clause 5.1 a) defines it as clause 6 without §6.6.3.6 e),
§6.6.3.7 and §6.6.3.8. Accepting those three makes a level 1 processor.

Most of the mechanism is already here. ADR-0040's schematic formal parameter is
a descriptor beside the address — bounds that travel with the actual — which is
what a conformant array parameter needs and is why one compiled body can serve
every extent. What is genuinely new is §6.6.3.7's congruity rules for
conformant array schemas, which are not ADR-0030's rules for procedural
parameters however alike the two read.

Worth knowing before starting: a schematic formal already covers this ground in
Extended Pascal, so the feature buys **conformance and not expressiveness**.

### 4. ~~Nothing can currently measure what the corpus reaches~~ Done

Both versions this entry proposed were built, and each found something the run
before it could not see.

- **The cheap version** — every diagnostic literal looked for in the `.err`
  goldens — landed in v1.1.1 as `diagnostic-coverage`. It found **32 messages
  nothing named** at once; 26 cases were written and four are argued unreachable
  in a catalogue that fails in both directions.
- **`procedure-coverage`** (ADR-0103) instruments the *emitted IR* with clang's
  SanitizerCoverage, which is possible only because the backend is textual.
  563 of 565 procedures are entered. It found four documented `--dump` flags no
  case had ever passed, and `tests/dumps/` exists because of it.
- **The expensive version** — `pascalc --coverage` (ADR-0104) — landed in
  v1.2.0 and did want a record. The compiler instruments itself, one counter per
  statement, and the *denominator* is read back from the same `.ll` the
  compilation wrote, so the two halves of a figure cannot disagree about which
  lines were executable. 12,949 of 13,403 statements are run by the corpus.
- **`tests/spec/`** (ADR-0105, ADR-0106) is the same question asked of the
  *standards* rather than of the compiler: 13 of 207 testable clauses cited,
  with 85 of the 292 headings triaged out as structural or unimplemented so the
  denominator means something.

**Two things it did not buy, both in `doc/sop.md` §7.** A statement is not a
branch — `if c then a else b` on one line is covered when either arm runs — and
the line-coverage gate is a **ratchet** rather than an allowlist, so it notices
a loss and cannot argue that what is uncovered ought to be. The corpus is also
enumerated by glob, so the shell harnesses are invisible to it; that is how
`Usage` and `Version` first read as unreached.

### 5. The platform lock has a scoped way out

`seed/README.md` states the cost — the repository is x86-64 Linux only, and
porting needs a working compiler on the new target first. A `--target=` option
would turn that into "porting needs a cross-assembler": the triple and the
datalayout are already written out as text (ADR-0028), so the emitter's half is
small.

What needs investigating rather than promising is everything *else* that
assumes the target — `fileSize` against `PAS_FILE_SIZE`, the pointer width the
frame layouts are computed with, and `LlSize`/`LlAlign`. This has an honest
chance of "more is baked in than it looks", and should be scoped as an
investigation rather than as a feature.

### What continuous integration does and does not check

`.github/workflows/ci.yml` builds and tests on every push and pull request, in
two minimal **containers** rather than on a machine with a toolchain already
installed — which is the whole of what it adds. Every machine this compiler has
been built on has LLVM 21 and a C++ toolchain, so "the build needs nothing of
LLVM's" is a claim none of them can test. It also puts an assembler *older*
than the one that emitted the seed against that seed, a portability property
nothing else checks; and at a `v*` tag it requires `seed/pascalc.ll` to be what
the current source produces, which is the one question ADR-0085's
refresh-at-release-tags policy otherwise leaves to a human to remember.

**It adds no oracle.** It runs the ones that already exist, on a machine that
has never seen this repository. Item 1 is not something CI can supply.

**Its first two runs each found something**, which is the argument for having
written it:

- **README.md's build instructions were wrong.** "Requires `clang` on PATH, and
  nothing else" is false — `--no-install-recommends` gives no `make`, and
  configure fails before it reaches a compiler. Nobody could have noticed on a
  machine that has one. The sentence now names `cmake`, `make` and `clang`, and
  claims *nothing of LLVM's* rather than nothing at all.
- **Which z3 is installed decides whether the proofs pass.** `verify.py` gives
  each rule 30 seconds and reports a timeout through the same channel as a
  counterexample, so Debian trixie's z3 4.13.3 — slow enough to exceed it on
  the two symbolic 32-bit modulo rules — produces *"verification FAILED:
  mod-is-non-negative"*. That reads as the compiler getting `mod` wrong, which
  is ADR-0074's lesson about a message naming the wrong rule, in the one
  directory whose entire purpose is being sure. CI installs the pip package
  `verify/README.md` documents, and that README now says which failures to
  disbelieve; **making a timeout report as something other than a disproof is
  not done.**

One thing the workflow had to be told explicitly: `verify.py` *skips* when z3
is absent, which is right for a checkout and wrong for CI — the rest of the
suite would report green with the 43 rules never run. It asserts z3 is importable before it
configures, so a green bar means the proofs ran.
