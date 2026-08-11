# 43. A heap variable's tuple is a header in front of it

Date: 2026-08-11

## Status

Accepted. It is ADR-0039's fourth deferral: a schema as the domain of a
pointer, with `new(p, d₁, ..., dₛ)`.

## Context

ISO/IEC 10206:1991 §6.4.4 spells a domain-type `type-name | schema-name`, so
`^vector` is a pointer whose domain is a *schema* rather than a type, and
§6.7.5.3 gives `new` a second form whose arguments are the tuple the created
variable's type is produced with. A pointer to a type *produced* from a schema
already worked — `type v3 = vector(3); vp = ^v3` is a pointer to an ordinary
named type — so what is new is the case where the tuple is not chosen until the
allocation happens.

Every tuple so far has lived somewhere a *symbol* can name. ADR-0040 put a
schematic formal's in the parameter's own frame slot and ADR-0041 put a
dynamically-declared variable's in its own; both are reached by `addressOf`,
the walk every access to an enclosing variable makes. A variable created by
`new` has no activation record at all, and is not reached by a name — `p^` is
not one, and neither is `q^[1]^`. So the question this record answers is where
the tuple lives and how the code that reads bounds finds it.

## Decision

**The tuple is a header immediately in front of the variable, and the pointer
denotes the variable rather than the block.** `new` allocates
`headerSize + dynSize` bytes, writes the tuple into the front, and stores
`block + headerSize`; `dispose` gives back `p - headerSize`.

That choice is what makes the feature small. Because the pointer denotes the
variable, `p^` is the same address `p` already was: assignment between
pointers, comparison with `nil`, the nil check on every dereference, storing a
pointer in a record or an array, and ADR-0019's rule that every pointer type is
`ptr()` are all untouched. Only `new` and `dispose` know the header exists.
The alternative — a fat pointer carrying the tuple — would have made a pointer
a multi-word value and reached into all of the above.

**A discriminant is one `i32` whatever its own type, and the header is rounded
up to 16 bytes.** The rounding is not cosmetic: `malloc` returns storage
aligned for anything, and the variable must keep that alignment, which a header
of 4 or 12 bytes would break. 16 rather than 8 because a set is 256 bits and
this target aligns one to 16 — the same fact ADR-0028 learned by segfaulting.

**The bounds are found by walking down the designator, not by threading them
through.** One header serves every dimension, so `g^[i][j]` reads `rows` and
`cols` out of the same one — but the inner subscript's base address is a
component's, not the variable's, so it cannot compute the header from what it
has. `heapHeader` walks a designator through its subscripts and field
selections to the whole variable it selects from and takes the header there.
Re-emitting the root address is what that costs, and it is a load LLVM already
knows how to fold.

**One type per schema, memoised** — `^vector` written twice denotes one type,
the way `vector(3)` written twice does — **and a domain naming the schema being
produced waits.** These are two separate things, and it is worth saying which
does the work, because the obvious reading gets it backwards. It is the
*waiting* that makes §6.4.7's recursion terminate: a production in progress
cannot answer, so the pointer goes on the pending list ADR-0019 already keeps
for the language's only forward reference, and the production fills it in on
the way out. The memo does not stop any recursion the guard would not have
stopped; it decides *identity*, and saves resolving the body once per denoter.

Mutation testing is what established that. Removing the memo left every test
green, and no program could be written that told the difference — two heap
types produced from one schema have equal `schema` fields, so `assignable`,
the schematic-formal check and every discriminant read answer identically. It
is kept because one schema denoting two types would be a fact waiting to
matter, not because a test defends it, and this paragraph is here so the next
reader does not go looking for the test.

**Inside `new` the bounds are answered from the arguments.** The size is asked
of the tuple before there is anywhere to put the tuple — the block being sized
is where it will live. Rather than build it in scratch storage, `boundValue`
consults the values themselves for the length of the two calls that need them.
That is not a shortcut: the Pascal-hosted emitter is sequential and cannot go
back to put an `alloca` in the entry block, so scratch storage would have had
to be claimed where the `new` is, and `new` inside a loop would grow the stack
until the activation ended. The state is null everywhere except inside `new`,
which is what makes it safe for a bound reader to consult at all.

**The two forms of `new` are told apart by the domain and by nothing else.**
`new(p, c₁, ..., cₙ)` selects variants (ISO 7185 §6.6.5.3, ADR-0027) and
`new(p, d₁, ..., dₛ)` gives a tuple; a record with a variant part takes the
first and a schema domain the second, and the argument lists are
indistinguishable. This is the same shape as ADR-0034's two meanings of
`otherwise`, decided by one fact each time rather than by looking at the
arguments.

## Consequences

**A discriminant given to `new` need not be a constant**, and that is not a
concession — §6.7.5.3 never asked for one. It is the difference between this
and §6.4.8's actual-discriminant-part, and it is the whole reason a header
exists rather than a compile-time layout.

**Two checks, in the places they already belonged.** A discriminant outside its
own type goes through `checkedForStore`, so it reports in the words a subrange
always uses; a tuple that leaves an index range empty reaches
`checkSchemaDomain`, which ADR-0041 wrote for a block's entry and which needed
only a header parameter to serve here too.

**`p^` may be assigned, compared and passed like any other schematic
variable**, and none of that is new code: ADR-0042's tuple comparison reads
whichever side is on the heap through `discValue`, and ADR-0040's call-site
tuple does the same. `discValue` grew one case and two call sites collapsed
into it.

**`dispose` of nil now traps, and only for a schema domain.** ISO 7185
§6.6.5.3 always made it an error, and until there was a header it was a
harmless one — freeing nil does nothing. Stepping back over a header first
turns it into a free of an address that was never allocated, so the check
exists where this record introduced the hazard rather than being extended to
every pointer, which would change behaviour this feature has no business
changing.

**Use-after-dispose is still undetected**, and the header makes it no worse and
no better. `dispose` sets the pointer to nil, so the common form traps; a
second pointer to the same variable reads freed storage, header and all.
ADR-0019 said so and this does not change it.

**Twenty-five mutations across both compilers, all caught — after two escapes
and one of them was the harness.** The one that was real is the header's
rounding: every case in the corpus had a component aligned to 8 or less, so a
header rounded to 8 instead of 16 passed everything. `schema_pointer.pas` now
allocates an `array [1..n] of set of char`, which is the alignment ADR-0028's
segfault was about, and it faults under that mutation exactly as that one did.

**No proof rule.** `verify/` quantifies the array rules over their bounds, so a
pair that arrives from a header is already inside what they say — the third
record in a row where that is the answer. The allocation arithmetic is checked
instead by running: `tests/extended/schema_pointer.pas` allocates, fills and
frees variables of five different shapes, and a 2000-iteration stress program
under `MALLOC_CHECK_` is what says the header offset and `dispose` agree.

## What this does not do

Of ADR-0039's five deferrals one remains — a discriminant as a variant-selector
(§6.4.3.3) — and ADR-0040's second half stands: a schematic formal whose
discriminants reach past an array, which is the shape `string` itself has.

A schema producing anything but an array is still refused everywhere a
descriptor is needed, a pointer domain included: the discriminants have to
bound an array, because that is the only size a descriptor can describe. The
diagnostic gained a third noun and nothing else.
