# ADR-0151: Block-scoped ownership is the model, and the fork is forced by sharing

Date: 2026-08-21

## Status

Accepted. Answers `doc/roadmap.md` §7, the last of that chapter's seven
questions and the one ADR-0109 calls the most expensive here to reverse.

It does not choose between ARC and borrow-checking. It finds that the evidence
to choose has never been collected, says what would collect it, and names the
model the language has been using unremarked since before this project started.

## Context

ADR-0109 wants networking, internationalisation, concurrency and memory safety.
`doc/roadmap.md` §7 put three of the four behind one decision that has never
been made — the safety model, "ARC, ownership, or neither" — and offered two
readings of the five increments that preceded it:

> **Two readings fit that equally well**: either the decision genuinely keeps
> proving unnecessary, or it is being routed around because it is the hardest
> thing here. The opaque handle (`DIR *`, `FILE *`) is the first item that
> forces it, which is the reason it has not simply been started.

Neither reading is right, and the sentence after them is false.

### 1. There is already a model here, and it has never been named

A **file variable** is a handle whose lifetime the language manages. Every
property a memory-safety model is asked for, it has:

| Property | How | Where |
| --- | --- | --- |
| It cannot be copied | no assignment, no relational operator, no value parameter, no function result — and since ADR-0150 none of those for anything *containing* one either | `Assignable`'s `ContainsFile` arm, `CheckedResultType`, the value-parameter check |
| It is released when its block exits | the epilogue closes every file the block declared | `CloseFiles` |
| It is released when the block is abandoned | a non-local `goto` closes every file registered after the target's activation began | ADR-0032, `pas_open_files` |
| It is released when `halt` skips the epilogues | the runtime discharges what they owed | `runtime/pasrt.c` |
| It is released when its heap variable is disposed | `pas_file_done` is emitted before `pas_dispose` | CodeGen |
| Lifetimes nest | so "registered later" and "abandoned" are the same set — stated as an invariant in the runtime | `struct pas_file` |

That is **affine ownership with scope-based release**: a value that may be used
at most once as itself, that cannot be duplicated, and that is destroyed at
every exit from the region owning it. Move semantics and `Drop`, arrived at
from ISO 7185 §6.4.6 a) and §6.6.3.1 rather than from Rust, and implemented
here across 30 `IsFile` call sites, 14 `ContainsFile` and 9 `HoldsFile`.

"Block-scoped" is the shorthand and the common case. The exact invariant is
narrower and better: **a file is released when the variable holding it dies,
and it cannot be copied out of that variable.** For a local that is block exit,
for a heap variable `dispose`, for a global the end of the program. The scope
that owns it is the variable's, not always a block's.

### 2. The opaque handle was never blocked. It crosses today, and it is unsafe

AP §6.7.7.9 c) forbids an external-declaration having

> a result that is an address of storage the callee owns … This is where this
> document stops and ADR-0109's memory-safety model begins.

AP §6.7.7.8 admits an `int64` result, which ADR-0128 added for `ssize_t`. A
pointer fits in 64 bits, and no processor can tell a count from an address. So:

```pascal
function ExtOpendir(path: string): int64; external 'opendir';
function ExtClosedir(handle: int64): integer; external 'closedir';
```

compiles, links and runs. The directory opens. And because AP §6.4.2.6.2 makes
`int64` **numeric** on purpose, every property the model would have given the
handle is not pending but absent:

- it copies, and nothing says a handle is unique;
- `d := d + 8` is a legal statement about an open directory stream;
- closing it twice is `double free or corruption (!prev)`, SIGABRT, exit 134.

`tests/dialect/foreign_int64_handle.pas` is that program, committed as a
KNOWN_GAP in `verify/`'s sense: it fails in both directions, so a dialect that
later refuses it fails the case and this record with it.

**The prohibition is a requirement on the program, unenforced and
unenforceable** — Annex C.7 now, which is where the dialect's unchecked
requirements go. It appeared in no register before this: not §7, not ADR-0128,
not Annex C, not `doc/sop.md`.

So the deferral was not preserving anything. The boundary it was protecting had
been open since ADR-0128, under a spelling nobody connected to it, and §7's
"the reason it has not simply been started" was a reason for not starting
something that had already happened.

### 3. The fork is forced by aliasing, and nothing has asked yet

The four narrow estimates now have one explanation instead of a pattern.
ADR-0122 found the argument side has no lifetime question; ADR-0123 found the
nearest blocker was null; ADR-0132 found a lent buffer was never blocked; and
this record finds the handle was not either. Every one of those was a question
about **when storage dies** — and that is the half this language answered
before the project began.

ARC and borrow-checking do not differ about lifetime. They differ about
**aliasing**: what may hold a second name for one owned value, and what happens
when it does. Nothing in the foreign-function interface has asked that
question, which is why no increment produced evidence for either.

What still has no answer, and each is an aliasing question:

- a handle that outlives its block — returned from a factory, or stored in a
  structure that does;
- use-after-`dispose` through a second pointer (ADR-0019, undiminished);
- a value reachable from two activations at once, which is what concurrency is.

## Decision

**1. The dialect's memory-safety model is block-scoped ownership**, and it is
the file variable's discipline named rather than anything new: an owned value
is released when the variable holding it dies, and it cannot be copied out of
that variable. Nothing changes meaning; what changes is that the next feature
needing a lifetime has a model to be built against instead of an open fork.

**2. The remaining fork — ARC or borrow-checking — is deferred, and the trigger
is named.** It becomes decidable at the first construct that lets **two live
names reach one owned value**: a handle as a function result, a handle stored
in a structure outliving its block, a second pointer to a disposed variable, or
any form of concurrency. Until one of those is on the table the two candidates
decide nothing that differs, and a record choosing between them would be
choosing on taste.

This is what §7 asked for in its own words — a decision deferred long enough to
deserve being deferred explicitly — except that the deferral now has a
criterion rather than a mood.

**3. AP §6.7.7.9 c) is stated rather than enforced**, and says so: a NOTE at the
clause, and Annex C.7.

**4. No compiler change and no new language surface.** Deliberate, and the
alternative is in Rejected below.

## Consequences

`doc/roadmap.md` §7 is answered and keeps its entry, struck through, because
what a survey *found* is the part worth carrying forward. The chapter's hardest
question is replaced by a smaller and sharper one — not "which model", but
"what will first need two names for one value" — and that question has a
visible answer: concurrency, which is unstarted.

The `Where the ideas come from` table's two memory-safety rows change from
"plausible" and "strongest guarantee, worst fit" to what they actually are:
undecidable from the evidence in hand, and blocked on the same thing actors are.

**`doc/sop.md` §7 gains the row** the probe belongs to. It is the fourth entry
about the foreign boundary and the first that is not about the far side
behaving: this one is about what the near side permits.

### What it does not do

**It does not make the `int64` door safe**, and it cannot be closed from here.
Refusing an `int64` result would break `read` and `write`, which is what the
type was admitted for; distinguishing a count from an address needs a type the
dialect does not have. The door stays open, and what changes is that it is now
written down in three places instead of none.

**It does not claim files are safe in general.** The discipline covers the
variable that holds the file. A heap record holding one, never disposed, leaks
it; two pointers to such a record, one disposed, is ADR-0019's hole with a
`FILE *` in it. Both are aliasing, which is exactly the half left open.

### Rejected: deciding ARC or borrow-checking now

The evidence does not exist. Both answer lifetime the same way — the way this
language already answers it — and the FFI has never posed an aliasing question,
so five increments produced nothing that discriminates. A record written now
would be justifying a preference rather than explaining a decision, which
ADR-0001 is explicit is the failure mode of a record written at the wrong time.

Against ARC specifically: it changes what `^T` *is*, so it reaches ADR-0019 and
every heap program, and it needs a runtime this project does not have. Against
borrowing: `doc/roadmap.md`'s own reading, that it is the worst fit for a
language whose grain is value semantics and a small orthogonal core.

### Rejected: implementing a handle type in this change

It is the obvious next feature and it is not this record's. A handle type would
be the first dialect feature **designed rather than demanded**, and ADR-0116 is
what that looks like: the allocator was the one designed feature and it did not
survive contact. No program in this tree wants a `DIR *` yet. When `PasFS`
needs `opendir` the increment will have a caller, the shape will be argued
against a use, and the record will be written where ADR-0125 and ADR-0129 were
— behind a demand.

The model this record names is what that increment will be built against, which
is the whole of what it is for.
