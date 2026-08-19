# ADR-0125: A slice is a parameter form, and the pair travels as two words

## Status

Accepted. The **slices** row of `doc/roadmap.md`'s table — "a pointer and a
length, from Zig and Rust; excellent, and already the house style" — and the
decision ADR-0122 deferred a buffer to by name.

It settles bounds safety for a *part* of an array. It does not settle the
memory-safety model, and it does not cross the foreign boundary; §"What this
does not do" says why the second one is a probe's finding rather than a scope
limit.

## Context

Two things converge, and only one of them is about C.

**Extended Pascal gives a string a substring and gives an array nothing.**
§6.7.6.7's `substr` and the `s[i..j]` designator produce a value that is part
of a string; there is no such thing for `array [1..100] of real`. A procedure
that wants to sort, sum or fill *part* of an array cannot be written. The
workarounds are to pass the whole array and two indices — which puts the bounds
outside anything that checks them — or to copy the part out, which is a copy
nobody wanted.

**And ADR-0122 refused a buffer at the foreign boundary**, in those words:
"it is a pointer *and* a length, and the length is not in-band the way a C
string's is … That is the slices row of `doc/roadmap.md`'s table, and it is a
language decision, not an FFI one." This is that language decision.

### The shape is not new here

Four things in this compiler already travel as two scalars rather than as a
struct, each for the same stated reason — nothing here may depend on how a
struct is passed, because the backend is textual `.ll` and has no opinion about
the C ABI:

| What | Pair | Record |
| --- | --- | --- |
| a procedural parameter | code, static link | ADR-0030 |
| a schematic formal | address, discriminants | ADR-0040 |
| a `complex` | two doubles | ADR-0049 |
| a string | pointer, length | ADR-0051 |

A slice is that shape a fifth time, and the roadmap said so before any of this
was built. What ADR-0051 did for `char`, this does for any component type.

### And the precedent for "a type only a parameter may have" exists

`tyProc` is the type of a procedural or functional parameter and of nothing
else: no variable has one, no field, no function result. A slice is the second
such kind, which means the rule below is not an exception invented for it.

## Decision

### 1. `array of T` is a parameter form

```pascal
procedure Fill(var a: array of real; v: real);
function Sum(protected var a: array of real): real;
```

**The lexis costs nothing, for the third time and by a third route.** ADR-0121
got it from a directive (an identifier in one position) and ADR-0123 from a
character no standard admits. Here both words are already reserved in both
standards and it is the *combination* that is free: §6.4.3.2 spells an
array-type `'array' '[' index-type … ']' 'of' component-type`, so `array of T`
— with no brackets — is a syntax error in ISO 7185 and in
ISO/IEC 10206:1991 alike. No program that compiled stops compiling.

The spelling is Delphi's open array, deliberately, because a Pascal programmer
who has seen one knows what it is. Where it differs is decision 4, and the
difference fails loudly.

**The denoter is confined to a parameter's own type**, which is stronger than
"a slice may not be a variable" and needs one test rather than a list of
positions. `type reals = array of real` is refused, and so is a slice inside a
record, inside an array, or inside another slice — all by the same question:
*is this the denoter a formal parameter was declared with?* A named slice type
would have been convenient and would have needed a separate refusal at every
place a variable of one could be created; there is no such place to miss when
the name cannot exist.

### 2. `var` and `protected var` only — a slice is never a value parameter

A slice is a **view of storage the caller owns**. That is what makes it a slice
rather than an array, and a value parameter is by definition not a view: it is
a copy, and a copy of part of an array is a thing this language can already
express by passing a schematic array by value.

So `var` gives write access and **`protected var` gives the read-only borrow**
— §6.6.3.7's protected parameter (ADR-0046), which is exactly Rust's `&[T]`
under a name Extended Pascal already chose. Nothing new is needed for it: the
threat rules ADR-0046 walks apply unchanged.

### 3. The actual is an array, a slice of one, or another slice — and `a[i..j]` is already the syntax

```pascal
Sum(a);              { the whole of it }
Sum(a[3..7]);        { five components }
Sum(s[2..4]);        { a slice of a slice, inside a callee }
```

**`a[i..j]` needed no parser change at all.** It is the designator
ISO/IEC 10206:1991 gives a substring, and this compiler already parses it into
`nkSubstr`; what decides between a substring and a slice is the *type of the
base*, which Sema knows and the parser does not. That is the "ask the symbol,
not the syntax" pattern this repository has now reached for six times
(ADR-0044, ADR-0053, ADR-0066, ADR-0071, ADR-0087), and it is the reason this
feature is as small as it is.

The base's index-type must be an integer type. An enumerated index has no
arithmetic a slice could be built from, and `a[red..green]` would have to
invent one.

**And the designator is dialect-only, which difftest is what noticed.** §6.5.6
gives `a[i..j]` to a string and to nothing else, so both conformance modes must
go on saying "only a string can have a substring taken of it" — the reading is
a conformance question even though the feature is not, exactly as ADR-0121
decision 7 found for `external`. Left ungated, this changed what
`--std=extended` said about `tests/extended/substring_errors.pas`, and `src/`
— frozen at the conformance surface, and right — disagreed. The gate is one
condition; the alternative was a `difftest_baseline.txt` entry, which spends
the emptiness that makes an entry mean something.

### 4. A slice is indexed from 1, and `length` answers its count

§6.4.3.3.1 gives every string here an index-domain starting at 1, and
§6.7.6.7's `substr` yields one indexed from 1 however far into the string it
was taken. A slice follows: `a[3..7]` has components `1..5`.

**This differs from Delphi**, whose open array is indexed `0..High(a)`. The
divergence is chosen rather than overlooked: one base index for every
sequence-like thing in the language beats agreement with a dialect this one is
not trying to be. It also fails *loudly* — a Delphi habit writes `s[0]`, and
that is a bounds trap on the first access, not a quiet off-by-one.

`length(s)` answers the count, extending the required identifier
ISO/IEC 10206:1991 §6.7.6.5 gives a string. A slice and a string are the same
shape; giving them two spellings for one question would be the invention.

### 5. The pair travels as two arguments, and the slot holds two words

`ptr` then `i32`, exactly as the four rows above travel. The formal's frame
slot is `{ ptr, i32 }`, which is the shape a procedural parameter's slot
already has — and it is a slot that holds the pair even though the parameter is
a `var` one, because the *length* is not in the caller's variable. It is what
the designator computed, and there is nowhere else for it to live.

**Two slices are compatible when their component types are the same type**, and
never because they are the same type object. That reverses ADR-0017's name
equivalence, and the reason it is not an exception to it is that ADR-0017 is a
rule about types a program can *write*: a slice type has no name, cannot be
declared, and is built afresh at every designator. There is nothing to
name-equate. The extent is exactly what does not have to match — that is the
feature — so what is left to agree on is the component.

### 6. Bounds are checked twice, and the second check is not the first repeated

Where the slice is **taken**, `a[i..j]` is checked against `a`'s own bounds:
`i >= lo`, `j <= hi`, and `j >= i - 1` — the last admitting the empty slice,
because §6.7.6.7 already lets `substr(s, i, 0)` yield the null-string and a
loop that consumes a slice down to nothing should not have to special-case its
last step.

Where the slice is **indexed**, `s[k]` is checked against `1..length(s)`. That
is a different check and not a repetition: the callee cannot see where its
slice came from, and its length is the only bound in scope. This is the
property the feature is for — the bounds travel *with* the pointer, so no
caller can hand a length that does not match the storage, which is precisely
what a C buffer-and-count pair cannot promise.

### 7. No slice variables, no slice fields, no slice results

A slice may be a formal parameter and an actual, and nothing else. That is what
makes it safe without a memory model: ADR-0122 found that **an argument has no
lifetime question** — the caller owns the storage and outlives the call — and a
slice that cannot be stored cannot outlive the array it views.

This is the third increment to take that shape, and it is worth naming as a
pattern rather than as three coincidences: where a feature's danger is
*lifetime*, confining it to an argument removes the danger without deciding
anything about ownership.

## Consequences

- **`tySlice` is the eighteenth type kind, and `kind-exhaustive` demanded six
  arms before this would build.** The gate written in ADR-0124 did its job on
  the very first kind added after it, which is the outcome that record was
  betting on.
- **A slice's length is the callee's only bound**, so a wrong length is a wrong
  program that traps rather than a wrong program that reads someone else's
  storage. The check cannot be omitted the way an array subscript's can inside
  a `for` over its own bounds (ADR-0017), because nothing in the callee knows
  the extent statically.
- **`verify/` gets no rule.** The index check is `1 <= k <= n` against a length
  in a register, which is the array rule of `verify/rules.py` with a dynamic
  bound — and that rule is already stated symbolically over its bounds, so a
  second copy would restate it. The commit carries a `Model-unchanged:`
  trailer.
- **difftest does not follow it** (ADR-0117), `src/` being frozen at the
  conformance surface. The *refusal* is on that surface and needs nothing:
  `array of T` is a syntax error there already, and both front ends say so.
- **A `for` loop over a slice needs its length twice** — `for i := 1 to
  length(s)` — and §6.8.3.9 evaluates the limit once, so this costs one load.
- **`tySlice` joins the type kinds `StaticThroughout` answers `true` for**, and
  by argument rather than by approximation: a slice denoter may be written only
  as a formal parameter's own type, never in a schema body, so nothing inside
  one can name a discriminant.

## What this does not do

- **It does not cross the foreign boundary, and that is a probe's finding.**
  What `clang` emits for the POSIX data path on this target:

  ```
  declare i64 @read(i32, ptr, i64)
  declare i64 @write(i32, ptr, i64)
  declare i64 @recv(i32, ptr, i64, i32)
  declare i32 @snprintf(ptr, i64, ptr, ...)
  ```

  Every length is `i64`, and every one of `read`, `write` and `recv` *returns*
  `ssize_t`, which is `i64` as well. A slice could cross with an `i64` length
  without difficulty — the compiler generates that word, so it may choose its
  width — but the **result** cannot be received: this language's `integer` is
  `i32` and has no wider type. Declaring `read` to return `integer` reads the
  low half, which happens to be right for a count and for -1 and is right by
  luck.

  So the data path needs *two* things and this is one of them. Shipping a
  buffer argument now would put a knowingly wrong ABI in the tree for the sake
  of a call that cannot report how many bytes it moved. **The other half is a
  64-bit integer type**, and it is the next increment.
- **No slice of a string.** A variable-string's characters do not start at its
  address — the length word is in front (ADR-0045) — so `array of char` from a
  `string(n)` is a third case in every path that handles the pair, for a use
  ADR-0122's `const char *` already covers in the one direction that exists.
- **No multi-dimensional slice.** `a[1..3, 2..4]` of a two-dimensional array is
  not a pointer and a length; it is a pointer, two lengths and a stride, and a
  stride is a fourth word the house shape does not have.
- **No slice arithmetic** — no concatenation, no comparison, no assignment
  between slices. §6.7.2.5 gives an array none of those either, and a slice is
  a view of an array.
- **Nothing about the memory-safety model.** ADR-0109's decision stays open.
  What this settles is bounds safety, for the case where the bounds and the
  pointer travel together.
