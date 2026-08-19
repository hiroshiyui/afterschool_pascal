# ADR-0122: An address crosses only as an argument, and its lifetime is the call

## Status

Accepted. The second increment of ADR-0109's foreign-function interface, and
the one ADR-0121 named as next: "the single most wanted foreign type is a
string, and it needs a pointer type that crosses the boundary — which is the
memory-safety question in its smallest form."

It does not answer that question. It finds the part of it that does not need
answering.

## Context

ADR-0121 admitted two types, `integer` and `real`, and listed what it did not
do. Four items on that list — strings, `var` parameters, `char *`, and anything
about memory safety — are one item, because each of them is a pointer and the
objection to a pointer was always the same: **a foreign call can do anything,
and a pointer outlives the call.** `doc/roadmap.md` put it that the next
increment and the memory-safety model "may genuinely have to be designed
together".

They do not, and the reason is a distinction the roadmap's own sentence
contains. *A pointer* outlives the call. **An argument does not.** The lifetime
question is a question about where a pointer comes from:

| Direction | Where the storage is | How long it must live | Who decides |
| --- | --- | --- | --- |
| A `var` actual | the caller's own variable | the call, and the caller outlives it | the caller |
| A string actual | a copy the caller makes | the call, and it may be freed after | the caller |
| A returned `char *` | the callee's, or nobody's | unknown, and possibly nothing | the callee |

The first two rows need no model. The caller owns the storage, the caller
outlives the call, and the *only* thing that can go wrong is a callee that
keeps the address — which is a promise, not a lifetime. The third row is the
one that needs ownership, or ARC, or regions, and it is not in this increment.

**And the third row has a second problem that is nearer.** A returned `char *`
may be null, and null is not an error: `getenv` of a name that is not set
returns it in the ordinary course of things. Copying from it would trap on a
value the C library returns on purpose, and answering the empty string would
conflate "not set" with "set to nothing". What is missing is an optional type,
which is one of ADR-0109's four open decisions and is the *pointer safety* row
of the roadmap's table — not the memory-safety row. So the result direction is
blocked twice over, and neither block is one this increment could pick at.

### What the arena already promises

ADR-0111 gave a string temporary a lifetime: it lives for one statement, the
runtime's arena is a stack, and the emitter releases at the end of any
statement that took storage. A foreign call sits inside a statement. So the
lifetime a `const char *` argument wants — longer than the argument list, no
longer than the statement — is a lifetime this compiler already keeps, for
reasons that had nothing to do with C.

That is the whole mechanism. The increment is small because the storage
discipline it needs was built two records ago.

## Decision

### 1. An address crosses only as an argument

Nothing is returned as an address, in either direction: no `char *` result, no
pointer result of any kind, and no out-parameter that hands back storage the
callee owns. The reason is the table above, and it is a reason about lifetimes
and about null rather than a scope limit — a later increment that admits a
returned pointer will be *adding an optional type*, not relaxing a boundary.

### 2. `string` in an `external` heading means `const char *`

```pascal
function atoi(s: string): integer; external 'atoi';
function Remove(path: string): integer; external 'remove';
```

What crosses is one `ptr`: a NUL-terminated copy of the value, made by
`pas_str_cstr` in the string arena. The actual may be any string expression —
a literal, a variable, a concatenation, a substring, or a char, §6.4.3.3.1
giving the char-type "length 1 and capacity 1".

**`string` there is not a schematic formal**, and that is the one thing a
reader has to know. Everywhere else in this compiler `s: string` is a schema
parameter: the actual must be a *variable* produced from the schema, because
its capacity is read out of a descriptor (ADR-0040). At a foreign boundary
there is no descriptor, no discriminant and no callee prologue — the formal is
spelled `string` because that is what a string is called, and what crosses is
the value.

### 3. The formal has no capacity, and no fixed size either

`string(20)` and `packed array [1..3] of char` are refused. A C string carries
its length in-band, as the NUL; a capacity on the formal would be a promise
nothing on the other side keeps, and ADR-0115's guarantee — the callee's
prologue converts and checks — has no callee here to make it. One spelling and
no second rule, which is ADR-0121 decision 2 applied again.

### 4. A `var` parameter of `integer` or `real` crosses as the actual's address

```pascal
function modf(x: real; var ip: real): real; external 'modf';
function frexp(x: real; var e: integer): real; external 'frexp';
```

`int *` and `double *`, the two out-parameter shapes libm uses. Sema's ordinary
var-parameter rules apply unchanged — the actual must be a variable, not a
parenthesised expression, not a substring, not threatened where §6.9.4 says so
— because they are the rules that make an address exist at all.

### 5. A buffer does not cross, and that is the slice decision

`var b: packed array [1..n] of char`, the shape `read` and `snprintf` want, is
refused. It is not refused for a lifetime reason — the lifetime is the same as
row 1's — but because **it is a pointer and a length, and the length is not
in-band.** A C string's is; a buffer's has to be restated by the programmer as
a separate argument, and nothing would check the two against each other.

That is the *slices* row of `doc/roadmap.md`'s table — "a pointer and a length,
from Zig and Rust; excellent, and already the house style" — and it is a
language decision, not an FFI one. ADR-0051's string, ADR-0030's procedural
parameter, ADR-0040's schematic formal and ADR-0049's `complex` are all the
same shape already. Admitting a buffer here would invent a fifth spelling of it
at the one place nothing can check it.

### 6. A NUL inside the value traps

C cannot represent such a string, so there is no image to hand over. Passing
the prefix would quietly rename a path or shorten a command, and a silent
truncation is exactly the class of thing every other check here traps on — a
subscript (ADR-0017), a subrange store (ADR-0018), a nil dereference
(ADR-0019). `pas_str_cstr` scans, and the scan costs nothing it was not already
paying: it copies the same bytes.

This is the one safety property the increment *adds*. Everything else it does
is make a hole visible.

### 7. A foreign call's arguments are their own rule, in Sema and in CodeGen

`EmitForeignArgument` is a fourth argument shape and not a case inside the
other three, and `CheckArguments` takes a branch of its own before the
schematic-formal one. ADR-0121 said "the `declare` is not the ABI; the call
site is"; this makes that literal. None of the existing shapes describes a
foreign argument — there is no descriptor to pass, no pointer-and-length pair
to keep together, and no prologue on the other side to convert anything.

### 8. A procedural parameter is refused, and says why

What would cross is a code pointer *and* the link it runs under (ADR-0030), and
C takes one word. The link is the half with no image at all, so this is not a
narrowness that a later increment widens by admitting one more type: a callback
needs a Pascal procedure that has no static link, which is a different feature.

## Consequences

- **`errno` is not reachable, so a binding module reports one category.**
  glibc spells `errno` as `*__errno_location()` — a function returning `int *`,
  which is decision 1's refusal exactly. So `lib/dialect/pasfs.pas` answers
  `errIO` for every failure and cannot say whether the file was missing or the
  directory unwritable. That is a real cost of the narrowness, and it is the
  first thing the increment after this one buys.
- **A C header's constants are still unreachable**, and the same module shows
  it: `access` takes `R_OK`, `W_OK` and `X_OK`, which are numbers a header
  supplies and an FFI without a header parser cannot see. `F_OK` is 0 and 0 is
  0 everywhere, so `Exists` is offered and the other three are not. Writing 4
  and 2 into a Pascal source would be asserting a value nothing here can check.
- **Nothing checks that the callee does not keep the address.** It cannot: the
  callee is a symbol in an archive. This is registered in `doc/sop.md` §7 beside
  ADR-0121's larger one — that nothing checks a foreign signature at all.
- **`pas_str_cstr` is a third arena producer, and the emitter has to say so.**
  ADR-0111 makes the release a *counter* the allocating arms bump, not a
  predicate over the tree, and CLAUDE.md warns that nothing checks a new
  producer bumped it. `tests/dialect/foreign_string.pas` has a loop whose only
  arena producer is the boundary copy — 100000 iterations through an arena of
  1 MiB — because the loop beside it, which concatenates, bumps the counter for
  its own reasons and would hide the omission.
- **A `var` parameter's declared type is documentation, as everything else at
  this boundary is.** `EmitExterns` writes `ptr` for it, and LLVM does not check
  a direct call against a declaration under opaque pointers (ADR-0121). The
  mutation that kills `tests/dialect/foreign_var.pas` is at the call site.
- **`verify/` gets no rule.** As with ADR-0121, the change is to how an
  argument list is written rather than to an arithmetic, conversion or
  comparison lowering, so a rule would restate the emitted text — which ADR-0013
  says dilutes "no known gaps". The commit carries a `Model-unchanged:` trailer.
- **difftest does not see any of it** (ADR-0117): `src/` is frozen at the
  conformance surface and already refuses `external` at the directive, so a
  source using one is skipped and counted. Nothing new was needed there, and
  that is the ADR-0121 decision 7 boundary holding: the *refusal* is on the
  conformance surface and this record does not move it.
- **The BSI suite does not see it either**, being ISO 7185 and fixed.

## What this does not do

- **No returned pointer, so no `getenv`, `strerror`, `getcwd` or `readlink`.**
  Decision 1, and it needs an optional type before it needs a memory model.
- **No buffers**, per decision 5, so no `read`, `snprintf` or `getline`. That is
  the slice decision and it belongs to the language.
- **No `char` and no `boolean`**, unchanged from ADR-0121: each needs a
  parameter attribute and `char` needs an answer about signedness.
- **No structured types, no sets, no files, no `nil`.** A Pascal pointer does
  not cross in either direction; `new` is still the only origin of one
  (ADR-0116).
- **No callbacks**, per decision 8.
- **No library naming and no `-l`**, unchanged.
- **Nothing about the memory-safety model.** ADR-0109's decision is still open
  and this record deliberately did not touch it. What it did was show that one
  useful slice of the FFI sits entirely on the near side of it. A reader must
  not conclude that the rest does.
