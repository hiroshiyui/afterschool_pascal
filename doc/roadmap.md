# Roadmap

**A Pascal you can get daily work done in** (ADR-0109): a dialect and a
standard core library for networking, internationalisation, concurrent
execution, and memory safety as a property of the language rather than a
convention. Two goals came before it — bootstrapping, then conformance — and
both are **finished**; this is the only one left.

What is open toward it, in three parts: **the language**, **the standard
library**, and **the first-party utilities** around them, followed by the
rules this page is written under. **All four of ADR-0109's areas already have
an answer**, the last on 2026-08-30, and that is [not the goal
met](#the-goal-adr-0109) — which is the distinction this page exists to keep
making.

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

## Where development stands — 2026-09-07

**Released: v3.6.0**, the first release whose headline is a **library**
change that breaks existing programs: `PasContainer`'s map keys itself with a
trait, so every map call loses two arguments (ADR-0355). `CHANGELOG.md`'s
`Unreleased` holds the day after it — a TOML library and the project reader
rewritten over it, and a command injection in the language server found,
closed, audited and audited again (ADR-0359 – ADR-0364) — none of it a change
to the language. The compiler builds itself, stage 2 equals stage 3 in every
program-component, and the suite is 905 cases green at `-O2` and at `-O0`.

| | |
| --- | --- |
| **Open and ready to do** | the platforms, and only the platforms — **and 32-bit is no longer among them** (ADR-0325, ADR-0346). **macOS has never been tried** and the runtime's five non-ISO names are all there, which makes it the cheapest unknown on this page; **Windows** needs two hand-written `FILE*`-over-memory functions, `_access` for `access`, and an answer for MSVC's missing `_Complex`; **s390x** aligns `tySet` where nothing else does, 13 offsets. Everything else below is a decision, a measurement, or a resource |
| **Open and awaiting a decision** | the object model, and only it — ADR-0315 is `Proposed`, its increment B is built, and A and C are judged separately. **B now has a client that is not a test** (ADR-0355), which is the evidence the proposal asked for and the one thing it had been short of |
| **Open and awaiting a program** | [What a daily program still cannot reach for](#what-a-daily-program-still-cannot-reach-for), whose inventory is **empty** and whose lesson is what it keeps in its place. A row here is evidence from somebody writing a program, not an item from a list |
| **Open and unavailable** | the two rows under [Deferred](#deferred-insufficient-resources): no second front end, and no third-party corpus |
| **In progress** | nothing is half-built. The parts below hold no partially landed feature — a feature lands with its clause, its record and its case, or it does not land |

**What moved most recently is the boundary** — set out in
[`doc/history.md`](history.md#after-v360-a-configuration-file-and-the-boundary-audited),
because it is settled and this page is for what is not. A path an editor
handed `lsp/pasls.pas` could run a command (ADR-0362); the audit over the fix
returned six findings, four older than the fix (ADR-0363); and one CI container
with a dirty register showed that a foreign scalar bound at the wrong width has
**no behavioural oracle on any one host**, so the claim is now a catalogue
(ADR-0364). Nothing in it was found by an oracle failing.

**Before that, the oracles** — in
[`doc/history.md`](history.md#the-oracles-that-were-not-looking).
**In short**: a coverage review asked what is measured and the answer was
46 718 lines of 67 931, so `lib/`, `runtime/*.c` and `lsp/pasls.pas` gained
gates of their own; the dumps a tool asks for turned out to have no corpus, and
`--dump-symbols` to crash on any source containing a trait; Valgrind went in
and reported **377 programs, 0 flagged**, which is a statement this project had
not been able to make before; and then the attribute ADR-0342 measured and
declined was taken, so **the sanitizers see compiled Pascal for the first
time**. Each of those had been true for as long as the thing it watches has
existed, and every one of them was found by asking what an oracle covers rather
than by an oracle failing.

**And before that**, the memory model was struck as closed on 2026-09-04 and
corrected three times the day after. Three of its four rows are settled and
[the chapter](history.md#the-memory-model-read-against-the-goal) has the
working; what stands is [below](#memory-model-and-memory-safety). The lesson
that outlived it is about its own cost cells — three were wrong within two days,
each in the same shape, a count taken by machine with the reason beside it
written by hand. **A cost cell is a report and not an estimate.**

## How to read this

| Part | What it holds |
| --- | --- |
| [Where development stands](#where-development-stands--2026-09-07) | the one-screen answer, dated: what is released, what is open and awaiting a decision, what is awaiting a program, and what is unavailable |
| [The language](#the-language) | what the compiler accepts, and what it does not: the concurrency residue, the memory model measured against the goal it is named in, the object model whose middle increment is built and whose other two nobody has committed to, and the limitations a program meets |
| [The standard library](#the-standard-library) | the thirty-three modules — and **nothing open**, which is a finding and not an omission |
| [First-party utilities](#first-party-utilities) | everything outside the compiler: obtaining it, learning it, the editor's questions, packaging, and the platforms it runs on |
| [Deferred](#deferred-insufficient-resources) | the two rows whose blocker is a resource this project does not have, at the lowest priority there is — with the admission test they had to pass, and the candidate that failed it |
| [How this page is written](#how-this-page-is-written) | [the goal](#the-goal-adr-0109) and the test it sets, the rules for the next row somebody adds, where the ideas came from, the one structural risk no record can close, and the index of what this file used to carry |

**The three parts are new, and the chapters inside them are not.** This page
was arranged by *how a row was learned* — a chapter for what a feature left
behind it, a chapter for what writing a program found, a chapter for what
picking the language up needed. That grouping is what taught the lessons at
the end, and it is kept inside the parts rather than thrown away; what changed
is that a reader asking *what is open in the language* now has one place to
look. Two chapters split rather than moved. **What would make this practical
to pick up** gave its *Writing a daily program* section to the library and the
rest to the utilities. **The goal (ADR-0109)** gave its four areas to the two
parts that answer them — concurrency and memory safety to the language,
networking and internationalisation to the library — and kept its *test* and
its table at the end, among the rules, because *the four areas are answered
and that is not the goal met* is a rule about what may be written here and not
a status line.

**Read the parts in order the first time and by name after that.** They are
not equally full, and the shape of that is the state of the project: the
language has half a proposal and four shapes, the library has nothing, and the
utilities are down to the platforms — every other row in them was struck within
four days of being written, which is what moved most of this file into
[`doc/history.md`](history.md).
[Deferred](#deferred-insufficient-resources) is last because nothing in it is
available to do.

---

## The language

**What the compiler accepts.** Both standards were implemented and there is
one language now (ADR-0232), so nothing here is owed to a standard; a feature
in this part needs a reason of its own, and the four chapters below are the
four kinds of reason that have worked. A feature *left something behind* and
the record named it. A property the language *claims* was measured against the
goal it is named in and the claim turned out narrower than the record.
Somebody *asked* for something the language does not have. Or a program *met*
a limit and the limit is written down.

**Two of ADR-0109's four areas are answered here**, and both are properties of
the language rather than facilities beside it — a third, internationalisation,
is a clause of the language too and is listed under [the standard
library](#the-standard-library) because that is where a program meets it:

- **concurrent execution** — `task`, `spawn`, `channel [n] of T`, `send` and
  `receive`, reserving no word-symbol: share-nothing, only transferable values,
  channels and a **moved handle** cross (ADR-0303), and every task a block
  spawned is joined before that block releases anything (ADR-0268). Since
  2026-09-03 a program can also *steer* it: an activation has a name and a
  type — `task` is a handle-type and `spawn t := P(x)` binds one — `wait(t)`
  joins that one early (ADR-0312), and the **select-statement** waits until one
  of several channels can proceed, with `after N` to give up and `otherwise`
  not to wait at all (ADR-0313).
- **memory safety** — optionals and no bare null, slices carrying their
  bounds, scope-based release, `owned ^T` for a variable `new` created, and
  the move both affine kinds need (ADR-0123, ADR-0125, ADR-0151, ADR-0181,
  ADR-0182, ADR-0267) — and **most of Rust's model, arrived at without
  reading Rust**, which is also how the four things it was short of went
  unnoticed until they were probed for. Three of the four closed within two
  days of being written down; what is left of them is a sentence each.

Neither is finished in the sense that matters, and what each left behind it is
the first two sections below.

**Nothing in this part is scheduled.** The one proposal in it is still
`Proposed`: its middle increment is built and has shipped, and the other two
have no commitment behind them — which is said again where it stands.

**And nothing here is where a decision lives.** Every row in this part that is
decided or implemented is written up in `doc/afterschool-pascal-spec.md`, in
[`doc/implementation-defined.md`](implementation-defined.md), or in both;
[the rule](#how-this-page-is-written) says which takes what, and a row that
closes is not finished until it has gone there.

### What each landed feature left open

Every row a survey of daily needs put here has been struck, and so has every
row the FFI and container increments left behind them. What stands here now is
the residue of the **concurrency** increment (2026-08-30), plus one shape that
has never found a client — and the prior the chapter arrived at, which is worth
more than any of the rows was.

**The chapter as it stood, with how each of its rows closed, is in
[`doc/history.md`](history.md#what-each-landed-feature-left-open).**

**What two threads of control left open** (ADR-0268, AP 6.7.8) is closed in
full, and the table is in
[`doc/history.md`](history.md#the-concurrency-residue) with what closing each
row found. Its four rows — to give a task a handle (ADR-0303), to wait for one
task (ADR-0312), to wait for whichever comes first (ADR-0313), and to send a
string (ADR-0302) — all closed on 2026-09-03, three of them named by ADR-0268
itself and the fourth by ADR-0295. **What the chapter is kept
for is what the closing rate says about the naming**: the record wrote its own
residue down rather than letting the feature imply it, and four rows that
closed in a day say the residue was named honestly. That is the shape to
expect from a feature record from here on.

**Three shapes stand behind the closed rows**, and none of them is a row
because none is a thing a program is waiting to be able to write — each is a
question with an answer nobody has needed yet.

- **A channel cannot carry a handle** (AP 6.7.8.1 NOTE 6, ADR-0302). A task
  may be *given* a socket at the moment it starts and cannot be sent one
  afterwards, so a fixed pool of workers taking connections off a queue is
  still unwritable. What would make it expressible is a rule about which
  activation owns a value sitting in a bounded queue.
- **An activation cannot close a channel and then drain it.** All three
  spellings of AP 6.4.16.4 — `release(c)`, `c := nil`, `c := take(d)` — empty
  the handle variable as well as closing the channel, so the close a `receive`
  or a select arm reports is always another activation's: the ordinary
  pipeline, a producer task closing what a consumer drains. It was met twice
  while ADR-0313 was written. Closing without releasing would be a new
  operation on a channel, and it is not built.
- **There is no timeout on `wait`**, and that one is a decision rather than an
  omission (ADR-0312, ADR-0313): a wait that gave up would leave a program
  holding a task-variable whose activation is still running, and no clause
  here says what that is.

**And one proposal, of which the middle increment is now built** (ADR-0315):
**methods and traits, without inheritance.** It is the first record in this tree that is *Proposed*
rather than *Accepted*. It is named here because it is what this feature's
residue turned into, and set out in full three sections down, in [The object
model (proposed)](#the-object-model-proposed). The evidence for it is this
project's own library: **139 of the exported names repeat their module's
noun** — `JsonMember`, `StreamOpenWrite`, `NetListen` — because §6.11.2 puts
every imported name into one scope and `export-unique` (ADR-0298) refuses a
collision, so the prefix is a receiver spelled by hand; and where a property
belongs to a *type*, the caller carried it instead — `MapPut(m, 'k', 1,
StrHash, StrEq)` was the shape, with **14 routine-valued parameters** across
two modules and **30 call sites** threading one pair through. **That half of
the evidence is collected**: since ADR-0355 the map's key implements `Key`, the
thirty sites name no pair, and what is left is `PasSort`'s two procedural
parameters and `PasFile`'s one, each taking a *routine* rather than standing
in for a property of a type. The prefix half stands. The denominator is the
gate's and moves: **490 exports across 32 modules** on 2026-09-07,
`python3 tests/checks/export_unique.py`; it read 486 when the numerator was
taken, 484 the day after and 489 the day after that.

The record proposes Rust's model and argues against Object Pascal's on four
grounds that are each about a decision already taken here, stages it in three,
and names what each stage costs — `dyn` being the only one that adds a
representation. **Its four open choices are settled**: all three stages, the
`impl` block, a receiver written out with its type, and one library module
rewritten as proof rather than a sweep.

**Increment B is built** — traits, implementations and the bound (ADR-0338 to
ADR-0341, AP 6.7.9). It is not the design ADR-0315 proposed for it, and the
correction is the interesting part: the bound belongs on the **schema's
discriminant**, where the client writes the type, because a routine over a
growable container takes a *pointer* to the schema and a pointer determines
nothing. ADR-0315's own payoff was unreachable from ADR-0315's own spelling.
Three further records exist because each corrected the one before it —
probing beat reading, building beat probing, and probing again beat the
obvious reading of how a trait reaches a client. **Increments A and C are not
built** and are judged separately; the question the record named as gating the
second stage does not arise, a bound being checked where the type is written
and not where inference chose one.

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

### Memory model and memory safety

**ADR-0109 names memory safety as a property of the language, and the bullet at
the head of this part calls it answered.** It is answered in the sense every
row here demands: each mechanism has a record, a clause and a case. This
section is what is left of a review on **2026-09-04** that read the model
against the goal stated as *a Rust-flavoured Pascal* and **probed it rather
than reading it**. The finding was not that the design is missing a piece. It
was that **the pieces missing are not the ones the records say are missing** —
ADR-0201 withdrew the aliasing fork as a question this language does not have,
and three of the review's four rows were aliasing. Those three closed within
two days; the working is in
[`doc/history.md`](history.md#the-memory-model-read-against-the-goal) and what
stands here is what they left.

**What is already Rust's, and by what route.** The routes are the interesting
column: not one of these was taken from Rust, and two were here before anybody
looked.

| Rust | Here | How it arrived |
| --- | --- | --- |
| `Box<T>` | `owned ^T` (AP 6.4.14) | from the file variable and not from Rust (ADR-0181) |
| `Drop`, RAII | scope-based release | present since 1982, unnamed until ADR-0151 |
| a move, `mem::take` | `take` (AP 6.4.14.6, AP 6.4.12.7) | forced by writing `PasList`, not designed (ADR-0182, ADR-0267) |
| `&mut T` | a `var` parameter bound to `o^` | *unformable* rather than checked (ADR-0201) |
| `&T` | `protected var` (§6.7.3.1), and since 2026-09-04 over an owned pointer too | ISO's own word (ADR-0283, ADR-0318) |
| `Option<T>` | `?T` (AP 6.4.11) | ADR-0123 |
| `Result<T, E>` and `?` | `T ! E` and `try` (AP 6.4.13, AP 6.8.9) | ADR-0176, ADR-0178 |
| `&[T]` | `array of T` (AP 6.7.3.9) | ADR-0125 |
| `Send`, channels | `task`, `channel [n] of T` (AP 6.4.16, AP 6.4.17) | ADR-0268 |
| traits | `trait` / `impl … for`, as a **bound** (AP 6.7.9, AP 6.7.10) | ADR-0338 to ADR-0341 |
| lifetimes, `Rc`, `RefCell`, `unsafe` | **absent** | the rows below, and the three that closed |

**Three of the four rows are closed**, and the working is in
[`doc/history.md`](history.md#the-memory-model-read-against-the-goal): the
borrow rule enforced in one direction (closed 2026-09-04, reopened and closed
again the next day — ADR-0317, ADR-0318, ADR-0319, ADR-0326, ADR-0332), the
unsafe subset being the unmarked default (measured and retired — ADR-0320,
ADR-0323, ADR-0336), and the release walk that ended in a signal (ADR-0322,
ADR-0333). **What each left standing is a sentence and not a row**, and the
three sentences are what this section is now for:

- **The escape half of the borrow rule is held by construction and watched by
  nothing.** ADR-0201's *unformability is what protects against escape and is
  exactly what makes invalidation invisible* is strength in one direction only.
  The invalidation half is refused now, at the point a borrow is **formed**
  (ADR-0319) — but the escape half rests on there being no way to form the
  value at all, so a feature that ever gives the language one takes the
  property away silently. `doc/sop.md` §7 carries it.

- **A fifth warning — a `new` of an ordinary `^T` where `owned` would have
  compiled — is not built, and the reason has changed three times.** It is no
  longer that nothing *could* take the word, nor that a rewrite is needed, but
  that taking it is sometimes the wrong answer and a warning cannot know which:
  an owned container cannot be aliased, cannot be returned by a function and
  must travel as a variable parameter, which is right for a tree one block owns
  and a real loss for a container callers pass around (ADR-0337). The ordinary
  pointer itself is *kept* and written down as the unchecked form (ADR-0336);
  [Known limitations](#known-limitations) is where that stands.

- **A chain of a million owned nodes no longer ends in a signal, and a shape
  that is neither a chain nor a tree still can.** The release threads a work
  list through the link fields of the nodes waiting on it (ADR-0322,
  ADR-0333), so a list and a tree each cost one frame; a self-owned pointer the
  domain does not hold **directly** — inside an array or a sub-record component
  — has no link to thread, and a cycle of two domains is two routines calling
  one another. Neither is reachable by writing a list or a tree. Reference
  counting is the way out that is unbuilt, and nothing has asked for it: the
  arena-and-index shape needs no language change and is written down as
  `examples/arena_graph.pas`.

#### A record has no `Drop`

A handle names its closer in its own type — `handle external 'fclose'` — and
that is the only user code this language runs when a value dies. A record
owning something runs none, and `defer` is per *activation* rather than per
value (ADR-0175), so a type cannot maintain an invariant across its own
release.

**This row said "nothing has asked for it yet" and that was wrong**, in the
shape ADR-0116 already catches twice: a reason written by hand beside a row
and re-read by nobody. One thing has asked, precisely, and says so in its own
header — `PasTls.Connection` (`lib/dialect/pastls.pas`) wants `SSL_shutdown`
sent before its three handles are released, because without the close-notify
"the far end cannot then distinguish the end of the data from a connection
that was cut".

**What that asker wants is not a release, and the distinction is the finding.**
Every affine kind a record can own is *already* released from inside it: one
walk (`WalkFiles`) has a record branch that recurses on every field answering
`HoldsFile`, and the block epilogue, `dispose` and the generated `@ownrelN`
bodies are its four call sites. A record holding a file gets `pas_file_done`
per field; one holding foreign handles gets a `pas_handle_done` per field
against the closer named at entry; one holding an owned pointer gets
`@ownrelN`, recursively and worklist-driven since ADR-0333. And
`ContainsFile` already makes such a record affine. What a record cannot run is
an action *ordered before* the release, and the corpus has exactly one site
wanting one.

So the row stays open for a better reason than the one it gave: **one site is
below ADR-0116's own threshold for a design.** Should a second appear, the
cheapest shape is ADR-0290's — no spelling at all: a procedure declared in the
record's own scope taking the record as its sole `var` parameter, run by that
record branch before the field loop. It would add no affineness, such records
being affine already.

### The object model (proposed)

**Increment B is built and increments A and C are not**, so what follows is
the record's own framing kept for the two that are still proposals. Read it
with ADR-0338 to ADR-0341 beside it: they are what B turned into, and each
corrects the one before.
[ADR-0315](adr/0315-methods-and-traits-without-inheritance.md) is the first
record in this tree with the status `Proposed`, and it was written that way on
purpose: the design was asked for on paper before any of it is implemented, so
that the shape could be argued about while the alternatives were still live.
Whether it is built is **not settled**. The two goals before this one —
bootstrapping, then conformance — were each finished before they were left, and
an area announced and abandoned would be the first thing on this page that was
neither.

#### What asked for it

Not a missing facility. Every program in `examples/` was written without an
object model, and the containers, the JSON reader and the language server are
all records with routines over them. What asked is the *second* clause of
ADR-0109's test — **can a program get it pleasantly** — measured on this tree's
own library:

- **179 exported names repeat their own module's noun, and increment A would
  retire 118 of them** — `JsonMember`, `StreamOpenWrite`, `NetListen`,
  `MapPut`. Out of **484** (`python3 tests/checks/export_unique.py`).
  **Retaken mechanically on 2026-09-05**, this page's own rule having called
  the previous `139` an estimate: the sweep reuses `export_unique.py`'s reader
  and asks two questions of each name — does it repeat the module's noun, and
  is it a routine whose *first formal's type* is a type the module exports,
  which is the only set a method can touch. The second is the number that
  matters, and it is **118 of 484, 24%**. The gap between the two is the
  finding: **59 of the repeats are types and constants** — `JsonPtr`,
  `JsonChars`, `ListItemMax`, `TlsHostMax` — which no method can ever remove,
  so they stay exported, stay prefixed, and the export surface a reader meets
  on `import` does not change at all. That is forced rather than chosen. §6.11.2 puts every imported name into one scope, so two modules
  may not export one spelling, and ADR-0298's `export-unique` gate refuses a
  collision outright. **The prefix is a receiver, spelled by hand, at every
  declaration and every call site**, and ADR-0306 renamed four examples' worth
  of them before anyone counted the rest.
- ~~**14 routine-valued parameters and 30 call sites** thread `StrHash, StrEq`
  through `lib/passort.pas` and `lib/dialect/pascontainer.pas`~~ — **the thirty
  are gone** (ADR-0355): the map's key implements `Key` and no call names the
  pair. Three routine-valued parameters remain, in `PasSort` and `PasFile`, and
  each takes a genuine routine rather than a property of a type.
- `lib/passort.pas` **never sees an element** — it sorts by `less(i, j)` and
  `swap(i, j)` — which is the *Traits / protocols* row of
  [Where the ideas come from](#where-the-ideas-come-from) said from the
  library's end.

#### The shape

**Rust's decomposition and not Object Pascal's**, and the difference is the
whole of the proposal: methods and traits without inheritance, so there is no
base class, no virtual by default, and no `is`/`as`. A method is an ordinary
routine whose first parameter is written out with its type — value,
`protected var` and `var` being what Rust spells `self`, `&self` and
`&mut self` — declared in an `impl T; … end;` block, and `x.M(a)` means
`M(x, a)`. Three increments:

| Increment | What it adds | What it retires |
| --- | --- | --- |
| **A. Methods** | the impl block, the receiver rule, `x.M(a)`, the type's own scope | the 139 prefixes. No new representation, no compatibility rule, no vtable, and CodeGen untouched — a method is an ordinary routine |
| **B. Traits, static** | the trait-type, `impl … for`, `Self`, and `T: Trait` bounds | the 14 routine parameters and 30 call sites. Resolved at instantiation, so still no vtable |
| **C. `dyn T`** | dynamic dispatch, permitted only as `owned ^dyn T` and as a var parameter | nothing — it is what a heterogeneous collection needs, and the first thing here that emits a vtable |

**A is not a prerequisite for B, and the record said it was** (2026-09-05).
ADR-0315's *Staging* table asserts "A is the prerequisite for B and B for C" in
one sentence with no argument under it, and the mechanism contradicts it.
`T: ordered` **compiles today**: AP 6.7.3.10.5 gives the type-parameter slot
four categories, recognised by `CatOfName` in `selfhost/apfront.pas` and
checked at the activation inside `InstantiateGeneric`. A trait bound is a
*fifth category in the identical slot, checked at the identical place*,
differing only in that the answer comes from a table of impls rather than from
a closed list of spellings. Increment A's three distinctive features are the
dot-call `x.M(a)`, the inherent `impl T;` block and method names living in the
type's scope, and **B uses none of them** — inside a bounded generic the call
is `Compare(a, b)`, resolved through the bound. What A and B genuinely share is
the `impl` keyword's position and its block grammar. B→C is real, a trait
object needing traits; A→B is not, and the record's own *Consequences* agree
without noticing, explaining the ordering as cheapest-evidence-first rather
than as a dependency.

**What that changes.** The measurement that passes ADR-0109's test is B's — 30
call sites and 14 routine parameters, a program's own text — and A's is 118
call-site spellings that block no program. With the toll booth gone, the two
are judged separately: B is the one to build, and A stands or falls on its
own.

**And B's own design did not survive being probed** (2026-09-05,
[ADR-0338](adr/0338-a-bound-belongs-where-the-type-is-written-down.md)).
ADR-0315 puts the bound on a routine's type parameter, and that cannot reach
PasContainer, where 30 of the call sites are: `Determine` has three arms --
`nkNamed`, `nkSchema` and `nkArray` -- and no pointer arm, 6.7.3.1's
parameter-form admitting no denoter to read a tuple out of, while the
container's routines must take the pointer because `MapPut` grows the map with
`new(m, bigger)`. Determined from the key instead, a string literal binds a type
per literal *length*, which is the failure `pascontainer.pas` already records.
**The bound belongs on the schema's discriminant** -- written `Map(K: Key;
V: type; cap: integer)` when it landed, one trait rather than `Hash + Eq`,
the language admitting one bound -- where the client writes the type down and
it is checked once. The 30 call sites did *not* stay unchanged, as this
paragraph predicted; each lost two arguments, which was the point (ADR-0355).

Two more findings came with it. The orphan rule contradicts the record's own
*What this does not do*, and taking either reading leaves `string(n)`
implementable by no component, since a type-name denotes an existing type object
and no component declared it -- so `impl` must be able to name a **schema**, or
increment B misses what a map is keyed by most of the time. And `T: Ord` is
ambiguous with an ordinary value parameter; the real slot is `T: Ord type`, the
parser already committing on that juxtaposition and merely refusing the name.

**Nothing was built at that point, and the record landing alone was the
point.** Each of the three was a contradiction of a design written without
probes, against a compiler that was there to be asked.

**Two of ADR-0338's own claims then failed the same way**
([ADR-0339](adr/0339-a-trait-heading-names-one-type-and-one-scope.md),
2026-09-05), which is the lesson holding for the record that stated it.
`Congruous` compares by type *identity*, so reusing it after substituting `Self`
works for a bare `self: Self` and not for `array of Self` -- 6.4.1 giving each
denoter that is not a type-name its own type object, so the trait's and the
impl's are two. `Self` is therefore admitted only as a whole parameter-form or
result-type, refused **at the trait-declaration**, because left to the impl the
message arrives once per implementation, in the wrong file, describing
procedural parameters to a reader who wrote none. `^Self` needs no rule at all:
6.7.3.1's parameter-form admits no pointer denoter, so it is unformable.

And a trait's routine names do collide, outright rather than as a catalogue
entry: 6.11.2 puts every imported name in one scope, and two modules exporting
`Compare` refuse the program with *'compare' is already declared in this
block*. The names a trait wants are the contested ones. The answer needed
nothing invented -- 6.11's `qualified` keeps both, probed -- but it is the
strongest argument yet for **increment A**, and not the one A is justified by:
`x.Compare(y)` resolves in the receiver's type scope and is the collision-free
form of what `qualified` here answers by hand. A is still not a prerequisite
for B; it is now something better, a reason of its own.

**And then building it found four more**
([ADR-0340](adr/0340-four-things-a-trait-heading-cannot-do.md), 2026-09-05),
which is the third turn of one wheel: ADR-0338 was written because probing beat
reading, ADR-0339 because a probe beat that record's own claims, and this
because **building beat probing**. A trait, an implementation and a dispatching
call now compile and run on the `traits-b` branch, which does not pass its
gates and is not for merging. All four findings are limits on what a trait
heading can say. It cannot name its receiver `self` -- 6.1.2 case-folds, so the
parameter name and the type name `Self` are one identifier, and every record
before this used `self: Self` as its example. Its routines cannot live in the
block's scope, two implementations of one trait each defining one spelling, so
they are declared in the implementation's own scope and reached by a
**trait-keyed** selection on the first actual's type -- which is not increment
A's per-type scope and is what keeps A out of B's way. It cannot be resolved
once, resolution annotating shared nodes so that the second impl reads the
first's types; it is re-parsed per implementation from its token position, as
AP 6.7.3.5 already re-reads a generic's body and for that clause's own reason.
And it cannot take a `protected var` receiver and serve a subrange: selection
does follow `Base()`, and then 6.6.3.3 refuses the call, a var parameter
requiring an actual of the same type. ADR-0315 asserts both halves of that last
one. The advice that falls out is that **a trait meant to serve subranges takes
its receiver by value**, which `Ord` and `Hash` both should.

**And separate translation was the question none of the three had asked**
([ADR-0341](adr/0341-a-trait-crosses-a-component-and-an-implementation-need-not.md),
2026-09-06). 6.13 has a client translate against the interface alone, so an
implementation written in a module-block is invisible to every importer -- and
the obvious reading, that this makes the feature useless in a library, is
wrong. A module may declare a trait in its interface, bind a schema's
discriminant with it there, and have its own routines dispatch to an
implementation **the client** wrote: probed at 93, the library's body reaching
the client's `Hash`. It works because such a routine is generic over its
pointer, and AP 6.7.3.5 re-reads a generic's body in the translation that
activates it -- the client's. That is the shape `PasContainer`'s routines
already have, so **the payoff needs no implementation to cross a boundary**.

One case remains and is **deferred rather than built**: a module shipping its
own implementation for its clients. The argument is ADR-0116's, not cost -- a
client writing one `impl Key for MapKey` block still removes `StrHash, StrEq`
from all 30 call sites, so the whole measured payoff survives without it --
and on 2026-09-07 it did (ADR-0355), every client of the map writing its own
block and every golden unchanged. Of
the two ways to build it, one does not exist: `NameForLinkage` derives a
cross-component name from the export-part, and separate translations share no
symbol table, so the per-impl-scope option collapses into the derived-name
option plus extra machinery. Reopening it has one candidate, not two.

Building it also found three defects reading had not. An implementation nested
in a procedure gave **a wrong answer with a zero exit status** -- 14 where the
answer was 106, the table being one unscoped list and the call passing whatever
frame it had. A module-heading did not interleave its declarations by written
position, so a trait was invisible to a schema declared above it in its own
interface. And a call that selected two implementations took the one declared
last, silently. All three are refused or fixed.

**And the first client found two more**
([ADR-0344](adr/0344-the-first-client-of-a-trait.md), 2026-09-06), which is
the fifth turn of the same wheel and the first one where the thing being used
was a library rather than a test. `lib/dialect/passortx.pas` sorts an
`array of T` by the element's own implementation, the trait declared in the
module and every implementation written by the client -- ADR-0341's shape,
exercised by something a program would import instead of by a probe. Writing
it took under an hour. The trait it wanted to declare was named `Ordered`,
because that is what the concept is called, and `ordered` is one of
AP 6.7.3.10.5's four category spellings, identified in a bound position by
spelling alone; the trait declared, implemented for two types, and reported at
the *call* that a record was not admitted by a category admitting "int64,
real, a string-type and utf8". It is refused at the declaration now. The
second finding is left alone: a local named `t` in a generic whose type
parameter is `T` **is** that type parameter, 6.1.2 folding case, which is
ADR-0340's `self`/`Self` collision one scope further in.

**Four factors were settled on 2026-09-03**, each against a real alternative:
all three increments are in scope including `dyn`; the declaration is a block
rather than a marker on each routine; the receiver is **written out with its
type** rather than implied; and one library module is rewritten as proof before
any judgement about the other thirty.

The argument that arrived *after* that choice is the best one for it: a trait
impl repeating only the routine's name is not new syntax at all —

```pascal
impl Ord for Point;
  function Compare;
  begin Compare := self.x - other.x end;
end;
```

— it is §6.7's own parameterless definition, the shape this compiler's source
writes **248 times** after a `forward`. A trait heading plays the part
`forward` plays.

#### What is settled, and what is not

**Settled.** The four factors above. And the one technical question that gated
increment B, settled by probe on 2026-09-04: a trait bound **cannot narrow
inference, because inference has no candidates to narrow** — `Determine` reads
one type off the first determining actual and `BindType` is first-wins, so
AP 6.7.3.10.5's category is checked *after* the tuple is built and a trait
bound takes that same position. Two things fell out of settling it. The
receiver is the determining position **for free**, being the first parameter.
And the tuple holds the actual's *own* type, so `1..9` is bound and not
`integer` — every existing category goes through `Base(t)` and none can tell a
subrange from its host, which makes a trait bound the first constraint that
could; the record decides the impl lookup **follows `Base()`**, so a subrange
takes its host's implementation and cannot carry one of its own.

**Not settled.** Whether to build **A or C** — B is built, and since
ADR-0355 it has a client that is not a test, which is the evidence the record
asked for and got a release out of. What increment A's one rewritten module
reads like is the evidence A waits on, and it is a different kind: B's payoff
was 30 call sites and 14 routine parameters, a program's own text, and A's is
118 call-site spellings that block no program. And what to do
about the one cost no gate will see: `x.M(a)` resolving in the type's scope
means a reader can no longer find a routine by grepping its name — `Put` will
be declared in a dozen impls. `--dump-uses` already answers *where is this name
declared* and the language server reads it, so the tooling is ready and a
person with `grep` is not. That is the feature working as intended, which is
why it is written down here rather than discovered later.

**A note on what to call it.** This section is not titled *a Rust-flavoured
Pascal dialect*, though the description is fair — eleven of the eighteen rows
in [Where the ideas come from](#where-the-ideas-come-from) are Rust or Rust and
somebody else, and slices, optionals, moves, owned pointers, `Result` and `?`
are all already here. That table **is** the Rust-flavour chapter, written per
borrowing and tied to the open decision each one settled, and a second section
under that name would say the same things with the discipline taken out. What
is new here is one proposal, so the chapter is named after the proposal.

### Known limitations

Things that are wrong or absent today, listed so they are not rediscovered as
surprises. **Until 2026-09-02 this chapter was two lists headed by the two
standards**, and every entry in them was classified as a deviation from a
clause. ADR-0232 made that the wrong question — there is one language and no
clause governs it — and every fact the lists stated was already in
[`doc/implementation-defined.md`](implementation-defined.md), which is the
register of what this processor decides. What stays here is what is still
open in the dialect's own terms: one gap and three capacities. **The two
decisions this chapter carried are both taken** — what bindability is once no
clause fixes it to the variable-declaration, by ADR-0299 on 2026-09-04, and
`string(5)` as a parameter form by ADR-0324 on 2026-09-05. This sentence said
*two decisions* for a day after the first of them was taken, the body having
been updated to *one* and the summary above it not: a count in a heading and a
count in the prose under it are two measurements, which is the lesson this page
keeps re-learning one document at a time.

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
ADR-0181 withdraws nothing.

**Decided 2026-09-05: kept, and written down as the unchecked form**
(ADR-0336). The two ways out were measured rather than weighed, and both fail:
*retire* on the numbers — 41 ordinary-pointer type-definitions outside `tests/`
and **0 of 41** convertible to `owned ^T` plus a borrow, the compiler's own 34
deciding it — and on containment, `new(p); q := p; dispose(p)` being conforming
Extended Pascal that ADR-0117 obliges this dialect to accept and mean the same;
*check* on cost, ADR-0325's i386 leaving no spare address bits and soundness
requiring `dispose` stop returning storage, so the checked pointer would be the
one that leaks by design. The measurement is in
[`doc/history.md`](history.md#the-memory-model-read-against-the-goal).

What is written down instead is the inversion, stated rather than glossed: the
safe subset is `owned ^T` with the non-escaping borrow, and §6.4.4's pointer is
the unchecked form containment requires be kept. Unlike Rust's `unsafe`, here
the unchecked form is the *unmarked default* and safety is opt-in and spelled —
a fact about containment rather than a lapse, and saying so is what keeps
ADR-0109's goal from reading as a claim the compiler does not meet. [Memory model and memory
safety](#memory-model-and-memory-safety) is where it stands beside the rest of
the model, and where the other half of the same question — an *owned* pointer
released while a borrow of it is live — is written down.

**Three capacities**, each a decision with a record and each a refusal or a
trap a program can meet:

| A program meets | Decided in |
| --- | --- |
| nesting deeper than 1000 levels is refused, and an operator chain is counted toward the same limit because it is flat for the parser and deep for everything after it | ADR-0020, ADR-0110; the register's §6 |
| a set's base type must have its values in 0..255, every set being one 256-bit word — so `set of integer` is refused, and so is `set of 1..m` for a bound the block evaluates, which cannot be checked against 0..255 before the program runs | ADR-0028, ADR-0133; §6 |
| string concatenation draws from an arena released at the end of every statement, so one *statement* holding more live string values than the arena holds is the limit, and both ways of exhausting it are reported | ADR-0111; §6 |

**And the one decision that had no record has one.** `string(5)` as a
parameter form (ADR-0171) is **decided and admitted** — AP 6.7.3.1.1 and AP
6.7.2.1, ADR-0324, moved to
[`doc/implementation-defined.md`](implementation-defined.md) §5 with the other
extensions that have a record. Probing it to write the clause found two things
this row had not: the **result-type** takes the form as well, which is the
position ADR-0215 wrote down as an open question and believed unwidened; and
the acceptance is exactly one production alternative, every other type-denoter
being refused in both positions. The count moved a third time in taking it —
16 sources and 22 parameters became 18 sources, 24 parameters and one
result-type, a scan that had not separated a parameter from a result never
having been asked to.

The adversarial audits that filled the old lists — five now, ADR-0162,
ADR-0167, ADR-0168, ADR-0171 and ADR-0342 — are [open question
§1](#1-the-dialect-has-no-external-authority-and-every-gate-here-is-anchored-in-one)'s
instrument, and that entry says when the next is worth running.

---

## The standard library

**Thirty-three modules, and nothing open.** That is the shortest part of this
page and it is a finding rather than an omission: the chapter that listed
library gaps struck the last of them at v3.2.0, and what replaced it is the
lesson about how those rows got there.

**The other two of ADR-0109's four areas are answered here**, and they are not
answered the same way — which is the one thing worth knowing before reading
the split as tidy:

- **networking** is a library facility outright. `PasNet`, where a socket is a
  handle and both ends are strings, so `getaddrinfo` decides what they mean
  and no program writes a byte order, with `NetWait` over `poll` and `PasTls`
  and `PasHttp`/`PasHttps` above it (ADR-0203, ADR-0205, ADR-0264, ADR-0265).
  No clause of the language mentions a socket.
- **internationalisation is a language rule with a library under it**, and is
  listed here because that is where a program meets it. AP 6.4.15 is a
  *clause* — UTF-8 in normal form C, an element is an extended grapheme
  cluster, an integer index refused — and `runtime/pasrt_unicode.c` is the
  tables it is decided by, judged against Unicode's own conformance files,
  the one oracle here nobody in this project wrote (ADR-0189 – ADR-0193,
  ADR-0196, ADR-0199). **So the four areas do not partition by these three
  parts**, and pretending they did would be the kind of tidiness this page's
  own lessons warn about.

**The library has now asked the language for something, which is the direction
this part had never run in.** `PasContainer`'s map was keyed by a caller
threading `StrHash, StrEq` through thirty call sites; it declares `trait Key`
and binds the key discriminant with it now, and every client writes the `impl`
block (ADR-0355). That is the object model's increment B earning its keep in a
module a program imports rather than in a test, and it is the only evidence
[the proposal](#the-object-model-proposed) had been short of. It is not a row
here, because nothing about the library is open as a result — but it is what a
row here would look like if one appeared.

**A row will appear here the way every good one did** — somebody writing a
program and finding it hard, not somebody reading a list. Two of that
chapter's eight rows said why they were blocked and both reasons were wrong,
which is why this part is kept open and empty rather than closed. **Two of the
four areas have been used in anger by something in this tree and two have
not**, and which two is a fact about this page's own error rate rather than
about the modules.

### What a daily program still cannot reach for

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

**Thirty-three modules exist** — eight conforming and twenty-five dialect,
listed by name in `README.md`'s module table. The newest is `PasToml`
(ADR-0360), and it is the shape the paragraph above describes: somebody wanted
to read a configuration file, which is a thing a daily program does and this
library could not.

### Writing a daily program

**Every row closed**, and the chapter is in
[`doc/history.md`](history.md#the-last-of-the-daily-program-rows) with a
pointer to where each of them went. What a program reads can be cut without a
word (ADR-0305); concurrency was one row short and is not (ADR-0302, ADR-0303,
ADR-0312, ADR-0313); four of twelve examples collided with a library name on
their first draft, and the compiler defect under that was a placeholder type an
error path left behind (ADR-0306); `PasJson` rendered `0.75` as
`7.500000000000E-01` and its reader was not correctly rounded (ADR-0309,
ADR-0314); a `MapKey`'s 63 characters were never the map's bound (ADR-0310); an
owned pointer refusing `p := nil` has a reason and now names it (ADR-0307); and
inference could not read a type parameter through a whole array, which turned
out to be `Determine` and not the clause (ADR-0316).

**The prediction the chapter made about its own order was right**, which is
worth more than any single row: a single task's completion was the next thing
wanted and waiting for whichever came first was the one after it. What is not
worth carrying forward is any of the *reasons* it wrote beside a row — three of
them were wrong, and each was found by compiling four lines.

---

## First-party utilities

**Everything outside the compiler**, and it is down to one thing: which
machines it runs on. None of it is a language feature and none needs a
spelling — how the compiler is obtained, how it is learned, what an editor may
ask of it, how it is packaged — and every row but the platforms was struck
within four days of being written down.

The two parts above are for someone working *on* the compiler and on what it
compiles. **This one is for someone working with it**, and it was written on
2026-09-02 — as the chapter *What would make this practical to pick up*, whose
other half is now under [the standard
library](#writing-a-daily-program) — by asking what separates the tree as it
stands from a language a person picks up on a Tuesday and has a program
running by the afternoon. Every row was measured before it was written, and
the command is beside the number so that a reader can take it again; where a
cost is given it is a guess and says so, because [the language
part](#what-each-landed-feature-left-open) has three rows that were wrong
about exactly that.

ADR-0109's four areas are answered and both standards are complete, so what is
missing here is not what the compiler accepts but what surrounds it. The
struck rows are below as one table, each pointing at where its narrative went;
[`doc/history.md`](history.md) has what doing each of them found.

### Getting it, learning it, and the editor's questions

**Every row of these three sections is struck**, and they are kept as one
because what is left of them is a single sentence: the things separating a
compiler from a language a person picks up on a Tuesday were cheap, and every
one was taken within four days of being written down.

| What was missing | Where it went |
| --- | --- |
| no release carried a binary | ADR-0296 — a `v*` tag attaches an `x86_64-linux` and an `aarch64-linux` archive, each checked the way `install-layout` checks a prefix before it is uploaded. [`doc/history.md`](history.md#the-first-archive) |
| no program to read that is not a test | ADR-0295 — `examples/` holds twelve programs of a page each, every one a case, and writing them found seven things. [`doc/history.md`](history.md#the-examples-and-what-writing-them-found) |
| no tour | [`doc/tour.md`](tour.md), eleven sections of prose with short programs in it, linked from the top of `README.md`. [`doc/history.md`](history.md#the-tour-and-what-writing-it-found) |
| a runtime error named no position | ADR-0293 — `… at file:line:col` after every trap message. [`doc/history.md`](history.md#a-runtime-error-names-no-position--closed-adr-0293) |
| a source named with no directory found no sibling module | ADR-0308, the day the tour that found it landed: `SourceDir` answered the empty string where the answer is `./`, and `AddPath` drops an empty directory on purpose. `bare-source-name` is the gate, and it has to be one because no test case can choose how it is named |
| no way to start a project except by hand | ADR-0348 — `pascalcc new-project <name>` writes `src/`, `test/`, a `.gitignore`, a README and `afterschool-pascal.toml`; `build`, `run` and `test` read it. [`doc/history.md`](history.md#a-project-is-a-convenience-over-a-file) |
| the server answered thirteen methods and none of them completed a name | ADR-0300, ADR-0301 — fifteen now. [`doc/history.md`](history.md#tooling--closed-adr-0300-adr-0301) |
| a user's own multi-module program already built itself and nothing said so | [`doc/tour.md`](tour.md#there-is-no-manifest-and-no-build-order-to-maintain), under a heading of its own — resolution is transitive, `--dump-imports` tells `pascalcc` what to translate, and there is no manifest and no order to maintain (ADR-0244) |

**Windows and macOS are the exception, and are in the [cross-platform
chapter](#what-is-left)** rather than repeated here. The one sentence worth
adding from this side: macOS is the cheapest unknown in the tree — the
runtime's five non-ISO names are all there — and a language nobody has run on a
laptop is not yet practical whatever else is true of it.

**What the chapter got right and what it got wrong** is the part worth keeping.
It asked for one row from each section to be taken first — a binary, a line in
every trap, `references`, and the examples — and all four went within a day,
which says the ranking was sound. What it got wrong is what [the language
part](#what-each-landed-feature-left-open) got wrong three times over: the
*reasons* written beside the rows. Every row that said why it was blocked was
cheaper than it claimed, and the row about a source named with no directory was
not a missing feature at all but two right answers to two different questions,
wrong together.


### Cross-platform support

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
on 2026-09-01, said **10 346**, and on 2026-09-05 it says **10 898**. Two
documents answered differently about one gate, neither was right, and the
number has moved twice since. Run it: `python3 tests/checks/target_layout.py`.

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
| i686, arm, riscv32, mipsel, powerpc, x32, … | 3858–3904 | **every 32-bit target** — and the offsets were the wrong measure of the work: 3858 offsets differ because **seven rules** do, which is what ADR-0325 cost |

#### What is left

- ~~**32-bit, which is the real work.**~~ — **done** (ADR-0325) on 2026-09-05,
  and the row had named four rules where there are seven. The port, the two
  defects no arithmetic check could see, and *which* i386 (ADR-0346) are in
  [`doc/history.md`](history.md#the-32-bit-port-and-the-width-it-left).
- ~~**How a foreign declaration should name a C `long`**~~ (ADR-0129) —
  **decided** the same day it was measured (ADR-0328, AP 6.4.2.7), and then
  found wrong **twice more** with the decision in place: `labs` at `-O0`
  (ADR-0334), and nine bindings plus the emitter's own slice count that no
  corpus on any one host could convict (ADR-0364), so `foreign-width` holds
  the claim as a catalogue. All three are in the same chapter of
  [`doc/history.md`](history.md#the-32-bit-port-and-the-width-it-left).

**The rest is small and specific.** s390x's `tySet` alignment (13 offsets;
`target-layout`'s second claim is what would catch it now — i386 does not have
that problem, `i128:128` being in its own datalayout). Windows: `fmemopen` and
`open_memstream` do not exist in the CRT, so `readstr` and `writestr` need two
hand-written `FILE*`-over-memory functions, `access` is `_access`, and MSVC
lacks the `_Complex` §6.7.6.2's functions are written in. **macOS needs none
of it** — the runtime's five non-ISO names are all there — and has never been
tried, which makes it the cheapest unknown in the chapter.

#### What is not claimed

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

## Deferred: insufficient resources

**Lowest priority, and not a queue.** Everything else on this page is open
because nobody has decided it or nobody has done it. These two are open because
what they need is not a decision and not an afternoon: it is a resource this
project does not have, and no amount of prioritising conjures one. They are
here so that a reader can stop weighing them against work that is actually
available.

**The admission test, and it is strict on purpose.** A row belongs here only
when somebody has *shown* the blocker is a resource — not when it looks
expensive. That is the same rule the rest of this page is under: a row is a
report and not an estimate. It matters more here than anywhere, because
"insufficient resources" is the most comfortable reason there is to write
beside something, and the least likely to be re-examined.

**It has already caught one.** *A miscompilation only an aarch64 backend
produces has nothing looking for it* was written into this chapter and taken
straight out again: checking it found `llc-second-backend` skipping on arm64
for want of an `apt-get install llvm`, and the objection recorded against that
— `llvm` must stay out of the container the documented build is checked in
(ADR-0085) — turned out to be an objection to a step of the *test* job and not
to a job of its own. GitHub's arm64 runner was already in use by the job beside
it. It cost about thirty lines of CI (ADR-0331) and had been filed as a machine
nobody has.

### 1. The front end has no second implementation

`difftest` compared `src/`'s tokens, AST and Sema against the Pascal
compiler's over every source in the tree, and ADR-0232 retired it with the
conformance surface it compared. So the whole front end is now guarded by
goldens that agree with whoever wrote them, plus `tests/spec/` for a
clause-shaped requirement. `doc/sop.md` §7 calls it **the largest blind spot on
that page**, and it is.

**What it needs is a second implementation, and that is a team-year.** But the
reason it is deferred rather than merely expensive is the second half, which
ADR-0232 already wrote down: *a second implementation of a language with no
external specification would be two readings by one author*, which is exactly
what `difftest` could never contradict either. What it did catch was drift
between two ports of one reading — real, and narrower than the gap it looks
like it closes.

So the cost is a team and the value is disputed, and both would have to change
before this is worth starting. `.claude/skills/langspec-audit/` is the
substitute already in use: independent readers given the behaviour and not the
reasoning, told to prove the compiler wrong from the standards text (ADR-0101).

### 2. There is no third-party corpus

BSI's 812 programs were the only artefact here that nobody in this project
wrote, and they are ISO 7185: 25 of them use a word-symbol §6.1.2 reserves, so
this compiler cannot compile the suite at all (ADR-0232). Nothing replaces it,
and **nothing exists to acquire** — which is what puts this row here rather
than in a budget.

Two things narrow it and neither closes it. `unicode-conformance` is an oracle
nobody here wrote and covers one clause. `fpc-differential` (ADR-0234) is a
second *processor* rather than a corpus: it answers 103 of the 244 cases that
have a golden, reaches nothing in `tests/dialect/`, and shrinks with every
release as the dialect grows.

---

## How this page is written

**The goal, the rules, the lineage, and the one risk that is not a task.**
Nothing in this part is an item of work. The goal is here rather than at the
top because the useful half of it is a **test** — *does a program someone
would actually write today need it, and can it get it* — which governs what
may be written in the three parts above; the lessons are for whoever adds the
next row; the borrowings table records where each idea came from and what it
settled; the standing risk is read every time and finished never; and the
index at the end says where everything this file used to carry went.

### The goal (ADR-0109)

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
on 2026-08-30. Each is set out in the part that answers it — the first two
under [the language](#the-language), the last two under [the standard
library](#the-standard-library) — and the table is kept whole here because it
is one claim and not four:

| Area | Where it is answered |
| --- | --- |
| networking | `PasNet` — a socket is a handle and both ends are strings, so `getaddrinfo` decides what they mean and no program writes a byte order — with `NetWait` over `poll`, and `PasTls` and `PasHttp`/`PasHttps` above it (ADR-0203, ADR-0205, ADR-0264, ADR-0265) |
| internationalisation | AP 6.4.15's text model: UTF-8 in normal form C, an element is an extended grapheme cluster, an integer index refused — and Unicode's own conformance files judge it, which is the one oracle here nobody in this project wrote (ADR-0189 – ADR-0193, ADR-0196, ADR-0199) |
| concurrent execution | `task`, `spawn`, `channel [n] of T`, `send` and `receive`, reserving no word-symbol: share-nothing, only transferable values and channels cross, and every task a block spawned is joined before that block releases anything (ADR-0268) |
| memory safety | Optionals and no bare null, slices carrying their bounds, scope-based release, `owned ^T` for a variable `new` created, and the move both affine kinds need (ADR-0123, ADR-0125, ADR-0151, ADR-0181, ADR-0182, ADR-0267) |

**A fifth area is proposed and ADR-0109 does not name it** — an **object
model**, which is a different shape from the four above: nothing is
unreachable without one, and every program in `examples/` was written without
it. It has a section of its own under [the language](#the-language) — [The
object model (proposed)](#the-object-model-proposed) — because it is a design
on paper with nothing built, and a table row here would read as a plan.

**That is not the goal met**, and the distinction is why this section sits
among the rules rather than at the top of the page. A facility that exists is
not a facility that is pleasant to use, and ADR-0109's test was never *does the
language have it* — no standard governs this language, so that question has no
asker — but **does a program someone would actually write today need it, and
can it get it**. What answers that is somebody writing a program and finding it
hard, which is what [What a daily program still cannot reach
for](#what-a-daily-program-still-cannot-reach-for) is waiting for and what [the
language server](history.md#the-language-server-and-the-bound-it-found-before-it-ran)
was written to produce. **So a row in any of the three parts is evidence from a
program and not an item from a list**, which is the same rule the three lessons
below give in three other ways.

**The four *decisions* the goal forced are all made too** — three of them by
discovery rather than by design, and the fourth by deleting the thing it was
about. Not one decided the question its row was written to pose, which is the
part worth reading: the table, with what each answer cost, is in
[`doc/history.md`](history.md#the-four-decisions-the-goal-forced).

**One thing outlived its row.** The C++ reference front end went (ADR-0232),
and with it the last comparison of this front end against a second answer —
which is [open question §1](#1-the-dialect-has-no-external-authority-and-every-gate-here-is-anchored-in-one)
two sections below, and `doc/sop.md` §7's largest entry, and is stated there
rather than here so that one fact does not come to disagree with itself.

What is already in hand and was not built for this: modules and separate
compilation (ADR-0053, ADR-0079) mean a library needs no new language
mechanism, and `runtime/pasrt.c` is where the outside world already enters.

**A decided or implemented thing in [the language](#the-language) belongs in
`doc/afterschool-pascal-spec.md`, in
[`doc/implementation-defined.md`](implementation-defined.md), or in both — and
a row here is not where it lives.** This page is a queue and those two are the
language: the specification says what the language *is*, clause by clause, and
the register says what this processor decides where a clause leaves it open.
So a row that closes is not finished when it is struck through; it is finished
when the thing it decided can be looked up by somebody who never read this
file. Which document takes it:

| What was decided | Where it goes |
| --- | --- |
| a rule of the language, or a consequence of one a reader would otherwise have to derive | a clause or a NOTE in `doc/afterschool-pascal-spec.md` |
| an answer this processor gives where a clause leaves it open, a capacity a program can meet, an error not reported, an extension, or a program accepted that the grammar it came from rejects | the matching section of `doc/implementation-defined.md` |
| a decision **not** to build something, where a reader would otherwise read the absence as an oversight | a NOTE beside the construct it was not given to |
| why it was decided, and what it cost | an ADR, and neither of the two above |

**The third row is the one that gets missed**, and it is the reason this rule
is written out. Three of the concurrency residue's standing shapes were
decisions — a channel cannot carry a handle, an activation cannot close a
channel and then drain it, and there is no timeout on `wait` — and only the
first was in the specification; the other two read as things nobody had got to
(AP 6.4.16.4 NOTE 5 and 6.9.3.14 NOTE 5 now say otherwise). A limitation that
is a decision and does not say so will be "fixed" by somebody eventually.

**And the check is a reader, not a gate.** `spec-clause-traceability` asks
whether a clause a scenario cites exists and whether the triage calls it
testable; nothing here asks whether a *decision* reached either document, and
nothing can — the question is whether a fact was written down, and only
somebody reading both can answer it. `doc/sop.md` §7 carries that gap.

**Three lessons govern how this page is written**, and they are here rather
than in the history because they are rules for the next row somebody adds.
They were learned by the chapter that used to stand between *What a daily
program cannot reach for* and *What would make this practical to pick up* --
the second of which is now split across the library and utilities parts --
**What would make this easier to work on**, archived to
[`doc/history.md`](history.md#what-would-make-this-easier-to-work-on) on
2026-09-03 when the last of its eleven items closed.

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

Nothing here is a work queue with owners and dates. Where a decision has been
made it has an ADR; where it has not, that is the point of the entry.

### Where the ideas come from

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
| Traits / protocols | Rust, Swift | abstraction | **Half done, and something has now asked for the other half.** Schemata gave parametric types over a *value* (ADR-0039); ADR-0209 lets a discriminant name a **type**, so a container is written once; ADR-0266 lets a type parameter say what it needs. What is absent is a generic *routine* over one — `lib/passort.pas` sorts by `less(i, j)` and `swap(i, j)` and never sees an element for exactly that reason. This row read *nothing has asked for* abstraction over **behaviour** until 2026-09-03, and [ADR-0315](adr/0315-methods-and-traits-without-inheritance.md) is what asked. **Both halves are now built, and the successor is written**: a trait bounds a schema's type-valued discriminant and a routine's type parameter, and `lib/dialect/passortx.pas` sorts an `array of T` by the element type's own `Sortable` (ADR-0338 to ADR-0341, ADR-0344, AP 6.7.9). `PasSort` stays, being conforming Extended Pascal, and its `SortIndexed` still answers for parallel arrays |
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

### The open questions

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

#### 1. The dialect has no external authority, and every gate here is anchored in one

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
from the standards' text. **Five have run** (ADR-0162, ADR-0167, ADR-0168,
ADR-0171, ADR-0342); the fifth was scoped to the memory model on 2026-09-06
and found **three real holes every gate here was green over**, which is what
the instrument exists for. It also found the largest thing in that record and
the one no reading was needed for: **AddressSanitizer had never instrumented
compiled Pascal**, the emitted IR carrying no `sanitize_address` attribute, so
every argument of the form *ASan reports nothing* made about a program's
behaviour was empty — until ADR-0358 put the attribute on every emitted
function, measured the corpus clean under it, and made the gate refuse to
sweep without first proving that it bites. The *Known limitations* chapter used to close with the
note that the next audit is worth running whenever that chapter has not moved
for a while, and the note belongs here, since a claim no test names is a claim
nothing checks.

#### 2, 3 and 4 — answered

A third-party differential (ADR-0234), mutation testing committed to the tree
(ADR-0207) and *should the dialect read a type off a component?* (ADR-0215)
were the other three questions this chapter carried. Each has a row in
[Answered, and where](#answered-and-where) and its narrative in
[`doc/history.md`](history.md#what-the-roadmap-answered). §1 above is the only
one left, and it is the one no record can close.

### Answered, and where

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
| Is what the corpus reaches what this project is *made* of? | No: 46 718 lines of 67 931 had an instrument. `lib/`, `runtime/*.c` and `lsp/pasls.pas` are measured now, the dumps have a corpus, and the sanitizers see compiled Pascal for the first time — [the chapter](history.md#the-oracles-that-were-not-looking) is what four gates in two days found | ADR-0342, ADR-0349 – ADR-0354, ADR-0358 |
| Is the memory model the one its records describe? | No, and not in the direction expected: three of a review's four rows closed within two days — the borrow rule's invalidation half is refused where a borrow is *formed*, the fifth warning was measured and retired, and the release walk that ended in a signal is a work list. The fourth, a record's `Drop`, is still open with exactly one asker. [The chapter](history.md#the-memory-model-read-against-the-goal) | ADR-0317 – ADR-0337 |
| What separates this from a language a person picks up on a Tuesday? | Eight rows, every one struck within four days of being written: an archive, a tour, twelve examples, a position in every trap message, a project skeleton, two more server methods, and two claims that were true of every spelling of the command but the one a person types | ADR-0293 – ADR-0308, ADR-0348 |
| Mutation testing, committed to the tree | One file per recorded mutation and a harness that runs them; not a `ctest` case, because it edits the tree. A register of demonstrations and not a measurement | ADR-0207 |
| Is the platform lock scoped? | Three things, two done at once and the third — 32-bit — on 2026-09-05, when the *offsets* turned out to be the wrong measure of it: seven rules, not four | ADR-0155 – ADR-0159, ADR-0325 |
| Is a foreign scalar the width of its C type? | Not by inspection: `time` as `int64` gave the right answer on every host but one CI container, and the mutation putting it back survived. `clong`/`csize` are the answer and `foreign-width` is what holds it, as a catalogue — [the chapter](history.md#the-32-bit-port-and-the-width-it-left) | ADR-0328, ADR-0364 |
| Can a conforming program learn that a file is missing? | `binding(f).bound` says whether it is there | ADR-0172 |
| Can a program get its arguments as a list? | `argcount` and `argument(k)`, required identifiers of the dialect | ADR-0173 |
| Can a foreign address be owned? | A handle-type: a file variable for it, released where a file closes | ADR-0174 |
| What is a character, once a byte is not one? | A grapheme cluster; text is UTF-8 in normal form C, in a value with a byte capacity, and `char` is left alone because it cannot widen | ADR-0189 |
| Should the dialect read a type off a component? | Yes: `type of` takes a whole variable-access, so a generic reads an element type off the container it was handed. The substring is the one access it must refuse, and a *result* type is where the widening stops | ADR-0215 |
| What did version 3 take, and what did it leave? | Four proposals: three became records and the fourth dissolved under the first. The one it left open was `src/` — whether the second front end earned its cost — and §0 answered that by removing the surface it was frozen at. The chapter is in [`doc/history.md`](history.md#version-3--what-it-took-and-what-it-left) | ADR-0229 – ADR-0233 |
| What did the language server demand? | Findings enough that the count is kept in one place and not four — [the chapter as it closed](history.md#the-chapter-as-it-closed), which had said twenty-one where that section said twenty-six. Five were **bounds**, each chosen by counting what the largest thing in the tree needed at the time, and the largest thing in the tree was a test case. All twenty-seven are closed and in [`doc/history.md`](history.md#the-language-servers-findings-as-they-were-recorded); the chapter as it closed, in the same place, keeps the count | ADR-0236 – ADR-0249 |
| Is this a conforming processor or a dialect? | A dialect. `--std` and the two conformance modes are removed, the clause 5.1 a) compliance statement withdrawn, and 25 of 172 ISO 7185 cases became inexpressible — a conforming ISO 7185 program with a field called `value` no longer compiles. Five oracles retired with the surface they asked about. It is what version 3 is named for | ADR-0232 |
