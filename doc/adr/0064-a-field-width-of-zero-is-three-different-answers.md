# 64. A field width of zero is three different answers

Date: 2026-08-12

## Status

Accepted.

## Context

ISO 7185 §6.9.3.1 says of a write-parameter's field width:

> The values of TotalWidth and FracDigits shall be greater than or equal to
> one; it shall be an error if either value is less than one.

ISO/IEC 10206:1991 §6.10.3.1 moves the bound:

> The value of TotalWidth shall be greater than or equal to zero; it shall be
> an error if the value is less than zero. The value of FracDigits shall be
> greater than or equal to zero; it shall be an error if the value is less than
> zero.

One word changed, and every subclause under it had to say what the new value
means. That is the feature: not "widths may now be zero" but "here is what zero
writes", type by type, and the answers are not the same.

## Decision

**The bound is checked in the compiler, not in the runtime.** A width is an
expression, so this is a run-time error rather than a diagnostic — but *which*
number is the least legal one is the one thing about it the standard decides,
and the runtime is never told which language a program was compiled for.
`emitWriteArgs` emits the compare and the trap, with the message naming the
bound it applied.

That also keeps `-1` usable as the "no width given" sentinel, which the
obvious alternative would have destroyed: if a negative width reached the
runtime it would be indistinguishable from a width nobody wrote.

**`Sema::std()` is the second whole-program answer CodeGen asks for**, after
ADR-0053's `activeModules()`. The Sema→CodeGen contract says a fact about the
source program belongs in Sema; the standard *is* a property of the source
(ADR-0033), so this is that rule applied rather than an exception to it.

**Zero means three different things, and the clauses are explicit about each:**

- **A string or a Boolean writes nothing.** §6.10.3.6: "if TotalWidth = 0, no
  characters", and §6.10.3.5 makes a Boolean "equivalent to writing the
  appropriate character-string 'True' or 'False' ... with a field-width
  parameter of TotalWidth", so it is the same clause and the same code.
- **A char writes nothing** (§6.10.3.2's new case).
- **An integer writes its digits.** §6.10.3.3 b) applies whenever TotalWidth is
  less than IntDigits + 1, which zero always is — so only the padding goes.
  Reading "zero width" as "suppress" would have been wrong here and nowhere
  else.
- **A real writes a full representation either way**, because both §6.10.3.4.1
  and §6.10.3.4.2 clamp: the floating form takes `ActWidth = max(TotalWidth,
  ExpDigits + 6)` and the fixed form's NOTE says "At least MinNumChars
  characters are written. If TotalWidth is less than this value, no initial
  spaces are written."

**§6.10.3.6's truncation was already ISO 7185's rule, and this runtime did not
honour it.** "if 1 <= TotalWidth <= n, the first through TotalWidth-th
characters" is in §6.9.3.6 word for word, and `pas_write_str` wrote the whole
string whenever the width did not exceed the length. One corpus program
noticed — `tests/extended/schema_string.pas` had `short:1` printing `[abc]` —
and its golden changed to `[a]`. So this feature fixed a conformance gap that
predates Extended Pascal, and it fixed it in *both* standards, because the
clause is the same in both.

**A FracDigits of zero writes the point.** §6.10.3.4.2's representation is
"... the character '.', the next FracDigits digit-characters", with the '.'
unconditional and counted in MinNumChars — so `x:8:0` is `      4.` and not
`       4`. C's `%.0f` writes no point, which is why that one case is formatted
by hand rather than by a format string.

**The floating form now derives DecPlaces from the width**, which §6.10.3.4.1
always required and this runtime never did: it hard-coded six fraction digits
whenever a width was given. `x:12` was `3.750000E+00` — twelve characters of
number in a field of twelve, with the width doing nothing. It is now
`DecPlaces = ActWidth - ExpDigits - 5`, so the representation is exactly
ActWidth characters wide and the width means what it says. The default form's
output is unchanged, because the implementation-defined default TotalWidth
(E.24) is defined here as `ExpDigits + 17`, which is the value that yields the
twelve fraction digits it already printed.

## Consequences

`verify/` gained nothing: there is no new arithmetic, and the trap's condition
is `width < least`, which is the ISO condition written once rather than twice
(the case ADR-0013 says not to add a rule for).

**ExpDigits is not fixed, and that is a stated deviation.** §6.10.3.4.1 makes
it "an implementation-defined value representing the number of digit-characters
written in an exponent" — a *value*, so one number for the whole
implementation. Here it is two digits, or three past 1e100, because that is
what C's `%E` writes and the alternative is formatting the exponent by hand for
no observable gain. The consequence is that `ActWidth` is computed per value
rather than per program, which keeps every representation exactly ActWidth wide
— the property the clause is actually after — while making that width depend on
the exponent. A conforming processor would pad `E+00` to `E+000`.

**The two cases of §6.10.3.6 agree at the boundary, and a mutation proved it.**
Changing the padding test from `TotalWidth > n` to `>=` survives every oracle,
and no test can kill it: at `TotalWidth = n` the padding branch writes zero
spaces and then `n` characters, and the truncating branch writes `TotalWidth`
characters, which is the same number. That is not a gap in the corpus — it is
the clause's own overlap, which is why §6.10.3.6 can state "if TotalWidth > n"
and "if 1 <= TotalWidth <= n" as separate cases without contradicting itself.

**Rounding may move the exponent past the boundary** — `9.99e99` written narrow
enough rounds to `1.0e100` — and ExpDigits is chosen before the rounding, so
such a value is one character wider than ActWidth. Stated rather than fixed:
detecting it means doing §6.10.3.4.1's arithmetic twice.

**Writing an enumerated value is still refused**, and ISO/IEC 10206:1991 does
not add it: §6.10.3.1's list of writable types is ISO 7185's, word for word.
The comment in Sema that says so needed no change.

### What this does not do

**Sema does not fold a constant width and diagnose it.** `write(x:-1)` is a
run-time error under both standards, where a compiler could see it. That is
§6.1's f) latitude — an error may be reported at preparation time or during
execution — and reporting it at run time keeps one implementation of one rule,
which is the trade ADR-0042 already made for a schematic assignment's tuple.
