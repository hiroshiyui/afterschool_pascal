# ADR-0327: The checker the construct rests on

Date: 2026-09-05

## Status

Accepted. Closes `doc/sop.md` §7's ThreadSanitizer row, which stood from
ADR-0261 through ADR-0313. Makes `sanitize.sh` (ADR-0261) two-mode.

## Context

`doc/sop.md` §7 said it plainly and said it for a long time:

> The concurrency construct's real oracle is TSan: it found the runtime's
> global handle list being unlinked by two threads on the *first run of the
> first program that spawned two tasks*, and then the string arena's cursor —
> and neither is a defect any golden could hold, both orders producing the same
> output nearly always. **It was run by hand.**

CLAUDE.md carried the instruction in as many words — *run it by hand over every
concurrent program when a task changes* — which is a procedure nobody executes
on a Tuesday. Two increments then widened what it was being asked to watch and
neither armed it: ADR-0312's reference-counted task record, whose join is
claimed under a mutex so that `wait` and the block's own join call
`pthread_join` exactly once, and ADR-0313's select-statement, whose correctness
is stated as an invariant about two mutexes never being held together.

The last hand run was 2026-09-03: eight programs, three runs each, all clean.
Nothing made that happen again.

## Decision

**A mode of `sanitize.sh`, not a second script.** `SANITIZE_MODE=thread`
selects `-fsanitize=thread` and the concurrent corpus; the default is
unchanged. `thread-sanitizer` is the ctest case.

Three things decided it.

**ASan and TSan cannot be combined** — clang refuses the pair — so this is a
second invocation rather than a longer flag list, and that settles it as a
mode rather than an extra checker in the existing sweep.

**The 120 lines it reuses are the ones that took the defects out.** That script
translates a case's `.components` in §6.13 order, supplies `.importpath` and
`.importenv`, reads `.opt`, and hands the objects to the link. Getting that
wrong once left 47 cases — the whole of `lib/` and `lib/dialect/` — silently
unlinked and counted as skips. A copy of that logic is a copy free to drift,
which is the argument this repository makes about `verify/lowering.py` and
about `WriteTypeName`, one harness over.

**The corpus selects itself.** A source qualifies by writing `spawn`, `channel`
or `task`, not by being on a list, so a concurrent program added tomorrow is
swept without this gate being edited — `target-layout`'s arrangement for a
target, and for the same reason. Eleven qualify today and all eleven are clean.

## Consequences

**It has teeth, measured rather than assumed.** Unlocking the store in
`pas_chan_send` — moving `pthread_mutex_unlock` above the `memcpy` — flags
**five of the eleven**, naming `pas_chan_receive` and `__tsan_memcpy`.

**And it found a gap in the corpus rather than in the runtime.** A second
mutation, `pas_select_turn++` outside the activity mutex, flags **nothing**.
That is not the gate failing: it says the corpus contends on `select` less than
`tests/dialect/select_contended.pas`'s name suggests, and the row in
`doc/sop.md` §7 now records it. A program that puts two threads into
`pas_select` at once is what would close it, and nobody has written one.

**The floor is per mode and both exist for one reason.** 100 for the address
sweep, 8 for the thread sweep — a run that reaches nothing prints the same
tally as a clean one, which is the failure this whole register is about. The
thread floor counts `clean + known`, so cataloguing a finding cannot lower the
denominator past the floor.

**A skip is told from a failure before anything is built.** The probe compiles
a C `main` with the checker's flags and exits 77 if that fails. Without it a
clang without compiler-rt reports every case as unbuilt — 500 of them, for one
reason, printed once — which is how this harness failed the first time it met
`debian:trixie`.

**The pattern the gate matches is TSan's own and not the other three's.**
ThreadSanitizer writes `WARNING: ThreadSanitizer: data race` with no
`==pid==ERROR:` in front, so the address mode's pattern finds nothing in a
racy program and reports it clean. The two are written separately rather than
one wider pattern being invented to catch both — a pattern that happens to work
is what this register exists to refuse.

## What this does not do

**It runs in CI, and that is deliberately not left for later.** The case skips
where clang cannot link `-fsanitize=thread`, and a gate landing with a
`*_REQUIRE` nobody sets is the shape this repository has shipped twice —
`fpc-differential`, and `target32` yesterday. So the `sanitizers` job gained a
step in the same commit, and it refuses a skip the way that job's first step
already does. It also runs in every developer's `ctest`, which the hand
procedure did not.

**It does not make the corpus concurrent enough.** Eleven programs is what
exists; the gate reports the eleven and the mutation above says where they are
thin. A gate cannot write the programs it sweeps.

**It does not check AP 6.7.8.2's transitivity**, which is the other half of the
row above it in the register and is about what a task may *name* rather than
about a race.

**It does not slow the suite much.** Six seconds against the address sweep's
seventy: eleven programs rather than five hundred, which is the whole reason
the corpus is filtered rather than swept twice.

## Alternatives rejected

**A fourth checker in the existing pass.** Impossible: clang refuses
`-fsanitize=address,thread`.

**A separate `tsan.sh`.** Seventy lines of new script and a second copy of the
component-linking, which is the part with the history.

**Sweep every program under TSan.** Minutes of runtime to ask nothing: a
single-threaded program has no race to find, and a gate that takes long enough
is a gate people stop running.

**Keep it a hand procedure and write it down more loudly.** It was written down
in two files, in the imperative, and was not run between 2026-09-03 and today.
