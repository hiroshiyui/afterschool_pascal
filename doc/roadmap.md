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
| [What would make this practical to pick up](#what-would-make-this-practical-to-pick-up) | for someone working *with* the compiler rather than on it: no binary, no tour, a trap that names no line, a server that completes nothing — every row measured on 2026-09-02 with its command beside it, and the examples row already closed (ADR-0295) with seven findings from writing them |
| [The program that would judge the language](#the-program-that-would-judge-the-language) | the one client big enough to answer a usability question; [all twenty-seven of its findings are closed](#the-findings-all-closed) since 2026-09-03, and the chapter now carries the method rather than a list |
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
is waiting for and what [the language server](#the-program-that-would-judge-the-language)
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
| **to give a task a handle** | AP 6.4.12.7's move exists — a handle moves (ADR-0267) — and the argument block does not use it, so a task takes channels and transferable values and cannot be handed a socket or a stream. ADR-0267 was landed *for* this and is one increment early; the two records say so rather than implying each other |
| **to wait for one task** | There is no `Task` variable, no select over several channels, and no timeout on a send or a receive. A block joins every task it spawned, and a program needing anything finer writes a second channel |
| **to send a string** | `Transferable` admits one and the implementation copies `esize` bytes, which is right for a fixed-capacity `string(n)`. It has no case, so it is **unclaimed** rather than done — the distinction ADR-0080 exists to keep |

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
is learned, what it says when a program stops, and what an editor can ask of
it. None of these is a language feature and none needs a spelling.

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

- **No tour.** `doc/afterschool-pascal-spec.md` is an amendment in ISO
  numbering, `doc/adr/` is an audit trail, and `README.md`'s language section
  is a feature list 900 lines long. Nothing in the tree explains the dialect
  to a person who knows Turbo Pascal and wants an HTTP client by evening —
  what an owned pointer is *for*, when to reach for `T ! E` and when for an
  accessor, why a module's heading is its interface. The examples above are
  half of that document; the other half is prose that says why.

### Writing a daily program

- **A runtime error names no position.** Sixty-eight distinct trap messages
  stand in the corpus' `.err` files and **not one carries a file or a line**
  (`grep -rho 'runtime error: [^(]*' tests --include='*.err' | sort -u | wc -l`,
  and the same list filtered for `line` is empty). `array index out of bounds
  (1..3)` is exact about the bounds and silent about *where*, and a program
  of any size has a hundred subscripts in it. The emitted IR carries no debug
  metadata either — `grep -c '!dbg' selfhost/compiler.pas` is 0 — so a
  debugger stopped at the trap shows nothing. Two separable things: a
  position in every trap message is the compiler passing what it already
  holds, `ErrorAt` having the line and column of every node; a line table is
  textual metadata in the `.ll` and links nothing new, which is ADR-0085's
  bar. The first is the one that changes a user's afternoon.

- **What a program reads can be cut without a word.** ADR-0292 closed with
  a warning rather than a gap, and this row is where it lives now. `readln`
  truncates **silently** at the variable's capacity, §6.9.1 skipping the rest
  of the line, so the capacity a reader declares is a decision and not a formality —
  which is why `DumpLineMax` is derived from `MaxPath` and not counted. And
  `PasFile.ReadLine` and `ForEachLine` still hand a caller a `FileLine` of 255
  and cut the rest away without a word. No client here has been bitten by that
  one, so it is written down and not fixed: ADR-0116's bar, applied to the
  module next door.

  From the user's side it is one thing: **a line longer than a number the
  program did not choose is lost, and nothing says so.** The library half is
  a schematic formal, which is what ADR-0291 did for `PasJson`; the language
  half is a decision about whether a truncating read may be *reported*, and
  it has not been probed.

- **Concurrency is one increment short**, and the rows are in [What each
  landed feature left open](#what-each-landed-feature-left-open): a task
  cannot be handed a socket, cannot be waited on singly, has no select and no
  timeout. Nothing to add here but the observation that these are the three
  things the first real server written with tasks will want in its first
  hour.

- **A task cannot close the channel downstream of it, and the program that
  tries deadlocks in silence** (ADR-0295, finding 1). `release(c)` on a
  channel a task was *handed* drops that task's reference and does not
  close — `runtime/pasrt_task.c`'s `pas_chan_unref` says so and nothing a
  program's author reads does — so a pipeline of stages each closing the
  next is unwritable by close, and the first draft of
  `examples/pipeline_tasks.pas` hung at once. The command that shows it:
  give a stage `k := release(out)` after its loop and run it under
  `timeout 5`. The example ends its stages on a sentinel. The cheap answer is
  a compile-time refusal of `release` on a channel parameter inside a task;
  the other is a sentence in AP 6.9.3.13.

- **The library has not caught up with the language's inference, measured
  again** (ADR-0295, finding 2). `MapGet(CountMap, integer, counts, w, 0,
  StrHash, StrEq)` is seven arguments for a lookup, two of them types the
  call already knows, because a type appearing only in the result must be
  written and ADR-0254's rule is then all or nothing. `MapPut` beside it
  writes none. `examples/word_freq.pas` is the measurement the row above
  asked for, and it reads as a program about `MapGet`'s signature.

- **Four of twelve example programs collided with a library name on their
  first draft** (ADR-0295, finding 3). Pascal folds case, so `info: InfoResult`
  is a second declaration of `PasFS.Info` and `parts: Parts(16)` of
  `PasText.Parts`. The names are the nouns a caller reaches for first —
  `Info`, `Dir`, `List`, `Parts`, `Stream` — and `tests/dialect/lib_dir.pas`
  already carried a comment warning about one of them. Three of the four
  diagnostics were exact; `info := Info(child)` reports *cannot assign
  integer to a variable of type inforesult*, naming a type nothing in the
  source holds, and that one is the compiler's.

- **Three smaller reports from the same pass** (ADR-0295, findings 4 to 6):
  an owned pointer refuses `p := nil` where a handle takes it as its early
  release, and the refusal does not name `dispose`; `PasJson` renders `0.75`
  as `7.500000000000E-01`, which `examples/json_pretty.out` now holds so the
  day it changes is visible; and a `MapKey` is 63 characters, so a map keyed
  by text from outside needs a guard the example has to explain.

### Tooling

- **The server answers thirteen methods and none of them completes a name.**
  `grep -o "'textDocument/[a-zA-Z]*'" lsp/pasls.pas | sort -u` lists three
  notifications and ten requests, and `completion` and `codeAction` are not
  among them. In order of what they cost, guessed:

  | Request | What it is made of |
  | --- | --- |
  | `codeAction` | the four warnings each know the edit they want — add `protected`, delete the declaration, delete the statement after the one that leaves — and the compiler already has the positions (ADR-0272, ADR-0277, ADR-0278, ADR-0283) |
  | `completion` | the one an editor user misses within a minute, and the one with a design in it: the outline gives the names in scope after a parse, but what may follow a token is the parser's knowledge and `--dump-symbols` stops before Sema |

  Completion is the row a person notices. `references` and `rename` stood
  above these as the rows that were nearly free, and were (ADR-0294): the
  cached `use` rows read backwards, plus one compilation per component for a
  name declared in one. What doing them found is in `doc/history.md`, and
  the sharpest part was not the server's — the compiler had reported every
  qualified name in an expression from its point rather than its start.

### Platforms and packaging

- **Windows and macOS are in the [cross-platform chapter](#what-is-left)**,
  and are not repeated. The one sentence worth adding from this side: macOS
  is the cheapest unknown in the tree — the runtime's five non-ISO names are
  all there — and a language nobody has run on a laptop is not yet practical
  whatever else is true of it.

- **A user's own multi-module program already builds itself**, and nothing
  tells them so. `import` resolution is transitive, `--dump-imports` tells
  `pascalcc` what to translate, and `AFTERSCHOOL_PASCAL_PATH` reaches an
  installed library (ADR-0244) — so there is no manifest to write and no
  order to maintain. That is better than most languages and it is stated in
  `README.md` only as a consequence of the install layout. It belongs in the
  tour.

**If one row from each section were taken first**: a binary, a line in every
trap, `references`, and the examples. Three of the four were taken the next
day — the binary (ADR-0296), `references` (ADR-0294) and the examples
(ADR-0295), which paid twice as the sentence said: twelve cases, and seven
findings in *Writing a daily program* above. The line in every trap is what
is left, and `codeAction` is the tooling row now.

---

## The program that would judge the language

**A Language Server Protocol implementation, written in Afterschool Pascal and
for it**, and it is written: `lsp/pasls.pas` answers `publishDiagnostics`,
`documentSymbol`, `definition`, `hover`, `foldingRange`, `selectionRange` and
formatting for a document and for a range, and the same binary speaks MCP over
stdio when given `--mcp`. `lsp/README.md` says what it is and how to run it;
`.mcp.json` declares it as this project's own development tooling, which is
the loop closed from the other end — the program written to judge the language
is a program the people working on the language use every day.

It was proposed as **the caller** and not as a feature. Every gate here says
whether the compiler is correct; not one of them can say whether a program
large enough to get tired inside is *pleasant* to write in this dialect —
where the boilerplate collects, which of the three affine kinds gets in the
way, whether `T ! E` and `try` still read well at depth, whether a module's
export list is a help or a chore at the fortieth import. **The argument, why a
server rather than the text-mode IDE this chapter first proposed — now
withdrawn — and what
each of its increments found are in
[`doc/history.md`](history.md#the-language-server-and-the-bound-it-found-before-it-ran)**
— including the one result no golden here could have produced, an
independent client computing UTF-16 columns the server then agreed with, which
is the external authority open question §1 says the dialect structurally
lacks.

Nothing about the program is open, and since 2026-09-03 nothing that writing
it demanded of the language is open either. The chapter is kept because the
method is the product, and the method is written out below.

### The findings, all closed

Twenty-seven entries, and **all twenty-seven are in
[`doc/history.md`](history.md#the-language-servers-findings-as-they-were-recorded)**
— twenty-five acted on, and two that needed no action because each is a
thing a writer has to know rather than a defect. The last three closed
together on 2026-09-03 and each was a decision this chapter had been
carrying as a question: the library now uses the inference it asked for
(ADR-0297), no two library modules export one spelling and a gate holds it
(ADR-0298), and every file variable is bindable (ADR-0299). Two of the three
were wrong as recorded — the collision entry had counted three of
thirty-seven, and the bindable entry's *nobody has asked twice* was answered
by counting — which is the shape the whole register has: a finding recorded
and left is a finding wasted, and the rule that made the first one
actionable was this section's own — one site is an anecdote, two are a demand
(ADR-0116).

The shape of the register is the argument for the chapter: five of the
twenty-seven were **bounds** — 8 imports, 24 arguments, a 63-character key, a
255-character line, a 16 384-byte capture — and every one of them was chosen
by counting what the largest thing in the tree needed at the time. The
largest thing in the tree was a test case.

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
activity and had never been done. Three came out of one pass and all three
are closed: one in both its halves within four days (ADR-0290, ADR-0291,
ADR-0292), which taught that the pass that finds an annoyance can also file
a defect as a taste; the accessor finding by ADR-0297, whose probe found two
compiler defects a green suite had not, and whose retaken measurement answers
the depth question — `try` reads well four levels deep across two modules,
and a server has no place for it because a server answers every request; and
the `only` finding by ADR-0298, where the fortieth-import program did not
need writing because reading the export-parts did. Of the four questions,
two are answered by those records, and two — where the boilerplate collects,
and which affine kind gets in the way — are still questions with no
finding against them, which after 3 280 lines of server is itself the
answer for now.

**What the examples then found** (ADR-0295) is the next register, and it is
in [*Writing a daily program*](#writing-a-daily-program) rather than here:
twelve one-page programs written to be read produced seven findings in an
afternoon, which is the sentence this chapter kept making — the next finding
comes from somebody writing a program.

**The text-mode IDE this chapter once proposed is withdrawn**, on 2026-09-01
and by decision rather than by discovery: the language server is the better
tool for what the IDE was wanted for, it exists, and it is in daily use here.
The reasoning that chose a server over it is in
[`doc/history.md`](history.md#the-chapter-as-it-stood-and-the-argument-it-was-made-on),
and so is the withdrawal. Nothing was lost in capability — `PasTerm` built the
terminal binding the IDE would have needed (ADR-0262), and it stands as a
library module like any other.

Everything after that is unknown on purpose. **The list of what this demands is
the product of writing it**, and enumerating it here would be designing
features without a caller — which is the practice this entry exists to serve
rather than to break.

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
| What did the language server demand? | Findings enough that the count is kept in one place and not four — [above](#the-findings-all-closed), which had said twenty-one where that section said twenty-six. Five were **bounds**, each chosen by counting what the largest thing in the tree needed at the time, and the largest thing in the tree was a test case. All twenty-seven are closed and in [`doc/history.md`](history.md#the-language-servers-findings-as-they-were-recorded); [above](#the-findings-all-closed) keeps the count | ADR-0236 – ADR-0249 |
| Is this a conforming processor or a dialect? | A dialect. `--std` and the two conformance modes are removed, the clause 5.1 a) compliance statement withdrawn, and 25 of 172 ISO 7185 cases became inexpressible — a conforming ISO 7185 program with a field called `value` no longer compiles. Five oracles retired with the surface they asked about. It is what version 3 is named for | ADR-0232 |
