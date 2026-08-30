# 263. One linker symbol per component, not per program

Date: 2026-08-30

## Status

Accepted, 2026-08-30.

It narrows [ADR-0147](0147-one-linker-symbol-one-external-declaration.md) to the scope
AP 6.7.7.11 always stated, and moves the case ADR-0147 was really protecting
against to where it belongs.

## Context

Asked whether TLS could be bound through this dialect's FFI, the answer turned
out to be yes — OpenSSL's API is opaque pointers throughout, which is AP
6.4.12's handle exactly, and a full handshake ran from an ordinary program with
no change to the compiler or the runtime. What stopped the *first* attempt was
not TLS at all:

    error: the foreign name 'pasx_socket_fd' already names 'extfd';
    one linker symbol may be named by one 'external' declaration,
    so call that one

`extfd` is `PasNet`'s own private binding. The program had not written it,
could not see it, and could not call it — `PasNet` does not export it.

AP 6.7.7.11 reads: *"Within one program-component, no two external-declarations
shall have the same character-string."* The check was over the whole
compilation.

## Decision

**Sema asks the clause's question about one component**, keyed on
`pdFileIdx = 0` — the component being translated, an import's index while its
source is read (ADR-0210).

**The emitter asks its own question about one module.** `ForeignDeclaredBefore`
drops a second `declare` of one linker name, which is what `handleClosers`
already did for a closer.

**Two questions, because they are two questions**, and conflating them is what
made the diagnostic wrong. The clause is about what a *program-component* may
say; LLVM's refusal is about what one *module* may contain. They coincide until
a generic crosses a component boundary, and then they do not.

## Consequences

**The over-strictness grew with the library.** Every foreign name any module
binds privately was taken from every program that imports it: `PasNet` holds
`pasx_socket_fd` and the eleven socket calls, `PasProcess` holds `popen`,
`fgetc` and `system`, `PasIO` holds `read`, `write`, `open` and `close`. A
program importing `PasIO` could not bind `read`. That surface has been growing
since `lib/` did, and nothing was measuring it.

**The case ADR-0147 was actually protecting against is real**, and it is
narrower than the check that covered it. AP 6.7.3.10.2 translates an
instantiation in the component that named the types (ADR-0212), so a generic
whose body calls a foreign routine emits that routine's `declare` into the
*client's* module — beside the client's own, if it bound the same symbol.
`tests/dialect/foreign_shared_symbol.pas` stages both halves, and each is
caught by putting one half back: unscoping the check refuses the program,
removing the dedupe makes LLVM refuse the module.

**It was measured rather than argued.** A client importing a module that binds
`strlen` emits *no reference to it at all* — the client calls the module's
Pascal routine by its linkage name and the foreign call sits in the module's
own object. That is what says the cross-component check protected nothing, and
it took one `grep` of the emitted IR.

**Where two declarations disagree, the first written wins.** That costs nothing
that is not already true: `doc/sop.md` §7 records that nothing checks a foreign
heading against the routine it names, and that the call site is the whole of
the ABI — a mutation writing `declare double @cbrt(ptr, double)` beside a
correct call assembled, linked and ran. The `declare` is documentary.

**And the roadmap entry that sent me here was wrong**, which is the fifth
estimate on that page to be. It said TLS "means binding a C library, which puts
the *whole* of that library's surface behind ADR-0185's rule that a library may
not declare a foreign struct". ADR-0185 does not apply: OpenSSL declares no
struct to a caller. And it said the runtime would have to link it; the *program*
links, through `AFTERSCHOOL_PASCAL_CFLAGS`, a seam that already existed and
that the sanitizer gate already used. Both grounds were asserted without a
probe, and the probe took twenty minutes.
