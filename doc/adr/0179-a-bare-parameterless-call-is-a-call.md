# 179. A bare parameterless call is a call

Date: 2026-08-24

## Status

Accepted. A conformance fix to ISO/IEC 10206:1991 §6.7.3.2, and one predicate
that two sites now share.

## Context

`take(mk)`, where `mk` is a parameterless function answering a record, was
refused:

    argument 1 of 'take' is Point and needs a variable

while every neighbouring position accepted the same call. `take(mk(0))` — the
same construct with a parameter — was fine. `q := mk` copied from exactly the
address `take` would have copied from. `mk.x` selected a field of it. Only the
value parameter refused, and only when its type was structured.

§6.8.5 makes a function-designator's actual-parameter-list **optional**, so a
parameterless function written as a bare identifier *is* the function-
designator. §6.7.3.2 makes a value parameter's actual an expression. So the
program conforms and the processor refused it — a violation of §5.1 e) in the
direction that is hardest to notice, since nothing crashes and no golden can
name a program that was never written.

**It is Extended Pascal's problem alone**, and not because of a mode: ISO 7185
§6.6.2 gives a function a simple-type or a pointer-type result, so no ISO 7185
program has a structured result to pass. The compiler already refuses one with
*a function cannot return Point; use a var parameter*.

**This is a fix to a fix.** ADR-0055's comment at the same site records that
the call was missing once before and was added — "the call was missing and
that was a defect, not a restriction" — and what was added was `!is<Call>(a)`,
a test on the **node kind**. A bare parameterless call is not that node kind.
It is a `VarRef`/`nkVar` whose symbol Sema resolved to a function, because the
parser cannot tell a bare name from a variable and Sema can (ADR-0044's husk,
seen from the asking side). So the fix covered the spelling someone had in
mind and left the other one refused.

## Decision

**Ask for the construct, not the node kind.** `IsCallValue` / `isCallValue`
answers whether an expression is a function-designator however it is spelled,
and the value-parameter rule asks it.

```pascal
function IsCallValue(e: nodePtr): boolean;
begin
  if e = nil then IsCallValue := false
  else if e^.kind = nkCall then IsCallValue := true
  else if e^.kind = nkVar then
    IsCallValue := (e^.vrCall <> nil) or
                   ((e^.vrField = nil) and IsInvocable(e^.vrSym))
  else IsCallValue := false
end;
```

Three things about it are decisions rather than mechanics.

### 1. It is the sibling of `IsDesignator` and not a widening of it

`IsDesignator` answers **false** for both spellings, and that is right: it is
the question a *var* parameter asks, where there must be a variable to bind.
Making a call a designator would have let `procedure p(var x: Point)` take
`p(mk)`, which §6.7.3.3 forbids and which has nowhere to write back to. Two
questions, two predicates, and no site asks one meaning the other.

### 2. The second caller already existed, written out inline

The dereference rule got this right when it was written:

    if (e^.drBase^.kind = nkCall) or
       ((e^.drBase^.kind = nkVar) and IsInvocable(e^.drBase^.vrSym))

with a comment saying in words what this record is about — "a parameterless
function is a bare name and the parser cannot tell, so this is where it is
told". It is now `IsCallValue(e^.drBase)`, behaviour for behaviour, and the
refactor is in this change deliberately: a predicate with one caller is a
helper, and a predicate with two is the answer to a question the compiler asks
in more than one place. The mutation below is what proves the refactor changed
nothing.

### 3. A bare name of a function that *has* parameters answers yes

It is not a call — Sema has already said *'mk' needs arguments*. Answering yes
suppresses a second message about the same fault, which is ADR-0054's rule
about not reporting a consequence of a fault already reported.

## Consequences

- **The reference front end carries it**, because this is a Sema rule on the
  conformance surface and `difftest` compares the two. Same predicate, same
  two call sites, same comment.
- **CodeGen needed nothing.** `EmitAddress`'s `nkVar` arm has answered for a
  bare parameterless call since ADR-0055, and Sema had already given it a
  result slot at the point where it decided the bare name was a call. Every
  part of the mechanism was present; only permission was missing.
- **`predicate-callers` is unmoved** and this is worth saying, because the
  shape is that gate's exactly — a shared question, asked at several sites,
  got wrong at one. That gate sweeps `Assignable`'s callers for a permission
  **granted** too widely. This is a permission **withheld** too widely, which
  no gate here looks for, and no oracle could have: a refused program that
  should compile is a program nobody wrote. `doc/sop.md` §7 carries it.

## What this does not do

- **It does not fix the handle assignment**, which has the same shape and is a
  different rule. `t := make` where `make` is a parameterless `external`
  function answering a handle is refused by AP 6.4.12.2's arm, which also
  tests `kind = nkCall`. Fixing it is two halves, not one: the assignment arm
  has to reach the *symbol* through either spelling to check `linkKind`, and
  the mirror refusal — a handle-valued call standing anywhere else — lives in
  `CheckCall`, which the bare spelling never reaches, so the bare form would
  otherwise be admitted everywhere the written-out one is refused. That is a
  dialect change with its own case and its own mutation, and it is recorded in
  `doc/roadmap.md` rather than done here.
- **It does not audit the rest of the compiler for the pattern.** Every site
  testing `nkCall` was read (there are six) and the other four are CodeGen or
  `IsDesignator` itself, where the node kind is the right question.

## Mutation

Two, and they separate the predicate from its use.

- **The bare spelling dropped from `IsCallValue`** (leaving only the `vrCall`
  arm): `value_param_bare_call` is refused again with the three diagnostics it
  was written for, **and `funcderef_iso` fails** — the case that has covered
  the deref site since ADR-0056. One mutation, two cases, which is what says
  the two sites are now asking one question.
- **The value-parameter site put back to `a^.kind <> nkCall`**, the predicate
  and the deref site left alone: `value_param_bare_call` fails and
  `funcderef_iso` stays green. That is this site's own line, proved
  independently of the refactor.
