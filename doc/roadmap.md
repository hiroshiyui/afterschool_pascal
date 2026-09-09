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

## Where development stands — 2026-09-07

**Released: v3.7.0**, and `CHANGELOG.md`'s `Unreleased` is empty. Its
headline is the boundary: a command injection in the language server found,
closed, audited and audited again (ADR-0362 – ADR-0364), a TOML library and
the project reader rewritten over it (ADR-0360, ADR-0361) — none of it a
change to the language. The release before it, v3.6.0, was the first whose
headline broke existing programs: the map keys itself with a trait
(ADR-0355). The compiler builds itself,
stage 2 equals stage 3 in every program-component, and the suite is 905 cases
green at `-O2` and at `-O0`.

| | |
| --- | --- |
| **Open and ready to do** | the platforms, and only the platforms: **macOS** runs green on arm64 and its job can now fail ([below](#cross-platform-support)), with nine skips left — every one a tool the runner has not got — and a release leg still disabled; **Windows** is **deferred** ([below](#cross-platform-support), ADR-0374) and it was deferred on a run rather than a reading: a program builds and prints its golden under wine, and the non-local goto faults on an alignment this compiler gets wrong for Win64 alone; **s390x** aligns `tySet` where nothing else does. **Windows is now a target the compiler emits for** even though nothing here runs one (ADR-0371) |
| **Open and awaiting a decision** | the object model's increments A and C (ADR-0315 is `Proposed`; B is built and has a client that is not a test), and a record's `Drop`, with exactly one asker |
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
([history](history.md#the-memory-model-read-against-the-goal)); what each left
is a sentence:

| Rust | Here | Route |
| --- | --- | --- |
| `Box<T>` | `owned ^T` (AP 6.4.14) | from the file variable, not from Rust (ADR-0181) |
| `Drop`, RAII | scope-based release | present since 1982, named by ADR-0151 |
| a move | `take` (AP 6.4.14.6, 6.4.12.7) | forced by writing `PasList` (ADR-0182, ADR-0267) |
| `&mut T` | a `var` parameter bound to `o^` | *unformable* rather than checked (ADR-0201) |
| `&T` | `protected var`, over an owned pointer too | ISO's own word (ADR-0283, ADR-0318) |
| `Option<T>`, `Result<T, E>`, `?` | `?T`, `T ! E`, `try` | ADR-0123, ADR-0176, ADR-0178 |
| `&[T]` | `array of T` | ADR-0125 |
| `Send`, channels | `task`, `channel [n] of T` | ADR-0268 |
| traits | `trait` / `impl … for`, as a bound | ADR-0338 – ADR-0341 |
| lifetimes, `Rc`, `RefCell`, `unsafe` | **absent** | the three sentences below |

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

### The object model (proposed)

[ADR-0315](adr/0315-methods-and-traits-without-inheritance.md) proposes
Rust's decomposition — methods and traits without inheritance, no base class,
no `is`/`as` — in three increments. **B is built** (traits, `impl … for`, the
bound on a schema's discriminant: ADR-0338 – ADR-0341, ADR-0344, AP 6.7.9)
and since ADR-0355 has a client that is not a test. **A and C are not**, and
are judged separately: A is not a prerequisite for B, the record's staging
sentence notwithstanding.

| Increment | What it adds | What it would retire |
| --- | --- | --- |
| **A. Methods** | `impl T; … end;`, `x.M(a)` meaning `M(x, a)`, method names in the type's scope | 118 of 484 exported names that repeat their module's noun as a hand-spelled receiver (retaken 2026-09-05; run `tests/checks/export_unique.py`). No new representation |
| **C. `dyn T`** | dynamic dispatch, only as `owned ^dyn T` and as a var parameter | nothing — it is what a heterogeneous collection needs, and the first vtable here |

**Not settled**: whether to build A or C. B's payoff was a program's own
text — thirty call sites and fourteen routine parameters — and A's is
call-site spellings that block no program; A's best argument arrived from B
(ADR-0339): two modules exporting `Compare` collide under §6.11.2, and
`x.Compare(y)` in the receiver's scope is the collision-free form. Its one
cost no gate will see is that `Put` declared in a dozen impls cannot be found
by grepping its name; `--dump-uses` and the language server already answer
it, a person with `grep` does not. Whether any of it is built is not a promise
either way — an area announced and abandoned would be the first thing on this
page that was neither finished nor left.

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

### Cross-platform support

Developed on x86-64 Linux; **built and tested on aarch64 on every push**
(ADR-0155 – ADR-0159), shipped as an archive per release (ADR-0296); **i386
admitted** (ADR-0325, ADR-0346), the two width defects the port left found
and gated (ADR-0328, ADR-0334, ADR-0364;
[history](history.md#the-32-bit-port-and-the-width-it-left)). The twenty-five
target measurement is
[in history](history.md#cross-platform-support-measured); run
`python3 tests/checks/target_layout.py` rather than quoting it.

**The tiers, since 2026-09-09.** **GNU/Linux is first**: the seed is generated
for x86-64, both shipped archives are Linux, every gate has a job that installs
its tools, and i386 is built and run at two optimisation levels. **macOS
(arm64) is second**: the whole suite runs natively on every push and the job
can fail (ADR-0368), with nine gates skipping for want of a tool and no archive
shipped. **Everything else is unsupported and open to contributors** —
Windows, FreeBSD, OpenBSD, NetBSD, Haiku — with `README.md`'s *Platform tiers*
saying what a port starts from.

**What is left** is small and specific:

| Target | What it needs |
| --- | --- |
| **macOS** | **a job that can fail, since [ADR-0368](adr/0368-macos-is-a-job-that-can-fail.md).** 904 of 912 cases run and pass on arm64; `SANITIZE_REQUIRE` and `UNICODE_CONFORMANCE_REQUIRE` are set and the remaining eight variables name tools the runner has not got. **Eight skips remain and the job's comment lists them with the reason for each.** ADR-0368 listed ten, and two of those were not facts about macOS at all: `verify-lowering` skipped because z3 was installed with `--user`, which Homebrew's externally-managed Python refuses, and the step swallowed its own failure — so the 43 SMT rules had never run there; `unicode-conformance` skipped because that job did not fetch the database. Both closed in `d8d925d`, which is what makes the remaining eight a homogeneous list — and the second bought a reading the tree had never had, `runtime/pasrt_unicode.c` compiling under `-pedantic-errors -Werror` on Apple clang with the committed tables regenerated on a second platform. **`--target=` admits both Darwin triples since ADR-0372**, so a module built there names the machine it is for rather than relying on clang to override the header — and `setjmp-arity` stopped skipping on that runner with them, the host target having become comparable. **Nothing is open**: ADR-0375 enabled the release-matrix leg, so a `v*` tag ships an `arm64-darwin` archive beside the two Linux ones. Apple has no static libc, so that leg configures `APASCAL_STATIC_PASCALC=OFF` and does not set `RELEASE_REQUIRE_STATIC`; what it asserts instead is a claim macOS can answer and `ldd` never could — that the binary depends on nothing outside `/usr/lib` and `/System`, which `otool -L` reports and every hosted runner's Homebrew makes worth asking. The leg that was disabled, which is three decisions rather than a run finding anything — the `package` job's comment names them. Nine failures got it there and **not one was in the compiler** — every one was a harness assuming Linux ([history](history.md#the-first-macos-run)) |
| **Windows** — **deferred (ADR-0374)** | **Measured against mingw-w64 rather than read, on 2026-09-09** (Debian's `x86_64-w64-mingw32-gcc` 16-win32, run under wine 10.0), and the row it replaces was wrong in both directions. Reproduce it with `x86_64-w64-mingw32-gcc -std=c11 -O2 -I runtime -c runtime/<unit>.c` — `pasrt_unicode.c` **compiles clean**, which is the whole of AP 6.4.15. What was real and is **closed**: `fmemopen` and `open_memstream`, absent there as in the MSVC CRT — ADR-0370 removed both, §6.7.5.5 needing an auxiliary `text` variable backed by memory and never a `FILE *`, so `pasrt.c` **compiles here** as of ADR-0373 and is three names from ISO C. What is real and **larger than this row said**: `_longjmp`. It is not a spelling. `setjmp(x)` expands to `_setjmp(x)` on glibc and to `_setjmp((x), frame)` on mingw — two arguments, through `__imp__setjmp` — because Win64 unwinds through SEH, and the emitted code calls `_setjmp` with one argument, which is a wrong arity and the class ADR-0121's row says nothing here checks. The signal mask is **not** the difference — the arity is — but it is a real cost, and a measurement first published here said otherwise: calling glibc's `setjmp` *symbol* costs **265.4 ns against `_setjmp`'s 2.4**, a `sigprocmask` syscall, where the earlier figure had compiled both arms to `_setjmp` because the macro expands to it. So emitting `setjmp` is not an available answer. What is left is a target-dependent call, and **it is done** (ADR-0371): `x86_64-w64-windows-gnu` is a fourth admitted target, the emitter writes `_setjmp(env, frame)` there with `llvm.frameaddress` supplying the second, and `setjmp-arity` compares the arity against clang's on every admitted target. `llc -mtriple=x86_64-w64-windows-gnu` assembles the module to COFF and `clang --target=x86_64-w64-mingw32` compiles it to an object whose one undefined symbol is `_setjmp`. **The runtime's half is closed too** (ADR-0373), and `runtime/pasrt.c` **compiles here**. mingw declares `longjmp` and never `_longjmp` — only `_longjmpex` for i386 and `__mingw_longjmp` for arm — and it is not a CRT question, being absent from the msvcrt and the UCRT sysroot alike. No portable spelling exists: `longjmp` after `_setjmp` works on glibc and would restore a mask on Darwin that was never saved. So `pasrt.c` holds **one preprocessor conditional**, the only one in the runtime, and `runtime-isoc` catalogues the set of them in both directions so a second is a decision rather than a habit. The tidier shape — the emitter writing the jump as it already writes `_setjmp` — waits on a reseed, the committed seed declaring and calling `@pas_jump_go`. A mingw-w64 *version* difference stops mattering with it: Ubuntu 24.04's declares `_longjmp` and Debian trixie's v14 does not, which is why the toolchain is pinned, and which no longer decides whether this unit compiles. What is **not**: `access` compiles and links against `<io.h>`, so that was an MSVC-only problem; `_Complex` is declared and implemented for all seven functions `pasrt.c` uses, and a probe built from that block compiles under this tree's own `-pedantic-errors -Werror`, links, runs, and agrees with glibc — `(1+1i)**2` differs in the last bits and mingw is the *more* accurate of the two, which `tests/extended/complex.pas` cannot see at `:6:3` anyway. `timespec_get`/`TIME_UTC` are `#ifdef _UCRT` in mingw's `<time.h>`, so they are a CRT choice and not a gap — **settled on 2026-09-09 against a real UCRT sysroot**, `mingw-w64-ucrt64-dev` having supplied the `include` this row once recorded as missing. Under it `__MSVCRT_VERSION__` is `0xE00` and the headers define `_UCRT` themselves, and `pasrt_task.c` compiles with no `-D` at all. `runtime-nonposix` carries the claim as a `crt _UCRT` row, both directions. **And the weight is somewhere nobody had costed**: `pasrt_posix.c` stops at `netdb.h`, and behind it are `sys/socket.h`, `poll.h`, `spawn.h`, `termios.h`, `sys/wait.h` and `sys/ioctl.h` — winsock2 with its own initialisation and error convention, `WSAPoll` for `poll`, and no `posix_spawn` for `PasProcess.Execute`. Fifteen call sites name a socket primitive. **That was a floor and is now a list** (ADR-0369): `runtime-nonposix` probes each `#include <...>` on its own, so seven come back where the compile reported one — `netdb.h`, `poll.h`, `spawn.h`, `sys/ioctl.h`, `sys/socket.h`, `sys/wait.h`, `termios.h`. **Ten of the seventeen it names are present**: `dirent.h`, `errno.h`, `fcntl.h`, `signal.h`, `stdio.h`, `stdlib.h`, `string.h`, `sys/stat.h`, `time.h`, `unistd.h`. So the directory walk, the file information and the file model are not what is missing — sockets, the terminal and `posix_spawn` are, and `<pthread.h>` is there, so AP 6.4.16's channels do not block a port either. **A program was built and run** under wine 10.0 on 2026-09-09, and that is what settled it: `tests/hello.pas` prints its golden, and `tests/goto_nonlocal` and `tests/goto_files` **fault** — `_setjmp` on Win64 saves XMM6–15 with an aligned `movdqa` and this compiler places the jump record at offset 136, which is 8 mod 16 (`doc/sop.md` §7, proven in isolation). Two more things running found that no compile check could: the runtime must be built by **clang**, mingw-gcc compiling `_Thread_local` to emulated TLS that the emitted module's native TLS cannot link against; and a Windows build writes **CRLF** where a POSIX one writes LF, which ISO 7185 leaves to the processor and which makes the corpus goldens not directly comparable. **So the platform is deferred**: a frame-layout change measured across six targets, plus seven headers and the `PasNet` question, is a body of work rather than a finish. What is kept costs a second a push — the six targets, the two units compiling, `runtime-nonposix` and `setjmp-arity`. Run `python3 tests/checks/runtime_nonposix.py` rather than quoting this |
| **s390x** | aligns `tySet`'s `i256` to 8 where every other target says 16 — thirteen offsets, and `target-layout`'s second claim would catch it |

**What is not claimed**: the seed is generated for x86-64 and stays so; the
aarch64 job establishes that the port *works*, not that every oracle has run
there — `llc-second-backend` and `benchmark` abstain on it (`doc/sop.md` §7);
and the layout gate sees frames and nothing else.

### What a helper is written in

Decided in [ADR-0366](adr/0366-a-helper-is-not-a-shell-script.md), and the
short form is three sentences.

**The portability boundary is the set of external programs a helper invokes,
not the language.** A Python script that runs `nm` is exactly as unportable as
a shell script that runs `sed`, which is what two of the nine macOS failures
were. So: a harness is Python 3, *and* it reaches for the standard library
rather than a subprocess — `pathlib`, `tempfile`, `difflib`, `re` in place of
`find`, `mktemp`, `diff`, `sed`. Invoking the toolchain is not what that
forbids; invoking a general-purpose Unix utility to do what the language can
do is.

**A helper that ships to a user is written in Afterschool Pascal; a gate is
written in Python.** A gate must be able to fail *because the compiler is
broken*, so it cannot be written in the language under test. A shipped helper
has the opposite constraint, and the one thing present on the user's machine
is the compiler and runtime just installed there — `bin/apconfig` is the
precedent (ADR-0361).

**Nothing is converted wholesale, and a conversion is checkable.** These
scripts *are* this project's evidence, so a rewrite lands with two things and
neither is a green suite: byte-identical output from both versions on the
current tree, and that gate's own historical mutation re-run against the new
version, failing the same way.

**Why it is a decision and not a preference**: macOS was a platform where a
shell script *runs* and differs in detail. Windows is one where there is no
bash, no `sed`, no `nm` and no `#!` line, so all 31 scripts do not run at all —
each is a blocker rather than a bug, and a rule that converts them only when
they are being edited never reaches the stable ones. The driver is the
collision the record names and leaves open: `tools/pascalcc` is the product
rather than a harness, and the decision that it stays a shell script cannot
stand beside the Windows row.

**The lint is built** ([ADR-0367](adr/0367-the-rule-about-helpers-is-enforced.md)):
`helper-portability` is a `ctest` case, and what it watches has moved with the
tree. There is no longer a script to lint for GNU-only flags — every harness
is Python — so the three claims are that **no tracked shell script the
catalogue does not name** appears, that the one it does name holds none of the
constructs bash 3.2 lacks, and that **no Python helper starts a
general-purpose utility** to do what the standard library does. All three fail
in both directions, and the catalogue is one line of shell: `tools/pascalcc`,
which the Windows row above is the standing argument against.

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
