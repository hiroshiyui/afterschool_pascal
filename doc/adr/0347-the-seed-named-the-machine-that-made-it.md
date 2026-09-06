# ADR-0347: The seed named the machine that made it

Date: 2026-09-06

## Status

Accepted. Corrects `seed/refresh.sh` and `tests/checks/seed_current.sh`, adds
the `seed-portable` gate, and required a second reseed inside the v3.5.0
release. ADR-0293 is not superseded — the positions are right, and this is what
putting a path into an emitted module cost somewhere nobody looked.

## Context

ADR-0293 gave every trap its own position: `... at file:line:col` after the
message. The file name is a string constant **in the emitted module**,
`@at.file`, and it is whatever path the compiler was handed on its command
line. That is correct for a program a user compiles: they wrote the path and it
is theirs.

`seed/*.ll` is an emitted module too, and it is **committed**. `seed/refresh.sh`
translated `"$root/selfhost/$component"` — an absolute path — so the seed cut
for v3.5.0 held

```
@at.file = private unnamed_addr constant [62 x i8]
           c"/home/<user>/<...>/selfhost/compiler.pas\00"
```

in all three modules. Two things follow and the second is the serious one. The
committed artefact names the machine and the directory that produced it. And
`tests/checks/seed_current.sh` — *is the committed seed the one this source
produces?* — translated the same way, so it could only ever pass in the
directory that had reseeded. Everywhere else it reported a seed that is not
this source's.

**It was found in the tag job, which is the one place it runs.** That is not an
oversight in the job: the seed is refreshed at a release and nowhere else
(ADR-0085), so between releases it is legitimately stale and the check would
fail on every push. It cannot be a `ctest` case, and a release is therefore the
first time anybody asks. Eight releases have carried positions; this is the
first whose seed was compared anywhere but where it was made.

## Decision

**`seed/refresh.sh` and `tests/checks/seed_current.sh` both translate from the
repository root with a relative source path**, so the constant reads
`selfhost/compiler.pas` and the seed reproduces wherever the tree is checked
out. The two must go on agreeing: they are one claim, and a difference between
them is a seed that reproduces nowhere.

**The compiler is unchanged.** Making it shorten or relativise a path would
change what every user's trap message says in order to fix a property of one
committed artefact, and the path a program is compiled by is the program's
business. The scripts are the layer that owns reproducibility.

**`seed-portable` is a new `ctest` gate**: no string constant in a seed module
begins with `/`. It is a much weaker question than `seed_current.sh`'s — it says
nothing about whether the seed is *this* source's — and that is exactly why it
can run on every push. It costs a grep, and it would have caught this on the
commit that introduced the positions.

## Consequences

**A release cut before this one cannot be verified by its own gate.** The seeds
committed for v3.4.0 and earlier hold absolute paths, so
`tests/checks/seed_current.sh` run against those tags answers about the
directory. Nothing is wrong with those compilers — the seed builds and
reproduces itself, which `refresh.sh` checked at the time — but the *claim*
that a tag's seed is that tag's source was, for those tags, only ever tested on
one machine.

**The v3.5.0 tag failed its own release and that is the gate working.** No
release was published: `release`, `package` and `publish` are gated on every
oracle being green, and they were skipped. A tag that produces nothing is the
correct outcome for a seed that reproduces nowhere.

**It is the second time in one day that a check answered about the wrong
machine.** ADR-0345's `llc_check.sh` compared x86-64 modules on an ARM host;
this compared a directory. Both were harnesses passing a path or a target that
was right where they were written and wrong where they ran, and neither could
be seen from the machine that wrote them. `doc/sop.md` §7's row for a harness
that ignores what it is handed now carries a third instance and a sharper
statement of the shape.

## What this does not do

**It does not make the seed byte-reproducible in general.** It removes the one
input that was environmental. Whether two machines with different clangs would
produce identical seed IR is a separate question, and the answer is that they
should — `pascalc` emits the IR and clang only assembles it — but nothing here
asserts it.

**It does not make `seed_current.sh` a `ctest` case.** It still cannot be one,
for the reason above.

**It does not audit the other committed artefacts for machine-specific
content.** `seed/` is the only generated file this repository commits.

## Alternatives rejected

**Have the compiler emit a path relative to the current directory.** It would
fix the seed and change every trap message a user sees, and a user who compiles
`/home/me/foo.pas` should be told that. The bug is in what the seed script
passed, not in what the compiler did with it.

**Strip the path from the seed after generating it.** A post-processing step on
a 10 MB artefact, which would make the committed seed something no compiler
produces — and `seed_current.sh` would then have to apply the same edit to
compare, so the check would be verifying its own edit.

**Accept the absolute path and have `seed_current.sh` ignore `@at.file`.** It
makes the gate blind to the one line that moves, and the committed artefact
would still name a stranger's home directory.
