# 184. A record crosses when C lays it out the same way

Date: 2026-08-24

## Status

Accepted. AP 6.7.7.6.2.

## Context

`doc/roadmap.md` has carried one item under "What blocks the library" since the
FFI increments closed: a foreign **struct with a layout** — `struct stat`,
`struct dirent`, `struct sockaddr`. The sentence under it said crossing one
"needs the compiler and C to agree about offsets, which nothing here does for a
foreign type", and named it as what stands between here and a directory
listing, and between here and a socket.

That framing is what kept it closed for as long as it stayed closed, and it is
wrong in a way worth recording, because it is the third time in five FFI
increments that an estimate was wrong in the same direction (ADR-0122,
ADR-0123, and the roadmap's own closing lesson: *a decision that looks like it
needs a model may need it for only part of its surface*).

**Nothing had to be made to agree.** `RecordLayout` already rounds each field
up to its own alignment, takes the widest field's alignment as the record's,
and rounds the total to that — which is not a rule chosen to resemble C's, it
is C's rule. The measurement, taken before any of this was designed:

    $ cat off.c            # struct stat, glibc, x86-64
    sizeof(struct stat) = 144, alignof = 8
      st_dev 0   st_ino 8   st_nlink 16   st_mode 24   st_uid 28
      st_gid 32  st_rdev 40 st_size 48    st_blksize 56 st_blocks 64
      st_atim 72 st_mtim 88 st_ctim 104

A Pascal record of the same fields, with the two `glibc` holes written out as
fields of their own, emits `call void @llvm.memcpy...(i64 144, ...)`. Same
size, same offsets, no code written.

So the gap was never offsets. It was **permission**: AP 6.7.7.6 admitted
`integer`, `int64` and `real` as the type of a `var` parameter and refused
everything else, and a caller-owned buffer therefore had no way across as a
single argument. A slice (AP 6.7.7.7) is the other caller-owned shape and it
crosses as *two* arguments, address then length, which is what `read` and
`send` take and what `stat` does not.

## Decision

### 1. A `var` parameter of an external-declaration may be a record

    type StatBuf = record dev, ino, nlink: int64; ... end;
    function ExtStat(path: string; var buf: StatBuf): integer;
      external 'stat';

**There is nothing new to spell.** No word-symbol, no directive, no position
that did not already exist: `var buf: StatBuf` at an `external` heading is
something a program could always write and was told it could not have. This is
the first dialect feature to need neither of ADR-0140's two shapes, because it
adds no syntax at all.

### 2. What qualifies is decided by the fields, not by a marker

A record crosses when it has no variant part and every field, at any depth, is
`char`, `integer`, `int64`, `real`, a fixed array of one of those, or a record
that itself qualifies.

The list is ADR-0129's slice-component list, and it is that list for ADR-0129's
reason: **the callee writes through the address**, so a type with a byte
pattern that is not a value of it cannot be admitted. `char` has none.
`boolean` has 254, an enumeration has as many as it lacks constants, and a
subrange has whatever lies outside its bounds — and nothing runs
`CheckedForStore` over what a routine this compiler did not translate left
behind.

A fixed array is admitted because C lays one out the same way, and because it
is what a `sockaddr` is mostly made of. A nested record is admitted because the
rule one level down is the same rule. A field's size is always static, so there
is no question to ask about bounds: `AddField` already refuses a field whose
extent a discriminant decides (ADR-0045).

A **variant part** is refused. The storage an arm is laid over is `[k x iN]`, a
shape chosen here (ADR-0028), and a C union is not laid out from it; the tag is
a field C has no member for. This is the one refusal that is about the
*compiler's* representation rather than about a value set.

### 3. `packed` is admitted and means nothing, and the corpus says so

This compiler's layout does not depend on packing — ISO 7185 §6.4.3.1 permits
that and `doc/implementation-defined.md` records it — so a packed record
crosses at the offsets C computes for a struct that is **not** packed.
`packed` is therefore not a way to spell `__attribute__((packed))`, and that
is a footgun rather than a limitation: a program could write it believing the
opposite and be wrong silently.

Refusing `packed` at the boundary was considered and rejected: it would refuse
correct programs, packing being innocuous on a struct C does not pack. So it
is admitted, stated in AP 6.7.7.6.2 NOTE 5, and **witnessed**. The probe's
nested struct is `{ char c; int n; }` — a shape where packing would move `n`
from 44 to 41 — and the Pascal side declares it `packed`. The case reads both
fields, so if packing ever began to mean something here, it fails. A NOTE
about a no-op with no test behind it is the kind of claim this tree has been
wrong about before.

### 4. By `var` only — not by value, not as a result

Both are the same question, which is how C copies a struct into a call and back
out of one, and that is a fact about its ABI. ADR-0030 is the standing rule
that nothing here may depend on one: every argument at this boundary travels as
a separate scalar precisely so the textual `.ll` backend needs no opinion about
struct passing. Admitting a by-value struct would give it one.

The by-value case gets a diagnostic of its own rather than falling into the
general refusal, because it is the mistake the feature invites — the answer is
not "records do not cross" but "records cross the other way", and the message
says so.

### 5. Nothing is lowered

`EmitForeignArgument`'s `skVarParam` arm is `EmitAddress` then one `ptr`
operand, and it was already that for every type. A record var parameter emits
the same two lines a `real` one does. So this change touches Sema and nothing
else, and `verify/lowering.py` is untouched — `model_drift.py` reports the edit
as outside both modelled regions, CodeGen and the constant folder, so it asks
for no `Model-unchanged:` trailer at all. A feature that adds a type rule
without adding a lowering is the case that trailer exists to distinguish itself
from.

### 6. The oracle is a probe in the runtime, not in the corpus

`pasx_record_probe` is a `struct` in `runtime/pasrt.c` carrying one member of
every admitted kind — both integer widths, a `char` and the hole it leaves, a
fixed array of each, a `double` that forces realignment, and a nested struct
whose shape makes packing observable — filled with values no other member
could hold, answering `sizeof`.

It is in the runtime rather than in `tests/` deliberately. The claim is that
**two compilers agree about offsets**, and there is no way to check that from
one side; the C compiler builds `pasrt.c` and this compiler builds the record,
so the test is the two of them meeting. And the claim is *per target* —
`LlSize` and `LlAlign` answer with one number for every target (ADR-0028),
which is why `target-layout` exists — so the question has to be askable on a
machine that is not this one, without rebuilding this tree's tests.

`timespec_get` is the second half of the case: a real struct, from ISO C11
rather than from POSIX, and `struct timespec` is a `time_t` beside a `long` on
every target with a 64-bit word. Its values are not fixed, so what the golden
holds is what can be asserted about them — and a swapped or misplaced pair puts
a nanosecond count where the seconds go, which the range test catches.

## Consequences

- **`stat`, `statvfs`, `sockaddr`, `timeval`, `tm` and `flock` become
  declarable**, which is the point. `tests/dialect/foreign_record.pas` calls
  `timespec_get`; the probe covers the shapes.
- The library gains nothing in this change, and that is deliberate — see below.
- Three new diagnostics, all with goldens in
  `tests/dialect/foreign_record_errors.err`.
- One golden was regenerated: AP 6.7.7.6's refusal message now names the record
  as a thing that crosses, in `tests/dialect/foreign_types.err`. The rule
  changed, so the message had to.
- `src/` is untouched. ADR-0121's rule is that a dialect feature *with a syntax
  of its own* must have its refusal carried by the reference front end; this one
  has no syntax, and under `--std=extended` the `external` directive is refused
  before a parameter is looked at. `difftest` needs nothing.

### And it falsifies a premise of ADR-0140, without finding a limit

ADR-0140 decided the dialect reserves no word-symbol, and gave the rule that
makes that applicable: **a dialect feature is spelled in a position where a
conforming program cannot have written it.** That rule is untouched here and
this record does not revisit it.

What this feature meets is the sentence under *What this does not do* in that
record:

> A feature with no position is a feature that has found the real limit, and
> the right response then is to say so in a record — not to quietly reserve a
> word and let ADR-0138's gate discover it.

That is a disjunction resting on a premise nobody stated: **that every dialect
feature needs a spelling.** Two have now falsified it, and neither found a
limit:

- **ADR-0177's `exit`.** No position works — a procedure-statement is something
  ISO/IEC 10206:1991 admits, so there is no juxtaposition a conforming program
  could not have written. The escape was `int64`'s: a required identifier,
  which §6.1.3 lets any program shadow, so the name is the dialect's only
  where the program has not taken it. Recorded there and in `CLAUDE.md`, but
  as a fact about `exit` rather than as a route.
- **This record.** No spelling is needed at all. The feature is not a construct
  but a *rule* — which types are admitted at a position the dialect already
  holds — and a rule has nothing to spell.

So the ordering is the part worth carrying forward, and it is one question
earlier than ADR-0140 starts:

> **Before looking for a position, ask whether the feature needs a spelling at
> all.** A feature that only widens what is admitted somewhere is a rule and
> not a construct, and a marker for it would be a second place for the truth to
> live.

That last clause is the argument that actually rejected `record external` here:
whether a record can cross is decided by its fields, so a marker could only
ever agree with them or contradict them.

**The greppability is not lost, and the reason is worth stating**, because a
feature with no spelling sounds like one that cannot be found. ADR-0121 claims
that `grep external` lists every place checking stops, and that still holds:
this construct is reachable *only* through an `external` heading, so it does
not avoid a position — it **inherits** one, and inherits its properties with
it. A no-spelling feature at a position no dialect feature already held would
be a different proposition and would need its own argument.

## What this does not do

- **It does not make a foreign struct's layout a checked claim.** The program
  writes the fields, and that they are the fields `struct stat` has, in that
  order, with that padding, is a claim of exactly the same class as the
  signature of every `external` routine here — unchecked, and uncheckable
  without a header parser. What the change removes is the *arithmetic*: a
  program no longer states offsets, only fields, and the compiler computes the
  rest by the same rule C does. `doc/sop.md` §7 carries this.
- **So no POSIX struct is declared in `lib/`.** `struct stat` differs between
  glibc and macOS in its member widths and its order, and a library module
  declaring one would hard-code a single platform's layout in a tree that has a
  gate (`target-sizes`, ADR-0155) precisely because two struct sizes were once
  x86-64 measurements written as constants. A `PasFS.FileSize` wants a way to
  be *sure* of the layout, and that is a separate increment: either a
  build-time probe of the real headers, or per-platform declarations chosen by
  something that knows the platform.
- **A callee-owned struct pointer is still refused**, which is AP 6.7.7.9 c)
  unchanged and is what `readdir` needs. This increment took the half whose
  storage the caller owns — the half that needs no memory model — and left the
  half that does. That is the same split ADR-0174 made for the opaque pointer,
  and for the same reason.
- **It does not admit a union**, and a program wanting `struct sockaddr_storage`
  has to declare the arm it means as a fixed array of the right size.

## Alternatives rejected

- **Teach the compiler C's layout algorithm.** There was nothing to teach; it
  is already the algorithm. Writing a second one for foreign records would have
  been a copy free to drift from the one `RecordLayout` uses, which is exactly
  the shape ADR-0155 was written about.
- **A `record external` denoter, marking the ones that cross.** A marker is a
  second place for the truth to live, and the truth is already in the fields —
  a record of an enumeration cannot cross however it is marked, and one of two
  integers always can. It would also have needed a spelling, and this is the
  one dialect feature that needs none.
- **Cross field accessors instead of the struct**, with C helpers in
  `pasrt.c` doing the extraction. That puts every foreign struct anyone ever
  wants into the runtime, which does not scale, is not a language feature, and
  would grow `runtime-isoc`'s catalogue of five non-ISO names once per header.
- **Admit a by-value struct.** ADR-0030, and it is not close: the whole reason
  every argument here travels as a separate scalar is so that no part of this
  compiler has an opinion about a C ABI.
