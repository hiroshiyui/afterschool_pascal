# 185. A struct claim is checkable, and a library may not make one

Date: 2026-08-24

## Status

Accepted. Adds `--dump-layout` and the `foreign-layout` gate. Closes half of
the row ADR-0184 added to `doc/sop.md` §7.

## Context

ADR-0184 made a record cross to a foreign routine as a `var` parameter, and
what makes that sound is that `RecordLayout` *is* C's struct rule — the two
compilers agree about offsets for whatever fields are declared. That record
also wrote down, in the same breath, what it did not close:

> That the declared fields **are** `struct stat`'s, in that order and with that
> padding, is a claim of exactly the same class as the signature of every
> `external` routine here — unchecked, and uncheckable without a header parser.

It is a *worse* claim than the signature, in one specific way. A wrong
signature is usually wrong immediately and loudly; a wrong field list can be
right for eleven fields and wrong for the twelfth, and every field after the
mistake is silently wrong. `struct stat` on glibc/x86-64 is 144 bytes with
**two holes** — four bytes after `st_gid` spelled `__pad0`, twenty-four at the
end spelled `__glibc_reserved` — and a program that omits `__pad0` gets a
plausible number out of `st_size` that is really `st_blksize`.

And ADR-0184 deliberately shipped no library consumer, for a reason it stated
and did not solve: `struct stat` is not the same struct on macOS, so a module
declaring one would be a single platform's layout written as a constant, which
is the shape `target-sizes` (ADR-0155) exists to catch.

So there are two questions here and they have different answers.

## Decision

### 1. A source states its struct claim in a comment, and the claim is checked

    { @cstruct: TimeSpec = struct timespec, <time.h> }
    type TimeSpec = record
      sec: int64;      { @cfield: tv_sec }
      nsec: int64      { @cfield: tv_nsec }
    end;

**A comment, so the language pays nothing.** There is precedent: ADR-0166 reads
`{ @std:iso7185 }` out of a header comment before the lexer runs. A claim about
what a foreign struct looks like is not a statement about *this* language — no
construct here means anything different because of it — so it does not belong
in the grammar, and a program that never crosses a struct should not have to
know the notation exists.

### 2. `--dump-layout` is the compiler's half

It reports every record type-definition the source made, with the size and
alignment this compiler gives it and the offset of each field. Shaped like
`--dump-limits` (ADR-0148): it runs the whole pipeline, writes at the end, and
is **not** part of `--dump-all` — so `difftest`'s three sections and every
`tests/dumps/` golden are untouched, and `src/` needs nothing.

The list of subjects is built in `CheckTypeDecl`, at the one place holding both
halves — the name as written and the type it resolved to — and only when the
flag is set, which is `--coverage`'s discipline (ADR-0104).

### 3. `foreign-layout` is the C compiler's half

The gate zips the compiler's offsets against the `@cfield:` annotations in
source order, generates `_Static_assert(offsetof(...) == N)` per field plus one
for `sizeof`, and hands it to a C compiler holding the real header.

**Zipped in order, not matched by name.** A missing annotation then shifts
every one after it and the count check fires; name-matching would silently
check a subset and call it a pass. A `-` annotation is padding with no C member
— its offset is not asserted, but it still occupies its place, so every member
after it is.

The message names the Pascal field, not only the C one, because the file the
reader has to edit is the Pascal one.

### 4. `@cplatform:` skips rather than fails

`struct stat` is one platform's struct. A subject marked `@cplatform: linux-glibc`
is reported as *not checked here* on a machine that is not that, rather than
failed.

This is not a weakening of the gate. A declaration nobody can check on this
machine is precisely the thing being made visible, and the run says so and
counts it. Failing would make the honest answer indistinguishable from a real
defect.

### 5. **A library module may not make a struct claim at all**

This is the half the gate does *not* solve, and the decision it forces.

`foreign-layout` makes a declaration checkable **on the machine you build on**.
That is exactly what a *program* needs and exactly what a *library* cannot rely
on: `lib/` has to work on machines nobody here can check, and a module carrying
glibc's `struct stat` would be wrong on macOS with nothing at run time to say
so — the gate would report it skipped, which is the correct answer to a
question the user never asked.

So `PasFS` answers about a file through a `pasx_` routine in the runtime, where
the *C compiler on the target machine* reads the header. `runtime/pasrt.c` is
the one file here that is compiled per target, which is what makes it the right
place for a struct nobody can declare portably. ADR-0184 rejected accessors as
the answer to *how a struct crosses*; this is a different question — how a
portable library answers about a file — and the answer differs with it.

`tests/checks/foreign_layout_stat.pas` is the worked example of the other side:
declare the struct you need, say what you claim it is, and let the build tell
you when you are on a machine where the claim is false.

## Consequences

- The claim ADR-0184 registered in `doc/sop.md` §7 is now checked where the
  header is available. The row is amended rather than struck: what remains is a
  declaration on a platform whose header is not here.
- Two mutations, two different messages. Widening the `__pad0` field from
  `integer` to `int64` fails with `sizeof(struct stat) is not 152` and names
  every field after it, `st_rdev` first, with its Pascal name beside it.
  Dropping one `@cfield` annotation fails the count check instead.
- `tests/dumps/layout.pas` is the flag's golden, which is also what covers
  `DumpLayout` — `tests/dumps/` is swept by the coverage harness, and ADR-0103
  exists because four documented `--dump` flags had no case at all.
- The gate fails when it finds **no** claim anywhere, because a run that reaches
  nothing looks exactly like a clean one — the corpus-size check `difftest` has
  for the same reason.

## What this does not do

- **It does not check a declaration against a header that is not on this
  machine.** Nothing can. `@cplatform` makes that visible instead of silent,
  and CI on a second platform is the only thing that turns two skips into two
  checks.
- **It does not parse C.** The gate writes assertions and lets a C compiler
  judge them, which is `target-sizes`' method (ADR-0155) and for its reason: a
  header is not a thing to reimplement reading.
- **It says nothing about the *meaning* of a member** — that `st_size` is a
  size. Only that the field the program reads is the member it named.
- **It does not make `lib/` able to declare a struct.** That is decision 5, and
  it is a limit rather than a deferral: a portable module cannot carry a
  platform's layout, and the runtime is where such a question belongs.

## Alternatives rejected

- **A language construct for the claim** — `record external 'struct stat'`.
  It would put a fact about C in the grammar of this language, and it would
  have to be carried by `src/` as a conformance-surface refusal (ADR-0121).
  A comment costs neither and is read by the tool that needs it.
- **Matching annotations to fields by name.** Silently checks a subset when one
  is missing, which is the failure mode a gate must not have.
- **Generating the Pascal declaration from the headers at build time.** It
  makes `lib/` generated rather than readable, needs a code generator and a
  build step, and would put a C parser or a `pahole` dependency in the build.
  The gate checks a declaration a person wrote and can read, which is the
  property worth keeping.
- **A runtime size check.** `sizeof` alone does not catch a hole in the wrong
  place — the mutation above changes the size, but moving two fields of equal
  width past each other does not — and it would need the runtime to include
  every header a program might use.
