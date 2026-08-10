# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Afterschool Pascal: an ISO 7185 Standard Pascal compiler with an LLVM backend,
written in C++20 against the LLVM 21 C++ API. The near-term goal is
**self-hosting** — see "Bootstrap constraints" below, which govern design
choices that would otherwise look arbitrary.

## Commands

```sh
# configure (LLVM_DIR is required on Debian; llvm-config is not on PATH)
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DLLVM_DIR=/usr/lib/llvm-21/lib/cmake/llvm
cmake --build build -j

ctest --test-dir build --output-on-failure
ctest --test-dir build -R control --output-on-failure   # a single case, by name
tests/run_test.sh build/bin/pascalc tests/control.pas iso7185   # without ctest
tests/run_test.sh build/bin/pascalc tests/extended/otherwise.pas extended
selfhost/difftest.sh build/bin/pascalc   # the Pascal compiler against the C++ one
selfhost/irtest.sh build/bin/pascalc     # what the Pascal compiler *builds*, and stage 2 = stage 3

build/bin/pascalc tests/hello.pas -o /tmp/hello && /tmp/hello
build/bin/pascalc -O0 --emit-llvm tests/hello.pas -o /dev/stdout   # inspect IR
build/bin/pascalc --std=extended prog.pas   # ISO/IEC 10206:1991 instead
```

Adding `tests/foo.pas` + `tests/foo.out` requires **re-running `cmake`** — cases
are registered by a `file(GLOB)` at configure time, and `tests/` and
`tests/extended/` are globbed separately because they are compiled under
different standards.

`pascalc` shells out to `clang` to link, and finds `libpasrt.a` through the
build path baked in as `APASCAL_RUNTIME_DIR`; `AFTERSCHOOL_PASCAL_RUNTIME`
overrides it.

## Pipeline and its contracts

`main.cpp` runs: Lexer → Parser → Sema → CodeGen → PassBuilder → TargetMachine →
`clang` link. Each stage bails before the next if `Diagnostics::hasErrors()`.

The contract that keeps `codegen.cpp` simple: **Sema leaves every `Expr::type`
non-null and every `VarRef::sym` resolved.** CodeGen therefore never inspects
names, never re-derives types, and reports no user-facing errors — if it needs a
fact about the source program, that fact belongs in Sema. On an error path Sema
still assigns a placeholder type rather than null, so codegen can't crash on a
half-checked tree.

Errors: the parser throws `ap::ParseAbort` (the only exception in the codebase)
when it cannot make progress; Sema and the lexer instead accumulate into
`Diagnostics` so one run reports many errors.

**Activation records and static links** (ADR-0016). Every procedure — and the
program itself, at level 0 — gets a frame struct alloca'd in its entry block.
Field 0 is the static link to the enclosing block's frame; locals, value
parameters, `var` parameters, and the function result are the remaining fields.

- `frameAt(level)` walks the chain; `addressOf(sym)` walks then indexes. All
  variable access goes through `addressOf`, so there is no separate global path.
- Calling a procedure at level `L` passes the frame at level `L-1` as a hidden
  first argument. For a *recursive* call that is the caller's parent, not the
  caller — the one place this is easy to get subtly wrong.
- A `var` parameter's frame slot holds a pointer; `addressOf` dereferences it.
- The link is field 0 at offset 0, so intermediate hops load it without knowing
  the struct type at that level. Only the final index needs the target's type.
- `tests/nesting.pas` pins the case that distinguishes a correct implementation:
  a nested procedure inside a *recursive* one must see the locals of the
  invocation it was called from.

Sema mirrors this: `Symbol` carries `level`, `owner`, and `frameIndex`, and
`Symbol::frameVars` is the frame layout codegen consumes. Assigning to a
function's own name writes `resultVar`; *reading* the name is a recursive call
(ISO 7185 §6.8.2.2), so there is no way to read a function's result back.

**Structured types and designators** (ADR-0017). `Type` is a flat struct with a
`TypeKind` tag; simple types are shared singletons and every array or record
*type-denoter* allocates one, owned by `Sema::types_`. Two structured types are
the same only when they are the same object — ISO 7185 §6.4.5 name equivalence
— so `assignable` compares them with `==`. Packed char arrays are the standard's
own exception and compare by length instead.

- A designator is `VarRef` with `IndexExpr` and `FieldExpr` wrapped around it.
  `CodeGen::emitAddress` is the single path to an address; `emitLoad` reads
  through it. An array or a record has no register form, so a designator of one
  yields its *address* and assignment becomes a memcpy.
- Every subscript is bounds-checked before the offset is computed, and the
  offset subtraction is unchecked because the check has already made it sound.
  `verify/rules.py` proves both halves of that sentence.
- A structured parameter always travels as an address: a `var` parameter binds
  to it, a value parameter is copied by the callee's prologue. `paramType`
  differs from `slotType` for exactly this reason.
- A string literal is typed `packed array [1..n] of char` in Sema, not given a
  type of its own, so `write`, assignment, comparison, and argument passing need
  no literal-shaped special case.
- `with` binds the record's address into a hidden frame slot of kind
  `VarParam`, so the designator is evaluated once and the binding is
  per-invocation. A bare name that is a field of an open `with` resolves to
  that binding plus `VarRef::withField`.
- The data layout is set on the module *before* codegen (`main.cpp` builds the
  TargetMachine first), because the size of a record decides what a whole-
  variable assignment copies.

**Ordinal types** (ADR-0018). `Type::base()` returns the host of a subrange and
the type itself otherwise, and `isInteger()`, `isChar()`, `isNumeric()` and the
rest all answer for the base — so `1..9` *is* an integer everywhere except
where its bounds matter. That is what let subranges reach arithmetic,
comparison, `write`, indexing and parameter passing with no edits. Code needing
the distinction asks `isSubrange()`.

- Two enumerated types are never compatible however alike they look, so
  `assignable` requires identity for them and must not fall through to the
  kind comparison.
- `ordinalLo()`/`ordinalHi()` give a type's first and last values. `succ`/`pred`
  trap at *those*, not at `maxint` — an enumeration ends at its last constant.
- `checkedForSubrange` is applied where a value *enters* a variable
  (assignment, value parameter, both `for` bounds) and is a no-op for every
  other type, so call sites need no conditional. Nothing between the `for`
  bounds needs a check because the loop never leaves them.
- `case` is an LLVM switch whose default traps: ISO 7185 §6.8.3.5 has no `else`
  and none is invented.
- A variant part is one block of shared storage with each arm a struct laid
  over it. The block's element type carries the alignment (`[k x i64]`, not
  `[n x i8]`) or a `real` inside a variant would be misaligned. An arm's
  field-list is a field-list, so **an arm may hold a variant part of its own**
  (ADR-0026): `Variant` has the same `variants`/`tagField`/`tagType` a record
  has, `Field::variant` is the *path* to the field's field-list rather than one
  index, and `fieldsAt`/`armsAt`/`fieldAddress` are keyed by that path.
  `parseVariantPart` takes its own depth guard, because it is the one recursion
  in a type-denoter that does not pass through `parseTypeExpr`.

**`goto` and labels** (ADR-0029, ADR-0032). A label is a *number*, not a name (§6.1.6),
so it is not a Symbol and does not go in a scope — two blocks may each declare
label 1. Sema gives every label a program-wide unique id, and that id is what a
goto resolves to and what codegen branches to.

- **Where a goto may land is a prefix test.** Each labelled statement and each
  goto records the chain of statements containing it; §6.8.1 is exactly "the
  label's chain is a prefix of the goto's". That is leaving-but-not-entering,
  sibling loops, and same-level jumps in one comparison. A block's statement
  part is deliberately *not* on the chain — it is the outermost sequence, not a
  statement — which is what makes "top level of the block" mean "empty chain".
- **A goto is resolved when its block has been walked**, not where it is
  written: a forward jump has nothing to resolve against yet. One whose label
  is in an enclosing block is handed *outwards*, because a nested procedure's
  body is checked before the statements of the block containing it.
- A goto opens a fresh block for what follows it. LLVM tolerates the
  alternative, so no test can see this — don't "simplify" it away.

**The non-local form** (ADR-0032) leaves the block, which a branch cannot do.
The *target* block carries a jump record in its activation record — after the
variables, so no frame index moves — and its prologue arms it, calls `_setjmp`,
and switches on the result to the label the jump named. The goto reaches that
record with `frameAt(owner->level)`, the same walk every access to an enclosing
variable does, so a recursive enclosing procedure gets the invocation this one
was called from.

- **A block learns it is a target from its nested blocks**, when Sema resolves
  a goto handed outwards to it — which has already happened by the time its own
  statements are walked. `Symbol::nonLocalLabels` is what codegen reads.
- **`_setjmp` is called from the generated function, never through a wrapper**:
  a wrapper would have returned by the time the jump arrived, and its frame is
  what `_setjmp` recorded. `pas_jump_env` arms the record and hands back the
  address to call it on, so `jmp_buf` stays the runtime's business.
- **`returns_twice` is load-bearing and LLVM does not infer it.** Without it the
  declaration comes out bare and `-O2` will inline a function containing the
  call. No test catches its removal; don't drop it because the suite stays green.
- A label arrives as its id **plus one**, because `_longjmp` with zero comes
  back looking like the ordinary entry.
- **The abandoned blocks' files are closed dynamically, not through the static
  chain.** Every open file is on a list and the record notes its head when
  armed; the jump closes what was registered since. Walking the static chain
  looks equivalent and is wrong — a procedure passed as a procedural parameter
  is called from a block that is not on its chain, and a jump out of it
  abandons that block too. `tests/goto_files.pas` has both shapes.

**Procedural and functional parameters** (ADR-0030). A procedure passed as an
argument travels as a **pair**: the code, and the static link to call it with —
the link of the block it was *declared* in, which the caller cannot derive
because its own static chain says nothing about where the passed procedure
came from. `tests/procparam.pas` pins the case that distinguishes a correct
implementation: a nested function passed out of a *recursive* procedure must
see the locals of the invocation that passed it.

- The pair **never exists as an LLVM value**. It occupies one frame slot of
  type `{ptr, ptr}`, written and read through its own two getelementptrs, and
  travels as *two* arguments. Nothing then depends on how a struct is passed,
  which is what keeps the textual `.ll` backend free of `insertvalue` and of
  an opinion about the C ABI. `appendParamTypes` is the one place the shape is
  decided, so a caller and a callee can only agree.
- Naming a procedure takes its address and `staticLinkFor` it; naming a
  procedural *parameter* forwards the pair it already holds, so a procedure
  handed on through three levels still runs in its own scope.
- **Congruity (§6.6.3.6) is checked on symbols, not on types.** The rule is
  pairwise over the parameter lists — same count, same passing mode, same type,
  and congruity again for a procedural parameter of one — which is exactly what
  `Symbol::params` holds. `assignable` is untouched: a procedural parameter is
  never assigned, and its `Type` carries only the result type, for diagnostics.
- **An actual procedural parameter is resolved against its formal.** `f`
  written as an argument denotes the function; written anywhere else it is a
  call of it. That is why `checkArguments` checks each argument knowing which
  parameter it is for, rather than checking them all first — the one place in
  Sema where an expression's meaning depends on where it sits.
- The formals *of* a procedural parameter are descriptors: they get no frame
  slot and no scope, because the frame they will occupy belongs to whatever
  procedure is eventually passed.
- This is the first thing here that lets an activation record's address outlive
  the call that made it. It is safe only because there is no procedure type in
  the type part, so the pair cannot be stored anywhere — don't add one without
  answering what that would mean.

**Sets** (ADR-0028). A set is one 256-bit word, a bit per possible member, so a
base type's values must lie in 0..255 — `set of integer` is refused under the
latitude ISO 7185 §6.4.3.4 gives, not silently truncated. The consequence that
matters is that a set is a **value**: `isStructured()` and `isMemory()` both
exclude it, it is assigned with a store and passed in a register, and none of
the by-address machinery applies.

- Set compatibility is **structural**, decided on the base type. That is
  §6.4.6's own rule, not an exception invented here — it is why `assignable`
  must handle sets before falling through to name equivalence, and why `[]`
  needs no exception at all.
- The operators are one instruction each: `or`, `and`, `and not`, and
  `(s and not t) = 0` for inclusion. There is no `<` or `>` on sets.
- **Two range checks answer different questions.** A member outside 0..255 has
  no bit, so the *constructor* traps. A member outside the *target's* base type
  is representable but not a value of the type, so the **store** traps —
  `checkedForSetBase` beside `checkedForSubrange`. `in` traps on neither: an
  unrepresentable value is simply not a member.
- A range `[lo..hi]` is built by shifting, and `hi < lo` is selected away to
  the empty set. No 256-bit literal is ever needed, which matters because the
  Pascal-hosted compiler cannot spell one.
- A set is the first type wider than a machine word, which is what turned the
  emitted module's missing `target datalayout` from a latent hazard into a
  segfault — see the CodeGen section, where that rule now lives.

**Pointers** (ADR-0019). A pointer's domain is a type *identifier* and may name
a type defined later in the same type part — the language's only forward
reference, and what makes a recursive type possible. `resolvePointer` records a
`PendingPointer` when the name is not yet known and
`resolvePendingPointers()` completes them at the end of the type part.

- `ty::Nil()` is a pointer with a null domain: assignable to any pointer,
  nothing assignable to it. Two named pointer types stay as distinct as any
  other named types, so ADR-0017 needed no exception.
- Every `NK::Deref` traps on nil, and `dispose` stores nil back into the
  variable. Use-after-dispose through another pointer is **not** detected —
  don't let a comment or a doc imply otherwise.
- `new(p, c1, ..., cn)` allocates only the selected variants (ADR-0027). Sema
  folds the tag values into `ProcCallStmt::variantSelection`, a path of the same
  shape as `Field::variant`, and `selectedSize` trims the *tail* only: the
  offsets stay the full type's, so `p^.field` is the same getelementptr it
  always was. ISO's rule that such a variable may not be assigned or passed is
  **not** enforced — that needs a run-time property.
- Opaque pointers make every pointer type `ptr()`, so recursion needs nothing
  from codegen.
- There is deliberately **no SMT rule** for pointers; a nil-check rule would be
  a tautology. They are covered by the cross-check and by an ASan run.

**Text files** (ADR-0021). A file variable's storage is *opaque to the
compiler*: codegen alloca's `PAS_FILE_SIZE` bytes in the frame and only ever
passes their address, and `struct pas_file` is private to `runtime/pasrt.c`.
The size lives in `runtime/pasrt.h`, included by `codegen.cpp`, so the two
cannot disagree; a `_Static_assert` fails the build if the struct outgrows it.

- The buffer variable `f^` is real, and `read`/`write` are *derived* from
  `get`/`put` in the runtime, as ISO 7185 §6.6.5.2 defines them. This is
  deliberate and load-bearing: `f^` is one character of lookahead, which is
  what a lexer — the first component of the self-hosted compiler — is written
  against. Don't "simplify" it into direct `getc` calls.
- `f^` shares `NK::Deref` with pointer dereference; Sema parts the two on the
  base type, and codegen calls `pas_buffer` for a file.
- A file is **not** `isStructured()` — that predicate grants whole-variable
  copying, which a file must never have. `isMemory()` is the one that means
  "travels by address". Assignment, comparison, value parameters and function
  results are all refused for files.
- Program parameters bind to command-line arguments in order; `input`/`output`
  are the standard streams, declared *only* when the header lists them, so
  using `write` without `output` is the error §6.10 says it is.
- Standard input is opened but not read until the program first asks, or every
  program listing `input` would block before its first statement.
- A block exit closes the files the block declared, and also frees the buffer
  variable a `file of T` allocated. Pascal has no early return, so the single
  exit point each body already has is the epilogue. A *local* `goto` cannot
  leave the block; a **non-local** one does, and skips that epilogue — so the
  runtime does the same work for every block the jump abandons (ADR-0032).
  Two implementations of one obligation, and the second exists because a
  `longjmp` skips the first.
- `char` is a byte, ordinal 0..255, and nothing consults the locale. UTF-8
  passes through as bytes; a multi-byte character is several `char` values.

**Non-text files** (ADR-0031). A `file of T` is the text-file machine with two
constants changed: a component is `compsize` bytes rather than one, and there
is no line structure. `pas_file_init` carries both, and that pair is the whole
of what the compiler tells the runtime about T — so `get`, `put`, `eof` and the
buffer variable are one implementation with a text branch each, not two.

- **`text` is not `file of char`.** §6.4.3.5 makes them different types and
  gives only the first one lines, so `readln`, `writeln` and `eoln` are refused
  on every other file. One flag on the `Type` says which, set on the `text`
  singleton and never by `resolveFile`; they are otherwise identical, down to
  the component size. A diagnostic that called both "text" would be naming the
  wrong type, which is why `Type::name()` spells the component out.
- **`read` and `write` on one are emitted as the assignments §6.6.5.2 defines
  them to be** — `v := f^; get(f)` and `f^ := e; put(f)`. That is what split
  `emitAssign` into `emitStore`, which is now the whole of what assignment does
  and is called with the buffer variable as the destination. A component of a
  `file of 1..9` is range-checked because it is a store like any other, in both
  directions, and neither check is new code.
- The buffer variable is fetched **again for each variable** in one `read`,
  because `get` invalidates the previous one. `tests/typedfiles.pas` pins that
  with a two-variable read; a mutation hoisting the fetch out of the loop
  survived a green suite before it was there.
- **The runtime allocates the buffer**, because its size is T's and its
  alignment must be T's. It is freed at the block exit that already closes the
  file. The compiler alloca'ing it would put the component's size back into the
  compiler's half of an interface whose point is that the storage is opaque.
- The component may be **any type that is not, and does not contain, a file** —
  checked through arrays, fields, and every arm of every variant part.
- A `read` of a structured component is a memcpy, not an aggregate
  `load`/`store`. LLVM accepts the latter and it behaves identically, so no
  test defends this; it is ADR-0017's rule that a structured value has no
  register form, and that rule is what lets both backends share one copy path.

## Decisions

`doc/adr/` holds the architecture decision records. Read them before undoing
something that looks over-complicated — most of the odd-looking choices here are
load-bearing for the bootstrap, and each record says what it costs. Add a record
when a choice constrains future work or deviates from the standard.

## Bootstrap constraints (do not casually violate)

1. **No C++ RTTI in the AST.** `ast.h` tags nodes with `NK` and casts via
   `as<T>(n)` / `is<T>(n)`, where each node declares `static constexpr NK
   NodeKind`. Two reasons: Debian's LLVM is built without RTTI, and the eventual
   Pascal-hosted compiler has no `dynamic_cast` — the tag + variant record is
   what it will use. Adding a node means adding an `NK` enumerator and the
   `NodeKind` member.
2. **Textual `.ll` output stays a first-class path.** A compiler written in
   Pascal cannot call LLVM's C++ API, so `--emit-llvm` is the backend that
   survives the rewrite, not a debugging aid.
3. Prefer C++ that maps onto Pascal — plain structs, tags, explicit control
   flow — over template or exception machinery in the tree walks.

Feature priority follows what a compiler is written in (procedures, records,
pointers, text files, a usable string type), not ISO chapter order. README.md
holds the three-stage plan and the dependency ordering; `doc/roadmap.md`
tracks it.

**All six bootstrap items are now settled**, so the language is finished for
bootstrap purposes — and the bar for a new feature has therefore *changed*
rather than risen. During the bootstrap a feature needed a reason beyond "the
standard has it"; now that is exactly the reason, because the goal is
conformance with ISO 7185, and **that is now complete**.

**Stage 2 has begun** (ADR-0033). `--std=iso7185` is the default and
`--std=extended` is ISO/IEC 10206:1991. The two are *not* nested: Extended
Pascal reserves word-symbols a valid ISO 7185 program may use as identifiers,
and `selfhost/compiler.pas` has a field named `value` — so a source is written
in one language or the other, and the standard is a property of the source.

- **`tests/extended/` is the Extended Pascal corpus**, and the directory is
  what tells every harness which flag to use. `run_test.sh` (via CMake),
  `difftest.sh` and `irtest.sh` each derive it from the path, so the two
  compilers cannot be told different things about one file. The glob is
  **unanchored** on purpose: a file named on the command line arrives relative,
  and `*/tests/extended/*` quietly called it ISO 7185 — which compares two
  identical rejections and passes (ADR-0034).
- **The stage-1 compiler reads the standard from a file** — a third program
  parameter, one word. ISO 7185 gives a program no access to its command line
  beyond its program parameters, and those are files; `compiler.pas` cannot
  take a flag. Same constraint as ADR-0024's one source file.
- **A word-symbol is reserved when the feature needing it lands**, not before.
  Until the list is complete, `--std=extended` accepts some programs a
  conforming processor would reject; that is stated, and each feature closes
  its own part of it.
- `otherwise` (§case-statement) is the first feature, and it retires ADR-0018's
  "ISO 7185 has no `else` and none is invented" — the standard has one now. The
  lowering is unchanged: an otherwise-part is *what the default block holds*.
  A case with no otherwise-part still traps, and `tests/trap_case.pas` is what
  says so.
- **The same word ends a variant part** (ADR-0034): `otherwise (fields)` is the
  arm every tag value the labelled arms leave selects. It is an arm with no
  labels — numbered, pathed and laid out like the rest — so **codegen is
  untouched**, because nothing in the layout ever reads a label. The one place
  that does is `new(p, c)`, where an unclaimed value now selects the completer
  instead of being an error. Nothing may follow it, and the flag is not "the
  label list is empty": a label that fails to evaluate is dropped, and a
  diagnostic must not turn a broken arm into the completer.
- **Exponentiation is a precedence level, and two operators** (ADR-0037).
  §6.8.1 puts `factor = primary [ exponentiating-operator primary ]` between
  `not` and the multiplying operators, so what was `parseFactor` is now
  `parsePrimary` and a factor is the exponentiation level. Under ISO 7185
  neither operator can reach it and a factor *is* a primary, which is why the
  rename is unconditional. The syntax admits **one** operator, so `a ** b ** c`
  is diagnosed rather than associated — §6.8.1's left-associativity rule has
  nothing to apply to when the syntax offers no second operator.
  - `**` yields a **real** however it is written and `pow` yields the type of
    its **left** operand (table 3 of §6.8.3.2). That is the whole reason the
    standard has two, and `i := 2 ** 3` is therefore an error while
    `i := 2 pow 3` is not.
  - A sign takes a whole factor, so `-3 ** 2` is `-(3 ** 2)`. Not taste: a
    negative left operand is an *error* under `**`, so the other reading turns
    a legal expression into a runtime error.
  - All three forms are runtime calls (`pas_pow_real`, `pas_pow_realint`,
    `pas_pow_int`) and carry §6.8.3.2's error conditions with them, so neither
    backend spells a check. Integer `pow` traps on overflow because it *is*
    repeated multiplication — the accumulator is wider than the type, and both
    ends are checked, and `tests/extended/trap_pow_overflow*.pas` are the two
    programs that say so. Neither is the obvious one: a wrap onto a plausible
    in-range value, and an overflow at −maxint−1.
  - The proof rules model `pas_pow_int` — the first time `verify/` describes C
    rather than emitted IR. They establish the *design* (the check fires on
    exactly the powers that leave the type) and cannot see the runtime drift
    away from the model, so the trap programs are not redundant with them.
- **A discriminated schema produces an ordinary type** (ADR-0039). §6.4.7's
  schema is a mapping from discriminant tuples to types; §6.4.8's
  `vector(3)` selects one. The whole feature lives in the parser and Sema —
  codegen gained one line, for `v.n`, and `verify/` gained nothing.
  - **A schema keeps its syntax, not a type.** `Symbol::schemaBody` is the
    type-denoter, re-resolved once per distinct tuple with the discriminants
    bound as ordinary constants. By the time `array [1..n] of real` is
    resolved, `n` *is* a constant — which is why no existing resolver changed.
    The resolution cache is cleared **before** each production; a schema that
    kept the first one would hand the same type to every tuple.
  - **§6.4.8's identity rule is an intern table**, keyed by (schema, tuple).
    Both halves matter: distinct tuples are distinct types, *and* one tuple is
    one type however often it is written. `assignable` gained no case at all,
    which is the test of whether it was encoded in the right place.
  - A produced type **names itself** `vector(3)`, or two productions differing
    only in a discriminant the body never mentions print identically.
  - **Discriminants must be constants.** A stated deferral, not an
    oversight — the ADR's "What this does not do" lists all five.
- **A schematic formal parameter carries its discriminants beside the address**
  (ADR-0040), which is the other half of §6.4.7's summary: `procedure p(var v:
  vector)` takes a vector of any length, and one compiled body serves every
  tuple.
  - The parameter's frame slot is `{ptr, d1, ..., dn}` and it travels as
    **n+1 arguments** — ADR-0030's shape for a procedural parameter's pair, for
    the same reason: nothing depends on how a struct is passed.
  - A discriminant is a **symbol with storage** (`SymKind::Disc`) whose owner,
    level and frame index are the *parameter's*, so `addressOf` reaches it by
    the walk every enclosing variable makes — which is what makes the tuple
    per-invocation rather than per-procedure.
  - The schema body is resolved **once, generically**: the discriminants are
    bound to those symbols instead of to values, and a bound that reaches one
    is recorded on the `Type` as the symbol. `array [1..n] of real` is then an
    ordinary array type whose upper bound is read at run time, so the array,
    index and assignment code needed no case for schemata.
  - **A dynamic bound is a discriminant and nothing else** — not `n - 1`.
    ISO 7185 has no constant-expression, so this is the restriction every other
    bound is already under, not one invented here.
  - A discriminant may bound an array, and an array inside it: `dynSize` is
    `(hi - lo + 1) * dynSize(component)` and an address is
    `base + (i - lo) * dynSize(component)`, in bytes. **Anywhere else it is
    refused** — a record field after a dynamically-bounded one would sit at an
    offset nothing can compute.
  - A **value** parameter is copied on entry into an `alloca` of a computed
    length, because its size is not known until the tuple is in place.
  - **The tuple is compared at compile time**, because every tuple this
    compiler can write is a constant. §6.7.3.3 calls a mismatch a
    dynamic-violation; when non-constant discriminants land it becomes one.
  - **`verify/` gained nothing**, and that is the point: the array rule already
    quantifies over its bounds, so it covers a pair that arrives at run time.
    The span check `resolveArray` cannot make for a dynamic bound was already
    made where the actual's type was produced.
  - Refused, and neither is in the standard's words: an **enumerated type in a
    schema body** (its constants would be declared once per tuple, into a
    scope that dies with the production), and a schema **naming itself**
    outside a pointer domain (§6.4.7 does require this; without it the
    production recurses forever).
- **A word-symbol may be two words** (ADR-0038). §6.1.2 spells the
  short-circuit operators `and then` and `or else` — one word-symbol apiece,
  written as two words. Not `and_then`: there is no underscore in the standard,
  and the roadmap, README and ADR-0033 all said otherwise before this landed.
  - The lexer **joins two tokens**; nothing is added to either keyword table,
    so the feature reserves **nothing** — all four words are already reserved
    in ISO 7185. It is the first Extended Pascal feature costing that language
    nothing lexically.
  - The join is across **any separator**, so a comment or a line break may sit
    between the words. §6.1.10's "no separators shall occur within tokens"
    cannot be applied literally to a token whose reference representation
    contains a space. The leniency cannot change a valid program's meaning:
    `then` cannot begin a factor and `else` cannot begin a term, so the pair
    has no other reading.
  - `AndThen`/`OrElse` are **their own BinOps** although they lower to the very
    same short-circuit code ADR-0010 already gave `and` and `or`. The standard
    only *permits* short-circuiting `and` and *requires* it here; one node for
    both would throw that away. The consequence is that **no program's output
    distinguishes them** — the AST dump and a diagnostic are the only two
    places, which is why `tests/extended/shortcircuit_errors.pas` is the
    load-bearing half of the pair rather than a companion to it.
- **A non-decimal literal is lexical and nothing else** (ADR-0036). `16#ff` reaches the
  parser as an integer literal, so no later rule knows it was written that way.
  Two things the code says and a reader might undo: the extended-digit sequence
  is **maximal** — `16#ffand` is one ill-formed number, not a number and a
  word-symbol, because a letter *is* a digit here — and the overflow is caught
  while accumulating rather than by converting and comparing, because the
  Pascal lexer has no wider type and both must agree where a literal stops
  being one. Under `--std=iso7185` it is consumed and refused, so one
  diagnostic comes out rather than a cascade.
- **A case label is an interval** (ADR-0035). Extended Pascal generalised the
  case-constant-*list*, and both the case statement and a variant name it, so
  `1..9` is legal in either. Sema folds every label to a `LabelRange`, a single
  constant being `lo = hi`, and "this label appears twice" is interval overlap.
  Codegen **tests a range and switches on a constant**: `1..maxint` is a legal
  label list and two billion switch cases, so the cost is the number of ranges
  written, never the number of values they cover. Every arm's block is therefore
  created before the switch, because a range test names it first.
- Telling `otherwise` the construct from `otherwise` the constant is one token
  of lookahead, and it is a *different* token in each place: a case label is
  followed by `:`, `,` or `..` and an otherwise-part is not, while the variant
  completer is followed by `(` and a variant's label list is not.
  `tests/iso_identifiers.pas` pins both legal ISO 7185 programs that depend on
  it. **Anything the standard does not
have still waits**: the second stage targets ISO/IEC 10206:1991 (Extended
Pascal), so an extension should be taken from its spelling rather than
invented here.

Strings are the length-plus-buffer record of ADR-0012, not an extension:
`tests/bootstrap_strings.pas` is the working evidence and the regression test
for it. Don't add a `string` type without new evidence from real stage-1 code,
because measuring the C++ compiler is what showed the extension was
unnecessary — nearly all its string building feeds text that is written out.
Extended Pascal defines a `string` type, so that decision is the one most
likely to be revisited at stage 2 — its reason expires there rather than the
decision being overturned on taste.

## Where things live

`src/lexer.cpp` case-folds identifiers and knows every reserved word of both
standards, even ones the parser rejects — which of them are *reserved* is the
one thing `--std` decides in the lexis (ADR-0033). `src/parser.cpp` is recursive descent shaped like the
ISO grammar (`expression` → `simple-expression` → `term` → `factor`) — note a
leading sign binds to the whole *term*, so `-7 mod 3` is `-(7 mod 3)`.
The parser bounds the depth of the tree it builds at 1000 levels (ADR-0020);
the spine-building loops count their iterations toward the same limit, because
an operator chain is flat for the parser but deep for Sema, CodeGen and the
destructor — a call-depth-only limit would miss it.
`src/astdump.cpp` writes the tree in the format `selfhost/compiler.pas` also
writes, before and after Sema; it is the specification of that format, so
change it and the Pascal side together.
`src/sema.cpp` owns scopes, type rules, type-denoter resolution, constant
folding, and — since ADR-0039 — the schema intern table, which is the one place
a type's *identity* is decided by something other than the denoter that built
it. A type-denoter is a `TypeExpr`, deliberately not an `Expr`, and a
declaration group shares one — which is what makes `a, b: array [1..3] of
integer` the *same* type rather than two alike ones. The one exception is a
parameter group naming a schema (ADR-0040): each name there gets its *own*
type, because each reads its own descriptor. `runtime/pasrt.c`
holds anything not expressible in IR — formatted output and runtime checks —
where `width < 0` / `prec < 0` mean "not given".

Adding a language feature usually touches, in order: `token.h`/`lexer.cpp` →
`ast.h` → `parser.cpp` → `sema.cpp` → `codegen.cpp` → a `tests/` pair, plus
`runtime/pasrt.c` if it needs library support.

`selfhost/compiler.pas` is the stage-1 compiler, written in Afterschool Pascal.
The lexer (ADR-0022), the parser (ADR-0023), Sema (ADR-0024) and CodeGen
(ADR-0025) are all done, and **the bootstrap closes**: the compiler compiles
itself and stage 2 equals stage 3. **It is one source file** — ISO 7185 has no
include mechanism, so each component was merged in as it was ported rather than
kept as a program of its own.

It takes three program parameters: `compiler.pas <source> <ircode> <options>`.
The dumps go to standard output; the IR goes to the second file, because it is
the compiler's *product* rather than a dump and has to be assembled. It is
written on every run, which is what keeps `difftest.sh` exercising the code
generator on all 207 files even though it compares none of it. The third holds
one word, the standard to compile for — ISO 7185 gives a program no access to
its command line beyond its program parameters, and those are files, so there
is no `--std` flag to take (ADR-0033).

**The first three components are checked against `src/`, not against golden
files.** `pascalc
--dump-all` and `selfhost/compiler.pas` write the same three sections
(`=== tokens`, `=== ast`, `=== sema`), and `selfhost/difftest.sh <pascalc>`
diffs them over every `.pas` in the tree, under ctest as `selfhost-compiler`.
If you change what a C++ stage produces, the Pascal one changes in the same
commit or the test goes red — that is the point of it, not an inconvenience.

- There is **no mode argument for the dumps** because there is no second
  binary: the Pascal program runs every stage and dumps all of them. The one
  thing it *is* told is the standard, and that arrives as a file rather than an
  argument for the reason above. Each section reports what its
  own stage found and shows its result only when nothing was found — a stage
  that failed has nothing to show, and the stages after it do not run.
- `--dump-ast` runs **before Sema**, so it shows only what the parser decided,
  and prints `@line:col` only where the tree really records a position.
  `--dump-sema` walks the same tree through the same walker with an `annotate`
  flag, adding the frame layouts, the type of every expression, the frame slot
  every name resolved to, and every record's field/variant numbering. Sharing
  the walker is deliberate: the shape is then the same question asked twice.
- `selfhost/torture.pas` is deliberately **not** a valid program: it carries the
  error paths and lexical corner cases a valid program never reaches. Add to it
  when a lexical rule changes.
- `selfhost/badparse/` is its parser equivalent, spread over one file per
  message because the parser stops at its first error. `selfhost/badsema/` is
  Sema's, and is only thirteen files because Sema *accumulates* errors rather than
  bailing. Add to them when you add a message, and don't assume the corpus
  reaches a branch — **count it**. Every time anyone has, something turned out
  to be uncompared: no file had a tab, no file had a parse error, Sema reached
  48 of its 85 messages, and then sets, congruity, non-text files and the
  non-local goto each had mutations survive a green suite (ADR-0022 to -0024,
  -0028, -0030 to -0032). Don't look for a running total — the records
  disagree, because they are immutable and the count moved on without them.
**CodeGen is the exception, and had to be** (ADR-0025). Two backends' assembler
text is not comparable — the C++ builds an `llvm::Module` and LLVM's printer is
not a specification — so it is checked by *running* what it produces against the
same `tests/*.out` and `tests/*.err` the C++ compiler is held to, and then by
compiling the compiler with itself twice and requiring the results to match.

- The emitter is **sequential**, with no instruction list: the C++ builder never
  returns to a block it has left, so the order it emits in is the order text can
  be printed in. Don't add buffering to "fix" something; if a block needs
  revisiting, that is a change to the C++ side too.
- Types print structurally and inline, because opaque pointers make every Pascal
  type non-recursive once printed. **Activation records are the exception** —
  one would be spelled at every variable access — so they get a name apiece,
  emitted before the first function that indexes one.
- Globals are deferred to the end of the module: a string constant is numbered
  where it is used and its text written after the last function.
- **A real literal is carried as its source text all the way into the IR.**
  LLVM's assembler is the `strtod`. The one adjustment is that LLVM's float
  syntax needs a decimal point where Pascal's `1e6` has none. Three ADRs
  deferred a conversion that turned out never to be needed.
- The layout rules are written out (`LlSize`/`LlAlign`) because there is no
  `DataLayout` to ask. They are needed in exactly two places — a whole-variable
  copy's length and the size `new` allocates. `fileSize` must equal
  `PAS_FILE_SIZE`; `irtest.sh` checks it, because the two files cannot include
  one another.
- **The module states its `target datalayout`**, so the assembler lays things
  out the way `LlSize`/`LlAlign` say it does. It did not, until a set in a
  record segfaulted: LLVM's defaults align an i256 to 8 and the target's to 16,
  and 16-byte moves landed on an 8-aligned frame (ADR-0028). The rules were
  never wrong, only unstated — which is the same thing once something else is
  doing the layout. Don't drop the line.
- `WriteTypeName`/`WriteOrdinalName` write through the `Put` sink, which either
  goes to output or into `msgBuf`. A trap message is a string constant *in the
  generated program*, so it has to be assembled before it is emitted — and a
  second copy of those routines would be a copy free to drift.

## Pascal semantics already encoded (keep them)

`mod` yields a non-negative result (not C's truncating remainder); `and`/`or`
short-circuit; `/` is always real division; `for` evaluates its limit once and
tests `= limit` before stepping so the last iteration cannot overflow; a
one-character string literal is a `char`; and a statement may be **empty**
(§6.8.1), which means every token that can *follow* a statement also starts
one — `;` and `end`, but also `else` and `until`, so `if c then ; else s` is
legal. `tests/empty_statements.pas` pins it.

An array subscript outside its bounds traps (ADR-0017), and a `for` loop over an
array's own bounds optimises the check away; where the bounds arrived with the
actual (ADR-0040) the message is built by the runtime and says the same words. Storing outside a subrange traps,
and so does a `case` whose selector matches no label (ADR-0018) — unless it has
an Extended Pascal `otherwise`, which is the only thing that gives that arm
something to do (ADR-0033) — a dereference of `nil` (ADR-0019), and a set whose
members are not values of the target's base type (ADR-0028).

**ISO error conditions trap** (ADR-0014, ADR-0015). Integer `+ - *` and `sqr` go
through `checkedArith` and stop the program on overflow rather than wrapping —
they carry no `nsw`. `chr` outside 0..255, `succ`/`pred` at the ends of their
type, `div` by zero, `INT_MIN div -1`, and `trunc`/`round` of a real outside the
integer range (or of a NaN) all reach `pas_runtime_error` (stderr, exit 1).
The integer type is **-maxint..maxint**, narrower than the `i32` behind it, so
`INT_MIN` is not a value of the type and a literal above `maxint` is a
compile-time error.

A check is omitted only where its absence is *proved* sound — the `for` step and
unary negation are unchecked, and `verify/` carries the theorems saying they
cannot overflow. Don't add a check there, and don't remove one elsewhere.

Most of these are not merely tested — they are **proved** in `verify/` for every
input. Changing one breaks a theorem, not a sample.

## Formal verification (`verify/`)

`verify/verify.py` proves each lowering rule against a property-style statement
of ISO 7185 using Z3, then cross-checks the real binary at the adversarial
points. It runs under `ctest` and skips when z3 is missing
(`pip install z3-solver`). ADR-0013 has the rationale; `verify/README.md` has the
mechanics.

Three things to know before touching it:

- **`lowering.py` is a model of `codegen.cpp` and must be maintained with it.**
  A drifted model keeps passing and proves nothing. When you change a lowering,
  change the model in the same commit.
- **Specifications state properties, never computations.** Writing `iso.py` so it
  computes the answer the way the compiler does would make every proof circular
  and the circularity invisible.
- **A `KNOWN_GAP` that starts holding fails the build.** That is intentional: it
  means the compiler was fixed and the catalogue is now describing a compiler
  that no longer exists. Flip it to `MUST_HOLD` in the same change.

New arithmetic, conversion, or comparison lowering should arrive with a rule.
The catalogue currently has **no known gaps** — 35 rules, 27 of them for every
32-bit input — so any gap that appears is something this change introduced.

Don't add a rule that restates the lowering. A check whose ISO condition *is*
the emitted test (the nil check) proves nothing and dilutes what "no known gaps"
means. Cross-check or sanitiser-check those instead, and say which in the ADR.

Keep bounds **symbolic** where the lowering treats them symbolically. The array,
subrange and `succ` rules quantify over the bounds as well as the value, so they
say something about every array and every enumeration rather than about a
sampled one; the integer-only `succ` rule they replaced could not have caught
the generalisation because it had `maxint` written into it.

A rule may also state why a check is *unnecessary* (`negation-cannot-overflow`,
`accepted-index-selects-the-right-element`). Those are the ones that pay: the
index rule failed on first run and made Sema reject arrays spanning more than
`maxint` values. When a rule's precondition names a restriction the compiler
enforces, the check and the assumption are the same statement written twice, and
neither can drift without the other failing.

For floating-point rules, state the specification inside FP theory
(`fpRoundToIntegral`, `fpLEQ`) rather than via `fpToReal`: mixing FP and Real
does not solve in practice, and the same property expressed FP-internally proves
in under a second (ADR-0015).
