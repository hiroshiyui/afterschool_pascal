# Design digest

One paragraph per mechanism, condensed from the record that decided it. Every
entry cites its ADR, and `doc/adr/` is where the reasoning, the alternatives and
the cost are written out in full; `doc/adr/README.md` indexes all of them by
number and title.

This file exists because `CLAUDE.md` is loaded into every session before any
work starts, and a digest of a hundred decisions is not what an agent needs to
read in order to find out where the compiler is built. `CLAUDE.md` keeps what is
true of *every* change — the pipeline contract, the gates, what each oracle
cannot see, the Pascal semantics a change must not undo — and points here for
the mechanism.

**Read the entry before touching the feature it describes.** Most of what looks
over-complicated in `selfhost/compiler.pas` is load-bearing, and the entry
usually names the test that fails when it is undone.

## The core mechanisms

Activation records, designators, ordinals, `goto`, procedural parameters, sets,
pointers and files — the ISO 7185 half, and the shape everything since has been
fitted to.

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
- A **variable-string value parameter is the exception**, and it is two
  arguments rather than an address: a pointer and a length (ADR-0051's string
  value). An actual of a different capacity has a different layout, so there is
  no object whose address could be passed and no memcpy that would be right —
  which is why a string is `isMemory` and deliberately *not* `isStructured`.
  The callee's prologue makes §6.4.6's store into its own slot, through the same
  `pas_str_store_var` an assignment uses, so a value parameter and an assignment
  cannot disagree about padding or about refusing an over-long value. ADR-0115;
  a *restricted* one is still refused, pending a reading rather than a
  mechanism.
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
  which is why the line is written out — see `CLAUDE.md`'s CodeGen bullets, where
  ADR-0028 records the segfault that came of leaving it unstated.

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
  segfault — see `CLAUDE.md`'s CodeGen bullets, where that rule now lives.

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
- **Taken together, this is the language's memory-safety model** (ADR-0151), and
  it had no name until that record. A file cannot be copied and is released
  when the variable holding it dies — the block epilogue, a non-local `goto`
  (ADR-0032), `halt`, or `dispose`, which emits `pas_file_done` before the free
  — and lifetimes nest, which the runtime states as the invariant making
  "registered later" and "abandoned" the same set. That is affine ownership with
  scope-based release, reached from ISO 7185 §6.4.6 a) and §6.6.3.1 rather than
  from Rust. What it does **not** cover is aliasing: a second name for one owned
  value, which is ADR-0019's hole and the half of the fork still open.
- **And the sentence quantifies over a variable, which a heap variable is not**
  (ADR-0181). "Released when the variable holding it dies" reaches nothing
  created by `new`: such a variable exists in no activation, so the release list
  of a file and of AP 6.4.12.3's handle both miss it, and a program that forgets
  `dispose` never releases what the heap record holds. Both halves of the
  mechanism were built and correct — `new` emits `pas_file_init`/
  `pas_handle_init` per owned thing in the domain and `dispose` emits the
  matching teardown — and nothing made `dispose` happen. Under `ulimit -n 64` a
  loop allocating one such record per iteration exhausted the descriptor table
  at the 62nd. AP 6.4.14's `owned ^T` is the answer: the pointer owns the
  variable, so the variable's death is the pointer's, and the release is
  recursive because a type may own something of its own type. It is a flag on
  `tyPointer` (`isText`'s shape), the refusals arrive through `ContainsFile` via
  `IsAffine`, and `IsOwned` keeps `IsMemory` to itself — ownership and
  representation were one name until that record. `tests/dialect/owned.pas` is
  the case, and the leak it closes is what `new` being a release point is for.
- **And a type with no copy needs a move, which writing the client found**
  (ADR-0182). `PasList` over AP 6.4.14 was unwritable: push-front and
  pop-front are each two copies, so an owned chain admitted insertion and
  removal at its far end only, both by recursion, and no operation in constant
  time. `take(v)` empties the variable and yields what it held, in the one
  position 6.4.12.2 already defines for the handle — the whole right side of
  an assignment to a variable of the type — reached by a flag set the way
  `handleBirth` is and for the same reason. **The source is emptied before the
  target's address is taken**, which turns `p^.next := take(p)` from a cycle
  nothing owns into a nil dereference, and makes `n := take(n^.next)` the
  entire body of pop-front. Lowered in `EmitAssign` in four instructions;
  `EmitCall` has no arm for it at all, and `partial_cases.txt` says why that
  is deliberate. `tests/dialect/take.pas` is the case.
- **A second name for an owned value exists, and cannot escape** (ADR-0201).
  `Bump(o^)` binds a `var` parameter to what `o` owns, which is a borrow for
  the duration of the call — and the borrow can never be stored, because
  Pascal has no address-of operator (§6.1.9's `@` is refused) and `new` is the
  only thing that produces a pointer, so `kept := n` is a type error and there
  is no other way to write it. **Unformable rather than checked**: nothing in
  the compiler knows this property, which makes it free while it holds and
  silent when a future feature takes it away. It is why the ARC-or-borrowing
  fork is withdrawn rather than decided — the two differ about escaping
  aliases, and refusal covers the three affine kinds while containment fixes
  what `^T` means. `doc/sop.md` §7 carries what nothing watches.
- **And the client, once it could be written, is `PasList`** — the only
  container in `lib/` with no `Free`, because the block that declares the head
  disposes the chain. What it pays is traversal: the rule stopping a second
  pointer from dangling stops one from walking too, so only the four
  operations at the front are constant time and the rest are recursive. **The
  case that pins it is the one no gate can assert on**: 4000 chains of 50
  nodes built and abandoned, peak RSS 5.8 MB, and 58 MB with the block's
  release suppressed. Every oracle here reads what a program prints, and a
  leak prints nothing, so that tenfold is taken by hand (`doc/sop.md` §7).
- **And for anything holding one, at any depth** (ADR-0150). §6.4.6 a) is two
  conditions — "T1 and T2 are the same type, *and that type is permissible as
  the component-type of a file-type*" — and `Assignable` read only the first,
  so two records holding a `text` were assignable to each other. The copy is a
  memcpy of the file's own storage, so both variables named one
  `struct pas_file` and the block closed it twice: a double free, from a program
  §5.1 e) requires a processor to reject. `ContainsFile` is §6.4.3.5's
  "permissible as the component-type of a file-type" exactly and was already
  asked by the value-parameter, function-result, file-component and
  structured-value checks; assignment was the one caller of the four that had
  the weaker predicate. `tests/file_in_record_assign.pas` pins it, and BSI's
  **DEV102** is the same program — the one DEVIANCE test of 266 this compiler
  had not rejected.
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
  variable a `file of T` allocated. Neither standard has an early return, so
  the single exit point each body already has is the epilogue — and AP
  6.7.5.9's `exit` keeps it that way rather than adding a second, branching to
  the epilogue's own label (ADR-0177). A *local* `goto` cannot leave the block;
  a **non-local** one does, and skips that epilogue — so the runtime does the
  same work for every block the jump abandons (ADR-0032). Two implementations
  of one obligation, and the second exists because a `longjmp` skips the
  first.
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

## The Extended Pascal features

Everything ISO/IEC 10206:1991 added, in the order it landed, as one list under
ADR-0033's rule that a source is written in one language or the other. The
entries are the same shape: what the clause asks for, what it cost, and what was
refused or deferred and why. Where an entry says "codegen is untouched" or
"`verify/` gained nothing", that is the claim the feature was designed to be
able to make.

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
  - **And it is what ISO 7185 §6.6.3.7 needed** (ADR-0153). A conformant array
    parameter is the same object under another standard's clause: the
    bound-identifiers are `Disc` symbols reading the parameter's descriptor,
    the index-type is a subrange whose ends are those two symbols, and
    ADR-0113's `BoundSchemaFor` supplies the anonymous schema. §6.6.3.7's
    NOTE 2 says a bound-identifier denotes an object that "is neither a
    constant nor a variable", which `Disc` already was — so the clause needed
    no kind of its own, and *not assignable* and *not a var actual* came for
    free. Accepting it, with §6.6.3.6 e) and §6.6.3.8, is what makes this a
    **level 1** processor.
  - One type serves a whole conformant-array-parameter-*section*, because
    §6.6.3.7.1 says "the formal-parameters shall possess an array-type" —
    singular for a plural — and because ADR-0017's name equivalence would
    otherwise refuse `x := y` between two names of one section, which is
    conforming. `tests/conformant.pas` assigns.
  - **`pack` and `unpack` had never worked on either.** Both read the bounds
    and the packed array's size from the type's compile-time `lo` and `hi`,
    which for any array whose extent arrives with an actual are placeholders.
    It had been wrong since ADR-0040 and no corpus program packed a schematic
    formal; BSI's LEV1F06, LEV1F07 and LEV1F51 are what found it.
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
- **A subrange bound may be an expression too, and becomes a discriminant**
  (ADR-0113). §6.4.2.4 writes `subrange-bound = expression` and §6.2.3.8 b)
  commences a bound in the same place it commences an actual-discriminant-part,
  so `var a: array [1..m] of real` inside a procedure is the entry above with
  no schema written anywhere. Extended Pascal only: ISO 7185 §6.4.2.4 is
  `constant '..' constant`.
  - **The type representation was already there.** `resolveSubrange` has
    carried `loDisc`/`hiDisc` — a bound read from a descriptor — since ADR-0040,
    and CodeGen has lowered it since. What was missing was the *offer*: the
    descriptor was handed only to a denoter that was a schema-name.
  - **The variable is given an anonymous schema**, with no body and no name.
    `isGeneric()` is "a schema and no tuple", the descriptor is laid out from
    `descSchema`'s discriminants, and the domain check and size walk are each
    handed one — thirty-odd sites across two front ends that a bare array would
    otherwise have had to teach about a null schema. No body is needed because
    nothing produces a second type from it, and no name because nothing looks
    it up.
  - **The empty name is load-bearing.** A tuple outside §6.4.7's domain is
    reported by naming the schema; with none to name, a zero-length spelling
    selects *this array has no components: its upper bound is below its lower
    bound* instead. `tests/extended/dynbounds_empty.pas`.
  - **Each bound carries its own expression**, on the discriminant, where a
    written actual-discriminant-part is a list on the variable. The group's
    second and later names re-resolve the same denoter, so a list built by
    chaining nodes the parser did not chain would be built twice over the same
    nodes.
  - Refused: the same bound in a record field, and in a module's variable
    (`tests/extended/dynbounds_errors.pas`,
    `tests/extended/module_sema_errors.pas`).
- **A type-definition's bounds belong to the block** (ADR-0127), which is the
  half of §6.2.3.8 b) the entry above left. A type-definition is
  closest-contained by the block, so `type t = array [1..m] of integer` and
  `type t = vec(m)` inside a procedure are legal — and the answer was the
  sentence ADR-0113 stopped at: a variable's descriptor belongs to the
  variable, a type's belongs to the **block**.
  - **A hidden frame variable of the block holds it**, named `bnd$N` for the
    reason `for$` and `with$` are: the Sema dump prints a frame's variables and
    a nameless one is indistinguishable from the next.
  - **The slot is claimed after the denoter is resolved.** Reserving one for
    every type-definition would move the layout of every frame in every
    Extended Pascal program, so the symbol is built outside the frame and
    joins it afterwards, with the `frameIndex` of every discriminant already
    built against it corrected.
  - **A variable of the type shares the discriminant *symbols***, not a copy of
    their values, and holds only the address in its own slot. That is what
    makes the extent the type's: nothing anywhere can hold a different answer,
    and §6.4.1's "one type-name, one type" survives — `a := b` between two of
    them is an assignment. Evaluated once per activation however many variables
    there are, which `tests/extended/dynbounds_type.pas` counts.
  - **A parameter of such a type needs no descriptor**, one thing simpler than
    a schematic formal: the bounds are in an enclosing activation record and
    the static chain reaches them.
  - **And a bare dynamic subrange was confined to an index-type**, which
    ADR-0133 below lifted. A bound worked only where the *subscript* check read
    it out of the descriptor; a subrange's own bounds were read by the range
    check at a store, which compared against the two numbers on the type, so
    `array [1..m] of 1..m` trapped on a legal store with the upper bound
    reading zero — present since ADR-0113, refused since ADR-0127.
- **The check at a store reads the descriptor** (ADR-0133), which is what was
  left. `CheckedForSubrange` calls `BoundValue` for each end instead of reading
  the type's two numbers, so `var x: 1..m`, `type t = 1..m` and
  `array [1..m] of 1..m` work and `dynBoundsIndex` — the one-shot flag that
  expressed the confinement — is deleted from both implementations.
  - **A subrange needed no clause of its own about sizing**, which is why the
    change is small: §6.2.3.8 b) is otherwise about storage whose extent is not
    known until entry, and a subrange's storage is its host's whatever its
    bounds are. Its bounds decide what a store is *compared against* and
    nothing else.
  - **The comparison moves to i32** where a bound is dynamic, that being the
    width a discriminant is loaded and widened to; a char or boolean value
    widens to meet it, exactly as the subscript check widens an index.
  - **`DynamicExtent` had to start answering no for a subrange**, which was
    invisible while the only dynamic one anywhere was an array's index-type —
    a position asked about the *array*.
  - **The anonymous schema leaked into two rules about §6.4.8's.** ADR-0113
    hangs a schema with no body and no name on such a type, and `Assignable`
    read it as a schema — so `x := 3` into `var x: 1..m` was refused — while
    the assignment lowering turned a four-byte store into a tuple check and a
    memcpy. Both are exempt by kind now: the schema on a subrange is a compiler
    device, not something a schema-definition produced.
  - **The message is built by the runtime**, and this is the part that looks
    like it needs no work and does. Where the bounds are constants the trap
    names the *type*; `WriteTypeName` handles a dynamic bound by writing the
    discriminant's own name, which is right for a schema and empty for a bound
    the program wrote as an expression — so the compile-time path produces
    `value out of range (1..)`, which is the defect's own message. Ordinal
    numbers instead, as `pas_index_error` prints them and for the same reason.
  - **§6.4.2.4's other requirement gained a check**: an empty dynamic subrange
    is reported at the declaration rather than at the first store, because a
    block that never stores would otherwise run with a type that is not a type.
  - Refused: a record's field, a set's base type and a file's component — the
    first and the third only until ADR-0134 below, which is the record that
    read that reason back and found it naming the check rather than the
    obstacle.
- **The register, read end to end** (ADR-0134). Seven entries of
  `doc/implementation-defined.md` and `doc/sop.md` §7, taken to their end in one
  pass — five closed, two narrowed, and none closed by deciding it did not
  matter. The pattern worth keeping is *why* they were open: each reason had
  either expired, been about the wrong thing, or been the cost of a mechanism
  since built for something else.
  - **§6.7.2's result variable.** A function with a result-variable-
    specification that never wrote to it compiled and returned whatever the
    slot held. §6.7.2 asks for "at least one statement threatening" it and
    §6.9.4's *threatens* is weaker than *assigns*, which is what the assignment
    flag could not answer — and the weaker word already had a walker, called at
    every one of the clause's six sites and nowhere else. The flag is set
    *there* rather than at the six call sites, and unconditionally: what is
    recorded is that the variable was threatened, not whether the threat was
    allowed.
  - **§6.4.3.3's region at a constant occurrence**, which was the whole of
    `doc/implementation-defined.md` §6.1 — the one program this compiler was
    known to accept that ISO 7185 requires it to reject. ADR-0112 asked at every
    *type-name* occurrence; a constant one goes through the expression checker
    instead. `inSchemaBody` keeps it exact: a production written inside a record
    re-resolves the schema's body, which is lexically outside it. `EvalOrdinal`
    now clears `constReported` *before* checking the expression, so the vaguer
    "must be ordinal constants" does not follow the specific message.
  - **§6.4.3.6's file length.** An eleventh component written to a
    `file [1..10]`. Only one thing grows a file's length, so the check is in
    `put` and nowhere else — `update` overwrites in place and a seek is already
    refused past the end. The capacity is a `pas_file_init` argument, zero
    meaning no bound worth carrying; the struct grew a field and stayed 112
    bytes.
  - **§6.4.9's type-inquiry-object**, and this one needed the clause rather
    than the paraphrase. A parameter-identifier's defining-point must be in the
    formal-parameter-list closest-containing the object — and §6.7.3.1 is what
    makes that a rule about *where the inquiry is written*, giving such an
    identifier **two** defining-points, as a parameter-identifier for the list
    and as the associated variable-identifier for the block. Inside the block it
    is the second, which is why the clause's own example is legal. One saved
    symbol across `BuildFormals`' recursion is the whole implementation.
  - **§6.2.3.8 b) through a record and a file.** A record is no kind of block,
    so a bound written inside one is still closest-contained by the block the
    declaration is in. What is refused is the consequence rather than the
    position — a field or component whose *size* the bound decides — and the
    test is `DynamicExtent`, asked in `AddField` and `ResolveFile`. Passing the
    offer through **without** that check was measured first: it compiles
    `record a: array [1..m] of integer; g: integer end` and silently
    miscompiles it, which is ADR-0045's offset problem happening.
  - **§6.9.1's read of an int64**, ADR-0128's one asymmetry. The clause is the
    same sentence at both widths, so `wide` selects the limit rather than a
    second copy of the loop selecting everything — and the overflow moved from
    after the accumulation to during it, which is not tidying: `value * 10`
    would already have wrapped.
  - Still open: §6.11.3's constituent-identifier region, which no program
    distinguishes; the definedness errors of Annex D, which need a mechanism
    this compiler does not have; and a set of a dynamically bounded subrange.
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
    from and a shorter length. Only `+` makes new characters, and **eight**
    things in the compiler take arena storage. Four are arms of `EmitString`:
    concatenation, a char given an address so it can stand where a string does,
    §6.7.6.9's `date` and `time`, and AP 6.4.15.7's join of two texts. Four are
    not: ADR-0122's NUL-terminated copy at a foreign call, ADR-0171's padded
    actual for a fixed-string value parameter, a text's store, and the operand
    of a text comparison that is not already a text. It was three when this
    paragraph was written, and that they are no longer all in one routine is
    the reason the next bullet's counter matters.
  - **A string temporary lives for one statement, and CodeGen says so**
    (ADR-0111). The arena is a stack: `@pas_str_at` is read into an SSA value in
    every prologue and stored back at the end of any statement that took
    storage, and after a `while` or `repeat` condition, which is the one
    expression a statement evaluates twice. Which statements need it is
    answered by a *counter* every producer bumps — the emitter's own account of
    what it emitted, rather than a predicate over the tree free to disagree
    with it — and the store goes *after* the statement because a sequential
    emitter cannot go back to put a mark in front of one.
    `tests/extended/str_arena_loop.pas` fails without it, at about 52 000 of its
    200 000 iterations; `tests/dialect/foreign_string.pas` and
    `tests/dialect/text_arena_loop.pas` are the same instrument for the other
    four producers, and all eight are mutation-checked. **A loop that pins a
    producer has to isolate it**: the counter decides whether a *statement*
    releases, so a bump dropped from a producer sharing its statement with
    another changes nothing — `t := a + b` over texts holds two of them, which
    is why the loop pinning the join compares rather than assigns.
  - **It was a ring until then, and wrapped in silence.** A wrap wrote one live
    value over another, so `a + a = b + b` over two 512K strings compared one
    buffer with itself and called two different values equal, exit status 0
    (`tests/extended/str_arena_overflow.pas`). Both ways of exhausting the arena
    are now reported, which is ADR-0110's rule; the limit is
    `doc/implementation-defined.md` §6.
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
    `158549b` added — see `tests/extended/schema_string_compare.pas`, which
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
  - **A real is rounded away from zero, on its exact decimal expansion**
    (ISO 7185 6.9.3.4.1-2, ISO/IEC 10206:1991 6.10.3.4.1-2, ADR-0169). The
    clauses prescribe `abs(e) + 0.5 * 10.0 pow(-FracDigits)` and then Truncate,
    which is half-away-from-zero where printf is half-to-even -- a silent
    one-unit difference at every exact halfway value. Two things make the
    implementation short. The arithmetic is **exact**: executing the clause in
    real arithmetic is defensible from `Truncate(y: real; ...): real` and is
    refuted by the denormal, where `10.0 pow ExpValue` underflows and 1e-320
    prints as zero -- 6.10.3.4's own "a decimal representation of the value of
    e, *rounded*" is what governs. And on an exact expansion the algorithm is
    one test: adding half and truncating at p rounds up exactly when the
    discarded tail reaches a half, so the answer is `d(p+1) >= 5` and no later
    digit matters. The expansion is finite -- a double is dyadic, and 2^-1074
    is the smallest -- so printf at 1074 fraction digits rounds nothing and the
    digits can be worked on directly; the floating-point form reads its
    exponent off `%e` rather than dividing, which is where the denormal went.
    The sign is separate and conditioned on the **rounded** magnitude, so
    `-0.000001:0:2` is `0.00` and a negative zero is unsigned.
    `tests/write_real_round.pas` and
    `tests/extended/write_real_round_zero.pas` are the cases, and their goldens
    come from a separate implementation of the clause rather than from this
    one -- 5022 swept cases agree.
  - **6.9.4's ten threats have two consumers, and only one wants a refusal**
    (ADR-0169's sibling in ADR-0168's audit). 6.7.2 asks whether a result
    variable was threatened at all; 6.7.3.1 and 6.8.3.9 ask whether a
    particular threat is allowed. Entry e), `new(p)`, was on neither list and
    is observable on the first: a constructor allocating its own result was
    refused for never writing to it, with no workaround, a pointer result
    having nothing to assign it but `new`. `RecordThreat` is the recording half
    and `Threatened` calls it before the refusal, because for `new` the refusal
    is unreachable -- 6.4.1 makes a pointer nonprotectable and a
    control-variable is an ordinal -- and a message no program can produce is
    what `unreachable_diagnostics.txt` exists to keep out. Entry j),
    `bind`/`unbind`, is deliberately *not* recorded: a result variable can
    never be a file (6.4.6 a)), so it could change no answer and no test could
    catch its absence. `tests/extended/new_threatens_result.pas`.
  - **A conformant array's actual is on 6.9.4 b)'s list too, and reaching it
    fixed two opposite defects** (ADR-0170). The conformant-array arm of the
    argument check is separate from the ordinary var-parameter arm and never
    asked, though 6.7.3.7.3 calls its actual "an actual-parameter corresponding
    to a formal variable parameter" in those words and 6.5.1's own
    cross-reference names 6.7.3.7.1 as one of the three sources of a protected
    variable-identifier. So `protected` was defeated -- a protected variable
    handed to an unprotected variable conformant array was written through,
    exit 0, and through a record field as well -- *and* 6.7.2 could not see the
    threat, so a function filling its result through such a parameter was
    refused for never writing to it. The parameter kind is asked because the
    value form threatens nothing: 6.7.3.7.2 attributes the expression's value
    to a variable of the activation. `tests/extended/protected_conformant.pas`
    and `tests/extended/conformant_threatens_result.pas` are the two
    directions, and `funcresult_errors.pas` carries the value form beside the
    var one.
  - **A for statement's control variable must be nonbindable** (6.9.3.9.1,
    ADR-0170), which is the second half of the sentence whose first half is
    "shall possess an ordinal-type". 6.5.1 makes a bindable variable
    totally-undefined while it is unbound, so a loop over an unbound one
    attributes a value to a totally-undefined variable and a loop over a bound
    one writes an external entity once an iteration -- which 6.9.3.9.2's
    equivalent program fragment says nothing about. Asked through
    `DesignatorBindable`, and needing no `--std` guard because `bindable` is
    not in ISO 7185's lexis. `tests/extended/forvar_bindable.pas`.
  - **A constant-access naming a *structured* component is a second way to
    define a constructor's storage** (6.8.8.1, ADR-0170). ADR-0069 fills a
    6.8.7 constant's zeroed global from the prologue of the block that defined
    it, and the test for "defined it" was whether the folded node is the
    written expression -- which a constant-access is not, its fold answering
    with the component's node. `ConstAddress` memoises that node into a global
    of its own, keyed on a different node from the container's, so nothing
    filled it: `row = grid[2]` then `row[i]` printed 0 where `grid[2][i]`
    printed the right number, in one program and with no diagnostic. What must
    still *not* fill is a plain constant-name, `const b = a` sharing a's
    storage, and a module-qualified name (6.11.3) is that same alias. Only an
    array or a record was affected; a string component, a set component and an
    alias were right throughout and are the test's controls.
    `tests/extended/const_access_component.pas`. The clause was triaged
    `structural` and so was in no work queue, which is the direction ADR-0106
    warns about.
  - **A value parameter of a fixed-string type is padded, not refused**
    (6.7.3.2, ADR-0171). 6.7.3.2 holds the actual to *assignment-compatibility*
    with the formal's type, and 6.4.6's last paragraph then treats a
    canonical-string value assigned to a fixed-string-type as "the components
    ... followed by zero or more spaces" -- 6.4.3.3.1's NOTE says so outright.
    This compiler refused a shorter actual and the diagnostic gave a lowering
    as the reason: *a value parameter is copied rather than padded*. What was
    missing was storage -- a structured value parameter travels as an address
    (ADR-0017) -- and ADR-0115 supplies the mirror of it: there the callee's
    prologue converts because the capacity is the callee's, here the *call*
    converts because the formal's capacity is written in the formal. The
    padded value is built in the string arena, whose lifetime is the statement
    (ADR-0111) and which an alloca could not have been (ADR-0102), so the new
    arm bumps that counter. `PadsToFixedString` is asked by both Sema and
    CodeGen and answers **false** for an actual that is already a char array of
    the formal's length, so nothing that compiled before is lowered
    differently -- and false under ISO 7185, which has neither 6.4.5 d) nor
    6.4.6 f). `tests/extended/fixedstring_param.pas` and
    `tests/extended/trap_param_capacity.pas`.
  - **A variant-part-value must name the tag field its variant part declares**
    (6.8.7.3, ADR-0171). Two sentences require it -- the selector's
    field-identifier "shall have an applied occurrence in the
    tag-field-identifier of each variant-part-value", and every component of a
    field-list "shall have exactly one applied occurrence" in the
    field-list-value. The grammar's `[ tag-field-identifier ':' ]` is optional
    for a variant part whose selector has *no* identifier, and was read as a
    licence to omit one that has. Three of the four shapes were already
    checked; only the omission was missed, and `structvalue.pas` was writing
    it with a comment asserting the rule the compiler implemented.
  - **`index` folds, and `substr` still does not** (6.7.6.7, 6.8.2, ADR-0171).
    The two-argument arm of the constant folder was written for `succ(x, k)`
    and `pred(x, k)` and asked their question -- is the first operand ordinal
    and the second an integer? -- of everything, so `index` was refused with
    *not a compile-time constant* and 6.3.2, the standard's own example of a
    constant-definition-part, did not compile. Neither reason that keeps a
    required function out reaches it: the result is an integer, so no real is
    converted, and the operands are literals already in the pool, so no
    computed string has to be named (ADR-0068). ADR-0054 found the same arm's
    other three misses. `tests/extended/constexpr_required_functions.pas`.
  - **Reading a string at end of file is D.97's error and is reported**
    (6.10.1, ADR-0171). D.97 makes `read` at `f0.R=S()` an error whatever is
    being read, and the char form reached it through 6.10.1 b)'s buffer
    variable while the two string forms of e) and f) reached nothing and
    answered with spaces and the null-string -- one procedure, two answers to
    one clause. End of *line* is untouched: NOTE 6 and NOTE 7 give it the
    null-string and still do, `readstr` included, because 6.7.5.5's auxiliary
    text file carries a line terminator. It stops programs that used to run.
    `tests/extended/trap_read_eof.pas`.
  - **A char is a legal assignment destination for a string value**
    (6.4.5 d), 6.4.6 f)), and the guard that chooses the string path asks
    `IsStringOrChar` of the *destination* for that reason. Asking
    `IsStringType` -- true of every string-type and false of `char` -- let
    `c := s` fall into the scalar store and put the string's pointer in an i8
    slot, which clang refuses; `c := s[i..j]` reached a different arm and
    stored chr(0) in silence. `EmitStringStoreValue` had the char arm
    throughout, and `pas_str_store_char` is 6.4.6 c)'s error and 6.4.6's
    space-padding in two lines, so the whole defect was the caller's predicate.
    `tests/extended/char_from_string.pas` sweeps nine spellings (ADR-0168).
  - **An initial-state-specifier follows any of a type-denoter's four bases**
    (6.4.1), the discriminated-schema included, so `var t: string(4) value 'jk'`
    initialises exactly as `var t: s4 value 'jk'` does. `CheckVarDecl` splits
    into a schema path and an ordinary one because 6.2.3.2 lets a schema's
    discriminants be variables, and only the ordinary one called
    `InitialStateOf`: the schema path resolved the denoter -- so a *wrong* value
    was still reported -- and then dropped the state. A global was zeroed; a
    local read its own frame slot and printed the stack.
    `tests/extended/initial_state_schema.pas` covers both storage classes and
    the group-sharing (ADR-0168).
  - **The question is asked of the variable-access, not of its root**, because
    §6.7.5.6 and §6.7.6.8 both say "the variable-access f". Asking the
    entire-variable was wrong in both directions: `bind(r.log, b)` over a
    bindable field was refused *naming the record*, and a `p^` was let through
    whatever the domain denotes, there being no `nkVar` under a dereference to
    ask. Bindability therefore travels on the field and on the array's
    component beside the initial state (§6.4.1 names the three in one breath),
    and not on the type — `type bt = bindable text` hands it on without making
    a type distinct from `text`, so a flag there would answer the same for
    both spellings. `DesignatorBindable` is the walk and `NotBindable` the one
    message all four routines share. The dereference is **left** as it is: for
    `^bindable text` it is right, for `^text` it is not, and a pointer's domain
    reaches Sema through the deferred and pending paths where the denoter that
    knows is out of hand — `doc/implementation-defined.md` §6.1 carries it as
    the one program accepted that the standard requires rejected. `tests/extended/bind_qualified.pas`
    is the case; dropping the field arm fails `binding_errors`, `difftest` and
    `dialect-containment` at once.
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
  - **And it may not be a field of a variant part** (ADR-0163) — §6.4.3.4's own
    sentence, unread until `CONF068` sent someone to the clause: a
    variant-denoter shall contain no type-denoter denoting a restricted-type,
    the bindability that is bindable, or a structured-type having such a
    component. Not an error (Annex D's D.3 for that clause is the
    discriminant-selector rule), so clause 5.1 e) makes reporting it
    compulsory. Two limbs asked two ways, and the asymmetry is the clause's:
    restrictedness is on the *type*, so `ContainsRestricted` recurses over it
    exactly as `ContainsFile` does, while §6.4.1 puts bindability on the
    *type-denoter*, so `BindableOf` is asked of the denoter at the call site —
    `type bint = bindable integer` hands it on, and the arm must be refused for
    a word it does not contain. `tests/extended/variant_denoter.pas` carries
    the legal control in the same file, the restriction being on the
    variant-denoter and nowhere else.
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
  `doc/implementation-defined.md` states the compliance level (**level 1** since
  ADR-0153 — conformant array parameters are accepted; it said level 0 for as
  long as they were not, and a specification audit found the sentence still
  saying so afterwards), answers all 52 entries of
  ISO/IEC 10206:1991's Annexes E and F and all 28 of ISO 7185's, names the
  errors that go unreported, and lists the extensions and restrictions.
  Answering an entry meant compiling a probe, which is what found the two.
  - **The unreported-errors section is keyed to Annex D and regenerable.** Its
    ISO 7185 half was reconciled against all fifty-nine entries using the BSI
    suite's `ERROR` category, which has a program per entry; each such row of
    `tests/bsi/expected.tsv` carries the Annex D number it names, so the list
    is data rather than prose. Eight entries were missing when that was first
    done — the section had been written one feature at a time and nothing had
    read the annex end to end against the compiler. Don't quote a count of
    them anywhere: it moved once and will again.
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
  - It was found by ADR-0071's sweep and **written into the roadmap instead of
    fixed**, which is the only reason it outlived two more
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
- **A defining-point precedes its applied occurrences** (ADR-0088). ISO 7185
  §6.2.2.9: a name used in a block may not then be declared in it. Enforced
  before only where the name resolved to *nothing* (ADR-0069's `var v: t`
  before `type t`); where it resolved to an enclosing declaration the earlier
  uses kept the outer meaning and nothing said so.
  - **One integer per symbol and one per block.** `Lookup` stamps the symbol it
    found with a counter; a block entry records the counter; `Declare` asks
    whether the *outer* symbol of that spelling has been applied since this
    block was entered. The **latest** application is enough, because the check
    runs at a defining-point and nothing later has happened yet.
  - **The comparison is with the block, not the depth.** A sibling procedure's
    body is at the same depth and is not in this block, and shadowing there is
    what the rule permits — a depth test reports it, and
    `tests/definingpoint_order.pas` leads with the two procedures that must not
    be reported for that reason.
  - **`Lookup` and `LookupRaw` are split, not flagged.** Resolving a name the
    program wrote goes through the first; asking whether a name is *taken*
    goes through the second. Asking the second question through the first
    records an applied occurrence for a defining one and refuses every
    redeclaration in the language.
  - **The exception needed its own line, and another feature's test found it.**
    A pointer domain may name a type defined later in its own
    type-definition-part, so `ResolvePointer` looks the name up without
    recording an application; `tests/pointer_domain_shadow.pas` is what went
    red first.
  - Not caught: the same rule where the earlier occurrence is a **required
    identifier**, which is recognised by name and so is not a symbol to stamp.
    ADR-0087's seam from the other side, and the answer to both is to declare
    the required identifiers as symbols.
- **A record type is a region** (ADR-0098, ADR-0112). §6.4.3.3 gives a
  field-identifier its defining-point in the record-type, and §6.2.2.4 makes its
  scope that whole region "and all regions enclosed by that region" — so a
  spelling written anywhere inside the denoter is an applied occurrence of the
  *field*, and a field is not a type.
  - **Asked of the denoter, not of the type.** The fields do not exist as
    symbols yet; the record is being resolved. That is also why the *whole*
    denoter is scanned rather than the part already seen —
    `record a: fred; fred: integer end` is refused for a field declared after
    the occurrence, the region being the record and not the text before the
    point.
  - **One function, asked at three occurrences** — a pointer's domain-type, a
    type-name and a schema-name. It was only the first for a long time, because
    that is where BSI's DEV043 pointed; the clause names no production, so
    enforcing it there alone was a different rule (`tests/record_region_field.pas`,
    `tests/extended/record_region_schema.pas`).
  - **Asked *before* the lookup**, because a field's defining-point is nearer
    than the region enclosing the program where the required identifiers live —
    which is what makes `record f: integer; integer: real end` refuse its own
    first field. Resolving first and testing afterwards would make the answer
    depend on whether a type of that name happened to exist.
  - Not caught: a **constant** occurrence — `array [1..fred]`, a field's
    initial-state expression — which goes through the expression checker and is
    not asked. `doc/implementation-defined.md` §6.1 carries it.
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
- **A limit is reported, not applied in silence** (ADR-0110). A security audit
  found three fixed bounds that were reached without a word, and none of them
  was memory-unsafe — what they were is worse in a different way, a compiler
  quietly disagreeing with its own input. `strMax` kept the first 255
  characters of an identifier and dropped the rest, so §6.1.3 making *every*
  character significant meant two names became one and a program could assign
  to one and read the other; the same bound truncated a character-string, so
  `writeln` of a 300-character literal printed 255 and the output did not match
  the source; and `ParseBlock` counted no nesting level, so 1001 nested
  procedure declarations indexed the scope stack off its end and the user got
  `array index out of bounds` on **stderr**, where this compiler's diagnostics
  go to stdout — a caller redirecting stderr saw a non-zero exit and no message.
  - **Reported, and not raised.** `strMax` bounds a `packed array [1..strMax]
    of char` that is frame storage in the lexer and in every routine holding a
    `str`, so raising it multiplies stack use across the compiler for a case no
    real program has, and whatever it became a program could still exceed.
    Reporting costs one comparison per token.
  - **`StrAppend` still drops in silence, deliberately.** It is the generic
    append and serves message construction too, where there is no source
    position to attribute and no error to raise. The check belongs where the
    scanner knows what it is scanning — and it **counts** rather than asking
    the buffer, because `text.len` is what was kept and the question is what
    was written.
  - **A block is one of the levels the bound was always meant to measure**, so
    a program's own block now costs one and 999 remain inside it.
    `tests/deep_chain.err` and `tests/deep_nesting.err` move by a column or
    two, which is the previous count having been short rather than a
    regression. `selfhost/badparse/ident_too_long.pas`,
    `string_too_long.pas` and `nesting_blocks.pas` are the three that fail
    without it.
  - Every such limit is now stated in `doc/implementation-defined.md` §6, which
    clause 5.1 c) requires and which had none of them. The **runtime's** limits
    were outside this — `pas_str_temp`'s ring wrapped in silence and the record
    called probing it the obvious next thing, which ADR-0111 then did.
  - Not done: a sweep of the remaining fixed arrays. Two were checked
    (`maxImports` and the command-line arguments) and were recorded as already
    reporting; the rest are bounded by construction or by a limit checked
    elsewhere, and the record says so rather than implying an audit happened.
    **Half of that was wrong and ADR-0158 is the correction** — `maxImports`
    reports because a counter can be compared, and the argument list could not,
    for a reason no reading of this compiler would have found.
- **One more program-parameter than the limit** (ADR-0158). An unbound
  program-parameter is the only end-of-list a Pascal program has (ADR-0081), so
  a compiler declaring *n* of them cannot distinguish *n* arguments from *n*
  plus any number: the twelfth binds, the thirteenth is not asked about, and
  everything past it is discarded in silence. `tests/dialect/lib_os.pas` needed
  exactly twelve, so one added flag pushed the `-o` file name off the end and
  the complaint named the wrong argument — `-o needs a file name`, about an
  argument that had been written. The limit is `argMax = 24` and there are
  **twenty-five** parameters: `argOver` is declared past the last usable one and
  never read for its name, only for whether it bound at all, which is what turns
  "the list ended" into "the list ended because it ran out". `--dump-limits`
  reports the pool and the tokens and cannot report this one for the same
  reason — a count is what a bound needs and an argument list has none.
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
  it.

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

## The dialect

Seven mechanisms, and the section exists because the first two landed without
an entry here. Nothing in it changes what either conformance mode accepts.

**The mode is an ordinal and the order is a containment** (ADR-0117). `stdKind`
is `(stdIso7185, stdExtended, stdAfterschool)`, and `HasExtended(s)` is
`s >= stdExtended`. Every one of the 40 sites that used to ask
`langStd = stdExtended` asks the predicate instead, which is the whole of what
keeps the dialect from silently switching Extended Pascal off — the equality
test still compiles, still reads correctly, and left 545 of 547 cases
passing. That is why the conversion landed as its own commit before the third
enumerant existed: a no-behaviour-change refactor is reviewable, and the same
edit mixed into a feature is not. `tests/dialect/inherits_extended.pas` pins the
containment itself; ADR-0117 for why the first two modes cannot nest and this
one can.

**A variant's tag is authoritative, in the dialect only** (ADR-0118).
`EmitVariantGuard` runs inside the path walk `FieldAddress` already does, so it
asks one comparison per variant part crossed and activity is a chain rather
than a flag: reading an inner field needs every tag on the way out to select
the arm containing it. Writing a field emits a *store* of the tag; reading one
emits the comparison and an `EmitTrapIf`. Which of the two a designator gets is
`designatorGuard`, a global that `EmitAssign` sets to `vgWrite` around the
target's address and `EmitExpr` clears and restores — so `r.a[i].b := 5` keeps
its spine a write while evaluating `i` as a read, without threading a parameter
through thirty-five callers. §6.5.3.3's violation is an *error* (§3.1), so
detecting it changes the meaning of no correct program, which is what lets a
safety feature into a mode that claims to contain Extended Pascal.
`tests/dialect/variant_tag.pas` and `trap_variant_read.pas`; the trap's
partition is proved for every tag value by `verify/`'s
`variant-completer-is-the-exact-complement`.

**The mode is part of a module's linkage name** (ADR-0119), because the two
rules above are a *pair* and both are emitted at the access. Split them across
program-components translated under different modes and the surviving half is
worse than neither: a dialect component's guard consults a tag a
conformance-mode component never stored, and passes the access. So
`PutModulePart` writes `@m.<module>.<mode>.init`, from `langStd` — the definer
spells its own mode, the caller spells its own, and a program calls that symbol
for every module it activates, so a mixture cannot reach an executable. Two
spellings and not three: what has to be separated is the dialect from the
conformance modes, and §6.11's module makes `--std=iso7185` unreachable here
anyway. `tools/pascalcc` translates the resulting link error, which otherwise
names the mode the *program* wanted rather than the one the object has.
`tests/checks/mixed_mode_link.sh` is the case, and it is a `ctest` case because
`run_test.sh` compiles every component of a case under one `--std` and cannot
express a mixture at all.

**And a module is locked by what it exports, not by the flag** (ADR-0137). The
mode is a proxy for the ABI and far too coarse a one: `lib/pasmath.pas` has no
variant record in it at all, so its object code is identical under both modes,
and a dialect program still could not link it — Sema accepted the program
completely and it died on `m.pasmath.afterschool.init`. So `ComputeModePortable`
asks the *emitter's own* condition — is any type reachable from the module's
interfaces a record with a variant-part whose `tagField >= 0`? — over the
interface instead of at one access, following a field, an array component, a
file component, a pointer domain and a parameter, and answering **true when the
depth runs out**, a cycle never being what makes a module look portable. A
module that answers no emits `@m.x.afterschool.init` as an *alias* of its own
spelling, so only the definer computes the predicate and the caller is
untouched. One direction only: a conformance-mode module gains the dialect's
name and not the reverse, because a dialect module may declare `external` and
is not a conforming program-component (ADR-0120). A tagless variant-part is
portable and falls out rather than being decided — `tagField` is `-1`, so no
check is emitted against it under any mode. `tests/dialect/lib_conforming.pas`
fails without the alias; `mixed_mode_link.sh` grew from four combinations to
seven, and the three new ones are what fail if every module is called portable.
The `.components` sidecar gained an optional second field naming a component's
standard, in both harnesses, because without it no case in `tests/` could
express the mixture.

**A fallible routine answers one record** (ADR-0120), and the shape is the
dialect's first real user rather than a fourth mechanism. `case ok: boolean of
true: (payload); false: (code: ErrorCode)` — `boolean` because §6.4.3.3 with
ADR-0096 wants the labels to be exactly the tag-type's values and a result needs
exactly two, and **nothing assigns `ok`**, the write to the payload being what
sets it. It is a convention and not a library type: with no generics the payload
type is part of the layout, so each producing module declares its own record and
only `ErrorCode` is shared. `lib/` therefore has two layers that do not mix —
ADR-0119 makes that enforced rather than promised — and they duplicate, which is
the price. `tests/dialect/lib_result.pas` and `trap_result_unchecked.pas`.

**A foreign function is a directive, and two types cross** (ADR-0121).
`external 'name'` sits where ISO 7185 §6.1.4 and ISO/IEC 10206:1991 §6.1.4 put
`forward` — an identifier in the one position it may occupy, so nothing is
reserved and a variable named `external` is untouched — and the foreign name is
a *string-literal* because this lexer case-folds identifiers and a linker
matches a symbol exactly. There is no default: deriving one from the other is a
lossy mapping to a name that has to be right, and writing it out is also what
makes the boundary greppable, which is the whole safety property claimed. The
mapping is `integer`↔`i32` and `real`↔`double` and nothing else, decided by a
probe rather than by reading — `clang` passes a `char` as `i8 signext` and a
`_Bool` as `i1 zeroext`, and those two rows need an attribute and an answer
about signedness that this increment does not have. It tests the type and not
`Base(t)`, reversing ADR-0018 everywhere else here: a subrange's values are its
host's only because something promised it, and nothing across this boundary
does. `EmitUserCall` writes no static link for a foreign callee and
`EmitExterns` no leading `ptr` — the mutation that kills
`tests/dialect/foreign.pas` is the call site, the `declare` being unchecked
against a direct call under opaque pointers. `ReservedForeignName` refuses a
name the compiler emits itself, LLVM rejecting any redeclared global, and
`tests/checks/foreign_reserved.py` keeps that list honest in both directions.
`lib/dialect/pasmathx.pas` is the first binding module and holds the shape: it
exports Pascal and keeps the directive to itself.

**And one linker symbol is one `external` declaration** (ADR-0147, AP
§6.7.7.11). Two headings on one symbol emitted two `declare`s of one global,
which LLVM refuses — *invalid redefinition of function 'abs'*, an error about a
file nobody wrote, which is `ReservedForeignName`'s own failure mode from the
other direction. The emitter's duplicate check existed and never fired:
`SameLink` compares the two names' **positions in the string pool** and
`PoolAdd` interns nothing, so two sources of the word `abs` are two positions.
The rule is Sema's rather than a fix to that comparison, because deduplicating
in the emitter is worse than the bug — it keeps the first declaration and lets
`declare i32 @abs(i32)` sit beside `call double @abs(double …)`, which LLVM does
not check under opaque pointers, so an accidental refusal would have become
silent undefined behaviour. Refusing outright also avoids needing a congruity
comparison, which would have meant a third caller of `Congruous` and ADR-0058's
sentence a third time. `tests/dialect/foreign_duplicate.pas` is the case; the
mutation is `prior := nil` in place of the lookup, and it carries `clang`'s own
message into the diff. `SameLink` is left as it is and is now sound by
construction: the only pair of distinct symbols that could share a link name
cannot be declared.

**An address crosses only as an argument, and its lifetime is the call**
(ADR-0122). The objection to a pointer at this boundary was always that it
outlives the call — and *a pointer* does, while **an argument does not**. A
`var` actual and a string actual are both storage the caller owns and outlives,
so neither needs the memory-safety model; a returned `char *` is the callee's
or nobody's and needs it, and needs an optional type before that, because null
is what `getenv` answers in the ordinary course of things. So nothing comes
back as an address. `string` in an `external` heading means `const char *` and
is **not** a schematic formal — there is no descriptor, no discriminant and no
callee prologue, so the actual has only to *be* a string and may be a literal,
a concatenation, a substring or a char. A capacity (`string(20)`) and a fixed
size (`packed array [1..3] of char`) are both refused: a C string carries its
length in-band as the NUL, so the formal states no size and ADR-0115's
prologue-converts guarantee has no callee here to make it. `pas_str_cstr` makes
the NUL-terminated copy in ADR-0111's arena, which is already exactly the
lifetime wanted — longer than the argument list, no longer than the statement —
and being a third arena producer it has to bump the same counter, which
`tests/dialect/foreign_string.pas` isolates with a loop that allocates nothing
else. A NUL *inside* the value traps rather than truncating, and is the one
safety property the increment adds. A `var` parameter of `integer` or `real`
crosses as the actual's address (`int *`, `double *`); a **buffer** does not,
and not for a lifetime reason — it is a pointer and a length whose length is
not in-band, which is the slice decision and belongs to the language. A
procedural parameter is refused because the link is the half with no image at
all. `lib/dialect/pasfs.pas` is what it buys, and what it does not: every
failure there is `errIO`, because `errno` is `*__errno_location()` and a
pointer result is the thing this record refuses.

**An optional is a type, and it is how a pointer comes back** (ADR-0123).
`?T` — a value of T, or nothing. It is here because ADR-0122 refused every
result that is an address and named what it was waiting for: a returned
`char *` may be null, and null is not an error, so trapping would stop a
program on a value the C library returns on purpose and the empty string would
conflate "not set" with "set to nothing". `?` is a character neither standard
admits anywhere, so the lexis costs nothing and the reference front end needed
**no** teaching — `unexpected character '?'` is what it already said, where
ADR-0121's `external` needed six lines in `src/`. The denoter takes a whole
sub-denoter where `^T` takes a name: §6.4.4 restricts a pointer's domain so a
type may close a cycle, and an optional contains its T rather than pointing at
it, so a type that were its own optional would have no size. `nil` is the
absent value and `= nil` the test, so no identifier and no operator is added;
`o^` is the only way to the value and traps when there is none, which is
ADR-0019's check with the same syntax and for the same reason. The guarantee is
that read backwards — **a `T` that is not optional can never be absent** — and
the type discipline is two lines in `Assignable`: an optional takes `nil` and
anything assignable to its T, and nothing takes an optional. Everything else is
refusal by construction, eight of the twelve refusals in
`tests/dialect/optional_types.pas` coming from diagnostics that already
existed. It is name-equivalent (ADR-0017), no exception made for a wrapper, and
`IsStructured` answers yes so a copy, a value parameter and a memory result all
work through the paths that meant "copied whole" already. The representation is
a flag then the value, and the *value* is stored first: an over-long string is
§6.4.6's error, so writing it first means no optional is marked present over
storage a store did not finish. A foreign function may return `?S` for a string
S with a capacity — null is absence, non-null is copied at the call site so no
C pointer becomes a Pascal value, and the capacity is a real check in §6.4.6's
words. `pas_cstr_take` *answers* the flag rather than writing it, so the layout
stays CodeGen's. What it does not do: no flow-sensitive narrowing, so
`if o <> nil then o^` still checks (`doc/sop.md` §7); no non-nullable `^T`,
which ADR-0117's containment forbids; and nothing about the memory-safety
model. `lib/dialect/pasenv.pas` is the user, and refuses to bind `putenv` —
which keeps the pointer it is handed — making it the first place the FFI's
registered blind spot decided an interface.

**A slice is a parameter form, and the pair travels as two words** (ADR-0125).
`array of T` is a formal parameter's type and nothing else — a view of part of
an array, indexed 1..`length` however far into the base it starts. It exists
because Extended Pascal gives a string a substring (§6.7.6.7) and gives an
array nothing, so a routine wanting part of one had to take the whole array and
two indices, which puts the bounds outside everything that checks them. **The
bounds travel with the pointer**: `s[k]` is checked against the length the
callee was handed, which is a different check from the one that made the slice
and is the property a C buffer-and-count pair cannot promise. The lexis cost
nothing a third time — §6.4.3.2 requires a bracketed index-type, so `array of
T` is a syntax error in both standards — and `a[i..j]` cost nothing at all,
being §6.5.6's substring designator with the base's type deciding which it is
(the "ask the symbol, not the syntax" pattern a seventh time). That decision is
gated on the mode, and **difftest is what found that it had to be**: §6.5.6
gives the designator to a string alone, so `--std=extended` must go on refusing
it over an array, and `src/` was right where the Pascal had become wrong. `var`
and `protected var` only, ADR-0046's protected parameter being the read-only
borrow: a slice is a view of the caller's storage and a value parameter is a
copy. The denoter is confined to a parameter's own type — stronger than "not a
variable", and one test instead of a list of positions, since a name that
cannot exist has no place a variable of it could be made. Two slices agree when
their *components* are the same type, which reverses ADR-0017 only in
appearance: that rule is about types a program can write, and this is one it
cannot. **That agreement is compatibility and not comparability** (ADR-0139):
the relational operators ask compatibility too, so `a[1..2] = a[3..4]` rode in
on a rule written for parameter passing and reached CodeGen, which had no
comparison for a two-word descriptor and emitted invalid IR — an error against
a file nobody wrote. AP §6.8.3.5 is the refusal and
`tests/dialect/slice_compare.pas` is what fails without it. It is ADR-0058's
sentence a second time, that a permission granted in a shared predicate leaks
to every caller, and the sentence was already written down. The pair is ADR-0030's shape a fifth time. What it does not do is cross
the foreign boundary, and that is a probe's finding rather than a scope limit —
every length in the POSIX data path is `size_t` and `read`, `write` and `recv`
all answer `ssize_t`, so the argument could cross as an `i64` the compiler
generates but the *result* could not be received, this language having no
64-bit integer. ADR-0128 is the half that answers and ADR-0129 is the decision,
so the boundary is neither a decision nor a mechanism away any more.

**An integer wider than the compiler's own** (ADR-0128). `int64` is the type a
`size_t` and an `ssize_t` cross as, and its whole shape comes from one
constraint that is not a standard's: `selfhost/compiler.pas` is written in this
language, so its own integers are 32 bits and there is no value of the wide
type anywhere in the compiler to fold with, compare, or put in a constant.

- **A value is carried as the text that was written**, all the way into the IR.
  That is ADR-0025's answer for a real literal reached a second time and for the
  same sentence — LLVM's assembler reads the digits, so nothing this compiler
  converts can be converted wrongly. `maxint64` is a required constant whose
  value is nineteen characters, and `Int64TooLarge` compares *text* against the
  limit because neither side is a number this compiler could hold. Nothing
  64-bit folds, which is the price: `const c = maxint64 - 1` is not a
  constant-expression here.
- **And no constant has the type at all** (ADR-0136). A symbol has nowhere to
  keep text, so `const c = 5000000000` is refused — with a message naming the
  type and the remedy, because the generic *is not a compile-time constant*
  would be untrue of a literal. Until that record a wide literal in any
  constant position **stopped the compiler**: `EvalConst`'s closing arm
  enumerates the node kinds that cannot fold and `nkInt64` was missing from it,
  with no `else`, so the folder reached no label. Nothing saw it because
  `int64_types.pas` writes the type name and `maxint64` in every such position
  and both of those fold; only a literal reached the arm.
  `tests/dialect/int64_const.pas` is what fails without the fix.
- **It is numeric and not ordinal**, which is one line in `IsOrdinal` and
  thirteen refusals that needed no message of their own. Every construct that
  refuses it needs the compiler to *hold* the value — a case label, an array
  index, a subrange bound, a set base, a `for` control variable, `succ`, `pred`,
  `ord`, `odd`, `chr`, `in` — so the line is forced as well as preferred. It
  answers where `real` answers instead: `IsNumeric` gains it and the operators,
  `abs`, `sqr` and the widenings pick it up unchanged.
- **`trunc` is the narrowing and the only one.** §6.6.6.3's words are "the value
  of x truncated to an integer" and its own error condition is that no such
  integer exists, so the meaning was already written; an implicit narrowing
  would have put an unwritten run-time check under an ordinary assignment.
- **One emitter, two widths.** `PutIntWidth` and `PutIntMin` take the width and
  every checked emitter takes it from them, so the checked add, the div guard
  and the mod adjustment exist once. Two copies of a checked multiply is two
  places for a check to go missing from.
- **`verify/` proved it by running the rules it already had.** The model was
  written generic in the width, so `WIDE = (32, 64)` establishes the emitted
  code at its real width rather than a second family of rules restating the
  first — a model written symbolically paying a second time, for a type nobody
  had in mind. The narrowing is new lowering and has two rules of its own.


**The command line as a list** (ADR-0173, AP 6.7.6.10). `argcount` and
`argument(k)` are required function-identifiers of the dialect, `int64`'s shape:
shadowable by §6.1.3, and *unknown function* under the conformance modes, which
is Annex B's existing row. The runtime answers both from the `argv` it already
holds for ADR-0081's program-parameter bindings, so the two mechanisms name one
list; `argument(k)` points into `argv` rather than the arena, which outlives
every statement. A bare `argcount` is the one piece with a mechanism: the parser
cannot tell it from a variable and must not try — `var argcount: integer` is
valid Extended Pascal and the first version took it away — so Sema decides by
looking the name up, builds the call, and hangs it off the `nkVar` as `vrCall`,
the husk ADR-0044 describes; `EmitExpr` and `EmitAddress` read it first, and
`IsDesignator`'s nil-symbol answer refuses every position wanting a variable.
`tests/dialect/inherits_extended.pas` declares both names and is what fails if
the decision moves back to the parser; `tests/dialect/arguments.pas` and
`trap_argument.pas` pin the values and Annex A.6.

**A handle is a file variable for a foreign address** (ADR-0174, AP 6.4.12).
`type Dir = handle external 'closedir'` is `tyHandle`: a 32-byte slot — value,
closer, two list links — that `WalkFiles` sets up empty in the prologue and
`pas_handle_done` releases in the epilogue, with the live handles on a runtime
list beside the open files so that `pas_jump_go` and `pas_halt` release what
they abandon with the walk they already do. `IsOwned` is a file or a handle,
`ContainsFile` walks it, and every refusal a file has reaches a handle with no
new arm — `predicate-callers` sweeps a third spelling. Four exceptions are
written beside the rules: the assignment from an external function-designator
of the same type (`pas_handle_set`, releasing the old value; a handle-valued
call may stand nowhere else, enforced by a flag the assignment arm sets),
`h := nil` (ADR-0202 — the same `pas_handle_set` with a null value, so it is
one Sema arm and no lowering: what it assigns is the *empty state* and not a
value, which is why the type still has one way to acquire one), `= nil`
(`EmitHandleTest`, a null word), and lending as an external's value parameter
(`pas_handle_lend`, an error if empty). The closer is declared
`i32 (ptr)` unless an `external` heading already declared the name. The
spelling reserves nothing: an identifier followed by `external` and a string
where a type-denoter ends is a syntax error in both standards.
`tests/dialect/handle.pas` reads every file back, `fputs` being buffered until
`fclose`, so each release is observed; `handle_errors.pas` is the refusals; and
`handle_nil.pas` opens and closes two thousand streams through one variable
under the harness's `ulimit -n 256`, which is what makes an early release
something a test can see.

**A socket is a handle and both ends are strings** (ADR-0203). `PasNet` is the
thirteenth dialect module and the first to reach the network. A descriptor is
an `int` and an integer is numeric (AP 6.4.2.6.2), so a program holding one
could add to it and close it twice — ADR-0151's `int64` door, deliberately not
walked through again. The runtime keeps the descriptor in a structure of its
own and Pascal holds `Socket = handle external 'pasx_socket_close'`.

- **Nothing names an address family, a port or a byte order.** A host and a
  *service*, both strings, go to `getaddrinfo`. That is what keeps
  `<netinet/in.h>` and `<arpa/inet.h>` out of `pasrt_posix.c` — the whole
  addition is `<sys/socket.h>` and `<netdb.h>` — and it is what gives a caller
  IPv6 without a line about it, the loop taking the first address that works.
- **An ephemeral port is expressible without a number type**: listen on
  service `'0'`, ask `Service`, hand the string back to `Connect`. That is how
  `tests/dialect/lib_net.pas` talks to itself, in one activation, `listen`
  having completed the handshake in the backlog before `accept` is called.
- **The line buffer is in the runtime** because a socket cannot use `FILE *`
  for it: a stream opened for update over a descriptor that cannot seek may
  not switch between reading and writing without a file-positioning call.
- **SIGPIPE is ignored where a socket is first made.** Its default disposition
  ends the process with no diagnostic, which is not an outcome an `ErrorCode`
  can report; dropping that one line ends the case with **exit 141** where the
  golden has a code, which is the mutation that argues for it. `signal` is ISO
  C and the alternatives are one system's each.
- **A library may not declare `struct sockaddr`** (ADR-0185's fifth decision),
  and sockets are the strongest case for that rule rather than an exception:
  it is a family of structs, and a program never declares the one it is really
  using.

**A server serves many clients, and the language needed nothing** (ADR-0205).
`PasNet.Wait` answers which of a list of sockets can be read, or accepted
from, without blocking. The list is a schema — `SocketList(n: integer) =
array [1..n] of Socket` — and the flags come back in a slice of booleans; the
whole feature is a library routine over AP 6.4.12, AP 6.4.8 and ADR-0125, and
the specification gained no clause. The client was written before the feature
and compiled, which is what showed that a **move** for a handle was not
standing in front of this: a handle reaches its slot as the `var` parameter
`Accept` writes through, so nothing is ever assigned and no second name is
wanted.

- **The set is built and thrown away inside one call**, which is the safety
  argument and not a simplification. C's shape — a set object built up, waited
  on and asked about — would hold a second name for every socket in it across
  statements, and `clients[k] := nil` would dangle it. Between `Wait`'s first
  statement and its last nothing can close a socket, so the question does not
  arise: ADR-0187's *an ownership question is only a question while something
  holds the address*, a second time.
- **Readiness is two questions and `poll` answers one of them.** `ReadLine`
  buffers, so a client sending two lines in one write leaves the second in the
  runtime with the descriptor quiet. Asking only `poll` leaves a server
  sitting still holding a line it was handed — which is the mutation that
  argues for `pasx_socket_pending`, and why this is a call of the module
  rather than a binding to `poll`.
- **An empty slot is a hole.** POSIX has `poll` ignore a negative descriptor,
  so a closed client needs no compaction and `Wait` needs no skip list.
- **The timeout is pinned against a clock** (§6.7.6.9's `GetTimeStamp`),
  because every other assertion in the case is satisfied by a `Wait` that
  never waits: both ends are in one program, so whatever was written has
  already arrived. `poll(…, 0)` is a mutation that would otherwise print every
  right answer while burning a processor.

**A fallible type is a record Sema writes** (ADR-0176). `T ! E` resolves to
`record case ok: boolean of true: (val: T); false: (cause: E) end`, built by
`ResolveFallible` rather than parsed from a synthesised denoter — §6.2.2.10
makes `boolean`, `true` and `false` shadowable, and a program that redefines
one must still get this type. It *is* a `tyRecord`, distinguished only by a
flag, so the copy, the layout, the parameter, the result and ADR-0118's trap
are inherited and **CodeGen is untouched**. Two rules are new: `Assignable`
takes a value of either side, and `AsFallibleArm` rewrites `r := x` into
`r.val := x` or `r.cause := x` — ADR-0044's husk, so the store and the tag are
the ones that already existed. It must be applied at §6.8.2.2's
function-identifier path too, which is a *different* branch: without it Sema
accepted `f := 1` and CodeGen stored an integer into a record. The rewrite
resolves the field directly rather than re-checking the base, because reading
a function identifier is a recursive call. The tag is read-only through
`Threatened`, which is where §6.9.4's six threat sites already pass, so
`read(r.ok)` is refused along with the assignment. `!` had to be added to
`LooksLikeSubrange`'s terminator set — it ends the denoter on its left, and
without that `integer ! 1..5` scanned as one subrange. `tests/dialect/fallible.pas`
is the type, `fallible_errors.pas` the refusals, `trap_fallible.pas` the read
that stops the program.

**`defer` is a flag in the frame and one function per block** (ADR-0175). A
defer-statement stores 1 in its own `i8` slot; the statement itself is emitted
twice — where the statement-sequence it stands in is completed (`EndSequence`,
called from the compound, the repeat-body and the case-completer, in reverse
source order and each arm clearing its flag first) and inside a runner
`@pN.defer` that takes the block's frame as its parameter. The runner is what
`pas_defer_done` calls, so a `goto` past the block and `halt` reach the armed
statements through the same list-and-mark machinery the files and handles use
— a third list, walked *first* in both `pas_jump_go` and `pas_halt` because a
deferred statement may still write to a file the block owns. Taking the frame
rather than allocating one is what makes every name in a deferred statement
mean there what it meant where it was written: `irLevel` is the block's, so
`FrameAt` of that level is the parameter. Storage is one bit per
defer-statement and not a stack, which is why a `defer` in a loop costs the
same as one anywhere else — a defer-statement can be pending only once, its
sequence not being re-enterable, and arming what is armed has no effect. The
sequence and not the activation is the unit because of the loop: a
per-activation defer would run `dispose(p)` once with the last `p`. A label
and a `goto` inside a deferred statement are refused because it is emitted
twice. `tests/dialect/defer.pas` observes every exit, `defer_halt.pas` the one
that ends the program, and `defer_errors.pas` the refusals; removing
`EndSequence` from the compound leaves the loop's two lines missing.
**`exit` is a forward-referenced label and one assignment** (ADR-0177). AP
6.7.5.9 terminates the activation of the block the statement stands in, and the
lowering is the epilogue the block already had: the first `exit` of a body
claims a block number, each writes `br label %LN` and opens a fresh block for
what follows (`EmitGoto`'s shape exactly), and `EmitExitTarget` writes one more
`br` and the label itself between the body and `CloseFiles`. The label is used
before it is defined, which textual IR admits and an instruction list would not
— the sequential emitter cannot return to a block it has left (ADR-0025). So
everything terminating an activation owes gets discharged by code that was
already there: the armed statements (`pas_defer_done` at the head of
`CloseFiles`), the files and handles, and the load of the result slot. The four
call sites are a procedure body, a module's initialization, its finalization
and `main` — where the exit is the *ordinary* end, so `EmitFinis` still runs
and that is the whole difference from `halt`. `exit(e)` is an `nkAssign` Sema
hangs on the node (ADR-0044's husk) with the argument moved out of `pcArgs`,
and `CheckResultAssign` is the one routine deciding both spellings of a result
assignment, so §6.7.2's "at least one", AP 6.4.13's arm shorthand and
assignment-compatibility cannot answer differently for `f := e` and for
`exit(e)`. `tests/dialect/exit.pas` observes each obligation, `exit_module.pas`
the three activations that are not a procedure's, and `exit_errors.pas` the
refusals; moving `EmitExitTarget` after `CloseFiles` leaves the file empty and
two armed statements unrun.

**`try` is a `with` binding and one branch** (ADR-0178). AP 6.8.9's `try(x)`
yields `x.val` where `x` succeeded and otherwise leaves the enclosing function
with the cause — and it is three husk nodes (ADR-0044) and a frame slot, with
no new mechanism in CodeGen at all. `CheckTry` binds the operand to a hidden
`skVarParam` slot, which is `EmitWith`'s binding line for line and is there
because all three husk reads designate through it: `try(f(x))` calls `f` once
where the expansion a reader writes for it calls it three times, and that is
the construct's one observable difference from the expansion. `clOk` reads the
tag, `clFail` is an `nkAssign` handed to `CheckResultAssign` — so `f := e`,
`exit(e)` and `try` cannot answer differently about a result — and `clVal`
reads the value; `EmitTry` writes a `br i1` and the branch `EmitLeaveBlock`
already wrote for `exit`. Everything downstream needed nothing: a value-type
that is a string, an array or a record is a *field of a record*, so
`EmitString` and `EmitAddress` answer through the path they had. The two field
reads carry ADR-0118's tag check and neither can fire, each being emitted on
the branch its arm is active on; they are left in because suppressing them
would be a second opinion about the tag beside the branch itself. The spelling
is a required function-identifier because no *position* would serve — a factor
may be a variable-access, so `try (x)`, `try [x]`, `try + x`, `try - x`,
`try.f` and `try^` are all things a program declaring `try` may write, which
is where ADR-0176's `try X` sketch failed. `tests/dialect/try.pas` observes
each obligation and `try_errors.pas` the five refusals; removing the binding
leaves the behaviour cases green and fails one spec scenario, which is why
that scenario counts the calls.

**A buffer crosses as the pair C already takes** (ADR-0129). A slice reaches a
foreign routine as `(ptr, i64)` — the address of the first component, then how
many there are, two arguments from one formal — which is what `read`, `write`,
`recv`, `send` and `snprintf` take, so the emitted `declare i64 @read(i32, ptr,
i64)` is byte for byte what `clang` writes. Three things decide it.

- **The program cannot write the count.** The Pascal heading has one parameter
  where C has two, so the length is one the compiler computed from the
  designator and checked against the array. The rejected alternative — an
  address alone — reads as the neutral choice and is not: a length travelling
  separately from its pointer is the hazard the slice exists to remove, placed
  where ADR-0121 established that nothing is checked.
- **The component list is `ForeignType`'s plus `char`**, and both halves are
  ADR-0121's rule read again. That rule tests the type rather than `Base(t)`
  and was argued with a side — passing a subrange is sound, returning one is
  not — and a slice is storage the callee *writes*, so every component is on
  the returning side. `char` is the addition because its refusal by value was
  about `i8 signext`, a register convention an array component does not use,
  and because in memory the type has no bit pattern that is not a value of it.
  That property is the test, and `boolean` fails it 254 ways.
- **The `declare` is documentary and the call site is the ABI.** Writing `ptr`
  where `ptr, i64` belongs — so the declaration and the call disagree about
  arity — survives the whole suite, which is ADR-0121's registered gap
  confirmed for arity rather than for types. So does dropping the `sext`, both
  target architectures zeroing the upper half of a 32-bit register write. Both
  are in `doc/sop.md` §7.

**A record crosses when C lays it out the same way** (ADR-0184, AP 6.7.7.6.2).
A `var` parameter of an external-declaration may be a record, and what makes it
sound is that nothing had to be made to agree: `RecordLayout` rounds each field
up to its own alignment, takes the widest as the record's and rounds the total
to it, which *is* C's struct rule. A Pascal record of `struct stat`'s fields
emits `memcpy(..., i64 144, ...)`, C's own `sizeof`, at C's own offsets — a
measurement taken before the feature was designed, and the reason the roadmap's
estimate of this item was wrong.

- **Nothing is spelled and nothing is lowered.** `var buf: StatBuf` at an
  `external` heading is a position that always existed and was refused, so this
  is the first dialect feature needing neither of ADR-0140's two shapes; and
  `EmitForeignArgument` already wrote `EmitAddress` then one `ptr` operand for
  every var parameter, so `model-drift` reports the edit as outside both
  modelled regions and asks for no trailer. The whole change is one arm in
  `CheckForeignHeading` and `BadForeignField` beside it.
- **The fields decide, and the list is ADR-0129's for ADR-0129's reason.**
  `char`, `integer`, `int64`, `real`, a fixed array of one of those, a record
  of them: the callee writes through the address, so a type with a byte pattern
  that is not a value of it cannot be admitted. A variant part is the one
  refusal about *this* compiler's representation rather than a value set — an
  arm is laid over `[k x iN]`, which no C union rule produces.
- **`packed` is admitted and means nothing**, packing not affecting layout here
  at all — so it is not a way to spell `__attribute__((packed))`, and the probe's
  nested struct is `{ char c; int n; }` precisely so the corpus fails if that
  ever changes.
- **The oracle is in the runtime, not the corpus.** The claim is that two
  compilers agree about offsets and no one side can check it, so
  `pasx_record_probe` is a struct in `runtime/pasrt.c` filled with values no
  other member could hold — the C compiler builds one side, this compiler the
  other, and `tests/dialect/foreign_record.pas` is them meeting. It is in the
  runtime because the claim is per *target* (ADR-0028), so the question has to
  be askable on a machine that is not this one.
- **What it does not close** is that the declared fields are the struct's
  fields — the same unchecked claim as every `external` signature.
  `doc/sop.md` §7 carries it. (The other half it left open — a callee-owned
  struct pointer — is ADR-0187 below.)

**A struct claim is checkable, and a library may not make one** (ADR-0185). The
half of the above that *can* be closed is closed by a gate rather than a
language feature, because only a C compiler holding the real header can answer
it and `tools/pascalcc` is already the one place that shells out to `clang`.

- **The claim is a comment**, `{ @cstruct: TimeSpec = struct timespec, <time.h> }`
  with a `@cfield:` per field — ADR-0166's route for `{ @std:iso7185 }`. A fact
  about C is not a statement about this language, so it does not belong in the
  grammar, and having no syntax it needs nothing from `src/`.
- **`--dump-layout` is the compiler's half**, shaped like `--dump-limits`
  (ADR-0148): whole pipeline, writes at the end, outside `--dump-all`, so
  difftest's three sections and every `tests/dumps/` golden are untouched.
- **Zipped in order, not matched by name.** A missing annotation then shifts
  every one after it and the count check fires; matching by name would silently
  check a subset and call it a pass. `-` is padding with no C member.
- **`@cplatform` skips rather than fails.** A declaration nobody can check here
  is the thing being made visible, and failing would make the honest answer
  indistinguishable from a defect.
- **And a library module may not make such a claim at all**, which is the
  decision the gate does not imply: it makes a declaration checkable on the
  machine you *build* on, and `lib/` must work on machines nobody here builds
  on. `tests/checks/foreign_layout_stat.pas` is the worked example of the other
  side — 18 fields, both glibc holes, and a gate fixture rather than a case
  because a case that ran would print a wrong number where the gate skips.

**The runtime has a POSIX half, and a catalogue that holds only functions**
(ADR-0186). Making `PasFS.Info` ask the runtime met a constraint that had been
there since ADR-0161 and had never been met: the catalogue is proved complete by
stripping the non-ISO includes and requiring what is left to compile, which
works for an undeclared *function* — a diagnostic that can be silenced — and
cannot work for a *type*, an incomplete `struct stat` being an error no flag
silences. All four earlier dependencies happened to be functions.

- `runtime/pasrt.c` keeps its five names and its check unchanged; the split
  cost that claim nothing.
- `runtime/pasrt_posix.c` is bounded by its **headers**, which is the
  granularity a port cares about — `<sys/stat.h>` rather than whichever members
  are read today — and both directions are checked.
- **Everything in it is `pasx_`**, enforced, so a system without those headers
  loses library routines and not the language: `pascalc` still builds, still
  compiles itself, and every conforming program still runs. That is what makes
  the split safe rather than tidy.
  `tests/checks/runtime_isoc.sh` fails on `#include <dirent.h>` there, and on a
  `pas_` name defined in that file.

**A foreign answer of a record is a copy** (ADR-0187, AP 6.7.7.8). The last row
under the roadmap's "What blocks the library": a routine that *answers* a
struct. `readdir`, `gmtime` and `localtime` each hand back the address of
storage they own and reuse, and each hand back a null that is an ordinary
outcome. ADR-0123 had already lifted ADR-0122's refusal as far as a string with
a **capacity**, the size being the whole of the condition — and after ADR-0184 a
record has one. So the result type may be an optional of a record 6.7.7.6.2
admits, and the value is copied where the call occurs.

- **The copy is the feature, not the plumbing.** A view onto the callee's
  storage would be a value of this language whose contents change when the
  program does something unrelated, and would hand ADR-0109's aliasing question
  to every program that lists a directory. The address is read once and is dead
  by the end of the statement, which is why widening 6.7.7.8 leaves 6.7.7.9 c)
  where it was. `foreign_optional_record.pas` calls the probe twice and reads
  the *first* value back: an aliasing view answers 2000, a copy answers 1000.
- **The conditions are 6.7.7.6.2's, and `BadForeignField` was not touched** —
  the same fields for the same reason, since what is copied is storage a C
  compiler laid out.
- **The length is the record's**, there being nothing the far side could
  report. A record declaring a *prefix* reads the prefix, which is how
  `struct tm` is usable without naming the `char *` glibc puts after the nine
  that matter; a record larger than the struct is 6.7.7.9 c)'s kind of
  requirement on the program. `foreign-layout` deliberately cannot check a
  prefix — it compares against the whole struct — so the case's `Tm` carries no
  annotation and what checks it is the calendar.
- **`pas_rec_take` is `pas_cstr_take`'s mirror** and holds the same
  non-opinion: a guarded `memcpy` that answers whether there was a value, with
  the flag stored by CodeGen because the layout of an optional is CodeGen's.
- **A record result by value gains a diagnostic naming `?` as the remedy.** It
  was reaching "only 'integer', 'int64' and 'real' cross the boundary", which is
  true and unhelpful — what the program got wrong is the direction. The chain a
  reader now follows is `: R` → write `?` → `: ?R` → and if a field cannot
  cross, the field is named.
- **What it does not reach** is a member that is a `char *`, so `struct passwd`
  and `struct addrinfo` are still only declarable as prefixes, and for the
  second that is not the useful part. A chained list of structs holding
  pointers is what ADR-0109 exists for.

**A library may not declare the struct the program may** (ADR-0188). The module
ADR-0187 was written to unblock does not use it. ADR-0185's fifth decision is
categorical — a struct claim is checkable only where you build, and `lib/` runs
where nobody here builds — and `struct dirent` is that case at its worst: glibc
puts an `unsigned short` and an `unsigned char` before `d_name`, macOS a 64-bit
seek offset and two 16-bit fields, and POSIX requires only `d_ino` and `d_name`,
**in any order**. `struct tm` is the same, standardised by ISO C 7.27.1 and then
declared order-free by it. So the set of structs a library may declare is close
to empty, and ADR-0187 is a *program*-level feature.

- **`PasDir` binds `opendir` and `closedir` itself** — neither has a struct in
  its signature — and asks the runtime for one thing, `e->d_name`. The `DIR *`
  is a handle (ADR-0174), so the stream is closed by leaving the block, which
  is ADR-0174's own worked example arriving as a library.
- **No entry kind, and that is the decision.** `d_type` is not POSIX, is
  invisible under `_POSIX_C_SOURCE` — what `runtime-isoc` compiles the POSIX
  half with — and is `DT_UNKNOWN` where it exists on filesystems that do not
  carry it. A caller composes `PasFS.Info`.
- **The capacity travels in, so `doc/sop.md` §7's unmeasured-string row is
  closed for this module.** `pasx_dir_next` holds the pointer and can call
  `strlen`, so an over-long name is `errFull` and never ADR-0123's capacity
  trap; `Next` takes `var name: string` and passes `name.capacity`, so the
  bound checked is the caller's own. The first version fixed it at 255, under
  which no filesystem in existence could have reached the branch — a branch
  that cannot fire is a branch nobody has checked. `PasEnv` could have the same
  fix and does not.
- **`Next` gives every entry; `List` skips `.` and `..`** — the iterator hides
  nothing, and the convenience makes an empty vector mean an empty directory.
- **Four outcomes and no new type**: `errNone`, `errAbsent` at the end (that
  code's own gloss, *nothing was there to return*), `errFull`, `errIO`.

**The text model's runtime half** (ADR-0189, ADR-0190, AP 6.4.15). `char`
cannot widen — `set of char` would stop compiling under ADR-0028's 256-value
cap, which breaks ADR-0117's containment — so text is a type *beside*
§6.4.3.3's strings and not a change to the character type. What was decided:
`utf8(n)`, a value with a capacity in **bytes**, holding well-formed UTF-8 in
Normalization Form C, whose elements are extended grapheme clusters. Only the
runtime exists so far.

- **Normalising on construction rather than on comparison is the load-bearing
  choice.** Both operands being NFC makes `=` byte equality *and* canonical
  equivalence at once, so `'é'` typed either way is one value, a text can be a
  `pasmap` key, and nothing is decoded at a comparison. The cost is that a text
  does not round-trip; `string(n)` is what a program holds when it means the
  octets, and it round-trips exactly.
- **`runtime/pasrt_unicode.c` is four functions**: `pas_text_validate`,
  `pas_text_nfc`, `pas_text_next` and `pas_text_count`. Strict ISO C11 with no
  catalogued name at all, which `runtime-isoc`'s fourth pass holds it to — a
  stronger claim than either other translation unit carries.
- **A starter is not always the beginning of a normalisation segment**, and
  this is the trap. Fifty-nine primary composites have a *starter* as their
  second element — 33 vowel signs over sixteen Indic and Southeast Asian
  scripts, where U+09C7 + U+09BE composes although both are of class zero —
  and Hangul's L + V and LV + T are the same case. A streaming normaliser that
  flushes at every class-zero character silently drops exactly those and passes
  everything else. `combines_back()` is the guard, and the set is derived from
  the composition table rather than written by hand.
- **The oracle is Unicode's own**, which is the whole reason this increment
  came first: `NormalizationTest.txt` and `GraphemeBreakTest.txt` state an
  input and the answer, and were written by people with no interest in this
  compiler. `unicode-conformance` is the gate — 20 034 normalisation cases, 766
  segmentation cases, and every code point the first does not list required to
  be its own NFC. It is the second oracle here nobody wrote, after the BSI
  suite (ADR-0086).
- **The tables are committed and the database is not**, which is `seed/`'s
  shape rather than `tests/bsi/`'s reason — Unicode does permit redistribution,
  so this is size and provenance. The gate therefore asks a second question the
  test files cannot: regenerating from the database must reproduce the
  committed header, or the two drift and every case still passes.
- **The compiler cannot call any of it.** `selfhost/compiler.std` is
  `extended`, so `external` is refused there — which makes AP 6.4.15.5's
  "converted … before the program is executed" the open question increment 2
  has to answer. ADR-0190 registers the four ways out and takes none.

**The text-type itself** (ADR-0191, AP 6.4.15). `utf8(n)` is a type
`--std=afterschool` has: a value with a capacity in bytes, holding well-formed
UTF-8 in normal form C, whose elements are extended grapheme clusters. It is a
required *schema* identifier with the discriminant `capacity`, so it reads and
interns exactly as `string(n)` does and §6.1.3 lets any program shadow it.

- **A new kind, `tyText`, and `IsStringRep` for what it shares.** The
  representation is a variable-string's — a length and that many bytes — so
  every frame slot, copy, parameter form and layout rule came free through one
  new predicate at six sites. The *rules* are not shared, and that is why it is
  a kind rather than a flag on `tyString`: indexing, substrings, `index`,
  `substr` and §6.8.3.5's padded comparison are each about a `char`, and a
  text has none. A flag would have granted all five and required five
  refusals to be remembered, which is ADR-0146 arranged on purpose.
- **Adding the kind granted comparison anyway, and it emitted invalid IR.**
  `IsMemory` asked `IsVarString`, so a text was not memory, so the relational
  operators took it for a simple type and wrote `icmp` on an aggregate —
  ADR-0139's defect reproduced by adding a type. `kind-exhaustive` could not
  see it: a predicate is not a case-statement. `doc/sop.md` §7 carries it.
- **The assignment rule changed when the type was implemented.** A text takes
  its value from any string-type or char and ill-formed input is an **error**,
  not a refusal — §6.4.6's own model for a constrained type, and ISO 7185's
  for a subrange since 1982 (ADR-0018). The clause said the opposite until
  writing the tests showed that a text could then be filled from a literal and
  from nothing else. AP Annex E.11, and the first divergence there found by
  implementing a clause rather than by auditing one.
- **Comparison refuses a string where assignment admits one**, and the
  asymmetry is the point: an assignment normalises, so what the text holds
  afterwards is right; a comparison against unnormalised bytes would give a
  *wrong answer* rather than an error. A character-string operand is
  normalised into the arena first; a string operand is named by Sema.
- **`length` counts elements and `capacity` counts bytes.** Different units
  for one value, so `length(t) <= t.capacity` is true and not tight, and
  `length` is the only required string function a text gets.
- **`tests/dialect/text.pas` is the readable statement**: seven source bytes
  of decomposed `é` and six of composed are one value of five elements; three
  Hangul jamo compose to one syllable; a ZWJ family emoji is one element of
  eighteen bytes. None of those numbers was chosen here.

**Joining and walking a text** (ADR-0192, AP 6.4.15.7 and 6.4.15.9). The two
are inverses and that is how they are tested.

- **`+` cannot return a length the compiler computes.** §6.8.3.6 makes a string
  concatenation's length the sum of the two, so `pas_str_concat` returns bytes
  and the emitter adds. Normal form is not preserved by joining — a base
  character at the end of the left operand and a combining mark at the start of
  the right compose across the join — so the result is *shorter* than the sum.
  `pas_text_concat` therefore returns a text **value** in the arena, a length
  word and the bytes, which is the shape a text variable already has and which
  the emitter reads with the same two getelementptrs.
- **One pass suffices** because composition removes code points and never adds
  any, so `la + lb` bounds the result.
- **The result is a text with no capacity**, as `canonStringType` is a
  variable-string with none: it must fit any target, and 6.4.15.5's store is
  where the fit is checked. Everything downstream asks `IsText` and needed
  nothing.
- **Iteration does not normalise, and must not.** `pas_text_take` copies the
  element and checks the fit; `pas_text_store` would take arena scratch, and
  the arena is released once per *statement* (ADR-0111), so a loop over a long
  text would exhaust it. Sound because a grapheme cluster boundary is also a
  boundary of normal form: everything that composes backwards is `Extend` or
  `SpacingMark`, and GB9 and GB9a make neither a boundary.
- **That argument is a reading, so it is a property test.**
  `tests/dialect/text_join.pas` walks a text, joins the elements back and
  requires the original. It is the one place in the text model whose
  correctness does not rest on Unicode's own conformance files.
- **The operand is evaluated once and outlives the loop**, which matters
  because `for g in a + b` walks arena storage: the pair is SSA values defined
  before the loop, and the body releases nothing.
- **A text iteration is told from a set's by the operand's type** (ADR-0140),
  so `for v in s` over a set is untouched. It cost one reordering: the
  iteration-clause is now typed *before* the control variable is judged, since
  §6.9.3.9.1's "shall possess an ordinal-type" has to know whether this is the
  text form.
- **`pas_text_boundary` is an `int` wrapper** over `pasrt_unicode.c`'s
  `long long` `pas_text_next`. Every `pas_text_*` entry point is: the emitted
  code speaks i32, and passing an i32 where a `long long` is declared is an ABI
  mismatch the IR verifier does not catch.

**`PasUnicode`, and what a library may do that the language may not**
(ADR-0193). AP 6.4.15.5 makes ill-formed bytes an *error* that stops the
program, which is right for a program's own literals and wrong for bytes off a
socket. `ToText(s, var t): ErrorCode` is the door for the second: `errSyntax`
for bytes that are not UTF-8, `errFull` for a value whose normal form will not
fit, and nothing assigned unless it succeeds.

- **It is a binding, not an implementation** — `lib/dialect/README.md`'s term.
  Both `ToText` and `NextScalar` go to `pasx_` runtime routines, because a
  UTF-8 decoder in Pascal would be a second reading of The Unicode Standard's
  table 3-7, and that table needs care for exactly the reason a second reading
  would get it wrong: an overlong encoding, a surrogate and a code point above
  the range each have a lead byte that looks ordinary.
- **Encoding *is* written in Pascal**, and the asymmetry is the decision:
  encoding is unambiguous arithmetic with one rejection, and table 3-7 is a
  table about decoding. A duplicate reading is refused where it could be wrong
  and allowed where it cannot.
- **The scalar view is over `string` and not over `utf8`.** A program that
  wants bytes holds a string (AP 6.4.15.8 NOTE), and a text crosses no foreign
  boundary — so `ToText` is the bridge and everything below it is bytes.
- **The fit cannot be computed from the byte counts.** Normal form can be
  longer than its source, so `pasx_text_check` normalises to answer, and it
  answers the two failures separately because a caller can act on which.
- **A third guard of the same shape turned up here**, and that is the entry
  worth remembering: `EmitAssign` selects the string store with
  `IsStringType`, so a text target fell through to the schema
  tuple-comparison, which compared a *string's* capacity against a text's and
  stopped the program. With `IsMemory` (ADR-0191) and the codegen comparison
  dispatch that is three in three increments, none of them a case-statement
  and so none of them visible to `kind-exhaustive`. All three were found by
  writing a client rather than by a gate.

**Case folding and case mapping** (ADR-0196). The last of ADR-0189's list bar
one, and the place the text model's oracle story ends.

- **Folding is not lowercasing**, and `Fold` exists so a program need not know
  that. `Fold(a) = Fold(b)` is the caseless comparison; comparing two
  lowercased values answers it wrongly, because the German sharp s lowercases
  to itself and folds to `ss`. Unicode publishes the mapping for that purpose.
- **All three are full mappings** — `CaseFolding.txt` statuses C and F for the
  fold, `UnicodeData.txt`'s simple mappings with `SpecialCasing.txt`'s
  unconditional entries over them for the other two — so one code point may
  become three and the caller's capacity goes in. `errFull` and `errSyntax`
  stay separate for ADR-0193's reason.
- **Every conditional mapping is declined**: a conditional entry names a
  language or a context, and this language reads no environment variable and
  knows where no word ends. `Lower('ΣΟΦΟΣ')` is therefore `σοφοσ`, with a
  final σ rather than ς, and `tests/dialect/lib_unicode.pas` prints that on the
  line that says so — a reader should meet the limitation in the test rather
  than in a program.
- **The result is bytes and not a text**, because case mapping does not
  preserve normal form. A caller putting it into a `utf8(n)` renormalises
  there, which AP 6.4.15.5's assignment does anyway, so the composition is
  correct by construction.
- **There is no conformance file for casing**, and that is the honest limit:
  normalisation and segmentation are settled by a document written elsewhere
  and these three are settled by a transcription. `doc/sop.md` §7 carries it,
  and nothing will close it.

**Reaching an element by number, and why there is no way to** (ADR-0199). The
last of ADR-0193's three, and the answer to *spell it so the cost is visible*
turned out to be **not to offer the index**. `ElementEnd(s, at)` answers the
byte where the element beginning at `at` ends — or 0 at the end and on
ill-formed bytes — and the element is `substr(s, at, ElementEnd(s, at) - at)`,
taken by the caller.

- **The walk is in the program**, so an O(n) access is n lines of loop rather
  than one call spelled like a subscript. A slice of elements 2 to 4 is a nine-
  line procedure, and `tests/dialect/lib_unicode.pas` contains it rather than
  the module.
- **Answering an offset removes the third answer.** Returning the bytes would
  need a destination and therefore a failure for an element that does not fit;
  the caller's own `substr` is where that error belongs, and it is the error
  AP 6.4.15.9 already gives a control-variable too small for an element.
- **A slice cut at element boundaries is already in normal form**, so `ToText`
  back cannot fail for want of it — ADR-0192's property used rather than
  restated.
- **The element is validated and the string is not.** `pas_text_next` advances
  one byte over a byte it cannot decode so an iteration still terminates; these
  are bytes the caller did not write, so the wrapper checks the element it
  names — over the element, because validating from the start on every call
  makes an n-element walk quadratic.
- **What it is for** is the three shapes `for g in t` cannot take: two texts in
  lockstep, a walk that stops and resumes, and a range out of the middle. Not
  convenience — an `ElementAt` would have been that, and is refused.
