# Roadmap

What is open: the goal, what blocks it, the questions no record has answered,
and what is wrong or absent today.

**How the compiler got here is [`doc/history.md`](history.md)** — the
bootstrap, both standards, the conformance sweeps, the dialect increment by
increment, and **every question this file has closed**, with what closing it
found. That document is settled and this one is not, which is why they are
two: an entry here is something someone still has to decide about, and the day
it is decided it moves there.

This file is kept to what is open, and that is maintenance and not tidiness. A
page where the answered outnumber the open teaches a reader to skim, and the
things worth not skimming here are the six or seven sentences saying what
nobody has decided yet.

## How to read this

| Chapter | What it holds |
| --- | --- |
| [The goal](#the-goal-adr-0109) | what this is all for, and the four decisions it forces |
| [What each landed feature left open](#what-each-landed-feature-left-open) | the residue of the FFI and container increments — three rows, and the chapter's own lesson about how few of them turn out to need the memory model |
| [What a daily program cannot reach for](#what-a-daily-program-still-cannot-reach-for) | nothing — the six library gaps and two language absences it listed are all built, and what is left is the chapter's lesson about its own error rate |
| [What would make this easier to work on](#what-would-make-this-easier-to-work-on) | nothing queued either: five items for someone working *on* the compiler, all closed, and the three things that were declined with a reason rather than left as estimates |
| [The program that would judge the language](#the-program-that-would-judge-the-language) | the one client big enough to answer a usability question, why it changed shape, and [the findings of its that are still open](#the-first-findings) — that section keeps the count, and this row deliberately does not |
| [Where the ideas come from](#where-the-ideas-come-from) | the borrowings from Rust, Swift and Zig, and where each stands |
| [The open questions](#the-open-questions) | the one structural risk no record can close — and it is the only entry left |
| [Cross-platform support](#cross-platform-support) | what the x86-64 lock turned out to be, and what is left of it |
| [Known limitations](#known-limitations) | what is wrong or absent today, under [ISO 7185](#under-iso-7185) and [ISO/IEC 10206:1991](#under-isoiec-102061991) |
| [Answered, and where](#answered-and-where) | the questions this file used to carry, each with its record and its narrative in `doc/history.md` |

Nothing here is a work queue with owners and dates. Where a decision has been
made it has an ADR; where it has not, that is the point of the entry.

---

## The goal (ADR-0109)

**A Pascal you can get daily work done in**: a dialect and a standard core
library for networking, internationalisation, concurrent execution, and memory
safety as a property of the language rather than a convention.

Two goals came before this one — bootstrapping, then conformance — and both are
**finished**: the compiler compiles itself, and every clause of both standards
was implemented. **This is now the only goal**, and version 3 is what made that
literally true: ADR-0232 removed `--std` and the two conformance modes, so
there is one language and no mode to be put into. What the standards still are
is where this language came from — it contains Extended Pascal, so every clause
reading in this tree still describes it — and not an obligation it is under.

**Four decisions the goal forces**, each to get its own record when it is made:

| Decision | Where it stands |
| --- | --- |
| **The memory-safety model** | **Answered, in both halves and by discovery rather than by design** — four records, and not one of them decided the question the row was written to pose. *Lifetime* — an owned value is released when the variable holding it dies and cannot be copied out of it — was already here, being what a file variable has been since 1982 (ADR-0151). But that sentence quantifies over a *variable*, and a variable created by `new` is held by nothing: it exists in no activation, so nothing released what a heap record owned unless the program said `dispose`, and under a 64-descriptor limit a loop allocating one per iteration ran out at the 62nd. `owned ^T` gives such a variable an owner and closes it (ADR-0181, AP 6.4.14). The *aliasing* half — may a second name hold one owned value, and if so how: ARC, or borrowing — stood here for a long time as undecidable until the fork was **withdrawn as posed** (ADR-0201). Neither candidate can reach `^T`, ADR-0117's containment fixing what an ISO program's only reference type means; the dialect's answer for the three affine kinds is refusal, given three times, so there is no second name for either candidate to govern; and the one alias that does exist — a `var` parameter bound to an owned value's referent — cannot escape, because Pascal has no address-of and `new` is the only producer of a pointer. **Unformable rather than checked**, which is stronger and free, and silent if a future feature takes it away (`doc/sop.md` §7). What is left of the fork is exactly one thing: **two threads of control**, which is the only sentence that breaks *a borrow cannot outlive a call because the caller is not running during it*. See the concurrency row [below](#where-the-ideas-come-from). |
| **The text model** | **Done** (ADR-0189 – ADR-0193, ADR-0196, ADR-0199, AP 6.4.15). Nothing of the clause is left, and the row's own offer — *a wider character type or a text type* — turned out not to be a choice: widening `char` stops `set of char` compiling under ADR-0028's 256-value cap. What was built instead, what it cost, and the one argued-rather-than-measured decision in it — refusing an integer index — are in [`doc/history.md`](history.md#the-text-model). **That refusal has since had its first external test** (ADR-0237): LSP counts positions in UTF-16 code units, a fourth unit this page said nothing answers in, and the count never needed the index — a scalar below U+10000 is one code unit and one at or above it is two, so the conversion is a walk over the scalar view, unchanged |
| **The memory model** | Unstarted, and **no longer blocked**: it could not be designed before the safety model, shared mutable state being where the two meet, and the safety model is answered. What that answer does to this row is shrink it — ADR-0201's construct is share-nothing, so there is no shared mutable state for a memory model to be about, and the question narrows to what a value crossing between two threads guarantees. It stays open because nothing has been designed, not because something is in its way. |
| ~~**How far the C++ reference front end follows**~~ (ADR-0108) | **Answered by deletion** (ADR-0232). It was frozen at the conformance surface — `difftest` skipped every dialect source — and when the conformance surface went, `difftest` had nothing left to compare and `src/` had no reader. Both are gone. The question the row was really about survives as [open question §1](#1-the-dialect-has-no-external-authority-and-every-gate-here-is-anchored-in-one) and as `doc/sop.md` §7's largest entry: nothing now compares this front end with a second answer. |

What is already in hand and was not built for this: modules and separate
compilation (ADR-0053, ADR-0079) mean a library needs no new language
mechanism, and `runtime/pasrt.c` is where the outside world already enters.

---

## What each landed feature left open

**This chapter was called "What blocks the library" and is renamed**, because
nothing is left of the list that named it. Every row a survey of daily needs
put here has been struck, and the last of them went the way the two before it
did — a decision that looked like it needed the memory-safety model turned out
to need it for only part of its surface.

What stands below is a different thing: **what each landed feature left open
behind it**. The two things the handle opened, both since struck within two
days of being written down; the move a k-way merge would have liked; the
routine half of the schema's type discriminant. None is a gap a survey found —
each is a consequence of a feature landing, which is the shape to expect from
here on. This page empties faster than it fills, and a landed feature is both
the commonest way it fills and, one increment later, the commonest way a row
leaves it.

**One row here is a compiler item and not a library one**, and it is stated
under the move below rather than in a heading of its own, which is where
nobody will find it: `function Open(p): Stream ! ErrorCode` is refused by a
*representation* choice — a fallible-type's two arms share storage, as a
variant part's do — and changing that reaches four gates and the emitted
struct shape. It is the only thing on this page with a named cost.

~~A foreign struct the callee owns~~ is **done** (ADR-0187, AP 6.7.7.8): an
`external` function may answer an optional of a record, a null address is the
absent value, and any other address yields a **copy** made where the call
occurs. That is the whole of it, and choosing a copy is what kept the model out
of it — nothing holds the address, so there is no lifetime to reason about.
`readdir`, `gmtime` and `localtime` are declarable. What is still not
declarable is a member that is *itself* a pointer, so a chained list of structs
cannot be read by a Pascal program.

**The example this sentence used to give has been answered, and by the same
move that answered the four below it.** It said `getaddrinfo` waits, and on
the memory model rather than on a clause. `getaddrinfo` is *called* — in
`runtime/pasrt_posix.c`, behind `<netdb.h>`, one of the six headers that unit
is bounded by — and `PasNet` crosses a host and a service as **strings** at
both ends so that the chain never reaches Pascal at all (ADR-0203). `PasDir`
did the same thing first: a library may not declare `struct dirent` under
ADR-0185's fifth decision, so the runtime supplies the one member access
(ADR-0188). Twice now the answer has been *arrange for nothing to hold the
address*, which is this chapter's closing lesson applied before the row could
be believed.

So what is left of the row is a **shape without a client**: no program here
wants a chained struct badly enough to have been written, and the two that
looked as though they would were answered in C. By ADR-0116's rule that is not
a thing to build. What would move it is a probe — a program that wants such a
chain and cannot get it through a `pasx_` binding — and writing one is how the
four estimates below were found to be wrong.

**And a rule this page had not noticed cuts across all of it** (ADR-0188).
ADR-0187 is a *program*-level feature: a program knows what it was built for
and can have its field list checked by `foreign-layout`, and a **library**
cannot, ADR-0185's fifth decision being categorical. `struct dirent` differs on
glibc and macOS and POSIX does not fix its member order; `struct tm` is
standardised by ISO C and *that clause* does not fix its member order either.
So the set of structs `lib/` may declare is close to empty, and a module
wanting one asks the runtime — which is how `PasDir` was built, and why the row
below closed without using the record that unblocked it.

~~The struct with a layout~~ is **done** (ADR-0184, AP 6.7.7.6.2), and the
sentence that stood here — *crossing one needs the compiler and C to agree
about offsets, which nothing here does for a foreign type* — was wrong in the
direction this page has now been wrong in four times. Nothing had to be made
to agree: `RecordLayout` already *is* C's struct rule, so a record of
`struct stat`'s fields was 144 bytes at C's own offsets before anything was
written. The gap was permission, not arithmetic, and a record now crosses as a
`var` parameter. `struct sockaddr`, `struct stat` and `struct timespec` are
declarable; what a program still writes for itself is the field list, and
nothing checks it against the header.

Everything else a survey of daily needs found is closed. **`README.md`'s
module table is the one place to count the library** — one row each, checkable
against `ls lib lib/dialect`, and it is named here instead of a number because
this sentence carried one and it went stale three times. `lib/dialect/README.md` is not a second listing and should not be
read as one: it is the error-shape convention, and it names only the modules
that illustrate it. That survey (2026-08-23, against the thirteen modules that
then existed in total) named six gaps. Three needed no language change and closed the same day:
`PasFile` (after ADR-0172), `PasProcess`, `PasStrVec`. Of the three that needed one, the command line as a
list turned out to be a feature rather than a module (ADR-0173), the opaque
handle is ADR-0174, and the struct is ADR-0184 — so all six are closed, and
what remains above is the narrower half none of them named.

Why those last three were one item underneath: what cannot cross is **a pointer
to storage the callee owns whose contents are not characters**. Every foreign
type that crosses today is a scalar, a string copied at the call, or a slice the
caller owns (AP §6.7.7). ~~The opaque half~~ is **done** — `handle external
'closedir'` is a file variable for a foreign address, released where a file
closes (ADR-0174, AP 6.4.12) — and what it deliberately does not touch is
aliasing: a handle cannot be copied at all, so no two names reach one value.
~~The half whose contents have a shape~~ is **done too**, in both directions:
a record crosses as a `var` parameter, so `stat` fills a buffer this program
declared (ADR-0184), and comes back as an optional whose value is copied at
the call, so `readdir` answers one this program then owns (ADR-0187). ~~The
piece that needed the memory model~~ — storage the callee owns **and** whose
shape the program must read — turned out not to need it either, because the
copy retires the address at the end of the statement. What genuinely waits on
the model is narrower than any row here ever said: a struct **member** that is
a pointer, which is a second name for storage and cannot be copied away.

**The three rows that stood here, and how each closed:**

| A daily program wanted | How it went |
| --- | --- |
| ~~a directory listing~~ | **done** — `PasDir` (ADR-0188), and it went a way the row above did not predict. ADR-0187 makes `readdir` declarable by a *program*; a **library** may not declare `struct dirent` at all, ADR-0185's fifth decision holding and POSIX not even fixing the member order. So `opendir` and `closedir` are bound directly, the `DIR *` is a handle, and the runtime supplies the one member access. `PasProcess.CaptureLines('ls -1 dir', names)` is superseded |
| ~~a socket~~ | **done** — `PasNet` (ADR-0203), and it went a way this row did not predict. The row assumed the module would declare `sockaddr` and cross it as a `var` parameter; ADR-0185's fifth decision forbids a *library* from declaring any foreign struct, and sockets are the strongest case for that rule rather than an exception to it — `struct sockaddr` is not one struct but a family, and a program never declares the one it is really using. So both ends of every call are **strings**, a host and a service, and `getaddrinfo` decides what they mean: no address family, no port number, no byte order, and IPv6 without asking. A socket is a handle the runtime owns, closed by `s := nil` or by the block. One connection at a time, which is what `Wait` then closed |
| ~~creating a file through `PasIO`~~ | **done**, beside it rather than in it: `PasStream` opens a file through `fopen`, whose mode is a string and needs no header number, and owns the stream as a handle (ADR-0174). `PasIO` stays descriptor-only |

**And what the last of them opened as it closed** — one row, where two stood
for a day:

| A daily program wants | Why it waits |
| --- | --- |
| ~~a server that serves more than one client~~ | **done** — `PasNet.Wait` (ADR-0205), and it needed nothing from the language. The server was written before the feature and compiled: an array of handles is admitted, `Accept(srv, clients[k])` writes a connection into a slot through a `var` parameter, `clients[k] := nil` releases one, and a schema gives the array whatever length a program wants. What was missing was only *which of these can I read without blocking*, which is a library routine over `poll`. The set is built and thrown away inside one call rather than being an object, because an object would hold a second name for every socket in it and `clients[k] := nil` would dangle it — ADR-0187's rule a second time |
| **to hand an owned value to something else** | Of the three affine kinds only `owned ^T` moves. `take` is refused for a handle in as many words — *nothing else has a value one variable can stop holding* — and there is no move for a file at all (ADR-0182, AP 6.4.14 NOTE 5). This row lost its stated client the day after it was written: it was entered because a task cannot be given a socket, and the server turned out to need neither a task nor a move, a handle reaching its slot as the `var` parameter its producer writes through. So a **second client was written on purpose**, to find out what the row is worth rather than to wait for one — a k-way merge of sorted files, a binary heap of open streams ordered by the line each is showing, which is the textbook program whose data structure exists to exchange its elements. **It is writable today**, and the whole of what the missing move costs is one indirection: an `array [1..K]` of records each holding a `Stream` is admitted and readable, but the heap has to be over *positions* in it rather than over the records, so every comparison reads `src[heap[c]].head` and `Swap` exchanges integers. That is not a workaround but the ordinary shape here — `lib/passort.pas` sorts by `less(i, j)` and `swap(i, j)` and never sees an element, for the unrelated reason that this compiler has no generic *routines* — a schema may now be parameterised by a type (ADR-0209) and a routine over one may not be, which is the row below — and its own header names parallel arrays as a caller it expects. The one bug the probe carried lived in exactly that doubled subscript, which is one author in one sitting and is worth recording rather than deciding on. **So the row is real and small**: an ergonomic cost and not a wall, and by ADR-0116's rule it stays unbuilt, the program that wants the move having managed without it. The **factory** that would change the answer is a compiler item and has a section of its own below. |

**What building on the handle found.** Two modules were written over
AP 6.4.12 the day it landed, and each met one edge of the clause:

- ~~**There is no `h := nil`.**~~ **Done** (ADR-0202). It was one Sema arm and
  no lowering, exactly as this bullet predicted — `pas_handle_set` already
  released what the slot held, and `nil` is a null pointer, so the existing
  emission of the first form *is* the second when the value is null. What made
  it land was the second caller: `PasDir` wanted it on the day it was written,
  and both modules had been closing a stream by opening a path they knew would
  fail, for a refused system call and a stale `errno` apiece.
- ~~**A closer's result is discarded.**~~ **Done** (ADR-0206, AP 6.4.12.5).
  Where it goes turned out to be the obvious place once the question was
  asked properly: `release(h)` is a required function that releases and
  *answers*, and the reason no release could report before is that none of
  them is a statement. `PasProcess.Capture` loses the marker, the subshell
  and the reader's lookahead, and its golden passed unchanged with all of it
  removed — the strongest thing that can be said for a simplification.

**And what the type discriminant opened**, on the day it landed:

| A daily program wants | Why it waits |
| --- | --- |
| ~~to write a *growable* container once~~ | **Done** (ADR-0209, ADR-0211, ADR-0212, ADR-0213), and the module is `lib/dialect/pascontainer.pas`: one growable vector and one string-keyed map, over whatever element type a program names. A client writes one line per element type — `type IntVec = ^Vec(integer);` — and the module is written once. `tests/dialect/lib_container.pas` runs both containers over `integer` and over a record, growing each past its opening capacity more than once. **What it does not replace**: `PasVector`, `PasStrVec` and `PasMap` are ordinary Extended Pascal and stay, because generics are the dialect's and a conforming program must still have a vector and a map; and `PasList` stays because an owned pointer's domain may not be a schema (ADR-0181), so a generic chain would make the *program* declare the node and list types. **What writing it found**, both recorded: a generic body may call only what its clients can reach, since the instantiation is emitted in the client and a module's private routines are internal to its own object file (`doc/sop.md` §7, and the module exports two helpers no caller wants); and that a type argument a call passes is one the container's own type already knows, which `x: type of v^.a[1]` removes — **not** a conformance gap, as this row said for a day: §6.4.9's object is a variable-name and no more, so the refusal is the standard's (ADR-0214), and the dialect widening it is a feature (ADR-0215). Five of the module's headings have lost a type parameter; `VecGet` and `MapGet` keep theirs, because they return the element type and §6.7.1 makes a result-type a type-name. **A generic map keyed by anything but a string** is done too, and needed no constraint (ADR-0260) — see the hash row below |

### The factory — **done** (ADR-0255, ADR-0256)

**`function Open(p): Stream ! ErrorCode` was the one item on this page with a
named cost**, and it is written: AP 6.4.12.6 admits a handle as the result of a
function of this program, and AP 6.4.13.5 admits an affine *value* side to a
fallible-type and lays that record's two arms beside one another rather than
over one another. `tests/dialect/factory_handle.pas` and
`tests/dialect/factory_fallible.pas` are the cases.

**The estimate written here was wrong in both directions at once**, and that is
worth more than the feature. It said the change reaches `target-layout` and
`foreign-layout`, "gates that compare offsets, so both would move and both
would have to be re-argued rather than regenerated". Neither moved. Neither
holds an expected value — both compute from the compiler's own output on every
run — and neither read a source that declared a fallible-type at all, so there
was nothing to re-argue and nothing to see. `tests/checks/target_layout.pas`
declares one now, which is the fix for a gate that could not have watched this
shape.

And it said the item is "not a clause and not a Sema arm … a representation
change". The representation is the small half. What it did not name: the record
then contains something with no copy, so it needs an assignment rule of its own,
a *mandatory* in-place build at the call — a memcpy there is ADR-0150's double
free with a handle in place of a file — two walks taught to reach an arm, and a
decision about `try`, which is refused because it yields the value and an owned
value has none to yield.

**The bare half was as cheap as this page said.** A handle is `IsMemory`, so a
function answering one already receives the address of the variable its result
is to occupy; its own `Open := ExtFopen(...)` is AP 6.4.12.2's assignment made
through that address; and a factory over a factory emits no `pas_handle_set` at
all. Three claims, checked rather than trusted, all three true.

**The first mutation survived and the test is what changed.** Laying the arms
over one another again passed all 754 cases, because the case wrote a cause
only over a handle that had never been opened — where the corrupted bytes are
zero either way. A case that writes a cause over a *live* stream makes the same
mutation exit 139. A test of a representation is worth nothing until it stages
the corruption the representation prevents.

**The lesson from the FFI increments**, worth keeping for whatever replaces the
rows above: a decision that looks like it needs a model may need it for only
part of its surface, and the part that does not is usually worth taking first.
Four estimates in a row were wrong in that useful direction — ADR-0122 and
ADR-0123, then ADR-0184, whose item this page had described as needing the
compiler and C to agree about offsets when they already did, then ADR-0187,
whose item this page had called the place *where the memory-safety model
actually bites*. It did not bite there. It bites one level further in, at a
struct member that is a pointer, and the reason is worth stating in general:
**an ownership question is only a question while something holds the address.**
Each of the four was answered by arranging for nothing to.

**And the row that was left as the place it genuinely bites has since been
answered the same way**, which makes five — `getaddrinfo`'s chained list is
walked in `runtime/pasrt_posix.c` and `PasNet` crosses strings, exactly as
`PasDir` crosses a name rather than a `struct dirent`. The pattern is now
strong enough to state as a prior rather than as a tally: **before recording
that something waits on the memory model, ask whether the address can be
retired at the call.** Five times running it could, and twice the answer was
not a language feature at all but a `pasx_` routine that does the walking on
the far side.

**And the factory above is the first item where the prior does not apply**,
which is what makes it worth keeping as a prior rather than a rule. The whole
point of a factory is that the callee's answer **outlives the call** — the
address cannot be retired there, because retiring it is exactly what a factory
must not do. So the question the prior asks is still the right first question,
and "no" is now a possible answer with a case behind it. Where the answer is
no, expect the ownership rule the five easy ones did not need.

---

## What a daily program still cannot reach for

**Nothing this page has thought of.** The chapter that stood here listed six
library gaps and two absences in the language itself, and version 3.2.0 struck
the last of them; it is in
[`doc/history.md`](history.md#what-a-daily-program-could-not-reach-for-and-now-can)
now, because a list with nothing open in it is a record rather than a queue.

That is not the same as *nothing*. It means the next entry will come from
somebody writing a program and finding it hard, rather than from somebody
reading this list — which is how every entry that closed well got here. Two of
the eight rows said why they were blocked and both reasons turned out to be
wrong, and the two most carefully argued entries each hid something a probe
found in an afternoon. A row here should be a report, not an estimate.

**Thirty-one modules exist** — eight conforming and twenty-three dialect,
listed by name in `README.md`'s module table.

## What would make this easier to work on

**Nothing this page has thought of, again.** The chapter that stood here
listed five things someone *working on the compiler* did not have — a
formatter, a profile, a diagnostic that is not an error, four blind spots, and
a suite that took too long. All five are closed and it is in
[`doc/history.md`](history.md#what-would-make-this-easier-to-work-on) now,
with what each closing found.

Two of those findings belong here rather than there, because they are about
how this page should be written.

**A number needs a date *and* a command.** The suite item said 262 seconds, and
every word of it was true of a configuration nothing used: it was measured
serially, while CI had run `-j"$(nproc)"` on every push since the workflow was
written. The figure had a date, had been re-measured twice after an earlier
round of six wrong figures, and was still wrong — so the rule this chapter
gave itself was not enough. What closed it was a flag worth 3.4× (ADR-0281).

**An item can be re-scoped by measuring it rather than by arguing about it**,
and two of the five were. `--dump-uses --at line:col` was asked for and the
measurement closed it the other way: the flag saves no compiler time, and
narrowing the query would have cost the per-document cache that took five
hovers from 795 ms to 159 (ADR-0276). The `protected var` warning found 81
real sites and was still not built, because §6.6.3.6's congruity makes the fix
illegal for a routine passed as a procedural parameter and no one component
can know whether an exported one ever is.

**What is left of the chapter is two named things** — it was three until
ADR-0283 — each recorded where it was declined rather than left as an estimate
here:

- ~~**A warning for a `var` parameter never written through.**~~ **Built**
  (ADR-0283), and the estimate above it was wrong in the direction this
  chapter's own lesson predicts. It said 111 sites and 81 after `Protectable`;
  the deferral it asked for was built exactly as described, and then the
  *number* turned out to be a fixed point rather than a count. §6.5.1 exempts a
  protected formal from being threatened, so protecting one parameter stops its
  callers' arguments from being threatened and exposes the next layer: one pass
  over this tree reports 130 and seven passes report zero, having added
  `protected` **54 times**. A one-shot count under-reports by a factor of five.
  Every round rebuilt clean, which is the evidence the advice was right — the
  word is enforced, so a wrong claim is a compilation error.
- **`textDocument/rangeFormatting`.** The formatter starts at column zero;
  being asked about *part* of a file means telling the printer where its
  indent begins, which is a question about the enclosing structure that only a
  parse can answer. ADR-0253 and ADR-0258 already report the extents.
- **A `style:` gate for the Pascal**, of the kind `git clang-format` gives the
  C. `format-check` proves the formatter *preserves* a program (ADR-0279); it
  says nothing about whether the output is well laid out, and **nothing in
  this tree is formatted by it**. That is a policy this tree has not chosen,
  and choosing it is a larger decision than the gate: it rewrites every Pascal
  source in the repository.

**One is blocked on hardware rather than on a decision.** `benchmark` abstains
on aarch64 and on CI (ADR-0282), so no push is guarded by it; an aarch64
baseline needs an *idle* aarch64 machine, and the shared runner that exposed
the gap is the one place a baseline must not be taken.

---

## The program that would judge the language

**A Language Server Protocol implementation, written in Afterschool Pascal and
for it**, and since v3.1.0 it is *written*: `lsp/pasls.pas` reads `didOpen` and
`didChange`, compiles what it is handed, and answers `publishDiagnostics`,
`documentSymbol`, `definition` and `hover` — every occurrence this language
has, across program-components — and since ADR-0258 `foldingRange` and
`selectionRange`, which are what a *statement's* extent buys. It was written
**here**, which was the whole
condition: a shim in another language wrapped around `pascalc` would have been
a statement about tooling and not about this dialect, and outside ADR-0116's
discipline entirely.

This chapter is kept in the tense it was written in below, because the
argument is what a reader needs and it was made before the outcome was known.
What follows the argument is what actually happened.

It is not proposed as a feature and it is not part of the compiler. It is
proposed as **the caller**, and the reason is ADR-0116's rule taken as far as
it goes. Every feature since ADR-0117 has had to be demanded by something, and
the discipline has held — the one facility that was designed rather than
demanded did not survive contact, and `take` (ADR-0182), `h := nil` (ADR-0202)
and the element walk (ADR-0199) were each shaped by the client written beside
them, sometimes into a different feature than the one that was set out to be
built. But every client so far has been a **library module or a test case**,
and those are small, single-purpose, and written by whoever was already holding
the feature. None of them can answer the question ADR-0109's goal is actually
about.

**What it measures is usability, and nothing here measures usability.** The
gates say whether the compiler is correct. The specification says what the
language is. `tests/spec/` says a clause is honoured. Not one of them can say
whether a program large enough to get tired inside is *pleasant* to write in
this dialect — where the boilerplate collects, which of the three affine kinds
gets in the way, whether `T ! E` and `try` still read well at depth, whether a
module's export list is a help or a chore at the fortieth import, what one
reaches for and finds missing at the moment of reaching. Those are answered by
writing something big, and by nothing else.

**Why a server, and what changing to one gives up.** This chapter proposed a
text-mode IDE in Turbo Pascal's mould from the day it was written, and the
argument for that shape was an **answer key**: [the open questions](#1-the-dialect-has-no-external-authority-and-every-gate-here-is-anchored-in-one)
name the other Pascals as an authority wherever one of them has already
answered a question this dialect is asking, and a Pascal programmer arriving
here already knows that IDE — so *this was easier there* would be a finding
and not a matter of taste. **That is given up, and it is a real loss**: LSP has
no Pascal-lineage precedent, so an ergonomic judgement against it falls back on
expectation, which is the softer evidence the IDE argument was chosen to avoid.
Three things buy it back.

- **No prerequisite.** The IDE could not start until a whole POSIX binding
  landed in front of it — there is still no terminal control anywhere in this
  tree, no `termios`, no `isatty`, no way to read a key without waiting for a
  line, no cursor addressing, no window size — which is a facility built
  *before* the first usability finding arrives, in the practice this entry
  exists to serve rather than break. A server over stdio needs none of it.
  `PasStream` frames the messages, `PasProcess.Capture` invokes `pascalc`,
  `PasParse` reads `file:line:col: error:` back off it, and a server that does
  nothing whatever but `publishDiagnostics` is producing findings on the first
  day.
- **It stresses both live design gaps by construction, rather than by
  argument.** Documents by URI, symbols per file, positions, capability
  records: a heterogeneous container is unavoidable, so the four monomorphic
  containers stop being something this page asserts and become something met
  in the first hour — which is the row [above](#what-each-landed-feature-left-open) and
  the caller ADR-0116 wants for it. And `didChange` arriving while a compile is
  in flight, with request cancellation, is **exactly the sentence** the
  concurrency row [below](#where-the-ideas-come-from) says no program here has
  yet said: a slow client not slowing the others.
- **It has an external authority**, which is the one thing open question §1
  says the dialect structurally lacks. The LSP specification is third-party and
  versioned, and there are independent clients that disagree with a server
  objectively. It answers nothing about the *language* — the specification is
  about a protocol — but the program judging the language is then held to
  something this project did not write.

  **That argument went unredeemed for six increments and is redeemed now.**
  Every session in `lsp/sessions/` is a golden written here, which is the
  *"a golden agrees with whatever wrote it"* blind spot this project is most
  careful about everywhere else — so the one thing LSP was chosen for was the
  one thing not being collected. What redeems it is **Microsoft's own
  `vscode-jsonrpc`**, the reference implementation of the wire protocol that
  VS Code itself uses, driving the server as a client: initialize with a real
  capabilities object, `initialized`, `didOpen`, diagnostics received,
  `definition`, `hover`, `documentSymbol` with hierarchy, `$/cancelRequest`,
  pipelined requests, positions past the end of a document and of a line, a
  method the server does not implement, `shutdown`, `exit`. **Zero connection
  errors and zero unhandled notifications**, across every probe.

  The sharpest result is ADR-0237's, and it is the one no golden here could
  have produced. Given a line where an astral pair and an accented letter
  precede an identifier — byte column 20, UTF-16 column 17 — the server
  answered **17** under `utf-16` and **20** under `utf-8`, against expectations
  the *client* computed from the document. A reading this project made about a
  protocol it does not own is now confirmed by an implementation it did not
  write. That is what open question §1 asks for and had never had.

~~**One hazard, and it is the sharpest edge in the idea.**~~ **Answered, and
the text model came through it** (ADR-0237). LSP positions are **UTF-16 code
units** by default; UTF-8 is negotiable since 3.17 and not guaranteed. AP
6.4.15 refuses an integer index outright and makes an element an extended
grapheme cluster, and `PasUnicode` offers a scalar view — so the protocol's
unit is a **third** one, and this page said nothing in the text model answers
in it.

**Half of that was wrong, and it is the useful half.** The index is refused and
always will be, but the *count* the protocol wants never needed one: a scalar
below U+10000 is one UTF-16 code unit and one at or above it is two, so
`PasLspDiag.Utf16Column` is a walk over `PasUnicode.NextScalar` and nothing
else. The externally specified stress test of AP 6.4.15's central choice was
run, and what it found is that refusing the index cost this nothing — the
scalar view was the right thing to have exported, and it was exported for a
different reason (ADR-0199).

**What the exercise did produce is a decision the plan had not seen**: the
encoding must be *negotiated* rather than converted to. Under `utf-8` the
compiler's own column is already the protocol's, so converting it would be the
defect and not the fix — and a client that offers `utf-8` is the common case in
practice. The server takes it when offered, echoes what it took, and converts
only under the default.

**What is already in hand**, which is more than one would guess: `PasStream`
and `PasFile` for the files, `PasProcess.Capture` for invoking `pascalc`,
`PasParse` for reading the diagnostics back off it, `PasVector`, `PasList` and
`PasMap` for the tables, `owned ^T` and `take` for a document store whose
entries are replaced rather than copied (ADR-0181, ADR-0182), and `utf8(n)` for
the content — which would be the text model's first client outside a test.
~~**One library gap is visible before starting**: there is no JSON anywhere in
this tree~~ — `PasJson` (ADR-0217), and it took two decisions this paragraph
had guessed wrong.

**And a second gap this paragraph did not see**: it says `PasStream` frames the
messages, and `PasStream` cannot. A message is `Content-Length: N` and then
exactly N bytes, so the header is line-oriented and the body is not — a reader
that has just consumed a header line is usually holding the first bytes of the
body, and nothing that reads *lines* can hand those back. `PasLsp` (ADR-0218)
is the buffer between `PasIO`'s byte reads and the frame, and it is what the
sentence should have said.

**The first increment is written** (ADR-0236). `lsp/pasls.pas` holds documents
by URI, writes the one it was asked about to a scratch file, invokes `pascalc`
on it and publishes what came back — `initialize`, `didOpen`, `didChange`,
`didClose`, `shutdown`, `exit`, and `MethodNotFound` for every other request.
It lives in `lsp/` and not in `tests/` because a server has to be a binary
someone can point an editor at, which is what makes the external authority
above real rather than theoretical; `lsp/build.sh` produces one and
`lsp/run.sh` replays recorded sessions against it as the `lsp-server` case.

**And the second method is answered, which is where the chapter first reached
the compiler** (ADR-0239). `textDocument/documentSymbol` is an outline, and
this compiler had nothing structured to say about a program that was not
`--dump-sema` — a format ADR-0085 demoted from a specification to a debugging
aid on the day there was no second front end to diff it against. So the choice
was between a server that parses Pascal-shaped debugging output and a compiler
that answers the question, and it is the second: `--dump-symbols` writes every
name a source declares with its kind, position and depth, in **Pascal's**
words rather than the protocol's numbers. `--dump-dispatch` (ADR-0229) and
`--dump-layout` (ADR-0185) are the precedent; what is new is that the caller is
not a gate. The flag stops after the *parse* on purpose — an outline is what an
editor draws while the file is wrong — which also means it needs no `--import`,
so this is the one question about a source that can be asked of the file alone.

~~**The next method is the one that will decide whether that surface
generalises.**~~ **It does, and the two methods turned out to be one**
(ADR-0246). Hover and go-to-definition want a *type* and a *defining point*,
which are Sema's and not the parser's — and Sema knows both at the same
moment, so `--dump-uses` carries them on one line and answers both. The shape
is `--dump-symbols`'s unchanged: the compiler in Pascal's words, the server
holding the protocol's table.

**What each had to say about a file that does not check** is the part the
record above declined to settle, and the answer is the opposite of the
outline's. `--dump-symbols` stops *before* Sema, so a wrong file still
outlines; a defining-point cannot do that, so `--dump-uses` is the one dump
**not guarded by `errorSeen`** and carries on instead. Sema accumulates its
diagnostics rather than stopping at the first, so a source with three mistakes
has resolved everything else correctly — and an editor asks where a name is
declared exactly while the file is being edited into shape. Two answers, one
requirement, reached from opposite ends of the pipeline.

**It also crosses a file, which is what the method is worth having for.** A
`file <index> <path>` table heads the dump, the imports come from the same
`.components` walk the diagnostics use (ADR-0238), and the name a reader does
not already know is exactly the one declared somewhere else.

### The first findings

The roadmap says the product of writing this is the list of what it demands.
Twenty-six entries so far, and **seventeen of them have been acted on** — three
of the nine open are the usability findings below, which are recorded rather
than acted on because each names a design question and not a defect — which
is the discipline this chapter is for: a finding recorded and left is a finding
wasted, and the rule that made the first one actionable was this section's own
— one site is an anecdote, two are a demand (ADR-0116).

**The seventeen that closed are in
[`doc/history.md`](history.md#the-language-servers-findings-as-they-were-recorded)**,
each with what closing it found. The shape of that list is the argument for
the chapter: five of the twenty-six were **bounds** — 8 imports, 24 arguments,
a 63-character key, a 255-character line, a 16 384-byte capture — and every
one of them was chosen by counting what the largest thing in the tree needed
at the time. The largest thing in the tree was a test case.

### The usability findings, which took a deliberate pass to get

**Twenty-three findings and not one of them was about *usability*, which is
what this chapter said it was for.** Every one was a capability finding — a
bound too small, a routine absent, `getpid` missing, a compiler that did not
record a position. Those are *X was not there*; this chapter asked *Y was
unpleasant*, and named four questions: where the boilerplate collects, which
of the three affine kinds gets in the way, whether `T ! E` and `try` still
read well at depth, and whether a module's export list is a help or a chore at
the fortieth import.

The reason is structural rather than flattering. Each increment was
feature-driven and recorded what **blocked** it, because a block stops you and
an annoyance does not — so the method this chapter proposed is biased toward
capability gaps by construction. Getting the other kind took reading the
finished program as a *reader* rather than as its author, which is a different
activity and had never been done. Three came out of one pass.

- **The dialect's error-handling constructs are unused by its largest
  client.** `lsp/pasls.pas` is 1 944 lines and contains **no `T ! E` and no
  `try`** — not one of either. It is not that the library withholds them:
  `PasIO.OpenRead`, `ReadInto` and `WriteFrom`, `PasFS.Info`,
  `WorkingDirectory`, `LinkTarget` and `TemporaryPath`, and `PasJson`'s parse
  all answer a fallible-type, and the server imports all three modules.

  What it reaches for instead is the **accessor**: `IntOr` sixteen times,
  `JsonIntegerOr` and `LookupOr` three each, `PathOr` once. Twenty-three calls
  against zero. The cause is that `try(x)` propagates by *leaving the routine*
  (AP 6.8.9), which is right for a program that may fail and wrong for a
  server, which must answer something to every request — so the library grew
  `…Or(r, whenBad)` and the client uses that.

  **This entry first said the helpers exist because a routine generic over the
  fallible type cannot be written. That was wrong, and the correction is the
  more useful finding.** It can be written, and
  `tests/dialect/generic_fallible.pas` is it: one
  `ValueOr(T: type; res: Fallible(T); whenBad: T): T` serving four types, two
  of them structured. What cannot be written is the *anonymous* form — a
  heading saying `res: T ! Code` is a type-denoter that is not a type name,
  and §6.4.1 makes each of those denote a type of its own, so it never matches
  the caller's. A **schema** answers, because §6.4.7 interns a production per
  tuple (ADR-0039), and a named production is the same type as the schema
  applied again — which is exactly the shape `lib/` already uses for its
  result types.

  **So the language is not the blocker, and why the library does not do it is
  the real finding.** Five of the helpers are genuinely `T ! ErrorCode → T`,
  and all seven result types in `lib/` share that shape, so one generic would
  serve them all — but the call site goes from `IntOr(r, 0)` to
  `ValueOr(integer, r, 0)`, naming a type the argument already knows.
  Collapsing five helpers into one would make **thirty call sites** wordier in
  order to make one library smaller. The helpers are not a workaround for a
  missing generic. They are a workaround for **missing inference**, which is a
  row this page already carries and which now has a measured caller rather
  than a hypothetical one.

  (The nine counted here were also two patterns and not one: `JsonIntegerOr`
  and its neighbours read a scalar out of a `JsonPtr`, and `LookupOr` takes an
  environment default — neither is a fallible accessor at all.)

  This is not an argument against `try`. It is the finding that **the shape a
  server needs is the one the language does not have**, and that the shape it
  does have has never been exercised at depth by anything here — so the
  question this chapter asked about `T ! E` reading well at depth is still
  unanswered, and now for a stated reason.

- **`only` is a collision workaround, not a narrowing tool.** The server
  imports **twelve** modules — the roadmap said ten, and it grew — against
  export lists that reach 49 names (`PasJson`), 24 (`PasFS`) and 16
  (`PasIO`). Both of its §6.11.3 `only` clauses are there because two modules
  export the same spelling: `PasDir` exports `Close` and `NameMax`, which
  `PasIO` and `PasJson` also export, and `PasParse` exports `ResultText`, and
  so does `PasError`. Neither `only` narrows for the sake of narrowing; each
  enumerates what the client wants from the *colliding* module so the other
  one's spelling survives.

  At twelve imports that is an annoyance with a workaround. It is worth
  recording because it **scales the wrong way**: collisions grow with the
  product of the export lists, `only` is per-import and enumerative, and the
  alternative the standard offers — `qualified` — makes every use of that
  module wordier rather than the one that collides. The answer this chapter's
  own practice suggests is to write the fortieth-import program before
  designing anything, and there is not one.

- **A comment in the client is the third finding and needs no prose here.**
  `MapKey` is 63 characters, so the document store is a vector searched
  linearly; `JsonLine` is 255, so a URI is held as a line. Both are already
  entries above. What the ergonomic pass adds is that the *reason* they are
  tolerable is the same reason `…Or` is: the program is small enough that
  linear search and a per-type helper cost nothing. **None of these three
  findings would have been found by a program that was merely correct.** They
  were found by asking what writing it was like, which is what this chapter is
  for and what it had not done.

The six below are what a program of this size still runs into. Two of them are
bounds that have not yet cost anything, one is a rule about the language a
writer has to know and nothing tells them, one is a limitation of the parse
tree, one is a clause that reads like a readiness test and is not, and one is
a decision nobody has asked for twice.

- **A program may not mix `writeln` with a descriptor write.** `output` is
  buffered and `PasIO.WriteText` is not, so the two appear in an order that
  depends on when the buffer flushes, and neither standard gives a program a
  `flush`. A program that speaks a descriptor protocol has to say *everything*
  that way, including its own diagnostics — which is what
  `tests/dialect/lib_lsp.pas` does and says at the top. Nothing is wrong here;
  it is a thing a writer has to know and nothing tells them.

  **The server closed this one by construction rather than by care.**
  `lsp/pasls.pas` declares *no program-parameters at all*, and §6.9.1 makes the
  default file of `write` a program-parameter — so a stray `writeln` in it is a
  compile-time error and not a corrupted frame. The discipline is enforced by
  the compiler; the finding stands for every other program that speaks a
  descriptor protocol.

- **`PasContainer`'s map cannot key on a URI.** `MapKey` is 63 characters and
  `file:///home/someone/projects/afterschool_pascal/selfhost/apfront.pas` is
  69, so the document store is a vector searched linearly. The example that
  stood here was 44 characters and fitted, which is worth saying rather than
  quietly replacing: the finding was true and the illustration of it was not,
  and nothing in this tree can check an arithmetic claim made in prose. For a
  handful of open documents that costs nothing and the workaround is fine; the
  finding is that the container's one dimension was sized for a test case's
  keys and nothing said so.

- **`JsonLine` is 255 characters and a URI is not a line.** Three modules pick
  255 for "a string a caller hands over in one piece", which is right for a
  message and wrong for an identifier that happens to be a path. The server
  uses `JsonLine` for its document key *deliberately* — `DiagPublish` takes
  one, so a URI the server could hold and that module could not would be a
  truncation at the boundary instead of a refusal at the door — and reports and
  ignores a document whose URI is longer.

- **A bindable file cannot cross a parameter**, which came out of fixing the
  above and is open. §6.4.1 makes `bindable` part of a *variable-declaration*
  and not of a type-denoter, so no formal parameter accepts one: `var f: text`
  compiles and `bind(f, b)` inside is then refused, *"only a variable whose
  type-denoter says 'bindable' can be bound to something outside the
  program"*. The cost is real and small — a check five routines need must be
  written once per routine, or the routines must be restructured so that one
  of them holds the file, which is what `lib/pasfile.pas` now does. What it
  would take to close is a decision about what a callee may do to a caller's
  binding, and nothing has asked for it twice.

- **The compiler does not keep the spelling a programmer wrote.** Not a
  defect and not a gap — the lexer case-folds an identifier and the string pool
  holds one copy, which is the whole of what makes `CaseTest` and `casetest`
  one name. It is here because an outline is the first thing that ever wanted
  the other spelling back, and the answer shows what a compiler's report is
  for: `--dump-symbols` gives a position and a length beside the folded name,
  and the caller holding the document slices the written spelling out of its
  own copy. Retaining both in the pool would have moved the one array whose
  headroom this tree measures (ADR-0126) for a display string. **The parse tree
  has no *extent* either** — a declaration's start was recorded and its end was
  not, which is why `range` and `selectionRange` were both the name. **That is
  closed** (ADR-0253): `ParseBlock` records the position past its closing
  `end`, `--dump-symbols` writes it, and a procedure's range now reaches its
  `end` where its `selectionRange` stays on the name. **And so is the other
  half** (ADR-0258): a statement carries its own extent, `--dump-stmts`
  reports it, and the server answers `foldingRange` and `selectionRange` from
  it — so expanding a selection steps outward through nested statements
  instead of jumping to the declaration.

  The answer did **not** have the same shape, which is the part worth keeping.
  A block ends at the token *past* its `end`, and that is right because the
  token there is the `;` or `.` immediately after it. A statement is followed
  by `;`, `end`, `else`, `until` or `otherwise`, routinely lines later and
  with comments between — and a comment is not a token, so the same convention
  would swallow whatever a reader wrote after the statement. A statement had
  to end at its own last token, and the token record could not say where that
  was: `len` is a length in the string *pool*, zero for most tokens and
  different from the source length for a literal. The token gained an end
  column before a statement could have an extent. Both wrong answers are
  staged as mutations and each is caught twice.

- **`binding(f).bound` is not a readiness test, and reads exactly like one.**
  `doc/implementation-defined.md` E.16 binds a variable when the external name
  *exists*, so a file about to be created reports `false` and one already
  written reports `true` — the opposite of what a "can I write here?" check
  wants, in both directions. The first `WriteScratch` asked it and refused to
  write anything at all. The register says so and the compiler's own `BindTo`
  does not ask; nothing else does either, which is why it survived to be met
  by the first program that needed it.

**The IDE is not struck; it is later.** An editor wants a language server
inside it, so server-first is the right order even if both are eventually
written — and the terminal binding the IDE needs is small and obviously shaped
(a `pasx_` binding in `runtime/pasrt_posix.c` bounded by its headers, with
`<termios.h>` joining ADR-0186's catalogue) whenever something asks for it.

Everything after that is unknown on purpose. **The list of what this demands is
the product of writing it**, and enumerating it here would be designing
features without a caller — which is the practice this entry exists to serve
rather than to break.

### MCP implementation — **built** (ADR-0241), and now **in use here**

**A short-term goal, and it is met**: the MCP server runs as this project's own
development tooling. `.mcp.json` in the checkout declares it, `lsp/mcp.sh` is
the stable command it names — finding a compiler in the build tree or on
`PATH`, building the server if the binary is missing or older than its sources,
and execing it with `--mcp` — and an agent working on this repository can then
ask `outline` where something is declared and `diagnostics` what the compiler
makes of a file, without shelling out to either.

It is a launcher and not a CMake target on purpose. `lsp/build.sh` says why a
server is a script rather than a build product — a server wants a binary a
*user* can point an editor at, not one buried in a build tree — and that
decision is worth keeping; what an agent needs is a stable *command*, which is
a different thing and is what the launcher supplies.

**Why this is a goal and not a convenience.** It closes the loop this chapter
is about from the other end: the program written to judge the language becomes
a program the people working on the language use every day, which is the only
way a tool's own rough edges get found. It is also the first time anything in
this tree is a *client* of the dialect during development rather than a
subject of its test suite.

The same binary answers MCP over stdio when given `--mcp`: one JSON message to
a line instead of `Content-Length`, with two tools built on `--dump-symbols`
and on a compilation. It was recorded here before it was started, with a
prerequisite in front of it and an expected finding named in advance, and both
did their job — so the entry as written, against what actually happened, is in
[`doc/history.md`](history.md#a-second-transport-over-one-program). Nothing
about it is open.


---

## Where the ideas come from

Rust, Swift and Zig are the reference points, and they do not all fit equally:
Pascal's grain is value semantics, explicitness and a small orthogonal core,
which is close to Zig and Swift and further from Rust. Each borrowing is tied to
the open decision it would settle.

| Idea | From | Settles | Where it stands |
| --- | --- | --- | --- |
| Slices — a pointer and a length | Zig, Rust | bounds safety | **Done** (ADR-0125, ADR-0129) |
| Optionals, and no bare null | Swift, Rust | pointer safety | **Done** (ADR-0123); the check is localised to `^`, not eliminated |
| Scope-based release | ISO 7185, Rust's `Drop` | lifetime | **Done, and it was already here** (ADR-0151) — for a *declared* variable. A created one had no owner until ADR-0181 |
| ~~An owning pointer~~ | Rust's `Box` | lifetime, for the heap | **Done** (ADR-0181, AP 6.4.14): `owned ^T` disposes what it identifies when its own variable dies, and cannot be copied. Reached from the file variable rather than from Rust, and it decides nothing about aliasing because it admits no second name |
| ~~A move~~ | Rust's `mem::take` | what an affine type needs to be usable | **Done** (ADR-0182, AP 6.4.14.6): `take(v)` empties a variable and yields what it held, in the one position an owned value may be assigned. Found by writing the client: without it push-front and pop-front are each two copies, so an owned chain had no constant-time operation at all |
| Explicit allocator passing | Zig | part of memory safety | **Tried; does not survive contact** (ADR-0116) |
| ~~Error unions / `Result`~~ | Zig, Rust | error handling | **Done** (ADR-0176, AP 6.4.13): `T ! E` is the result record ADR-0120's convention described, written by the compiler with the field names fixed |
| ~~An early exit~~ | Turbo Pascal, Delphi, FPC | what propagation stands on | **Done** (ADR-0177, AP 6.7.5.9): `exit` terminates one activation, `exit(e)` assigns the result first. The first borrowing here whose source is another *Pascal* rather than another language, and the row below is the second |
| ~~An early loop exit~~ | Turbo Pascal, Delphi, FPC | nothing structural — an ergonomic gap | **Done** (ADR-0208, AP 6.7.5.10 and 6.7.5.11): `break` leaves the closest-containing repetitive-statement, `continue` completes the current iteration of it. Taken whole from the three dialects that have it, down to the spelling and to leaving *one* loop rather than a named one. It settles no open decision, which is what makes it the plainest case in this table of the argument [above](#1-the-dialect-has-no-external-authority-and-every-gate-here-is-anchored-in-one): a question the standards do not answer and three Pascals answer alike is one where novelty would be a cost with nothing to show for it. It cost two branches — the blocks were already there, and AP 6.9.3.11 NOTE 2 already said what an armed statement does when a sequence is left by a jump |
| ~~Propagation~~ | Zig's `try`, Rust's `?` | the rest of error handling | **Done** (ADR-0178, AP 6.8.9): `try(x)` yields the value or leaves the enclosing function with the cause. Spelled as a required function because no position would serve — see below |
| ~~`defer`~~ | Zig, Swift | resource safety | **Done** (ADR-0175, AP 6.9.3.11): `defer S` arms a statement, executed when the statement-sequence it stands in is completed or when the activation terminates. Zig's unit rather than Go's, because a per-activation defer runs a loop's `dispose(p)` once with the last `p` |
| Unicode-correct `String` | Swift | the text model | **Done**, entirely — ADR-0189 – ADR-0193, then ADR-0196 and ADR-0199; the row in [the goal's table](#the-goal-adr-0109) is what the increments were and what each cost, and this one is only about the borrowing. The grapheme as the unit and the refusal of an integer index are Swift's and are taken whole. Its *storage* is not: Swift's `String` is a reference-counted heap buffer, which is the construct ADR-0151 says forces the aliasing decision, so this is a value with a declared capacity instead — and that in turn is what makes normalise-on-construction affordable, which Swift cannot do and which buys a bytewise `=` |
| ARC | Swift | aliasing | **The question is withdrawn** (ADR-0201). ADR-0117's containment fixes what `^T` means, and ARC changes it — so the candidate cannot reach the only reference type an ISO program has |
| Ownership and borrowing | Rust | aliasing | **The same, and half of it is already here**: a `var` parameter of an owned value's referent is a borrow, and it cannot escape because there is no address-of and `new` is the only producer of a pointer. Not checked — *unformable*, which is stronger and free (ADR-0201) |
| Traits / protocols | Rust, Swift | abstraction | **Later**, and the reason given here has since become half-true rather than true. Schemata gave parametric types over a *value* (ADR-0039); ADR-0209 lets a discriminant name a **type**, so `Vec(T: type; cap: integer)` is a container written once. What that does not give is a routine over one — see [the row above](#what-each-landed-feature-left-open) — and abstraction over *behaviour* is a further thing again, which nothing has asked for |
| `comptime` | Zig | metaprogramming | **Later.** Constant-expressions everywhere (ADR-0054) is as far as anything needs |
| Actors / `Send`+`Sync` | Concurrent Pascal, Ada, Swift, Rust | concurrency | **Unblocked and unbuilt** (ADR-0201). It unblocks nothing, the two rows above having been answered without it; what it does is *end* the sentence the rest rests on — a borrow cannot outlive a call because the caller is not running during it. So the construct must be **share-nothing**, a task owning what it is given, and the lineage to read is Pascal's own rather than Rust's: Concurrent Pascal had `process` and `monitor` in 1975. Not built, for ADR-0116's reason — nothing here wants it. **This row named its trigger and the trigger came and went in two days.** ADR-0201 said "a socket module serving more than one client is what would demand it, and `select` is the cheaper answer to try first"; ADR-0203 landed the module and ADR-0205 made it serve many, with `poll` and no construct at all. The cheaper answer was tried first and was enough, which is what ADR-0201 asked for. What a thread would still buy is a **slow client not slowing the others** — a different sentence, and one no program here has yet said. **A program that would say it is now named**: the [language server](#the-program-that-would-judge-the-language), where a `didChange` arrives while a compile is in flight and a cancelled request has to stop something already running. **The candidate is now written and the row still does not move** (ADR-0236): `lsp/pasls.pas` exists, and it compiles *synchronously* — it writes the document to a file, waits for `pascalc`, publishes, and only then reads the next message. **And it has now been measured, which this row asserted without doing** (ADR-0252). Against `selfhost/apfront.pas` at 22 900 lines, driven by an independent client: one hover 159 ms, five sequential hovers 795 ms, five *pipelined* hovers 800 ms — so pipelining buys nothing and the server is serial, as this row said — and a `didChange` arriving behind work in flight waited **933 ms**. But the larger number was not concurrency at all: five hovers on unchanged text cost five compilations, and caching the answer against the document took that 795 ms to **106**. The cost a reader actually pays fell 7.5× with no construct. What is left is the 933 ms, and the *second* cheaper answer in front of it has now been costed rather than waved at. The sketch was: this server already has `PasNet.Wait` over `poll` (ADR-0205), so a `Capture` polling the child's pipe **and** standard input could abandon work a newer message has made stale, single-threaded, which is what most language servers do. **What stops it is ADR-0174's own decision.** `PasProcess.Pipe` is `handle external 'pclose'` — an *opaque* handle, which is what made binding `popen` safe and what means no program can get a descriptor out of one to poll. `Collect` reads with `fgetc` on that handle, so there is nothing pollable anywhere on the Pascal side. Three routes and only one is small: a `pasx_` routine that polls on the far side, where the runtime holds the `FILE *` and can `fileno` it — no new headers, `<stdio.h>` being ISO C — keeping the handle opaque, which is right; exposing the descriptor, which breaks the opacity that made the binding safe; or `fork`/`exec`/`pipe`/`waitpid`, which is a large new POSIX surface for one caller. Even the small route needs `Collect` restructured to read incrementally and a server that can decide what "stale" means and abandon a child, so it is *cheaper than a construct* and not cheap. It stays unbuilt under ADR-0116: what a reader actually pays fell 7.5× without it. This row has now been answered by a cheaper thing twice — `select` for the sockets, a cache for the hovers — and the rule it is teaching is worth more than the construct: **measure the cost before naming the mechanism**, because twice the expensive-looking sentence was not where the time went **A fourth cheaper answer has now landed and this row is closed for the foreseeable** (ADR-0257). The server drains the messages that have *arrived* -- never waits for more, which would be a policy about a client's typing speed rather than a fact about the queue -- and keeps only the last `didChange` per document, a keystroke carrying the whole file. Measured: four queued edits of `selfhost/apfront.pas`, **780 ms to 340**, five `publishDiagnostics` to two, and the change a reader is waiting for compiled first rather than fourth. No construct, no compiler change; `pasx_fd_ready`, `PasIO.FdReady` and `PasLsp.LspPending` are the whole of it, and `<poll.h>` was already catalogued. **And the remaining work now has a number against it rather than a sketch.** What the drain cannot abandon is a compile already in flight -- one compilation, about 170 ms, once at the end of a burst. The cheapest route named above needs the pipe unbuffered, because a `FILE *`'s buffer is libc's and neither ISO C nor POSIX will say how much it holds -- ADR-0205's decision 4 a third time, with no counter available. Measured on the dump a hover actually reads, 1 555 350 bytes: **5 ms buffered, 621 ms unbuffered**. The cheap-looking route would cost 124 times what it could save, on the operation a reader performs most; the correct route is the other one, moving the buffer into C as `struct pasx_socket` does, and it stays unbuilt under ADR-0116. So the rule this row teaches has a fourth confirmation and a new face: three times the expensive-looking sentence was not where the time went, and this time **the cheap-looking route was the expensive one** |

Two conclusions worth stating:

- **The cheap items are not the small ones.** `defer` and error unions between
  them cover most of what "daily practical development" means, and neither
  required settling the memory-safety fork. Both are done (ADR-0175,
  ADR-0176), and the second was cheaper than this table predicted: it was
  expected to be "the larger of the two — a type constructor over a type", and
  it turned out to need no new type at all. `T ! E` denotes an ordinary record
  with a flag on it, so the copy, the layout and ADR-0118's trap came free and
  **CodeGen was not touched**. The lesson is ADR-0122 and ADR-0123's, a third
  time: an estimate that assumes a feature needs its own machinery is worth
  probing before it is believed.

- **Error handling is finished**, and it took three records rather than one.
  `T ! E` says what a failure is (ADR-0176), `exit` is how a block is left
  (ADR-0177), and `try(x)` connects them (ADR-0178). The two questions this
  entry said `try` still had to answer both got answers worth keeping. *What
  must the enclosing result type be?* — nothing in particular: the cause has
  only to be assignable to it, which the assignment already decides, so a
  function answering the error type takes the cause directly and the question
  dissolves. *Is there a spelling a conforming program could not have
  written?* — **no**, and that is the finding. ADR-0176 had sketched `try X`
  by the rule that works for a statement; a factor may be a variable-access,
  so `try (x)`, `try [x]`, `try + x`, `try - x`, `try.f` and `try^` all mean
  something to a program that declares `try`. It is a required identifier
  instead, which is `exit`'s answer and now the commoner of the dialect's two
  spelling shapes.

- **`exit` cost less than the table above expected, and for the third time the
  reason was the same.** It is a branch to the epilogue every block already
  had, so the armed statements, the files and the result all came free — the
  same shape as ADR-0176's "no new type" and ADR-0123's before it. What was
  *not* free was a gate: `exit(e)` can only stand in a function-block, and
  `predicate-callers`'s probe program declared its subject as a procedure, so
  the position had to be given a function to live in. A gate that would have
  passed for the wrong reason is worth more attention than the feature was.
- **ARC and borrowing are not equally costly here**, and the difference is not
  only effort: borrowing would make ADR-0108's C++ mirror prohibitively
  expensive and likely force the decision to freeze it. ADR-0151 declines to
  decide on that — cost is a reason to prefer one, not evidence about which the
  language needs.

One option was **closing** as the language diverges — a third-party
differential can only ever check the ISO 7185 core, because nobody else
implements this dialect — and it was taken for that reason (ADR-0234). It
checks 103 of 244 cases with a golden today and will check fewer next
release.

---

## The open questions

Seven structural questions about the dialect and five items of *what is next*
used to stand here. **Eleven of the twelve are answered** — the table at the
end says where — and what each found on its first run is in
[`doc/history.md`](history.md#what-the-roadmap-answered). **One remains, and
it is not a task**: §1 is a standing risk no record can close, which is why it
is first — it is read every time and finished never. §2 was the last of the
tasks and is done (ADR-0234). §4 was opened and answered on one day, by the
route its own entry records: it is what was left when a limitation written
here turned out to be a misreading (ADR-0214, ADR-0215).

**Version 3 made §1 heavier and §2 more urgent**, which is the one thing to
know before reading them: ADR-0232 removed the conformance modes, and with
them the BSI suite and `difftest` — the whole of §1's second column and the
premise of §2. Neither entry gained a new problem; each lost what partly
covered it, and §2 was then taken *because* it was shrinking. It bought §1 a
row back, and not the two it lost.

### 1. The dialect has no external authority, and every gate here is anchored in one

A standing **risk** rather than a task, and the one entry no record can close.

The table used to have three columns — ISO 7185, Extended Pascal, the dialect —
and the whole of what ADR-0232 did to this entry is collapse it into the last
one. The two struck rows went with the conformance modes they were about.

| | this language |
| --- | --- |
| ~~third-party corpus~~ | **—** (BSI, 812 programs, until ADR-0232) |
| ~~second implementation (`difftest`)~~ | **—** (`src/`, the refusal surface only, until ADR-0232) |
| clause-cited scenarios | yes (ADR-0135) |
| independent reading | [the spec](afterschool-pascal-spec.md), audited once (ADR-0144), by readers isolated since ADR-0228 |
| goldens, irtest, `llc`, `verify/` | yes |
| a published third-party answer | Unicode's own conformance files, for AP 6.4.15 alone (ADR-0189) |
| a second **processor** | Free Pascal under `-Miso`, over the 103 of 244 cases with a golden that it will compile — programs only, never `tests/dialect/` (ADR-0234) |

Every oracle in this repository bottoms out in *this project says X*, and no
oracle here can contradict a **reading** — which is how ADR-0072's set-packing
deviation survived in four documents and a purpose-written test. The remedy is
independent readers (`.claude/skills/langspec-audit/`), and its reach is
narrower than it was: an audit can check every claim the specification makes
*about* the standards — nine were wrong the first time — and cannot check a
requirement this language invents, where a reader can only ask whether the
processor agrees with the document.

**Both empty rows were partly filled once and are empty now**, which is the
thing to carry out of ADR-0232. The BSI suite is unavailable for two reasons
rather than one: it is ISO 7185, which this language is not, and 25 of its
programs use a word-symbol this language reserves, so the corpus cannot be
compiled here at all. `difftest` covered the conformance surface, and there is
none. A high citation fraction means the specification is young and was written
against a compiler someone could probe, not that this language is as well
checked as the conformance modes used to be.

**Two rows have grown since, and neither replaces what was lost.**
`fpc-differential` (ADR-0234) is a second *processor* rather than a second
corpus: it reaches 103 of the 244 cases with a golden, none of them in
`tests/dialect/`, and it is not an authority — it implements neither standard
completely, so a disagreement is a contradiction to be judged and not a
verdict. What it is worth is that a reading now has something that will
disagree with it out loud: three of its six clause-level disagreements
corroborate readings nothing here could challenge, ADR-0073's among them.

The other is `unicode-conformance` (ADR-0189,
ADR-0190) is a published answer nobody in this project wrote, checked against
20 034 normalisation cases and 766 segmentation cases — and it is the shape
worth looking for again: **a facility whose correctness some outside body has
already published**. It reaches exactly one clause. Where a future feature has
such a body — POSIX, the C ABI, Unicode, an RFC — taking its conformance data
into the tree buys more than any gate this project can write for itself.

Two authorities *are* available and should be used wherever they reach: **POSIX
and the C ABI** for anything FFI-facing (the slice's shape was the far side's
choice, ADR-0129), and the standards themselves wherever they answer the same
question differently — ISO 7185 §6.6.3.7's conformant array is the standard's
own answer to the slice's question, found only after the slice had landed
(ADR-0152). A new dialect feature should look for its authority before its
spelling.

**A third is the other Pascals**, and it is worth naming because this entry
reads as though there were none. Turbo Pascal, Delphi and Free Pascal are
*dialects* — none of them implements either standard completely, and each
answered questions these standards do not: an early `Exit`, `Break` and
`Continue`, `try..finally`, a string type that grows. **That list is not
hypothetical, and three of the five have since been taken off it** — `exit`
(ADR-0177), `defer` where those dialects have `try..finally` (ADR-0175), and
`break` and `continue` (ADR-0208) — each spelled the way a Pascal already
spells it, and each argued for in its own record on grounds of its own rather
than by citation. Where one of them has
already answered a question this dialect is asking, that answer is a reference
point: not because it is authoritative — it is not, and two of them disagree
with each other — but because a Pascal programmer arriving here already knows
it, and gratuitous novelty is a cost paid by every future reader.

**And the absence of an oracle is a fact about how a claim is checked, never a
reason not to make one.** This entry is a risk register, not a brake. Where no
authority answers, the dialect answers for itself — reasonably, in the
standards' own idiom, written down in the specification and pinned by a case
that fails without it. That is what every one of ADR-0117 onward did, and the
discipline that matters is internal: a named failing test, a mutation that
kills it, a clause that says what was meant. What this entry warns about is
narrower than it looks — that a *misreading of the two standards* is invisible
here — and it has nothing to say about a facility the dialect invents outright,
where there is no reading to get wrong.

### 2, 3 and 4 — answered

A third-party differential (ADR-0234), mutation testing committed to the tree
(ADR-0207) and *should the dialect read a type off a component?* (ADR-0215)
were the other three questions this chapter carried. Each has a row in
[Answered, and where](#answered-and-where) and its narrative in
[`doc/history.md`](history.md#what-the-roadmap-answered). §1 above is the only
one left, and it is the one no record can close.


---


## Cross-platform support

The repository is developed on x86-64 Linux and **built and tested on aarch64
on every push**, natively, from a seed whose header lines still say x86-64.
That port was measured rather than estimated (2026-08-22), and the lock turned
out to be three things for an LP64 little-endian target — two lines of emitted
text, one size constant, and a seed for the new host — of which the first two
are done (ADR-0155, ADR-0156, ADR-0157, ADR-0159). The measurements are in
[`doc/history.md`](history.md#cross-platform-support-measured); what follows is
what they leave.

**Where every target stands on layout**, from `target-layout`'s own comparison
run by hand over 25 targets rather than the two the compiler admits, on
2026-08-22, against the 4538 offsets there were that day. **Read the
proportions and not the absolute**: the denominator is every field of every
frame the compiler emits for its own source, so it moves with each declaration
added to any of the three program-components. **The gate prints its own count
and this sentence does not**, that number having been quoted here and gone
stale in two days: it said 4999 and the gate says 8955.

**The split is why, and not by adding a declaration.** A module emits the
frame *type* of every frame it can index, which includes the frames of the
modules it imports — a static link is walked across a module boundary and its
layout has to be spelled to do it — while the routines themselves are
`declare`d and defined once. So the three translations emit 85, 487 and 706
frame types against 710 functions defined in total: the counts are cumulative,
and the gate folds roughly 1.8 frames per frame there is. Harmless, the gate
comparing each against every target either way, and worth knowing before
reading the denominator as a measure of the compiler's size.

The comparison has no mode that reproduces itself, so the day it was taken is
part of what it says.

| target | offsets differing | |
| --- | --- | --- |
| aarch64, riscv64, powerpc64le, loongarch64, mips64el | 0 | LP64 little-endian |
| powerpc64, mips64, aarch64_be, sparcv9 | 0 | LP64 big-endian — endianness decides what a byte means, not where a field sits |
| x86_64 and arm64 apple-darwin; x86_64 and aarch64 windows | 0 | Mach-O and COFF agree |
| s390x | **13** | aligns `i256` to 8 where every other target says 16 — ADR-0028's shape exactly |
| i686, arm, riscv32, mipsel, powerpc, x32, … | 3858–3904 | **every 32-bit target** |

### What is left

**32-bit, which is the real work.** `LlSize` says a pointer is 8 by
construction; `tyProc` and `tySlice` are two pointers; `tyFile`'s alignment is
8. All of those become target-dependent, which means `LlAlign` and `LlSize`
stop being constants and start asking the target — and ADR-0129's `i64` count
at the foreign boundary is a second, independent question with a decision in it
rather than a lowering. Nothing here is blocked on measurement any more.

**The rest is small and specific.** s390x's `tySet` alignment (13 offsets, and
`target-layout` fails loudly if it is ever admitted). Windows: `fmemopen` and
`open_memstream` do not exist in the CRT, so `readstr` and `writestr` need two
hand-written `FILE*`-over-memory functions, `access` is `_access`, and MSVC
lacks the `_Complex` §6.7.6.2's functions are written in. **macOS needs none
of it** — the runtime's five non-ISO names are all there — and has never been
tried, which makes it the cheapest unknown in the chapter.

### What is not claimed

**aarch64 works; it is not supported.** No release ships an aarch64 binary,
`seed/*.ll` is generated for x86-64, and `seed/README.md`'s target lock
stands. CI establishes that the port *works* — the seed retargets textually,
the layout rules hold for a second machine, the runtime's constants clear it —
not that an artefact is maintained for it.

**Not every oracle follows.** `llc-second-backend` skips on the arm64 job, and
the SMT proofs are about the lowering *model*, the same file on either machine.
A miscompilation only an aarch64 backend produces has nothing looking for it
(`doc/sop.md` §7).

**The layout gate sees frames and nothing else.** A global's alignment, a string
constant's, and the ABI arguments travel by are outside it.

---

## Known limitations

Things that are wrong or absent today, listed so they are not rediscovered as
surprises. Each is a decision with a record or a piece of work with none yet;
the two kinds are marked.

### Under ISO 7185

- **Nesting deeper than 1000 levels is rejected** (ADR-0020, ADR-0110). A
  limit on the *tree*, protecting four recursive walkers with an order of
  magnitude of headroom against the measured crash point. Legal
  machine-generated programs with chains beyond 1000 terms are refused. *A
  decision.*

- **A variable created by `new(p, c1, …, cn)` may still be assigned or
  passed.** §6.6.5.3 forbids it; detecting it needs the pointer's *value* to
  carry which form created it, and nothing tracks that (ADR-0027). *A decision,
  permissive where the standard is restrictive.*

- **Use-after-dispose through a second pointer is undetected.** `dispose(p)`
  sets `p` to nil, which turns the common form into the nil trap, and that is
  all it does (ADR-0019). *The memory-safety model's aliasing half, above.* The
  dialect's `owned ^T` sidesteps rather than closes this: storage declared that
  way can have no second pointer, so there is nothing to dangle — but §6.4.4's
  ordinary pointer is untouched, and ADR-0181 withdraws nothing.

- **A text file's last line need not end in a terminator.** §6.4.3.5 says it
  does, so one is supplied when the file is read; reading at end-of-*file*
  is D.97's error and stops the program. *A decision (ADR-0021).*

- **Characters are bytes, and the locale is never consulted.** `char` is
  0..255, UTF-8 passes through, a multi-byte character is several `char`
  values. This one is not going to change: ADR-0189 records that `char`
  *cannot* widen without breaking containment, and puts the answer in a type
  beside the string rather than underneath it — `utf8(n)` (ADR-0191).
  *The text model, above.*

- **A set's base type must have its values in 0..255**, every set being one
  256-bit word. §6.4.3.4 leaves the size to the implementation, so this is a
  permitted limit rather than a deviation — but `set of integer` is a legal
  program this compiler refuses (ADR-0028). *A decision.*

- **An identifier may contain an underscore**, where §6.1.3 does not allow
  one. It is how a name that would collide with a word-symbol is spelled, and
  how a test program takes the name of its file (ADR-0072). *A decision, and
  one of the two extensions `doc/implementation-defined.md` §5 lists.*

### Under ISO/IEC 10206:1991

**Bindability is a property of the type-denoter, and two of its three shapes
are still read elsewhere.** ADR-0167's reader found five programs refused by
this; a field or array element of a bindable type can be bound now, and two
pieces remain. *Work with no record yet, and a record is owed before either.*

- **A dereference is answered `bindable` without asking**, so `bind(p^, b)`
  compiles for `p: ^text` as well as for `p: ^bindable text`. A pointer's
  domain reaches Sema through `ResolvePointer`'s deferred paths, where the
  denoter is no longer in hand. `doc/implementation-defined.md` §6.1 carries
  it as a program accepted that the standard requires to be rejected. *A fix.*

- **A `var` parameter of file-type takes its bindability from the actual, at
  run time.** §6.7.3.3 NOTE 1: "determined **dynamically** by the
  actual-parameter", and §6.7.5.6 and §6.7.6.8 make the file case a
  *dynamic-violation*. §6.7.6.8's own worked example, `procedure bindfile(var
  f: text)`, is the program this refuses. A conforming implementation carries a
  bindability word with every `var` file parameter — the seventh thing here
  that travels as two words. *Architectural.*

- **`bind` of a non-file bindable variable** — `var clock: bindable integer` —
  is refused with *'bind' needs a file variable*, and §6.7.5.6's "otherwise"
  branch presupposes it is legal. What binding an integer to an external entity
  means is implementation-defined and undesigned. *A feature, not a fix.*

**~~§6.4.9's type-inquiry-object is a variable-access~~ — it is not, and this
entry was wrong** (ADR-0214). The clause reads `type-inquiry-object =
variable-name | parameter-identifier`, and §6.5.1's variable-name is
`[ imported-interface-identifier '.' ] variable-identifier` — a *name*. So
`type of a[1]`, `type of p^` and `type of r.f` are outside *that clause*, and
refusing them was conformance rather than a gap in it. **Accepting them under
`--std=extended` would have been the defect**, which is the direction this
entry pointed. This language admits them — AP 6.4.9, ADR-0215 — which is a
different thing from having misread §6.4.9, and ADR-0232 removed the mode in
which the distinction was enforced.

It was written from the wish rather than the clause — the wish being to read a
container's element type off its pointer, `x: type of v^.a[1]`, which would
halve the type arguments a generic call in `lib/dialect/pascontainer.pas`
carries. ADR-0047 had quoted the production correctly since the feature landed
and this entry contradicted it for a day; nothing here could see that, which is
the point. What *did* come of it: the three refusals now say which rule they
are, instead of stopping at the declaration's own semicolon and reporting a
missing separator, and the wish itself became a dialect feature the same day
([question 4](#2-3-and-4--answered),
ADR-0215) — which is the useful ending: the clause is unchanged and the thing
that was wanted exists where it belongs.

**A discriminated-schema is not a parameter-form, and this compiler accepts
one** (ADR-0171). §6.7.3.1 admits `type-name | schema-name | type-inquiry`, so
`procedure q(x: string)` is right and `procedure q(x: string(5))` is outside
the grammar. Three sources under `tests/extended/` write the second spelling
and would have to change. **ADR-0232 dissolved half of this**: there is no
conformance mode to refuse it under, so what is left is one decision — admit
it with a clause of its own, or refuse it and edit three sources. It is
exactly the convenience ADR-0109 says belongs here and the spelling already
passes ADR-0140's test, so admitting it is the likely answer. *A feature with
its own record, written down rather than done because refusing it takes
something away from every program that uses it.*

Five more, each stated in the record that made it:

- **String concatenation draws from an arena** — a fixed buffer in the runtime,
  released at the end of every statement that took from it (ADR-0111). One
  *statement* holding more live string values than the arena holds is the
  limit, and both ways of exhausting it are reported. *A decision.*

- **A subrange whose bounds are not constants is refused as a set's base
  type.** `set of 1..m` inside a procedure is legal under §6.2.3.8 b) and is
  refused: a bound the block evaluates cannot be checked against 0..255 before
  the program runs, so it is the `set of integer` limit reached by another
  route (ADR-0028, ADR-0133). Every other dynamic-bound shape — arrays,
  schemata, bare subranges, record fields, file components — works since
  ADR-0127, ADR-0133 and ADR-0134. *A decision.*

- **ExpDigits is not a fixed number** (ADR-0064). §6.10.3.4.1 makes it one
  implementation-defined value; here it is what C's `%E` writes — two digits,
  or three past 1e100. A conforming processor pads `E+00` to `E+000`. *A
  decision, stated as a deviation.*

- **§6.5.6's substring aliasing rule is not enforced** (ADR-0057), for
  ADR-0027's reason: a property of values at run time that nothing tracks. *A
  decision.*

- **Nothing is known and unfixed about conformance** beyond this list. Both
  standards are complete, four adversarial audits have run (ADR-0162,
  ADR-0167, ADR-0168, ADR-0171), and the last seven findings of the fourth
  were closed on 2026-08-23. A claim no test names is a claim nothing checks
  — so the next audit is worth running whenever the list above has not moved
  for a while.

---

## Answered, and where

Every question this file has carried and closed. The narrative of each — what
the survey found, what the estimate got wrong — is in
[`doc/history.md`](history.md#what-the-roadmap-answered); the decision is in
the record.

| Question | Answer | Record |
| --- | --- | --- |
| Does the dialect spend reserved words? | No: a feature is spelled where a conforming program could not have written it. The `reserved-words` gate that enforced it retired with the conformance modes; the rule stands, and now protects this language's own claim to accept every Extended Pascal program | ADR-0140, ADR-0232 |
| Does containment survive the link? | It did, except where the dialect would emit a check the other mode did not — and the mechanism went with the modes. A module's activation names still carry a fixed language tag, so an object from an older release is refused with a message rather than mislinked | ADR-0137, ADR-0119, ADR-0232 |
| Is containment witnessed by more than one program? | It was — the whole of `tests/extended/` compiled a second way, every run — until there was only one way to compile it. `tests/dialect/inherits_extended.pas` is what remains | ADR-0138, ADR-0232 |
| Are the dialect's pieces coherent? | Four result shapes, one rule in two questions; a boundary shape may be a parameter and not a result | ADR-0141, ADR-0149 |
| Do the conformance modes "stay exactly as they are"? | They did, until they were removed. What they accepted never moved for the dialect; then ADR-0232 removed the modes rather than the promise | ADR-0154, ADR-0232 |
| Memory safety: deferral or discovery? | Discovery, twice. Lifetime was already answered, by the file variable (ADR-0151); aliasing was too, by refusal for the three affine kinds and by a **borrow that cannot escape** for the rest — Pascal has no address-of, so no pointer can name what a `var` parameter refers to. What is left of the fork is two threads of control and nothing else | ADR-0151, ADR-0201 |
| A third-party differential | Free Pascal under `-Miso` over every case with a golden, catalogued by which clause decides each disagreement. No defect found here; six clause-level disagreements, all six decided here. It cannot reach the eight conforming `lib/` modules — FPC implements no Extended Pascal module — and it shrinks with every release | ADR-0234 |
| An oracle nobody here wrote | The BSI suite and `src/` as a reference front end — **both retired with the conformance modes they were about**. What is left is `unicode-conformance`, which is a published third-party answer for one clause | ADR-0086, ADR-0108, ADR-0189, ADR-0232 |
| Diverse double-compiling | Run once, 2026-08-18, identical outputs; `seed/ddc.sh`. **The window is closed**: `v0.1.0` has no `--import` and cannot read a compiler that is three program-components | `seed/README.md`, ADR-0233 |
| Should the compiler be one source file? | No, and it had not needed to be since ADR-0053. Three program-components, cut where the file order already was a topological order — 66 `forward` declarations, all inside one stage. The reason is the linking blind spot and not the buffers | ADR-0024, ADR-0233 |
| Conformant array parameters, and level 1 | Done, and the 51 BSI level-1 programs found nine defects in the first implementation | ADR-0153 |
| Can anything measure what the corpus reaches? | Three coverage gates and a clause-cited suite | ADR-0103 – ADR-0106 |
| Mutation testing, committed to the tree | One file per recorded mutation and a harness that runs them; not a `ctest` case, because it edits the tree. A register of demonstrations and not a measurement | ADR-0207 |
| Is the platform lock scoped? | Three things, two done; 32-bit is what remains | ADR-0155 – ADR-0159 |
| Can a conforming program learn that a file is missing? | `binding(f).bound` says whether it is there | ADR-0172 |
| Can a program get its arguments as a list? | `argcount` and `argument(k)`, required identifiers of the dialect | ADR-0173 |
| Can a foreign address be owned? | A handle-type: a file variable for it, released where a file closes | ADR-0174 |
| What is a character, once a byte is not one? | A grapheme cluster; text is UTF-8 in normal form C, in a value with a byte capacity, and `char` is left alone because it cannot widen | ADR-0189 |
| Should the dialect read a type off a component? | Yes: `type of` takes a whole variable-access, so a generic reads an element type off the container it was handed. The substring is the one access it must refuse, and a *result* type is where the widening stops | ADR-0215 |
| What did version 3 take, and what did it leave? | Four proposals: three became records and the fourth dissolved under the first. The one it left open was `src/` — whether the second front end earned its cost — and §0 answered that by removing the surface it was frozen at. The chapter is in [`doc/history.md`](history.md#version-3--what-it-took-and-what-it-left) | ADR-0229 – ADR-0233 |
| What did the language server demand? | Findings enough that the count is kept in one place and not four — [above](#the-first-findings), which had said twenty-one where that section said twenty-six. Five were **bounds**, each chosen by counting what the largest thing in the tree needed at the time, and the largest thing in the tree was a test case. The closed ones are in [`doc/history.md`](history.md#the-language-servers-findings-as-they-were-recorded); the open ones stay [above](#the-first-findings) | ADR-0236 – ADR-0249 |
| Is this a conforming processor or a dialect? | A dialect. `--std` and the two conformance modes are removed, the clause 5.1 a) compliance statement withdrawn, and 25 of 172 ISO 7185 cases became inexpressible — a conforming ISO 7185 program with a field called `value` no longer compiles. Five oracles retired with the surface they asked about. It is what version 3 is named for | ADR-0232 |
