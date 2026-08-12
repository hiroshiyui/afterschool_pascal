# 70. A file need not be an entire variable

Date: 2026-08-13

## Status

Accepted.

## Context

ISO 7185 §6.5.1's own declaration example is

```pascal
pooltape : array [1..4] of FileOfInteger;
```

and §6.5.5's own buffer-variable example is `pooltape[2]^`. Both compilers
accepted that program, emitted no diagnostic, and **segfaulted**.

`initFiles` walked a block's frame variables and selected the ones whose *own*
type was a file:

```cpp
if (!v->type || !v->type->isFile() || v->kind == SymKind::VarParam)
  continue;
```

A file inside an array or a record therefore kept a zeroed `struct pas_file` —
`compsize` 0, no buffer allocated, not on the runtime's list of open files — so
the first `pooltape[2]^` dereferenced a null buffer pointer. `closeFiles` had
the same shape, so such a file was never flushed or closed either. It happened
in both standards, at every optimisation level, and identically in both
compilers, which is why `difftest` agreed.

Nothing in the 393-file corpus had ever declared one. Every file that mentioned
an array of files was a *negative* test checking that a file's component may not
contain a file. This was found by a systematic sweep of Annex A's 274
productions against compiled probes — the same shape as the three gaps before
it, and the fourth time an oracle set agreed about a construct no program in it
contained.

## Decision

**The walk belongs to the declaration, not to the use.** A block's prologue
walks each variable's type and prepares every file it holds; the epilogue
closes them the same way. The alternative — preparing a file where it is first
named — was rejected because `pas_file_init` resets the whole record, so
calling it at `reset(f)` would drop an already-open `FILE *` and the bound name
a program had chosen with `bind`.

- **A record recurses over its fields; an array emits a loop.** Not an unrolled
  run: an array's length may be a discriminant's (ADR-0040), and `array
  [1..10000] of text` is a legal declaration whose unrolled prologue would be
  ten thousand calls. The counter is an `alloca` in the entry block, which is
  where the prologue already is.
- **`holdsFile` selects the variables worth walking**, and it is deliberately
  *not* Sema's `containsFile`: that one looks into variant parts, and this one
  must not, because after the refusal below there are no files there to find.
- **`new` prepares them and `dispose` closes them**, because §6.4.4 does not
  stop a domain-type from containing a file and a created variable's storage
  has the same obligation a declared one's has. That case segfaulted too.

**A file may not be a field of a variant part.** This is a deviation: §6.4.3.4
permits it and this compiler refuses it. The reason is that a file's storage is
not just bytes. `pas_file_init` gives it a heap buffer sized by the component
type *and* links it into the runtime's list of open files — the list a
non-local `goto` reads to close what it abandons (ADR-0032). Two arms holding
files at one address would need two buffers there, so the second setup leaks the
first, and it would link one list node twice, which corrupts the list outright.

The alternatives were each worse. Initialising only the first arm silently
prepares the wrong file for every other. Making `pas_file_init` idempotent
per address makes "which arm's file is this" depend on declaration order.
Leaving them uninitialised is the bug this record fixes. Refusing states the
rule in one diagnostic that says why, and it is the only shape where the
question has no answer at block entry.

## Consequences

**`tests/file_errors.pas` gained a diagnostic.** That file declares a record
with a `text` in a variant arm, deliberately, to check that a file's component
may not contain a file *through a variant* — and the declaration is now refused
in its own right. The record still exercises the original rule, because the
field is still added after the diagnostic, so `file of` it is still refused for
the reason it always was.

**Sema's `containsFile` keeps its variant walk.** It is not dead: a record with
a file in a variant is still *built*, so `containsFile` still answers `true`
about it — every such answer is now preceded by another diagnostic, which is
one mistake reported twice but never a mistake missed.

**`verify/` gained nothing.** There is no arithmetic here: the loop counts from
zero to a length the array already knows how to compute, and the ends are the
array's own bounds, which ADR-0017's rule already covers.

### What this does not do

**A file component is not a program parameter.** §6.10 binds program parameters
by name to entire variables, so a file reached through a subscript or a field is
always an internal one — a scratch file with no external name. The walk passes
`PAS_BIND_INTERNAL` for every file below the top level, and that is a
consequence of the standard rather than a choice.

**A file in a variant part is refused rather than deferred.** If it is ever
wanted, what has to change is the runtime: the buffer and the open-file link
would have to belong to the *variable* rather than to the storage, which is a
larger change than the feature is worth today.
