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

## How to read this

| Part | What it holds |
| --- | --- |
| [The language](#the-language) | what the compiler accepts, and what it does not: the concurrency residue, the memory model measured against the goal it is named in, the object model nobody has committed to building, and the limitations a program meets |
| [The standard library](#the-standard-library) | the thirty-one modules — and **nothing open**, which is a finding and not an omission |
| [First-party utilities](#first-party-utilities) | everything outside the compiler: obtaining it, learning it, the editor's questions, packaging, and the platforms it runs on |
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
language has a proposal and three shapes, the library has nothing, and the
utilities have most of what is left.

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
  `receive`, reserving no word-symbol: share-nothing, only transferable values
  and channels cross, and every task a block spawned is joined before that
  block releases anything (ADR-0268).
- **memory safety** — optionals and no bare null, slices carrying their
  bounds, scope-based release, `owned ^T` for a variable `new` created, and
  the move both affine kinds need (ADR-0123, ADR-0125, ADR-0151, ADR-0181,
  ADR-0182, ADR-0267) — and **most of Rust's model, arrived at without
  reading Rust**, which is also how the four things it is short of went
  unnoticed until they were probed for.

Neither is finished in the sense that matters, and what each left behind it is
the first two sections below.

**Nothing in this part is scheduled.** The one proposal in it is `Proposed`
and has no commitment behind it, and that is said again where it stands.

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

**What two threads of control left open** (ADR-0268, AP 6.7.8). The record
names these itself rather than letting the feature imply them, which is the
shape to expect from here on — **and every row of it is now closed**, the last
four on 2026-09-03. What the table is kept for is the same thing the two
chapters above it are kept for: a feature that names its own residue is a
report, and four rows that closed in a day say the residue was named honestly.
Three shapes outlive the rows and are named under it:

| A daily program wants | Why it waits |
| --- | --- |
| ~~**to give a task a handle**~~ | **Done** (ADR-0303), and the whole of what was missing was a *position*: `take` stood on the right of an assignment and nowhere else. A task formal may be a handle-type and the actual is `take(v)` — moved, where a channel is lent. Moved to [`doc/history.md`](history.md#the-concurrency-residue) |
| ~~**to wait for one task**~~ | **Done** (ADR-0312), and it cost a type and one statement because a handle already had every rule a name for an activation needs: `task` is a handle-type, `spawn t := P(x)` makes a variable name the activation, and `wait(t)` returns when it is complete. AP 6.9.3.12.1 is untouched — a block still joins everything it commenced, and `wait` only completes one of them earlier. Moved to [`doc/history.md`](history.md#the-concurrency-residue) |
| ~~**to wait for whichever comes first**~~ | **Done** (ADR-0313), and the shape it took was a *statement* rather than an argument: `select` waits until one of several channels can proceed, `after N` gives up, `otherwise` does not wait at all, and `ok := receive(c, v)` carries the close of a drained channel into an arm. One thing it named is deliberately still open — there is no timeout on `wait`, ADR-0312's reason being that a wait which gave up leaves a task-variable naming a running activation and no clause says what that is. Moved to [`doc/history.md`](history.md#the-concurrency-residue) |
| ~~**to send a string**~~ | **Done** (ADR-0302), and writing the case is what showed the reading was wrong twice over: `send` chose its path with `IsStructured`, which a variable-string is not, so the module did not assemble; and a string *value* is shorter than the element it goes into, so copying `esize` bytes read past it. Moved to [`doc/history.md`](history.md#the-concurrency-residue) |

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

**And one proposal awaiting a decision** (ADR-0315): **methods and traits,
without inheritance.** It is the first record in this tree that is *Proposed*
rather than *Accepted*. It is named here because it is what this feature's
residue turned into, and set out in full three sections down, in [The object
model (proposed)](#the-object-model-proposed). The evidence for it is this
project's own library: **139 of 486 exported names repeat their module's
noun** — `JsonMember`, `StreamOpenWrite`, `NetListen` — because §6.11.2 puts
every imported name into one scope and `export-unique` (ADR-0298) refuses a
collision, so the prefix is a receiver spelled by hand; and where a property
belongs to a *type*, the caller carries it instead, `MapPut(m, 'k', 1,
StrHash, StrEq)` being the shape, with **14 routine-valued parameters** across
two modules and **30 call sites** threading one pair through.

The record proposes Rust's model and argues against Object Pascal's on four
grounds that are each about a decision already taken here, stages it in three,
and names what each stage costs — `dyn` being the only one that adds a
representation. **Its four open choices are settled**: all three stages, the
`impl` block, a receiver written out with its type, and one library module
rewritten as proof rather than a sweep. What is *not* settled is whether to
build it, and one technical question is named in the record as gating the
second stage — whether a trait bound narrows what ADR-0304's inference may
choose, or is checked after inference has chosen. Nothing is implemented.

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
section is what a review on **2026-09-04** found when the model was read
against the goal stated as *a Rust-flavoured Pascal* and **probed rather than
read**. The finding is not that the design is missing a piece. It is that
**the pieces missing are not the ones the records say are missing** — ADR-0201
withdrew the aliasing fork as a question this language does not have, and
three of the four items below are aliasing.

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
| traits | [proposed, nothing built](#the-object-model-proposed) | ADR-0315 |
| lifetimes, `Rc`, `RefCell`, `unsafe` | **absent** | the four rows below |

#### 1. The borrow rule was enforced in one direction — closed 2026-09-04

Rust's aliasing rule has two halves: a borrow may not outlive what it borrows,
**and** the owner may not be released while a borrow of it is live. ADR-0201
established the first — a `var` parameter bound to `o^` cannot escape, because
Pascal has no address-of and `new` is the only producer of a pointer — and
treated it as the whole rule. The second is unenforced, and AP 6.4.14.3 lists
three release points a callee can reach: `dispose`, `new`, and an assignment.

```pascal
procedure P(var o: op; var n: node);
begin dispose(o); n.v := 42; writeln('n.v = ', n.v) end;
...
new(q); q^.v := 1; P(q, q^)          { prints 42, exits 0 }
```

That is ADR-0201's own probe — `P(o, o)`, two `var` parameters bound to one
variable, pronounced safe — with `dispose` where the record wrote `take`.
Every oracle here agreed with it: `heap-balance` read 1/1 because the count is
honest, and a build under `AFTERSCHOOL_PASCAL_CFLAGS=-fsanitize=address`
reported nothing. Made observable, the write through the stale borrow lands in
an unrelated live variable — `dispose(g)`, then `new(h); h^.v := 111`, then
`n.v := 999`, and `h^.v` reads **999**. A third borrow form needs no call at
all: a with-statement's binding is a frame slot holding an address, so
`with q^ do begin dispose(q); v := 999 end` is the same defect inside one
block.

**Both forms are now refused** (ADR-0317, AP 6.4.14.7): the two
actual-parameters of one call, and a release under an open with-binding. What
the clause does *not* reach is the release the callee performs indirectly, and
that is Annex C.12 and a row of `doc/sop.md` §7 rather than an assumption.

**The cheap refusal does not close it, and shipped saying so.** Three
candidates were designed against this shape and the first was taken:

| Candidate | What it costs | Why it is not enough |
| --- | --- | --- |
| **taken**: refuse the call-site shape and the with-binding — the two forms one activation can be asked about | nothing; no program in this tree is refused, and the corpus carries five that must go on compiling | it is a narrowing and not a closure: the callee can reach the owner indirectly, `Bump(g^)` → `Clear` → `ClearIt(g)` → `dispose` of its own `var` parameter, and no local rule sees that |
| **also taken**, a day later: let the program say the callee will not release, by protecting the owner's formal parameter (ADR-0318) | nothing again, `protected` being a word §6.7.3.1 already had in that position | it is a *guarantee on request* and not a closure either — but where it is asked for it is complete, since a protected owned pointer refuses every release point and refuses being handed to anything unprotected |
| **release only in the block that declares the pointer** | sound under one thread — a declaring block is suspended for the whole life of any borrow | unaffordable, and measured: all **ten** of `PasList`'s exported routines take `var l: List` and **five** release through it, so the module could not be written |
| a **dynamic borrow flag**, Rust's `RefCell` and not its borrow checker | a word beside every owned-pointer variable and a check at three sites; the pair travels as two arguments, which is precedented (ADR-0030, ADR-0040, ADR-0051) | nothing — it is sound and complete, and it is a class A and C increment rather than a Sema patch |
| **also taken**, and it is what closed the row: refuse the borrow where it is *formed*, wherever the called block can **name** the owner (ADR-0319) | an owned structure held in a variable of the outermost block cannot be lent at all — 12 sites in this tree, every one of them a test written for the construct | nothing. 6.4.14.3 forbids copying the value, so an owned variable's only names are itself, a variable parameter bound to it, and a component of what contains it; the second is 6.4.14.7's activation-point and the first is scope, and there is no third |

Real lifetimes are the fourth candidate and are unavailable: **a borrow here
is a parameter binding and not a value**, so there is nothing for a lifetime
to be written on.

**The sentence to carry out of this row** was *unformability is what protects
against escape and is exactly what makes invalidation invisible* — ADR-0201
reads the borrow's absence from the type system as strength, and it is strength
in one direction only. That still stands, for the escape half, which nothing
checks.

**The invalidation half is closed**, and what it leaves is a different sentence.
Two records costed mechanisms for the residue — a call-graph summary and a
dynamic flag — and both were answering *may this release happen*. The
requirement is symmetric, so it can be enforced at either end, and the other end
is a question about **scope**: it costs nothing at run time and crosses a
program-component boundary in both directions. **A gap can be an artefact of
where the question is asked.** Annex C.12 is withdrawn, `doc/sop.md` §7's row is
struck, and what is left of this row is ADR-0201's original property — held by
construction, watched by nothing.

#### 2. The unsafe subset is the unmarked default

Rust marks its unsafe operations and makes them opt in. Here it is the other
way round:

```pascal
new(a); b := a; dispose(a); b^ := 5; writeln(b^)   { compiles clean, prints 5, exits 0 }
```

`^T` is the ordinary pointer — what every ISO program writes, what this
compiler is written with, and the unchecked one (ADR-0019, and the *one gap*
of [Known limitations](#known-limitations)). `owned ^T` is the safe form and
costs a word to say. ADR-0117's containment fixes what `^T` **means** and
settles nothing about what the compiler may **say**, so this row proposed a
fifth warning in ADR-0272's frame: a `new` of an ordinary `^T` whose variable
is never copied, where `owned` would have compiled.

**It was measured before it was written, and the measurement retired it —
and found something better than the warning would have.** Every ordinary
pointer type-definition outside the compiler was counted on 2026-09-04. There
were **nine**, and not one of them could take the word.

**That count was right and its table of reasons was wrong**, which probing it
later the same day found (ADR-0320). The table said five were refused for a
schema domain and four for value parameters. In fact `StrMap`, `IntVec` and
`StrVec` are themselves schemas, so `SMapPtr`, `IVecPtr` and `StrVecPtr`
belonged in the first row; and `JsonPtr`, put in the second, is refused before
any parameter is reached, because `JsonNode` has a **variant part**. Ten of
eleven — the count is eleven since `examples/arena_graph.pas` — were refused by
AP 6.4.14.2 and one by 6.4.14.3. The lesson is the one this page keeps
learning: a count taken by machine and a table of reasons written by hand are
two different measurements, and only the first was made.

**The table as it stands now**, after ADR-0320 narrowed 6.4.14.2 and each type
was compiled with the word to find out rather than reasoned about:

| Status | Which | Why |
| --- | --- | --- |
| **converted** | the two arenas in `examples/arena_graph.pas` | the block owns them; the `defer dispose` pair is gone and the example says so |
| legal, and **must not** be | `IVecPtr`, `SMapPtr`, `StrVecPtr` | `owned` is a dialect feature and these are in `lib/`, the conforming layer a reader can port to another Pascal (ADR-0120). Converting them would move three containers into `lib/dialect/` and out of reach of a conforming program |
| **converted** | `CountMap`, `WordVec` in `examples/word_freq.pas` | the module was unblocked by ADR-0323 and these two took the word; the two `Free` calls at the foot of that program are gone and the heap balance is the number it was |
| still refused, and **not** for the reason this row gave | `PathVec`, `DocMap` in `lsp/pasls.pas` | `PathVec` is a *field* of `Document` and `DocMap` holds `Document` values, so an owned `PathVec` makes the record affine and takes away the whole-record assignment the map is built on. AP 6.4.14.3 doing its job, and nothing to lift |
| still refused | `JsonPtr`, `JsonChars` | AP 6.4.14.2's other half: `JsonNode` is a tagged union, so its child pointers are fields of a variant part |

**That was the table's third error in two days**, and the shape of all three
is one: a count taken by machine, and the reason beside it written by hand.
This row said the four waited on `PasContainer`, that the module's routines
assign to the pointer, and that converting it was "a mechanical change,
`v := take(fresh)`, at about 22 sites". The count is **two** sites. The change
is not mechanical and was not about the sites at all: making them `take`
converts the module and *unconverts* every other client, because `take` is the
only operation in this language whose applicability is a property of the type
it is applied to, and `PasContainer` has both kinds of client in this tree.
That is ADR-0323, and it is a language amendment rather than a library edit —
AP 6.4.14 and AP 6.7.3.10 did not compose, and the module is the only thing
here written over both.

The compiler's own 34 are the second row again and harder: `nodePtr`,
`symPtr` and `typePtr` stand as a value parameter or a result 341, 156 and 198
times. A warning firing nowhere is what ADR-0116 rejects and what ADR-0272's
four already-shipped warnings each avoided by finding something on their first
run, so **it is not built**.

**What the count actually says is about the type and not about the warning.**
`owned ^T` has no client here not because nothing wants ownership, but
because **the only borrow this language had was an unprotected `var`
parameter**, and every container in `lib/` hands its handle to a *value*
parameter — `JsonKindOf(v: JsonPtr)`, `SMapGet(m: SMapPtr, …)`, `IVecLen(v:
IVecPtr)`. AP 6.4.14.3 forbids exactly that, so adopting the safe pointer means
rewriting every accessor to take `var` — and a plain `var` grants the caller's
ownership away, which collides with the rule of
[the row above](#1-the-borrow-rule-was-enforced-in-one-direction--closed-2026-09-04).

**That is settled, and it took two amendments rather than one** — and neither
was sufficient alone, which is why the row credited the first with the whole
job and was wrong.

**The borrow form was not missing** (ADR-0318, AP 6.4.14.8). §6.7.3.1's
`protected` is exactly a lend that may be read and not written, and an owned
pointer was excluded from it by §6.4.1 — whose stated reason, that a pointer
value can be copied out and disposed of through the copy, AP 6.4.14.3 had
already made false for this type. A handle-type had been protectable all along
on identical facts. `PasList`'s four read-only routines now take
`protected var l: List`, and the fourth warning found five more places for the
word in code written before there was one.

**And the schema domain was refused for a reason that reached further than it
does** (ADR-0320, AP 6.4.14.2). Releasing an owned variable means walking it,
and a schema's extents are read from a descriptor a frame holds and the heap has
not got — true, and true only where the variable holds something whose release
is more than giving the storage back. Where it holds nothing affine the release
*is* the deallocation, which `dispose` already performed. The condition is the
one the emitter was already asking to decide whether to walk.

**What is left of this row is a choice and not a blockage**, which is the third
thing this row has been wrong about. Nine of the eleven are legal as `owned ^T`
today. Two are converted. Three *must not* be, because they are the conforming
layer. Four wait on one module, and that module is where the question actually
lives: **should a general-purpose container own its storage?** An owned one
cannot be aliased, cannot be returned by a function, and must travel as a
variable parameter — which is right for a tree one block owns, and is a real
loss for a container callers pass around. `PasList` was written owned and has no
`Free`; `PasStrVec` was written indexed and has one. That the second kind exists
is not a gap.

So the facility is complete and its adoption is now a design question per
container rather than a restriction to lift — and it is a question a caller can
actually answer, which it was not until ADR-0323: `PasContainer` is now written
once for an owned type argument and an ordinary one, at two lines, and each
client chooses. The warning is still not built, and
the reason has changed twice: it is no longer that nothing *could* take the word,
nor that a rewrite is needed, but that taking it is sometimes the wrong answer —
and a warning cannot know which.

#### 3. There is no shared ownership; the release walk ended in a signal and no longer does for a chain — 2026-09-04

The dialect's answer to aliasing is refusal, given three times (ADR-0201), so
there is no `Rc` and no language-level arena, and an owned pointer admits no
back-pointer and no cursor. `PasList` states the consequence plainly — no
index, no tail pointer, every traversal recursive. What was not written down is
the failure mode. AP 6.4.14's NOTE 2 predicts it and this is the measurement,
taken again on 2026-09-04 with an 8 MB stack and narrowed:

| An owned chain of | On release, before ADR-0322 | after |
| --- | --- | --- |
| 200 000 nodes | clean, balance 0 | clean |
| 500 000 nodes | clean | clean |
| 1 000 000 nodes | `built 1000000` prints, **then exit 139** | clean, 35 ms, balance 0 |
| 8 000 000 nodes | the same | clean |

The boundary was between half a million and a million, and the message printing
first is what says it was the *release* and not the build: both were recursive,
and the build survives what the release did not, having no owned value to
release per frame.

It was the one capacity in this language that ended in a signal instead of a
diagnostic. ADR-0012's claim is that a full buffer is survivable **as a
diagnostic**, and the per-domain release routine was outside that claim: the
safe container's release path was the crash.

**It is a loop now, for a chain.** Where the domain has a field whose type is an
owned pointer to that same domain, the release empties that field, releases the
rest, disposes the variable and goes round again at what it took out — 6.4.14.6's
move written by the release rather than by a program, and the emptying is what
keeps the walk from releasing it twice. One frame, however long the chain.

**A tree still costs a frame per level**, the second and later self-referential
fields having nowhere to be continued at, so a degenerate tree is still a deep
recursion and nothing bounds it. That is what is left of this half of the row,
and the alternative — a depth counter and a diagnostic — is priced in ADR-0322:
a call per node released, on every program, to report a case no program here
reaches. Two ways out, both Rust's —
reference counting, which then owes an answer about cycles; or the
arena-and-index shape, which is what a Rust programmer reaches for when the
data is not a tree and which **needs no language change at all**.

**The second is now written down**: `examples/arena_graph.pas`. One block holds
every node and the links are *indices* into it, which is precisely the thing an
owned pointer refuses — an index may be copied, compared and stored twice, and
it cannot dangle, because nothing it names is separately freed. The example
holds a graph with a cycle and with two arcs into one node, neither of which an
owner per node admits, and then a path of a million nodes: **18.8 MB peak RSS,
13 ms, walked by a loop and released by two calls to free**, where the owned
chain of that length dies at the end of its block.

Two costs came out of writing it, and both are in the file. **The arena cannot
itself be `owned`** — its type is a schema and AP 6.4.14.2 refuses that domain —
so it is an ordinary pointer whose release is written, which `defer` (ADR-0175)
is where. And **an index is unchecked in the way a pointer is not**: a subscript
is bounds-checked (ADR-0017), so an index outside the arena traps, but an index
into the *wrong* arena is an integer like any other and nothing here can see it.
That is the trade the shape makes, and it is the one Rust's arena crates make
too.

What is still open in this row is the first way out. Reference counting is
unbuilt, and nothing has asked for it: the arena covers the non-tree data, and
the release-depth crash has a documented shape to move to. **The crash itself
is unfixed** — a program that wants a chain of a million owned nodes still has
no diagnostic, only a signal.

#### 4. A record has no `Drop`

A handle names its closer in its own type — `handle external 'fclose'` — and
that is the only user code this language runs when a value dies. A record
owning something runs none, and `defer` is per *activation* rather than per
value (ADR-0175), so a type cannot maintain an invariant across its own
release. Nothing has asked for it yet, which by ADR-0116's rule is the reason
it is a row here and not a design.

### The object model (proposed)

**Nothing here is built, and this section exists so that stays legible.**
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

- **139 of 486 exported names repeat their own module's noun**:
  `JsonMember`, `StreamOpenWrite`, `NetListen`, `MapPut`. That is forced rather
  than chosen. §6.11.2 puts every imported name into one scope, so two modules
  may not export one spelling, and ADR-0298's `export-unique` gate refuses a
  collision outright. **The prefix is a receiver, spelled by hand, at every
  declaration and every call site**, and ADR-0306 renamed four examples' worth
  of them before anyone counted the rest.
- **14 routine-valued parameters and 30 call sites** thread `StrHash, StrEq`
  through `lib/passort.pas` and `lib/dialect/pascontainer.pas`, because where a
  property belongs to a type the caller has to carry it instead.
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
`M(x, a)`. Three increments, and **only the first has to be built for the
other two to be judged**:

| Increment | What it adds | What it retires |
| --- | --- | --- |
| **A. Methods** | the impl block, the receiver rule, `x.M(a)`, the type's own scope | the 139 prefixes. No new representation, no compatibility rule, no vtable, and CodeGen untouched — a method is an ordinary routine |
| **B. Traits, static** | the trait-type, `impl … for`, `Self`, and `T: Trait` bounds | the 14 routine parameters and 30 call sites. Resolved at instantiation, so still no vtable |
| **C. `dyn T`** | dynamic dispatch, permitted only as `owned ^dyn T` and as a var parameter | nothing — it is what a heterogeneous collection needs, and the first thing here that emits a vtable |

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

**Not settled.** Whether to build any of it. What increment A's one rewritten
module reads like, which is the evidence the rest waits on. And what to do
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
ADR-0181 withdraws nothing. What would close it is a decision about the
ordinary pointer — kept as it is, retired in favour of the owned one, or
given a check — and it has not been asked with a caller. *The one entry here
that is a limitation in ADR-0109's sense.* [Memory model and memory
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

The adversarial audits that filled the old lists — four of them, ADR-0162,
ADR-0167, ADR-0168 and ADR-0171 — are [open question
§1](#1-the-dialect-has-no-external-authority-and-every-gate-here-is-anchored-in-one)'s
instrument, and that entry says when the next is worth running.

---

## The standard library

**Thirty-one modules, and nothing open.** That is the shortest part of this
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

**Thirty-one modules exist** — eight conforming and twenty-three dialect,
listed by name in `README.md`'s module table.

### Writing a daily program

- ~~**What a program reads can be cut without a word.**~~ — **done**
  (ADR-0305), and moved to
  [`doc/history.md`](history.md#the-capacity-is-the-callers). `ReadLine` and
  `ForEachLine` take the caller's own string, and the language half needed
  nothing built: `read(f, s)` stops at the capacity *or* at the line's end, so
  `eoln(f)` immediately afterwards is false exactly when something was left
  over. The row said that half had not been probed; probing it took four
  lines.

- ~~**Concurrency is one row short**~~ — **done**, and the row it named is
  the last of four that closed on 2026-09-03. A task can be waited on singly
  (ADR-0312), a program can wait for whichever of several channels comes first
  and can give up waiting (ADR-0313), a task can be handed a socket
  (ADR-0303), and a stage can close the channel downstream of it (ADR-0302).
  What is left is in [What each landed feature left
  open](#what-each-landed-feature-left-open) as three *shapes* rather than
  rows — a **channel of handles**, closing a channel without releasing it, and
  a timeout on `wait` — and the reason none of them is a row is that no
  program here has wanted one. The prediction under this bullet was right
  about the order: a single task's completion was the next thing wanted, and
  waiting for whichever came first was the one after it.

- ~~**Four of twelve example programs collided with a library name on their
  first draft**~~ — **done** (ADR-0306), and moved to
  [`doc/history.md`](history.md#the-capacity-is-the-callers). The compiler
  defect was a placeholder type an error path left behind and a later rule
  spelled out; the naming half is a paragraph in `README.md` and not a rename,
  because every rename moves the collision rather than removing it.

- **Two smaller reports from the same pass** (ADR-0295, findings 5 and 6):
  ~~`PasJson` renders `0.75` as `7.500000000000E-01`~~ — **done** (ADR-0309),
  and moved to [`doc/history.md`](history.md#the-fifth-of-the-seven-closed-adr-0309);
  the writer renders and reads its own output back and keeps the first
  spelling that returns the value it started from, and
  `examples/json_pretty.out` moved with it, which is what that golden was for.
  What it uncovered is the *reader*, and ~~`JsonParse` scales a decade at a
  time and is not correctly rounded~~ — **done** (ADR-0314), in
  [`doc/history.md`](history.md#a-decimal-is-the-languages-to-round): the
  reader stops computing and hands the significand and exponent to §6.9.5's
  `readstr`, which reaches the same correctly rounded conversion the writer's
  own round-trip search had been consulting all along, so the case that
  measured two converters disagreeing now has no FALSE in it. And
  ~~a `MapKey` is 63 characters, so a map keyed by text from outside needs a
  guard the example has to explain~~ — that one was **half wrong** and is
  **done** too (ADR-0310), in
  [`doc/history.md`](history.md#the-capacity-is-the-callers): the map has been
  generic over its key since ADR-0254, so 63 was `MapKey`'s capacity and never
  the map's; what was real is that a program keyed by text from outside must
  choose a capacity, and the rule for choosing it is now written where the
  library is. ~~The third — an owned pointer refusing
  `p := nil`~~ — is **answered** (ADR-0307): the asymmetry with a handle has a
  reason, which is that an owned pointer already has `dispose` and a handle has
  nothing else, and the message names it now.

- ~~**Inference cannot read a type parameter through a whole array**, only
  through a slice-designator.~~ — **done** (ADR-0316), the day after it was
  written down, and **the row had the direction wrong**: it said AP 6.7.3.10.4
  c) was narrower than the parameter it describes, and the clause was right
  all along. It defers to 6.7.3.9.3 for what is admitted, and 6.7.3.9.3
  admits a whole array; it was `Determine` that asked `IsSlice(t)` and so
  read only what was already a slice. The clause is widened in the one place
  it needed to be — an array indexed by something other than an integer now
  determines and is then refused for its index-type, so the reader gets that
  message rather than being told to write a type argument first — and the
  fix reached two shapes nobody had asked for either, a schema-produced array
  and an array whose component is structured. The original row, for the
  record: `Determine`'s slice arm asks whether the
  *actual's* type is a slice, and an ordinary array's is not — the conversion
  happens at the call — so `Total(r)` against `function Total(T: type;
  protected var xs: array of T)` is refused with *nothing in this call says
  what 't' of 'total' is*, while `Total(r[1..3])`, `Total(digit, r)` and the
  non-generic `Plain(r)` over `protected var a: array of digit` all compile and
  run. The whole array **is** admitted where `array of T` stands; it is only
  AP 6.7.3.10.4 c) that is narrower than the parameter it describes, so
  ADR-0266's own example `procedure Sort(Elem: ordered type; var a: array of
  Elem)` cannot be activated by inference from an array. Found by probe while
  settling ADR-0315's open question, and **nothing in this tree had ever
  written that call** — `generic_infer`'s one slice activation passes a
  slice-designator — so no oracle here could have said so. That is ADR-0304's
  own lesson a third time: the row that says a feature is unavailable is worth
  less than the four lines that ask the compiler.

---

## First-party utilities

**Everything outside the compiler**, and it is where most of what is left
lives. None of it is a language feature and none needs a spelling: how the
compiler is obtained, how it is learned, what an editor may ask of it, how it
is packaged, and which machines it runs on.

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
missing here is not what the compiler accepts but what surrounds it. What it
said when a program stopped was the first row to close, the day after the
chapter was written (ADR-0293), and `doc/history.md` has what doing it
found.

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

#### What is left

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
| Traits / protocols | Rust, Swift | abstraction | **Half done, and something has now asked for the other half.** Schemata gave parametric types over a *value* (ADR-0039); ADR-0209 lets a discriminant name a **type**, so a container is written once; ADR-0266 lets a type parameter say what it needs. What is absent is a generic *routine* over one — `lib/passort.pas` sorts by `less(i, j)` and `swap(i, j)` and never sees an element for exactly that reason. This row read *nothing has asked for* abstraction over **behaviour** until 2026-09-03, and [ADR-0315](adr/0315-methods-and-traits-without-inheritance.md) is what asked: [The object model (proposed)](#the-object-model-proposed) |
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
from the standards' text. Four have run (ADR-0162, ADR-0167, ADR-0168,
ADR-0171) and the last findings of the fourth closed on 2026-08-23; the
*Known limitations* chapter used to close with the note that the next is
worth running whenever that chapter has not moved for a while, and the note
belongs here, since a claim no test names is a claim nothing checks.

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
