# ADR-0147: One linker symbol, one `external` declaration

Date: 2026-08-21

## Status

Accepted. Fixes a defect present since ADR-0121, recorded in `doc/sop.md` §7
since ADR-0128 and left there because "it belongs to the FFI rather than to the
type".

**Narrowed by
[ADR-0263](0263-one-linker-symbol-per-component-not-per-program.md).** The rule
is AP 6.7.7.11's and that clause scopes it to **one program-component**, where
this check was over the whole compilation — so a program could not bind a C
function that any module it imported happened to bind privately. What this
record was really protecting against, two `declare`s of one global in one
module, is handled at emission now, which is the only place it can arise.

## Context

ADR-0121 lets a program name a linker symbol:

```pascal
function a1(x: integer): integer; external 'abs';
function a2(y: integer): integer; external 'abs';
```

The emitter writes one `declare` per foreign heading, so that program emits

```llvm
declare i32 @abs(i32)
declare i32 @abs(i32)
```

and LLVM refuses it: *invalid redefinition of function 'abs'*. An error about a
file nobody wrote, reported at a line number in a temporary — which is the
exact shape ADR-0121's own `foreign-reserved` gate exists to prevent from the
other direction, where the collision is between a foreign name and one the
compiler emits.

### The duplicate check exists, and asks the wrong question

`NeedOne` already refuses to add a symbol whose link is one it has:

```pascal
function SameLink(a, b: symPtr): boolean;
begin
  SameLink := (a^.linkKind = b^.linkKind) and
              (a^.linkIfaceAt = b^.linkIfaceAt) and
              ...
              (a^.linkItemAt = b^.linkItemAt) and
              (a^.linkItemLen = b^.linkItemLen)
end;
```

`linkItemAt` is a **position in the string pool**, and `PoolAdd` appends
unconditionally — this compiler interns nothing. Two sources of the word `abs`
are two positions, so `SameLink` says two links, and the check never fires.
It is asking where the text was written rather than what it says.

For every other user of `NeedOne` that happens to be harmless: an imported
variable or module is needed by *the same symbol* each time, whose offsets
compare equal to themselves. Two distinct symbols sharing one link name is a
thing only a foreign declaration can produce.

## Decision

**A linker symbol may be named by one `external` declaration per
program-component, and Sema says so.**

`CheckForeignHeading` keeps the declarations this component has made and
compares by pool *text*:

```
foreign_duplicate.pas:29:1: error: the foreign name 'abs' already names 'abs1';
one linker symbol may be named by one 'external' declaration, so call that one
```

Sema rather than CodeGen, because it is a rule about what the language accepts
and CodeGen reports no user-facing errors — the contract in `CLAUDE.md`.

### Why not simply fix the emitter's duplicate check

That was the fix `doc/sop.md` §7 proposed: "key the declaration list on the
linker name rather than on the Pascal symbol". It is wrong, and the reason is
worth keeping.

Two headings on one symbol need not agree:

```pascal
function AbsInt(x: integer): integer; external 'abs';
function AbsReal(x: real): real;      external 'abs';
```

Deduplicating in the emitter keeps the first and drops the second, so the
module carries `declare i32 @abs(i32)` beside a call written
`call double @abs(double ...)`. **LLVM does not check a direct call against a
declaration under opaque pointers** — §7 has carried that since ADR-0121, and
ADR-0129 confirmed it a second time for arity — so that module assembles,
links, and is undefined behaviour with no diagnostic anywhere. The accidental
refusal would have become a silent wrong answer, which is the one trade this
repository does not make.

Refusing the second declaration outright avoids comparing the two headings at
all. That matters because a comparison would have to be **congruity**, and the
only congruity predicate here is `Congruous`, written for §6.6.3.6's procedural
parameters. Adding a caller to it would be ADR-0058's sentence a third time,
this time in the direction where leniency means undefined behaviour.

### And nothing is lost

Nothing here checks a foreign heading against the routine it names — not the
types, not the arity, not the function (`doc/sop.md` §7, twice). A second
heading on one symbol is therefore a second unchecked claim about it, and buys
nothing that calling the first one does not. The only property ADR-0121 claims
for this boundary is that it is **visible**: one directive, the foreign name
written out, greppable. One heading per symbol is that property stated exactly.

`SameLink` is left as it is. With this rule in force the only pair of distinct
symbols that could have shared a link name cannot be declared, so the
positional comparison is now sound rather than accidentally sound — refusal by
construction, which is the shape `CLAUDE.md` records for a restricted type's
arithmetic and a discriminant-selected variant.

## Consequences

`tests/dialect/foreign_duplicate.pas` is the case: two headings on `abs` with
the same signature, a third with a different one, a fourth on `ABS` — a
character-string and so **not** case-folded the way §6.1.3 folds an identifier,
therefore a different symbol — and a fifth on `labs`. Two diagnostics, and the
last two headings are accepted.

The mutation is `prior := nil` in place of the lookup: it produces a working
compiler with the defect back in it, and `foreign_duplicate` is what fails,
carrying `clang`'s *invalid redefinition of function 'abs'* into the diff.

The conformance modes are untouched. `--std=extended` refuses the `external`
directive itself before `CheckForeignHeading` is reached, so the message a
conforming program sees is the one ADR-0121 gave it and `src/` needs nothing;
difftest is unaffected, and skips the dialect case in any event.

### What it does not do

It does not make the boundary type-safe, and nothing here can — the callee is a
symbol in an archive. It removes one way of writing a program that could not
work, and it does so with a diagnostic instead of an error about a temporary
file.

It is also **per program-component**. Two modules may each declare `external
'strerror'`; they are translated separately, emit one `declare` each in
separate modules, and the linker resolves both to one symbol. That is §6.13
working, and no rule here needs to say anything about it.
