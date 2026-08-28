# ADR-0119: The program-components of one program agree on the mode

## Status

Accepted, and narrowed by
[ADR-0232](0232-afterschool-pascal-is-the-language.md). A module's activation
names still carry a tag and the tag still keeps ADR-0118's pair of rules
together across separately translated components; there is one value now,
`afterschool`, so what a mismatch reports is an object from an older release
rather than a mode disagreement.

## Context

ADR-0118 says the dialect's variant tag cannot lie, and makes it true with two
rules:

1. assigning to a field of a variant makes that variant active — the tag is
   stored as part of the assignment;
2. reading a field of a variant that is not active traps.

Both are emitted **at the access**, by `EmitVariantGuard` inside the path walk
`FieldAddress` already does. That is the right place for each of them
separately. It also means each belongs to whichever program-component contains
the access — and §6.13 lets a program have several, translated at different
times, with nothing until now requiring them to have been translated the same
way.

So the two rules could be split. Four builds of one pair of files, measured
rather than reasoned about:

| module `--std=` | program `--std=` | module reads an inactive field | program reads one |
| --- | --- | --- | --- |
| extended | extended | `4` | `4` |
| afterschool | afterschool | **traps** | — |
| **afterschool** | **extended** | **`4` — the guard ran and passed** | `4` |
| extended | afterschool | `4` | **traps** |

Rows 1 and 2 are the documented behaviour of each mode. Row 4 is unsurprising
and harmless: an Extended Pascal component behaves as Extended Pascal, which is
exactly what ADR-0117's containment promises, and the dialect component's own
accesses are still checked.

**Row 3 is the defect.** The dialect module's guard was emitted, ran, read the
tag, and permitted the access — because the *write* that should have set the
tag happened in a component that does not store tags. The check consulted a
field nothing maintains and reported a wrong read as a right one.

### Why that is worse than having no check

Every other unchecked thing in this compiler is unchecked *visibly*.
§6.5.3.3's error is listed in `doc/implementation-defined.md` §3 as one this
processor does not report, and a reader who wants the guarantee turns it on
with `--std=afterschool`. Row 3 breaks that: the flag is on, the check is
compiled in, and the answer is wrong in the safe direction. A safety feature
that reports `safe` for an unsafe access is the one outcome ADR-0118's claim
cannot survive, because it converts a known gap into a false assurance.

It is also not a case a user would suspect. Nothing about `--std` reads like a
property that has to match across a link; it reads like a property of a source,
which is exactly what ADR-0033 established it to be for the two conformance
modes and what remains true of parsing.

## Decision

**The program-components of one program shall have been translated under the
same `--std`, and a mixture shall not link.**

The mechanism is one line of naming rather than a new channel. §6.13 already
requires the components to agree on the *names* of a module's two activation
functions, because the component holding the main-program-declaration calls
them and may be another translation. The mode joins that name:

    @m.parts.extended.init          a module translated under --std=extended
    @m.parts.afterschool.init       …and under --std=afterschool

`PutModulePart` writes it, from `langStd` — so the definer spells its own mode
and the caller spells its own, and a program calls this symbol for every module
it activates (`activeModules`, ADR-0053). A mixture therefore leaves an
undefined symbol and never reaches an executable.

**Two spellings and not three.** What the name has to separate is the dialect
from the conformance modes, because it is ADR-0118's pair of rules that a
mixture splits and only `--std=afterschool` has them; mixing the two
conformance modes could not split a pair. `--std=iso7185` cannot arise here in
any case, §6.11's module being an Extended Pascal feature. Spelling it as a
third value would have been a statement about a translation that cannot happen,
and — since nothing could reach it — a line no case could run, which
`line-coverage` reported as soon as the first draft had one.

**Nothing can lie about it.** The name comes from the translation that is
happening, not from an option, a sidecar or a claim in the source. That is the
property a `.std` sidecar beside the module would not have had, and it is why
the alternative below was rejected.

`tools/pascalcc` translates the resulting link error, which names the mode the
*program* wanted and not the one the object has:

```
pascalcc: error: module 'parts' was translated under a different --std
pascalcc: this program is --std=afterschool, so every component it links must be
pascalcc: too. ...
pascalcc: rebuild 'parts' with --std=afterschool, or this program without it.
```

The linker's own output is passed through first and the exit status is still a
failure: only the diagnosis is added.

## Alternatives rejected

- **Refuse the mixture in the compiler, from a `.std` sidecar beside the
  imported source.** It would give a `file:line:col:` diagnostic, which is
  better than a link error. But `--import` is handed a *source* and the mode is
  a property of a *translation*, so the sidecar would be a claim about how the
  object was built, maintained by hand, and wrong exactly when it matters. A
  check that can be satisfied by editing a file that nothing else reads is not
  a check.
- **Encode the mode in every cross-component symbol**, not just the two
  activation functions. No more safety: the program calls `init` for every
  module it activates, so one symbol already makes the mixture unlinkable.
  More surface to keep in step, and `FrameGlobal` and `PutModulePart` would
  then have to agree about a spelling — a second copy free to drift.
- **Make the guard defensive instead — trap when the tag is out of range.**
  Does not help. In row 3 the tag was a perfectly good value; it was simply the
  wrong one, because the write that should have changed it was compiled by a
  component that does not.
- **Allow row 4 and refuse only row 3.** The asymmetry is real — row 4 is
  harmless — but the rule "components agree on the mode" is one sentence and
  the rule "a dialect component may not read a variant written by a
  conformance-mode one" is not checkable at a link. A refusal a user can
  predict is worth more than the mixture it costs, and no program in this tree
  wants one.

## Consequences

- **The conformance modes are unaffected in what they accept.** An
  all-`--std=extended` program links exactly as before; only the symbol's
  spelling changed, and every component of one program changes with it.
- **A stale object now fails loudly instead of quietly.** Rebuilding half a
  program after changing `--std` used to link and misbehave; it now refuses.
- **`lib/` is unaffected today and constrained tomorrow.** Every module in it
  is Extended Pascal and every case that imports one is too. What this decides
  is the *next* question: a library cannot be a dialect layer under
  conformance-mode callers, so if a dialect library is wanted it is dialect all
  the way down — separate modules, dialect callers — rather than a mixed stack.
  That is the decision ADR-0118 parked, and this record does not take it; it
  removes the option that would have been unsafe.
- **`tests/checks/mixed_mode_link.sh` is the case**, and it is a `ctest` case
  rather than a `tests/` one because `run_test.sh` compiles every component of
  a case with a single `--std` — deliberately, the standard being a property of
  the source — so a mixture cannot be expressed there at all. It checks all
  four rows and fails in both directions.
- **The refusal has no `.err` golden and cannot have one.** It is not a
  compiler diagnostic: nothing is wrong with either source, and neither
  translation fails. The failure is a property of the pair, and the linker is
  the first thing that sees both.
- **`verify/` gets no rule.** There is no lowering here — the change is a
  symbol's spelling — and a rule asserting that a name contains a word would be
  the restatement ADR-0013 warns against.
- **difftest cannot see it**, twice over: the two components are compared only
  as standalone sources (`pascalc-s0` has no `--import`), and one of the four
  rows is a dialect translation, which ADR-0117 freezes `src/` out of. Both
  gaps are already in `doc/sop.md` §7.
