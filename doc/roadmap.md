# Roadmap

What is open: the goal, what blocks it, the questions no record has answered,
and what is wrong or absent today.

**How the compiler got here is [`doc/history.md`](history.md)** — the
bootstrap, both standards, the conformance sweeps and the thirteen dialect
increments. That document is settled and this one is not, which is why they are
two.

## How to read this

| Chapter | What it holds |
| --- | --- |
| [The goal (ADR-0109)](#the-goal-adr-0109) | what this is all for, [what still blocks it](#what-is-still-blocked-on-it), and [where the ideas come from](#where-the-ideas-come-from) |
| [The two standards and the dialect](#the-two-standards-and-the-dialect) | seven structural questions no ADR has settled, ranked |
| [What is next](#what-is-next) | the oracle that was given up, and four other things worth doing |
| [Known limitations](#known-limitations) | what is wrong or absent today, under [ISO 7185](#under-iso-7185) and [ISO/IEC 10206:1991](#under-isoiec-102061991) |

Nothing here is a work queue with owners and dates. Each entry is something
that is true now and that someone will have to decide about; where a decision
has been made it has an ADR, and where it has not, that is the point of the
entry.

---

## The goal (ADR-0109)

**A Pascal you can get daily work done in**: a dialect and a standard core
library for networking, internationalisation (l10n/i18n/m17n), concurrent
execution, and memory safety as a property of the language rather than a
convention.

Two goals came before this one — bootstrapping, then conformance — and both are
**finished**. The compiler compiles itself, ISO 7185 is complete, and
ISO/IEC 10206:1991 is complete to its last clause.
[`doc/history.md`](history.md) keeps that account, because it explains why the
compiler has the shape it has, and because the conformance modes it produced
are not going away:
`--std=iso7185` and `--std=extended` stay exactly as they are, and the dialect
is a third mode beside them (ADR-0033's construction, used a third time).

Four decisions this forces, none of them yet made, each to get its own record:

- **The memory-safety model.** ADR-0019 says use-after-`dispose` is not
  detected; "memory safety first" is incompatible with that sentence. Checked
  pointers with regions, ownership and borrowing, or a tracing collector differ
  in what a pointer *means*. The most expensive decision here to reverse.

- **The text model.** `char` is a byte and nothing consults the locale
  (documented, deliberate). Real i18n needs a wider character type or a text
  type distinct from §6.4.3.3's strings.

- **The memory model.** Pascal has none, and concurrency cannot be specified
  without one. It must be designed *with* the safety model, because shared
  mutable state is where the two meet.

- **How far the C++ reference front end follows** (ADR-0108). It came back one
  commit before this goal changed, on the reasoning that the language was
  finished and slow-changing. Freezing it at the conformance surface is the
  obvious answer and is not the decided one.

What is already in hand and was not built for this: **modules and separate
compilation** (ADR-0053, ADR-0079) mean a standard library needs no new language
mechanism to exist, and `runtime/pasrt.c` is where the outside world already
enters. Those two are most of a library's scaffolding, finished and tested.


### What is still blocked on it

**A pointer to storage the callee owns whose contents are not characters**, and
it is now two things rather than a category:

- **An opaque handle** — `DIR *` from `opendir`, `FILE *` from `fopen`. No
  layout has to be agreed; it is a token to hand back. What it needs is a
  *lifetime*, and Pascal has a precedent worth using: a file variable is a
  handle whose lifetime a block manages, and ADR-0021 and ADR-0032 already
  close files at block exit and on a non-local `goto`. This is the cheapest
  thing left and the first that genuinely touches ADR-0109's open decision.

- **A struct with a layout** — `struct sockaddr`, `struct stat`. Unlike a
  handle this needs the compiler and C to agree about offsets, which nothing
  here does for a foreign type. It is what stands between here and a socket.

**Creating a file**, which is not a language question at all — `O_WRONLY`,
`O_CREAT` and `O_TRUNC` are header numbers, and the policy PasFS set and PasIO
kept is that a number the module cannot check does not go in. What would lift
it is something that reads a C header, which is a different project.

**The rest of the FFI**, and the ordering has not changed — it is the narrowness
that moved, not the position.

Three things this file expected to make it cheap did, and are spent:

- **The calling convention already existed.** The compiler emits textual LLVM
  IR and already called C functions by name with C types — every `write` is
  one — so what was missing was a language surface and not a mechanism.

- **The grammar already had the shape.** ISO 7185 §6.1.4 and
  ISO/IEC 10206:1991 §6.1.4 make `forward` a **directive**, an identifier in
  the one position it may occupy, and ADR-0053 had noted that §6.1.5's
  `interface` and §6.1.6's `implementation` are directives too. `external` cost
  the lexis nothing, exactly as predicted.

- **Modules gave it somewhere to live** (ADR-0053, ADR-0079). A binding is a
  module that exports Pascal and keeps the directive to itself, and nothing
  about separate compilation changed. `lib/dialect/pasmathx.pas` is the first.

**The real work is still the type mapping**, and two rows of it are done. What
a C `char *`, `size_t` or struct pointer is in Pascal — and which Pascal types
may cross at all — is the whole of what stands between here and a socket, and
it cannot be settled the way `integer` and `real` were, by observing that the
ABI needs no attribute. A pointer crossing the boundary is the memory-safety
question in its smallest form:

- **It is a hole in every safety property the goal asks for.** A foreign call
  can do anything. ADR-0121 answered that for a *call* by making the boundary
  lexically visible — Rust's and Zig's answer, and the one this table already
  said was likeliest to fit — and that answer does not extend to a pointer,
  which outlives the call.

  **This entry expected the next increment and the memory-safety model to be
  designed together, and they were not.** ADR-0122 found that the
  argument side of the boundary has no lifetime question on it at all — the
  caller owns the storage and outlives the call — so half of what was blocked
  here was never blocked on a model. ADR-0123 then took the other half's
  nearest blocker, which was **null** rather than ownership, and a *string*
  now comes back: the copy is made at the call site, so nothing the program
  holds is a foreign pointer.

  What is left is every returned pointer that is not a string — a buffer, a
  struct, and `errno`, which is `*__errno_location()` and a macro besides. Two
  estimates in a row were wrong in the same useful direction, and the lesson is
  worth keeping for the rows below: **a decision that looks like it needs a
  model may need the model for only part of its surface**, and the part that
  does not is usually worth taking first.


### Where the ideas come from

Rust, Swift and Zig are the reference points, and the honest position is that
they do not all fit equally. Pascal's grain is value semantics, explicitness and
a small orthogonal core; that is close to Zig and Swift and further from Rust.
Each borrowing below is tied to the open decision it would settle.

| Idea | From | Settles | Where it stands |
| --- | --- | --- | --- |
| **Slices — a pointer and a length** | Zig, Rust | bounds safety | **Done** (ADR-0125, ADR-0129) |
| **Optionals, and no bare null** | Swift, Rust | pointer safety | **Done**, and this row's description was half wrong (ADR-0123) |
| **Explicit allocator passing** | Zig | part of memory safety | **Tried; does not survive contact** (ADR-0116) |
| **Error unions / `Result`** | Zig, Rust | error handling | **Good**, and the biggest practical gap |
| **`defer`** | Zig, Swift | resource safety | **Good** |
| **Unicode-correct `String`** | Swift | the text model | **The model to copy** |
| **ARC** | Swift | memory safety | **Plausible** |
| **Ownership and borrowing** | Rust | memory safety | **Strongest guarantee, worst fit** |
| **Traits / protocols** | Rust, Swift | abstraction | **Later** |
| **`comptime`** | Zig | metaprogramming | **Later** |
| **Actors / `Send`+`Sync`** | Swift, Rust | concurrency | **Blocked** on the two above it |

**Slices.** The prediction held: `array of T` is the two-scalar shape a fifth
time and needed no new mechanism. What the row did not anticipate is how much
of it §6.5.6 had already paid for — `a[i..j]` is the substring designator, and
only the base's type tells the two apart, so the parser was untouched.
Argument-only, so bounds safety is settled without the memory-safety decision.
ADR-0129 then carried it across the foreign boundary, where the same two words
are what `read`, `write`, `recv` and `send` take — the first time the far side
of a design chose the shape rather than this project choosing it.

**Optionals.** `?T` exists, `nil` is its absent value and `o^` is the only way
to a value — and half of what this row used to claim for it was wrong. What it
does *not* do is make the check a type question instead of a run-time one:
`o^` still traps, as Swift's `!` does, and flow-sensitive narrowing (`if let`)
is a Sema this has not built. What the type gives is that
a `T` which is not optional can never be absent, so the check is **localised**
to where the source writes `^` rather than eliminated. And "no bare null" is
unavailable in the second half of its name: ADR-0117's containment means `^T`
has to go on meaning what Extended Pascal says it means.

**Explicit allocator passing.** An allocator *record* is not expressible — a
record field may not have a procedure type, neither standard having general
procedure types. A per-type allocator *parameter* is, and compiles; but `new`
is the only origin of a typed pointer and there is no pointer arithmetic or
cast, so it can only recycle blocks `new` produced rather than carve one into
several. And the capacity it serves is unchecked: a pool asked for 9 may return
a block of 4, whose own discriminant then answers `p^.cap`. Not unsafe — the
bounds check reads the served block — but the central contract is unenforced.
**This needs the FFI too**, which moves it from "cheapest on the list" to
behind the same gate as everything else.

**Error unions.** Pascal has *no* error handling — no exceptions, no result
convention. It needs sum types with payloads, which variant records nearly are.
Independent of the memory-safety fork, so it can proceed while that is open.

**`defer`.** Pascal has no early return, so a block already has one exit and
the epilogue is already where files close (ADR-0021, ADR-0032). `defer`
generalises a mechanism that exists.

**Unicode-correct `String`.** Swift's is the best-considered answer to "what is
a character" in any mainstream language, and the question is exactly the one
ADR-0109 leaves open.

**ARC.** Needs retain/release in CodeGen and a runtime, but no borrow checker,
no lifetime inference, and stays self-hostable and cheap to mirror in `src/`.

**Ownership and borrowing.** Lifetime inference is a large Sema, the most
expensive thing here to mirror in the C++ front end (ADR-0108), and the
furthest from anything recognisably Pascal.

**Traits, and `comptime`.** Schemata already give parametric types (ADR-0039),
so traits are the next layer and not the first; ADR-0054 gave the language
constant-expressions everywhere, and `comptime` is a much larger idea that
nothing yet needs.

**Actors.** Blocked, and rightly: concurrency cannot be designed before the
memory model, and the memory model cannot be designed before the safety model.

Two conclusions worth stating rather than leaving implicit:

- **The cheap items are not the small ones.** Slices, an allocator convention,
  `defer` and error unions between them cover most of what "daily practical
  development" means, and none requires settling the memory-safety fork.

- **ARC and borrowing are not equally costly here**, and the difference is not
  only implementation effort. Borrowing would make ADR-0108's C++ mirror
  prohibitively expensive and would likely force the decision to freeze it —
  so the safety choice and the oracle question are the same question asked
  twice.

One option **closes** as the language diverges: a third-party differential (FPC
under `-Miso`, or p5) can only ever check the ISO 7185 core, because nobody else
implements this dialect. Worth spending while it is still worth anything.

**The bootstrap has closed** — the compiler compiles itself and stage 2 equals
stage 3 — so the question this file used to answer, what is left before it can
compile itself, is answered. What it tracks now is the second standard.

Two orderings, and the second replaced the first. During the bootstrap it was
not ISO 7185's chapter order but the order a *compiler* needs its features in:
procedures, then the data structures an AST is made of, then the I/O that reads
source and writes IR (ADR-0004). That priority expired when the language
finished being a means to an end: since then a feature needs no reason beyond
the standard having it, ISO 7185 was completed on those grounds, and
ISO/IEC 10206:1991 is being worked through the same way.


---

## The two standards and the dialect

[`doc/history.md`](history.md#the-dialect-increment-by-increment) describes the
dialect one increment at a time — what each feature cost, and what the record
said it unblocked. This chapter is the other reading: what the *relationship* between `--std=afterschool` and the
two conformance modes now is, where it is asserted more strongly than it is
checked, and which decisions are being made by default rather than on purpose.

None of these is a work item. Each is a question with a live answer that no ADR
has written down, and the reason they are here rather than in
`doc/implementation-defined.md` §6 or `doc/sop.md` §7 is that those two
registers hold *what this compiler does not do*. These are about what it does
and whether we have said so accurately.

**They are in priority order**, so the number is the answer to "which first"
rather than a label; the section at the end says what *kind* of work each one
is, which is the part the ordering cannot carry.

### 1. ~~The dialect has spent no reserved word, and that is a fact rather than a policy~~ Answered

Four features have landed and none of them cost the lexis anything:

| Feature | What it cost |
| --- | --- |
| `external` (ADR-0121) | nothing — a directive, in the one position `forward` occupies |
| `?T` (ADR-0123) | nothing — `?` was unused punctuation |
| `array of T` (ADR-0125) | nothing — two words already reserved |
| `int64` (ADR-0128) | a *required identifier*, which §6.1.3 makes shadowable |

That is a real discipline and it was never decided: each feature found a cheap
spelling on its own, and the pattern is visible only in aggregate. **It is also
the only thing keeping the containment claim itself true — §3 below.** The
moment the dialect reserves a word-symbol, a valid Extended Pascal program
using that identifier stops compiling — which is exactly how ISO 7185 and
Extended Pascal came to be non-nested (ADR-0033), and the reason `--std` is a
property of a source rather than a switch.

The collision is coming. `defer`, error unions, traits and actors — every
remaining borrowing in *Where the ideas come from* wants a word. The dodges
available are a directive position (only where the grammar admits exactly one),
a required identifier (names, never statement syntax), punctuation (a small
supply, and poor for statements), and ADR-0038's trick of joining two words the
lexer already has, the way `and then` is joined.

**Decided (ADR-0140): a constraint, and permanently.** The dialect reserves no
word-symbol, and the question of "spending a budget" turns out to be the wrong
frame — what is scarce is not spellings but **positions**, and a position is
not used up by being occupied. `external` taking the directive slot does not
stop something else taking the statement-initial slot.

So the rule the four features were following, written down: **a dialect feature
is spelled in a position where a conforming program could not have written
it.** The test is one sentence — could a conforming program have written this
spelling *in this position*? — and it is answerable before a spelling is
chosen rather than after.

**Statements were the case this question was really about**, and they pass the
test. A statement-initial identifier in either conforming language is followed
by exactly one of `(`, `:=`, `[`, `.`, `^`, or a statement terminator (`;`,
`end`, `else`, `until` — the last three because §6.8.1 admits an empty
statement; probed, not derived). So `defer <statement>` is decidable with one
token of lookahead and cannot collide. A program that declares `var defer`
keeps its variable and loses the statement form in that scope, which is the
right direction: the dialect yields to the standard it contains.

`reserved-words` is the gate, and it is not redundant with the sweep §4 built:
reserving `defer` in the dialect leaves **all 619 cases green**,
`dialect-containment` included, because no corpus program uses that identifier.
AP §6.1.2 states the requirement.

### 2. The dialect has no external authority, and every gate here is anchored in one

| | ISO 7185 | Extended Pascal | the dialect |
| --- | --- | --- | --- |
| third-party corpus | BSI, 812 programs | — | — |
| second implementation (difftest) | yes | yes | **skipped** |
| clause-cited scenarios | yes | yes | yes, since ADR-0135's wiring |
| independent reading | ADR-0101, ADR-0107 | ADR-0101, ADR-0107 | [the spec](afterschool-pascal-spec.md), since ADR-0135 |
| goldens, irtest, `verify/` | yes | yes | yes |

The third row is literal rather than rhetorical. `tests/spec/run.py` matches

```python
TAG = re.compile(r"@(iso7185|extended):(\d+(?:\.\d+)*)")
```

was the pattern until ADR-0135's wiring, so a dialect scenario could not be
tagged at all and ADR-0105's apparatus — the one suite whose unit is a clause
rather than a program — was unavailable to the fastest-growing part of the
compiler. It now reads `@(iso7185|extended|afterschool)`.

Every oracle in this repository bottoms out in *the standard says X*.
`.claude/skills/langspec-audit/` exists because no oracle here can contradict a
**reading**, and its remedy is independent readers holding the standards text.

**Half of this is now answered.** ADR-0135 wrote
[`doc/afterschool-pascal-spec.md`](afterschool-pascal-spec.md), an amendment to
ISO/IEC 10206:1991 in that standard's own clause numbering, derived from the
thirteen records and verified by probe rather than from the compiler's source —
so there is a text to hold, and the fourth row above is no longer empty. It
found five divergences on its first pass, one of them a compiler crash no gate
here could see.

**The third row followed it.** `tests/spec/run.py` takes `@afterschool:` beside
the two standards' tags, and 45 of the specification's 46 testable clauses are
cited by a scenario — the one that is not is 6.13.1, which needs two
program-components and a link, and the harness compiles one program
(`doc/sop.md` §7). The clause table is generated from the document rather than
transcribed, so the two cannot drift.

What is **still** empty is the first two rows, and neither is something a
document or a harness can supply: there is no third-party corpus for a language
this project invented, and no second implementation, `src/` being frozen at the
conformance surface on purpose. A high citation fraction here means the
specification is young and was written against a compiler someone could probe,
not that the dialect is as well checked as the conformance modes.

One external authority is already in play and is worth naming, because ADR-0129
noticed it and then dropped it: **POSIX and the C ABI are specifications**, and
`read`, `write`, `recv` and `send` taking a pointer and a count is the far side
of the boundary choosing a shape rather than this project choosing it. Every
FFI-facing decision has an authority available to it.

**And one more turned up when the spec was aligned with the standard's clause
numbering**: ISO/IEC 10206:1991 §6.1.4's NOTE anticipates a remote-directive
spelled `external` for a heading whose block lies outside the program-block —
so ADR-0121 chose the spelling the standard names, without knowing it. The same
NOTE recommends enforcing type compatibility across the boundary, which this
compiler cannot; the departure is now written down rather than merely true.
Nothing else in the dialect has an authority.

### 3. ~~The containment stops at the link, and no document says so~~ Answered

ADR-0117's claim is that the dialect **contains** Extended Pascal:
`HasExtended(s)` is `s >= stdExtended`, and
`tests/dialect/inherits_extended.pas` is the witness. At the source level it
holds. It does not survive separate translation:

```
$ tools/pascalcc --std=extended -c lib/pasmath.pas -o pm.o     # fine
$ tools/pascalcc --std=afterschool use.pas --import lib/pasmath.pas pm.o
ld: undefined reference to `m.pasmath.afterschool.init'
pascalcc: error: module 'pasmath' was translated under a different --std
```

Sema accepts that program **completely** — the interface resolves and
`PasMath.IMax(3, 4)` type-checks — and it dies at the link. So the six
conforming modules in `lib/` are unreachable from the dialect: the layer
ADR-0114 built so the *conforming* language would have a library is the layer
the language that contains it cannot use.

ADR-0119's reason is real and the hole it closes is real — the dialect's
variant rules are a pair emitted at the access, so a dialect component reading
a variant a conformance-mode component wrote runs its guard against a tag
nothing stored and **permits** the read. What is wrong is not the rule but its
granularity: the mangling names the *mode*, and the mode is a proxy for the ABI
that is far too coarse. `lib/pasmath.pas` contains no variant record at all,
and its object code is identical under both modes.

The principled fix is the move this project already makes everywhere else —
**ask what actually differs, not what the flag says** (ADR-0044, ADR-0053,
ADR-0066, ADR-0071, ADR-0087 are the same sentence about five other
constructs): mangle on a fingerprint of the ABI-relevant features a module
actually uses, or emit both symbols where the object code is mode-independent.

**ADR-0137 took the second of those two moves**, and the entry above describes
the compiler as it was. What ships now: Sema asks whether any type reachable
from a module's interfaces is a record with a variant-part having a tag-field —
the emitter's own condition for the check, asked over the interface instead of
at one access — and a module for which the answer is no emits its activation
names under the dialect's spelling as well as its own. `lib/`'s six modules are
reachable from the dialect and not one of them needed changing; none has a
variant-part anywhere.

The alias was taken over the fingerprint because **only the definer computes
it**. A fingerprint both sides compute is the more general answer and puts one
predicate in two places, and the day they disagree is a link error nobody can
read. The caller is unchanged: it asks for its own mode's name, as it always
did.

**One direction stays closed**, and that is ADR-0120's decision rather than
work left undone: a dialect module may call `external` routines and is not a
conforming program-component, so a conforming program still cannot link one.

So the honest phrasing is no longer that the containment stops at the link. It
is that **the linkage follows the language except where the dialect would emit
a check the other mode does not**, and AP §6.13.1 now carries that sentence —
the first clause of that document to change because the language did.

### 4. ~~Containment is a claim about every program, witnessed by one~~ Answered

`dialect-containment` is that sweep (ADR-0138). The whole of `tests/extended/`
is compiled a second way under `--std=afterschool` and required to behave
identically — 228 cases, 13 seconds, four divergences with an argument apiece
in `tests/checks/containment_exceptions.txt`.

The proposal above said "require identical results" and the word doing the work
turned out to be *results* rather than output: diffing the emitted IR does not
work, because 19 of 219 sources differ textually and sixteen of those differ
because the dialect is working — ADR-0119 spells `--std` into a module's
activation names, ADR-0118 adds a tag check to every variant access. So the
gate runs the case, which is what `run_test.sh` already decides.

**What it was worth is measurable.** Switching Extended Pascal off for the
dialect at the `readstr`/`writestr` site — the literal mistake `CLAUDE.md`
warns against — leaves **all 617 existing cases green**, `inherits_extended`
included, and `dialect-containment` names sixteen. At the string-comparison
site the single witness does fail, with one opaque error where the gate reports
ten cases and their diagnostics.

It also found the only case in 228 that diverges for a reason of its own,
`substring_errors`, and following that thread found a defect the corpus could
not reach: two slices are compatible, the relational operators ask
compatibility, and `a[1..2] = a[3..4]` compiled to invalid IR (ADR-0139).

### 5. The dialect was pulled, not designed, and the pieces have not been checked for coherence — *the sharpest instance answered*

Every feature so far was demanded by the foreign interface or by the library
built on it: `external` because nothing outside the program was reachable
without it, `?T` because a `char *` may be null, `array of T` because a buffer
needs bounds at the boundary, `int64` because `read` answers an `ssize_t`, and
the variant rules and the result record because the library needed a way to
report failure. The one *designed* feature — ADR-0116's allocator — did not
survive contact.

That is a strength: nothing speculative has landed, and the record of the last
five increments is that each blocked half turned out narrower than written
down. The risk is its mirror — no one has stepped back and asked whether the
pieces form a language rather than a set of local optima.

The sharpest instance was that **the dialect had two ways to say "this may have
failed"**: an optional (`?T` — absence) and a result record (ADR-0120 — absence
with a code). **Answered (ADR-0141)**, and the survey found the premise
understated: there are **four** shapes, not two, and the fourth is not about
failure at all.

| Shape | Routines | What it says |
| --- | --- | --- |
| `ErrorCode` | 9 | the routine acted; it worked or here is why not |
| `?T` | 1 | there is a value, or there is not, and nothing to add |
| a result record | 9 | there is a value, or here is why there is not |
| `boolean` | 4 | a question about the world, with no failure of its own |

The rule is two questions in order: **is there a value to return?** — no, and it
is an `ErrorCode`; then **can it be missing for a reason the caller could act
on?** — no, an optional; yes, a result record. All 35 exported routines
classify. `absence is not a failure` was the right slogan for the second
question's *no* arm and was never a rule for the whole surface, which is why it
alone would not have told an author what to do about `Remove`, which returns
nothing, or `Exists`, which cannot fail.

`lib/dialect/README.md` is that written for the author of the next module, and
it is where the two spelling rules live too — a result record's tag is `ok`
everywhere, and an extractor is `XOr(result, default)`.

**One routine breaks the rule and cannot be fixed**, which is the part worth
carrying forward: `PasEnv.Lookup` stops the caller's program on an environment
value longer than 4096 characters, a third outcome its optional cannot express.
`getcwd` is lent a buffer and reports `ERANGE`; `getenv` returns a pointer to a
string of a length nobody stated, and the dialect has no result form that can
receive an unmeasured one. So the rule ends with a clause about honesty rather
than shape — where a boundary cannot report a failure, say so at the routine.

What §5 asks *as a whole* is still open: optionals against pointers, slices
against strings and `int64` against `integer` are three more near-overlaps that
have not been examined this way.

### 6. "The conformance modes stay exactly as they are" is slightly stronger than the truth

ADR-0121 requires `src/` to carry the *refusal* of `external`, and the message
names the mode — so a program written for the dialect and compiled under
`--std=extended` is told about the dialect.
`.claude/skills/release-engineering/` makes diagnostics part of the public
interface, alongside the accepted language and the command line.

The exact claim is therefore: **the dialect does not change what the
conformance modes accept; it does change what they say.** That is almost
certainly unavoidable and is not a conformance question — §5.1 is about
accepting and rejecting — but the phrasing in `CLAUDE.md` and in README is
stronger than what is true, and noticing that gap is this repository's habit.

### 7. The memory-safety fork: deferral, or discovery?

ADR-0109 wants networking, internationalisation, concurrency and memory safety.
Three of the four are behind the one decision that has never been made:
networking needs a struct with an agreed layout; concurrency cannot be designed
before the memory model and the memory model cannot be designed before the
safety model; and the safety model itself is the open fork — ARC, ownership, or
neither.

The record of the last five increments cuts both ways. ADR-0122 found the
argument side of the boundary has no lifetime question on it, ADR-0123 found
the nearest blocker was **null** rather than ownership, and ADR-0132 found a
buffer the caller lends was never blocked at all. **Two readings fit that
equally well**: either the decision genuinely keeps proving unnecessary, or it
is being routed around because it is the hardest thing here. The opaque handle
(`DIR *`, `FILE *`) is the first item that forces it, which is the reason it
has not simply been started.

Internationalisation is the fourth and is wholly unstarted. It is also the one
with the best model available to copy, and the one whose absence a "practical
Pascal" would be judged on first.

### What kind of work each of these is

The order above is the ranking, so what is left to say is the kind:

- **§1 was a decision** and is made (ADR-0140). It governs the spelling of
  every remaining feature, and what it turned into was a *test* a spelling has
  to pass rather than a quantity to ration.

- **§2 is a risk.** It is the condition under which this project's own history
  says a mistake survives every oracle at once.

- **§3 is a bug.** Concrete, reproduced above, and probably a day's work under
  the ABI-fingerprint framing.

- **§4 was cheap** and is done. It also demonstrated its own limit, which is
  what motivated §1's gate: a word-symbol the dialect reserves breaks
  containment for every program using that identifier, and the sweep reports it
  only where a corpus program does — which for `defer` is nowhere.

- **§5's sharpest instance is written** (ADR-0141) and the rest of §5 remains
  writing. **§6 and §7 are writing too**: a sentence, and a decision deferred
  long enough to deserve being deferred *explicitly*.


## What is next

Both standards are complete and every sweep in
[`doc/history.md`](history.md#conformance-sweeps) has been run, so only the
third item below is a language feature. Two of the others are about **oracles**
— what could still be wrong with nothing here to say so — and they come first
because v1.0.0 gave up the strongest oracle this project had and nothing has
replaced it. The fifth is the platform lock.

**The fourth is done**, and is left in place rather than deleted because what it
found is the argument for the two above it: every one of those measurements
turned something up on its first run, which is what an unasked question looks
like from the outside.

Nothing here is scheduled. This section exists so that the reasons are written
down while they are still live, which is ADR-0001's rule applied to work that
has not started.

### 1. An oracle nobody here wrote

ADR-0085 stated the cost, and **two entries have since answered it** — this
section is kept because the reasoning is what justifies the third candidate
below, which is still open.

`selfhost/difftest.sh` compared two independent implementations over 436
sources; what ADR-0085 left — the 435 cases, the stage-2/stage-3 fixed point,
and 43 SMT rules — all shared one implementation, and **a golden cannot
disagree with the program that wrote it**. The defects difftest caught were
exactly the ones every other oracle agreed about: a builtin's enumerator one
apart (ADR-0059), a comment-delimiter rule implemented wrongly in *both*
compilers (ADR-0073), a diagnostic that named two types identically and
explained nothing (ADR-0074).

Both restorations have now paid. The BSI suite found three defects on its first
run (below), and the returned front end found a **dump defect in the product**
that no golden could have: `pascalc` padded twice for a redefined `write`,
once for the husk node and once for the call it looks through, so a `proccall`
printed two levels deeper than its own arguments. Copying that into `src/`
would have closed four files and been ADR-0073's failure exactly — two
compilers wrong the same way, difftest agreeing happily —
so the Pascal was fixed and `tests/dumps/redefine_family.pas` pins it.

Three candidates, cheapest first, and not exclusive:

- ~~**The Pascal Validation Suite**~~ **Done** (ADR-0086). The BSI suite,
  version 5.7, 812 programs — fetched rather than committed, because BSI grants
  use and not redistribution, and pinned to one upstream commit so a red bar
  cannot be a corpus edit. `tests/bsi/expected.tsv` records what the compiler
  does with every one and fails on any difference **in either direction**, which
  is `verify/`'s rule for a `KNOWN_GAP` that starts holding.

  - **It found three defects on the first run**, all of which the goldens, the
    fixed point and the 43 proofs agreed were correct: `succ`/`pred` running
    out at a *subrange's* bounds rather than its host's (§6.6.6.4 with §6.7.1),
    the `for` bounds being range-checked when the loop does not execute
    (§6.8.3.9), and a program being unable to redefine `write` (§6.6.4.1). The
    first was wrong in `tests/trap_succ_subrange.pas`'s own comment and in
    CLAUDE.md as well as in the compiler — which is exactly the shape ADR-0085
    said nothing left here could catch.

  - **All three are fixed**, the third by ADR-0087, which also retired
    ADR-0060's deviation on `readstr`/`writestr` and found a check that had
    never been reachable. CONF116 is the only one of the 812 whose verdict has
    moved since, and the catalogue is what said so.

  - **Level 0 is now confirmed from outside**: all 51 `LEVEL1` programs are
    rejected, as the suite requires of a processor without conformant array
    parameters. The first claim in `doc/implementation-defined.md` §1 that
    something other than this project has checked.

  - ~~Outstanding from it: **28 undetected errors against that document's
    twelve**~~ **Done.** The two numbers were never comparable — 28 is a count
    of *programs* and the document's rows are *rules* — so the reconciliation
    was done against Annex D itself, which both sides can be keyed to. The 28
    programs name fifteen distinct entries, of which
    `doc/implementation-defined.md` §3 had eight: D.5, D.6, D.12, D.13, D.19,
    D.27, D.30 and D.48 were missing, each unenforced since the feature it
    belongs to landed. Every ERROR row of `tests/bsi/expected.tsv` now carries
    its Annex D number, so the section is regenerable rather than asserted, and
    D.59 — the one entry the suite has no program for — was probed by hand and
    is reported.

  - The largest of the accepted-but-should-be-rejected group is closed:
    §6.2.2.9's rule that a defining-point precedes every applied occurrence in
    its region was nine programs, and five are now refused (ADR-0088). The
    other four turn on a required identifier being recognised by *name* rather
    than being a symbol — ADR-0087's seam from the other side. Declaring the
    required identifiers as symbols in an outermost scope would close those
    four, §6.2.2.10 for required *types* (`type integer = char` is accepted and
    then ignored), and the rest of ADR-0087's own deferral, in one change. That
    is the next thing worth doing here.

  - Two entries the suite *reports* are not enforced either, and the document
    now says so: an undefined pointer is usually nil here, because a level-0
    activation record is a global (ADR-0053), so the nil checks catch D.4 and
    D.24 for the shape where the variable was never assigned and catch neither
    where the pointer is stale. A check that coincides with a rule is not that
    rule being enforced, and a green run of those two programs must not be read
    as one.

- ~~**The reference front end**~~ **Done** (ADR-0108). `src/` came back as
  `pascalc-s0` — lexer, parser and Sema, no code generator — so
  `selfhost/difftest.sh` compares tokens, AST and Sema over every source in the
  tree again. It arrived red at **89 of 731** files, the drift of twenty-four
  Sema commits, and the baseline is **now empty** over 732: every one of those
  rules was ported into `src/`, one commit per rule naming its clause. Eleven
  BSI CONFORM programs came back with them, CONF027 and CONF116 among them.

  - **It is a `ctest` case and an ordinary regression gate**, so any file the
    baseline names is a disagreement the change under review introduced.

  - What it still cannot do is contradict a **reading**: both sides are written
    by one author from one reading, which is why the candidate below is not
    struck through.

- **A third-party differential.** FPC under `-Miso`, or p5, over the ISO 7185
  half of `tests/`. Not a second implementation to maintain: a second *answer*,
  on programs that already exist. **The only candidate here that would
  contradict a misreading** — the BSI suite is a *fixed* corpus from 1982, and
  difftest compares this project against itself.

- **Mutation testing, committed to the tree.** It has found something every
  time it has been run here — the six occasions listed under "Stage 1", and
  ADR-0065's two mutants that changed the compiler rather than the tests — and
  it exists only as prose in those records. Two things it needs, both learned
  the expensive way: a wall-clock and output-size limit per mutant, because a
  looping mutant fills the disk before anything notices; and a restore that
  does **not** preserve mtime, or the mutated binary stays in the build tree
  and the next control run reads as a broken feature.

### 2. ~~Diverse double-compiling, while it is still possible~~ Done

**Run on 2026-08-18 at commit `ef49570`, and it passed.** The two outputs were
identical — 7,024,210 bytes, sha256 `399b9cdc…` — so a compiler reached through
LLVM's code generator and one reached through the seed translate
`selfhost/compiler.pas` to the same text. `seed/ddc.sh` is the procedure, and
`seed/README.md` holds the dated statement with what it does and does not
establish; the short version of the latter is that `v0.1.0` is this project's
own earlier compiler, so the implementations are diverse but not independently
authored.

The window was still open, which was not certain — the four steps below are kept
because they are the argument, and because `ddc.sh` reports the day they stop
working as a *skip* saying so rather than as a failure.

ADR-0085's sharpest cost is that provenance became "a chain rather than an
inspection": the first compiler now comes from a committed artefact whose only
warrant is this repository's history. That is answerable **once**, by David A.
Wheeler's diverse double-compiling, and `v0.1.0` still holds the second
implementation it needs.

1. Build `pascalc-s0` from `src/` at `v0.1.0`.
2. Have it translate today's `selfhost/compiler.pas` — call the result **A**.
3. Have `seed/pascalc.ll` build a compiler the ordinary way — call it **B**.
4. Have A and B each translate `compiler.pas`, and compare *those* outputs.

They must be identical, because both are the Pascal backend running on one
source, while the compilers that produced them came from unrelated
implementations. A and B cannot be compared to each other — ADR-0025 settled
that two backends' assembler text is not comparable — which is exactly why the
comparison is made one stage further on.

**The window closes on its own**, and nothing will announce it: it works only
while the v0.1.0 C++ compiler still accepts `compiler.pas`, and every feature
the compiler starts *using* risks ending that. Worth doing now and recording
the result in `seed/README.md` even if it never runs again — a dated statement
that the seed carried nothing the C++ compiler did not is worth more than the
ability to repeat it.

### 3. Conformant array parameters, and level 1

The one language feature here, and the only work that would change the
compliance level `doc/implementation-defined.md` states.

That document's §1 declares **level 0**, which is a complying level rather than
a gap: ISO 7185 clause 5.1 a) defines it as clause 6 without §6.6.3.6 e),
§6.6.3.7 and §6.6.3.8. Accepting those three makes a level 1 processor.

Most of the mechanism is already here. ADR-0040's schematic formal parameter is
a descriptor beside the address — bounds that travel with the actual — which is
what a conformant array parameter needs and is why one compiled body can serve
every extent. What is genuinely new is §6.6.3.7's congruity rules for
conformant array schemas, which are not ADR-0030's rules for procedural
parameters however alike the two read.

Worth knowing before starting: a schematic formal already covers this ground in
Extended Pascal, so the feature buys **conformance and not expressiveness**.

### 4. ~~Nothing can currently measure what the corpus reaches~~ Done

Both versions this entry proposed were built, and each found something the run
before it could not see.

- **The cheap version** — every diagnostic literal looked for in the `.err`
  goldens — landed in v1.1.1 as `diagnostic-coverage`. It found **32 messages
  nothing named** at once; 26 cases were written and four are argued unreachable
  in a catalogue that fails in both directions.

- **`procedure-coverage`** (ADR-0103) instruments the *emitted IR* with clang's
  SanitizerCoverage, which is possible only because the backend is textual.
  563 of 565 procedures are entered. It found four documented `--dump` flags no
  case had ever passed, and `tests/dumps/` exists because of it.

- **The expensive version** — `pascalc --coverage` (ADR-0104) — landed in
  v1.2.0 and did want a record. The compiler instruments itself, one counter per
  statement, and the *denominator* is read back from the same `.ll` the
  compilation wrote, so the two halves of a figure cannot disagree about which
  lines were executable. 12,949 of 13,403 statements are run by the corpus.

- **`tests/spec/`** (ADR-0105, ADR-0106) is the same question asked of the
  *standards* rather than of the compiler: 13 of 207 testable clauses cited,
  with 85 of the 292 headings triaged out as structural or unimplemented so the
  denominator means something.

**Two things it did not buy, both in `doc/sop.md` §7.** A statement is not a
branch — `if c then a else b` on one line is covered when either arm runs — and
the line-coverage gate is a **ratchet** rather than an allowlist, so it notices
a loss and cannot argue that what is uncovered ought to be. The corpus is also
enumerated by glob, so the shell harnesses are invisible to it; that is how
`Usage` and `Version` first read as unreached.

### 5. The platform lock has a scoped way out

`seed/README.md` states the cost — the repository is x86-64 Linux only, and
porting needs a working compiler on the new target first. A `--target=` option
would turn that into "porting needs a cross-assembler": the triple and the
datalayout are already written out as text (ADR-0028), so the emitter's half is
small.

What needs investigating rather than promising is everything *else* that
assumes the target — `fileSize` against `PAS_FILE_SIZE`, the pointer width the
frame layouts are computed with, and `LlSize`/`LlAlign`. This has an honest
chance of "more is baked in than it looks", and should be scoped as an
investigation rather than as a feature.

### What continuous integration does and does not check

`.github/workflows/ci.yml` builds and tests on every push and pull request, in
two minimal **containers** rather than on a machine with a toolchain already
installed — which is the whole of what it adds. Every machine this compiler has
been built on has LLVM 21 and a C++ toolchain, so "the build needs nothing of
LLVM's" is a claim none of them can test. It also puts an assembler *older*
than the one that emitted the seed against that seed, a portability property
nothing else checks; and at a `v*` tag it requires `seed/pascalc.ll` to be what
the current source produces, which is the one question ADR-0085's
refresh-at-release-tags policy otherwise leaves to a human to remember.

**It adds no oracle.** It runs the ones that already exist, on a machine that
has never seen this repository. Item 1 is not something CI can supply.

**Its first two runs each found something**, which is the argument for having
written it:

- **README.md's build instructions were wrong.** "Requires `clang` on PATH, and
  nothing else" is false — `--no-install-recommends` gives no `make`, and
  configure fails before it reaches a compiler. Nobody could have noticed on a
  machine that has one. The sentence now names `cmake`, `make` and `clang`, and
  claims *nothing of LLVM's* rather than nothing at all.

- **Which z3 is installed decides whether the proofs pass.** `verify.py` gives
  each rule 30 seconds and reports a timeout through the same channel as a
  counterexample, so Debian trixie's z3 4.13.3 — slow enough to exceed it on
  the two symbolic 32-bit modulo rules — produces *"verification FAILED:
  mod-is-non-negative"*. That reads as the compiler getting `mod` wrong, which
  is ADR-0074's lesson about a message naming the wrong rule, in the one
  directory whose entire purpose is being sure. CI installs the pip package
  `verify/README.md` documents, and that README now says which failures to
  disbelieve; **making a timeout report as something other than a disproof is
  not done.**

One thing the workflow had to be told explicitly: `verify.py` *skips* when z3
is absent, which is right for a checkout and wrong for CI — the rest of the
suite would report green with every rule never run. It asserts z3 is
importable before it configures, so a green bar means the proofs ran.

## Known limitations

Things that are wrong or absent today, listed so they are not rediscovered as
surprises.

### Under ISO 7185

- **Nesting deeper than 1000 levels is rejected** (ADR-0020). The limit bounds
  the *tree*, not the parser's call depth — the distinction matters because a
  30 000-term `a+b+c+...` chain parses iteratively and used to segfault in
  *Sema*, two stages after the parser survived it. The bound protects all four
  recursive walkers (parser, Sema, CodeGen, the AST destructor) with an order
  of magnitude of headroom against the tightest measured crash point, ~19 000
  levels on an 8 MiB stack. The cost: legal machine-generated programs with
  chains beyond 1000 terms are refused. Since ADR-0110 a **block** is one of
  the levels it counts, which it always should have been — so 999 remain inside
  the program's own, and nested declarations past the bound reach this
  diagnostic instead of running the scope stack off its end.

- **A variable created by `new(p, c1, ..., cn)` may still be assigned or
  passed.** ISO 7185 §6.6.5.3 forbids it, because the unselected variants do
  not exist; detecting it needs the pointer's *value* to carry which form
  created it, and nothing tracks that (ADR-0027). Permissive where the standard
  is restrictive, like the use-after-dispose gap below.

- **Use-after-dispose through a second pointer is undetected.** `dispose(p)`
  sets `p` to nil, which converts the common form into the nil trap, and that is
  all it does. No proof in this repository claims more.

- **`readln` at an unterminated last line** stops rather than failing, where
  ISO calls reading past end-of-file an error. Files whose last line has no
  terminator are common enough to be worth the deviation; `readln` with nothing
  left at all still fails (ADR-0021).

- **Characters are bytes, and the locale is never consulted.** `char` is
  0..255, so UTF-8 passes through unchanged but a multi-byte character is
  several `char` values. That is a deliberate non-decision: encoding is the
  program's business. It does mean a Pascal-hosted lexer sees bytes, which is
  fine while the language it lexes is ASCII.

- **Not implemented at all:** nothing. Sets (ADR-0028), `goto` (ADR-0029 and
  ADR-0032), procedural parameters (ADR-0030), non-text files (ADR-0031), the
  transfer procedures with `page` (ADR-0067) and §6.3's string constant
  (ADR-0068) were this group, and it is now empty — **ISO 7185 is complete**.
  The last four are worth a sentence, because they arrived the same way twice.
  §6.6.5.4's `pack`/`unpack` and §6.9.5's `page` were *missed*, not declined,
  and three documents asserted completeness while they were absent; a
  documentation audit found them by compiling a probe. `const s = 'hello'` was
  then found the same way, hours after the `iso-7185-done` tag had been moved
  to the commit that fixed the first three. No program in the corpus had ever
  written any of them, so every oracle agreed. What makes the claim true now is
  `tests/transfer.pas`, `tests/page.pas`, `tests/stringconst.pas` and the cases
  beside them — not the implementations.

- **A set's base type must have its values in 0..255**, because every set is
  one 256-bit word. ISO 7185 §6.4.3.4 leaves the size to the implementation, so
  this is a permitted limit rather than a deviation — but `set of integer` is a
  legal program this compiler refuses (ADR-0028).

- **An identifier may contain an underscore**, where §6.1.3 makes one `letter {
  letter | digit }`. It is how a name that would collide with a word-symbol is
  spelled — `label_`, `set_`, `packed_` — and how a test program takes the name
  of its file: thirteen identifiers in `selfhost/compiler.pas` and the program
  headers of forty-three test programs (ADR-0072).

### Under ISO/IEC 10206:1991

Five more, each stated in the record that made it. A sixth was listed here for
exactly one commit and is **fixed**: a variable-string may now be a value
parameter (ADR-0115), so a string argument may be a literal, another function's
result or a string of any capacity. It is worth a sentence because of how it was
found — ADR-0052 recorded the refusal from the *compiler's* side and no document
carried its cost to a **caller** until a library was built on it, at which point
`StartsWith(s, 'Hello')` not compiling stopped looking like a house style and
started looking like what it was.

- **String concatenation draws from an arena.** A string value is a pointer and
  a length (ADR-0051), so only `+` makes characters that did not exist; they
  come from a fixed buffer in the runtime. One *statement* holding more live
  string values than the arena holds is the limit.

  - It was a **ring**, and the sentence here used to end "stated rather than
    silently wrong". That was the reverse of the truth: a wrap wrote one live
    value over another, so `a + a = b + b` over two 512K strings compared a
    buffer with itself, printed EQUAL and exited 0. ADR-0111 made it a stack
    whose end CodeGen supplies — a release emitted after any statement that
    took storage — and both ways of exhausting it are reported now.

- **A subrange whose bounds are not constants is refused as a set's base
  type.** `set of 1..m` inside a procedure is legal under §6.2.3.8 b) and is
  refused. Every set here is one 256-bit word whose base type must have its
  values in 0..255 (ADR-0028), and a bound the block evaluates cannot be
  checked against that before the program runs — so it is the limit
  `set of integer` already states, reached by a different route.

  - **Everything else in the entry that stood here is fixed**, over five
    records. `type t = array [1..m] of integer` and `type t = vector(m)` work
    since ADR-0127 — a type's descriptor belongs to the **block**, so it is
    evaluated once and every variable of the type shares the discriminant
    symbols rather than a copy of their values; that was ADR-0107's independent
    reading's finding most likely to break a real program. The *bare* subrange
    — `var x: 1..m`, `type t = 1..m`, `array [1..m] of 1..m` — works since
    ADR-0133, which did the one thing ADR-0127 named: the range check at a
    store reads the descriptor the way the subscript check always has. And a
    **record's field** and a **file's component** work since ADR-0134, a record
    being no kind of block. **There is no longer a conformance defect that is
    known and unfixed.**

  - Worth carrying forward from how those two went. ADR-0133's fix was three
    lines of check and three *other* things that had been true only because the
    shape was unreachable — `DynamicExtent` answering yes for a subrange, and
    the anonymous schema ADR-0113 hangs on such a type being read as §6.4.8's
    by `Assignable` and by the assignment lowering. **A device that borrows a
    language concept's representation will be read as that concept**, and the
    misreading is invisible until something outside the device's original shape
    reaches it. ADR-0134's was the opposite lesson: the reason ADR-0133 gave
    for refusing a record field **named the check rather than the obstacle**,
    and the first attempt to admit it without that check silently miscompiled a
    program — so a register entry is worth re-reading for what its reason is
    actually saying.

- **ExpDigits is not a fixed number** (ADR-0064). §6.10.3.4.1 makes it one
  implementation-defined value; here it is what C's `%E` writes — two digits,
  or three past 1e100 — so a representation stays exactly ActWidth wide while
  that width depends on the exponent. A conforming processor pads `E+00` to
  `E+000`.

- **A direct-access file's length bound is not checked** (ADR-0050). §6.4.3.6
  makes `file [1..10] of T` at most ten components; this one will hold eleven.
  The index type is used for the position's *type* and its lower bound, not as
  a capacity.

- **§6.5.6's substring aliasing rule is not enforced** (ADR-0057), for the same
  reason ADR-0027's is: it is a property of values at run time, and nothing
  tracks it.

