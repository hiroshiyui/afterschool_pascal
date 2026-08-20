# ADR-0137: A module is mode-locked by what it exports, not by the flag it was translated with

Date: 2026-08-20

## Status

Accepted. Narrows ADR-0119 without weakening it, and answers the third of the
seven open questions in `doc/roadmap.md`.

Amends AP §6.13.1 of `doc/afterschool-pascal-spec.md`, which is the first time
that document has had to change because the language did.

## Context

ADR-0117's claim is that the dialect **contains** Extended Pascal.
`tests/dialect/inherits_extended.pas` witnesses it at the source level. It did
not survive separate translation:

```
$ tools/pascalcc --std=extended -c lib/pasmath.pas -o pm.o        # fine
$ tools/pascalcc --std=afterschool use.pas --import lib/pasmath.pas pm.o
ld: undefined reference to `m.pasmath.afterschool.init'
pascalcc: error: module 'pasmath' was translated under a different --std
```

Sema accepted that program **completely** — the interface resolved and
`PasMath.IMax(3, 4)` type-checked — and it died at the link. Only the two
activation names were missing; `p.pasmath.imax` resolved, because a procedure's
linkage name carries no mode.

So the six conforming modules in `lib/` were unreachable from the dialect: the
layer ADR-0114 built so that the *conforming* language would have a library was
the layer the language that contains it could not use.

ADR-0119's reason is real and its hole is real. ADR-0118's two rules are a
**pair** — a write to a variant's field stores the tag, a read of an inactive
variant traps — and each is emitted at the access, so each belongs to whichever
program-component contains that access. Split them across components and the
surviving half runs its check against a tag the other half never stored, and
**passes** the access: a check answering `safe` for an unsafe read, which is
worse than the documented gap it replaced.

What was wrong is not the rule but its **granularity**. The mangling names the
mode, and the mode is a proxy for the ABI that is far too coarse.
`lib/pasmath.pas` contains no variant record at all, and its object code is
byte-identical under both modes.

## Decision

**A module's activation names carry the dialect's spelling as well as its own
when nothing it exports could differ between the modes.**

### 1. The question is the emitter's own, asked over the interface

The check is emitted where `TagFieldAt(t, path) >= 0` under
`--std=afterschool`. So the module-level question is whether **any type
reachable from the module's interfaces has a variant-part with a tag-field**,
and `ComputeModePortable` asks exactly that, following a field, an array
component, a file component, a pointer domain and a parameter — a value of the
type crosses at any of them.

Nothing else the dialect adds is a change to a construct ISO/IEC 10206:1991
also has. `external`, `?T`, `array of` and `int64` are new syntax, and a
conformance-mode component cannot contain any of them; a dialect module that
exports one cannot be imported by a conforming program in the first place,
because that program cannot parse the interface.

**The interface and not the module** is the right scope, and the reason is
worth stating: a variant record used only inside a module's block is one no
caller can access, so no cross-component access to it exists. Conversely,
exporting the *type* is enough to be unsafe even if no variable of it is
exported, because the program may declare one and pass it to an exported
routine that writes a field without storing a tag.

**It answers `true` when it cannot tell.** The walk is depth-bounded, an
exhausted depth meaning a cycle through a pointer domain, and a cycle must
never be what makes a module look portable.

### 2. Sema decides it; CodeGen emits an alias

`modePortable` is a field on the module symbol, set by a pass that runs where
`ComputeActiveModules` does — once the interfaces are complete. CodeGen reads
it and writes

    @m.plain.afterschool.init = alias void (), ptr @m.plain.extended.init

An alias rather than a second definition: one body, two names, and nothing for
the two to disagree about. This keeps CLAUDE.md's contract — CodeGen re-derives
no fact about the source program — and it is why the emitter side is nine
lines.

**Only the definer computes the property.** That is the whole reason this shape
was taken over the alternative `doc/roadmap.md` also offered, which was to
mangle on a fingerprint both sides compute: two computations of one predicate
can disagree, and a disagreement here is an undefined symbol at best and a
silently mismatched ABI at worst. With an alias the caller is unchanged — it
asks for its own mode's name, as it always did.

### 3. One direction only

A conformance-mode module gains the dialect's spelling. A dialect module does
**not** gain a conformance mode's.

That is ADR-0120's decision and not an oversight. A dialect module may call
`external` routines and is not a conforming program-component, so letting a
conforming program link one would put a component outside both standards into a
program that claims one. The direction that matters is the other: `lib/` is
ordinary Extended Pascal, and the language that contains Extended Pascal could
not use it.

## Consequences

- **`lib/`'s six modules are reachable from the dialect**, and none of them
  needed a change: not one has a variant-part anywhere. That was measured
  before the walk was written, and it is why the *precise* test was worth
  having over the cruder "exports no record type at all" — the cruder one would
  still have locked `PasMap` and `PasVector`, which export records without
  variants.
- **A tagless variant-part is portable**, and this falls out rather than being
  decided: `tagField` is `-1` for one, so no check is emitted against it under
  any mode (AP §6.4.3.4.5). The predicate is the emitter's own condition, so
  the two agree by construction rather than by a second opinion.
- **`tests/checks/mixed_mode_link.sh` grew from four combinations to seven**,
  and it is the only place the safety half can be checked: `tests/` compiles
  every component of a case under one `--std`, deliberately. The three new rows
  are a portable module linked by a dialect program, the same by a conforming
  one, and a *dialect* portable module refused by a conforming program.
- **A `.components` line may now name a standard**, in both `run_test.sh` and
  `selfhost/irtest.sh`. Without it no case in `tests/` could exercise this at
  all, the standard having been one per case. The two harnesses read the file
  the same way, because a case that meant two things would be worse than no
  case.
- **`tests/dialect/lib_conforming.pas` is the named case**, and the mutation
  that kills it is removing the two `PutModuleAlias` calls. A second mutation —
  claiming every module portable — kills `mixed-mode-link` alone, which is the
  safety regression and the reason that gate keeps its own copy of the question.
- **AP §6.13.1 is amended**, from "every program-component shall have been
  translated under the same `--std`" to the narrower requirement this record
  makes true. The specification is the normative statement (ADR-0135), so the
  language change is stated there and this record says why.
- **`verify/` gets no rule.** What changed is a linkage name and one alias
  directive; no arithmetic, conversion or comparison lowering moved, and a rule
  would have nothing to state that is not the emitted text. The commit carries
  `Model-unchanged:`.
- **`src/` needs nothing.** It is frozen at the conformance surface (ADR-0117)
  and has no code generator, so it emits no linkage names and difftest compares
  none.

## What this does not do

- **It does not make the containment total.** A module exporting a tagged
  variant is still mode-locked, correctly, and a dialect module is still
  unusable from a conforming program. The honest phrasing is no longer "the
  dialect contains Extended Pascal as a language and not as a linkage"; it is
  that the linkage follows the language **except where the dialect would emit a
  check the other mode does not**.
- **It does not synthesise a hidden tag** for a tagless variant-part, which is
  ADR-0118's parked question and would change a record's representation.
- **It does not let the modes mix within one component**, which is not a thing
  a translation could mean.
- **It does not check that a module's object file is what its source says.**
  Nothing here does: the alias is emitted from the translation that is
  happening, which is ADR-0119's property and is kept.

## Alternatives rejected

**Mangle on a fingerprint both sides compute**, which `doc/roadmap.md` offered
first. It is the more general answer and it puts the predicate in two places —
the definer over its own export part, the caller over the interface it
imported. Those are the same types today, and the day they are not is a link
error nobody can read. The alias needs one computation and leaves the caller
untouched.

**Drop the mode from the name and check compatibility some other way.** There
is no other channel: §6.13 gives separate translation nothing but the linker,
which is exactly why ADR-0119 used the name. Dropping it would restore the
unsafe read.

**Make the test "the module declares no variant-part anywhere."** Simpler to
compute and *unsound*: a module may re-export a type it imported, so its own
declarations do not bound what its interface exposes.

**Widen it to both directions.** Rejected in 3; it is ADR-0120's decision,
which this record has no reason to reopen.
