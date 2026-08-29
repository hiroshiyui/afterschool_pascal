# Roadmap

What is open: the goal, what blocks it, the questions no record has answered,
what a redesign would change if one were started, and what is wrong or absent
today.

**How the compiler got here is [`doc/history.md`](history.md)** — the
bootstrap, both standards, the conformance sweeps, the dialect increment by
increment, and since this revision **every question this file has closed**,
with what closing it found. That document is settled and this one is not,
which is why they are two: an entry here is something someone still has to
decide about, and the day it is decided it moves there.

## How to read this

| Chapter | What it holds |
| --- | --- |
| [The goal](#the-goal-adr-0109) | what this is all for, and the four decisions it forces |
| [What blocks the library](#what-blocks-the-library) | the one foreign-interface item a practical library still waits on, and what each landed feature left open behind it — two of those are still open |
| [What a daily program cannot reach for](#what-a-daily-program-still-cannot-reach-for) | the five library gaps still open — JSON was the sixth and is done — and the two deliberate language absences, none of which is a mystery |
| [The program that would judge the language](#the-program-that-would-judge-the-language) | the one client big enough to answer a usability question, why it changed shape, the two library gaps that were in front of it — both now closed, so nothing is — and [a second transport](#mcp-implementation--built-adr-0241), built, with what it found against what it was predicted to find |
| [Where the ideas come from](#where-the-ideas-come-from) | the borrowings from Rust, Swift and Zig, and where each stands |
| [The open questions](#the-open-questions) | the one structural risk no record can close — and it is now the only entry left |
| [Version 3](#version-3-what-it-took-and-what-it-left) | what the release took, what dissolved under it, and the one proposal it left open — which has since been taken |
| [Cross-platform support](#cross-platform-support) | what the x86-64 lock turned out to be, and what is left of it |
| [Known limitations](#known-limitations) | what is wrong or absent today, under [ISO 7185](#under-iso-7185) and [ISO/IEC 10206:1991](#under-isoiec-102061991) |
| [Answered, and where](#answered-and-where) | the questions this file used to carry, each with its record |

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
| **The text model** | **Done** (ADR-0189 – ADR-0193, AP 6.4.15). The choice this row offered for eleven records — *a wider character type or a text type* — turned out not to exist: widening `char` stops `set of char` compiling under ADR-0028's 256-value cap, which breaks ADR-0117's containment. So it is a type **beside** the string: `utf8(n)`, a value with a capacity in **bytes** holding well-formed UTF-8 in normal form C, whose elements are **extended grapheme clusters**. Normalising where a value is constructed rather than where two are compared is the load-bearing choice — it makes `=` byte equality *and* canonical equivalence at once, so `é` typed either way is one value and a text can be a `pasmap` key. There is no integer index, for Swift's reason. Four increments: the Unicode tables and runtime, judged by Unicode's own conformance files; the type, with assignment, comparison, `length` in elements and `write`; joining and walking, where `+` renormalises across the join and rejoining the elements of a text gives back the original; and `PasUnicode`, whose `ToText` reports where the assignment stops and whose scalar view answers what the language will not — a family emoji is one element and five scalar values. Case folding and case mapping followed (ADR-0196), and they are where the model's oracle story ends: Unicode publishes a conformance file for normalisation and for segmentation and **none for casing**, so those three routines rest on a transcription where the rest rests on a document written elsewhere. The last question was grapheme-indexed slicing, and the answer was **not to offer the index** (ADR-0199): `PasUnicode.ElementEnd` answers where an element ends, so the walk is written in the program that pays for it and a slice, a lockstep comparison and a resumable walk are all compositions over it. Nothing of AP 6.4.15 is left. **And the refusal has since had its first external test** (ADR-0237): the Language Server Protocol counts positions in UTF-16 code units, which is a *fourth* unit and one this page said nothing in the text model answers in. The index is still refused and the count never needed one — a scalar below U+10000 is one code unit and one at or above it is two, so the conversion is a walk over the scalar view, unchanged. The one part of this row that was argued for rather than measured has now been measured by a specification nobody here wrote. |
| **The memory model** | Unstarted, and **no longer blocked**: it could not be designed before the safety model, shared mutable state being where the two meet, and the safety model is answered. What that answer does to this row is shrink it — ADR-0201's construct is share-nothing, so there is no shared mutable state for a memory model to be about, and the question narrows to what a value crossing between two threads guarantees. It stays open because nothing has been designed, not because something is in its way. |
| ~~**How far the C++ reference front end follows**~~ (ADR-0108) | **Answered by deletion** (ADR-0232). It was frozen at the conformance surface — `difftest` skipped every dialect source — and when the conformance surface went, `difftest` had nothing left to compare and `src/` had no reader. Both are gone. The question the row was really about survives as [open question §1](#1-the-dialect-has-no-external-authority-and-every-gate-here-is-anchored-in-one) and as `doc/sop.md` §7's largest entry: nothing now compares this front end with a second answer. |

What is already in hand and was not built for this: modules and separate
compilation (ADR-0053, ADR-0079) mean a library needs no new language
mechanism, and `runtime/pasrt.c` is where the outside world already enters.

---

## What blocks the library

**Nothing is left of the list this chapter was named for.** Every row a survey
of daily needs put here has been struck, and the last of them went the way the
two before it did — a decision that looked like it needed the memory-safety
model turned out to need it for only part of its surface.

What stands below it is a different thing and is why the chapter is still
here: **one narrow foreign-interface item that genuinely waits on the model**,
and **what each landed feature left open behind it** — the two things the
handle opened, both since struck within two days of being written down; the
move a k-way merge would have liked; and, newest, the routine half of the
schema's type discriminant. None of those is a gap a survey found: each is a
consequence of a feature landing. That is the shape to expect from here on —
this page empties faster than it fills, and a landed feature is both the
commonest way it fills and, one increment later, the commonest way a row
leaves it.

~~A foreign struct the callee owns~~ is **done** (ADR-0187, AP 6.7.7.8): an
`external` function may answer an optional of a record, a null address is the
absent value, and any other address yields a **copy** made where the call
occurs. That is the whole of it, and choosing a copy is what kept the model out
of it — nothing holds the address, so there is no lifetime to reason about.
`readdir`, `gmtime` and `localtime` are declarable. What is still not
declarable is a member that is *itself* a pointer, so a chained list of structs
— `getaddrinfo` — waits, and it waits on the model rather than on a clause.

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

Everything else a survey of daily needs found is closed. The library is
twenty-five modules, eight conforming and seventeen dialect. **`README.md`'s
module table is the one place to count them** — one row each, checkable
against `ls lib lib/dialect`, and this sentence has held a number that went
stale twice. `lib/dialect/README.md` is not a second listing and should not be
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
| **to hand an owned value to something else** | Of the three affine kinds only `owned ^T` moves. `take` is refused for a handle in as many words — *nothing else has a value one variable can stop holding* — and there is no move for a file at all (ADR-0182, AP 6.4.14 NOTE 5). This row lost its stated client the day after it was written: it was entered because a task cannot be given a socket, and the server turned out to need neither a task nor a move, a handle reaching its slot as the `var` parameter its producer writes through. So a **second client was written on purpose**, to find out what the row is worth rather than to wait for one — a k-way merge of sorted files, a binary heap of open streams ordered by the line each is showing, which is the textbook program whose data structure exists to exchange its elements. **It is writable today**, and the whole of what the missing move costs is one indirection: an `array [1..K]` of records each holding a `Stream` is admitted and readable, but the heap has to be over *positions* in it rather than over the records, so every comparison reads `src[heap[c]].head` and `Swap` exchanges integers. That is not a workaround but the ordinary shape here — `lib/passort.pas` sorts by `less(i, j)` and `swap(i, j)` and never sees an element, for the unrelated reason that this compiler has no generic *routines* — a schema may now be parameterised by a type (ADR-0209) and a routine over one may not be, which is the row below — and its own header names parallel arrays as a caller it expects. The one bug the probe carried lived in exactly that doubled subscript, which is one author in one sitting and is worth recording rather than deciding on. **So the row is real and small**: an ergonomic cost and not a wall, and by ADR-0116's rule it stays unbuilt, the program that wants the move having managed without it. What would change the answer is the **factory** — `function Open(p): Stream ! ErrorCode`, which is how a caller would rather receive one. That was tried, and the trying is what the row is now worth reading for. The bare half is nearly free: a handle is `IsMemory`, so a declared function answering one already takes the address of the variable the result is to live in, `CloseFiles` already skips it for being a `var` parameter, and a factory over a factory passes `%res` straight through with no intermediate handle at all — three Sema arms and one address. **But the bare half has no caller**: every handle producer in `lib/` answers an `ErrorCode` and writes the handle through a `var` parameter, so a factory that can only answer `nil` is a regression, not an improvement. And the fallible half is refused by something load-bearing. AP 6.4.13.1's refusal is not an oversight — it is `HoldsFile`'s invariant, whose own comment says a variant part cannot hold a file *because the arms share storage and a file's storage is its own*, which is also what lets `WalkFiles` reach every file exactly once. A fallible-type's two arms **are** a variant part, so an owned value in one would have its closer clobbered by the other arm and be released through garbage. Making it work means laying the two arms side by side instead of over one another, which changes the emitted struct shape and reaches `PutStructAt`, `SelectedSize`, `target-layout` and `foreign-layout`. So the row stands, and what stands in front of it is now named: **a representation change to every fallible-type, not a clause** |

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
| ~~to write a *growable* container once~~ | **Done** (ADR-0209, ADR-0211, ADR-0212, ADR-0213), and the module is `lib/dialect/pascontainer.pas`: one growable vector and one string-keyed map, over whatever element type a program names. A client writes one line per element type — `type IntVec = ^Vec(integer);` — and the module is written once. `tests/dialect/lib_container.pas` runs both containers over `integer` and over a record, growing each past its opening capacity more than once. **What it does not replace**: `PasVector`, `PasStrVec` and `PasMap` are ordinary Extended Pascal and stay, because generics are the dialect's and a conforming program must still have a vector and a map; and `PasList` stays because an owned pointer's domain may not be a schema (ADR-0181), so a generic chain would make the *program* declare the node and list types. **What writing it found**, both recorded: a generic body may call only what its clients can reach, since the instantiation is emitted in the client and a module's private routines are internal to its own object file (`doc/sop.md` §7, and the module exports two helpers no caller wants); and that a type argument a call passes is one the container's own type already knows, which `x: type of v^.a[1]` removes — **not** a conformance gap, as this row said for a day: §6.4.9's object is a variable-name and no more, so the refusal is the standard's (ADR-0214), and the dialect widening it is a feature (ADR-0215). Five of the module's headings have lost a type parameter; `VecGet` and `MapGet` keep theirs, because they return the element type and §6.7.1 makes a result-type a type-name. **A generic map keyed by anything but a string** still waits on constraints |

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

---

## What a daily program still cannot reach for

The chapter above is about what the *language* blocks. This one is about what
is simply not written yet, and it is here because a survey of it was asked for
and the answer turned out to be short and specific rather than vague. Nothing
in it needs a language feature; each is a module somebody has to write, which
is the cheap kind of gap and the kind this page should name rather than imply.

**Twenty-five modules exist** — eight conforming and seventeen dialect, listed
by name in `README.md`'s module table. What a program written today reaches for
and does not find:

| Missing | What exists instead | Why it is not built |
| --- | --- | --- |
| ~~**JSON**~~ | **Done** — `lib/dialect/pasjson.pas` parses, navigates, builds and renders, and `tests/dialect/lib_json.pas` runs all four | It was the one gap here with a named client and it needed no language feature, as this row said. Two things it guessed wrong. A value is a variant record over the seven kinds — right — but a string is **bytes**, not AP 6.4.15's `utf8`: assignment to a text establishes normal form C, so round-tripping somebody's source file through it would edit their document, and `utf8` stops the program on ill-formed bytes where a parser must report. And the tree is plain pointers with `JsonFree`, not owned ones: AP 6.4.14.3 gives an owned pointer no copy, so `JsonMember(doc, 'params')` could not exist and navigation is the whole job. What it *did* need was ADR-0216 — it is the first module in the library to instantiate a generic imported from another, and until that fix the component linked to nothing |
| **date and time** | `PasProcess` can shell out; ISO/IEC 10206:1991 §6.7.6.9's `date`/`time` give a `TimeStamp` for *now* | Arithmetic on a date, parsing one, formatting one, and any zone at all are absent. `TimeStamp` is a required type and a good foundation; nothing has needed a second one |
| **terminal control** | nothing — no `termios`, no `isatty`, no raw key, no cursor, no window size | Its shape is decided (a `pasx_` binding in `runtime/pasrt_posix.c` bounded by its headers, `<termios.h>` joining ADR-0186's catalogue). It was the IDE's prerequisite and left with it when the judging program became a language server |
| **regular expressions** | `PasStrings` has `Pos`, `Trim`, case conversion; `PasUnicode` has the element walk | The largest of these by far, and the only one where the right answer is not obvious — a backtracking matcher and a DFA are different programs with different failure modes |
| **HTTP, TLS** | `PasNet` gives a socket and line reading | HTTP is a module over what exists. TLS is not: it means binding a C library, which puts the *whole* of that library's surface behind ADR-0185's rule that a library may not declare a foreign struct |
| **a hash of anything but a string** | `PasMap` maps `string(n)` to `integer` | Which is the container row above, one step on: a generic map needs growth on the heap *and* a way to say that a key can be hashed and compared — the second being a constraint, and the dialect has none |

**And two absences in the language rather than the library**, both deliberate
and both now the shape of a decision rather than an omission:

- **Concurrency.** Not one construct: no thread, task, process or channel.
  ADR-0201 decided what it must be — share-nothing, a task owning what it is
  given — and declined to build it, and the trigger it named was met and
  answered by a library routine instead. What would demand it now is a slow
  client not slowing the others, which is the language server's `didChange`
  arriving mid-compile. See the concurrency row in
  [where the ideas come from](#where-the-ideas-come-from).
- **Generics have no inference and no constraints.** The types are written at
  the call — `Swap(integer, i, j)` and not `Swap(i, j)` — and a body that adds
  its `T` values is refused, at the instantiation, for a type that cannot be
  added. Inference is a separate feature with a question of its own (what
  happens when two arguments imply different types); constraints are what a
  generic `PasMap` would need, and what the row above waits on second.

---

## The program that would judge the language

**A Language Server Protocol implementation, written in Afterschool Pascal and
for it**: a server over standard input and output that reads `didOpen` and
`didChange`, compiles what it is handed, and answers `publishDiagnostics` —
and then, as it grows, the document symbols, the hovers and the
go-to-definition an editor asks a server for. Written **here**, or it measures
nothing: a shim in another language wrapped around `pascalc` would be a
statement about tooling and not about this dialect, and outside ADR-0116's
discipline entirely.

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
  in the first hour — which is the row [above](#what-blocks-the-library) and
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
Eighteen entries so far, and **twelve of them have been acted on** — which is
the discipline this chapter is for: a finding recorded and left is a finding
wasted, and the rule that made the first one actionable was this section's own
— one site is an anecdote, two are a demand (ADR-0116).

The first two came from the framing alone, before a single protocol message
had been dispatched. The next two came from the diagnostics, before a server
existed to send one. **Everything after that came from the program itself**,
and the first of those is the one worth reading before the others: it is a
limit that looked generous beside a test case and turned out not to be a limit
a *program* could live inside, and it had to be fixed before the server could
be compiled at all.

The shape of the whole list is the argument for the chapter. **Five of the
eighteen are bounds** — 8 imports, 24 arguments, a 63-character key, a
255-character line, a 16 384-byte capture — and every one of them was chosen by
counting what the largest thing in the tree needed at the time. The largest
thing in the tree was a test case. One is not a gap at all: the protocol asked
the text model a question it had been designed to refuse, and the answer was
already exported. One came from pointing the finished program at the
repository it was written in, which is not a thing the earlier ones had needed
— and two more came from asking the compiler a question no gate had ever asked
it. **One pair is worth reading last**: one of them changed the language and
the demand for it turned out not to be this program at all but a library
module written a year of increments earlier, whose five writers could fail and
could not say so. A finding this chapter produced was already true everywhere
else.

**And the last three are all about what the compiler had never been asked.**
Two are things it did not keep — where a symbol was declared, and where a
field-identifier is — each thrown away by code that had the answer in its hand
and no reason to hold it. The third is not a demand on the language at all: it
is a defect this program shipped and an oracle caught, and it is here because
of *which* oracle.

**One entry took two records to close and they are not the same kind of
thing.** *A program cannot make a temporary file, and cannot survive failing
to* was written as two halves; the second was a language question and became
AP 6.4.3.4.7 (ADR-0240), the first was a library one and became
`PasProcess.ProcessId` (ADR-0242). Splitting it when it was recorded is what
made that visible — a single entry would have been closed by the language
change and the sharing of one scratch file between two servers would have gone
with it, unfixed and unrecorded.

- ~~**There is no empty substring**~~ — **answered, and it is the first
  finding this chapter produced that changed the language** (AP 6.5.6,
  ADR-0219). §6.5.6: *"it shall be an error if … the value of the first
  index-expression is greater than the value of the second"*. So
  `s[1..length(s) - 1]`, the ordinary way to drop a last character, **traps on
  a string of one** — and the header line that ends a frame's headers is
  exactly one character, a bare carriage return. This entry closed with
  *"whether the dialect should have `s[i..i-1] = ''` is undecided and wants a
  second sighting; one site is an anecdote."*

  **The second sighting arrived the next day, and it had already shipped.**
  `lib/dialect/pasparse.pas`'s blank trim is the same shape, written a week
  earlier, and `ParseInt(' ')` stopped the program where it should have
  reported a syntax error — through every gate, because no test passed a string
  that trims down to exactly one character. Three sites in the tree, three
  different treatments: `pastext.pas` builds its result a character at a time
  and never takes a substring, `paslsp.pas` writes the guard out, `pasparse.pas`
  gets it wrong. This language now admits `s[i..i-1]` and still refuses
  `s[4..2]`, which cost one flag on one runtime check — a flag ADR-0232 then
  removed, there being no mode left that keeps §6.5.6's trap for the empty
  case. **The argument was in the tree already** — §6.7.6.7's
  `substr(s, i, 0)` is the null-string and ADR-0125's `a[i..i-1]` is the empty
  slice, so `s[i..i-1]` was the only bracketed range that could not be empty.
- **The chapter named a module by what its name suggests, for the third
  time.** It says `PasParse` reads `file:line:col: error:` back off the
  compiler. `PasParse` parses an **integer** and nothing else — ADR-0120's
  result shape applied to one parse — and reads no diagnostic. That is the
  third prerequisite this chapter guessed wrong about its own plan, after the
  JSON row and after `PasStream` framing a message it cannot frame, and the
  three share a shape worth naming: **a module named by what its name suggests
  is a guess, not a survey.** `lib/dialect/paslspdiag.pas` is the module that
  actually reads them, and it landed with the conversion the protocol needs —
  LSP counts lines and characters from zero where `ErrorAt` counts from one.
- **The first realistic payload found a defect in `PasJson`.**
  `JsonCharsInto` asks whether a rendered document fits the *caller's*
  capacity and then built the answer through a 255-character local, so a
  document between 256 and the caller's capacity passed the guard and stopped
  the program. A `publishDiagnostics` notification carrying two diagnostics is
  321 characters. Nothing had rendered one that long — every case in
  `tests/dialect/lib_json.pas` fits a line — which is why it was invisible.
  **This is the chapter's argument in miniature and it arrived before the
  server did**: the finding is not that the library is weak but that nothing
  had asked it for anything the size of real work.
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
- ~~**The command line cannot express a program with ten modules**~~ —
  **answered, and it is the finding that had to be answered first** (ADR-0235).
  `maxImports` was 8 and `argMax` was 24. The server's import chain is ten
  modules and none is optional: `PasIO` needs `PasFS`, `PasJson` needs
  `PasContainer`, `PasProcess` needs `PasStrVec`, and the server needs
  `PasProcess`, `PasEnv` and the three protocol modules. The compiler answered
  *"more than 8 --import arguments"* — ADR-0110's rule working exactly as
  designed, reporting rather than truncating — and it was still a program that
  could not be built.

  **The two numbers are one number**, which is the part worth carrying
  forward: an import costs two words of the command line, so a bound on
  imports is only real as far as the argument list can express it. They are
  now 32 and 72, and the second is *derived* from the first in the comment
  that declares it. ADR-0114 recorded *"a library of more than eight modules
  cannot be used whole"* as a limitation of the library; there are 25 modules
  in `lib/` and that sentence is struck.
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
- ~~**A program cannot make a temporary file, and cannot survive failing to.**~~
  **Both halves answered.** There was no `getpid` anywhere in this tree, no
  `mkstemp`, and nothing in `PasFS` that answered a temporary name, so the
  scratch path was one fixed name under `TMPDIR` and two servers sharing a
  `TMPDIR` shared the file. Worse: `rewrite` on a bound name that cannot be
  created is a run-time error and *stops the program*, and neither standard
  gives a program a way to ask beforehand — so a server could not survive a bad
  scratch path however carefully it was written.

  ~~The first half~~ — **answered, and it stayed a library question** (ADR-0242).
  `PasProcess` exports `ProcessId`, the server's default name carries it, and
  two servers no longer share a file. It is *not* `mkstemp`'s guarantee and
  could not be: §6.7.5.6 binds by **name**, so a file created exclusively would
  have to be opened a second time to be written and the exclusivity is given up
  at that moment. What a name can carry is a number no other **live** process
  has. `getpid` is bound by the module rather than by the runtime because
  `pid_t` is a *scalar* typedef and ADR-0186's rule reaches structs — the one
  case that distinction has been tested on. The primitive landed and the *name*
  did not: there is one caller, and ADR-0116 says one site is an anecdote.

  ~~**The residue**~~ — **answered too, and by ISO C** (ADR-0243).
  `PasFS.TemporaryPath(dir, prefix)` answers a path that names nothing else
  **with the file created**, which is what makes it unique against a process
  that has already exited as well as against one running now; the caller
  removes it. `mkstemp` is still absent and stays absent: it takes a `char *`
  it *modifies*, and the only mutable storage this FFI lends is a slice, which
  supplies a pointer **and** a count — so binding a one-argument C function
  through it would be a claim about an ABI. C11 7.21.5.3's exclusive `fopen`
  mode is the mechanism instead, tried in a loop, and the non-ISO-C catalogue
  stays at five names where `mkstemp` would have brought `close` and made it
  seven.

  **The two records answer different questions** and the language server is the
  reason to say so: `ProcessId` gives a **predictable** name and `TemporaryPath`
  a **unique** one. A server started a thousand times should leave one file in
  `TMPDIR` and not a thousand, and a predictable name is what makes the scratch
  source findable when the server and the editor disagree — so the server keeps
  the first and is not a caller of the second.

  ~~That second half~~ — **answered, and it is the second finding this chapter
  produced that changed the language** (AP 6.4.3.4.7, ADR-0240). §6.7.5.6's
  NOTE 2 offers `bound` to a program about to *read* and the write side had
  nothing, so `BindingType` gained a third field, `writable`. It needed **no
  spelling**: §6.4.3.4 NOTE 7 says *"a processor may provide additional fields
  as an extension"*, so the standard named the extension point and `binding`
  is a required function that already returns a record. That is the second
  feature in this dialect to need no position at all, after ADR-0184's, and
  the first where a standard put the door there.

  **The demand was not the server.** It was `lib/pasfile.pas`, whose four
  exported writers were *procedures* — routines that could not report failure
  and could fail, killing their caller — and whose `CopyFile` returned a
  boolean that covered only the source. Five sites in one module, written long
  before this chapter existed and never noticed, because nothing had pointed
  any of them at a path it could not write. One site is an anecdote and this
  was six.

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
- ~~**The protocol counts in a unit nothing here answers in**~~ — **answered,
  and the text model needed no change at all** (ADR-0237). This chapter had
  said the conversion was one nothing in the tree could do, because AP 6.4.15
  refuses an integer index and `PasUnicode` answers in scalar values. The
  refusal stands and the count did not need it: a scalar below U+10000 is one
  UTF-16 code unit and one at or above it is two, so `Utf16Column` is a walk
  over `NextScalar`. It is the fourth estimate on this page to be wrong in the
  useful direction, after the three the FFI increments produced — *a decision
  that looks like it needs a model may need it for only part of its surface.*

  **What was genuinely missing was the negotiation.** 3.17 lets a client offer
  `positionEncodings`, and under `utf-8` the compiler's column is already the
  protocol's — so a server that converted unconditionally would be *introducing*
  the error it was written to remove. Two sessions in `lsp/sessions/` differ in
  nothing but the offer and in nothing but that number.
- ~~**The server works on a single-file program and on nothing in this
  repository**~~ — **answered by reading the build description** (ADR-0238).
  The compiler is handed one file and a program is several, so a module
  compiled alone fails on every name it imports: 48 diagnostics for
  `lib/dialect/pasjson.pas`, two real and 46 cascade — and **21 171** for
  `selfhost/apfront.pas`, which is not a partial answer but noise the length of
  the file. Every module in `lib/` and every source in `selfhost/` behaved the
  same way, and it was invisible for exactly as long as the server was only
  ever pointed at documents this chapter wrote itself.

  The answer is `.components`, which is this tree's build description and is
  already read by five other things — `compile_commands.json` is what clangd
  reads and `go.mod` is what gopls reads, and none of them makes the compiler
  resolve names. **One rule covers every shape: take the entries before this
  file.** A sidecar beside the file and named after it gives all of them,
  because it does not name the file; `selfhost/compiler.components` names
  `compiler.pas` and gives the two before it, which is the case a second rule
  would have been written for.

  ~~**What this does not close is `README.md`'s gap**~~ — **closed**
  (ADR-0244), and by the compiler, exactly where this entry said it belonged.
  An `import` naming an interface no `--import` supplied is looked for as
  `<directory>/<name>.pas` in the source's own directory, then in each
  `--import-path`, then in each entry of `AFTERSCHOOL_PASCAL_PATH`; the search
  is transitive and post-order, so the list it produces is the activation order
  §6.2.3.6 requires. `--dump-imports` is the other half — resolution finds an
  *interface* and something still has to translate the file and link it, and
  that something is `tools/pascalcc`, which is now the second caller of a dump
  flag after the language server.

  **The install location went with it.** `cmake --install` lays out
  `<prefix>/bin`, `<prefix>/lib` and `<prefix>/lib/afterschool`; `pascalcc`
  looks for its compiler and its runtime beside itself before it looks in a
  build tree, and adds the installed library to the search path only when the
  variable says nothing. `install-layout` is the gate and is the first oracle
  here that runs an *installed* compiler — every other harness drives one out
  of the build tree, which is exactly the configuration an installed copy does
  not have.

  The server keeps reading `.components`, and that is not redundant: it needs
  the imports of a file it is *not* compiling as a program, for a document that
  may not parse, and the sidecar answers without the compiler having to.
- ~~**The whole-output buffer was sized for diagnostics**~~ — **answered by
  not having one** (ADR-0239). `CaptureMax` is 16 384 and the outline of
  `selfhost/apfront.pas` is **51 192 bytes**, so `documentSymbol` on the
  largest thing in this tree would have stopped a third of the way through and
  said nothing about it — `Capture` reads and drops the tail, which is right
  for a diagnostic and wrong for an answer whose length is proportional to the
  file. The fifth bound on this page, and the first that was *removed* rather
  than raised: an outline is a **list of lines**, so `CaptureLines` collects it
  on the heap and what is left is a per-line bound against six short fields.
  The diagnostics path keeps `Capture` deliberately — a compilation is long
  only when the file is badly broken, where an outline is long whenever the
  file is.

- ~~**The driver had never been handed a dump**~~ — **answered** (ADR-0239),
  and it is the entry on this page that failed most quietly. `PASLS_COMPILER`
  may name `tools/pascalcc` as readily as `pascalc` — `lsp/README.md` said so —
  and `pascalcc` knew no `--dump-` flag at all: it wrote `pascalcc: unknown
  option '--dump-symbols'` to *standard error*, which the server was not
  reading, and answered an empty outline with no complaint anywhere. Nothing in
  the tree had ever run a dump through the driver, because every dump case is
  handed `pascalc` and every ordinary case wants a program. It passes them
  through now and `producttest.sh` asks; the general shape is that **the two
  halves of this compiler have a seam and only one side of it is swept**.

- **The compiler does not keep the spelling a programmer wrote.** Not a
  defect and not a gap — the lexer case-folds an identifier and the string pool
  holds one copy, which is the whole of what makes `CaseTest` and `casetest`
  one name. It is here because an outline is the first thing that ever wanted
  the other spelling back, and the answer shows what a compiler's report is
  for: `--dump-symbols` gives a position and a length beside the folded name,
  and the caller holding the document slices the written spelling out of its
  own copy. Retaining both in the pool would have moved the one array whose
  headroom this tree measures (ADR-0126) for a display string. **The parse tree
  has no *extent* either** — a declaration's start is recorded and its end is
  not — which is why `range` and `selectionRange` are both the name. That one
  is a real limitation and is open; what would close it is the parser noting
  where a block ends, which nothing has yet needed.
- **The compiler did not know where a symbol was declared** — answered, and
  it is the finding that made go-to-definition possible at all (ADR-0246).
  Every applied occurrence in this compiler resolves to a `symbol`, and a
  `symbol` could not say where it came from. `Declare` is *handed* a line and
  a column — for its own "is already declared in this block" message — and
  threw them away, at the one site every named declaration passes through.

  Nothing had ever wanted them, and the reason is worth keeping: a diagnostic
  reports where the **mistake** is, and for thirty-six thousand lines of
  compiler that was the only question anyone asked about a position. A tool
  asks the opposite one. Three integers on the record and three lines at the
  site were the whole of it, which is what makes it a finding rather than a
  feature: the fact was already in the hand of the code that discarded it, and
  what it cost to keep was nothing.

- **The parse tree records a field-designator's `.` and not its name** —
  answered, and it is the other half of the extent finding above. A field node
  is built when the parser sees the point and before it reads the identifier,
  so the node's own line and column are the point's; whitespace is legal on
  either side of one, so `col + 1` is a guess and not a derivation. `nkField`
  carries `fdLine`/`fdCol` now, which is what lets a schema's discriminant be
  reported at the name a reader is pointing at. The declaration end is still
  not recorded and that half stays open.

- **A leak with every golden green, and only one oracle here could see it**
  (ADR-0246). Both new methods began by making a JSON `null` and replacing it
  where there was an answer, which abandoned one node per successful request —
  thirteen over two sessions. Every reply was byte-for-byte correct, because
  what leaked was a value nobody printed.

  It is not a demand on the language and it is here for **which** oracle
  caught it: `heap-balance` is the one gate in this tree that reads no output
  at all (ADR-0183), written after two leaks had each been found by a
  measurement taken once, by hand, and by nothing afterwards. This is the
  first program to exercise it since, and it failed on the first run. The
  chapter's own argument, met from the other side: the value of a client large
  enough to get tired inside is not only what it demands but what it trips.

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

### MCP implementation — **built** (ADR-0241)

**A second transport over the same program**, asked about because an agent is
now a reader of this repository as much as an editor is. It was recorded here
before it was started, with a prerequisite in front of it and an expected
finding named in advance, and both of those did their job: the prerequisite was
ADR-0239 and the prediction was half right in a way worth reading. What follows
is the entry as it was written, with what actually happened marked where it
differs.

**What is already shared, and it is most of it.** `lsp/pasls.pas` splits into a
transport half and a work half, and the split is clean: `ImportsFor`,
`WriteScratch`, `Compile`, `DiagnosticsIn`, the document store and `UriToPath`
know nothing about LSP beyond taking a URI. MCP speaks the same JSON-RPC 2.0
envelope with the same error codes, so `Dispatch`, `NewResponse`, `CopyId` and
the `-32601` path carry over unchanged. That makes it `pasls --mcp` rather than
a second binary — one document store, one import resolver, one scratch path.

**The one real code change is the framing**, and it is the interesting part.
MCP's stdio transport is newline-delimited JSON; LSP is `Content-Length: N` and
then exactly N bytes. `PasLsp` (ADR-0218) exists *because* that framing is not
line-oriented — a reader that has just consumed a header line is usually
already holding the first bytes of the body, and nothing that reads lines can
hand those back. Newline-delimited is the easier of the two, so the work is
small and the value is not the work: it asks whether `PasLsp`'s seam is an
abstraction or merely the one shape it was written for, which is a question one
framing cannot answer.

**The scenario that benefits is not the editor's.** LSP serves a human in an
editor; MCP would serve an agent working on this repository, which is a real
reader here. An agent editing `selfhost/apfront.pas` — 22 102 lines — has no
semantic route into it and falls back on `grep`, which fails in a way this tree
has already paid for: §6.11.1 puts an exported routine's header in the
module-heading *and* leaves the block repeating the name, so `^function Name(`
matches an interface entry with no body, which is how `foreign-reserved` broke
on the day of the three-component split. *Where is this declared*, *what does
this name resolve to* and *which component exports it* are questions the
compiler answers exactly and a regex answers by accident.

**That argument is already accepted here**, which is why this entry exists at
all: ADR-0229 and ADR-0230 moved `kind-exhaustive` off a Pascal-parsing regex
and onto the compiler's own `--dump-dispatch`, deleted 85 lines of it, and
found three dispatch sites the text match had simply missed. The agent is the
next reader in that line, and MCP is the socket it plugs into.

**Where it buys little**, said plainly so the entry is not read as larger than
it is. Compiling, running the suite and reading diagnostics are all done
through a shell today and are not improved by wrapping them in a tool call. The
gates gain nothing: a Python reader wants a line-oriented `--dump-*` flag,
which is what it has and the better interface for it. Editor users gain nothing
whatever.

**What it would stress that LSP has not.** Two things, both live. `PasJson`
under *construction* load — MCP tool descriptors are JSON Schema, nested and
heterogeneous and kilobytes long, where a flat `publishDiagnostics` carrying
two diagnostics is 321 characters and that alone found the `JsonCharsInto`
defect; `JsonLine` at 255 and `MapKey` at 63 are both open findings above, and
a tool list is the payload that turns them from recorded into blocking. And a
second framing over one reader, which is ADR-0116's two-sites test applied to
`PasLsp` itself.

**The prerequisite, and it decided the ordering.** Nearly every tool worth
exposing needs the compiler to answer a structured question *about a program*,
and when this was written it could not: the only route was `--dump-sema`, which
ADR-0085 demoted from a specification to a debugging aid the moment there was
no second front end to diff it against. That is **settled now** — ADR-0239
gave the compiler `--dump-symbols` and the decision behind it, which is that
the answer comes from the compiler and not from a second reader of its
debugging output. One question is answered and the surface is one question
wide; what the tool list above would need is more of them, and each will ask
the question ADR-0239 deliberately left open — whether it belongs behind this
flag, behind another, or behind something that is not a flag.

**The finding it is expected to produce**, named in advance the way the
concurrency row names its sentence, because a second surface added without one
is breadth where this chapter wants depth: *`PasLsp` is a frame reader and not
a transport, and the second transport is what says so.*

**That was right, and it was the smaller of the two.** `LspReader`, `Ready` and
`NextByte` are shared unchanged; `LspRead` is 40 lines and the pair that
replaces it 58. The module's name is now narrower than its contents and is kept
anyway — a third caller wanting the reader and *neither* framing would be the
reason to rename it.

**The finding the prediction did not have is the one worth carrying.** The
*work* half was less transport-neutral than the paragraph above claims, and only
a second caller could say so. `CompilerCommand` had the scratch path baked in
as the **source**, which is an LSP assumption — a document may never have been
saved, where MCP's unit is a file on disk. And the tool's `path` has to be made
absolute, because `ImportsFor` compares against sidecar entries it resolved
against the sidecar's own directory: a relative path matches none of them and
`lib/dialect/pasjson.pas` reports its 48 diagnostics again. **That is
ADR-0238's defect arriving a second time by a different road**, and the LSP
side never met it because `UriToPath` always yields an absolute path. *A
routine is not neutral because it has one caller; it is neutral when a second
one does not have to change it* — which is ADR-0116's two-sites rule applied to
an interface rather than to a feature, and is the sentence this entry adds to
the page.

**And one prediction above is wrong**, which is worth leaving visible rather
than editing away. The tool descriptors were expected to stress `PasJson` and
turn `JsonLine`'s 255 and `MapKey`'s 63 from recorded findings into blocking
ones. The whole `tools/list` frame is **931 bytes** and every literal in it is
under 255. What stressed something was the *outline*: 40 146 characters holding
1 624 newlines, in a frame of 41 859 bytes and one line, because `JsonRender`
escapes a newline and the frame therefore holds none — so what it stressed was
the framing, and `JsonlWrite` refuses a body holding a real newline rather than
assuming the property.

**What it cost** is what was estimated: a second thing to keep green. It is
one more session in the same corpus rather than a corpus of its own —
`lsp/sessions/mcp.jsonl` with a `.mcp` marker that says the framing is one
message to a line — plus `tests/dialect/lib_lsp_jsonl.pas` for the module half,
which had to be a second *program* because one program has one standard input
and the two framings cannot be read from it at once.

One caveat about the reading above, in this page's own spirit: the LSP and
`lsp/` facts here were taken from the sources, and the MCP-side ones —
newline-delimited stdio framing, the JSON-RPC envelope, the shape of a tool
descriptor — are from knowledge of that protocol and were not checked against
its specification in this tree. Confirm them against the published version
before any of this is built on.

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
| Traits / protocols | Rust, Swift | abstraction | **Later**, and the reason given here has since become half-true rather than true. Schemata gave parametric types over a *value* (ADR-0039); ADR-0209 lets a discriminant name a **type**, so `Vec(T: type; cap: integer)` is a container written once. What that does not give is a routine over one — see [the row above](#what-blocks-the-library) — and abstraction over *behaviour* is a further thing again, which nothing has asked for |
| `comptime` | Zig | metaprogramming | **Later.** Constant-expressions everywhere (ADR-0054) is as far as anything needs |
| Actors / `Send`+`Sync` | Concurrent Pascal, Ada, Swift, Rust | concurrency | **Unblocked and unbuilt** (ADR-0201). It unblocks nothing, the two rows above having been answered without it; what it does is *end* the sentence the rest rests on — a borrow cannot outlive a call because the caller is not running during it. So the construct must be **share-nothing**, a task owning what it is given, and the lineage to read is Pascal's own rather than Rust's: Concurrent Pascal had `process` and `monitor` in 1975. Not built, for ADR-0116's reason — nothing here wants it. **This row named its trigger and the trigger came and went in two days.** ADR-0201 said "a socket module serving more than one client is what would demand it, and `select` is the cheaper answer to try first"; ADR-0203 landed the module and ADR-0205 made it serve many, with `poll` and no construct at all. The cheaper answer was tried first and was enough, which is what ADR-0201 asked for. What a thread would still buy is a **slow client not slowing the others** — a different sentence, and one no program here has yet said. **A program that would say it is now named**: the [language server](#the-program-that-would-judge-the-language), where a `didChange` arrives while a compile is in flight and a cancelled request has to stop something already running. **The candidate is now written and the row still does not move** (ADR-0236): `lsp/pasls.pas` exists, and it compiles *synchronously* — it writes the document to a file, waits for `pascalc`, publishes, and only then reads the next message. So the sentence is still unsaid. What has changed is that saying it is now a step rather than a proposal: the program that would is in the tree, the shape of what blocks it is visible, and the row is one increment away from having a caller instead of a candidate |

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

### 2. ~~A third-party differential~~ — done (ADR-0234)

`fpc-differential` compiles every case with a golden under Free Pascal's
`-Miso` and compares. It is a `ctest` case that skips without `fpc`, and
`tests/checks/fpc_disagreements.txt` is the catalogue, failing in both
directions like every other catalogue here.

**It found no defect in this compiler**, which is the result and not a
disappointment: of eleven catalogued disagreements, six turn on a clause and
all six are decided here, two are implementation-defined, and three are not
verdicts. Three of the six corroborate a reading that nothing in this tree
could previously challenge — ADR-0073's mixed comment delimiters, whose own
record says a comment is invisible to every stage after the lexer so no oracle
here could have caught it; `round` defined by equivalence rather than by a
rounding mode, where the test's comment had predicted the disagreement and had
never met a processor that made it true; and ADR-0076's longest-prefix number
read.

**Two things this entry got wrong, both worth keeping.** It named the eight
conforming `lib/` modules first, as the portable half — and no second
processor can run them: FPC's `-Mextendedpascal` does not implement §6.13's
modules at all, so `module m interface;` is a syntax error. And it said the
option was worth more now than later; the numbers say how much more. FPC
refuses **141 of 244** cases with a golden, so the differential reaches 103,
and every release moves that the wrong way.

What is left is not a task. `tests/dialect/` is compared by nothing and no
third party can be found for it, which is
[§1](#1-the-dialect-has-no-external-authority-and-every-gate-here-is-anchored-in-one)'s
standing risk.

### 3. ~~Mutation testing, committed to the tree~~ — done (ADR-0207)

`tests/mutation/` holds one file per recorded mutation and a harness that runs
them. Both conditions this entry named are enforced by it, and a **third**
arrived while ADR-0205 was being written: a mutant restored with a plain `cp`
and a `touch`, correctly by the old rule, and never rebuilt — so the next run
measured the mutant and a golden was taken against it. The rule was right and
one step too short.

What is left of the entry is a caution rather than a task, and it is in
`doc/sop.md` §7: the catalogue is a **register of demonstrations, not a
measurement**. `ls tests/mutation/mutants/` is where to count them, and **this
sentence no longer says how many**, having gone stale twice — it said eleven
when there were eleven and again when there were forty-five. "The mutation
suite passes" means those recorded claims still hold and nothing more.

Many more records carry a mutation in their *prose* instead, most naming code
that has since moved, and nothing runs one of those. **`doc/sop.md` §7 owns
that comparison** and carries the count with the grep that produced it; this
entry says only that the register is much the smaller half, so that one
sentence does not come to disagree with itself in two files.

### 4. ~~Should the dialect read a type off a *component*?~~ — yes (ADR-0215)

`type of` now takes §6.5.1's whole variable-access, and
`lib/dialect/pascontainer.pas` is the caller it was built for: five of its
headings lost a type parameter.

```pascal
procedure VecPush(Ptr: type; Elem: type; var v: Ptr; x: Elem);  { was }
procedure VecPush(Ptr: type; var v: Ptr; x: type of v^.a[1]);   { is }
```

Three things it settled that the question above had only guessed at.

**The cost was not the resolution.** The worry was a designator typed without
being evaluated inside re-entrant declaration checking, re-entered per generic
instantiation. It needed nothing: `ResolveType` caches on the denoter's own
`ntype`, `ForgetResolved` clears exactly that, and `CheckExpr` re-resolves
every name unconditionally rather than consulting what is already there. The
non-evaluation is likewise free — the type of `a[i]` does not depend on `i`,
and a type-denoter is never walked by CodeGen.

**What it cost instead was the substring**, which nothing above had thought of.
§6.5.6's substring-variable *is* a variable-access and what it possesses is the
canonical string-type — a pointer and a length with no capacity, which no
variable may have. The program compiled, ran, and stopped at *a string of
length 3 does not fit a capacity of 0*. It is refused now, and that is the only
variable-access this denoter cannot answer for.

**And it found where the widening stops.** `VecGet` and `MapGet` still take the
element type, because they *return* it and §6.7.1 makes a result-type a
`type-name`:

```
result-type = type-name .
```

So `function VecGet(…): type of v^.a[1]` is unwritable in the dialect too. That
is a second production and wants the same argument made again about a different
clause; it is not carried here as an open question, because nothing is waiting
on it — the two-parameter form works and reads fine.

---

## Version 3 — what it took, and what it left

**Shipped, 2026-08-28.** This chapter was four proposals looking for a
decision; three of them are now records and the fourth dissolved. What is left
open is §1, and it is written out below rather than struck through, because it
is the one that did not happen and the reasons it was wanted are unchanged.

[`CHANGELOG.md`](../CHANGELOG.md) says what the number tracks — *the accepted
language, the diagnostics and the command line* — and by that definition three
of the four original proposals were invisible to it. §0 is what the number is
actually for.

### 0. Afterschool Pascal is the language — **this is v3** — ADR-0232 ✔

`--std` is gone, and with it the two conformance modes, ADR-0166's `{ @std: }`
header comment, the `.std` sidecars and the clause 5.1 a) compliance statement.
A source is written in Afterschool Pascal; the compiler has no mode to be put
into. The lexis is the dialect's, which is survivable only because the dialect
contains Extended Pascal (ADR-0117).

The decision was taken with the cost measured rather than estimated, and
ADR-0232 records all of it. What actually landed, against what was predicted:

- **The Extended Pascal corpus came through**, as predicted. Four cases went —
  the three type-inquiry refusals and `trap_substring`, each of which asserted
  that the *dialect's* answer was refused, and each with a positive counterpart
  under `tests/dialect/` already.
- **The ISO 7185 corpus did not survive intact**, as predicted, and the shape
  was slightly different: 42 `*_refused` cases (Annex B's grid, 21 constructs
  times two modes) and 28 `*_iso` mode gates were deleted outright, six
  `badparse` gates with them, and **nine sources were renamed** because a
  word-symbol took their identifier — `value` in seven, `only` in one, a
  function called `Value` in two. `verify/verify.py`'s generated program was a
  tenth. That rename is the cost in its most concrete form.
- **Five oracles retired and nothing replaced them**: the BSI suite (the only
  third-party corpus this project ever had), `difftest`, `dialect-containment`,
  `annex-b` and `reserved-words`. The gate count went 24 → 19 — and to 20 since, `fpc-differential` being the first added after v3 (ADR-0234).
- **And `src/` went with them**, which was not part of the proposal. With
  `difftest` and `annex_b.py` deleted it had no reader, and it was in no build
  chain — 16 936 lines of C++, and the last reason this build needed a C++
  compiler. That is written up in the [question this chapter left
  open](#the-question-this-chapter-left-open) below.

The alternative — make the dialect the *default* and keep the modes, which is
what Free Pascal does with `{$MODE ISO}` — was recommended and declined, on the
ground that it leaves the project presenting itself as a conformance vehicle
with a dialect attached, which is not what it is.

### 1. Split the compiler into §6.13 program-components — **done** ✔

The one proposal v3 did not take, taken the day after v3 shipped:
[ADR-0233](adr/0233-the-compiler-becomes-three-program-components.md), written
**Proposed** while the alternatives were still live, accepted two days later
without a word of the argument changing, and implemented the same day. The
compiler is `selfhost/aptypes.pas`, `selfhost/apfront.pas` and
`selfhost/compiler.pas`, and `selfhost/compiler.components` is the order.

Writing the record before the work changed the proposal twice, and doing the
work corrected the record twice. All four are in
[`doc/history.md`](history.md#the-compiler-becomes-three-program-components);
the two that matter to a reader of this file are that **the buffer argument was
false** — `--import` re-tokenises the whole imported file, so nothing about the
peak follows from splitting — and that the pool peak nevertheless **fell by
27%**, which the record predicted it would not. `buffer-headroom` measures all
three translations now and reports the worst of them, which is a better
question than it was asking before.

What the split was taken for is the linking blind spot, and that closed:
`doc/sop.md` §7's row is narrowed to the combinations the compiler's own
structure does not use, because every build now translates a module alone,
translates a module that imports another, and links the result.

### 2. Let the compiler be written in the dialect — **dissolved by §0** ✔

It is. `selfhost/compiler.std` said `extended`, and there is no such file and
no such mode: the compiler's own source is an Afterschool Pascal source by
construction, as every source now is.

The question was rejected twice before that. ADR-0190 refused it on the ground
that *"the fixed point holds only while the compiler is an Extended Pascal
source"*; ADR-0223 built the compiler a second time to arm ADR-0118's variant
guards and used that build as a *reader*, never as the product; ADR-0231 then
measured the sentence and found it false — the second build **is** a fixed
point, and it is the **same compiler**, byte-identical on 1025 sources. So the
objection had already narrowed to the seed before ADR-0232 arrived, and the
seed was refreshed in this release.

**What is left of it is an ordering discipline, not a question**: a dialect
feature must be expressible in what `seed/*.ll` accepts, or the seed is
refreshed first (ADR-0109). What the compiler now *may* use — `defer`, `T ! E`,
`owned ^T`, slices, `break`, `exit`, the generics, `type of` over a
variable-access — it does not yet use, and whether adopting any of them makes
this compiler better is the thing ADR-0109 wanted to learn and still has no
measurement of. That is worth a record when someone tries it, not a roadmap
entry.

### 3. Have the compiler report its own dispatch — ADR-0229, ADR-0230 ✔

`--dump-dispatch`, in two halves. ADR-0229 moved the case-statement half off
the Python source parser: the compiler writes every case-statement whose
selector is an enumeration, with the constants its labels name, the ones they
miss, and the constants no case names at all. The two readers were compared
before the old one was deleted — 60 sites, same routine, enumeration, ordinal,
`N of M` and missing constants on every one — and 85 lines of Pascal-parsing
regex went with it.

ADR-0230 moved the if-chain half, and `tests/checks/kind_exhaustive.py` now
reads **no Pascal at all**: 542 lines to 384. A chain is a *shape* and not a
node, so Sema records every if-statement with its else-part and every tag test
in a condition, and a head is an if that is no other's else-part. The dump
reports the **field** each chain reads, which is what selects a dispatch from a
lookahead — and that is where the regex turned out to have picked its scope by
accident: ADR-0221's "three enumerations qualify" described what a text match
could see, and the compiler finds 70 chains where the regex found 38.

**The limit the proposal stated is unchanged and a dump does not lift it**:
neither form judges whether an arm is *right*. `tyOptional: StaticThroughout :=
true` satisfies the gate and is wrong. This moved the oracle from a Python
parser to the compiler; it did not move it from a prompt to a proof.

### 4. Reconsider containment-by-position — **dissolved by §0**, and the rule kept ✔

This was the proposal §0 predicted it would dissolve, and it did, though not
quite in the way predicted.

The argument *against* withdrawing ADR-0140's rule was that containment buys
`dialect-containment` — the conformance corpus compiled a second way, with the
other mode as the oracle. That sweep is gone, so the argument is gone with it,
and `reserved-words` — the gate that asked whether this language reserves
exactly what Extended Pascal reserves — is not a question once there is one
list.

**The rule is kept anyway**, and the reason is better than the one it had. It
was stated as a constraint on a *mode*: the dialect must not disturb what the
conformance modes accept. It now protects something this language claims about
itself — that every Extended Pascal program is an Afterschool Pascal program
meaning the same thing. Reserving a word-symbol takes that spelling from every
such program that uses it as an identifier, which is exactly the 25-case cost
§0 paid once and deliberately. Paying it again casually is what the rule
forbids.

What did change is who enforces it: `reserved-words` did, and nothing does now.
ADR-0140's Status records that, and `.claude/skills/code-review` is where a new
spelling gets looked at. ADR-0177's `exit`, ADR-0178's `try` and ADR-0184's
unspelled feature remain the three shapes a reader should know before proposing
a fourth.

### What v3 must not touch — and did not

- **Textual `.ll` as the only backend.** ADR-0085 made it more load-bearing,
  not less: it is what lets a clone with no LLVM development files build the
  compiler. Untouched, and v3 went further — the build needs no C++ compiler
  either now.
- **ADR immutability.** Thirteen records were annotated at their Status with
  what ADR-0232 did to them; not one had its argument edited.
- **[`doc/sop.md`](sop.md) §7.** It grew: the front end has no second
  implementation, and there is no third-party corpus.
- **A green suite is not evidence; evidence is a named case that fails without
  the change.** This is the one v3 made *harder* to honour and more necessary
  to: with `difftest` gone, a golden regenerated after a change is agreed with
  by nothing else. `doc/sop.md` B4a says so in as many words.

### The question this chapter left open

`src/` — whether the second front end earned its cost. The chapter had no
answer and observed that the cost had never been counted. It has been:
**16 936 lines of C++, and the whole of the build's need for a C++ compiler**,
against a reader that ADR-0117 had frozen at the conformance surface and that
skipped every dialect source.

§0 answered it by removing the surface. With `difftest.sh` and `annex_b.py`
deleted, `src/` had no consumer at all; it was verified to be in no build chain
— `pascalc` builds with the binary absent, and all 730 cases pass — and it was
deleted. Reviving it would have meant first teaching it the language ADR-0117
deliberately kept it out of, and a second implementation of a language with no
external specification is two readings by one author, which is the one thing
`difftest` could never contradict.

What it *did* catch was drift between two ports of one reading, and that is the
loss. It is recorded in [`doc/sop.md`](sop.md) §7 as the largest blind spot on
that page, and [open question §1](#1-the-dialect-has-no-external-authority-and-every-gate-here-is-anchored-in-one)
is where it belongs from now on.

The fix for the *other* half of that question — that the independent readers
were not independent — was cheaper than any of the four proposals and was not a
v3 item at all, which is why it went first: **ADR-0228 did it.** Readers now
run out of process against a sandbox built outside the repository, with the
compiler's source comment-stripped, that last being the half missed for four
records. Asked whether it was given project documentation, a reader in the
repository names this project and its path; one in the sandbox answers no.

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
([question 4](#4-should-the-dialect-read-a-type-off-a-component-yes-adr-0215),
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
| Is this a conforming processor or a dialect? | A dialect. `--std` and the two conformance modes are removed, the clause 5.1 a) compliance statement withdrawn, and 25 of 172 ISO 7185 cases became inexpressible — a conforming ISO 7185 program with a field called `value` no longer compiles. Five oracles retired with the surface they asked about. It is what version 3 is named for | ADR-0232 |
