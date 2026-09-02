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
| [The program that would judge the language](#the-program-that-would-judge-the-language) | the one client big enough to answer a usability question, and [the findings of its that are still open](#the-first-findings) — that section keeps the count, and this row deliberately does not |
| [Where the ideas come from](#where-the-ideas-come-from) | the borrowings from Rust, Swift and Zig — every row that named an open decision is now settled, the last by ADR-0268 |
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

**All four of the areas ADR-0109 names now have an answer**, the last of them
on 2026-08-30:

| Area | Where it is answered |
| --- | --- |
| networking | `PasNet` — a socket is a handle and both ends are strings, so `getaddrinfo` decides what they mean and no program writes a byte order — with `Wait` over `poll`, and `PasTls` and `PasHttp`/`PasHttps` above it (ADR-0203, ADR-0205, ADR-0264, ADR-0265) |
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

Nothing about the program is open. What is open is what writing it demanded of
the language, which is the product the chapter was for.

### The first findings

Twenty-seven entries so far, and **twenty of them have been acted on** — three
of the seven open are the usability findings below, which are recorded rather
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

The seven below are what a program of this size still runs into, and **five of
them are closed**. What is left is a rule about the language a writer has to
know and nothing tells them, and a decision nobody has asked for twice. The
closed ones are kept in place rather than moved to `doc/history.md`, because
what each is now worth reading for is what closing it found — two of them were
**wrong**, one was right and understated by a wide margin, and the last was
opened by closing that one and shut three hours later.

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

- ~~**`PasContainer`'s map cannot key on a URI.**~~ **Closed by ADR-0290, and
  the sentence was wrong.** It read: *`MapKey` is 63 characters and
  `file:///home/someone/projects/afterschool_pascal/selfhost/apfront.pas` is
  69, so the document store is a vector searched linearly* — and the map has
  been generic over its key type since ADR-0254. A probe keys one on a
  200-character string and stores the 69-character URI in it, so the map could
  always have held the document store and the entry named a limitation the
  library did not have.

  **What was true is one layer down.** `StrHash` and `StrEq` — the ready-made
  pair — were declared over `MapKey`, and ISO/IEC 10206:1991 §6.7.3.6 makes a
  procedural parameter's congruity exact, so a map keyed on any other capacity
  got the pair refused and its client wrote eight lines of its own. AP 6.7.3.6
  lets a schematic `string` value formal stand where a produced string type is
  written, the pair is schematic now, and a client writes nothing.

  **This is the second entry in this chapter to be corrected by a probe rather
  than by a test**, after the `T ! E` one above, and both corrections say the
  same thing: *the language could do it and the convenience layer could not*.
  The first illustration here was 44 characters and did not fit the claim; the
  claim itself then turned out not to fit the library. Nothing in this tree
  can check a sentence, which is why writing the probe is the only method
  there is — and it is cheap, and it was not done for eleven increments.

  `lsp/pasls.pas` was converted the same day, and the conversion is the last
  word on the entry: it **removed** code rather than adding it — `Store` went
  from two paths to one, and `Forget` from closing a gap in the vector by hand
  to deleting a key — and the nine `at: integer` declarations it left behind
  were named by the unused-variable warning rather than by a reader. Nothing
  got faster and nothing was meant to: an editor holds a handful of documents.
  The two mutations are what the change rests on, and they fail differently —
  a `Forget` that does not delete is a **double free** in three sessions, the
  text having been released while the entry stayed; a shutdown walk that frees
  nothing moves `heap_balance.txt`.

- ~~**`JsonLine` is 255 characters and a URI is not a line.**~~ **Closed by
  ADR-0291, and it was recorded as a bound that had not yet cost anything.** It
  had, three times over, and the entry named the least of them.

  What it said is that the server holds its document key at 255 *deliberately*,
  `DiagPublish` taking one, so a URI the server could hold and that module could
  not would be a truncation at the boundary instead of a refusal at the door.
  True, and two floors below it the same bound was doing worse. **The library
  did not truncate, it stopped the program** — §6.4.6 c)'s error at the call,
  `a string of length 300 does not fit a capacity of 255`. **The server answered
  go-to-definition with a URI naming a different file**, `PathToUri` appending
  under a `< LineMax` test and simply stopping, which a client resolves with
  nothing on either stream to say it was cut. **And the compiler had the same
  bound and it was the sharpest**: `nameStr` was 255 and its own comment read
  *"a file name or a command-line argument"*, so `pascalc` at a 310-character
  path stopped at `pas_str_fits` **naming no file**. A checkout a few
  directories deeper than usual is the whole of what it takes.

  Two comments in this tree had walked up to it and stopped. `compiler.pas`
  says of `envMax` that *"nameStr … is 255 and is the bound on one path"* and
  then never asks whether 255 is right for one path; `pasls.pas` says of
  `ItemMax` that four of this program's findings are *"bounds chosen by
  counting what the largest thing in the tree needed at the time"*. **A comment
  that names a hazard is not a check**, and the number sitting next to it was
  wrong in both.

  It closed as three schematic-parameter changes, one derived constant, one new
  gate — `long-path`, because no test case can choose its own path — and an
  **out-of-cycle reseed**: `BindingType`'s capacity for a program is decided by
  the compiler translating it, so the shipped `pascalc` went on reading its own
  arguments into a 255-character field however the source read. That is
  ADR-0126's sentence about the seed, met for a value rather than a buffer.

- ~~**`PasStrVec.ItemMax` is 255 and a dump line carrying a path crosses it.**~~
  **Closed by ADR-0292, and the design it asked for was not needed.** The
  entry proposed a container generic over its element's capacity, on the
  reading that the server needed one vector to hold both 40 821 short rows and
  a handful of paths. It needed **two**, sized by the two different facts, and
  the thing that had to be replaced was not the container at all.

  It was the *reader*. `PasProcess.CaptureLines` cuts every line at `ItemMax`
  — its contract says so, and the contract is right for the 40 000 rows it was
  reached for — and the server used it for a dump one of whose rows carries an
  absolute path. **Pascal's own `readln` reads a line into a string variable of
  whatever capacity the reader declared**, so the fix was to write the dump to
  a file and read it with the language rather than with the library: no
  container, no generic, no new capability, and one bound fewer than before.

  **The probe that found this took two minutes and the entry had proposed a
  language feature.** That is the third time in this chapter — after `T ! E`
  and the map — and all three corrections say the same thing a different way:
  the reach for a library convenience is what introduced the bound, and the
  language underneath it had none.

  What it leaves is a warning rather than a gap. `readln` truncates
  **silently** at the variable's capacity, §6.9.1 skipping the rest of the
  line, so the capacity a reader declares is a decision and not a formality —
  which is why `DumpLineMax` is derived from `MaxPath` and not counted. And
  `PasFile.ReadLine` and `ForEachLine` still hand a caller a `FileLine` of 255
  and cut the rest away without a word. No client here has been bitten by that
  one, so it is written down and not fixed: ADR-0116's bar, applied to the
  module next door.

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
