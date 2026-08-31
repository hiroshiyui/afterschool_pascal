# 283. A parameter that could say it is read-only

Date: 2026-09-01

## Status

Accepted, 2026-09-01.

## Context

ADR-0272 listed four warnings. Three are built — an unused local, a statement
after one that leaves (ADR-0277), a result written on one path (ADR-0278) — and
the fourth was measured in ADR-0278's sitting and **not** built, with the reason
recorded:

> It is not built because **the fix is not always legal and no component can
> tell**. §6.6.3.6's congruity compares the formal-parameter-lists, `protected`
> included, so a procedure passed as a procedural parameter cannot take the word
> […] The sound version warns only for a routine that is neither exported nor
> passed as a procedural actual anywhere in the component, which needs the
> warnings deferred to the end of a compilation rather than written where they
> are found. That is a change to ADR-0272's discipline and wants a record of its
> own.

This is that record.

**The advice is exact and not a guess**, which is what makes it worth giving.
§6.7.3.1 spells a variable parameter a body never writes through `protected
var`; §6.5.1 forbids a statement to threaten a variable-access
closest-containing a protected variable-identifier; §6.9.4 lists the six ways
to threaten one; and `wasThreatened` is already set at every one of those six
sites and nowhere else (ADR-0089, ADR-0134). So **`not wasThreatened` is
precisely the condition under which adding the word still compiles** — not a
reading of what a body appears to do. The compiler owned the whole analysis
already and had never been asked the question.

## Decision

A fourth warning, and **the first whose answer is a property of the component
rather than of the routine**.

`NoteUnwrittenVarParams` records a candidate where `CheckProcBody` finishes a
body: a parameter that is `skVarParam`, not already `isProtected`, never
threatened, and whose type `Protectable` admits — §6.4.1 refusing a file or a
pointer, so without that last test the warning would advise something the
compiler rejects. `WarnUnwrittenVarParams` judges them after
`CheckMutualSupply`, which is the last thing `RunSema` does, and it is called
**outside** the branch that tests for a main-program-block, because a component
with none records candidates exactly as one with a block does.

Two guards need the whole component and are the reason for the deferral:

- **Passed as a procedural actual.** `passedAsProc` is set where a routine is
  bound to a procedural or functional formal. The call may be written after the
  routine — `tests/dialect/protected_hint.pas` writes it 20 lines later on
  purpose — so at the moment the body is checked, nothing knows.
- **Exported.** §6.11.1 makes the export-part the interface, so whether some
  importer passes it that way is a question this component cannot answer at
  all. An exported routine is never advised.

The report is **sorted by declaration position**, because candidates arrive in
the order bodies are checked and a nested routine's body is checked before the
block that declares it. Deferred warnings are written after the per-site ones;
that is what deferring costs, and a whole-component answer cannot be
interleaved with answers given a block at a time.

### The finding: it is a fixed point and not a list

The measurement everyone would take is the one ADR-0278 took — run it once and
count. That number is **130** sites over the tracked corpus with no guards, and
**110** with them.

It is the wrong number, and the reason is the clause. §6.9.4 counts passing a
variable as an actual **variable parameter** as a threat — but §6.5.1 exempts a
*protected* formal, so `apfront.pas`'s own actual-parameter check asks
`not p^.sym^.isProtected` before recording one. **Protecting a parameter
therefore stops its callers' arguments from being threatened**, and the next
layer of callers becomes visible. Adding the word to the first 11 sites took
the count *up*, 58 to 91.

Iterating to convergence took seven rounds: **54 parameters gained `protected`
across the compiler, the library and the server, and the tree now reports
zero.** Three of those were groups like `var l, r, v: str` where two names are
inputs and one is the output, split into `protected var l, r: str; var v: str`
— which is the warning doing the thing it exists for, since the group had been
saying that all three were writable and only one was.

**Every round rebuilt clean.** That is the strongest evidence the analysis is
right: `protected` is enforced by the compiler, so a wrong claim is a
compilation error rather than a wrong warning, and 54 of them were accepted.

### What it costs

47 warnings remain in `tests/`, over 23 cases, each of which gains a `.warn`
sidecar rather than a fix — a corpus program with a read-only `var` parameter
is usually pinning something else, and editing 23 fixtures to quiet a new
warning would change what they pin. That is ADR-0277's precedent at eight times
the scale, and it is the honest price of ADR-0272's rule that a case without a
sidecar must produce none.

## Consequences

- **A warning may now be deferred**, which ADR-0272's discipline did not
  provide for. The mechanism is a list of *symbols* and not of formatted text:
  the message is generated at emission, so nothing is buffered and the fixed
  arrays of ADR-0012 are untouched.
- **A new guard on this warning is cheap and a new deferred warning is not.**
  The list, the sort and the emission point are general; what is specific is
  that these two guards happen to be answerable from `interfaces` and one
  boolean. A warning needing, say, every call site would need more.
- **`protected` is now load-bearing in this tree**, on 54 parameters where it
  was on far fewer. A future change that writes through one of them is a
  compilation error naming the clause, which is the point — but it will look
  like an unrelated refusal to someone who did not expect the word to be there.
- **The corpus grew 23 `.warn` sidecars.** A case added later with a read-only
  `var` parameter will fail until it gains one, which is the rule working and
  will still be surprising.
- **`tests/dialect/protected_hint.pas` is the client**, in ADR-0116's sense and
  in lifecycle step 3a's: ten routines, each a position the construct can be
  wrong in, and most of them refusals. Two mutations were killed by it — the
  whole-component guard replaced by `true` named `Passed` alone, and dropping
  `wasThreatened` named exactly the four written-through shapes, one per §6.9.4
  entry.

## Alternatives rejected

**Emit where the candidate is found and accept the unsound advice.** This is
what a linter outside the compiler would do, and it would have advised
`protected` on 20 routines where the word makes the program stop compiling. A
warning that is wrong one time in six is one people turn off.

**Defer every warning and sort them all together**, so the output is in source
order throughout. It needs the message text buffered rather than the symbol,
which is a fixed array in a compiler whose arrays are sized for its own source
(ADR-0012), for a gain that is cosmetic. The order within the deferred group is
the source's, which is what a reader scanning for a line number needs.

**Warn only where the fix is *certainly* legal — a routine neither exported,
nor passed, nor called at all.** Strictly sounder and it advises almost
nothing: every one of the 54 is called.

**Take the 130 as the answer and stop.** The number is real and describes a
tree nobody has fixed. The cascade means a one-shot count under-reports by a
factor of five, and reporting it would have been the third time this project
quoted a figure that described a configuration nobody was in (ADR-0281).
