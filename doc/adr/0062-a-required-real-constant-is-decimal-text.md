# 62. A required real constant is decimal text

Date: 2026-08-12

## Status

Accepted.

## Context

ISO/IEC 10206:1991 §6.4.2.2 b) requires three constants:

> Each of the required constant-identifiers `minreal`, `maxreal`, and `epsreal`
> shall denote an implementation-defined positive value of real-type. The
> values of `minreal` and `maxreal` shall be such that arithmetic in the set
> including the closed interval −`maxreal` to `maxreal` but excluding the two
> open intervals −`minreal` to zero and zero to `minreal` can be expected to
> work with reasonable approximations ... The value of `epsreal` shall be the
> result of subtracting 1.0 from the smallest value of real-type that is
> greater than 1.0.

Three ADRs have deferred them, and always for one reason. ADR-0025 decided that
a real literal is carried as **the text that was written**, all the way into
the IR — LLVM's assembler is the `strtod`, and `selfhost/compiler.pas` has no
floating-point type at all. ADR-0054 refused real-valued constant-expressions
on the same grounds: there is no float in the Pascal-hosted compiler to fold
with. ADR-0059 said the three constants "need interned *text* rather than a
value", and left them.

## Decision

**The text is the mechanism, not a workaround.** Each constant is spelled as
the shortest decimal that round-trips to the IEEE-754 binary64 value it names,
and *the same characters are written in both compilers*:

```
maxreal  1.7976931348623157e308
minreal  2.2250738585072014e-308
epsreal  2.220446049250313e-16
```

The C++ compiler reaches the value through its own literal parsing and stores a
`double` in the symbol; `selfhost` interns the characters and prints them into
the IR, where LLVM's assembler parses them. Two routes, one value — because
decimal-to-binary64 is correctly rounded in both, and each spelling is the
shortest that identifies its value uniquely.

That is why ADR-0025's deferral turned out to cost nothing. What was missing
was never a conversion; it was somewhere to put twenty-two characters.
`selfhost` interns a name it knows about through a fixed-width literal type,
and its widest is sixteen — so the three constants are interned in two pieces
by `InternWide2`, which is the whole of the new machinery.

**They are required *identifiers*, so they are declared in the outermost scope
and a program may shadow them.** §6.4.2.2 b) calls them constant-identifiers
and §6.1.2's word-symbol list does not contain them, so this is ADR-0049's
rule again: gated in Sema on `--std=extended`, invisible to the lexer, and
overridden by any declaration of the same name.
`tests/extended/realconsts_shadow.pas` declares all three as something else.

**Which three values** is Annex E's business rather than the clause's — E.5,
E.6 and E.7 make each of `minreal`, `maxreal` and `epsreal`
implementation-defined, one entry apiece — so naming the representation is what
fixes them. `real` is a binary64 here,
and the three are its largest finite value, its smallest positive **normal**
one, and its epsilon. `minreal` is deliberately the smallest *normal* rather
than the smallest subnormal: §6.4.2.2 b) asks for the bound below which
arithmetic "cannot be expected to work with reasonable approximations", and
subnormal arithmetic loses precision, which is exactly what the clause is
warning about.

## Consequences

`verify/` gained nothing, no lowering changed, and CodeGen was not touched in
either compiler: a constant of real type already emitted, in the C++ through
`ConstantFP` and in `selfhost` through `EmitRealText`, and these three arrive
in those paths as any `const pi = 3.14159` does.

**The property that defines `epsreal` is what the test asserts.**
`1.0 + epsreal > 1.0` and `1.0 + epsreal / 2.0 = 1.0` are §6.4.2.2 b)'s
sentence written as a program, and they are worth more than the printed
characters — the characters would pass with any nearby value.

**`tests/realconsts_iso.pas` is the gate**, and it had to be a *negative* test:
the names are ordinary identifiers under ISO 7185, so a program that declares
its own compiles under both standards and distinguishes nothing. Writing
`maxreal` with nothing declaring it is the only program whose two answers
differ. Same shape as ADR-0056's gate, and for the same reason.

### What this does not do

**A real-valued constant-expression is still refused** (ADR-0054). Nothing here
gives either compiler a float to fold with; the three constants are values a
symbol *holds*, not values an operator can produce. `const c = maxreal` works
because it copies a symbol; `const c = maxreal / 2.0` does not, and that
deferral is unchanged.
