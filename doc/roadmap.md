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
| [The goal](#the-goal-adr-0109) | what this is all for — and all four areas ADR-0109 names now have an answer, which is not the same as the goal being met |
| [What each landed feature left open](#what-each-landed-feature-left-open) | the residue of the concurrency increment — three rows the record named itself — one FFI shape that has never found a client, and the chapter's prior about how few of them turn out to need the memory model |
| [What a daily program cannot reach for](#what-a-daily-program-still-cannot-reach-for) | nothing — the six library gaps and two language absences it listed are all built, and what is left is the chapter's lesson about its own error rate |
| [What would make this easier to work on](#what-would-make-this-easier-to-work-on) | nothing queued either: eight items for someone working *on* the compiler, all closed, one style decision left to whoever maintains this source, and the three lessons about how this page is written |
| [What would make this practical to pick up](#what-would-make-this-practical-to-pick-up) | for someone working *with* the compiler rather than on it: no binary, no tour, a trap that names no line, a server that completes nothing — the tour is written now (`doc/tour.md`) and found one defect in doing it, and the server completes a name (ADR-0301) — every row measured on 2026-09-02 with its command beside it, and the examples row already closed (ADR-0295) with seven findings from writing them |
| [Where the ideas come from](#where-the-ideas-come-from) | the borrowings from Rust, Swift and Zig — every row that named an open decision is now settled, the last by ADR-0268 |
| [The open questions](#the-open-questions) | the one structural risk no record can close — and it is the only entry left |
| [Cross-platform support](#cross-platform-support) | what the x86-64 lock turned out to be, and what is left of it |
| [Known limitations](#known-limitations) | what is wrong or absent today, in the dialect's own terms: one gap, three capacities and two decisions — the two lists headed by the standards retired on 2026-09-02, everything they stated being in the register already |
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

**All four of the areas ADR-0109 names now have an answer**, the last of them
on 2026-08-30:

| Area | Where it is answered |
| --- | --- |
| networking | `PasNet` — a socket is a handle and both ends are strings, so `getaddrinfo` decides what they mean and no program writes a byte order — with `NetWait` over `poll`, and `PasTls` and `PasHttp`/`PasHttps` above it (ADR-0203, ADR-0205, ADR-0264, ADR-0265) |
| internationalisation | AP 6.4.15's text model: UTF-8 in normal form C, an element is an extended grapheme cluster, an integer index refused — and Unicode's own conformance files judge it, which is the one oracle here nobody in this project wrote (ADR-0189 – ADR-0193, ADR-0196, ADR-0199) |
| concurrent execution | `task`, `spawn`, `channel [n] of T`, `send` and `receive`, reserving no word-symbol: share-nothing, only transferable values and channels cross, and every task a block spawned is joined before that block releases anything (ADR-0268) |
| memory safety | Optionals and no bare null, slices carrying their bounds, scope-based release, `owned ^T` for a variable `new` created, and the move both affine kinds need (ADR-0123, ADR-0125, ADR-0151, ADR-0181, ADR-0182, ADR-0267) |

**That is not the goal met**, and the distinction is the one this page exists
to keep making. A facility that exists is not a facility that is pleasant to
use, and ADR-0109's test was never *does the language have it* — no standard
governs this language, so that question has no asker — but **does a program
someone would actually write today need it, and can it get it**. What answers
that is somebody writing a program and finding it hard, which is what
[What a daily program still cannot reach for](#what-a-daily-program-still-cannot-reach-for)
is waiting for and what [the language server](history.md#the-language-server-and-the-bound-it-found-before-it-ran)
was written to produce. Two of the four areas have been used in anger by
something in this tree and two have not.

**The four *decisions* the goal forced are all made too** — three of them by
discovery rather than by design, and the fourth by deleting the thing it was
about. Not one decided the question its row was written to pose, which is the
part worth reading: the table, with what each answer cost, is in
[`doc/history.md`](history.md#the-four-decisions-the-goal-forced).

**One thing outlived its row.** The C++ reference front end went (ADR-0232),
and with it the last comparison of this front end against a second answer —
which is [open question §1](#1-the-dialect-has-no-external-authority-and-every-gate-here-is-anchored-in-one)
and `doc/sop.md` §7's largest entry, and is stated there rather than here so
that one fact does not come to disagree with itself.

What is already in hand and was not built for this: modules and separate
compilation (ADR-0053, ADR-0079) mean a library needs no new language
mechanism, and `runtime/pasrt.c` is where the outside world already enters.

---

## What each landed feature left open

Every row a survey of daily needs put here has been struck, and so has every
row the FFI and container increments left behind them. What stands here now is
the residue of the **concurrency** increment (2026-08-30), plus one shape that
has never found a client — and the prior the chapter arrived at, which is worth
more than any of the rows was.

**The chapter as it stood, with how each of its rows closed, is in
[`doc/history.md`](history.md#what-each-landed-feature-left-open).**

**What two threads of control left open** (ADR-0268, AP 6.7.8). The record
names these itself rather than letting the feature imply them, which is the
shape to expect from here on:

| A daily program wants | Why it waits |
| --- | --- |
| ~~**to give a task a handle**~~ | **Done** (ADR-0303), and the whole of what was missing was a *position*: `take` stood on the right of an assignment and nowhere else. A task formal may be a handle-type and the actual is `take(v)` — moved, where a channel is lent. Moved to [`doc/history.md`](history.md#the-concurrency-residue) |
| **to wait for one task** | There is no `Task` variable, no select over several channels, and no timeout on a send or a receive. A block joins every task it spawned, and a program needing anything finer writes a second channel |
| ~~**to send a string**~~ | **Done** (ADR-0302), and writing the case is what showed the reading was wrong twice over: `send` chose its path with `IsStructured`, which a variable-string is not, so the module did not assemble; and a string *value* is shorter than the element it goes into, so copying `esize` bytes read past it. Moved to [`doc/history.md`](history.md#the-concurrency-residue) |

**And one shape with no client at all**, which is what is left of the FFI rows:
a struct **member** that is itself a pointer. A record crosses as a `var`
parameter (ADR-0184) and comes back as an optional copied at the call
(ADR-0187), so `stat`, `readdir`, `gmtime` and `localtime` are all reachable;
a *chained* list of structs is not, a member that is a pointer being a second
name for storage that cannot be copied away. No program here has wanted one
badly enough to be written, and the two that looked as though they would were
answered in C. By ADR-0116's rule that is not a thing to build; what would
move it is a probe that cannot get its chain through a `pasx_` binding.

**The prior this chapter arrived at, and the one thing to carry out of it:**
**before recording that something waits on the memory model, ask whether the
address can be retired at the call.** Five times running it could, and twice
the answer was not a language feature at all but a `pasx_` routine doing the
walking on the far side. The factory (ADR-0255, ADR-0256) is the first item
where it does not apply, which is what makes it a prior and not a rule — a
factory's whole point is that the callee's answer *outlives* the call. Where
the answer is no, expect the ownership rule the five easy ones did not need.

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

**Nothing here is a task.** Five items stood in this chapter and all five
closed; three more were added afterwards and closed too — two built and one
declined. All of it is in
[`doc/history.md`](history.md#what-would-make-this-easier-to-work-on).

Two things are left, and only one of them is a decision.

- **A `style:` gate for the Pascal**, of the kind `git clang-format` gives the
  C. **Tried, measured and declined** (ADR-0285), and revivable the day a
  house style is agreed — the mechanism is already there, `format-check`
  formatting every source on every run and discarding the result. What stops
  it is that the diff is a disagreement about style and not a list of bugs.
  A full reformat of the implementation alone — `selfhost/`, `lib/`, `lsp/`,
  36 files — rewrites **25 070 lines** and grows the source **6.8%**: 818
  one-line `var` declarations split in two, 558 one-line `begin … end` bodies
  expanded, 210 blank lines inserted between headings written as a group.
  Fixing the five real layout defects the attempt found moved that number
  **up**, 24 490 to 25 070, which is what settles it. Deciding it belongs to
  whoever maintains this source.
- **An aarch64 `benchmark` baseline**, blocked on hardware rather than on a
  decision. The gate abstains on aarch64 and on CI (ADR-0282), so no push is
  guarded by it; a baseline needs an *idle* aarch64 machine, and the shared
  runner that exposed the gap is the one place a baseline must not be taken.

**Three lessons belong here rather than in the history**, because they are
about how this page is written.

**A number needs a date *and* a command.** The suite item said 262 seconds,
and every word of it was true of a configuration nothing used: it was measured
serially while CI had run `-j"$(nproc)"` on every push since the workflow was
written. The figure had a date, had been re-measured twice after an earlier
round of six wrong figures, and was still wrong — so the rule this chapter
gave itself was not enough. What closed it was a flag worth 3.4× (ADR-0281).

**A row saying a feature is blocked is a row nobody has tried.** Three rows in
succession were settled by attempting them, and each had carried a stated
reason it could not be done. The `protected var` warning said §6.6.3.6's
congruity made the fix illegal — it does, and the answer is to defer the
diagnostic to the end of the component, which is one page of code (ADR-0283);
the estimate under it said 81 sites where the truth is a **fixed point**, one
pass reporting 130 and seven reporting zero. `textDocument/rangeFormatting`
said the printer had to be *told* where its indent begins, which only a parse
can answer; the printer accumulates that depth itself as it walks the token
stream, and the whole feature is a gate on two routines (ADR-0284).

**And the lesson is not about this page.** ADR-0286 is the third instance and
it was found in `doc/sop.md` §7, which is a register of what is *not* checked
and so is the one document here whose rows are supposed to be uncomfortable.
A row there said nothing holds ADR-0283's zero, and gave a reason for
declining a gate: the count is a fixed point rather than a number, so a gate
would have to iterate to convergence. Iterating is what **reaching** zero
needed; holding it needs one sweep. The gate is 1.2 seconds, and removing one
`protected` from the compiler's own source leaves 798 of 798 cases green — so
the row was right about the gap and wrong about the cost, which is the same
shape twice over. **A reason written beside a declined item is an estimate
like any other**, wherever it is written, and this page's own rule applies to
it: it is a report or it is a guess.

**An item can be re-scoped by measuring it rather than by arguing about it.**
`--dump-uses --at line:col` was asked for and the measurement closed it the
other way: the flag saves no compiler time, and narrowing the query would have
cost the per-document cache that took five hovers from 795 ms to 159
(ADR-0276).

---

## What would make this practical to pick up

The chapter above is for someone working *on* the compiler. This one is for
someone working **with** it, and it was written on 2026-09-02 by asking what
separates the tree as it stands from a language a person picks up on a
Tuesday and has a program running by the afternoon. Every row was measured
before it was written, and the command is beside the number so that a reader
can take it again; where a cost is given it is a guess and says so, because
the chapter above has three rows that were wrong about exactly that.

Almost everything here is on the **outside** of the compiler. ADR-0109's four
areas are answered and both standards are complete, so what is missing is not
what the compiler accepts but what surrounds it — how it is obtained, how it
is learned, and what an editor can ask of it. None of these is a language
feature and none needs a spelling. What it said when a program stopped was
the first row here to close, the day after the chapter was written
(ADR-0293), and `doc/history.md` has what doing it found.

### Getting it and learning it

- ~~**No release carries a binary.**~~ — **done** (ADR-0296), and moved to
  [`doc/history.md`](history.md#the-first-archive). A `v*` tag now attaches
  an `x86_64-linux` and an `aarch64-linux` archive to its release, each
  checked the way `install-layout` checks a prefix before it is uploaded.
  The guess was an afternoon, most of it the CI job; the CI job was the
  cheap half, and the afternoon went on making the script fail on every push
  rather than at the tag.

- ~~**No program to read that is not a test.**~~ **Built** (ADR-0295):
  `examples/` holds twelve programs of a page each, every one a case, and
  writing them found seven things, all in *Writing a daily program* below.
  The row as it stood is in
  [`doc/history.md`](history.md#the-examples-and-what-writing-them-found).

- ~~**No tour.**~~ **Written**: [`doc/tour.md`](tour.md), eleven sections of
  prose with short programs in it, linked from the top of `README.md`. The row
  as it stood and what writing it found are in
  [`doc/history.md`](history.md#the-tour-and-what-writing-it-found).

- ~~**A source named with no directory finds no sibling module.**~~ — **done**
  (ADR-0308), the day the tour that found it landed. `SourceDir` answered the
  empty string where the answer is `./`, and `AddPath` drops an empty
  directory on purpose, so ADR-0244's first rule held for every spelling but
  `pascalc prog.pas`. Two right answers to two different questions, wrong
  together; `bare-source-name` is the gate, and it has to be one because no
  test case can choose how it is named.

### Writing a daily program

- ~~**What a program reads can be cut without a word.**~~ — **done**
  (ADR-0305), and moved to
  [`doc/history.md`](history.md#the-capacity-is-the-callers). `ReadLine` and
  `ForEachLine` take the caller's own string, and the language half needed
  nothing built: `read(f, s)` stops at the capacity *or* at the line's end, so
  `eoln(f)` immediately afterwards is false exactly when something was left
  over. The row said that half had not been probed; probing it took four
  lines.

- **Concurrency is one row short**, and it is in [What each landed feature
  left open](#what-each-landed-feature-left-open): a task cannot be waited on
  singly, and there is no select and no timeout. A task *can* now be handed a
  socket (ADR-0303) and a stage *can* close the channel downstream of it
  (ADR-0302). What is left is the observation that a single task's completion
  is the next thing the first real server written with tasks will want, and
  that a **channel of handles** is the shape behind both of the closed rows:
  a task may be given a socket at the moment it starts and not afterwards, so
  a fixed pool of workers taking connections off a queue is still unwritable.

- ~~**Four of twelve example programs collided with a library name on their
  first draft**~~ — **done** (ADR-0306), and moved to
  [`doc/history.md`](history.md#the-capacity-is-the-callers). The compiler
  defect was a placeholder type an error path left behind and a later rule
  spelled out; the naming half is a paragraph in `README.md` and not a rename,
  because every rename moves the collision rather than removing it.

- **Two smaller reports from the same pass** (ADR-0295, findings 5 and 6):
  `PasJson` renders `0.75` as `7.500000000000E-01`, which
  `examples/json_pretty.out` now holds so the day it changes is visible; and a
  `MapKey` is 63 characters, so a map keyed by text from outside needs a guard
  the example has to explain. ~~The third — an owned pointer refusing
  `p := nil`~~ — is **answered** (ADR-0307): the asymmetry with a handle has a
  reason, which is that an owned pointer already has `dispose` and a handle has
  nothing else, and the message names it now.

### Tooling

- ~~**The server answers thirteen methods and none of them completes a
  name.**~~ — **done** (ADR-0300, ADR-0301), and moved to
  [`doc/history.md`](history.md#tooling--closed-adr-0300-adr-0301). It answers
  fifteen now, and this section is empty. Both rows found something the row
  itself could not have: `codeAction` carries an edit for **two** of the four
  warnings and not three — deleting an unused local's declaration can delete an
  enumerated constant declared in its own type-denoter — and building it found
  ADR-0283's warning advising a word that does not compile, `protected`
  belonging to a formal-parameter-section and not to a parameter.
  `completion` refuses member completion for the reason its own row named, and
  needed `--dump-symbols` to start reporting formal parameters, which it never
  had.

### Platforms and packaging

- **Windows and macOS are in the [cross-platform chapter](#what-is-left)**,
  and are not repeated. The one sentence worth adding from this side: macOS
  is the cheapest unknown in the tree — the runtime's five non-ISO names are
  all there — and a language nobody has run on a laptop is not yet practical
  whatever else is true of it.

- ~~**A user's own multi-module program already builds itself**, and nothing
  tells them so.~~ **Told**: it is
  [`doc/tour.md`](tour.md#there-is-no-manifest-and-no-build-order-to-maintain),
  under a heading of its own — resolution is transitive, `--dump-imports`
  tells `pascalcc` what to translate, `AFTERSCHOOL_PASCAL_PATH` reaches an
  installed library, and there is no manifest and no order to maintain
  (ADR-0244). Writing that section is what found the row above it in *Getting
  it and learning it*: the claim is true of every spelling of the command but
  the one a person types.

**If one row from each section were taken first**: a binary, a line in every
trap, `references`, and the examples. Three of the four were taken the next
day — the binary (ADR-0296), `references` (ADR-0294) and the examples
(ADR-0295), which paid twice as the sentence said: twelve cases, and seven
findings in *Writing a daily program* above. The fourth went the same day
(ADR-0293), so all four are struck — and the Tooling section closed the day
after (ADR-0300, ADR-0301). What is left in this chapter is the tour and the
findings the examples produced.

---

## Where the ideas come from

Rust, Swift and Zig are the reference points, and they do not all fit equally:
Pascal's grain is value semantics, explicitness and a small orthogonal core,
which is close to Zig and Swift and further from Rust. Each borrowing was tied
to the open decision it would settle, and **every row that named one has now
been settled** — the last of them by ADR-0268.

| Idea | From | Settles | Where it stands |
| --- | --- | --- | --- |
| Slices — a pointer and a length | Zig, Rust | bounds safety | **Done** (ADR-0125, ADR-0129) |
| Optionals, and no bare null | Swift, Rust | pointer safety | **Done** (ADR-0123); the check is localised to `^`, not eliminated |
| Scope-based release | ISO 7185, Rust's `Drop` | lifetime | **Done, and it was already here** (ADR-0151) — for a *declared* variable; a created one had no owner until ADR-0181 |
| An owning pointer | Rust's `Box` | lifetime, for the heap | **Done** (ADR-0181, AP 6.4.14). Reached from the file variable rather than from Rust, and it decides nothing about aliasing because it admits no second name |
| A move | Rust's `mem::take` | what an affine type needs to be usable | **Done** (ADR-0182, ADR-0267). Given to an owned pointer first, then **widened to a handle** when a task needed to be handed a socket; a file has no value for a variable to stop holding, so the refusal there is a decision and not a gap |
| Error unions / `Result` | Zig, Rust | error handling | **Done** (ADR-0176, AP 6.4.13), and it needed no new type: `T ! E` denotes an ordinary record with a flag on it, so the copy, the layout and ADR-0118's trap came free and CodeGen was not touched |
| Propagation | Zig's `try`, Rust's `?` | the rest of error handling | **Done** (ADR-0178, AP 6.8.9). A required identifier and not a position, because a factor may be a variable-access — `try (x)`, `try [x]`, `try.f` and `try^` all mean something to a program that declares `try` |
| An early exit | Turbo Pascal, Delphi, FPC | what propagation stands on | **Done** (ADR-0177, AP 6.7.5.9). The first borrowing here whose source is another *Pascal*, and a branch to the epilogue every block already had |
| An early loop exit | Turbo Pascal, Delphi, FPC | nothing structural — an ergonomic gap | **Done** (ADR-0208). Taken whole from the three dialects that have it, down to the spelling: a question the standards do not answer and three Pascals answer alike is one where novelty would be a cost with nothing to show for it |
| `defer` | Zig, Swift | resource safety | **Done** (ADR-0175, AP 6.9.3.11). Zig's unit rather than Go's, because a per-activation defer runs a loop's `dispose(p)` once with the last `p` |
| Unicode-correct `String` | Swift | the text model | **Done** (ADR-0189 – ADR-0193, ADR-0196, ADR-0199). The grapheme as the unit and the refused integer index are Swift's and taken whole; the *storage* is not — a value with a declared capacity rather than a reference-counted buffer, which is what makes normalise-on-construction affordable and buys a bytewise `=` |
| Explicit allocator passing | Zig | part of memory safety | **Tried; does not survive contact** (ADR-0116) |
| ARC | Swift | aliasing | **Withdrawn as posed** (ADR-0201): ADR-0117's containment fixes what `^T` means and ARC changes it, so the candidate cannot reach the only reference type an ISO program has |
| Ownership and borrowing | Rust | aliasing | **The same, and half of it was already here**: a `var` parameter bound to an owned value's referent is a borrow, and it cannot escape because there is no address-of and `new` is the only producer of a pointer. *Unformable* rather than checked (ADR-0201) |
| Actors / share-nothing tasks | Concurrent Pascal, Ada, Swift, Rust | concurrency | **Done** (ADR-0268), and it is the row this table was really about — the one sentence left of the aliasing fork, *two threads of control*. `task`, `spawn`, `channel [n] of T`, `send` and `receive`, reserving no word-symbol: a task takes only transferable values and channels, may name only its own variables, and every task a block spawned is joined before that block releases anything — which is what makes *a borrow cannot outlive the call* true again. The lineage read was Pascal's own: Concurrent Pascal had `process` and `monitor` in 1975. **Built without meeting ADR-0116's bar**, which the record says in as many words — nothing in this tree wants it, and the compiler is one thread and must stay so, the seed compiling it. What it left open is [above](#what-each-landed-feature-left-open) |
| Traits / protocols | Rust, Swift | abstraction | **Half done, and narrowing.** Schemata gave parametric types over a *value* (ADR-0039); ADR-0209 lets a discriminant name a **type**, so a container is written once; ADR-0266 lets a type parameter say what it needs. What is absent is a generic *routine* over one — `lib/passort.pas` sorts by `less(i, j)` and `swap(i, j)` and never sees an element for exactly that reason — and abstraction over **behaviour** is a further thing again that nothing has asked for |
| `comptime` | Zig | metaprogramming | **Later.** Constant-expressions everywhere (ADR-0054) is as far as anything needs |

**The lesson this table is kept for**, drawn four times over and once against
itself: **measure the cost before naming the mechanism.** Three times the
expensive-looking sentence was not where the time went — `select` answered a
socket server where a thread was named, a cache took five hovers from 795 ms
to 106, and a `didChange` drain took four queued edits from 780 ms to 340 —
and once the *cheap-looking* route was the expensive one, polling an
unbuffered pipe measuring 621 ms against 5 on the operation a reader performs
most. The narrative is in
[`doc/history.md`](history.md#the-concurrency-row-and-the-four-cheaper-answers).

**And the other one: the cheap items are not the small ones.** `defer` and
error unions between them cover most of what "daily practical development"
means, and neither required settling the memory-safety fork. Four estimates in
a row — ADR-0122, ADR-0123, ADR-0176, ADR-0177 — assumed a feature would need
its own machinery and none of them did. Probe before believing an estimate of
that shape.

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

**The instrument for the risk is the adversarial audit** — independent readers
given the behaviour and not the reasoning, told to prove the compiler wrong
from the standards' text. Four have run (ADR-0162, ADR-0167, ADR-0168,
ADR-0171) and the last findings of the fourth closed on 2026-08-23; the
*Known limitations* chapter used to close with the note that the next is
worth running whenever that chapter has not moved for a while, and the note
belongs here, since a claim no test names is a claim nothing checks.

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
stale in two days: it said 4999 and the gate then said 8955. **And this
sentence went stale in its turn**, which is the argument rather than an
embarrassment -- 8955 stood here while `CLAUDE.md` said 9320 and the gate, run
on 2026-09-01, says **10 346**. Two documents answered differently about one
gate and neither was right. Run it.

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

**aarch64 works and is shipped; it is not seeded.** Since ADR-0296 every
release attaches an `aarch64-linux` archive, built and put through the whole
suite on an arm64 runner. What that archive does not claim is written in the
record and worth repeating: `seed/*.ll` is generated for x86-64 and
`seed/README.md`'s target lock stands, the compiler in the archive writes an
x86-64 header unless `--target=` or `AFTERSCHOOL_PASCAL_TARGET` says
otherwise (clang overrides it when it assembles, so a program is right and a
`pascalcc -S` file names the wrong machine), and CI establishes that the port
*works* — the seed retargets textually, the layout rules hold for a second
machine, the runtime's constants clear it — not that every oracle has run
there.

**Not every oracle follows.** `llc-second-backend` skips on the arm64 job, and
the SMT proofs are about the lowering *model*, the same file on either machine.
A miscompilation only an aarch64 backend produces has nothing looking for it
(`doc/sop.md` §7).

**The layout gate sees frames and nothing else.** A global's alignment, a string
constant's, and the ABI arguments travel by are outside it.

---

## Known limitations

Things that are wrong or absent today, listed so they are not rediscovered as
surprises. **Until 2026-09-02 this chapter was two lists headed by the two
standards**, and every entry in them was classified as a deviation from a
clause. ADR-0232 made that the wrong question — there is one language and no
clause governs it — and every fact the lists stated was already in
[`doc/implementation-defined.md`](implementation-defined.md), which is the
register of what this processor decides. What stays here is what is still
open in the dialect's own terms: one gap, three capacities and two decisions.
The chapter as it stood, with the two entries that had closed inside it, is
in [`doc/history.md`](history.md#the-known-limitations-chapter-as-it-stood-under-the-standards).

Six entries that stood here are the language's rule now and are looked up in
the register rather than here: an identifier may contain an underscore (§5);
`ExpDigits` is what C's `%E` writes (§2.3, E.13); §6.5.6's substring aliasing
rule is not enforced (§3, D.17); a variable created by `new(p, c1, …, cn)`
may be assigned or passed (§3, D.25); a textfile's last line need not end in a
terminator (§2.4); and a `char` is a byte, which ADR-0189 records *cannot*
change and answers with a type beside the string rather than underneath it
(§2.2, ADR-0191).

**One gap: an ordinary pointer can dangle.** `dispose(p)` stores nil into the
variable it was given, which turns the common form of use-after-dispose into
the nil trap, and does nothing for a second pointer to the same storage
(ADR-0019; the register's §3, D.4 and D.5). It is the aliasing half of the
memory-safety question, and ADR-0109 names memory safety as a property of the
language rather than a convention. The dialect's `owned ^T` sidesteps rather
than closes it: storage declared that way can have no second pointer, so
there is nothing to dangle, and §6.4.4's ordinary pointer is untouched —
ADR-0181 withdraws nothing. What would close it is a decision about the
ordinary pointer — kept as it is, retired in favour of the owned one, or
given a check — and it has not been asked with a caller. *The one entry here
that is a limitation in ADR-0109's sense.*

**Three capacities**, each a decision with a record and each a refusal or a
trap a program can meet:

| A program meets | Decided in |
| --- | --- |
| nesting deeper than 1000 levels is refused, and an operator chain is counted toward the same limit because it is flat for the parser and deep for everything after it | ADR-0020, ADR-0110; the register's §6 |
| a set's base type must have its values in 0..255, every set being one 256-bit word — so `set of integer` is refused, and so is `set of 1..m` for a bound the block evaluates, which cannot be checked against 0..255 before the program runs | ADR-0028, ADR-0133; §6 |
| string concatenation draws from an arena released at the end of every statement, so one *statement* holding more live string values than the arena holds is the limit, and both ways of exhausting it are reported | ADR-0111; §6 |

**One decision, and it has no record yet:**

- **`string(5)` as a parameter form** (ADR-0171). §6.7.3.1 admits
  `type-name | schema-name | type-inquiry`, so `procedure q(x: string)` is
  inside the grammar and `procedure q(x: string(5))` is outside it, and this
  compiler accepts both; three sources under `tests/extended/` write the
  second. There is no mode to refuse it under any more, so what is left is to
  admit it with a clause of its own or refuse it and edit three sources.
  Admitting it is the likely answer — it is exactly the convenience ADR-0109
  says belongs here and the spelling already passes ADR-0140's test — and
  what it wants is a clause and a record, not a change. Written down rather
  than done because refusing it takes something away from every program that
  uses it.

The adversarial audits that filled the old lists — four of them, ADR-0162,
ADR-0167, ADR-0168 and ADR-0171 — are [open question
§1](#1-the-dialect-has-no-external-authority-and-every-gate-here-is-anchored-in-one)'s
instrument, and that entry says when the next is worth running.

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
| What did the language server demand? | Findings enough that the count is kept in one place and not four — [the chapter as it closed](history.md#the-chapter-as-it-closed), which had said twenty-one where that section said twenty-six. Five were **bounds**, each chosen by counting what the largest thing in the tree needed at the time, and the largest thing in the tree was a test case. All twenty-seven are closed and in [`doc/history.md`](history.md#the-language-servers-findings-as-they-were-recorded); the chapter as it closed, in the same place, keeps the count | ADR-0236 – ADR-0249 |
| Is this a conforming processor or a dialect? | A dialect. `--std` and the two conformance modes are removed, the clause 5.1 a) compliance statement withdrawn, and 25 of 172 ISO 7185 cases became inexpressible — a conforming ISO 7185 program with a field called `value` no longer compiles. Five oracles retired with the surface they asked about. It is what version 3 is named for | ADR-0232 |
