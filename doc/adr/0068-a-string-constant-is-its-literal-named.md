# 68. A string constant is its literal, named

Date: 2026-08-13

## Status

Accepted.

## Context

ISO 7185 §6.3 writes a constant-definition's right-hand side as

```
constant = [ sign ] ( unsigned-number | constant-identifier )
         | character-string .
```

A `character-string` is a constant, and §6.4.3.2 makes one of more than a
single character a value of a packed array of char. `const s = 'hello'` was
refused under **both** standards, with the message a non-constant expression
gets:

```
error: the value of constant 's' is not a compile-time constant
```

`const c = 'a'` worked, because the parser makes a one-character literal a
`CharLit` and a char has a field to be folded into. Two characters is where a
`Symbol`'s four scalar fields — `intVal`, `realVal`, `charVal`, `boolVal` —
run out.

This is the second gap of this kind found in as many days, and the shape is
identical to ADR-0067's: nothing in the corpus had ever written one. 388 files,
many with constant-definition-parts, and **not one string constant** — so every
oracle agreed, and ADR-0067's own sentence about the oracles was still true of
the clause immediately before the one it was written for. It was found the same
way, by compiling a probe rather than reading prose.

## Decision

**A string constant is its literal, named.** `Symbol` gains `constValue`, an
`Expr *`, and the folder puts the `StrLit` node there instead of a value. Every
use of the constant then emits what the literal would have emitted: a private
constant global holding the characters, which is what `CreateGlobalString`
(and, in the Pascal compiler, `AddGlobal`) already produced for a literal
written in place.

That is not a shortcut but the smallest true statement of §6.3. A constant
*denotes a value*; the literal already denotes that value and already knows how
to be one, so naming it is the whole of the feature. Nothing had to learn what
a string constant is:

- **It takes the literal's type**, so the two standards need no case. ISO 7185
  types a literal as a packed array of char and ISO/IEC 10206:1991 as a
  fixed-string-type, which this compiler spells the same way (ADR-0051) — and
  either way the constant inherits it. There is no `--std` test anywhere in
  the feature, which is unusual enough to be worth saying.
- **A constant naming a constant carries the node along**, because the folder
  already copies the whole symbol for that case. `same = hello` is one literal
  written once.

**The shape is `Symbol::initValue`'s, not a new idea.** ADR-0048 already had a
symbol holding an AST node as its value — §6.6's initial state — read by
CodeGen's prologue and by nothing else. This is the second, and the two say the
same thing: when a value does not fit in a field, Sema keeps the tree and
CodeGen emits it where the value is wanted.

**`emitAddress` had a hole exactly where this lands.** Its `VarRef` arm went
straight to `addressOf`, which computes a frame slot — and a constant's
`frameIndex` is `-1`, which indexes field 0, the static link. That was
unreachable while every constant was scalar, because `emitExpr` short-circuited
to `emitConst` first. It is reachable now, so the `Const` test comes *before*
the `addressOf` in both backends, and the qualified form (§6.11.3's imported
constant) gets the same test in the `Field` arm.

**A constant is not a variable, and no rule was added to say so.** §6.5.1's
variable-accesses do not include a constant-identifier, and `isDesignator`
already answered false for one — so assignment, a `var` parameter, a `read`
target and a subscript-of-a-constant-as-an-lvalue are each refused through the
message they already had. `stringconst_errors.pas` is nine diagnostics and no
new code produced any of them.

**The one rule that did change is the opposite direction.** §6.6.3.2 makes an
actual value parameter an *expression*, so a string constant may be copied into
one. ADR-0061 had already loosened that test once — a structured-value
constructor "is not a variable but does have storage" — and this is the same
loosening for the same reason, so `isMemoryConstant` joins the literal and the
constructor as a third thing with storage and no variable behind it. It asks
about the *type*, not about strings, so it needs nothing when another kind of
memory-valued constant arrives.

**The dump prints `const expr`, not a number.** The Sema dump prints a
constant's value, which is how constant folding is compared between the two
compilers — and a string constant has no scalar field, so both were printing
whichever number `intVal` happened to hold. The C++ read a zeroed field and the
Pascal an uninitialised one, and `difftest` caught it as `const 0` against
`const 3`. A real constant already printed only its type, for ADR-0022's reason
about float formatting; this is the second value that cannot be printed as a
number, for an unrelated reason.

## Consequences

**ISO 7185 was not complete, again.** The `iso-7185-done` tag was moved to the
`pack`/`unpack`/`page` commit hours before this was found. What that says is
not that the standard is large but that "complete" is a claim about the
*corpus*, and the corpus is what keeps being smaller than the standard.

**`verify/` gained nothing**, and correctly: there is no arithmetic here, no
conversion and no check. The characters are the same characters in the same
global, whether the literal was written in place or named.

**The feature is testable in both languages and the tests differ.**
`tests/stringconst.pas` is ISO 7185 — writing, comparing, assigning, passing by
value, indexing. `tests/extended/stringconst_ops.pas` is what Extended Pascal
adds: concatenation, `substr`, `length`, `index`, §6.5.6's substring of a
constant, and §6.8.3.5's padded comparison against a value of a different
length, which ISO 7185 refuses. It also imports the constant from a module, for
the one path a bare name does not reach — a qualified constant-name is a
different node and a different arm of `emitAddress`.

**Four of the five new code paths are killed by the tests**; the fifth is not,
and this is what it is. `emitConst`'s memory case — the one that hands back
storage rather than a scalar — is **not reached by any of the 388 files**, and
that was established by instrumenting the branch and compiling the whole
corpus, not by supposing. Every context that wants a memory value asks for its
address directly, so `emitAddress` is the route and `emitConst` is a second
door onto the same helper. It is kept because `emitConst` answers for *every*
constant and the alternative is a silent `i32 0` if anything ever arrives; the
honest description is that it is a guard, not a lowering.

### What this does not do

**A constant-expression still cannot be string-valued.** ADR-0054 refuses
folding a real-, set- or string-valued operation, and that is unchanged: `const
t = 'ab' + 'cd'` is refused, because folding it would mean building characters
in the compiler and both compilers must refuse or both must agree on the
result. What is new is only the *literal* case, where there is nothing to
compute.

**§6.8.8's constant-accesses are still not implemented.** `hex_digits =
hex_string[1..10]` — a substring of a string constant, in §6.3.2's own example
— needs the folder to select from a constant's value, which is a separate
feature. This record makes the value reachable; it does not make it
selectable.
