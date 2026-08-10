# 25. The code generator is checked by running it, and the bootstrap closes

Date: 2026-08-10

## Status

Accepted

## Context

The last component of the stage-1 compiler, and the one ADR-0006 was written
for: a compiler written in Pascal cannot call LLVM's C++ API, so the backend
that survives the rewrite is the assembler text, not the builder.

Two questions had to be answered before any of it could be written, and neither
had the answer the three previous ports had.

The first is **what to compare**. The lexer, the parser and Sema were each
checked by diffing a dump that both compilers write. CodeGen cannot be: the C++
side builds an `llvm::Module` and the Pascal side prints text, and LLVM's own
printer is not a specification. It renumbers values, it reorders attributes and
it changes between releases. Requiring the Pascal side to reproduce it byte for
byte would be porting LLVM's `AsmWriter`, not porting `codegen.cpp`.

The second is **the real literal**, deferred by three records now. ADR-0024 said
CodeGen is where it stops being deferrable, "because a value must be emitted".

## Decision

**The oracle is the program's behaviour, not the text of its IR.** Compile each
case in `tests/` with the Pascal compiler, assemble and link what it wrote, run
it, and compare against the *same* `tests/*.out` and `tests/*.err` the C++
compiler is held to under ADR-0011. Two compilers, one expected answer. That is
still the same question asked twice; it is asked of the answer rather than of
the spelling.

**And then the bootstrap closes.** `selfhost/irtest.sh` runs the three stages
ADR-0004 named:

```
stage 1 = pascalc(compiler.pas)     built by C++
stage 2 = stage1(compiler.pas)      built by a compiler C++ built
stage 3 = stage2(compiler.pas)      built by a compiler Pascal built
```

and requires stage 2 to equal stage 3. They are compared as IR rather than as
binaries, because IR is what the Pascal compiler emits — the same fixed point
one step earlier, and readable when it fails. A compiler that reproduced itself
and nothing else would pass that comparison alone, so stage 2 is put through the
golden suite as well.

**A real literal reaches the IR as the text it was written with.** This is not
a fourth deferral: it is what a textual backend wanted all along. LLVM's
assembler is the `strtod`, and it is the same correctly-rounded conversion the
C++ compiler gets from its own. The only adjustment is that LLVM's float syntax
needs a decimal point where Pascal's `1e6` has none. A real *constant* now
carries its source text and a sign rather than a value, and `EvalConst` folds a
negation by flipping the sign.

Three consequences of writing text rather than building a module, all of which
made the port smaller than the C++ it came from:

- **The emitter is sequential**, with no instruction list at all. It works
  because the C++ builder never returns to a block it has left: every
  `SetInsertPoint` moves to a block that is then filled to its terminator. The
  order the C++ emits in is the order text can be printed in.
- **Types are printed structurally, inline.** A Pascal type can contain itself
  only through a pointer, and opaque pointers make every pointer `ptr`, so
  nothing is recursive and no named type is needed. Activation records are the
  exception — one is spelled at every variable access — so those get a name
  apiece, emitted before the first function that indexes one.
- **Globals are deferred.** A global cannot be written inside a function, so
  every string constant is numbered where it is used and its text written after
  the last function. LLVM resolves the forward reference.

**The IR is a program parameter, not a mode.** ADR-0024 has the Pascal compiler
dumping every stage in one pass because there is no second binary to select a
mode on, and that stands: the IR is the compiler's *product* rather than a
dump, so it goes to a file of its own — `compiler.pas source ircode`. It is
written on every run, which is what keeps `difftest.sh` exercising the code
generator on all 175 files even though it compares none of it.

## Consequences

The port is finished. The compiler compiles itself, and **stage 2 and stage 3
are identical**: 56 121 lines of IR, byte for byte. Stage 2 agrees with the C++
compiler on all 175 files, stage for stage, and both stages pass the golden
suite.

**Stage 0 needed no change at all** — the first port of the four that did not.
Everything this component asks of the C++ compiler was already there, which is
what ADR-0006 and ADR-0008 were for.

**The Pascal side needed one refactor: a character sink.** A trap message is a
string constant *in the generated program*, so unlike a diagnostic it cannot be
written as it is computed — it has to be assembled first. `WriteTypeName` and
`WriteOrdinalName` are wanted in both places, so they now write through a `Put`
that either goes out or goes into a buffer. A second copy of them would have
been a copy free to drift, which is the mistake ADR-0024 exists to stop making;
the differential test over `badsema/` is what proved the refactor changed no
diagnostic.

**The layout rules had to be written out.** The C++ asks LLVM's `DataLayout`;
there is nobody to ask from Pascal. They are needed in only two places — the
length of a whole-variable copy and the size `new` allocates — because a
`getelementptr` names the type it indexes and LLVM does the arithmetic. The
size of a file variable is the one number that cannot be derived, so
`irtest.sh` checks that `fileSize` still equals `PAS_FILE_SIZE`; the C++ side
gets the same guarantee from `#include`, and neither side can drift silently.

**What the proofs now do and do not cover.** `verify/lowering.py` models
`codegen.cpp`, and the roadmap asked for a decision before the port reached
here. The decision is that **the theorems stay attached to the C++ model**, and
the Pascal generator is tied to it by behaviour rather than by a second model:
the golden files carry the trap messages and the traps themselves, so a lowering
that stopped checking, or checked at the wrong bound, fails `irtest.sh`. What
this does *not* give is a proof about the Pascal generator for every input —
`tests/trap_*.pas` exercise a sample where `verify/` quantifies. Writing a
second model would have doubled the thing ADR-0013 warns is dangerous when it
drifts, and would still have modelled a program rather than proved one. When
stage 0 is retired the model has to be re-pointed at the Pascal source, and that
is the moment to reconsider; until then the C++ generator is still the one being
proved, and it is still the one that builds stage 1.

**The corpus was measured, not assumed** — the fourth time, and the fourth time
it was short. Twelve mutations were applied to the Pascal code generator: the
alignment of a variant's shared storage, a record's trailing padding, an
off-by-one array bound, `succ` at the end of a subrange rather than of its host,
a `downto` that steps upward, an ordinal compared signed, a `var` parameter left
undereferenced, a structured value parameter shared instead of copied, an
unwidened `char` subscript, a real constant that loses its sign, a
whole-variable copy of the wrong length, and a standard file bound as a scratch
file.

**Five escaped**, and each named something the suite had no program for: no
record's size depended on its padding, nothing compared a `char` across 127, no
`succ` ran out at a subrange's own bound, and no constant was a negative real.
`tests/codegen_edges.pas` and `tests/trap_succ_subrange.pas` close all five, and
they are ordinary golden tests — **the C++ compiler is held to the same output**,
so neither compiler can drift from them alone. Twelve of twelve are caught now.

Two of the five are worth keeping in mind, because both were nearly *invisible*
rather than merely uncovered:

- The variant-alignment mutation first escaped a record that already had two
  words of fixed part, which aligned the storage by accident. It only shows in a
  record whose fixed part does *not* already round out — which is why the test's
  record has no fixed part at all, and says so.
- The `downto` mutation did not produce a wrong answer; it produced a program
  that ran 2³¹ times before wrapping out of the loop. `irtest.sh` had no bound
  on how long a *test program* may run, only on the compiler, so the whole run
  hung instead of going red. Bounding it is the fix, and the same reasoning
  `difftest.sh` already had for a scanner that consumes no character.

**The generated programs are not sanitised, and cannot be here.** ASan and UBSan
instrument during IR *generation* from C or C++, driven by function attributes
this backend does not emit, and Debian's LLVM 21 ships no `libclang_rt.asan.a`
to link against in any case. So a memory-safety bug in the generated code shows
up only if it changes an answer — which is why the variant-alignment case above
was closed with a record whose *size* depends on the alignment, rather than left
to a sanitiser that would have caught it directly. Worth revisiting if the
runtime library ever appears.

**Two things are deliberately not done.** There is no `-O` on this path: the
Pascal compiler prints IR and `clang` is what optimises and links it, which is
ADR-0009's arrangement one step further out. And the emitted module names no
target triple, so `clang` supplies the host's — the layout rules written above
are x86-64's, and a different target would need them changed rather than
guessed.
