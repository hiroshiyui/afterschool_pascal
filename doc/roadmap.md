# Roadmap

**A Pascal you can get daily work done in** (ADR-0109): a dialect and a
standard core library for networking, internationalisation, concurrent
execution, and memory safety as a property of the language rather than a
convention. Two goals came before it — bootstrapping, then conformance — and
both are **finished**; this is the only one left.

This page is kept to **what is open**, and to the rules for adding a row. An
entry here is something someone still has to decide about, and the day it is
decided it moves to [`doc/history.md`](history.md), which holds every
question this page has closed and what closing it found — including
[the page as it stood on 2026-09-07](history.md#the-roadmap-as-it-stood-on-2026-09-07),
verbatim, the moment before it was cut to this.

## Where development stands — 2026-09-13

**Released: v3.11.0, and `CHANGELOG.md`'s `Unreleased` is not empty.** What
stands on top of the tag is all of one subject: the library reads as **methods
of its types**. Sixteen modules export
203 names where they exported 354, `export-unique` counts 429 where it counted
527, and three rules were added to AP 6.7.10 on the way — one implementation of
a type per *program* (ADR-0413), an implementation only for a name the type was
given (ADR-0414), and a method may name itself through a receiver (ADR-0415).
**The version number is undecided** and is the next thing to settle: the
library rename breaks every existing client, which is what a major number is
for, while `release-engineering` defines the public interface as the accepted
language, the diagnostics and the command line and does not name the library.

v3.11.0's headline is the editor: it replaces, and two defects v3.10.0 had shipped a
day earlier do not happen any more — a Ctrl-Q that discarded another
document's work in silence (ADR-0401) and a menu that stopped the program on
F3 (ADR-0404 is the gate that could have caught it and had been pointed at
the compiler alone). v3.10.0 before it was display width as a *language*
question (AP 6.4.15.13, ADR-0395) with eight documents and a palette over it;
v3.9.0 was the editor arriving and WebAssembly running the corpus. The
compiler builds itself, stage 2 equals stage 3 in every program-component,
and the suite is 938 cases green at `-O2` and at `-O0`.

**The three releases before those are in [history](history.md)** — the
platforms measured rather than assumed (v3.8.0: `--target=` admits seven
machines where it admitted three, and Windows got as far as a program that
runs and was then dropped, ADR-0374 and ADR-0380), and the boundary audited
twice over (v3.7.0, ADR-0360 – ADR-0364).

| | |
| --- | --- |
| **Open and ready to do** | the platforms, and only the platforms: **macOS** runs green on arm64 and its job can now fail ([below](#cross-platform-support)), with nine skips left — every one a tool the runner has not got — and a release leg that ships an `arm64-darwin` archive since ADR-0375; **s390x** aligns `tySet` where nothing else does. **Windows is dropped** ([below](#cross-platform-support), ADR-0380) and what was measured about it is in history rather than deleted; **`wasm32-wasi` is admitted** (ADR-0383) and 571 of the 606 corpus programs run there (ADR-0385) — the runtime is two translation units short of five, and ADR-0405 is what made that a smaller number than it was: the file model was never what the target lacked |
| **Open and awaiting a decision** | the **version number** of the release the library rewrite has earned ([above](#where-development-stands--2026-09-13)), and a record's `Drop`, with exactly one asker. The object model is closed: all three of ADR-0315's increments are built, that record is superseded, and the rewrite that was to judge them is done |
| **Open and awaiting a program** | [the standard library](#the-standard-library), whose inventory is **empty**: a row there is evidence from somebody writing a program, not an item from a list |
| **Open and unavailable** | the two rows under [Deferred](#deferred-insufficient-resources): no second front end, and no third-party corpus |
| **In progress** | nothing is half-built. A feature lands with its clause, its record and its case, or it does not land |

**What moved most recently is the boundary**
([history](history.md#after-v360-a-configuration-file-and-the-boundary-audited));
before that the oracles
([history](history.md#the-oracles-that-were-not-looking)); before that the
memory model, struck as closed and corrected three times the next day
([history](history.md#the-memory-model-read-against-the-goal)). The lesson
that outlived the last of those governs every cost cell on this page: **a
cost cell is a report and not an estimate.**

---

## The language

Both standards were implemented and there is one language (ADR-0232), so
nothing here is owed to a standard; a feature needs a reason of its own. Two
of ADR-0109's four areas are answered here as properties of the language —
concurrent execution (ADR-0268, ADR-0312, ADR-0313) and memory safety
(ADR-0123, ADR-0125, ADR-0151, ADR-0181, ADR-0182, ADR-0267) — and neither is
finished in the sense that matters. **Nothing in this part is scheduled**, and
nothing here is where a decision lives: a decided thing goes to the
specification or the register, by [the rule below](#how-this-page-is-written).

### What each landed feature left open

Every row a survey put here has been struck, the concurrency residue closed in
a day (ADR-0302, ADR-0303, ADR-0312, ADR-0313), and what stands is three
**decisions**, each a question with an answer nobody has needed yet, and one
shape with no client:

- **A channel cannot carry a handle** (AP 6.7.8.1 NOTE 6, ADR-0302), so a
  fixed pool of workers taking connections off a queue is unwritable. What
  would make it expressible is a rule about which activation owns a value
  sitting in a bounded queue.
- **An activation cannot close a channel and then drain it** (AP 6.4.16.4
  NOTE 5): all three spellings of release empty the variable too. Closing
  without releasing would be a new operation, and it is not built.
- **There is no timeout on `wait`** (AP 6.9.3.14 NOTE 5, ADR-0312): a wait
  that gave up would leave a task-variable whose activation is still running,
  and no clause says what that is.
- **A struct member that is itself a pointer** has no client. A record crosses
  as a `var` parameter and comes back as a copy (ADR-0184, ADR-0187); a
  *chained* list of structs cannot, and by ADR-0116's rule that is not a thing
  to build until a probe cannot get its chain through a `pasx_` binding.

**The prior to carry out of this chapter**: before recording that something
waits on the memory model, ask whether the address can be retired at the call.
Five times it could; the factory (ADR-0255, ADR-0256) is the first case where
it cannot, a factory's answer outliving the call.

### Memory model and memory safety

Reviewed against *a Rust-flavoured Pascal* on 2026-09-04, **probed rather than
read** — and the pieces missing were not the ones the records said were
missing. Three of the review's four rows closed within two days
([history](history.md#the-memory-model-read-against-the-goal)), and the map of
what answers what — `owned ^T` for `Box<T>`, `take` for a move, a `var`
parameter for `&mut T`, `protected var` for `&T`, `?T` and `T ! E` for
`Option` and `Result`, `array of T` for a slice, `trait` for a trait —
is [in history](history.md#the-rust-flavoured-map-as-it-stood) row by row.
What is **absent** is lifetimes, `Rc`, `RefCell` and `unsafe`, and what each
of those left open is a sentence:

- **The escape half of the borrow rule is held by construction and watched by
  nothing.** Invalidation is refused where a borrow is formed (ADR-0319); escape
  rests on there being no way to form the value, so a feature that adds one
  takes the property silently. `doc/sop.md` §7 carries it.
- **A fifth warning — `new` of an ordinary `^T` where `owned` would compile —
  is not built**, because taking the word is sometimes wrong and a warning
  cannot know which (ADR-0337). The ordinary pointer is kept as the unchecked
  form (ADR-0336, [below](#known-limitations)).
- **A chain of a million owned nodes no longer ends in a signal; a shape that
  is neither a chain nor a tree still can** (ADR-0322, ADR-0333). A self-owned
  pointer held inside an array or sub-record has no link to thread, and a
  cycle of two domains is two routines calling each other. Reference counting
  is the unbuilt way out and nothing has asked; `examples/arena_graph.pas` is
  the shape that needs no language change.

#### A record has no `Drop`

A handle names its closer in its type and that is the only user code run when
a value dies; a record runs none, and `defer` is per activation (ADR-0175).
Every affine kind a record owns is *already* released from inside it — one
walk, four call sites — so what a record cannot run is an action **ordered
before** the release. **Exactly one site wants one**: `PasTls.Connection`
wants `SSL_shutdown` before its handles go. One is below ADR-0116's threshold;
should a second appear, the cheapest shape is ADR-0290's — no spelling at all,
a procedure in the record's own scope taking it as sole `var` parameter, run
before the field loop.

### The object model

**Closed.** All three of ADR-0315's increments are built, in six records
rather than three, and the library rewrite that was to judge them is done:
fourteen modules read as methods of their types, exporting 177 names where
they exported 325, and every module that is *not* converted has a probed
reason rather than a measurement. The chapter as it stood, with what each
increment cost and what the first client found, is
[in history](history.md#the-object-model-chapter-as-it-stood).


### Known limitations

What is still open in the dialect's own terms; every fact the two old
standards-headed lists stated is in
[`doc/implementation-defined.md`](implementation-defined.md), the register of
what this processor decides
([history](history.md#the-known-limitations-chapter-as-it-stood-under-the-standards)).

**One gap, decided kept: an ordinary pointer can dangle** (ADR-0019; the
register's §3, D.4 and D.5). Measured both ways out and both fail — *retire*
on the numbers, 0 of 41 type-definitions convertible, and on containment,
`new(p); q := p; dispose(p)` being conforming Extended Pascal; *check* on
cost, i386 leaving no spare address bits (ADR-0336). So the safe subset is
`owned ^T` with the non-escaping borrow, and §6.4.4's pointer is the
**unmarked default** — the inversion of Rust's `unsafe`, a fact about
containment and not a lapse.

**Three capacities**, each a decision with a record:

| A program meets | Decided in |
| --- | --- |
| nesting deeper than 1000 levels is refused, an operator chain counting toward the same limit | ADR-0020, ADR-0110; the register's §6 |
| a set's base type must have its values in 0..255, so `set of integer` and `set of 1..m` are refused | ADR-0028, ADR-0133; §6 |
| one *statement* holding more live string values than the arena holds is the limit, and both ways of exhausting it are reported | ADR-0111; §6 |

The adversarial audits that used to fill this chapter — five (ADR-0162,
ADR-0167, ADR-0168, ADR-0171, ADR-0342) — are [open question
§1](#1-the-dialect-has-no-external-authority-and-every-gate-here-is-anchored-in-one)'s
instrument.

---

## The standard library

**Thirty-three modules, and nothing open** — eight conforming and twenty-five
dialect, listed in `README.md`'s module table. The other two of ADR-0109's
areas are answered here and not alike: **networking** is a library facility
outright (`PasNet`, `PasTls`, `PasHttp`/`PasHttps`: ADR-0203, ADR-0205,
ADR-0264, ADR-0265), and **internationalisation is a clause of the language
with a library under it** (AP 6.4.15, ADR-0189 – ADR-0199), listed here
because that is where a program meets it.

### What a daily program still cannot reach for

**Nothing this page has thought of.** The chapter that listed six library gaps
and two absences closed at v3.2.0
([history](history.md#what-a-daily-program-could-not-reach-for-and-now-can)),
and the lesson is worth more than the list was: two of its eight rows said why
they were blocked and both reasons were wrong. **A row here is a report from
somebody writing a program, not an estimate from a list.** The newest module,
`PasToml` (ADR-0360), arrived that way, and so did the library's first request
of the language — a trait on a map's key (ADR-0355).

### Writing a daily program

Every row closed ([history](history.md#the-last-of-the-daily-program-rows)).
What the chapter predicted about its own order was right; every *reason* it
wrote beside a row was wrong, and each was found by compiling four lines.

---

## First-party utilities

Everything outside the compiler — how it is obtained, learned, packaged, what
an editor may ask of it — and it is down to **which machines it runs on**.
Every other row was struck within four days of being written
([history](history.md#the-roadmap-as-it-stood-on-2026-09-07) has the table,
and each row's narrative is a chapter there).

### The text-mode editor

`tui/` is open work rather than a finished thing, which is why it has a row
here at all. It was proposed, carried for six increments, **withdrawn by
decision** on 2026-09-01 — *"the language server is the better tool for what
the IDE was wanted for"* — and un-withdrawn on 2026-09-10 for two reasons the
withdrawal could not weigh
([ADR-0381](adr/0381-the-ide-is-un-withdrawn.md)): the *Pascal-lineage answer
key* the record itself named as what was being given up, and that this is a
hobby project. The server is undisturbed and the two answer different
questions.

**Two milestones have landed.** One is open, edit, save, compile, land on the
error. Two is undo and redo over a journal, find and find-again, and
go-to-line ([ADR-0387](adr/0387-an-undo-is-a-journal-and-a-prompt-is-a-mode.md)) —
and each of those three turned out to be a design question rather than a
feature, which is the argument for using the thing you are building.

**Display width was on this list and is closed** (ADR-0395), and it went the
way the list said it would — a *language* question first. AP 6.4.15 NOTE 14
had put the number of columns a value occupies outside this language, and that
was half right: no property of a character can say how wide it is in a
proportional font, but UAX #11 assigns East_Asian_Width precisely so a
fixed-pitch device can lay text out, and declining to provide it only moved
the problem into the editor. AP 6.4.15.13 defines it, `PasUnicode.Columns`
answers it, and a column in the editor is a cell.

**More than one file at once is closed** (ADR-0396), and it closed a *defect*
as well as a gap: `EditFault` was throwing the filename away, so a diagnostic
about another program-component jumped to that line number in whatever
document was open. Eight documents, F3 to open and F6 to cycle, and a
diagnostic naming an open one is landed on.

**Replace is closed** (ADR-0403), and it needed the model to grow rather than
the editor: an *action* a person takes may be more than one of ADR-0387's four
operations, and an undo that reverses one of six is an undo of nothing anybody
did. A journal entry may now say the undo continues through it, which is a
property of an entry and not a fifth operation, so replacing every occurrence
in a document is one Ctrl-Z. Confirm-each was **rejected rather than
deferred**: what a person wants after a replace that went wrong is to undo it.

**What is open**, in no order and none of it decided: a shaping model, which
is what East_Asian_Width is *not* — Arabic and Devanagari are laid out by
rules no per-code-point property expresses; resize, which needs a signal
facility this language does not have; mouse; and a **selection**, which is the
largest of them and is missing from four features at once — cut, copy, paste
and replace-in-a-region are one design and not four, this editor having no
notion of a region at all. The milestone-one and milestone-two exclusions are
listed in `tui/README.md` with the reason for each.

**What the shell emits is checked now** (ADR-0402), and the row that said
otherwise was `doc/sop.md` §7's oldest. `tui-terminal` drives the real editor
under a pseudo-terminal and requires every coloured run it writes to be one
the model decided, at the same columns, in the colour that role's table gives,
over both the twenty-four-bit and the eight-colour table. **It is not the
binding ADR-0262 declined twice** — the pseudo-terminal is the harness's, in
Python, as `lsp/run.py`'s pipe is, so nothing in this language knows about it
and no case tests a binding. The expectation is *derived* from the session
golden's own run decomposition rather than recorded, a golden of escape bytes
being one that agrees with whoever wrote it.

**What nothing checks** is narrower and is still real: that a terminal renders
those sequences as they are meant, and that an emulator setting `COLORTERM` is
telling the truth — neither checkable here at all — and three of raw mode's
six claims, the other three being reached by the editor not working without
them.

### Cross-platform support

Developed on x86-64 Linux; **aarch64 (ADR-0155 – ADR-0159), i386 (ADR-0325,
ADR-0346) and macOS on arm64 (ADR-0368) are built and run on every push**, and
each is shipped as an archive per release (ADR-0296, ADR-0375). How each was
admitted, what the 32-bit port's two width defects cost
([history](history.md#the-32-bit-port-and-the-width-it-left)) and what the
twenty-five-target measurement said
([history](history.md#cross-platform-support-measured)) are settled; run
`python3 tests/checks/target_layout.py` rather than quoting a target count.

**The tiers, since 2026-09-09.** **GNU/Linux is first**: the seed is generated
for x86-64, every gate has a job that installs its tools, and i386 is built and
run at two optimisation levels. **macOS (arm64) is second**: the whole suite
runs natively on every push and the job can fail (ADR-0368), with nine gates
skipping for want of a tool, and a release ships an `arm64-darwin` archive
since ADR-0375. **Everything else is unsupported and open to contributors** —
FreeBSD, OpenBSD, NetBSD, Haiku and Windows — with `README.md`'s *Platform
tiers* saying what a port starts from.

**Windows is dropped, since 2026-09-10** (ADR-0380), and what was measured
about it is [in history](history.md#windows-measured-and-then-dropped) rather
than deleted, so a contributor who wants it starts from a page of findings.

**Seven targets are admitted and two of them are WebAssembly.**
`wasm64-wasi` (ADR-0386) is closed: it cost nothing and nothing waits on it
([history](history.md#wasm64-and-what-admitting-it-cost)). **`wasm32-wasi` is
the open one** (ADR-0383) — the first target this compiler names that is
neither POSIX nor a machine. The compiler emits for it and the corpus runs
under a WASI runtime (ADR-0385); what is short is the runtime, and
`runtime-nonposix` is the measurement rather than an estimate: two translation
units of five, blocked by five headers wasi has not got and by threads it has
not got either.

| Target | What a wasm port still needs |
| --- | --- |
| **the runtime** | `pasrt_posix.c` over wasi's own interfaces, or a build that ships neither `PasProcess` nor `PasNet`; `pasrt_task.c` needs the threads proposal, so AP 6.4.16 and AP 6.9.3.12 are what a first port gives up. **The file model is not in that list** (ADR-0405, [history](history.md#the-editors-third-increment-and-three-gates-that-were-pointed-too-narrowly)): `pasrt_file.c` compiles for the target |
| **the driver** | `tools/pascalcc` links with `clang`, and `-pthread`, `-fPIC` and `wasm-ld`'s own `undefined symbol:` spelling are what a wasm link would differ in |
| **a runner** | every harness executes what it built; a `.wasm` needs `wasmtime` or `node`, and the two scratch argv paths need preopened directories |

**What is left** is small and specific:

| Target | What it needs |
| --- | --- |
| **macOS** | **Nine skips, and every one of them is a tool the runner has not got** — the job's comment lists them with the reason for each. The suite runs natively and the job can fail (ADR-0368), `--target=` admits both Darwin triples (ADR-0372) and a `v*` tag ships an `arm64-darwin` archive (ADR-0375). Nothing else here is open: how the list got from ten to nine, and what the first run cost, is [in history](history.md#the-macos-row-as-it-closed) |
| **s390x** | aligns `tySet`'s `i256` to 8 where every other target says 16 — thirteen offsets, and `target-layout`'s second claim would catch it |

**What is not claimed**: the seed is generated for x86-64 and stays so; the
aarch64 job establishes that the port *works*, not that every oracle has run
there — `llc-second-backend` and `benchmark` abstain on it (`doc/sop.md` §7);
and the layout gate sees frames and nothing else.

### What a helper is written in

**Decided in [ADR-0366](adr/0366-a-helper-is-not-a-shell-script.md) and
enforced since [ADR-0367](adr/0367-the-rule-about-helpers-is-enforced.md)**, so
what is left here is the rule and not the argument for it
([history](history.md#what-a-helper-is-written-in-and-the-one-it-left)). A
gate is Python 3 reaching for the standard library rather than a subprocess,
because the portability boundary is the set of external programs a helper
invokes and not the language it is written in; a helper that *ships to a user*
is written in Afterschool Pascal, `bin/apconfig` being the precedent
(ADR-0361); and a conversion lands with byte-identical output and that gate's
own mutation re-run, never with a green suite. `helper-portability` holds all
three, in both directions.

**One thing is left open and it moved when Windows was dropped.** The
catalogue is one line of shell — `tools/pascalcc`, which is the product rather
than a harness — and the standing argument against it was the Windows row,
where a `#!` line does not run at all. That row is gone (ADR-0380), so nothing
currently presses on the driver; a target that is not POSIX is where the
question comes back.

---

## Deferred: insufficient resources

Two rows whose blocker is a resource this project does not have, at the lowest
priority there is. The admission test: a row belongs here only if the cost is
a team or an artefact nobody can acquire, and not a reason that a probe would
settle — every reason of that second kind on this page has turned out wrong.

### 1. The front end has no second implementation

`difftest` retired with the conformance surface it compared (ADR-0232), so the
front end is guarded by goldens that agree with whoever wrote them, plus
`tests/spec/`. `doc/sop.md` §7 calls it the largest blind spot there. A second
implementation is a team-year **and** disputed in value — two readings by one
author is what `difftest` could never contradict either. `langspec-audit` is
the substitute in use.

### 2. There is no third-party corpus

BSI's 812 programs cannot be compiled here — 25 use a word-symbol §6.1.2
reserves — and nothing exists to acquire. `unicode-conformance` covers one
clause; `fpc-differential` (ADR-0234) is a second *processor*, reaches nothing
in `tests/dialect/`, and shrinks every release.

---

## How this page is written

Nothing in this part is an item of work: the goal is here because its useful
half is a **test**, the routing rule says where a decision goes, the lessons
are for whoever adds the next row, and the standing risk is read every time
and finished never.

### The goal (ADR-0109)

All four areas have an answer — networking and internationalisation in the
library, concurrency and memory safety in the language — and **that is not the
goal met**. The test was never *does the language have it*; it is **does a
program someone would actually write today need it, and can it get it**. What
answers that is somebody writing a program and finding it hard, so a row in
any part above is evidence from a program and not an item from a list. The
four decisions the goal forced are made, none deciding the question its row
posed ([history](history.md#the-four-decisions-the-goal-forced)).

### Where a decision goes

A row that closes is not finished when it is struck; it is finished when the
thing it decided can be looked up by somebody who never read this page.

| What was decided | Where it goes |
| --- | --- |
| a rule of the language, or a consequence a reader would otherwise derive | a clause or a NOTE in `doc/afterschool-pascal-spec.md` |
| an answer this processor gives where a clause leaves it open, a capacity, an error not reported, an extension | the matching section of `doc/implementation-defined.md` |
| a decision **not** to build something, where the absence would read as an oversight | a NOTE beside the construct it was not given to |
| why it was decided, and what it cost | an ADR, and neither of the two above |

**The third row is the one that gets missed** — two of the concurrency
residue's three shapes read as things nobody had got to until their NOTEs were
written — and the check is a reader, not a gate (`doc/sop.md` §7).

### Rules for the next row

- **A number needs a date *and* a command.** A figure with a date, re-measured
  twice, was still wrong because it measured a configuration nothing used
  (ADR-0281). Every count on this page names the gate that prints it.
- **A cost cell is a report and not an estimate.** Three were wrong within two
  days of the memory-model review, each a count taken by machine with the
  reason beside it written by hand.
- **A row saying a feature is blocked is a row nobody has tried.** Three in
  succession were settled by attempting them (ADR-0283, ADR-0284, ADR-0286),
  each having carried a stated reason it could not be done. A reason beside a
  declined item is an estimate like any other, wherever it is written. **A
  fourth, and this one was wrong in both directions**: the Windows row named
  three things and two of them — `access` and `_Complex` — were problems with
  MSVC and not with the platform, while the item that actually carries the
  weight, a socket layer, was not on the row at all. Half an hour with a cross
  compiler settled it; nobody had installed one.
- **An item can be re-scoped by measuring it** rather than arguing about it
  (ADR-0276), and **measure the cost before naming the mechanism** — four
  times the expensive-looking sentence was not where the time went
  ([history](history.md#the-concurrency-row-and-the-four-cheaper-answers)).
- **The cheap items are not the small ones.** `defer` and error unions cover
  most of what daily work means and needed no machinery of their own; probe
  before believing an estimate of that shape.
- **Ask the other Pascals before saying Pascal has no X.** `exit`, `break`,
  `continue` and `defer` were each spelled the way a Pascal already spells
  them, and argued for on their own grounds.

### Where the ideas come from

Rust, Swift and Zig are the reference points, each borrowing tied to the open
decision it settled — and **every row that named one is settled**, the table
being [in history](history.md#the-roadmap-as-it-stood-on-2026-09-07) row by
row. What is left of it: **`comptime`** is *later*, constant-expressions
everywhere (ADR-0054) being as far as anything needs; explicit allocator
passing was tried and does not survive contact (ADR-0116); and ARC was
withdrawn as posed, containment fixing what `^T` means (ADR-0201).

### The open questions

Twelve stood here and **eleven are answered**
([history](history.md#what-the-roadmap-answered), and the
[index](#answered-and-where) below). One remains and is not a task.

#### 1. The dialect has no external authority, and every gate here is anchored in one

A standing **risk** rather than a task. Every oracle here bottoms out in *this
project says X*, and no oracle can contradict a **reading** — which is how
ADR-0072's deviation survived four documents and a purpose-written test.

| | this language |
| --- | --- |
| third-party corpus, second implementation | **—** (both until ADR-0232) |
| clause-cited scenarios; goldens, irtest, `llc`, `verify/` | yes |
| independent reading | the spec, audited by readers isolated since ADR-0228 |
| a published third-party answer | Unicode's conformance files, for AP 6.4.15 alone (ADR-0189) |
| a second **processor** | Free Pascal under `-Miso`, programs only (ADR-0234) |

**What to do with it.** The instrument is the adversarial audit — five have
run (ADR-0162, ADR-0167, ADR-0168, ADR-0171, ADR-0342), the last finding three
holes every gate was green over. Where an outside body has published an answer
— POSIX, the C ABI, Unicode, an RFC — take its conformance data into the tree;
where the standards answer the same question differently, read both
(ADR-0152); where another Pascal has answered, that answer is a reference
point. **And the absence of an oracle is a fact about how a claim is checked,
never a reason not to make one**: where no authority answers, the dialect
answers for itself, in the standards' idiom, written in the specification and
pinned by a case that fails without it.

#### 2, 3 and 4 — answered

A third-party differential (ADR-0234), mutation testing in the tree
(ADR-0207) and *should the dialect read a type off a component?* (ADR-0215);
rows below.

### Answered, and where

Every question this page has carried and closed; the narrative of each is in
[`doc/history.md`](history.md#what-the-roadmap-answered).

| Question | Answer | Record |
| --- | --- | --- |
| Does the dialect spend reserved words? | No: a feature is spelled where a conforming program could not have written it | ADR-0140, ADR-0232 |
| Does containment survive the link, and is it witnessed by more than one program? | It did, and it was, until the modes went; `inherits_extended.pas` remains | ADR-0137, ADR-0138, ADR-0232 |
| Are the dialect's pieces coherent? | Four result shapes, one rule in two questions | ADR-0141, ADR-0149 |
| Memory safety: deferral or discovery? | Discovery, twice; what is left of the fork is two threads of control | ADR-0151, ADR-0201 |
| A third-party differential | Free Pascal under `-Miso`, six disagreements, all decided here | ADR-0234 |
| An oracle nobody here wrote | Retired with the modes; `unicode-conformance` is what is left | ADR-0086, ADR-0108, ADR-0232 |
| Diverse double-compiling | Run once; the window is closed | `seed/README.md`, ADR-0233 |
| Should the compiler be one source file? | No: three program-components | ADR-0233 |
| Conformant array parameters, and level 1 | Done; nine defects found | ADR-0153 |
| Can anything measure what the corpus reaches, and is that what the project is made of? | Three coverage gates and a clause-cited suite; then `lib/`, the runtime and the server measured, and the sanitizers seeing compiled Pascal | ADR-0103 – ADR-0106, ADR-0342, ADR-0349 – ADR-0358 |
| Is the memory model the one its records describe? | No, three of four rows closed in two days; a record's `Drop` stands | ADR-0317 – ADR-0337 |
| What separates this from a language a person picks up on a Tuesday? | Eight rows, every one struck within four days | ADR-0293 – ADR-0308, ADR-0348 |
| Mutation testing, committed to the tree | One file per mutation, a register and not a measurement | ADR-0207 |
| Is the platform lock scoped, and is a foreign scalar the width of its C type? | Three things, all done; and not by inspection — `foreign-width` holds the width as a catalogue | ADR-0155 – ADR-0159, ADR-0325, ADR-0328, ADR-0364 |
| A missing file, an argument list, an owned foreign address, a character | `binding(f).bound`; `argcount`/`argument`; a handle-type; a grapheme cluster | ADR-0172, ADR-0173, ADR-0174, ADR-0189 |
| Should the dialect read a type off a component? | Yes, `type of` over a whole variable-access | ADR-0215 |
| What did version 3 take, and what did the language server demand? | Four proposals, three records; twenty-seven findings, all closed | ADR-0229 – ADR-0233, ADR-0236 – ADR-0249 |
| Is this a conforming processor or a dialect? | A dialect, and version 3 is named for it | ADR-0232 |
