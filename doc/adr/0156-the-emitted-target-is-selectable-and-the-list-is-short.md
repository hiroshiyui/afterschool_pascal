# ADR-0156: The emitted target is selectable, and the list is deliberately short

Date: 2026-08-22

## Status

Accepted. Item 2 of `doc/roadmap.md`'s cross-platform chapter, and it turned out
to be a smaller feature than the chapter expected, for a reason worth writing
down.

## Context

The emitted module opens with two lines — a `target datalayout` and a
`target triple` — and ADR-0028 put them there because leaving the datalayout
unstated let LLVM fall back to defaults the compiler's own `LlSize`/`LlAlign`
disagreed with: an i256 is 16-aligned by the stated layout and 8-aligned by the
default, and a set in a record got 16-byte moves against an 8-aligned frame.

Both lines named x86-64. ADR-0155 made the runtime build for other targets;
this makes the compiler say which one it is emitting for.

**What the chapter did not know is what those lines are worth on the ordinary
path.** `clang` overrides both with its own target's, and warns about the
triple only — measured, not assumed: a module carrying a 32-bit datalayout and
compiled with `--target=x86_64` lays its structs out the 64-bit way and says
nothing about it. So on the `tools/pascalcc` path the two lines are
**advisory**, and being *absent* was the segfault rather than being wrong.

They are not worth nothing. `llc` with no `-mtriple`, `opt`, and a person
reading the file all take the module at its word — and `llc` is a `ctest` case
here (`llc-second-backend`). A module that says x86-64 and is meant for aarch64
is a document that lies.

## Decision

**`pascalc --target=<triple>`, and it admits two.**

`x86_64-pc-linux-gnu` (the default) and `aarch64-linux-gnu`. Anything else is
refused, naming what is admitted and why.

**The shortness is the decision.** A target belongs on that list when this
compiler's hand-written layout rules have been shown to agree with LLVM's for
it — which for aarch64 means the 4501 frame sizes and field offsets ADR-0155's
chapter compared, `i256` in a record included. It does not hold for a 32-bit
target, where `LlSize` says a pointer is 8; emitting `i686-linux-gnu` would
produce a module whose header and whose contents disagree. Refusing it is the
same move the rest of this compiler makes — refusal by construction beats an
enumerated list of what is forbidden — and it keeps `--target=` from becoming a
promise the layout rules cannot keep.

Both spellings of aarch64 are accepted, `aarch64-linux-gnu` being the Debian
package and the cross compiler's prefix and `aarch64-unknown-linux-gnu` being
what clang normalises it to. The **emitted** one is clang's, so that assembling
the module raises no `-Woverride-module`.

**`tools/pascalcc --target=` hands it to both halves** and validates neither:
`pascalc` refuses a target it has no layout for, clang refuses one it has no
toolchain for, and a wrong spelling is then reported by whichever knows why
rather than by a third opinion in the driver.

## Consequences

`pascalcc --target=aarch64-linux-gnu -c hello.pas` produces an aarch64 object
on an x86-64 machine, given the cross toolchain ADR-0155's gate already wants
installed. With `--sysroot` it links.

`selfhost/producttest.sh` gained three checks — the flag emits that target, the
default is still x86-64, and an unverified target is refused naming what is
admitted. Mutations: making `--target=` emit the host's triple anyway, and
making `TargetIndex` accept anything, each fail one of them.

### And the `-h` check could not have seen this flag

`producttest.sh` derives the flags `pascalc` accepts from `EQ(a, '-...')` in the
source and requires `-h` to mention each. `--target=` takes a **joined** value,
so it is matched by `EQ(substr(a, 1, 9), '--target=')` and that derivation found
nothing — the check that exists to notice an undocumented flag could not have
noticed this one. It now reads both forms. Removing the `--target=` line from
`Usage` fails it.

That is the third time in this repository a check has been found holding only
the half of a comparison it could see (ADR-0144, ADR-0152), and the shape is
always the same: the derivation is narrower than the thing it derives from.

### What it does not do

**It does not make the compiler run anywhere else.** A `--target=` build is
cross-compilation from x86-64; a native aarch64 compiler still needs a seed
generated for that host, which ADR-0155's measurement shows is a textual
retarget away but which nothing here automates.

**It does not widen the layout rules.** `LlSize` and `LlAlign` still say a
pointer is 8 bytes. The two-entry list is exactly the set of targets for which
that has been checked, and adding a third means comparing the offsets first —
`doc/roadmap.md`'s chapter says how.

**Nothing produced this way has been run.** The objects assemble and link;
there is still no emulator on the machine this was built on.

### Rejected: deriving the datalayout from the target rather than tabling it

LLVM knows every target's datalayout and the compiler could ask — except that it
cannot, being a Pascal program that links nothing. Shelling out is not available
to it either (ADR-0009). A table it is, and a short one is the honest kind:
every entry is a claim that the offsets were compared.
