# ADR-0115: A string value parameter is converted by the callee

## Status

Accepted. Retires the deferral in
[ADR-0052](0052-binding-is-a-file-name-chosen-while-the-program-runs.md)'s "What
this does not do" — *a variable-string may not be a value parameter* — which
that record made a consequence of a missing mechanism rather than a decision.

## Context

ADR-0052 refused `procedure attach(nm: string(64))` and said why:

> a conversion needs somewhere to build the result that the caller can name

That sentence located the problem in the **caller**, and everything since has
been read against it. `doc/roadmap.md` listed the refusal among the
ISO/IEC 10206:1991 limitations, and ADR-0111 cited it as a reason the string
arena is hard to reach.

**ADR-0114 is what made the cost legible.** A standard library is mostly
functions over strings, and under this refusal every string parameter had to be
`var` or `protected`, so every actual had to be a *variable*: `StartsWith(s,
'Hello')` did not compile, and neither did `Upper(Reverse(s))`. The library
shipped with that written into its interface as a convention, and the convention
was the defect showing through.

## Decision

**The conversion happens in the callee's prologue, and the value travels as a
pointer and a length.**

The premise ADR-0052 reasoned from was wrong in one word: the conversion does
not need somewhere the *caller* can name. It needs somewhere with the
**formal's capacity**, and that is the callee's own slot for the parameter — an
ordinary frame field of the formal's type, which every value parameter already
has. So:

- **The caller passes ADR-0051's string value**: a pointer and a length, which
  `EmitString` already produces for *any* string expression — a literal, a
  variable, a `substr`, a concatenation. It builds nothing and owns nothing.
- **The callee's prologue makes §6.4.6's store** through
  `EmitStringStoreValue`, which is the same `pas_str_store_var` call that
  `s := expr` compiles to. A value parameter and an assignment therefore cannot
  disagree about §6.4.6, because they are one call.

**A string value parameter is two LLVM arguments**, and this is the fourth time
this project has reached for that shape and the same reason each time
(ADR-0030): nothing that is two words may depend on how a struct is passed. It
is *forced* here rather than chosen — an actual of a different capacity has a
different layout, so there is no single object whose address could have been
passed instead, which is exactly why the structured-value-parameter path
(a memcpy in the prologue) could not be reused. A string is `isMemory` and
deliberately **not** `isStructured`, and that distinction is what said so.

## Consequences

**It is a calling-convention change, so it lands in one place and is read in
three**: `PutParamTypes` writes the signature, `EmitUserCall` writes the
arguments, `EnterFrame` reads them. Those three already had to agree about the
procedural parameter's two words; this is the second such parameter kind, and
the count is now derived in each of them from the same predicate.

**A restricted string value parameter is still refused, for a different
reason.** §6.4.2.5 makes a restricted string's states one-to-one with the
string's, so the conversion is available to it too — what is unsettled is
whether a clause forbidding *assignment* of a restricted value permits copying
one into a parameter. That is a reading, and a lowering is the wrong place to
take one. The diagnostic says so in its own words rather than reusing the old
message, so a program meeting it is not told something that stopped being true.

**Both front ends changed.** `src/` has no code generator, so it received the
Sema half only — the refusal narrowing to restricted types. Without that
`difftest` would report every new case as a disagreement, which is ADR-0108's
standing cost and the reason a front-end change is two edits.

**`verify/` gained nothing**, and the commit carries a `Model-unchanged:`
trailer: no rule models a string store, and adding one that restated
`pas_str_store_var` would be the kind of rule ADR-0013 says dilutes "no known
gaps".

**Two goldens moved and one is worth arguing.**
`tests/extended/restricted_errors.err` takes the reworded message.
`tests/extended/binding_errors.pas` declared `procedure takes(v: string(5))`
*as an error*, and it is now legal — so that expectation is deleted while the
declaration stays, its comment rewritten to two lines so that no line number in
the golden moves. Keeping the declaration is deliberate: it is the construct
this record made legal, and a case that used to refuse it is a good place for a
reader to find that out.

**ADR-0114's convention is retired in the same change**, along with the
roadmap limitation added one commit before it. `lib/passtrings.pas` now takes
its strings by value, so `StartsWith(s, 'Hello')` and `Upper(Reverse(s))`
compile, and the library's interface no longer documents a compiler defect as a
house style.

### What this does not do

- **A bare `string` value parameter is still refused**, because `string` is a
  schema-name and needs its discriminants: a formal with no capacity has no
  slot to convert into. `protected s: string` remains how a routine accepts any
  capacity without copying, and it remains the right choice where the routine
  only reads.
- **Nothing about a *fixed*-string value parameter changes.** `packed array
  [1..8] of char` is copied rather than converted, so an actual must still have
  the same length; §6.4.5 d)'s compatibility does not pad a copy.
  `tests/extended/binding_errors.pas` still pins that.
- **No `verify/` rule**, and no change to either conformance mode's lexis. It is
  a defect fix inside `--std=extended`, not a dialect feature — ISO 7185 has no
  `string` to have an opinion about.
