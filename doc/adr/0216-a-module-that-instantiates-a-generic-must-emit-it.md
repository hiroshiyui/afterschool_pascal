# 216. A module that instantiates a generic must emit it

Date: 2026-08-27

## Status

Accepted.

## Context

Found while starting the JSON module. `PasJson` wants a growable byte buffer
and `lib/dialect/pascontainer.pas` has one, so the first thing written was a
module that imports `PasContainer` and instantiates `Vec(char)`. It did not
link:

```
undefined reference to `@p10'
```

`@p10` is a name no source spells. The component **translated cleanly**; what
failed was `clang`, one command later, assembling the `.ll` the compiler had
just written.

**ADR-0212 established this clause for a program.** AP 6.7.3.10 makes an
instantiation belong to the translation that named the types, not to the one
that declared the generic — which is what lets a generic cross
ISO/IEC 10206:1991 §6.13 at all, since a module cannot know the types a later
program will name. `tests/dialect/generic_import.pas` is that case and has
passed since the day it landed.

**A module is such a translation too, and `RunCodeGen` had two arms.** The
whole tail of code generation splits on `progBlock = nil` — a component with no
main-program-declaration takes the first arm and a program the second — and the
loop that emits instantiation *bodies* was written only in the second. What
made it invisible is that the loop naming their **frame types** sits *above*
the branch and is shared, so the module was internally consistent: a frame
type, a call, and no body.

### Why nothing here could see it

| Oracle | What it said |
| --- | --- |
| the compiler | translation succeeded — this is not a diagnostic, and nothing in Sema or CodeGen has an opinion about a name it emitted a call to |
| `irtest.sh`, `run_test.sh` | green — no component in the corpus imported a generic and instantiated it |
| `difftest` | not asked: `src/` has no dialect, and generics are the dialect's |
| `line-coverage` | green — the missing statements are the ones that were never written |
| `llc-second-backend` | green — the compiler's own source has no module importing a generic |

The corpus had a program importing a generic (`generic_import`) and a module
*declaring* one (`genericmod.pas`), and no module importing one. Two features
that had each been exercised, in the one combination nothing wrote.

## Decision

**Emit AP 6.7.3.10's instantiation bodies in the module-only arm as well.**
Five lines, the same loop the program arm runs, placed before `EmitOwnRels` for
the reason that arm's comment already gives: a function definition cannot be
nested inside the one that calls it.

The rule stated positively: **an instantiation is emitted by whichever
translation named the types, and "translation" means a component, not a
program.** §6.13 makes those the same kind of thing and this is the second
place that has had to be said — ADR-0212 said it about tokens, this says it
about bodies.

## Consequences

**`tests/dialect/generic_module.pas` and its component are the case**, and the
component is what carries the whole of it: the program calls two ordinary
routines and knows nothing about generics. `components/genericwrap.pas` imports
`GenericMod`, instantiates `Swap(integer, …)` in a procedure body and declares
a local `Pair(integer)`. Reverting the five lines fails it, and fails nothing
else in 801 cases.

**A library may now wrap a generic**, which is what makes
`lib/dialect/pascontainer.pas` reusable *inside* the library rather than only
by programs. Every dialect module that wants a growable buffer had this in its
way and none had met it, `PasContainer` being one day old.

**The failure mode is the one worth remembering.** A compiler defect that
produces an invalid module is loud — LLVM's parser rejects it and names the
line. This produced a *valid* module that was merely incomplete, so the
compiler, the assembler and the corpus all passed it and the linker complained
about a symbol whose name is a counter. `doc/sop.md` §7 gains a row: **nothing
here links a component on its own and checks the result**; what catches this is
a case with a `.components` sidecar, and only for the combination that case
writes.

**Cost.** Five lines and one comment; no interface, no diagnostic, no clause.
It is a defect in the implementation of AP 6.7.3.10 rather than a change to it,
so the specification is untouched.

**What was rejected.** *Hoisting the loop above the branch, beside the frame
types* — it reads as tidier and is wrong: the program arm emits bodies after
`EmitProcs(progBlock)`, and a definition emitted before the module's own
functions would be a definition inside `@main`'s neighbourhood rather than
after it. The two arms genuinely differ in where the loop belongs, which is why
the shared loop above emits *types* and not bodies.
