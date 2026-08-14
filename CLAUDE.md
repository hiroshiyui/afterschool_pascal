# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Afterschool Pascal: an ISO 7185 Standard Pascal compiler with an LLVM backend,
written in C++20 against the LLVM 21 C++ API. The near-term goal is
**self-hosting** — see "Bootstrap constraints" below, which govern design
choices that would otherwise look arbitrary.

## Commands

```sh
# configure -- no LLVM_DIR: nothing links libLLVM since ADR-0085
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release   # needs clang on PATH, nothing else
cmake --build build -j

ctest --test-dir build --output-on-failure
ctest --test-dir build -R control --output-on-failure   # a single case, by name
tests/run_test.sh tools/pascalcc tests/control.pas iso7185   # without ctest
tests/run_test.sh tools/pascalcc tests/extended/otherwise.pas extended
selfhost/irtest.sh build/bin/pascalc-seed   # what pascalc *builds*, and stage 2 = stage 3
selfhost/producttest.sh build/bin/pascalc build/lib   # the built pascalc itself
seed/refresh.sh                             # regenerate the seed (release only)

tools/pascalcc tests/hello.pas -o /tmp/hello && /tmp/hello
tools/pascalcc -S tests/hello.pas -o /dev/stdout   # inspect IR
tools/pascalcc --std=extended prog.pas   # ISO/IEC 10206:1991 instead
```

**There is one compiler, and it does not link.** `build/bin/pascalc` is
`selfhost/compiler.pas`, and it writes IR and stops — no standard Pascal program
can start an assembler. `tools/pascalcc` is where the missing half lives and is
what every harness is handed; anything wanting an executable goes through it.
`build/bin/pascalc-seed` is the same compiler built from `seed/pascalc.ll`, and
exists only to bootstrap: what ships is always built from the source in the tree
(ADR-0085).

Adding `tests/foo.pas` + `tests/foo.out` requires **re-running `cmake`** — cases
are registered by a `file(GLOB)` at configure time, and `tests/` and
`tests/extended/` are globbed separately because they are compiled under
different standards.

`tools/pascalcc` shells out to `clang` to assemble and link (ADR-0009), and
finds `libpasrt.a` beside the compiler; `AFTERSCHOOL_PASCAL_RUNTIME` and
`PASCALC` override where it looks for each, which is how CMake points the tests
at their own build tree.

## Pipeline and its contracts

`Compile` runs: Tokenize → ParseProgram → RunSema → RunCodeGen, and each stage
is guarded by `errorSeen` — a stage that failed has nothing for the next one to
read. Assembling and linking are *outside* the compiler entirely
(`tools/pascalcc`), because no standard Pascal program can start another.

The contract that keeps `RunCodeGen` simple: **Sema leaves every node's `ntype`
non-null and every `nkVar`'s symbol resolved.** CodeGen therefore never inspects
names, never re-derives types, and reports no user-facing errors — if it needs a
fact about the source program, that fact belongs in Sema. On an error path Sema
still assigns a placeholder type rather than nil, so codegen cannot crash on a
half-checked tree.

This was written about `src/codegen.cpp` and holds unchanged for the Pascal one
it was ported to; the C++ compiler is gone (ADR-0085) and the contract is the
thing that survived it. Where a bullet below still names a C++ file, read it as
naming the component: the port is line-for-line enough that the reasoning
transfers, which is what ADR-0022 to ADR-0024 were for.

Most of what Sema hands over is *per node*. Since ADR-0053 one thing is not:
`Sema::activeModules()` is a whole-program answer — which modules supply the
main-program-block, in the order their activations must commence. It is on the
same side of the contract as everything else (Sema decided it, CodeGen only
emits calls in that order), and it is worth knowing that the contract has a
shape other than an annotation on a node.

Errors: the parser sets `aborted` when it cannot make progress, and every
production and loop tests it — Pascal has no exceptions, so what was
`ap::ParseAbort` in the C++ became a flag (ADR-0023). Sema and the lexer instead
accumulate into
`Diagnostics` so one run reports many errors.

**Activation records and static links** (ADR-0016). Every procedure gets a
frame struct alloca'd in its entry block; a **level-0** block — the program, and
since ADR-0053 every module — gets a global instead, because it has exactly one
activation and a module's must outlive the function that fills it in.
Field 0 is the static link to the enclosing block's frame; locals, value
parameters, `var` parameters, and the function result are the remaining fields.

- `frameAt(level)` walks the chain; `addressOf(sym)` walks then indexes. All
  variable access goes through `addressOf`, so there is still no separate
  global path — but it asks for the frame of the symbol's *owner*, and a
  level-0 owner answers with its global without walking. That is what lets a
  module reach the program's `output` and the program reach a module's
  variable, neither of which is on the other's static chain.
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
- The data layout is **stated by the emitted module itself** (`target datalayout`),
  because the size of a record decides what a whole-variable assignment copies
  and the assembler has to lay things out the way `LlSize`/`LlAlign` say it
  does. The C++ compiler asked a TargetMachine; there is no TargetMachine now,
  which is why the line is written out — see the CodeGen section, where ADR-0028
  records the segfault that came of leaving it unstated.

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
  **For a subrange they are the host's**, because §6.6.6.4 gives the result "the
  same type as that of the expression (see §6.7.1)" and §6.7.1 is where the rule
  lives: "any factor whose type is S, where S is a subrange of T, shall be
  treated as if it were of type T". So `succ` of a `1..9` holding 9 is 10, and
  what traps is storing it back. This was wrong in both directions for a long
  time — the compiler trapped, and `tests/trap_succ_subrange.pas` asserted the
  wrong rule in a comment citing §6.6.6.4 without following its cross-reference,
  so every oracle agreed. The BSI suite's CONF139 is what disagreed.
- `checkedForSubrange` is applied where a value *enters* a variable
  (assignment, value parameter, both `for` bounds) and is a no-op for every
  other type, so call sites need no conditional. Nothing between the `for`
  bounds needs a check because the loop never leaves them.
  - **The `for` bounds are checked under the loop's entry test**, not before
    it: §6.8.3.9 requires them to be assignment-compatible with the control
    variable's type *"if the statement of the for-statement is executed"*, so
    `for i := maxint to maxint - 1 do` over an `i : 0..10` is a legal program
    with an empty loop. `NeedsSubrangeCheck` exists so that the guard and the
    check cannot ask the question differently. `tests/for_empty_bounds.pas` and
    `tests/trap_for_bound.pas` are the two halves, and the second was written
    because deleting the check outright passed the whole suite without it.
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
The size lives in `runtime/pasrt.h` as `PAS_FILE_SIZE` and in the compiler as
`fileSize`, in two files that cannot include one another — `selfhost/irtest.sh`
checks they agree, which is the same arrangement the version number has. A
`_Static_assert` fails the build if the struct outgrows it.

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
- Program parameters that are **files** bind to command-line arguments in order;
  `input`/`output` are the standard streams, declared *only* when the header
  lists them, so using `write` without `output` is the error §6.10 says it is.
  A program parameter that is **not** a file is permitted and bound to nothing,
  consuming no argument (ADR-0074) — §6.10 restricts the list to files nowhere.
- Standard input is opened but not read until the program first asks, or every
  program listing `input` would block before its first statement.
- **A file need not be an entire variable** (ADR-0070). §6.5.1's own example is
  `pooltape : array [1..4] of FileOfInteger`, so the prologue walks each
  variable's *type* and prepares every file it holds — a record over its
  fields, an array with a real loop, because a length may be a discriminant's
  and an unrolled run may be enormous. `new` does the same to what it
  allocated and `dispose` closes it. Selecting frame variables by `isFile`
  rather than by "holds a file" left such a file with a zeroed `struct
  pas_file` and segfaulted on the first `f^`, in both compilers and both
  standards, with nothing in the corpus to notice.
  - **A file may not be a field of a variant part**, which §6.4.3.4 permits: a
    file's storage carries a heap buffer and a place on the runtime's
    open-file list, so two arms holding files at one address would leak the
    first buffer and link one list node twice. The one shape where "which
    arm's file is this" has no answer at block entry.
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

**A landed feature is two commits**, and the split is not tidiness: the `feat:`
one, then a `docs:` one that moves the feature out of README's "not accepted
yet" list and into the accepted block, and nothing else. That cadence is what
makes the language's growth greppable from `docs:` alone — `git log
--oneline --grep='^docs'` is meant to read as a changelog of what the compiler
accepts. The rule is written out in `.claude/skills/docs-engineering/SKILL.md`,
which is loaded only when that skill is invoked; it is repeated here because
that is exactly how it came to be missed.

It *was* missed, for the eight Extended Pascal features from `d49bc75`
(protected parameters) through `2ce4c85` (modules): each carried its README
edit inside the `feat:` commit. Those features are documented — the grep is
what is incomplete, not the docs — and the gap is recorded here so the next
reader does not conclude otherwise from an empty search. Don't try to repair it
by rewriting published history.

## Bootstrap constraints (what is left of them)

The bootstrap is over and stage 0 is retired (ADR-0085), so two of the three
constraints below constrain nothing any more. They are kept because they explain
the shape of `selfhost/compiler.pas`, which a reader will otherwise find
arbitrary.

1. **No C++ RTTI in the AST** — *historical*. `ast.h` tagged nodes with `NK` and
   cast via `as<T>(n)`, because Debian's LLVM is built without RTTI and because
   the Pascal compiler has no `dynamic_cast`. That is why the AST here is a tag
   plus a variant record, and why the port needed nothing redesigned.
2. **Textual `.ll` output stays a first-class path** — *live, and more so*. It
   was the backend that had to survive the rewrite; it is now the only backend,
   and `seed/pascalc.ll` makes it what lets this repository build itself.
3. **Prefer constructs that map onto Pascal** — *satisfied by construction*.
   There is no other language here to prefer them over.

Feature priority follows what a compiler is written in (procedures, records,
pointers, text files, a usable string type), not ISO chapter order. README.md
holds the three-stage plan and the dependency ordering; `doc/roadmap.md`
tracks it.

**All six bootstrap items are now settled**, so the language is finished for
bootstrap purposes — and the bar for a new feature has therefore *changed*
rather than risen. During the bootstrap a feature needed a reason beyond "the
standard has it"; now that is exactly the reason, because the goal is
conformance with ISO 7185.

**ISO 7185 is complete** — and the last four arrived only because someone went
looking, in two separate rounds. §6.6.5.4's `pack`/`unpack` and §6.9.5's `page`
were *missed*, not declined, while three separate documents asserted
completeness: the names were in `isRequiredName` so §6.6.3.7 could refuse
passing one as a parameter, and nowhere else. Then §6.3's **string constant** —
`const s = 'hello'`, refused under both standards — was found the same way
hours after the tag was moved to say the standard was done (ADR-0068).

No corpus program had ever written any of the four, so every oracle agreed. The
lesson is about the oracles rather than the gaps — a claim no test names is a
claim nothing checks (ADR-0067) — and the second round is the evidence that
learning it once is not enough. **Before asserting completeness of anything,
compile a probe for the clause.**

ADR-0080 is that rule applied to the list that broke it: all 94 of
ISO/IEC 10206:1991's required identifiers (Annex C) are probed by
`tests/extended/required_identifiers.pas`, one program using every one of them
for its purpose. It is the first sweep here to find nothing — and its own first
design would have reported a false all-clear, because it asked whether a name
*resolves* rather than whether it works, which is the same mistake that let
`pack` and `page` sit in `isRequiredName` with no implementation behind them.

**Stage 2 has begun** (ADR-0033). `--std=iso7185` is the default and
`--std=extended` is ISO/IEC 10206:1991. The two are *not* nested: Extended
Pascal reserves word-symbols a valid ISO 7185 program may use as identifiers —
so a source is written in one language or the other, and the standard is a
property of the source.

- **`selfhost/compiler.pas` is itself an Extended Pascal source** (ADR-0082),
  which reverses the example ADR-0033 gave: it *had* a field named `value`, and
  that one identifier was quoted here for a long time as the reason the stage-1
  compiler was ISO 7185. Renaming it and `bindable` — by *token position*, not
  by text, since both words also appear in the keyword tables the lexer matches
  against — was the whole of the conversion, and the token stream and Sema dump
  were byte-identical under the two standards before the harnesses were told.
  The reason to do it is ADR-0081: only Extended Pascal lets a program read its
  own command line, so only an Extended Pascal compiler can take a flag.

- **`tests/extended/` is the Extended Pascal corpus**, and the directory is
  what tells every harness which flag to use — except where a `name.std`
  sidecar overrides it, which is how `selfhost/compiler.pas` says it is
  Extended Pascal from outside that directory (ADR-0082). `run_test.sh` (via CMake),
  `irtest.sh` and `producttest.sh` each derive it from the path, so none can be
  told a different thing about one file. The glob is
  **unanchored** on purpose: a file named on the command line arrives relative,
  and `*/tests/extended/*` quietly called it ISO 7185 — which compares two
  identical rejections and passes (ADR-0034).
- **`tests/extended/components/` holds §6.13's separately translated
  components**, and the subdirectory is load-bearing: the CMake glob is not
  recursive, so a source declaring no program is never registered as a case
  that fails to run. A case that needs one lists it in `name.components`, one
  path per line relative to the case's own directory, and `run_test.sh` and
  `irtest.sh` each translate it separately and link the objects.
  - `irtest.sh` skips a source with **no `.out` and no `.err`**, which is what
    keeps a component from being run as a program. Selecting by "the C++
    compiler rejected it" stopped working the moment a component became
    something the C++ compiler accepts.
- **The stage-1 compiler reads the standard from a file** — a third program
  parameter, one word. ISO 7185 gives a program no access to its command line
  beyond its program parameters, and those are files; `compiler.pas` cannot
  take a flag. Same constraint as ADR-0024's one source file.
- **A word-symbol is reserved when the feature needing it lands**, not before —
  so until the list was complete, `--std=extended` accepted some programs a
  conforming processor rejects. **It is complete now**: §6.1.2 adds thirteen
  word-symbols to ISO 7185's, `restricted` (ADR-0058) was the last, and
  `and then`/`or else` are reserved by the lexer joining two tokens rather than
  from a table (ADR-0038). Nothing still unimplemented needs a fourteenth — the
  time procedures are required *identifiers*, which §6.1.3 makes shadowable.
  So the lexis is complete even though the language is not.
- `otherwise` (§case-statement) is the first feature, and it retires ADR-0018's
  "ISO 7185 has no `else` and none is invented" — the standard has one now. The
  lowering is unchanged: an otherwise-part is *what the default block holds*.
  A case with no otherwise-part still traps, and `tests/trap_case.pas` is what
  says so.
- **The `;` before `otherwise` is optional**, in both the case statement
  (§6.9.3.5) and the variant part (§6.4.3.4): each writes the completer as
  `[ [ ';' ] ...completer ]`, and §6.9.3.5's own Example 1 omits it. Both arm
  loops broke out when a `;` did not follow, so the standard's own example was
  a syntax error until the grammar sweep compiled it. Under ISO 7185
  `otherwise` is an ordinary identifier and never that token, so testing for
  the word-symbol costs that standard nothing —
  `tests/extended/otherwise_nosemi.pas` is the example transcribed.
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
    `base + (i - lo) * dynSize(component)`, in bytes. Since ADR-0045 it may
    also bound a record's **last** field; anywhere else it is still refused.
  - A **value** parameter is copied on entry into an `alloca` of a computed
    length, because its size is not known until the tuple is in place.
  - **The tuple is compared at compile time**, because every tuple this
    compiler can write is a constant. §6.7.3.3 calls a mismatch a
    dynamic-violation; when non-constant discriminants land it becomes one.
  - **`verify/` gained nothing**, and that is the point: the array rule already
    quantifies over its bounds, so it covers a pair that arrives at run time.
    The span check `resolveArray` cannot make for a dynamic bound was already
    made where the actual's type was produced.
- **A discriminant may be evaluated when the block is entered** (ADR-0041),
  which is §6.2.3.2 and the deferral ADR-0039 called the one that mattered.
  `var s: vector(n)` is ADR-0040's descriptor with the tuple *computed* on
  entry instead of brought by a caller, so `Symbol::discExprs` is the whole of
  the difference between the two.
  - The prologue evaluates the discriminants, stores them, checks them, and
    `alloca`s the storage they size — in that order, because everything after
    the store asks the *descriptor* and not the expressions that filled it, and
    because a discriminant may name a parameter.
  - **§6.2.3.2's position is the whole of the permission.** `resolveType`
    withdraws the offer before it recurses, so a non-constant discriminant is
    refused in a component, a field, a pointer domain and a type definition —
    including one written *inside a schema body*, which is the case the flag
    exists for and the one a corpus only has on purpose.
  - **A tuple is checked where it is chosen.** ADR-0040 argued a schematic
    formal needed no run-time check because the actual's tuple had been checked
    when its type was produced; that argument only holds if *every* tuple is,
    so two checks are made on entry — a discriminant outside its own type
    (`checkedForStore`, the same words a subrange always uses) and an index
    range left empty (§6.4.7 NOTE 2, one comparison per dynamic dimension).
  - **A variable cannot be one of its own discriminants.** Its name is in scope
    by then — Pascal scopes to the block, not to the point of declaration — so
    without a word about it `v: vector(v)` compiles and reads an unwritten
    descriptor.
  - `var a, b: vector(n)` gives each name its own type, where `var a, b:
    vector(3)` gives them one. The only place a declaration group does not
    share a type, and the reason is that each has its own descriptor.
  - Refused, and neither is in the standard's words: an **enumerated type in a
    schema body** (its constants would be declared once per tuple, into a
    scope that dies with the production), and a schema **naming itself**
    outside a pointer domain (§6.4.7 does require this; without it the
    production recurses forever).
- **An assignment between two schematic types compares the tuples**
  (ADR-0042), and that is the *whole* of the feature: §6.4.6 a) is "the same
  type" and §6.4.8 makes one schema with one tuple one type, so `assignable`
  decides only that both came from one schema and CodeGen decides the rest.
  §6.4.6 d) makes a mismatch a **dynamic-violation**, and §6.1's f) permits
  reporting one either at preparation time or during execution — which is why
  `vector(3) := vector(4)` is still a diagnostic and nothing was weakened to
  make room for the run-time check.
  - **Every discriminant is compared**, not the ones a bound used: identity is
    keyed on the whole tuple, so the walk is over the *schema's* discriminant
    list rather than the array's `loDisc`/`hiDisc`.
  - **Either side may be a constant.** `discValue` answers "the k'th
    discriminant of this type's tuple" from the descriptor for a generic type
    and from the `Type` for every other, so the known tuple may be on the left
    as easily as the right. A version that took the run-time path only when the
    *destination* was generic is the mutation to remember — it copies the right
    number of bytes and simply never asks whether the source was that type.
  - Once the tuples agree the copy is ADR-0017's whole-variable one, with
    `dynSize` as its length and the **component's** alignment, because the
    array type has no extent to give.
- **A heap variable's tuple is a header in front of it** (ADR-0043). §6.4.4's
  domain-type may be a bare schema-name and §6.7.5.3's `new(p, d1, ..., ds)`
  supplies the tuple, so the created variable has no activation record to keep
  a descriptor in.
  - **The pointer denotes the variable, not the block.** That is the whole
    reason the feature is small: `p^` is the address `p` already was, so
    pointer assignment, comparison with nil, the nil check on a dereference
    and ADR-0019's "every pointer type is `ptr()`" are untouched, and only
    `new` and `dispose` know a header is there.
  - A discriminant is one `i32` whatever its type and the header is rounded to
    **16**, because `malloc`'s alignment has to survive to the variable — a set
    is 256 bits aligned to 16, which is ADR-0028's segfault again.
  - **The bounds are found by walking *down* a designator** to the whole
    variable it selects from. One header serves every dimension, and an inner
    subscript's base is a component's address, so it cannot compute the header
    from what it has.
  - **Inside `new` the bounds come from the argument values**, because the size
    is asked of the tuple before there is anywhere to put it. Not a shortcut:
    the Pascal emitter is sequential and cannot put an `alloca` in the entry
    block afterwards, so scratch storage would grow the stack for a `new`
    inside a loop.
  - The two forms of `new` are told apart by **the domain and nothing else** —
    a record with a variant part selects variants, a schema domain gives a
    tuple, and the argument lists are indistinguishable.
  - `dispose` of nil traps **only** for a schema domain: §6.6.5.3 always made
    it an error, and stepping back over a header is what turned a harmless one
    into a free of an address that was never allocated.
- **A discriminant may be the variant-selector** (ADR-0044), which is §6.4.3.4's
  third form of one and the last of ADR-0039's five deferrals. The selector is
  then **not a field** — §6.4.3.4 makes it one only when a tag-field names it —
  so it has no storage anywhere, the tuple is the only place the value exists,
  and `v.k` already reads that. **CodeGen, `verify/`, the parser and the lexer
  are untouched**: the layout is a tagless `case T of`, which has been emitted
  since ADR-0018.
  - §6.4.3.4's dynamic-violation is enforced **by construction**. No designator
    denotes the selector, so nothing can attribute another value to it — which
    is why this feature adds no runtime error where the three before it each
    added two.
  - The two forms are told apart by **the symbol, not the syntax**: `case k of`
    is a tag-type when `k` names a type and a discriminant-identifier when it
    names a discriminant, so Sema asks *before* resolving the denoter — as a
    type-denoter the name would be reported unknown. `Symbol::discBinding` is
    what it asks, and the *kind* cannot answer: a production with a tuple binds
    each discriminant as an ordinary `Const`. Set in **two** places, because
    ADR-0039 resolves a body by binding values and ADR-0040 by binding `Disc`
    symbols; either going unmarked is caught.
  - A **tag-field is refused** with this form. It would be a second place to
    keep a value the tuple fixes, and one the program could then assign.
  - **`new(p, c1, ..., cn)` may not select such a variant part** (§6.7.5.3
    requires a tag-type of every one it selects), and the check is per variant
    part rather than per record — an outer tag-selected part is selectable and
    a discriminant-selected one nested in the arm it chooses is not.
  - Where this meets ADR-0043 the two readings of `new(p, round)` agree, but
    only because that record decided the form is chosen by the domain and by
    nothing else. Decided by the arguments, this is the program that would have
    made it ambiguous.
- **A record may hold a dynamically bounded array, last** (ADR-0045) — the
  other half of ADR-0040, and the shape the required schema `string` has: a
  length beside a buffer whose capacity is the discriminant.
  - The rule is the exact boundary of ADR-0040's own sentence: **every offset
    inside the type must stay a constant while the size need not.** A field
    after a dynamically-sized one has an offset that is not; there is no field
    after the last. `Sema::dynamicTail` is that sentence, and it replaced the
    walk-the-array-spine-then-ask-`staticThroughout` pair.
  - **LLVM already had the representation.** A dynamically bounded array is
    `[0 x T]` (ADR-0040), so such a record is a flexible-array-member struct:
    `getStructLayout` gives every field's offset, and **`fieldAddress` is
    untouched**. No byte arithmetic was added anywhere.
  - **`dynamicExtent()` reads `fields.back()`, not "any field"**, and the
    asymmetry is deliberate: a record with a dynamic field elsewhere is not a
    type with a dynamic extent, it is a type that is *refused*.
  - The size is **rounded up to the record's alignment** — an array of them
    strides by it, so 4 + cap content bytes at 4-byte alignment must stride 12
    for cap = 5 and not 9. The one piece of arithmetic that is new rather than
    reused.
  - A **variant part is refused**, and that clause is not implied by the field
    clause: a *tag-field* is an ordinary field and lands after the dynamic one,
    but a **tagless** `case T of` contributes no field at all and would be
    accepted without it. Two mutations needed tests written for them, and both
    are of that kind — the other is a record with *two* dynamic fields, since a
    static field after a dynamic one already fails the last-field question.
- **A protected parameter is a rule about the body** (ADR-0046). §6.7.3.1's
  `protected` is a Sema-only flag on the parameter's symbol: the calling
  convention is untouched and CodeGen never reads it.
  - **§6.5.1 is the whole enforcement** — "no statement shall threaten a
    variable-access closest-containing a protected variable-identifier" — and
    every entry on §6.9.4's list of threats is a place this compiler had
    already decided the argument was a variable, so each check sits beside an
    existing `isDesignator` test. "Closest-containing" is the walk
    `baseSymbol` already made.
  - **Protection forwards.** §6.9.4 b) threatens an actual var parameter only
    when the *formal* is not protected, which is what makes the word usable at
    all, and §6.7.3.6 ("either both contain protected or neither") is what
    keeps a procedural parameter honest about it — symmetric on purpose.
  - **`new(p)` needs no check**: §6.4.1 makes a pointer type unprotectable, so
    nothing reaching it can be protected. Enforced by construction, as
    ADR-0044's dynamic-violation is, and the code says so where the check
    would have gone.
  - A **`with` carries the protection onto its hidden binding**, because that
    is where the protected variable's name stops being written down.
- **A type-inquiry hands back a type that already exists** (ADR-0047).
  §6.4.9's `type of x` resolves to the `Type *` the named symbol holds and
  builds nothing. That is what the clause asks for, not a shortcut: ADR-0017
  makes two structured types the same only when one identifier denotes both,
  so a type-inquiry that *built* an alike type could not be assigned from the
  original. CodeGen and `verify/` are untouched, because nothing records that
  a second name arrived at the type this way.
  - It **reserves nothing** — `type` and `of` are ISO 7185 word-symbols
    already, the second such feature after `and then`.
  - Its **parameter form needed no new lookup**: `declareProcHeading` pushes a
    scope before building the formals, so `procedure p(var a: point; b: type
    of a)` finds `a` by ordinary lookup. A side list of the parameters built
    so far was written and then deleted for that reason.
  - Refused: `x: type of x` (§6.7.3.1), checked *before* the names are
    declared or the name finds itself; and an object that is a **schematic
    formal**, whose bounds are in a descriptor belonging to that one parameter
    — a second name would share the descriptor, not the type, which is a
    different mechanism.
  - **Where a parameter-identifier object may live is not enforced**, and the
    deviation is permissive: ordinary lookup lets a procedural parameter's own
    list see the enclosing list's parameters, which §6.4.9 does not allow.
- **An initial state belongs to the type-denoter** (ADR-0048). §6.6's `value`
  hangs off the type-denoter (§6.4.1), not the declaration — so a **type-name
  hands it on** to every variable of that type, and it is recorded on the type
  *symbol* rather than on the `Type`, which is shared and name-equivalent.
  - **Attributed at every activation** (§6.2.3.5), so a recursive procedure's
    local is created in its initial state on each call. It is a prologue
    beside ADR-0041's and ADR-0021's, and `emitStore` does the storing — so a
    subrange initialised out of range traps where it always would.
  - **Nonvarying (§6.8.2) is about what the expression reads**, not what the
    compiler folds: §6.6's examples are `ord(red)` and `polar(exp(1.0), pi)`.
    What survives is emitted where it stands, so no constant representation
    was added.
  - **Only one reading parses.** The three permitted positions — a variable
    declaration, a type definition, a record field — call `parseTypeExpr`;
    every nested denoter calls `parseTypeDenoter` and stops before the word,
    or `set of 1..9 value [2]` would attach it to the base type. That is what
    makes §6.6 NOTE 3's `array [1..8] of char value '*'` a type error.
  - A record's fields may each carry one, so the prologue recurses over
    fields; it does not recurse into an array, because §6.4.3.2 forbids a
    component-type from carrying one.
  - Refused, both stated: a **component-value that is not an expression**
    (§6.8.7's array- and record-values are the structured-value-constructor
    feature), and a field of a **variant part**, whose initial state §6.5.1
    makes conditional on the selector.
  - `value` is a word Extended Pascal *adds*, so no `--std` test is possible
    in the parser — under ISO 7185 the token never appears. Contrast ADR-0047.
- **`complex` is a simple type, and therefore a vector** (ADR-0049).
  §6.4.2.2 e) makes it *simple*, so a complex is a value — assigned with a
  store, passed in a register, returned from a function — and none of
  ADR-0017's by-address machinery touches it, exactly as for a set.
  - **`<2 x double>`, not a struct**, for ADR-0030's reason: nothing may
    depend on how a struct is passed. Three functions (`reOf`, `imOf`,
    `makeComplex`) are the whole interface to the representation, which is
    what makes §6.4.2.2's NOTE 4 — the representation is
    implementation-defined — free to honour.
  - **The arithmetic is inline and only the transcendentals are calls**, and
    each of those is **two** calls, one per part, so that no complex-shaped
    value ever crosses the C boundary. §6.7.6.2's principal values are C99's,
    so `csqrt`/`clog`/`catan` are called rather than re-derived.
  - **The first feature gated in Sema rather than the lexer.** `complex`,
    `cmplx`, `polar`, `re`, `im` and `arg` are required *identifiers*, not
    word-symbols — a valid ISO 7185 program may declare them, and
    `tests/complex_redeclared.pas` does. `Sema` therefore takes a `Std`.
  - `abs` and `arg` of a complex yield a **real**, the two places table 2's
    result kind does not follow its operand; §6.8.3.5 gives complex only `=`
    and `<>`; `write` and `read` refuse it through the message that was
    already there for every type not on §6.10.3.1's list.
- **A direct-access file is the sequential one plus a position** (ADR-0050).
  §6.4.3.6's `file [T] of C`: the index-type in brackets is the whole of the
  syntax, and one number is the whole of the mechanism — ADR-0031's machine
  with a position added, and one flag on `struct pas_file`.
  - **Counted in components, never bytes**, and the **lower bound is folded in
    the compiler**: `SeekRead(f, 'c')` on a `file ['a'..'z'] of T` reaches the
    runtime as 2, so the runtime needs no notion of an ordinal. The same
    division of labour ADR-0017 gave indexing.
  - `position`/`LastPosition` yield a value of the **index type** (§6.7.6.6's
    "a result of type T"), which is why `Type::indexType` is kept for a file.
  - **Seeking one past the last component is legal** — the append position,
    and §6.7.5.2's pre-assertion says so explicitly.
  - **Update mode has one door**, `SeekUpdate`; `update(f)` then writes the
    buffer variable back *without advancing*, which is what makes
    read-modify-write expressible. A direct-access file's stream is opened for
    reading *and* writing so that door needs no reopen.
  - **ADR-0021's lookahead became observable**: after a fill the stream is one
    component ahead of the program, so `position`, `update` and a mid-file
    `put` each step back. The only genuinely new subtlety in the feature.
  - Not checked: §6.4.3.6's length bound (`file [1..10]` may hold eleven
    components), stated in the ADR rather than silently omitted.
- **A string value is a pointer and a length** (ADR-0051). §6.4.3.3's string
  types, and the third time this project has reached for ADR-0030's
  two-scalar shape — nothing may depend on how a two-word value is passed.
  - **`substr` and `trim` copy nothing** — a pointer into the string they came
    from and a shorter length. Only `+` makes new characters, from a ring in
    the runtime whose one limit (a single *statement* concatenating more than
    it holds) is stated rather than silently wrong.
  - **A variable-string is `{ i32, [cap x i8] }`** — ADR-0045's
    flexible-array-member record — so `dynSize` needed nothing and
    `procedure p(var s: string)` is ADR-0040's descriptor with the capacity as
    its discriminant. The **required schema has no body**: the production
    builds the type rather than resolving a denoter.
  - **The canonical-string-type is that kind with a negative capacity**: no
    storage, so nothing to exceed. §6.4.6 checks a *value's length* against the
    destination's capacity, which is why a string assignment is a runtime
    operation and `isStructured()` excludes a variable-string — the same
    exclusion a file has, for the same reason.
  - **A literal is its own characters and its own length, checked first.**
    `''` is the null-string, has the canonical type, and reading a length in
    front of characters that are not there is what happens without that line.
    Both compilers had that bug for one test run.
  - **Two comparisons, never unified**: §6.8.3.5's operators pad the shorter
    operand with spaces; §6.7.6.7's `EQ`/`LT` family compares lengths as well.
    NOTE 3 says "LT(a,b) could be false and a<b true", and the test prints
    both.
  - It **retires ISO 7185's equal-length comparison rule** and the trap
    `9b72539` added — see `tests/extended/schema_string_compare.pas`, which
    now shows the padding.
  - Deferred, all stated in the ADR: substring *variables* (§6.5.6 as an
    lvalue), `readstr`/`writestr`, a string function result, and §6.10.3.6's
    zero/truncating field widths. **All four have since landed** — ADR-0057,
    ADR-0060, ADR-0055 and ADR-0064 respectively — so nothing on that list is
    outstanding; the third needed no string-specific work at all, a result
    living in memory being the caller's storage.
- **Binding is a file name chosen while the program runs** (ADR-0052).
  §6.7.5.6's `bind`/`unbind`, §6.7.6.8's `binding`, §6.4.3.4's `BindingType` —
  the feature ADR-0051 unblocked, since that record's `name` field needs "an
  implementation-defined variable-string-type".
  - **A bound file is a program parameter that named itself**: `pas_external`
    gained a third answer beside "argument n" and "a scratch file", so
    `reset`, `rewrite` and `extend` needed no change. It is the one thing ISO
    7185 could not express — §6.10 binds the parameters before the program
    starts.
  - **`bindable` belongs to the type-denoter and a type-name hands it on**
    (§6.4.1), which is why `type btext = bindable text` is how a bindable
    *parameter* is written: `text` is a required identifier and never is.
    `bindableOf` is `initialStateOf`'s shape.
  - **`binding(f)` is built in a hidden frame slot** — the `with` mechanism —
    because it is the only required function returning a record and this
    compiler returns none. The call is then a designator, so `b := binding(f)`
    and passing it by value need no cases.
  - `bind` ignores `b.bound` and never writes back to `b` (NOTES 3 and 4);
    only `binding` reports the result. Trailing spaces are trimmed from the
    name, because a fixed-string value arrives padded.
  - **It exposed a backend disagreement**: the Pascal `LlSize` for a string was
    unrounded, so a record's next field fell outside a whole-record copy.
    `irtest` caught it as a wrong answer — two backends can agree on every
    dump and still disagree about a number no dump prints.
  - Refused, all stated: binding anything but a file, a variable-string as a
    *value* parameter (it would have to convert its argument), and
    `binding(f).bound` written directly (§6.8.6's function-accesses) — the
    last of which **ADR-0056 retired**, and it needed nothing of its own,
    because a call already yielded an address.
- **A level-0 activation record is a global** (ADR-0053), and that one sentence
  is the whole of what §6.11's modules cost the code generator. A module has
  exactly one activation (§6.2.3.6) and it must outlive the function that
  commences it, so its frame cannot be an alloca; the main program is in the
  same position, so the rule is stated for *level 0* and its frame became a
  global too.
  - **`addressOf` asks the owner, not the level.** A level-0 owner answers with
    its global, which is the only way an imported variable can be reached: a
    module's static chain says nothing about the program's frame and the
    program's says nothing about any module's. ADR-0016's "no separate global
    path" still holds — there is one `addressOf` and it still answers for every
    variable; what moved is where the walk stops.
  - **Written order is a legal activation order and no sort produced it.**
    §6.2.2.9 already requires a module-heading to precede everything importing
    its interface, so a supplier is textually first — which is exactly
    §6.2.3.6's condition. Finalizations run in the reverse. Two modules *can*
    still supply each other, through a **split** module — A's heading supplies
    B and B supplies A's block, a later component (§6.11.1 NOTE 2) — and
    §6.11.1 then forbids an initialization- or finalization-part in either,
    which is the one thing enforced by a reachability check rather than by the
    text's order.
  - **Only the modules that supply the main-program-block are activated**, and
    supplying is transitive (§6.2.2.13). This matters rather than being a
    nicety: an unactivated module's initialization-part could write to output.
  - The module initializations are emitted **after the program's own file and
    initial-state prologue**, not before it. No module can observe that
    prologue — the program exports nothing — but §6.11.4.2 requires `output` to
    be open before the first access, and opening it is what the prologue does.
    A module writing at initialization time is the program that says so.
  - **A heading in a module-heading is `forward` under another name**
    (§6.11.1), so `declareProcHeading` was reused unchanged and only the
    diagnostic is new. **An interface is a table, not a scope** (§6.2.2.2), so
    exporting changes nothing about visibility inside the module. **A module's
    heading and block share one scope** (§6.2.2.12), kept between components.
  - **A qualified name is told from a field selection by the symbol**, as
    ADR-0044's variant-selector is. The one place the parser can decide is a
    call: `a.b(` has exactly one reading, because ADR-0030 left no procedure
    type in the type part and so no record field is ever followed by `(`.
  - **An imported variable is a copy of the symbol; everything else is
    shared** — the spelling and the protection belong to the import, and the
    copy names the same storage because owner, level and frame index are what
    an address is computed from.
  - Five word-symbols, not seven: §6.1.5 and §6.1.6 make `interface` and
    `implementation` *directives*, which are identifiers exactly as `forward`
    is. `tests/module_iso.pas` uses all five reserved ones as variable names.
  - Refused and stated: a module variable with computed discriminants (its
    activation outlives the stack the storage would be on), and a
    module-parameter that is not `input`/`output` is bound to nothing
    (§6.11.1 NOTE 6). This record also deferred **separate compilation of
    program-components**, which ADR-0079 has since done — see below.
- **An interface is a set of names** (ADR-0079). §6.13's separately translated
  program-components, and the last clause of ISO/IEC 10206:1991. The artefact
  ADR-0053 said would have to be invented is the **module-heading**: §6.11.1
  already makes it the whole of what a module exports, it is written in Pascal,
  and so `--import` reads another component's *source* and no second file
  format exists. An `.ll` could not serve — IR has no Pascal type system and no
  representation for ADR-0017's name equivalence, being the product rather than
  the interface.
  - **Nothing numbered may cross the boundary**, which is the whole cost. A
    procedure was `p.<name>.<counter>` and a variable a frame index, and both
    are facts of *one* translation — a frame's layout is decided by the
    module-**block**, the half a separate translation does not have.
    `Sema::nameForLinkage` derives a name from the heading alone, per
    *interface* rather than per constituent, because §6.2.2.2 makes interfaces
    disjoint and two modules may both export a `tally`.
  - **An exported slot is named with an alias.** The record stays internal and
    keeps its layout private; each reachable slot gets an external symbol
    beside it at no run-time cost. `nm` on a component is then its interface.
  - **`input`/`output` carry fixed names** (`pas.input`, `pas.output`), being
    the one thing a module reaches that the *program* declares. Fixed rather
    than derived: §6.10 and §6.11.4.2 make them one per program however it was
    divided. Nothing is emitted under ISO 7185.
  - The stage-1 compiler takes the other components as **one more program
    parameter, concatenated** — ADR-0033's constraint a third time — and that
    costs nothing to define, a sequence of program-components being exactly
    what a source file already is.
  - **The two compilers' objects are interchangeable**, which is a sharper
    statement than either passing its own tests.
  - Not done and stated: no staleness check (an edited heading relinks
    cleanly), no search path, and a heading's errors are reported once per
    importing component.
- **A constant-expression is one folder and every context follows**
  (ADR-0054). §6.8.2 makes `constant-expression = expression`, replacing the
  one-token `constant` ISO 7185 §6.3 and §6.4.2.4 each asked for. `evalConst`
  already served the constant definition and `evalOrdinal` — a wrapper on it —
  already served subrange bounds, array bounds, case labels, variant labels and
  a schema's discriminants, so the grammar was added to that one function and
  all six opened at once. No caller changed except to say less.
  - **Folding is gated on the standard, in the folder.** Everything ISO 7185
    admits folds under both; `Binary` and `Call` fold only under
    `--std=extended`, so the ISO 7185 diagnostic is unchanged — the expression
    still fails to fold and the caller still says what it always said. That
    gate is invisible to a corpus whose ISO program dies at a *parse* error
    first, which is why `tests/constexpr_iso_fold.pas` has no subrange in it.
  - **A folded operator must answer what the emitted one answers**, and the
    two that can disagree are the two where C differs from Pascal: `mod` is
    non-negative and `odd` is the low bit. A leading sign binds to the whole
    term, so a negative left operand has to arrive by name — `down mod 3`,
    never `-7 mod 3`.
  - **An error found while folding is a diagnostic, and the vaguer message is
    suppressed.** Failing to fold has two unrelated causes wanting different
    words: not constant (the *context* says so) or constant and wrong (only
    the folder can). `constReported_` is which, and without it the second is
    reported twice.
  - **`succ` tests the end before it steps**, because at `maxint` the step
    itself overflows and the Pascal-hosted folder has no wider type to
    range-check in afterwards.
  - The parser changed in **one** place: a bound is no longer two tokens from
    the `..`, so `looksLikeSubrange` scans for one at bracket depth zero. A
    schema production is the only name-led denoter with brackets and a set
    constructor the only way a `..` gets inside them, which is what
    `tests/extended/constexpr_errors.pas`'s `vec([1..3])` pins.
  - Refused and stated: real-, set- and string-valued constant-expressions.
    ADR-0025 carries a real literal as its *source text* into the IR, so
    neither compiler has a float to fold with — refusing in both beats folding
    in one, the same trade the real-literal range check made. What is refused
    is an *operation*: since ADR-0068 a bare string literal is a constant, and
    always was one in ISO 7185 §6.3, because there is nothing to compute. Bare
    `nil` is the same shape and took until ADR-0075.
- **A result that lives in memory is the caller's storage** (ADR-0055).
  §6.7.2 lets a function return anything that is not, and does not contain, a
  file and is not bindable — so a record, an array and a set. ADR-0017 gives a
  structured value no register form and the callee's frame dies at the return,
  so the caller supplies the storage and its address travels as a hidden
  argument after the static link; the function returns void.
  - **The mechanism already existed.** ADR-0052 built `binding(f)`'s record in
    a hidden frame slot because it was "the only required function returning a
    record, and this compiler returns none". `Call::resultSlot` is unchanged;
    a second thing now uses it. Per *call site*, not per callee, so `f(g(x))`
    and a call in a loop each get their own — and recursion needs nothing,
    since each activation brings its own frame.
  - **The callee binds the address as a `var` parameter does.** `resultVar`
    becomes a `VarParam` and the prologue stores the incoming pointer in its
    slot; `addressOf` dereferences it without being told why. Assignment,
    whole-variable copying, subscripting and field selection over a result
    therefore needed *nothing*. `CodeGen::signature` is the one place the shape
    is decided, as `appendParamTypes` is for the middle of it.
  - **Both halves of §6.7.2 arrive together**, because §6.8.2.2 makes every
    *read* of a function identifier a recursive call. Without a
    result-variable-specification (`function mk(a, b: integer) = r: point`) a
    structured result could be assigned whole and never built a field at a
    time. The name is one scope entry pointing at `resultVar` — the same
    symbol the function identifier assigns to.
  - **The two rules about writing the result are exclusive**, so one flag
    answers both: with a result variable the function identifier may not be
    assigned, without one it must be assigned at least once. The second is
    ISO 7185 §6.6.2's rule too, and adding it **found a real bug in
    `selfhost/compiler.pas`**: `ParseTypeDenoter` ended with `ParseTypeExpr :=
    t`, assigning a *sibling* function's result and never its own, through a
    green suite and a closed bootstrap. Don't weaken the check.
  - A refused result type suppresses the never-assigns message — the body
    cannot assign a type the heading does not have (ADR-0054's principle).
  - Not enforced, both stated: the *threatens* half of §6.7.2 (a `read` into a
    result variable satisfies the standard and not this compiler), and
    §6.8.2.2's rule that an assignment's function-identifier must be the
    containing block's, so a sibling assignment is accepted when it is not the
    only one.
  - **A dynamically sized result cannot arise**, and the standard is what
    prevents it: a result-type is a *type-name*, and ADR-0041 withdraws
    §6.2.3.2's permission inside a type definition, so no named type has a
    dynamic extent. That is what lets the caller always size the slot.
- **A function-access is a parser change** (ADR-0056). §6.8.6 lets a call carry
  selectors — `mk(7, 8).y`, `scale(10)[2]`, `alloc(3)^` — and the whole feature
  is `Parser::afterCall` handing a call to `parseSelectors` under
  `--std=extended`. Nothing downstream is told which of the two it walked.
  - **Sema and CodeGen needed nothing**, for ADR-0055's reason: a result that
    lives in memory travels in caller-supplied storage, so a call in that
    position already yields an address, and `emitAddress` has had a
    `case NK::Call` since ADR-0052 built `binding(f)` in a frame slot.
  - **§6.8.6's NOTE was already written, as `isDesignator`.** It answers
    `false` for a call, and an actual var parameter and a `read` target are two
    of its call sites; an assignment's target and a `with`'s record are refused
    a level earlier, by the grammar, because §6.5.1's variable-accesses do not
    include a record-function-access. No rule was added for any of the four.
  - **§6.8.6.4 is the exception and it is a variable.** §6.5.1 lists a
    function-identified-variable, so `alloc(3)^.x := 1` is legal — and a
    statement beginning with a name and an argument list is therefore no longer
    certainly a procedure-statement. `callTakesCaret` scans to the *matching*
    `)`, the second bracket-depth walk in this parser after ADR-0054's.
  - **The ISO 7185 gate needed a pointer-returning function to test at all.**
    A record result is refused by §6.6.2 first, so the obvious negative program
    passes whatever the parser does — ADR-0054's `constexpr_iso.pas` fault, met
    again. The statement form has a second gate and its own file.
  - §6.8.6.5's substring-function-access arrived with ADR-0057, in that shared
    `parseSelectors` — which is the reason this record gave for deferring it.
- **A substring is a pointer, a length, and somewhere to store** (ADR-0057).
  §6.5.6's substring-variable and §6.8.6.5's substring-function-access are one
  node, because §6.5.1 makes the first a variable-access and the second a value
  and **the base is the whole difference** — which `isDesignator` already asks.
  - **The parser decides without types**: a `..` inside a subscript can only be
    this, since §6.5.3.2 gives an array one index-expression per subscript.
  - **The type is the canonical-string-type.** §6.5.6's "new fixed-string-type"
    of capacity `hi - lo + 1` is never built — that capacity is not a
    compile-time number, and the only rule that reads it is the store, which
    reads it at run time from the same subtraction the length came from.
  - **Reading copies nothing** (ADR-0051's representation) and **writing is the
    fixed-string store unchanged** — §6.4.6 already pads a shorter value and
    refuses a longer one. `emitStore` was not touched.
  - **The bounds check could not be shared with `substr`.** §6.7.6.7 lets
    `substr(s, i, 0)` yield the null-string; §6.5.6 makes `i > j` an error, and
    `s[3..2]` is exactly the empty substring. The two conditions agree
    everywhere *except* the empty case, so `pas_str_substr_check` is its own.
  - **§6.7.3.3 NOTE 3** — a var parameter cannot denote one — is checked by
    name even though the same-type rule would refuse it anyway, because that
    rule's words name a representation rather than the reason.
  - §6.5.6's "a reference to a substring is a reference to the variable" needed
    no new walk: `baseSymbol` and `rootDesignator` step through a substring as
    through a subscript, which is what protects a protected string.
  - **`read` into a substring works**, and writing it found two things nothing
    had reached: the Pascal Sema refused *every* string read (§6.10.1 a) was
    ported to C++ only, so the compilers had disagreed since ADR-0051 with no
    corpus program to notice), and the Pascal backend's string-read branch fell
    through into a store because Pascal has no `continue`. Unreachable only
    because Sema refused first. `tests/extended/readstring.pas` is the program
    neither had.
  - Not enforced and stated: §6.5.6's aliasing rule (a run-time property, as
    ADR-0027's is).
- **A restricted type is a type kind** (ADR-0058). §6.4.2.5's `restricted T`
  has T's values and T's representation and almost none of T's operations, and
  making it a `TypeKind` is the whole enforcement: `isInteger`, `isOrdinal`,
  `isArray`, `isStringType` all answer `false`, so arithmetic, indexing, field
  selection, `write`, `case`, `for` and `ord` each refuse it through **the
  diagnostic they already had**. Nothing enumerates what is forbidden — the
  third refusal-by-construction here, after ADR-0044 and ADR-0046.
  - **`isStructured` and `isMemory` are the only two predicates that see
    through**, because *how a value travels* is not an operation the program
    performs. `llvmType` follows, and is the only line CodeGen gained.
  - **The comparison is the one refusal written down, and only because the
    assignment rule exists.** §6.4.2.5 makes a restricted type and its
    underlying type assign to each other, so `assignable` learned about them —
    and a relational operator asks `assignable`. Without its own line, `n = 3`
    rides in on the assignment's permission. A permission granted in a shared
    predicate leaks to every caller of it.
  - **Two restrictions of one underlying type do not assign to each other**:
    §6.4.2.5 says nothing about a second restricted type, so exactly one side
    may be restricted and ADR-0017 stands.
  - The var-parameter rule is a **widening** of the same-type rule, one way
    only. The initial state is handed on by ADR-0048's `initialStateOf`.
    Refused: `bindable restricted`, a restricted *file*, and restricting a
    restricted type.
  - **The first word-symbol too long for the Pascal `kwLit`** (nine wide, and
    `restricted` is ten). Recognised by one comparison beside the table rather
    than repadding 188 literals, and its spelling is written out in the token
    dump beside `and then`/`or else`, which are in no table either.
  - **A diagnostic cannot contain `§`** — `char` is a byte, so the Pascal source
    would carry two of them. `difftest` caught it as a one-character diff.
- **Five required things, and what each cost** (ADR-0059). `maxchar`, `halt`,
  `card`, the two-argument `succ`/`pred` and `><` — a batch, because each is
  too small to be a feature and too separate to be part of one.
  - **`><` is decided in the lexer**: under ISO 7185 the two characters can
    only be `>` then `<`, which no expression admits, so joining them there
    would turn one diagnostic into a cascade (ADR-0036's argument).
  - **`succ(x, k)` widens to i32 and range-checks both ends.** The
    one-argument form tests one end and steps; `ord(x) + k` may leave the type
    in either direction and by any amount, so the sum must not wrap first.
    §6.7.6.4 defines `pred(x, k)` as `succ(x, -(k))`, and this *subtracts*
    rather than negating — the same thing without negation's edge case.
  - **`halt` closes the open files through ADR-0032's list**, because it leaves
    every block without its epilogue, and it is answered before `emitStdProc`
    takes the address of a first argument — which since ADR-0084 it *may* have,
    an optional exit status being the second of this processor's two documented
    extensions. §6.7.5.7 gives `halt` no parameters and neither standard models
    an exit status at all, so `halt(1)` was a compile-time error and no
    conforming program contains one; what is extended is the processor, in the
    dimension where a run-time error has always exited 1 with no clause saying
    so. It exists because `pascalc` has to be able to report failure, and
    **`selfhost/producttest.sh` is the only thing that checks it does** —
    deleting the compiler's own `halt(1)` passed the whole suite as it then
    stood, goldens comparing what a program wrote and never how it stopped.
  - **A builtin's enumerator has to be placed, not written where it reads
    best**: the AST dump prints it as an ordinal, so both compilers must agree
    on the index. `difftest` caught two as a number one apart.
  - Not done and stated: `minreal`/`maxreal`/`epsreal` need interned *text*
    rather than a value, because ADR-0025 never converts a real literal — the
    same reason ADR-0054 refuses a real-valued constant-expression.
    **ADR-0062 did them**, and by that route: the text was always the
    mechanism, so what was missing was somewhere to put twenty-two characters.
- **readstr and writestr are a text file made of memory** (ADR-0060). §6.7.5.5
  does not say what the two procedures compute — it says each is *equivalent
  to* `rewrite(f); writeln(f, ...); reset(f); read(f, ...)` over "an auxiliary
  variable that the program does not otherwise contain, which possesses the
  required type text". So the runtime builds that variable with `fmemopen` and
  `open_memstream`, and every `pas_read_*` and `pas_write_*` primitive is
  reused **unchanged**: a field width, the spelling of a real and where a
  string read stops are §6.10's, because they are the same code.
  - `WriteStmt::str`/`ReadStmt::str` say which statement it is; Sema then
    skips the leading-argument-is-a-file detection and leaves `file` null, and
    CodeGen asks the runtime for the handle. `emitWriteArgs`/`emitReadArgs`
    take that handle and **do not know which kind of file they were given**.
  - **The `writeln` in the equivalence is a real newline**, appended after the
    characters, and that is what keeps `eof` false while the values are read —
    so "an error if eof(f) is true upon completion" means what it says.
  - **writestr's error condition is the string store's capacity check.**
    `eoln(f)` is false afterwards exactly when more was written than the
    destination holds, which is §6.4.6's rule every string assignment already
    carries. It needed no code, only the observation.
  - **The source characters are copied**, so `readstr(e, i, e)` is well
    defined; and the auxiliary file is heap-allocated **per statement**, not a
    static, because a `writestr` may appear in the write-parameters of
    another. It is deliberately not on ADR-0032's open-file list — the program
    does not contain it, so no block exit is responsible for it.
  - `PAS_FILE_SIZE` went 96 → 112, and `fileSize` in the Pascal compiler with
    it; `irtest.sh` is what checks the two still agree.
  - Both are parsed *by name*, as `read` and `write` are, because the parser
    has no scope. That was a stated **deviation** — a program could not declare
    its own, where §6.7.5.5 makes them required identifiers — until ADR-0087
    retired it by moving the question to Sema. The parser still recognises the
    words; what it no longer decides is what they denote.
    `tests/readstr_iso.pas` is the half that is a gate.
- **A structured value is built, not computed** (ADR-0061). §6.8.7's
  structured-value-constructor: an array and a record have no register form
  (ADR-0017), so the components are stored into the storage the value will
  occupy and the expression's value is that address. Nothing is assembled and
  nothing is copied afterwards.
  - Where the storage comes from is decided **per position**: the hidden frame
    slot ADR-0055 gives a memory-living result at the top of an expression,
    the component itself for a nested component-value, and the **destination**
    for an assignment — which is what makes §6.6's initial-state form work,
    since a variable's prologue has no result slot to lend.
  - **Three of the four productions were already here.** A selector is a
    case-constant-list (ADR-0035); a field-list-value corresponds to a
    field-list and an arm's *is* one (ADR-0026), so one `checkRecordValue` and
    one `emitRecordValue` walk the record and every variant nested in it,
    keyed by the path `Field::variant` already uses; and a component-value is
    `emitStore`, so a subrange component is range-checked and a string one
    padded by code written for something else. `fieldsAt`/`armsAt`/
    `tagFieldAt`/`tagTypeAt` moved onto `Type` so Sema and CodeGen ask one set
    of functions.
  - **The completer is filled in first and the elements written over it**, so
    §6.8.7.2 b)'s "each component not mapped to by an element" needs no
    complement computed — the ranges are disjoint by the time it matters. A
    component-value is emitted **once** however many components it is for and
    then copied, so a function call in one is called once.
  - **`[a: 1]` cannot be told apart by the parser** — an array-value when `a`
    is a constant, a record-value when it is a field name — so both selectors
    are parsed as expressions and Sema folds or resolves according to the
    type. Whether the *bracket* is a value at all is the third bracket-depth
    scan here, after ADR-0054's and ADR-0056's: a `:`, a `;`, `case` or
    `otherwise` at depth one, or an empty `[]`.
  - It **retires ADR-0048's deferral**: §6.6 NOTE 4 makes an
    initial-state-specifier's component-value an array- or record-value too,
    so `parseExpr` became `parseComponentValue` in `parseTypeExpr` and NOTE
    3's `array [1..8] of char value [1..8: '*']` is eight stars.
  - A constructor is **not a designator** and needed no rule saying so; the
    one rule that *was* needed is the opposite direction, since a structured
    value parameter had required a designator to copy from.
  - Refused and stated: §6.8.7.4's **set-value** (a set is a value and needs
    none of this; and `sieve[2,3]` cannot be told from `a[2,3]` without the
    symbol), §6.8.8's constant-accesses — which that record calls "structured
    constants" — and a value of a dynamically bounded type. The first landed
    as ADR-0066, by taking the second half of its own reason seriously: the
    symbol is what tells them apart, so Sema is where it is told. The second
    landed as ADR-0069. The third is still refused: a dynamically bounded type
    has no compile-time extent, so "every component is specified" is not a
    question that can be asked of it.
- **The transfer procedures are index arithmetic, and nothing else**
  (ADR-0067). ISO 7185 §6.6.5.4's `pack`/`unpack` and §6.9.5's `page`, the
  three required procedures that were missing.
  - §6.6.5.4 gives a *statement sequence* each is equivalent to, not an
    operation — `k := i; for j := u to v do begin zz[j] := aa[k]; if j <> v
    then k := succ(k) end` — and the `if j <> v` is the same care the `for`
    statement takes: no step after the last iteration, so `succ` never runs off
    the index type.
  - **The copy is a `memcpy` because `packed` means nothing here.** §6.4.3.1
    leaves it to the implementation and `llvmType` packs nothing, so the two
    array types have one layout and the conversion these procedures exist to
    make is vacuous. What is left is the index arithmetic and the range check.
    `emitTransfer` is the one function that would grow the component-wise loop
    back if `packed` ever meant something.
  - **The bounds are checked once, before anything is copied.** `k` runs
    monotonically from `i`, so the ends are the only values that can leave the
    array — and a program that stops leaves the destination untouched, where a
    per-component check would leave a partial copy.
  - **`i` is checked against the *unpacked* array's index-type**, never the
    packed one's: the packed bounds say how many components move, `i` says
    where in `a` they start. The rule a reader is most likely to invert.
  - **`page` needed per-file state.** §6.9.5's implicit `writeln` happens only
    "if f.L is not empty", which nothing in the runtime tracked — so
    `PAS_FILE_SIZE` went 112 → 120 with `fileSize` beside it, and the flag
    follows what was *written*, since a zero field width may write nothing.
  - Sema supplies `output` for the bare `page`, through the same
    `standardFileRef` a `write` with no file gets, because CodeGen never
    inspects names (ADR-0008).
- **A set-value is told from a subscript by the symbol** (ADR-0066). §6.8.7.4
  is four lines — `set-value = set-constructor` — so `digits[1, 3]` is `[1, 3]`
  with a type name in front, and what the name adds is a **type**: a bare
  constructor infers one from its members and `[]` has none at all.
  - **The parser builds a spine and Sema reinterprets it.** `digits[1, 3]` is a
    subscript chain and `digits[1..3]` a substring, and `setValueTypeOf` walks
    down the *base* links to the root and asks what that name denotes. Third
    time the answer is "ask the symbol, not the syntax", after ADR-0053's
    qualified name and ADR-0044's variant-selector — and the first where the
    two readings are a value and a *variable*.
  - **The spine carries the answer rather than being rewritten**, because
    `checkExpr` takes a raw pointer and cannot replace the node the parent
    holds. `IndexExpr::setValue`/`SubstringExpr::setValue` is
    `FieldExpr::qualified`'s shape; the members are *moved* out, so the spine
    left behind is a husk and every later pass reads the field first.
  - **Not a designator, and no rule says so**: `checkSetValue` returns before
    the base is checked, so the root `VarRef`'s symbol stays null and
    `isDesignator` — which asks the base — answers false. Assignment, a `var`
    parameter and `read` are all refused by tests that already existed.
  - **It makes the check ADR-0028 said a constructor could not.**
    `checkedForSetBase` is "the check a set constructor cannot make for itself,
    because a constructor does not know what it is being assigned to" — and a
    set-value *knows*. So `digits[i]` traps on a stray member with no
    assignment in sight; `tests/extended/trap_setvalue.pas` is that program.
  - **The parser gave up one rule and Sema took it back.** A set-value's
    members are a list, so a comma may follow a range; §6.5.6 gives a substring
    one range and no list. `SubstringExpr::listed` records that a comma
    followed, and Sema refuses it for anything that is not a set-value —
    without it the relaxation silently made `s[1..3, 2]` mean `s[1..3][2]`.
  - The port needed two things the C++ did not: `nkIndex`/`nkSubstr` had to
    leave `NewNode`'s "nothing of Sema's to clear" group, and `EmitExpr` had no
    `nkSubstr` arm at all — its `case` was not exhaustive over `nodeKind`, which
    in Pascal traps at run time rather than warning.
- **A required real constant is decimal text** (ADR-0062). §6.4.2.2 b)'s
  `minreal`, `maxreal` and `epsreal`, and the three ADRs that deferred them
  were all deferring the same thing: ADR-0025 carries a real as the characters
  that were written and `selfhost` has no floating-point type, so what was
  missing was never a conversion but somewhere to put twenty-two characters.
  Each is spelled as the shortest decimal that round-trips to the binary64
  value it names, **the same characters in both compilers**, and `InternWide2`
  — two fixed-width literals joined — is the whole of the new machinery.
  - Required *identifiers*, so declared in the outermost scope and shadowable
    (ADR-0049's rule); CodeGen and `verify/` are untouched, because a constant
    of real type already emitted.
  - The test asserts the **property**, not the characters: `1.0 + epsreal >
    1.0` and `1.0 + epsreal / 2.0 = 1.0` are the clause's own sentence, and
    printed digits would pass with any nearby value.
  - The ISO 7185 gate had to be a *negative* test — the names are ordinary
    identifiers there, so a program declaring its own compiles under both and
    distinguishes nothing (ADR-0056's fault, met again).
- **A set-member-iteration is a walk over the bits** (ADR-0063). §6.9.3.9.3's
  `for v in s do`. A set is one 256-bit word with a bit per member (ADR-0028),
  so "for each member" is a counter over the base type's ordinals and the
  `lshr`/`and`/`icmp ne` the `in` operator already emits.
  - **The iteration range is clamped to 0..255**, and that is the one thing
    this feature taught: a set *constructor* infers its base type from its
    members, so `[1, 2]` is a set of `integer` — a type ADR-0028 refuses to
    declare but happily infers — and its ordinal range is −maxint..maxint. The
    first run scanned two billion values. There is no bit outside 0..255, so
    the clamp states where a set keeps its members rather than guarding
    against the inference.
  - Three obligations were discharged by existing code: "evaluated prior to
    the first execution" is free because a set is a *value*; D.96's error on a
    member outside a narrower control variable is `checkedForSubrange` at the
    store; and the counter cannot overflow because it is an `i32` bounded by
    255 — so the sequence form's test-before-stepping care is unnecessary
    rather than omitted, and `verify/` gained nothing.
  - **One node, two shapes**, because §6.9.3.9.1 makes the two an
    *iteration-clause*: one production with two alternatives. The dump's head
    says which.
  - It **reserves nothing** — `in` is an ISO 7185 word-symbol already, the
    third such feature after `and then` and `type of`.
  - Not enforced, and stated: §6.9.4 g) (a body may assign to the control
    variable, in either form) and "the control-variable shall be undefined
    after the loop".
- **A field width of zero is three different answers** (ADR-0064). §6.10.3.1
  lowers the least width from one to zero, and every subclause under it then
  has to say what zero *writes*: nothing for a string, a char or a Boolean
  (§6.10.3.6, §6.10.3.2, and §6.10.3.5 by delegation), the sign and the digits
  for an integer (§6.10.3.3 b) applies whenever the width is under
  IntDigits + 1), and a full representation for a real, because both real
  forms clamp. Reading it as "suppress" is right three times and wrong twice.
  - **The bound is checked in the compiler**, because *which* number is least
    is the one thing the standard decides and the runtime is never told which
    language it was compiled for. It also keeps `-1` usable as the "no width
    given" sentinel, which a negative width reaching the runtime would have
    destroyed. `Sema::std()` is the second whole-program answer CodeGen asks
    for, after ADR-0053's `activeModules()`.
  - **§6.10.3.6's truncation was already ISO 7185's rule** (§6.9.3.6, word for
    word) and this runtime wrote the whole string instead. Fixed in *both*
    standards; `tests/extended/schema_string.pas` is the golden that moved.
  - **A FracDigits of zero writes the point** — §6.10.3.4.2's '.' is
    unconditional and counted in MinNumChars — which C's `%.0f` does not, so
    that one case is formatted by hand.
  - **The floating form derives DecPlaces from the width** (`ActWidth −
    ExpDigits − 5`), which §6.10.3.4.1 always required and the runtime never
    did: it hard-coded six. The default output is unchanged, because the
    implementation-defined default TotalWidth is defined as `ExpDigits + 17`.
  - Stated deviation: **ExpDigits is not a fixed number** — two digits, or
    three past 1e100, because that is what C's `%E` writes.
- **A time stamp is eight numbers, and the layout stays here** (ADR-0065).
  §6.7.5.8's `GetTimeStamp` and §6.7.6.9's `date`/`time`, over §6.4.3.4's
  packed `TimeStamp` record — the last feature on README's list.
  - **The record's layout never crosses to the runtime, in either
    direction.** `pas_gettimestamp` samples the clock and
    `pas_timestamp_field(k)` returns the parts one at a time; the compiler
    makes the eight stores itself. Passing a pointer to the record was
    rejected for ADR-0030's reason — a Boolean field is an `i1`, and how an
    `i1` sits in memory is exactly what neither backend may depend on.
  - **§6.4.3.4's field order is the interface and three places follow it** —
    Sema's record, CodeGen's `date`/`time` base indices (2 and 5), and the
    runtime's slot numbering. They cannot be reduced to one: the runtime has
    no view of the record, and ADR-0008 forbids CodeGen to look a field up by
    name. `tests/extended/timestamp_fixed.pas` gives every field a different
    small number, which is what makes a disagreement visible.
  - **The six subranges do most of the enforcement** (ADR-0018), which leaves
    §6.7.6.9's error condition small: February the 30th, and a year the
    representation cannot write. `year` is the one field whose type does not
    bound it. The stores need no `checkedForSubrange` — every value the
    runtime can return is in range by construction, so a check there could
    not be made to fail. That sentence is true **because of the leap-second
    clamp below**, which is the one place a calendar offers a number outside a
    field's type; the two are one decision, not two.
  - **§6.9.4 f) is the one entry on that list ADR-0046 could not have a call
    site for**, the procedure not existing then. It still sits beside the
    `isDesignator` test.
  - **`date` and `time` are pure**, so `nonvarying` needed no case: the clock
    is read by `GetTimeStamp`. Both results are **fixed-width**, so the length
    is a compile-time constant and only the pointer costs a call — the
    division `pas_str_concat` already made.
  - A **leap second is clamped** to 59. 60 is not a value of `second`'s
    subrange, and since the stores carry no check the alternative is not a
    trap but a 60 sitting in a `0..59` field with nothing reporting it. **No
    test reaches the clamp and none can** — a POSIX `time_t` cannot name a
    leap second — so removing it survives every oracle; don't take that as
    licence to remove it.
  - **"Current" is `SOURCE_DATE_EPOCH` when that is set, and the system clock
    otherwise** — read as UTC, because a fixed instant must not vary with the
    machine's zone. §6.7.5.8 makes the meaning implementation-defined, and this
    is the only definition under which the eight fields can be checked at all:
    no program knows what day it is except by asking the same function, so an
    off-by-one is true of almost every moment. `tests/run_test.sh` and
    `selfhost/irtest.sh` each export it from a `name.epoch` file, beside the
    `name.in` convention they already had, and each **unsets** it otherwise so
    an inherited one cannot replace the clock in the case that is testing the
    clock. `tests/extended/timestamp_fixed.pas` is the golden that names a
    date.
  - **Three answers, not two**, and the third is the one §6.7.5.8 provides
    for: an epoch that does not parse falls back to the clock
    (`timestamp_badepoch.pas`), and one that parses but names no calendar date
    takes the **invalid arm** — `DateValid` false and `January 1, 1`
    (`timestamp_invalid.pas`). Answering the second with the clock is the bug
    that was there first: the variable was set and the output still varied
    from run to run. It is also the only way a program on a working machine
    reaches that arm, so it is what makes the fallback fields testable at all.
- **A constant-access is a designator over a constant** (ADR-0069). §6.8.8, the
  last production of ISO/IEC 10206:1991, and the structured constants ADR-0061
  deferred. §6.5.1's variable-accesses and §6.8.8's constant-accesses have the
  same three selector forms and differ only in what stands at the bottom, so
  **CodeGen and `verify/` gained nothing**: the spine is the one the parser
  built, and D.88 to D.91 are the array, string and substring bounds already
  proved. `isConstantAccess` is `isDesignator` written for the other root, and
  is structural on purpose — it neither folds nor diagnoses, so it can be asked
  as a question.
  - **§6.8.8.1's NOTE is what the clause is for**: `c[i]` "denotes a different
    value for each iteration of the loop", so a constant-access is a *run-time
    read*. Where the index is constant it is a constant, which §6.3.2's own
    `column1 = BlankCard[1]` needs — and §6.8.2 keeps the two apart with no
    rule of its own, since a variable index is a variable-access and a
    constant-expression may not contain one.
  - **A structured constant is a global filled by a prologue**, not an LLVM
    aggregate initializer. Printing one needs record padding, variant arms and
    256-bit sets spelled as text in *both* backends, and ADR-0025's emitter has
    `LlSize`/`LlAlign` and no struct-literal printer. It is filled before every
    other initialisation — a constant-expression is nonvarying, so it cannot
    read what the rest of the prologue writes, and §6.6's initial state may
    name a constant. The global is keyed by the **node**, so `const b = a`
    shares storage rather than copying.
  - **A set constant needs no storage at all**, being a value (ADR-0028): the
    constructor is emitted where the name is written.
  - **Folding is a walk into the same node** — an array-value's element and a
    record-value's field-value are nodes the program wrote, so nothing is
    computed and no value representation was added. Only the two *string* forms
    compute, because the characters are the value; §6.8.8.4's substring is the
    one place this compiler builds a piece of tree the program did not write.
  - **§6.8.8.3's inactive-variant error is settled at compile time.** D.90 is a
    run-time property for a variable and ADR-0027 does not enforce it — but a
    constant's tag is a constant, so the walk down `Field::variant` either
    reaches the selected arm or reports that it did not.
  - **§6.9.3.10's with-element may be a constant-access**, and its field names
    are then constant-field-identifiers, which denote values. The binding is a
    `VarParam` either way, so the *kind* cannot answer and the binding carries
    a flag. Reusing ADR-0046's protection was tried and rejected: it would have
    said "protected", which is a different rule and the wrong noun.
  - **It forced the declaration parts to be read in written order.** §6.2.1
    makes an Extended Pascal block a *repetition* of the five parts in any
    order and §6.2.2.9 makes a defining-point precede its applied occurrences,
    so written order is the only one that works — and Sema had been imposing
    ISO 7185's fixed order on both standards. The parts are merged by **source
    position**, not recorded at parse time; under ISO 7185 there is at most one
    of each in the fixed order, so the merge is provably what it always did.
    §6.4.4's pointer domain completes at the end of *its* type-definition-part,
    so a run of type definitions ending is what triggers it. It **tightens**
    too: `var v: t` before `type t` is now the forward reference §6.2.2.9 says
    it is.
- **Five things the grammar admitted and the compiler refused** (ADR-0071).
  Not a feature: a sweep of Annex A's 274 productions, each probed with a
  compiled program, turned up five constructs the standard has and this
  compiler rejected — and *no corpus program wrote any of them*, so all five
  oracles agreed. That is the finding; the fixes are small.
  - `char + char` is a two-character string (§6.8.3.6). Table 7's operands are
    "Char-type **or** the canonical-string-type" and the clause says *a and b*,
    so both may be char. An explicit guard refused it, identically in both
    compilers and commented in neither — while README already documented it as
    working.
  - **A qualified name stands wherever a type-name may** (§6.11.3): a pointer
    domain, a restricted type, a type-inquiry object, and — through a different
    cause — either bound of a subrange, since `looksLikeSubrange` treated the
    `.` as the end of the denoter and so never found the `..`.
  - **A schema may be given a second name** (§6.4.7's first alternative), and
    the two must share one `Symbol`: §6.4.8 keys a produced type on (schema,
    tuple), so a copy would make `vec2(3)` and `vector(3)` distinct types.
    The fourth time "ask the symbol, not the syntax" has been the answer.
  - **A `with` may take a type produced from a schema** (§6.9.3.10), the
    discriminants becoming names over the statement. Three shapes, three
    answers, each already a symbol Sema had — a `Const` for a constant tuple,
    the parameter's own `Disc` for a schematic formal — **except on the heap**,
    where the tuple is a header reached by walking *down* a designator and a
    bare name has none to walk. There the binding becomes ADR-0040's
    descriptor and the discriminants are its.
  - **The `;` after a variant-part-value** (§6.8.7.3), which the production
    puts outside the alternation.
  - It also uncovered a crash **older than the feature**: a designator rooted
    at a `with` binding whose bounds are a heap variable's (`with g^ do
    cells[r, c] := 0`) built its bounds check on a null header. Both compilers
    were broken the same way, so `difftest` — which compares dumps, not
    generated code — agreed, and `irtest` had no such program.
- **Three things the compiler accepted and neither standard has** (ADR-0072) —
  ADR-0071's sweep run in the other direction. Fifteen ISO 7185 restrictions
  probed, six unenforced, three now checked.
  - **Pascal has no empty argument list.** `actual-parameter-list` requires at
    least one parameter in both standards, so `f()` is refused in both. Six
    copies of the loop wrote `if (!check(Tok::RParen))` around the list, which
    is the shape that permits the empty one; five are now
    `parseActualParameters` and `write` keeps its own, sharing only the rule.
  - **A block's declaration parts have an order** under `--std=iso7185`
    (§6.2.1), checked in the parser against the **highest** part begun rather
    than the previous one, so every misplaced part is reported. Two procedures
    in a row are the one exception, the grammar making that part a list.
  - **A constant may not be selected from** under ISO 7185; §6.8.8 is the next
    standard's. Refused in Sema, because a selector over a name is a designator
    until the symbol says otherwise — "ask the symbol, not the syntax" again.
    **Two of the three selector forms are checked, not three**: no substring
    node exists under ISO 7185, so that arm could never fire and is not written.
  - **The order check was lost by ADR-0069**, which correctly relaxed it for
    Extended Pascal and relaxed it for both. Three ISO programs in the corpus
    were themselves out of order, so nothing failed. Their goldens are
    byte-identical after being rewritten in §6.2.1's order.
  - **A wrong citation is invisible to every oracle here.**
    `tests/stringconst.pas` indexed a string constant citing §6.5.3.2, which is
    about an array-*variable*; it compiled, ran, printed the right answer and
    both compilers agreed. Nothing but reading the clause catches that.
  - Two deviations remain and are deliberate: an underscore in an identifier,
    and set compatibility not requiring §6.4.5 c)'s packing agreement.
- **Writing the document clause 5.1 requires found two bugs** (ADR-0073).
  `doc/implementation-defined.md` states the compliance level (**level 0** —
  conformant array parameters are not accepted), answers all 52 entries of
  ISO/IEC 10206:1991's Annexes E and F and all 28 of ISO 7185's, names the
  twelve errors that go unreported, and lists the extensions and restrictions.
  Answering an entry meant compiling a probe, which is what found the two.
  - **A comment may end with the other delimiter.** §6.1.8 is one production —
    an opening brace *or* star-paren, a commentary, a closing star-paren *or*
    brace — and its NOTE 1 says so outright. The lexer had two loops, one per
    pair. One loop serves both now, because which delimiter closes a commentary
    does not depend on which one opened it.
    - The consequence for this corpus: **a grammar production cannot be written
      inside a Pascal comment**, since neither pair can quote the other's
      characters. Every production mentioned in a test is described in words.
      The fix would not compile `selfhost/compiler.pas` until a comment
      containing `(member (',' member)*)` was rewritten.
    - **`selfhost/torture.pas` asserted the opposite rule** in its own
      comments, which is very likely why the two-loop version went
      unquestioned. A wrong claim in a test is invisible to every oracle here.
  - **`reset(input)` no longer discards a fetched lookahead.** §6.11.4.2 makes
    the effect implementation-defined and stdin cannot be repositioned — but
    clearing `f^` destroyed a character the *stream* had already consumed, so a
    `reset` between a peek and a read skipped one. It now leaves the file as it
    is, the only effect available that does not lose input.
  - Neither was reachable: a comment is invisible after the lexer, so
    `difftest` compared two compilers wrong in the same way; and no corpus
    program applied `reset`, `rewrite` or `extend` to a standard file at all.
- **A restriction the document invented, and a message that explained nothing**
  (ADR-0074) — the two worst entries on ADR-0073's own list of unpinned answers,
  one commit later.
  - **A program-parameter need not possess a file-type.** §6.10 requires each to
    be a variable the program-block declares and then makes the binding of one
    that *does not* possess a file-type implementation-**dependent**, reserving
    implementation-defined for the file case; §6.12 drops the distinction
    entirely. The binding here is to **no external entity**, and it **consumes
    no command-line argument** — which is the half a reader cannot guess, so
    `tests/progparam_nonfile.pas` writes a non-file parameter *between* two
    files and requires the second to still be argument two.
  - **The document had justified the refusal with a citation that says the
    opposite**: §6.12 requires no bindability of a program-parameter, and
    §6.5.1 *confers* it ("unless the variable-identifier is a
    program-parameter … in which case it shall possess the bindability that is
    bindable"). ADR-0072's wrong-citation lesson, now in the document clause
    5.1 requires — where it is worse, because that document is what a reader
    consults instead of the source. Four compiler comments and one glossary
    entry repeated the invented rule.
  - **A message naming two types says why they are two.** §6.4.1 makes each
    occurrence of a new-type a distinct type, so `cannot assign record x end to
    a variable of type record x end` is accurate and useless. Two forms: both
    anonymous gets the advice (name the type once), two type-*names* that print
    alike gets only the reason, since renaming is no advice.
  - **The note belongs to incompatibility and nothing else, and an existing
    golden proved it.** Added to every complaint a relational operator makes,
    it turned `tests/type_errors.pas` red: §6.7.2.5 gives a record no relational
    operators at all, so naming the type cures nothing. Only *compatible* is a
    complaint type identity can cause; numeric, set, boolean and comparable name
    a property of the **kind**, which two types written alike necessarily share.
  - That same golden had recorded the useless message since structured types
    landed. Nothing distinguishes a diagnostic that reports a rule from one that
    explains it, so `difftest` compared two compilers unhelpful in the same way.
  - **The comparison is capped and both compilers carry the cap**: the Pascal
    side can only ask "do these print alike" by rendering through `msgBuf`
    (`strMax`), so `kTypeNameCompareLimit` declines the same question in the
    C++. `fileSize`/`PAS_FILE_SIZE`'s coupling again — and checked, not
    asserted: the test declares a 263-character type name, and dropping the
    limit from one compiler fails both the golden and `difftest`.
- **A constant may be `nil`** (ADR-0075). §6.7.1 makes it an
  unsigned-constant, so §6.8.2 admits it — it names a value and reads nothing,
  which is the whole of nonvarying. ISO 7185 §6.3's `constant` has no `nil`, so
  the fold is gated on the standard where ADR-0054 gates `Binary` and `Call`.
  - **The constant keeps the literal's type**, which is why the feature is one
    arm of one `case`: §6.4.4's NOTE 2 gives the token "a suitable
    pointer-type", which is ADR-0019's nil-type, so one `q` serves every
    pointer type and assignment, comparison, a value parameter, an initial
    state and a `nil` component of a §6.8.7 constructor each needed nothing.
  - **The dump prints the word, not `intVal`** — a field the fold never writes.
    The same care the memory case beside it takes, and for ADR-0068's reason.
  - It gave **`nil^` a way of being written**, which exposed a message naming
    the wrong rule. The nil-type was always refused there, but through "only a
    pointer can be dereferenced, found nil"; §6.4.4's NOTE 1 is the rule that
    applies — the nil-value "does not identify a variable". ADR-0074's lesson
    in a third form, and equally invisible to every oracle here.
  - It was found by ADR-0071's sweep and **written into `doc/roadmap.md`
    instead of fixed**, which is the only reason it outlived two more
    conformance rounds.
- **A required procedure may be declared away** (ADR-0087). ISO 7185 §6.2.2.10
  puts the required identifiers' defining-points in "a region enclosing the
  program", and §6.6.4.1 is the procedures' half — so `procedure write(var a:
  integer)` in the program-block is what `write(i)` then activates. Found by
  the BSI suite's CONF116, which this compiler had been running as the
  required `write`, printing the wrong answer and **reporting nothing**.
  - **Every other required procedure had this for free.** They are not symbols:
    `CheckProcCall` reads a `Lookup` that answers nil as "the required one", so
    a declared `get` wins because the lookup succeeds. Six names could not —
    `read`, `readln`, `write`, `writeln` and Extended's `readstr`/`writestr` —
    because §6.8.2.3's procedure-statement is an actual-parameter-list *or* one
    of four read/write parameter lists, and only a write-parameter-list's field
    widths tell them apart. So the parser had to recognise the six words, and
    settled what they *denote* in a pass with no scope.
  - **The parser decides the statement's shape; Sema decides what the name
    denotes** — ask the symbol, not the syntax, for the fifth time after
    ADR-0044, ADR-0053, ADR-0066 and ADR-0071. The parser yields the name
    whenever what follows it can continue a designator, because `write := 5`
    and `write[i] := 5` are assignments and no parameter list begins with one;
    Sema's `RedefinedFamily` looks the name up and hangs the call off the node,
    which is then a **husk** every later pass reads through. ADR-0066's shape,
    for ADR-0066's reason.
  - **§6.7.5.5's two gave up their parameter list's shape**, which is what
    retired ADR-0060's deviation: a parser that requires the comma in
    `'(' string-variable ',' ...` has already decided the statement is a
    writestr, so the list is parsed as an ordinary write-parameter-list and
    **Sema moves the string out**.
  - **Nothing new checks a call.** Arity, `var`-parameter and
    not-a-procedure all come from the ordinary path; the one new message is
    that a declared `write` takes no field width. §6.6.3.7 came out right
    untouched — a *declared* `write` is now passable as a procedural parameter
    and the required one still is not, the rule and the fix being one question.
  - It made a check reachable that never had been (`writestr(s)` with nothing
    to write compiled and wrote nothing), and stopped a broken `readstr`
    demanding `input` — it reads from no file at all.
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

Strings *were* the length-plus-buffer record of ADR-0012; ISO/IEC 10206:1991's
own `string` type landed as ADR-0051 and that decision is now closed. What
follows is the reasoning that got there, kept because it is why the record
shape is still the right one to write in ISO 7185:
`tests/bootstrap_strings.pas` is the working evidence and the regression test
for it. Don't add a `string` type without new evidence from real stage-1 code,
because measuring the C++ compiler is what showed the extension was
unnecessary — nearly all its string building feeds text that is written out.
Extended Pascal defines a `string` type, so that decision is the one most
likely to be revisited at stage 2 — its reason expires there rather than the
decision being overturned on taste.

## Where things live

**Everything is `selfhost/compiler.pas`** — one source file, ~24,000 lines,
because neither standard has an include mechanism (ADR-0024). The names below
are the *components* inside it, and where a bullet names a `src/*.cpp` file it
is naming the component that file used to be: the port is close enough that the
reasoning transfers, and the C++ is at tag `v0.1.0` if you want to read it.

The **lexer** case-folds identifiers and knows every reserved word of both
standards, even ones the parser rejects — which of them are *reserved* is the
one thing `--std` decides in the lexis (ADR-0033). The **parser** is recursive
descent shaped like the ISO grammar (`expression` → `simple-expression` →
`term` → `factor`) — note a leading sign binds to the whole *term*, so
`-7 mod 3` is `-(7 mod 3)`.
It bounds the depth of the tree it builds at 1000 levels (ADR-0020);
the spine-building loops count their iterations toward the same limit, because
an operator chain is flat for the parser but deep for Sema and CodeGen — a
call-depth-only limit would miss it.
`DumpProgram` writes the tree before and after Sema, behind `--dump-ast` and
`--dump-sema`; the format was a specification while two compilers wrote it and
is now a debugging aid, which is the one thing ADR-0085 made *less* load-bearing.
**Sema** owns scopes, type rules, type-denoter resolution, constant
folding, and — since ADR-0039 — the schema intern table, which is the one place
a type's *identity* is decided by something other than the denoter that built
it. Since ADR-0053 it also owns the interface table and the module records: an
interface is not a scope (§6.2.2.2), so it lives beside the scope stack rather
than in it, and a module's scope is *kept* between program-components because
§6.2.2.12 makes the heading's defining-points the block's as well. Since
ADR-0069 `checkDeclarations` walks the constant, type and variable parts
**merged by source position** rather than one part at a time, because
ISO/IEC 10206:1991 §6.2.1 lets them interleave and §6.2.2.9 then makes written
order the only correct one. A type-denoter is a `TypeExpr`, deliberately not an `Expr`, and a
declaration group shares one — which is what makes `a, b: array [1..3] of
integer` the *same* type rather than two alike ones. The one exception is a
parameter group naming a schema (ADR-0040): each name there gets its *own*
type, because each reads its own descriptor. `runtime/pasrt.c`
holds anything not expressible in IR — formatted output and runtime checks —
where `width < 0` / `prec < 0` mean "not given", and nothing else: a width the
program *wrote* is checked against §6.9.3.1's or §6.10.3.1's least value
before it gets there, so the runtime never sees a negative one (ADR-0064).

Adding a language feature usually touches, in order, the components of
`selfhost/compiler.pas`: the token kinds and the lexer → the node kinds and the
parser → Sema → CodeGen → a `tests/` pair, plus `runtime/pasrt.c` if it needs
library support, and `selfhost/badparse/` or `selfhost/badsema/` if it adds a
diagnostic. It used to touch that list *twice*, once in C++ and once in Pascal,
in the same commit; halving that is what retiring stage 0 bought (ADR-0085).

`selfhost/compiler.pas` is the stage-1 compiler, written in Afterschool Pascal,
and since ADR-0083 it is **the compiler this repository produces**: CMake
translates it with the seed compiler and the result is `build/bin/pascalc`.
The lexer (ADR-0022), the parser (ADR-0023), Sema (ADR-0024) and CodeGen
(ADR-0025) are all done, and **the bootstrap closes**: the compiler compiles
itself and stage 2 equals stage 3. **It is one source file** — neither standard
has an include mechanism, so each component was merged in as it was ported
rather than kept as a program of its own. `selfhost/compiler.std` is the one
word that says which standard it is written in, and
`selfhost/producttest.sh` is what checks the built artefact — the other three
harnesses build a stage-1 compiler of their own in a temporary directory, so
`build/bin/pascalc` could be missing or stale with every one of them green.

It takes a **command line** — `pascalc [options] file.pas`, with `-o`,
`--std=`, `--import` (repeatable), `--dump-*` and `-h` (ADR-0083). It is quiet
on success and writes `file:line:col: error: message` on failure, to `output`,
because no standard Pascal program has a second stream. The dumps go to standard output; the IR goes to the file `-o`
names, because it is the compiler's *product* rather than a dump and has to be
assembled. It is written on every run, which is what keeps `difftest.sh`
exercising the code generator on every file in the corpus even though it
compares none of it.

**How a Pascal program has a command line at all** is the part worth knowing.
§6.5.1 makes every program-parameter possess "the bindability that is
bindable", and §6.7.6.8's NOTE 2 makes `binding(f)` report the binding §6.12
made *before the program was activated* — so `binding(argk).name` is argument
*k*. The compiler declares twelve program-parameters, opens none of them, and
reads their bindings; an unbound one is how the list ends, there being no other
way to count arguments (ADR-0081). The files it then works on are `bind`-ed to
names it computed, which is the same clause's other half.

That retires ADR-0033's constraint **for this compiler only**: "ISO 7185 gives
a program no access to its command line beyond its program parameters, and
those are files" is still every word true of ISO 7185, and this compiler is
simply no longer written in it (ADR-0082). Until then the standard arrived in a
file holding one word and §6.13's components arrived *concatenated* into a
fifth, because a program that cannot name a file cannot open several — the
shape ADR-0079 had to defend against the language rather than on its merits.
Twelve arguments and eight `--import`s are array bounds, and both report rather
than truncate.

**The first three components used to be checked against `src/`, and are now
checked against golden files.** `pascalc --dump-all` writes three sections
(`=== tokens`, `=== ast`, `=== sema`), and `selfhost/difftest.sh` diffed them
against the C++ compiler's over every `.pas` in the tree. That was the strongest
oracle here and ADR-0085 gave it up with stage 0; what replaced it is the
golden files, including the 157 error-path sources difftest was the only reader
of.

**Know what that means when you change a stage.** A golden agrees with whatever
wrote it, so a change that is wrong in the dump *and* wrong in the goldens you
regenerate is invisible. Regenerating a golden is a decision to be argued for in
the commit message, not a step.

- The dumps are **opt-in** — `--dump-tokens`, `--dump-ast`, `--dump-sema`,
  `--dump-all` — and each stops at the stage it names. They were unconditional
  while there was a second binary to compare them against, which is the reason
  ADR-0025 gave for having no mode to select; it expired with stage 0. Each
  section reports what its own stage found and shows its result only when
  nothing was found — a stage that failed has nothing to show, and the stages
  after it do not run.
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

**A number read takes the longest prefix that *is* a number** (§6.9.1 c) and
d), ADR-0076), which is one character more than a file's lookahead can decide:
`1.` is the integer 1 and then a point, `.5` is not a number at all, and `2e+`
is the integer 2 and then two characters. `struct pas_file` carries a
two-character give-back for it, and the order is a stack because the sign has
to come back out before whatever followed it. `tests/readlongest.pas` includes
`8.5.5`, which was already right, so a fix in the wrong direction fails too.

**`(.` and `.)` are `[` and `]`**, not a second spelling — §6.1.9 says "the
corresponding tokens or separators shall not be distinguished", so nothing
after the lexer is told which arrived and `a[2.)` is a legal subscript. Only
the *reference* tokens and the alternative `@` are implementation-defined
there; every other alternative representation is required, which is the same
sentence that requires `(*` and `*)`. `@` is refused, in `torture.pas`.

An array subscript outside its bounds traps (ADR-0017), and a `for` loop over an
array's own bounds optimises the check away; where the bounds arrived with the
actual (ADR-0040) the message is built by the runtime and says the same words. Storing outside a subrange traps,
and so does a `case` whose selector matches no label (ADR-0018) — unless it has
an Extended Pascal `otherwise`, which is the only thing that gives that arm
something to do (ADR-0033) — a dereference of `nil` (ADR-0019), and a set whose
members are not values of the target's base type (ADR-0028). That last check
fires at the **store**, because a constructor does not know what it is being
assigned to — except for §6.8.7.4's set-value, which names its type and is
therefore checked where it is written (ADR-0066). `tests/extended/trap_setvalue.pas`
is the program with no assignment in it.

`date(t)` traps when the day, month and year of a `TimeStamp` are not a
calendar date (§6.7.6.9) — February the 30th, and a year outside 1..9999, that
bound being what keeps the result fixed-width (ADR-0065). The six subranges of
§6.4.3.4 do the rest of the enforcement, which is why the check is that small.

**ISO error conditions trap** (ADR-0014, ADR-0015). Integer `+ - *` and `sqr` go
through `checkedArith` and stop the program on overflow rather than wrapping —
they carry no `nsw`. `chr` outside 0..255, `succ`/`pred` at the ends of their
type, `div` by zero, `INT_MIN div -1`, and `trunc`/`round` of a real outside the
integer range (or of a NaN) all reach `pas_runtime_error` (stderr, exit 1).
The integer type is **-maxint..maxint**, narrower than the `i32` behind it, so
`INT_MIN` is not a value of the type and a literal above `maxint` is a
compile-time error.

**Annex D is the checklist** (ADR-0077), and probing it found six errors that
were answered with a value: `ln` of a number that is not positive, `sqrt` of a
negative one, `x/y` with a zero divisor for real *and* complex, `i mod j` with
j negative, and `dispose` of nil. Two are worth remembering rather than
looking up:

- **`mod` is where the compiler disagreed with itself.** §6.7.2.2 makes a
  divisor that is zero *or negative* an error; Sema's folder had always said
  so for a constant, with a comment claiming the emitted code followed the
  same rule. It did not. The run-time check now uses the folder's words, which
  is what makes one rule one answer — and it turns `rules.py`'s `j > 0`
  precondition from an assumption into something the compiler enforces.
- **`dispose` of nil was checked only for a schema domain**, where stepping
  back over a tuple header made it a free of an address never allocated.
  Elsewhere it was a *harmless* error, and harmless is not the test §6.6.5.3
  sets. Same comparison; only the reason to report it differed.

**A `for` statement's control variable must be declared in its own block**
(§6.8.3.9, ADR-0077). Not merely "a variable": a procedure looping over the
program's `i` is refused. The message names where it must be declared rather
than saying "must be a variable", because a value parameter *is* one — the
complaint was never about what it is.

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

- **`lowering.py` is a model of the code generator and must be maintained with
  it.**
  A drifted model keeps passing and proves nothing. When you change a lowering,
  change the model in the same commit.
- **Specifications state properties, never computations.** Writing `iso.py` so it
  computes the answer the way the compiler does would make every proof circular
  and the circularity invisible.
- **A `KNOWN_GAP` that starts holding fails the build.** That is intentional: it
  means the compiler was fixed and the catalogue is now describing a compiler
  that no longer exists. Flip it to `MUST_HOLD` in the same change.

New arithmetic, conversion, or comparison lowering should arrive with a rule.
The catalogue currently has **no known gaps** — 43 rules, 27 of them for every
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
