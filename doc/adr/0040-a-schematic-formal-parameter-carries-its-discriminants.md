# 40. A schematic formal parameter carries its discriminants beside the address

Date: 2026-08-11

## Status

Accepted. It completes the half of schemata ADR-0039 deliberately left out.

## Context

ISO/IEC 10206:1991 summarises schemata in two sentences, and ADR-0039
implemented the first. This is the second:

> A schematic formal-parameter adjusts to the bounds of its actual-parameters.

§6.7.3.1 makes it a spelling in the parameter list and nothing more —
`parameter-form = type-name | schema-name | type-inquiry` — so `var v: vector`
is a parameter whose type is decided by whatever is passed to it. §6.7.3.3 says
what that means: all the actuals corresponding to one formal-parameter-section
possess the same type produced from the schema with *a* tuple, and within the
activation the formal possesses that type.

ADR-0039's design does not reach this. There, a discriminated schema produces
an ordinary type and nothing downstream of Sema learns schemata exist —
`vector(3)` *is* `array [1..3] of real`. A schematic formal has no tuple to
produce a type from, and is compiled once for every tuple any caller may bring.
Its bounds are therefore not constants, which is the first time in this
compiler that an array's extent is not known at compile time.

## Decision

**The tuple travels with the address, as separate arguments, into one frame
slot.** A schematic formal parameter occupies a slot of type
`{ptr, d₁, ..., dₙ}` — the address of the actual, then its discriminants — and
is passed as `n + 1` arguments the callee assembles. That is exactly ADR-0030's
shape for a procedural parameter's code-and-link pair, chosen for the same
reason: nothing then depends on how a struct is passed, and a caller and a
callee can only agree because both come through one place.

**A discriminant is a symbol with storage, not a value threaded through
codegen.** `SymKind::Disc` names one field of one parameter's descriptor. Its
`owner`, `level` and `frameIndex` are the *parameter's*, so `addressOf` reaches
it by the same walk up the static chain that every enclosing variable makes —
which is what makes the tuple per-*invocation*: a nested procedure inside a
recursive one sees the descriptor of the invocation that called it.
`tests/extended/schema_param.pas` pins that case, and it is the same shape
`tests/nesting.pas` and `tests/procparam.pas` pin for their features.

**The schema body is resolved once, generically.** ADR-0039 re-resolves it per
tuple with the discriminants bound as constants; this binds them as `Disc`
symbols instead, and a bound that reaches one is recorded on the `Type` as the
symbol rather than as a number. So `array [1..n] of real` comes out as an
ordinary array type whose upper bound happens to be read at run time, and the
existing array, index and assignment code needed no case for schemata — the
same trick, one level less folded.

**A dynamic bound is a discriminant, and nothing else.** Not `n - 1`: ISO 7185
has no constant-expression — a bound is a sign and a number or an identifier,
everywhere in the language — so this is the restriction every other bound is
already under rather than one invented here. When §6.3's constant-expression
lands it lands for every bound at once, and the descriptor already holds what
such an expression would be computed from.

**Where a discriminant may appear is bounded, and diagnosed.** It may bound an
array, and an array inside that array — `dynSize` is then
`(hi − lo + 1) × dynSize(component)` at each level, and an address is
`base + (i − lo) × dynSize(component)` computed in bytes. Anywhere else it is
refused: a record field after a dynamically-bounded one would sit at an offset
nothing can compute, and a set and a file are sized once. The message says so,
because "a discriminant may bound an array" is a rule a reader can act on and
"this schema cannot be a parameter form" is not.

**A value parameter is copied on entry, into storage claimed on entry.** Its
size is not known until the tuple is in place, so the copy is an `alloca` of a
computed length rather than a frame field, made after the descriptor is
written and freed with the activation as the frame is. The two passing modes
then differ in exactly one place, and everything after it reads the same
descriptor.

**The tuple is not compared at run time.** §6.7.3.3 makes a mismatch between
two actuals of one section a *dynamic-violation*, and §6.7.3.2 says the same
for a value parameter. Every tuple this compiler can write is a constant
(ADR-0039's deferral), so the check is decidable where the call is written, and
it is made there: `pair(v, w)` with `v: vector(3)` and `w: vector(4)` is a
compile-time error. When non-constant discriminants land, this becomes a
run-time comparison of two descriptors and the diagnostic becomes a trap —
which is a change to when it is reported, not to what is reported.

## Consequences

**No proof rule was added, and the existing ones still apply.** The array
rule in `verify/` quantifies over the bounds as well as the value, so
`accepted-index-selects-the-right-element` and the bounds check it constrains
are statements about *every* pair of bounds — including a pair that arrives at
run time. That is the payoff of ADR-0013's "keep bounds symbolic where the
lowering treats them symbolically", collected here rather than argued for: a
rule with `maxint` written into it would have had to be generalised, and this
one did not have to be touched.

The one thing the rule assumes and the lowering no longer proves locally is
that a dimension spans at most `maxint` values, which is what makes `i − lo`
sound. `resolveArray` cannot check it for a dynamic bound. It does not have
to: the actual's type was produced from constants and checked when it was
produced, and only such a type can reach a schematic formal. The check and the
assumption are still the same statement — it is just made one call earlier.

**The trap message is built by the runtime.** `array index out of bounds
(1..3)` is a string constant in the generated program everywhere else; here the
bounds are the actual's, so `pas_index_error` formats it. It says the same
words, which is the point: a reader of a `.err` file should not be able to tell
which array kind trapped.

**`--dump-sema` shows the last parameter a schema was a form for.** The body
carries whatever the most recent resolution left on it, exactly as ADR-0039
described for productions, and for the same reason — one parameter-form has as
many types as it has names. Both compilers do it, which is what the
differential checks.

**Two schematic formals of one schema are never the same type.** Each owns its
own generic type because each reads its own descriptor, so `assignable` says no
to `v := w` between two formals even where the standard would allow it. That is
a real gap and it is small: the operations that matter — subscripting, `v.n`,
passing on to another schematic formal, passing to a procedural parameter — all
work, because none of them compares two generic types. Whole-variable
assignment between schematic variables waits for the tuple comparison the
paragraph above describes.

**Twenty-one mutations on the C++ side and nine on the Pascal one, all
caught** — the second set matters because a code generator that only the
golden files cover is a code generator nothing compares, and `irtest.sh` is
what runs what it built. Three are worth naming.

Two needed a test written *for* them: a value parameter whose descriptor still
points at the actual after the copy is made — caught only by a callee that
writes to its copy and a caller that then reads the original — and a tuple
passed in reverse, caught only by a schema with two discriminants whose values
differ, which is why `grid(2, 3)` is not `grid(3, 3)`. §6.7.3.3's
one-section-one-tuple rule needed a third: a call with two schematic formals in
*different* sections and different tuples, which is legal and which nothing
else in the corpus wrote.

The twenty-second mutation is the one that did not survive into the count. It
removed a self-reference guard from the generic resolution and nothing noticed,
because the guard was unreachable: §6.4.7's rule is enforced where the
recursion would happen — in the production the body reaches — and a
parameter-form is never resolved inside one. The escape was right and the code
was wrong, so the guard is gone rather than tested.

## What this does not do

Of ADR-0039's five deferrals, this record closes one. The rest stand, and the
first is still the one that matters:

- **Discriminant values that are expressions**, and with them §6.2.3.2's
  dynamically sized variables. It is what `string(n)` needs, and it is what
  turns this record's compile-time tuple check into the dynamic-violation the
  standard calls for.
- **A schema as the domain of a pointer**, and `new(p, discriminants)`.
- **A discriminant as a variant-selector** (§6.4.3.3).
- The required schema **`string`**, and **`type of`** (§6.4.9).

And two this record adds:

- **A whole-variable assignment between two schematic-typed variables**, for
  the reason given above.
- **A schematic formal whose discriminants reach past an array** — a record
  with a dynamically-bounded field, which is the shape `string` itself has.
  Diagnosed rather than mis-laid-out.
