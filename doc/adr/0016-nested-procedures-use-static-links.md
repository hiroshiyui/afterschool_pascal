# 16. Nested procedures use static links

Date: 2026-08-09

## Status

Accepted

## Context

Procedures and functions are the first item in ADR-0004's dependency list, and
the reason they come first is nesting. ISO 7185 lets a procedure be declared
inside another and refer to the enclosing procedure's variables, to any depth.
That is not syntactic sugar: at the point `Inner` reads `b`, the machine has to
find the activation record of the *particular invocation* of `Outer` that
`Inner` was reached from.

Three implementations were considered.

**Lambda lifting** — rewrite each nested procedure to take the variables it uses
as extra parameters. Removes the problem entirely, but breaks on assignment to a
non-local (the copy would be updated, not the original), so every captured
variable would have to be passed by reference and every call site rewritten. It
also changes the shape of the AST, which is the thing the port has to translate.

**A display** — a global array indexed by nesting level, holding the current
frame at each level. Access is one indexed load rather than a chain walk, but
the array has to be saved and restored around every call, and it is fragile in
exactly the case that matters (recursion).

**Static links** — each activation record carries a pointer to the record of the
block that lexically encloses it. Access at `n` levels out walks `n` links.

## Decision

Static links. Every procedure gets an activation record — a struct alloca'd in
its entry block — whose field 0 is the link to the enclosing block's record.
Variables, value parameters, `var` parameters, and the function result all live
in that record as fields.

* Reading or writing a variable declared `n` levels out follows `n` links, then
  indexes. `frameAt` walks; `addressOf` indexes.
* Calling a procedure declared at level `L` passes the frame at level `L-1` as a
  hidden first argument. For a recursive call that is the caller's *parent*, not
  the caller — which is the whole subtlety in one line.
* A `var` parameter's slot holds the address of the caller's variable, so a
  reference passed onward stays bound to the original.
* The link is field 0, at offset zero, so an intermediate hop can load it
  without knowing which procedure's struct type that level has. Only the final
  index needs the target's type.

## Consequences

Nesting works to arbitrary depth, and a nested procedure inside a recursive one
sees the locals of the invocation it was called from. That case —
`Down(3)` printing `3 2 1 0 0 1 2 3` through a nested `Show` — is in
`tests/nesting.pas` precisely because it is what separates a correct
implementation from a plausible one; a display gets it wrong without careful
save/restore, and lambda lifting gets it wrong quietly.

Access to a non-local costs one load per level of distance. Real Pascal code
nests two or three deep, so this is a couple of loads at worst, and it is paid
only by code that actually reaches outward.

Putting *every* local in the frame struct rather than in its own alloca is the
notable cost. It means `mem2reg` cannot promote locals to registers whenever the
frame's address escapes — and it escapes as soon as the procedure passes it as a
static link to something nested inside it. Procedures with no nested
declarations never pass their frame anywhere, so SROA still promotes them
completely, which is the common case. Optimising the rest would mean putting
only the *captured* variables in the frame and leaving the others as ordinary
allocas; that is a worthwhile refinement and deliberately not done yet.

The `main` function is the program's own activation record at level 0, with a
null static link that is never followed. Treating the program as just another
block is what lets `checkBlock` and the `Block` AST node serve both.

## Notes for the port

This is the design a Pascal-hosted compiler can also emit, which matters for
ADR-0006: the frame struct, the link field, and the chain walk are all
expressible in textual LLVM IR with no C++ API involved. It is also, not
coincidentally, the design the stage-1 compiler's own source will rely on — the
compiler is a recursive-descent parser full of nested helpers.
