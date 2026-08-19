# 134. The register, read end to end

Date: 2026-08-19

## Status

Accepted. Completes work left by ADR-0047, ADR-0050, ADR-0053, ADR-0055,
ADR-0112, ADR-0128 and ADR-0133.

## Context

`doc/implementation-defined.md` is where this project keeps what it does not
do: §3 the errors it leaves unreported, §6 the programs it refuses that the
standards admit, and §6.1 the programs it accepts that ISO 7185 requires it to
reject. `doc/sop.md` §7 is the same register for what no oracle here checks.
Every entry was written by the change that created it, and each was true when
written.

Nothing had ever read the whole register back and asked which entries were
still *necessary*. ADR-0077 did that for Annex D and found six errors answered
with a value; this is the same pass over the rest, and it found seven entries
of which **five were doing no work** — the reason each gave had either expired,
been about the wrong thing, or been the cost of a mechanism that had since been
built for something else.

Three things made it worth doing now rather than as seven separate changes.
ADR-0133 had just removed the `DynamicExtent` mistake that was blocking two of
them. The standards are readable — they are on this machine, gitignored, and
two of the entries turned out to rest on a paraphrase rather than on the
clause. And the entries are not independent: two of them are the same sentence
of §6.2.3.8 b) reaching two containers.

## Decision

Seven entries, each taken to its end. Five are now closed and two are
narrowed; none was closed by deciding it did not matter.

### 1. §6.7.2 — a result variable nothing writes to

A function without a result-variable-specification that never assigns its
result was refused. One *with* one was not: `function f = r: integer; begin
end` compiled, and returned whatever the slot held.

ADR-0055 knew, and gave the reason: §6.7.2 asks for "at least one statement
threatening" the result variable, and §6.9.4's *threatens* is weaker than
*assigns* — a `read` into it counts, and so does passing it to a `var`
parameter — so the assignment flag could not answer.

**The weaker word already had a walker.** `Threatened` is called at every one
of §6.9.4's six sites and nowhere else, so the flag is set *there* rather than
at the six call sites, and it is set unconditionally: what is recorded is that
the variable was threatened, not whether the threat was allowed. Two halves of
one sentence, two flags, and the second was six lines.

### 2. §6.4.3.3 — the region at a constant occurrence

The last program this compiler accepted that ISO 7185 requires it to reject,
and the whole of §6.1.

ADR-0112 enforced the record region at every occurrence of a *type-name*
inside a record — a field's own denoter, an array's index-type and
component-type, a set's base-type, a file's component-type, a pointer's domain
and a schema-name. A **constant** occurrence was not asked, because those go
through the expression checker rather than through type-denoter resolution.

`FieldOfOpenRecord` answers for any spelling and needed nothing added; the
question is asked in `CheckExpr`'s variable case, before the lookup, for the
reason the three type occurrences ask before theirs.

**`inSchemaBody` is what makes it exact rather than approximately right.** A
production written inside a record — `a: vec(2)` — re-resolves the schema's
*body*, and that body is lexically outside the record, so a constant name in it
is in no region of this one. The actual-discriminant-part is not in the body
and is still asked, which is the half that matters.

**One message became two-with-one-noun** rather than a second procedure, for
ADR-0112's reason: four occurrences that cannot drift into saying it four ways.
And `EvalOrdinal` now clears `constReported` *before* checking the expression
rather than after, so "the bounds of a subrange must be ordinal constants"
after "'fred' is a field of this record type" is not the same mistake said
again and vaguely.

### 3. §6.4.3.6 — a file longer than its index-type

An eleventh component written to a `file [1..10] of T`. ADR-0050 recorded the
cost: a check per component written.

That is what it costs and no more, because only one thing grows a file's
length. The check is in `put` and nowhere else: `update` overwrites in place,
and a seek is already refused past the end — so seeking to the append position
of a full file stays legal right up until something is written there.

**The capacity travels as a `pas_file_init` argument and not as a flag.**
`direct` stays a flag; a capacity of zero means there is no bound worth
carrying, which is what an index-type spanning maxint values or more gets.
The arithmetic that decides that is the one `ResolveArray` already makes about
an array's index, written the same way round so neither subtraction can leave
the integer type. `struct pas_file` grew a field and stayed 112 bytes — it fit
in existing padding — so `PAS_FILE_SIZE` and `fileSize` are untouched.

### 4. §6.4.9 — a type-inquiry naming another list's parameter

ADR-0047 stated this one as "refusing that needs a distinction between a
parameter-list region and a block region that this compiler does not keep". It
does not: what it needs is one variable.

The clause is precise, and reading it settled a doubt a paraphrase had left:

> A parameter-identifier in a type-inquiry-object shall have its defining-point
> in a value-parameter-specification or variable-parameter-specification in the
> formal-parameter-list closest-containing the type-inquiry-object.

**What makes that a rule about where the inquiry is written** — rather than a
ban on naming an outer parameter at all — is §6.7.3.1: an identifier in a
value- or variable-parameter-specification gets **two** defining-points, one as
a *parameter-identifier* for the formal-parameter-list and one as the
associated *variable-identifier* for the block. So inside a
formal-parameter-list the name is a parameter-identifier and this applies;
inside the block it is a variable-identifier, which is §6.4.9's other
alternative. That is why the clause's own example —
`procedure p(var a: VVector); var b: type of a;` — is legal, and it is the
thing a reading that stopped at §6.4.9 would have got wrong.

`BuildFormals` already recurses for a procedural parameter's own list, so
saving and restoring one symbol across the call *is* "closest-containing":
inside `procedure q(x: type of k)` it names q. The other half of the sentence —
"value- or variable-parameter-specification" — was already enforced, because
`IsVariable` excludes a procedural parameter and the existing message says so.

### 5 and 6. §6.2.3.8 b) reaching a record and a file

Two entries of §6 and one sentence of the standard. A record is no kind of
block, so a subrange-bound written inside a record's denoter is still
closest-contained by the block the declaration is in; the same is true of a
file's.

ADR-0133 refused both and gave a reason about the *shape of the withdrawal*:
it is made at the container, so admitting a subrange there would admit an array
with it, and `record f: array [1..m] of integer end` is a genuine problem about
storage the activation does not size. That reason was correct and it was not a
wall — **it names the check rather than the obstacle**.

The offer now passes through a record and a file, and what is refused is the
consequence rather than the position: a field or a component whose *size* the
bound decides. The test is `DynamicExtent`, which a subrange answers no to
since ADR-0133 and an array answers yes to, asked where the storage is laid
out — in `AddField`, which covers a variant arm's fields by the same call, and
in `ResolveFile`.

**This was measured rather than assumed, and the measurement is the reason the
check exists.** Passing the offer through with no check compiles
`record a: array [1..m] of integer; g: integer end` and *silently
miscompiles* it — `v.a[1]` read 99140726979296144 where 1 was stored, which is
ADR-0045's "a field after a dynamically sized one sits at an offset nothing can
compute" happening. That is the trade ADR-0127 faced and refused, and the
check is what makes taking it sound.

**A set stays refused**, and this is the one entry narrowed rather than closed.
Every set here is one 256-bit word whose base type must have its values in
0..255 (ADR-0028), and a bound the block evaluates cannot be checked against
that before the program runs. It is the same limit `set of integer` already
states, reached by a different route.

### 7. §6.9.1 — `read` of an `int64`

ADR-0128's one asymmetry: `write` took the type from the day it landed and
`read` did not, because §6.9.1's longest-prefix rule "is runtime work this
increment did not do".

The work turned out to be a bound. The clause is the same sentence at both
widths — c) and d) take the longest prefix that *is* a number, the sign is the
sign, and the give-back is the two characters `struct pas_file` already
carries — so `wide` selects the limit rather than a second copy of the loop
selecting everything.

**The overflow moved from after the accumulation to during it**, which is not
tidying: `value * 10` would already have wrapped at the wider width, so the
check as written could not have been extended. It now compares against
`limit / 10` and the boundary digit, and the narrow width gets the same
treatment — the same rule, one number apart.

## Consequences

**Four programs that compiled no longer do**, and each returned or read
something wrong: a function that never wrote its result variable, a record
whose array bound named one of its own fields, a type-inquiry naming another
list's parameter, and a program writing past a direct-access file's index-type
(that last one is a run-time error rather than a refusal). They are in
`CHANGELOG.md`.

**Four that did not compile now do**: `var x: 1..m` as a record's field, the
same as a file's component, `read` of an `int64`, and the empty half of
nothing — the fourth is the subrange field and component counted once each.

**§6.1 is empty.** There is no longer a program this compiler is known to
accept that ISO 7185 requires it to reject. That is a claim about what is
*known*, and the section says so: it was one entry until this change and it was
found by reading, not by any oracle here.

**`doc/implementation-defined.md` §3 loses three entries** — §6.4.3.6's file
length, §6.7.2's result variable and §6.4.9's parameter-identifier — **§6 loses
one and narrows another**, and §6.1 is empty. `doc/sop.md` §7 loses the row
ADR-0133 narrowed.

**The BSI catalogue did not move.** Its DEVIANCE category has no program left
that this compiler wrongly accepts — the one entry §6.1 carried was found by
ADR-0101's independent reading — so `expected.tsv` is unchanged and the gate
saying so is the evidence.

**No lowering rule changed.** The file capacity check is in the runtime and the
`read` widening reuses an existing return type; nothing CodeGen emits is
modelled differently. The commit carries `Model-unchanged:`.

**`src/` carries the four Sema halves** — the result variable, the record
region at a constant, §6.4.9's closest-containing list, and the record/file
withdrawal with its `dynamicExtent` refusal. `int64` is a dialect type that the
reference front end does not have, so `read` of one has nothing to mirror.

### What this does not do

**§6.11.3's constituent-identifier region is still not enforced as a region**,
and this is now a precise statement rather than a vague one. §6.11.3 a) gives a
constituent-identifier's defining-point "each region that is a
constituent-identifier contained by the import-specification" — a region as
narrow as the occurrence itself — where this compiler makes the interface's
names reachable across the import-specification while it is being checked.

**No program distinguishes the two.** Every observable rule around it was
probed and holds: `only` imports exactly what it names, a renaming introduces
the new spelling and not the old, the interface's own name of the renamed
spelling is not imported, and `qualified` makes the long form the only form
(§6.11.3 NOTE 2). What is unenforced is a scope the standard draws more tightly
than the implementation does, with nothing behind it that a program can see.
It stays in §3 with those words.

**The remaining §3 entries are the definedness ones**, and they share one
cause: nothing here tracks whether a variable has been assigned at run time.
Annex D names it in thirteen of its fifty-nine entries and five of those ask
about a *file*, which the runtime does carry. The other eight need a mechanism
this compiler does not have, and inventing one is a feature and not a fix.

**A set of a dynamically bounded subrange stays refused**, above.

## Alternatives rejected

**Take the seven as seven changes.** Two of them are the same sentence of
§6.2.3.8 b) and would have had two records disagreeing about which container
was the hard one; the `read` widening and the file capacity are both "the
entry named the cost and the cost was one number". A sweep is what ADR-0077
was, and the register is what it swept.

**Refuse a type-inquiry naming an outer parameter anywhere**, which is what
§6.4.9 says if you stop reading at §6.4.9. It refuses the clause's own example.
The two defining-points in §6.7.3.1 are the whole of why, and finding them is
the reason this entry took reading rather than probing.

**Keep the record field refused and record the reason better.** Tempting,
because the first attempt at admitting it silently miscompiled a program. But
what that attempt showed is exactly where the check belongs, and a register
entry whose reason is "we tried it and something broke" without saying what is
the kind of entry this pass exists to remove.

**Give `pas_file_init` a capacity by overloading `direct`.** One field fewer,
and `direct` would then mean two things — a flag and a bound — with zero
ambiguous between "sequential" and "unbounded". The struct had eight bytes of
slack and the new field used none of them.
