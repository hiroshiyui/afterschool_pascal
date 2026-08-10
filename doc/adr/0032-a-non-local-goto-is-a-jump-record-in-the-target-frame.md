# 32. A non-local `goto` is a jump record in the target's frame

Date: 2026-08-10

## Status

Accepted. Completes the part ADR-0029 deferred; that record stands otherwise.

## Context

ADR-0029 implemented `goto` for labels of the same block and refused the rest.
§6.8.1's placement rule was checked either way, so the only thing missing was
the lowering — and that record named the two things it needed: `setjmp`/
`longjmp` with a buffer in the target's frame, and the abandoned activations'
files closed, which ADR-0021 made a block-exit obligation and which a `longjmp`
would silently skip.

This is the last of ISO 7185.

## Decision

**The target block carries a jump record, and the goto reaches it through the
static chain.** It is a field of the activation record, after the variables so
that no frame index moves, and it is not a frame variable because nothing in
the source can name it. A goto to a label of an enclosing block computes
`frameAt(owner->level)` — the same walk every access to an enclosing variable
does — so for a recursive enclosing procedure it lands in the invocation this
one was called from, not the outermost.

**Which blocks need one is decided by their nested blocks, not by themselves.**
A block learns that one of its labels is a non-local target when Sema resolves
a goto that was handed outwards to it, which has already happened by the time
that block's own statements are walked. That is the hand-off ADR-0029 built for
the diagnostic; it turns out to be what carries this information too.

**`_setjmp` is called from the generated function, never through a wrapper.**
A runtime helper that called it would have returned by the time a jump arrived,
and its frame is exactly what `_setjmp` recorded. So the runtime exposes
`pas_jump_env`, which arms the record and hands back the address to call
`_setjmp` on. That keeps `jmp_buf` — its size, its contents, its alignment —
the platform's business and the runtime's, which is the same division a file
variable already has (`PAS_JUMP_SIZE` beside `PAS_FILE_SIZE`).

A label arrives as its own id plus one, because `_longjmp` with zero comes back
looking like the ordinary entry to the block.

**The abandoned blocks' files are found dynamically, not through the static
chain.** Every open file is on a list, and the jump record notes the head of
that list when it is armed; the jump closes everything registered since. This
is not the obvious implementation — walking the static chain from the goto to
the target and closing each frame's files looks equivalent — but it is wrong.
A procedure passed as a procedural parameter (ADR-0030) is called from a block
that is *not* on its static chain, and a jump out of it abandons that block
too. `tests/goto_files.pas` has both shapes for that reason.

File lifetimes nest, so "registered after the target's activation was armed"
and "belongs to a block the jump abandons" are the same set. That is what makes
one mark enough.

## Consequences

**Every activation whose block declares a non-local target pays for it**: a
call to arm the record, a `_setjmp`, a switch, and `PAS_JUMP_SIZE` bytes of
frame. Nothing is paid by a block that is not one, and the vast majority are
not — Sema knows which, so the cost lands exactly where the feature is used.

**`returns_twice` is load-bearing and no test defends it.** LLVM does *not*
infer it from the name `_setjmp`: with the attribute removed the declaration
comes out bare, and at `-O2` a function containing the call was inlined into
one whose frame `_setjmp` never recorded. The suite did not notice, because the
tests happen not to keep anything in a register across the call. This is
recorded rather than papered over: the attribute is set on the declaration and
on the call site, both backends state it, and the reason is in the comment
beside it.

**ADR-0021's block-exit obligation now has two implementations**, the epilogue
and the runtime's jump. They are the same work, and the second exists because
the first is what a `longjmp` skips. A block exit also disarms the record.

**Sixteen mutations, thirteen caught.** Three escaped, and they are two
different things:

- *Removing `returns_twice`* — the real hazard above. It is a gap in the tests,
  not in the compiler, and it is not obvious how to close it: it needs a
  program whose correctness depends on a value the optimiser would have kept in
  a register, which is a property of LLVM's choices rather than of Pascal.
- *Leaving the record armed at block exit, and letting a jump into a dead frame
  through* — the same safety net, and unobservable by construction. The static
  chain names only live activations, so a program the compiler accepts cannot
  reach a dead frame. The check exists for the case where that reasoning is
  wrong, and a test for it would have to be a program the compiler rejects.

Three more escaped on the first round and were a corpus gap, now closed: no
test had the block a jump *lands in* owning a file it kept using, so arming the
record before the block's files were opened, closing every file rather than
only those above the mark, and never recording the mark at all were all
invisible. One addition to `tests/goto_files.pas` catches all three. That is the
sixth time counting what the corpus actually reaches has found a hole.

**The test harness now runs the compiled program with a small descriptor
table.** `files_scratch.pas` and `goto_files.pas` are both resource tests —
they can only fail if the table can run out — and on a machine whose default
limit is half a million it never would. `ulimit -n 256` is what makes them mean
what their comments say.

**ISO 7185 is complete.** What remains for the language is Extended Pascal
(ISO/IEC 10206:1991), which is a second stage rather than more of this one.
