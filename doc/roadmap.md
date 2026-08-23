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
| [What blocks the library](#what-blocks-the-library) | the foreign-interface items a practical library still waits on, and what a survey of daily needs left open |
| [Where the ideas come from](#where-the-ideas-come-from) | the borrowings from Rust, Swift and Zig, and where each stands |
| [The open questions](#the-open-questions) | the one structural risk no record can close, and the two oracles still worth building |
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
| **The memory-safety model** | Half answered. The *lifetime* half was already here — an owned value is released when the variable holding it dies and cannot be copied out of it, which is what a file variable has been since 1982 (ADR-0151). The *aliasing* half — may a second name hold one owned value, and if so how: ARC, or borrowing — is undecidable on the evidence in hand, and becomes decidable at the first construct that demands two live names. Concurrency is that construct. |
| **The text model** | Unstarted. `char` is a byte and nothing consults the locale. Real internationalisation needs a wider character type or a text type distinct from §6.4.3.3's strings, and Swift's `String` is the model to copy. **The largest thing on this page that no record has touched**, and the one a "practical Pascal" would be judged on first. |
| **The memory model** | Unstarted, and it cannot be designed before the safety model: shared mutable state is where the two meet. |
| **How far the C++ reference front end follows** (ADR-0108) | Frozen at the conformance surface in practice — `difftest` skips a dialect source — and that is the obvious answer, not the decided one. |

What is already in hand and was not built for this: modules and separate
compilation (ADR-0053, ADR-0079) mean a library needs no new language
mechanism, and `runtime/pasrt.c` is where the outside world already enters.

---

## What blocks the library

The library is sixteen modules — eight conforming, eight dialect. A survey of
what a daily program needs against the thirteen that then existed (2026-08-23)
found three gaps that needed no language change and were closed the same day (`PasFile`,
`PasProcess`, `PasStrVec`; the first needed ADR-0172 first), and three that
stay open. Every one of the three is the same item underneath.

**A pointer to storage the callee owns whose contents are not characters.**
Every foreign type that crosses today is a scalar, a string copied at the call,
or a slice the caller owns (AP §6.7.7). What cannot cross is now two things
rather than a category:

- **An opaque handle** — `DIR *` from `opendir`, `FILE *` from `fopen`. No
  layout has to be agreed; it is a token to hand back. What it needs is a
  *lifetime*, and the language has one to offer: a file variable is a handle a
  block manages, closed at exit and on a non-local `goto` (ADR-0021, ADR-0032).
  It is **not blocked** — `int64` carries one today, unsafely, and
  `tests/dialect/foreign_int64_handle.pas` pins exactly how unsafely (ADR-0151,
  Annex C.7). What is open is giving it a type. This is the cheapest thing left
  and the first that genuinely touches the aliasing question above.

- **A struct with a layout** — `struct sockaddr`, `struct stat`,
  `struct dirent`. This needs the compiler and C to agree about offsets, which
  nothing here does for a foreign type. It is what stands between here and a
  socket, and between here and a directory listing.

**What those two leave open, by name:**

| A daily program wants | Why it waits |
| --- | --- |
| command-line arguments as a list | the program's own parameters carry them (ADR-0081) and nothing else can — a *module* has no program-parameters to ask, and the runtime routine that would answer is a `pas_*` name AP §6.7.7.10 reserves. A feature, not a module |
| a directory listing | `readdir` answers a `struct dirent *` — the struct item. `popen` and `fgets` would do it through the shell and a `FILE *` — the handle item, plus an `int`-sized length where a slice crosses as `i64` |
| a socket | the struct item, with `sockaddr` |
| creating a file through `PasIO` | `O_WRONLY`, `O_CREAT` and `O_TRUNC` are header numbers, and the policy PasFS set is that a number a module cannot check does not go in. Not a language question, and not urgent: §6.10's `rewrite` creates files and `PasFile` wraps it |

**The lesson from the five FFI increments**, worth keeping for the rows above:
a decision that looks like it needs a model may need it for only part of its
surface, and the part that does not is usually worth taking first. Two
estimates in a row were wrong in that useful direction (ADR-0122, ADR-0123).

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
| Scope-based release | ISO 7185, Rust's `Drop` | lifetime | **Done, and it was already here** (ADR-0151) |
| Explicit allocator passing | Zig | part of memory safety | **Tried; does not survive contact** (ADR-0116) |
| Error unions / `Result` | Zig, Rust | error handling | **Open, and the biggest practical gap.** Variant records nearly are sum types with payloads; the library's result records (ADR-0120, ADR-0141) are the convention that exists. Independent of the safety fork |
| `defer` | Zig, Swift | resource safety | **Open and cheap.** A block already has one exit and the epilogue already closes files; `defer` generalises a mechanism that exists. Its spelling passes ADR-0140's test with one token of lookahead |
| Unicode-correct `String` | Swift | the text model | **The model to copy**, and unstarted |
| ARC | Swift | aliasing | **Undecidable on the evidence in hand** (ADR-0151) |
| Ownership and borrowing | Rust | aliasing | **The same, and the worst fit besides** — and the most expensive thing to mirror in `src/` |
| Traits / protocols | Rust, Swift | abstraction | **Later.** Schemata already give parametric types (ADR-0039) |
| `comptime` | Zig | metaprogramming | **Later.** Constant-expressions everywhere (ADR-0054) is as far as anything needs |
| Actors / `Send`+`Sync` | Swift, Rust | concurrency | **Blocked**, and it is what *unblocks* the two aliasing rows: concurrency is the construct that certainly demands two live names for one value |

Two conclusions worth stating:

- **The cheap items are not the small ones.** `defer` and error unions between
  them cover most of what "daily practical development" means, and neither
  requires settling the memory-safety fork.
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
used to stand here. Nine of the twelve are answered — the table at the end
says where — and what each found on its first run is in
[`doc/history.md`](history.md#what-the-roadmap-answered). Three remain.

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

### 2. A third-party differential

FPC under `-Miso`, or p5, over the ISO 7185 half of `tests/`. Not a second
implementation to maintain: a second *answer*, on programs that already exist.
**The only candidate that would contradict a misreading** — the BSI suite is a
fixed corpus from 1982, and `difftest` compares this project against itself,
both front ends being written by one author from one reading. Closes as the
language diverges, so it is worth more now than later.

### 3. Mutation testing, committed to the tree

It has found something every time it has been run here — the occasions are
listed in history under *Stage 1*, and ADR-0065's two mutants changed the
compiler rather than the tests — and it exists only as prose in those records
and as a step in `doc/sop.md`. Two things it needs, both learned the expensive
way: a wall-clock and output-size limit per mutant, because a looping mutant
fills the disk before anything notices; and a restore that does **not**
preserve mtime, or the mutated binary stays in the build tree and the next
control run reads as a broken feature.

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
run over 25 targets, all 4538 offsets each:

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
  all it does (ADR-0019). *The memory-safety model's aliasing half, above.*

- **A text file's last line need not end in a terminator.** §6.4.3.5 says it
  does, so one is supplied when the file is read; reading at end-of-*file*
  is D.97's error and stops the program. *A decision (ADR-0021).*

- **Characters are bytes, and the locale is never consulted.** `char` is
  0..255, UTF-8 passes through, a multi-byte character is several `char`
  values. *The text model, above.*

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
| Memory safety: deferral or discovery? | Lifetime was already answered, by the file variable; aliasing waits on concurrency | ADR-0151 |
| An oracle nobody here wrote | The BSI suite, fetched not committed; `src/` back as a reference front end | ADR-0086, ADR-0108 |
| Diverse double-compiling | Run once, 2026-08-18, identical outputs; `seed/ddc.sh` | `seed/README.md` |
| Conformant array parameters, and level 1 | Done, and the 51 BSI level-1 programs found nine defects in the first implementation | ADR-0153 |
| Can anything measure what the corpus reaches? | Three coverage gates and a clause-cited suite | ADR-0103 – ADR-0106 |
| Is the platform lock scoped? | Three things, two done; 32-bit is what remains | ADR-0155 – ADR-0159 |
| Can a conforming program learn that a file is missing? | `binding(f).bound` says whether it is there | ADR-0172 |
