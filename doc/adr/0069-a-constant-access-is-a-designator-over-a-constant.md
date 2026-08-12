# 69. A constant-access is a designator over a constant

Date: 2026-08-13

## Status

Accepted.

## Context

ISO/IEC 10206:1991 §6.8.8 is the last production of the standard this compiler
had not implemented. It adds three ways to select from a constant:

```
constant-access = constant-access-component | constant-name .
constant-access-component = indexed-constant | field-designated-constant
                          | substring-constant .
```

§6.8.8.1's NOTE is the clause's whole point, and it is easy to miss:

> Neither a constant-access nor a constant-access-component is necessarily a
> constant. … given `const c = t[1:1; 2:2; 3:3]` … the constant-access `c[i]`
> denotes a different value for each iteration of the loop.

So a constant-access is a **run-time read of compile-time-fixed storage** —
except where the index is itself constant, and then it is a constant, because
§6.3.2's own examples include `column1 = BlankCard[1]` and `hex_digits =
hex_string[1..10]`. Both readings are required and neither subsumes the other.

There was also nothing to access. ADR-0061 deferred structured constants, so
`const c = t[1: 1; 2: 2; 3: 3]` was refused: a `Symbol` had four scalar fields
and no room for an array. ADR-0068 gave it room — a constant *is* its defining
expression, named — which is half the obstacle removed before this record
starts.

## Decision

**A constant-access is a designator over a constant.** §6.5.1's
variable-accesses and §6.8.8's constant-accesses have the same three selector
forms and differ only in what stands at the bottom of them, so the whole
feature is that observation applied twice:

- **CodeGen needed nothing.** `c[i]`, `o.x` and `s[1..3]` are the `IndexExpr`,
  `FieldExpr` and `SubstringExpr` spine the parser already built, and once the
  constant has an address `emitAddress` walks it exactly as it walks a
  variable's. The bounds check, the field offset and the substring check are
  the ones that were already there.
- **`verify/` gained nothing**, and that is a statement about the clause rather
  than about the effort: §6.8.8's four error conditions D.88 to D.91 *are* the
  array, string and substring bounds already proved for every input. §6.8.8
  adds no arithmetic and no new check.
- **`isConstantAccess` is `isDesignator` written for the other root.** It is
  structural — it asks what the root denotes, never what the value is — which
  is what lets it be asked as a question in a context that must not diagnose or
  fold.

**A structured constant is a global filled by a prologue, not an LLVM
initializer.** The alternative was to fold the value into an aggregate constant
and emit `@c = constant %t { i32 1, i32 2 }`. That would need record padding,
variant arms and 256-bit sets printed as literal text in *both* backends, and
ADR-0025's Pascal emitter has `LlSize`/`LlAlign` and no struct-literal printer.
Filling a zero-initialised global with ADR-0061's existing store-based emitter
reuses everything and adds no representation at all.

- The block that **defined** the constant fills it, in the prologue, before
  every other initialisation — a constant-expression is nonvarying (§6.8.2), so
  it cannot read anything the rest of the prologue writes, and §6.6's initial
  state may name a constant, so it must come first.
- The order within a block is definition order, which is a legal order for
  ADR-0053's reason: a component-value naming another constant names an earlier
  one, because §6.2.2.9 makes a defining-point precede its applied occurrences.
- The global is keyed by the **node**, so `const b = a` shares `a`'s storage
  rather than copying it. Two names for one value, and the folder hands on one
  node.

**A set constant has no storage and needs none.** A set is a value (ADR-0028),
so `emitConst` emits the constructor where the name is written. It reads
nothing, so there is no order to get wrong — which is why the set case is the
one that needs neither a global nor a prologue.

**Folding is a walk into the same node.** `constAccessNode` selects the
component-value the access denotes and hands back *another node*, which the
ordinary folder then evaluates. Nothing is computed twice and no value
representation was added: an array-value's element and a record-value's
field-value are nodes the program wrote.

- §6.8.2 guarantees the indices are constant in that position — a variable
  index is a variable-access, which a constant-expression may not contain — so
  the two readings of `c[i]` never collide and no rule decides between them.
- **§6.8.8.3's inactive-variant error is answered at compile time.** D.90 is
  normally a run-time property, and ADR-0027 does not enforce it for heap
  variables; but a *constant's* tag is a constant, so the walk down
  `Field::variant` either reaches the arm the value selected or reports that it
  did not. It is the one error condition this clause lets a compiler settle.
- **Only the two string forms compute rather than select.** The characters of a
  string constant are the value, so `hex[1]` yields a char made here and
  `hex[1..10]` yields a literal made here — the one place this compiler builds
  a piece of tree the program did not write. Sema owns it, beside the symbols
  it owns; the Pascal compiler narrows the run of string pool the source
  literal already interned instead of interning new characters, which is sound
  only because what the pool holds is the *value*: §6.1.7's doubled apostrophe
  is one character there, not two.
- **That node is invisible to `difftest`**, and it is the first thing here that
  is. The synthesised literal is not in the tree the dumps walk, so the two
  compilers can disagree about its characters and every dump still match —
  `irtest` is the only oracle that sees it, because it runs what the Pascal
  compiler builds. An off-by-one in the pool offset was checked against both:
  `difftest` passed and `irtest` failed three programs. ADR-0052 met the same
  asymmetry from the other side, where two backends agreed on every dump and
  disagreed about a number no dump printed.

**§6.9.3.10's with-element may be a constant-access, and its fields stop being
designators.** The binding is a hidden slot holding an address either way, so
what changes is what the names it introduces *are*: §6.9.3.10 calls them
constant-field-identifiers, and they denote values. `isDesignator` therefore
asks the binding rather than its kind — the kind is `VarParam` for both — and
`with o do x := 1` is refused by the message an assignment to any non-variable
gets. Borrowing ADR-0046's protection machinery was tried first and rejected:
it would have said "protected", which is a different rule and the wrong noun.

### The declaration parts had to start being read in order

This is the prerequisite the feature ran into, and it is a conformance fix in
its own right. §6.2.1 makes an Extended Pascal block a **repetition** of the
five declaration parts, in any order:

> block = import-part { label-declaration-part | constant-definition-part |
> type-definition-part | variable-declaration-part |
> procedure-and-function-declaration-part } statement-part .

ISO 7185 §6.2.1 fixes the order instead — const, then type, then var — and Sema
had been imposing that on both standards by checking every constant, then every
type, then every variable. §6.2.2.9 then requires a defining-point to precede
each applied occurrence, so **written order is the only order that can be
right**.

It matters beyond this feature: `const first = red` after the type part that
declares `red` was refused, and that is an ordinary Extended Pascal program with
no structured constant in it. It matters *to* this feature because every
structured constant names a type.

- The parts are **merged by source position** rather than recorded in one list
  at parse time. The AST keeps a vector per part and the positions reconstruct
  the interleaving exactly, since one block's declarations are all distinct.
  Under ISO 7185 there is at most one of each part in the fixed order, so the
  merge is provably the order this always used.
- §6.4.4's forward-referenced pointer domain is completed at the end of **its**
  type-definition-part, so a *run* of type definitions ending is what triggers
  it — not the end of the block, which may now hold several.
- It **tightens** as well as loosens: `var v: t;` before `type t = integer` used
  to compile and is now the forward reference §6.2.2.9 says it is. The pointer
  domain is still the one exception, and `declorder_errors.pas` shows both.

## Consequences

**ISO/IEC 10206:1991 has one item left**, §6.13's separate compilation of
program-components, which the standard asks for with a *should* and which
ADR-0053 refuses with its reason stated.

**ADR-0061's deferral list is now empty.** That record deferred the set-value,
constant-accesses and a value of a dynamically bounded type. ADR-0066 took the
first, this takes the second, and the third remains refused — a dynamically
bounded type has no compile-time extent, so "every component is specified" is
not a question that can be asked.

**A structured constant is not a variable and no rule was added to say so.**
Assignment, an actual var parameter, a `read` target and a `with`'s
field-identifiers are each refused by a test that already existed, because
`isDesignator` asks the base and the base is a constant.
`constaccess_errors.pas` is ten diagnostics and only three *kinds* of them come
from code written for this feature — an index outside the array, a substring
outside the string, and the inactive variant.

### What this does not do

**A constant-expression is still not folded through an operator on a
structured value.** `const t = c` and `const m = c[2]` fold; `const u =
c + d` does not exist, because §6.8.3 gives arrays and records no operators —
but the same holds for the *set* operators, which do exist: `const s = odds +
evens` is refused, as ADR-0054 refused it, because folding it means computing a
256-bit value in a compiler that has two implementations to keep agreeing.

**The storage is not `constant` in the IR.** A global filled by stores is
mutable as far as LLVM is concerned, so nothing propagates through it. That is
the price of not printing aggregate initializers in two backends, and it buys
correctness in the one that cannot spell them.

**A constant defined in a nested block is filled whenever that block is
entered**, not once at program start. The value is the same every time — it is
nonvarying — so this is redundant work rather than a wrong answer, and it is
what lets the feature reuse the prologue every block already has instead of
adding a fourth whole-program answer beside `activeModules()` and `std()`.
