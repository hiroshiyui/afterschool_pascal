# Roadmap

What is open: the goal, what blocks it, the questions no record has answered,
and what is wrong or absent today.

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
| [The program that would judge the language](#the-program-that-would-judge-the-language) | the one client big enough to answer a usability question, why it changed shape, and the one library gap in front of it |
| [Where the ideas come from](#where-the-ideas-come-from) | the borrowings from Rust, Swift and Zig, and where each stands |
| [The open questions](#the-open-questions) | the one structural risk no record can close, and the one oracle still worth building |
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
**finished**: the compiler compiles itself, and both standards are complete to
the last clause. The conformance modes are not going away. The dialect is a
third mode beside `--std=iso7185` and `--std=extended`, and it changes
neither: what they *accept* moves only for a reason inside their own standard,
and what they *say* may mention the dialect where a program was compiled under
the wrong mode (ADR-0154).

**Four decisions the goal forces**, each to get its own record when it is made:

| Decision | Where it stands |
| --- | --- |
| **The memory-safety model** | **Answered, in both halves and by discovery rather than by design** — four records, and not one of them decided the question the row was written to pose. *Lifetime* — an owned value is released when the variable holding it dies and cannot be copied out of it — was already here, being what a file variable has been since 1982 (ADR-0151). But that sentence quantifies over a *variable*, and a variable created by `new` is held by nothing: it exists in no activation, so nothing released what a heap record owned unless the program said `dispose`, and under a 64-descriptor limit a loop allocating one per iteration ran out at the 62nd. `owned ^T` gives such a variable an owner and closes it (ADR-0181, AP 6.4.14). The *aliasing* half — may a second name hold one owned value, and if so how: ARC, or borrowing — stood here for a long time as undecidable until the fork was **withdrawn as posed** (ADR-0201). Neither candidate can reach `^T`, ADR-0117's containment fixing what an ISO program's only reference type means; the dialect's answer for the three affine kinds is refusal, given three times, so there is no second name for either candidate to govern; and the one alias that does exist — a `var` parameter bound to an owned value's referent — cannot escape, because Pascal has no address-of and `new` is the only producer of a pointer. **Unformable rather than checked**, which is stronger and free, and silent if a future feature takes it away (`doc/sop.md` §7). What is left of the fork is exactly one thing: **two threads of control**, which is the only sentence that breaks *a borrow cannot outlive a call because the caller is not running during it*. See the concurrency row [below](#where-the-ideas-come-from). |
| **The text model** | **Done** (ADR-0189 – ADR-0193, AP 6.4.15). The choice this row offered for eleven records — *a wider character type or a text type* — turned out not to exist: widening `char` stops `set of char` compiling under ADR-0028's 256-value cap, which breaks ADR-0117's containment. So it is a type **beside** the string: `utf8(n)`, a value with a capacity in **bytes** holding well-formed UTF-8 in normal form C, whose elements are **extended grapheme clusters**. Normalising where a value is constructed rather than where two are compared is the load-bearing choice — it makes `=` byte equality *and* canonical equivalence at once, so `é` typed either way is one value and a text can be a `pasmap` key. There is no integer index, for Swift's reason. Four increments: the Unicode tables and runtime, judged by Unicode's own conformance files; the type, with assignment, comparison, `length` in elements and `write`; joining and walking, where `+` renormalises across the join and rejoining the elements of a text gives back the original; and `PasUnicode`, whose `ToText` reports where the assignment stops and whose scalar view answers what the language will not — a family emoji is one element and five scalar values. Case folding and case mapping followed (ADR-0196), and they are where the model's oracle story ends: Unicode publishes a conformance file for normalisation and for segmentation and **none for casing**, so those three routines rest on a transcription where the rest rests on a document written elsewhere. The last question was grapheme-indexed slicing, and the answer was **not to offer the index** (ADR-0199): `PasUnicode.ElementEnd` answers where an element ends, so the walk is written in the program that pays for it and a slice, a lockstep comparison and a resumable walk are all compositions over it. Nothing of AP 6.4.15 is left. |
| **The memory model** | Unstarted, and **no longer blocked**: it could not be designed before the safety model, shared mutable state being where the two meet, and the safety model is answered. What that answer does to this row is shrink it — ADR-0201's construct is share-nothing, so there is no shared mutable state for a memory model to be about, and the question narrows to what a value crossing between two threads guarantees. It stays open because nothing has been designed, not because something is in its way. |
| **How far the C++ reference front end follows** (ADR-0108) | Frozen at the conformance surface in practice — `difftest` skips a dialect source — and that is the obvious answer, not the decided one. |

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
twenty-one modules, eight conforming and thirteen dialect. **`README.md`'s
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
| ~~to write a container once~~ | **Done** (ADR-0209, ADR-0211, ADR-0212), and it took three records because the last one was a buffer rather than a clause. ADR-0209 made a container's *storage* writable once (`Vec(T: type; cap: integer)`), ADR-0211 made the routine over it writable once too (`Push(T: type; var v: Vec(T, 4); x: T)`), translated per distinct type and cached the way a schema production is — and the wall the first record named, that a schematic formal reads its discriminants from a run-time descriptor (ADR-0040) and a type cannot travel in one, was gone round rather than through: a type parameter is not passed at all, it *chooses a translation*. What was left after that was that a generic could not cross `--import`, because an instantiation re-parses the body from a saved token position and the import loop cleared the token array between components — so a generic in `lib/` pointed at tokens that now held a different source, which is a defect no check could have caught and which no case could reach, since no module could declare a generic until it was fixed. ADR-0212 keeps the tokens. The cost was measured rather than estimated: the compiler imports nothing so `buffer-headroom` does not move, and a client importing three modules reaches 1969 tokens of 300000. **The four modules can now be one**, which is work for the library rather than for the language |

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

**One hazard, and it is the sharpest edge in the idea.** LSP positions are
**UTF-16 code units** by default; UTF-8 is negotiable since 3.17 and not
guaranteed. AP 6.4.15 refuses an integer index outright and makes an element an
extended grapheme cluster, and `PasUnicode` offers a scalar view — so the
protocol's unit is a **third** one, and nothing in the text model answers in it
today. That reads as a reason to do it rather than a reason not to: it is an
externally specified stress test of the text model's central choice, which is
the one part of AP 6.4.15 that was argued for rather than measured.

**What is already in hand**, which is more than one would guess: `PasStream`
and `PasFile` for the files, `PasProcess.Capture` for invoking `pascalc`,
`PasParse` for reading the diagnostics back off it, `PasVector`, `PasList` and
`PasMap` for the tables, `owned ^T` and `take` for a document store whose
entries are replaced rather than copied (ADR-0181, ADR-0182), and `utf8(n)` for
the content — which would be the text model's first client outside a test.
**One library gap is visible before starting**: there is no JSON anywhere in
this tree, and LSP's every message is a JSON object. That is a module and not a
clause, which is the kind of gap this page likes.

**The IDE is not struck; it is later.** An editor wants a language server
inside it, so server-first is the right order even if both are eventually
written — and the terminal binding the IDE needs is small and obviously shaped
(a `pasx_` binding in `runtime/pasrt_posix.c` bounded by its headers, with
`<termios.h>` joining ADR-0186's catalogue) whenever something asks for it.

Everything after that is unknown on purpose. **The list of what this demands is
the product of writing it**, and enumerating it here would be designing
features without a caller — which is the practice this entry exists to serve
rather than to break.

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
| Actors / `Send`+`Sync` | Concurrent Pascal, Ada, Swift, Rust | concurrency | **Unblocked and unbuilt** (ADR-0201). It unblocks nothing, the two rows above having been answered without it; what it does is *end* the sentence the rest rests on — a borrow cannot outlive a call because the caller is not running during it. So the construct must be **share-nothing**, a task owning what it is given, and the lineage to read is Pascal's own rather than Rust's: Concurrent Pascal had `process` and `monitor` in 1975. Not built, for ADR-0116's reason — nothing here wants it. **This row named its trigger and the trigger came and went in two days.** ADR-0201 said "a socket module serving more than one client is what would demand it, and `select` is the cheaper answer to try first"; ADR-0203 landed the module and ADR-0205 made it serve many, with `poll` and no construct at all. The cheaper answer was tried first and was enough, which is what ADR-0201 asked for. What a thread would still buy is a **slow client not slowing the others** — a different sentence, and one no program here has yet said. **A program that would say it is now named**: the [language server](#the-program-that-would-judge-the-language), where a `didChange` arrives while a compile is in flight and a cancelled request has to stop something already running. That is a proposal and not a caller — nothing of it is written — so the row does not move, but it is the first time this one has had a candidate rather than a hypothesis |

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

One option **closes** as the language diverges: a third-party differential
(FPC under `-Miso`, or p5) can only ever check the ISO 7185 core, because
nobody else implements this dialect. Worth spending while it is still worth
anything — it is the first item under the next heading.

---

## The open questions

Seven structural questions about the dialect and five items of *what is next*
used to stand here. Ten of the twelve are answered — the table at the end says
where — and what each found on its first run is in
[`doc/history.md`](history.md#what-the-roadmap-answered). **Two remain**, and
only one of them is a task: §2 below. §1 is a standing risk no record can
close, which is why it is first — it is read every time and finished never.

### 1. The dialect has no external authority, and every gate here is anchored in one

A standing **risk** rather than a task, and the one entry no record can close.

| | ISO 7185 | Extended Pascal | the dialect |
| --- | --- | --- | --- |
| third-party corpus | BSI, 812 programs | — | **—** |
| second implementation (`difftest`) | yes | yes | the refusal surface only (ADR-0160) |
| clause-cited scenarios | yes | yes | yes (ADR-0135) |
| independent reading | ADR-0101, ADR-0107 | ADR-0101, ADR-0107 | [the spec](afterschool-pascal-spec.md), audited once (ADR-0144) |
| goldens, irtest, `verify/` | yes | yes | yes |

Every oracle in this repository bottoms out in *the standard says X*, and no
oracle here can contradict a **reading** — which is how ADR-0072's set-packing
deviation survived in four documents and a purpose-written test. For the two
conformance modes the remedy is independent readers holding the standards text
(`.claude/skills/langspec-audit/`). For the dialect there is no text but the
one this project wrote, so an audit can check every claim the specification
makes *about* the standards — nine were wrong the first time — and cannot check
a requirement the dialect invents, where a reader can only ask whether the
processor agrees with the document.

What is still empty is the first row, and nothing can fill it: there is no
third-party corpus for a language this project invented, and the BSI suite is
unavailable for a second reason besides — the dialect contains Extended Pascal,
not ISO 7185. The second row is partial: everything the dialect **accepts** is
compared by no second implementation. A high citation fraction means the
specification is young and was written against a compiler someone could probe,
not that the dialect is as well checked as the conformance modes.

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

### 2. A third-party differential

FPC under `-Miso`, or p5, over the ISO 7185 half of `tests/`. Not a second
implementation to maintain: a second *answer*, on programs that already exist.
**The only candidate that would contradict a misreading** — the BSI suite is a
fixed corpus from 1982, and `difftest` compares this project against itself,
both front ends being written by one author from one reading. Closes as the
language diverges, so it is worth more now than later.

### 3. ~~Mutation testing, committed to the tree~~ — done (ADR-0207)

`tests/mutation/` holds one file per recorded mutation and a harness that runs
them. Both conditions this entry named are enforced by it, and a **third**
arrived while ADR-0205 was being written: a mutant restored with a plain `cp`
and a `touch`, correctly by the old rule, and never rebuilt — so the next run
measured the mutant and a golden was taken against it. The rule was right and
one step too short.

What is left of the entry is a caution rather than a task, and it is in
`doc/sop.md` §7: the catalogue is a **register of demonstrations, not a
measurement**. **Eleven** mutations are files, all eleven killed on
2026-08-26 — and `ls tests/mutation/mutants/` is where to count them, because
this sentence has already gone stale once. Two hundred records carry a
mutation in their *prose*, most naming code that has since moved. "The
mutation suite passes" means those eleven claims still hold and nothing more.

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
added to `selfhost/compiler.pas` — the gate reports 4999 as this is written,
and the comparison has no mode that reproduces itself, so the day it was taken
is part of what it says.

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
`seed/pascalc.ll` is generated for x86-64, and `seed/README.md`'s target lock
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
  beside the string rather than underneath it — `utf8(n)`, which
  `--std=afterschool` now has (ADR-0191). *The text model, above.*

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

**A discriminated-schema is not a parameter-form, and this compiler accepts
one** (ADR-0171). §6.7.3.1 admits `type-name | schema-name | type-inquiry`, so
`procedure q(x: string)` is right and `procedure q(x: string(5))` is outside
the grammar. Three sources under `tests/extended/` write the second spelling
and would have to change. What is probably right is to refuse it under the two
conformance modes and admit it in the dialect with a clause of its own — it is
exactly the convenience ADR-0109 says belongs there, and the spelling already
passes ADR-0140's test. *A feature with its own record, written down rather
than done because it takes something away from every program that uses it.*

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
| Does the dialect spend reserved words? | No, permanently: a feature is spelled where a conforming program could not have written it, and `reserved-words` enforces it | ADR-0140 |
| Does containment survive the link? | Yes, except where the dialect would emit a check the other mode does not; the conforming `lib/` is reachable from the dialect | ADR-0137 |
| Is containment witnessed by more than one program? | The whole of `tests/extended/` under `--std=afterschool`, every run | ADR-0138 |
| Are the dialect's pieces coherent? | Four result shapes, one rule in two questions; a boundary shape may be a parameter and not a result | ADR-0141, ADR-0149 |
| Do the conformance modes "stay exactly as they are"? | What they accept does not move for the dialect; what they say may | ADR-0154 |
| Memory safety: deferral or discovery? | Discovery, twice. Lifetime was already answered, by the file variable (ADR-0151); aliasing was too, by refusal for the three affine kinds and by a **borrow that cannot escape** for the rest — Pascal has no address-of, so no pointer can name what a `var` parameter refers to. What is left of the fork is two threads of control and nothing else | ADR-0151, ADR-0201 |
| An oracle nobody here wrote | The BSI suite, fetched not committed; `src/` back as a reference front end | ADR-0086, ADR-0108 |
| Diverse double-compiling | Run once, 2026-08-18, identical outputs; `seed/ddc.sh` | `seed/README.md` |
| Conformant array parameters, and level 1 | Done, and the 51 BSI level-1 programs found nine defects in the first implementation | ADR-0153 |
| Can anything measure what the corpus reaches? | Three coverage gates and a clause-cited suite | ADR-0103 – ADR-0106 |
| Mutation testing, committed to the tree | One file per recorded mutation and a harness that runs them; not a `ctest` case, because it edits the tree. A register of demonstrations and not a measurement | ADR-0207 |
| Is the platform lock scoped? | Three things, two done; 32-bit is what remains | ADR-0155 – ADR-0159 |
| Can a conforming program learn that a file is missing? | `binding(f).bound` says whether it is there | ADR-0172 |
| Can a program get its arguments as a list? | `argcount` and `argument(k)`, required identifiers of the dialect | ADR-0173 |
| Can a foreign address be owned? | A handle-type: a file variable for it, released where a file closes | ADR-0174 |
| What is a character, once a byte is not one? | A grapheme cluster; text is UTF-8 in normal form C, in a value with a byte capacity, and `char` is left alone because it cannot widen | ADR-0189 |
