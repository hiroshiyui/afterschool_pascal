# ADR-0121: A foreign function is a directive, and the boundary is two types wide

## Status

Accepted. The first increment of ADR-0109's foreign-function interface, and
the design document its roadmap entry asked for before any code
("the real work is the **type mapping** … that is a document before it is
code").

It decides the *surface* and the *mapping*, and deliberately admits two types.
It does not decide the memory-safety model, and §"What this does not do" is
where the reader should look for how much of the FFI is still unbuilt.

**One consequence below has since been discharged and the record is left as
written.** Decision 6 reserved five bare names and the consequences noted that
two of them — `hypot` and `atan2` — were ones a Pascal programmer might
reasonably want, "because this compiler emits them for `complex`", and that
routing them through `pas_` wrappers "would free them and is a change of its
own". That change was made: `atan`, `atan2` and `hypot` are now
`pas_atan`, `pas_atan2` and `pas_hypot` in `runtime/pasrt.c`, and a program may
name all three. **The decision is unchanged** — a foreign name may not be one
this compiler emits — and what moved is which names it emits, which is exactly
the thing `foreign-reserved` exists to track. Two remain, and neither can move:
`main` is the entry point, and `_setjmp` must be called in the frame `longjmp`
returns to. `tests/dialect/foreign_libm.pas` is the case.

## Context

`doc/roadmap.md` puts the FFI first among everything left, and the reason is
not that it is interesting: sockets, clocks, locales and ADR-0116's allocator
convention are all behind it, and today the only route out of a Pascal program
is a hand-written `pas_*` primitive in `runtime/pasrt.c`. That is right for the
twenty-odd things the standards require and does not scale.

**The stated blocker is discharged.** The FFI was held back one increment for a
reason written down at the time: every syscall wrapper is a routine that can
fail, and the language had no way to say so. ADR-0120 gave it one — a fallible
routine answers a record whose tag cannot lie — so `bind` reporting "the address
is in use" now has a shape rather than an ad-hoc invention per module.

**The unstated blocker is not, and is worked around rather than solved.**
`doc/roadmap.md` also says a foreign call "is a hole in every safety property
the goal asks for", so an FFI surface and the memory-safety model must be
designed as one thing — and the memory-safety model is one of ADR-0109's four
open decisions, none of which is made. This record does not make it. It takes
the answer the roadmap already named as most likely to fit: Rust and Zig both
make the boundary **lexically visible** rather than trying to check across it.
A directive is exactly that, and it prejudges nothing about ownership, ARC or
regions.

### Three mechanical facts, and one probe

**A directive is an established form and costs the lexis nothing.** ISO 7185
§6.1.4 and ISO/IEC 10206:1991 §6.1.4 make `forward` a *directive* — an
identifier in the one position it may occupy, not a reserved word — and
§6.1.5 and §6.1.6 do the same for `interface` and `implementation`, which is
why §6.11's modules reserve five words here and not seven. `ParseProcOrFunc`
already reads that position: it takes a heading, then either the identifier
`forward` or a block. A fourth directive is one arm of an existing choice.

**A Pascal call here carries a static link and a C call does not.**
`EmitUserCall` writes `call <ret> @f(ptr %link, …)` because field 0 of every
frame is the enclosing activation (ADR-0016). A foreign function has no
enclosing activation and no frame; the leading `ptr` must not be written, and
the `declare` must not have it either.

**`EmitExterns` already writes `declare` lines for procedures the current
translation does not define** — that is how §6.13's separately translated
components call into one another. A foreign declaration is a fourth kind of
entry in a list that exists.

**And the type mapping is a question about an ABI, so it was probed rather than
reasoned.** What `clang` emits for a C prototype on this target:

| C | LLVM parameter | This compiler's `PutLlType` |
| --- | --- | --- |
| `int` | `i32` | `integer` → `i32` — agrees, no attribute |
| `double` | `double` | `real` → `double` — agrees, no attribute |
| `char` | `i8 signext` | `char` → `i8` — **needs an attribute, and disagrees about sign** |
| `bool` | `i1 zeroext` | `boolean` → `i1` — needs an attribute, and `_Bool` is not what most C APIs take |

The two rows that need no parameter attribute are the two this record admits.
That is not a coincidence and it is not laziness: a sub-word argument passed
without `signext`/`zeroext` leaves the upper bits of the register undefined,
so admitting `char` means emitting an attribute *and* answering what
`chr(200)` means to a C `char` that is signed on this target. Both are
answerable; neither is answerable by inspection, which is why they are the next
increment and not this one.

## Decision

### 1. `external` is a directive, in the position `forward` occupies

```pascal
function hypot(x, y: real): real; external 'hypot';
procedure sync; external 'sync';
```

Grammar, as an addition to ISO/IEC 10206:1991 §6.7.1 and §6.7.2 under
`--std=afterschool` only:

```
procedure-declaration = … | procedure-heading ';' external-directive
external-directive    = 'external' character-string
```

`external` is an identifier in that position, exactly as `forward` is. Nothing
is added to the keyword table, no program that did not compile stops compiling,
and a variable named `external` is unaffected.

### 2. The foreign name is written out, and there is no default

The string is **required**. Two reasons, and the first is decisive:

- **This lexer case-folds identifiers and C is case-sensitive.** Deriving the
  linker symbol from the Pascal name is a lossy mapping to a name the linker
  will match exactly, and a silently lossy mapping is the kind of thing this
  repository refuses. `getaddrinfo` would work by luck; `LZ4_compress` would
  not, and nothing would say so until the link.
- **It is the boundary made visible.** `grep external` over a source lists
  every place checking stops, with the foreign name beside it. That is the
  whole safety property this increment claims.

One spelling and no default, so there is no second rule about when the name is
derived and when it is written.

### 3. The mapping is by *exact* type, and it is two types wide

Admitted, as a value parameter and as a function result: **`integer`** and
**`real`**. A procedure may also have no result. Everything else is refused
with a diagnostic.

**By exact type, not by base type**, which reverses this compiler's usual rule.
ADR-0018 makes a subrange answer for its host everywhere — `1..9` *is* an
integer, and `Base()` is what `PutLlType` already looks through. At this
boundary the host does not answer, for both directions and for different
reasons: an argument of a subrange type would be sound, but a *result* of one
arrives from a function that made no promise about the bounds, and
`checkedForSubrange` has nothing to apply it to. Admitting the argument
direction only would be a rule with a side, and a rule with a side is what gets
misremembered. Enumerations are refused for the same reason with a sharper
edge — an out-of-range ordinal is not a value of the type at all.

### 4. A foreign call carries no static link

`EmitUserCall` omits the leading `ptr %link` for a foreign callee, and
`EmitExterns` writes its `declare` without it. Nothing else about the call
changes: arguments are already emitted as separate scalars because nothing here
may depend on how a struct is passed (ADR-0030, ADR-0040, ADR-0049, ADR-0051),
which is exactly the property a C ABI wants.

### 5. The FFI is dialect-only, and that decides what `lib/` can never be

`external` is admitted under `--std=afterschool` and refused under both
conformance modes, per ADR-0117's containment. ADR-0119 then makes the
consequence total rather than partial: mode is part of a module's linkage name,
so a dialect module cannot be imported by an Extended Pascal program.

**So the outward-facing library is dialect-only, permanently.** Sockets, clocks
and locales will live in `lib/dialect/`, and `lib/` stays what ADR-0114 made it
— strings, sort, math, containers and text, in ordinary Extended Pascal that a
reader can take to another ISO/IEC 10206:1991 processor. That is the cost of
ADR-0120's two layers paid a second time, and it is stated here rather than
discovered when the third module wants `PasText`.

The alternative was admitting `external` into `--std=extended`, which is an
extension to a conformance mode, which this project forbids.

### 6. A foreign name may not be one this compiler already emits

Found by probing rather than by design: `external 'hypot'` produced

```
error: invalid redefinition of function 'hypot'
```

from LLVM, about a file the author never wrote. The emitted module declares
`@hypot` for `abs` of a `complex`, and LLVM's assembler refuses a second
declaration of any global however identical the two are.

So `ReservedForeignName` refuses the collision as a diagnostic instead. Every
name this compiler emits is caught by one of four tests, and the shape of them
is the point: a **dot** catches LLVM's intrinsics and all of §6.13's linkage
names — `p.<interface>.<constituent>`, `v.<…>`, `pas.input`, `frame.<module>`,
`m.<module>.<std>.<part>` — none of which is spellable without one; `pas_`
catches the runtime; a letter and digits catch the two counters. What is left
is five bare names: `main`, `_setjmp`, `atan`, `atan2`, `hypot`.

Five names is a list, and a list is a second copy of what the emitter writes.
`tests/checks/foreign_reserved.py` compares the two and fails **in both
directions** — a name the emitter grows and the predicate would let through,
and a name the predicate reserves that the emitter has stopped writing. That
is `verify/`'s `KNOWN_GAP` rule (ADR-0013) applied to a sixth catalogue.

### 7. The reference front end refuses it, though it follows it no further

ADR-0117 froze `src/` at the conformance surface, and this is the first dialect
feature with a **syntax of its own** — so the first one that front end can see
at all. It sees this source and must say something:

```pascal
program p(output);
function cbrt(x: real): real; external 'cbrt';   { under --std=extended }
```

Left alone it said `expected 'begin' at the start of a compound statement`,
which is a true thing to say and not the same true thing the real compiler
says — so difftest failed, correctly.

**The refusal is on the conformance surface even though the feature is not.**
What `--std=extended` does with a program is a conformance question, and the
alternative was one `difftest_baseline.txt` entry per dialect feature that ever
needs a diagnostic — which would spend the baseline's emptiness, the property
that makes any entry mean "this change introduced a disagreement". `src/`'s
`Std` still has two values and it is never given `--std=afterschool`, so the
refusal there is unconditional and the dialect *acceptance* path is what it
does not follow. Six lines.

### 8. No `-l` surface in this increment

`tools/pascalcc` already links libc and libm (`clang … -lm`). A first foreign
call therefore needs no build change at all. Naming a library to link is a
separate decision — it belongs to the command line and to whatever install
story `lib/` eventually gets, and neither exists yet.

## Consequences

- **Nothing checks that a declaration matches the function it names**, and the
  emitted `declare` does not help. A mutation that gave the foreign `declare` a
  static link it does not have — `declare double @cbrt(ptr, double)` beside
  `call double @cbrt(double 27.0)` — assembled, linked and ran correctly:
  under opaque pointers LLVM does not check a *direct* call against the
  declaration's parameter list. So the declaration is documentation and the
  call site is the whole of the ABI, and a wrong parameter count, a wrong type,
  or a name that is not the function the author meant is undefined behaviour
  with no diagnostic from anything in the chain. That is what an FFI is without
  a header parser; it is registered in `doc/sop.md` §7. It is also why the
  mutation that *does* kill `tests/dialect/foreign.pas` is the one at the call
  site.
- **A program cannot name `hypot`, `atan2`, `atan`, `main` or `_setjmp`.**
  Four of the five nobody will want; `hypot` and `atan2` are functions a
  Pascal programmer might reasonably reach for, and they are unavailable
  because this compiler emits them for `complex`. Routing those through
  `pas_` wrappers in `runtime/pasrt.c` would free them and is a change of its
  own, with its own goldens to move.
- **`--coverage`, the traps and the string arena are unaffected.** A foreign
  call is a call; it takes no arena storage, so ADR-0111's counter does not
  move.
- **`verify/` gets no rule.** The change is to how a call's argument list is
  written, not to an arithmetic, conversion or comparison lowering, so there is
  no property to state that would not be a restatement of the emitted text —
  which ADR-0013 says dilutes "no known gaps". The commit carries a
  `Model-unchanged:` trailer.
- **difftest does not see it** (ADR-0117): `src/` is frozen at the conformance
  surface, so a source using `external` is skipped and counted. `irtest.sh`
  does not skip, and goldens and a running case are what cover it.
- **The BSI suite does not see it either**, being ISO 7185 and fixed.

## What this does not do

- **No pointers, no strings, no `char *`.** The single most wanted foreign type
  is a string, and it needs a pointer type that crosses the boundary — which is
  the memory-safety question in its smallest form, and is where the next
  increment starts.
- **No `var` parameters.** An out-parameter is a pointer by another name and
  waits on the same decision.
- **No `char` and no `boolean`**, per the probe above: each needs a parameter
  attribute, and `char` additionally needs an answer about signedness.
- **No structured types, no sets, no files, no procedural parameters.**
- **No library naming and no `-l`**, per decision 6.
- **No callback direction.** A C function cannot be handed a Pascal procedure;
  that needs a Pascal procedure with no static link, which is a second feature
  and not the mirror of this one.
- **No header parsing, and no checking of a signature against anything.**
  See the consequence above: the `declare` is not even checked against the
  call.
- **Nothing about the memory-safety model.** The boundary is visible, not
  checked, and ADR-0109's decision stays open. A reader must not conclude from
  "the boundary is lexically visible" that anything about it is verified.
