# 52. Binding is a file name chosen while the program runs

Date: 2026-08-11

## Status

Accepted. It is the feature ADR-0051 unblocked.

## Context

ISO/IEC 10206:1991 §6.7.5.6 gives `bind(f, b)` and `unbind(f)`, §6.7.6.8 gives
`binding(f)`, and §6.4.3.4 gives the required type they trade in:

"There shall be a record-type designated packed and denoted by the required
type-identifier `BindingType`. For each of the required field-identifiers
`name` and `bound`, there shall be an associated required field of the
record-type, and that field shall have an **implementation-defined
variable-string-type** and a type denoted by the type-denoter `Boolean`,
respectively."

That phrase is why this feature waited: there was no variable-string-type to
give the field until ADR-0051.

## Decision

**The external entity is a file name**, and the binding is the name. §6.7.5.6
says only that "the binding shall be implementation-defined", so what matters
is choosing something the language could not already express — and this is
exactly that: ISO 7185 §6.10 binds the program parameters *before* the program
starts and gives it no other way to reach the outside. `bind` is how a program
names a file while it is running.

**A bound file becomes a program parameter that named itself.** `pas_external`
already answered "which external file is this variable for?", so binding adds a
third answer beside "argument *n*" and "a scratch file with no name" — and
`reset`, `rewrite` and `extend` needed no change at all.

**`bindable` belongs to the type-denoter**, and so a type-name hands it on:
§6.4.1 makes a type-name denote "the type, bindability and initial state" of
its definition. That is what makes `type btext = bindable text` the way to
write a bindable *parameter* — `var t: text` never is, because a required
type-identifier is not bindable. `bindableOf` is `initialStateOf`'s shape, for
the same clause's reason.

**`binding(f)` is built in a hidden frame slot.** It is the only required
function whose result is a record, and this compiler returns no records — so
Sema gives each call site a hidden frame variable of type `BindingType`, the
same mechanism a `with` binding uses (ADR-0017), and the call *is* that
designator. `b := binding(f)` is then an ordinary whole-record assignment and
passing it to a value parameter is an ordinary copy, with no case anywhere for
either.

**`bind` ignores `b.bound`**, which NOTE 3 says outright, and never writes back
to `b`, which NOTE 4 says twice. Only `binding` reports the result, and the
standard's own example is a loop that asks again after every attempt.

**Trailing spaces are trimmed from the name.** §6.4.6 pads a fixed-string value
with spaces, so a name that arrived as a `packed array [1..40] of char` ends in
them, and a file whose name ends in a space is never what was meant. A
*variable*-string carries its own length, so one that really ends in a space
keeps it.

## Consequences

**One number was wrong and the two backends disagreed about it.** The Pascal
`LlSize` for a string was `4 + capacity`, unrounded — so a record holding one
put its next field after the *rounded* size while the copy covered only the
unrounded one, and `BindingType.bound` fell outside a whole-record assignment.
`irtest` caught it as a wrong answer (`g TRUE` where the C++ said `g FALSE`),
which is exactly what that harness is for: two backends that agree on every
dump can still disagree about a number neither dump prints. Both compilers now
round, and the C++ `dynSize` for a string was under-rounding in the same way.

**§6.7.5.6's dynamic-violations are checked statically where they can be.**
"It shall be a dynamic-violation if the variable does not possess the
bindability that is bindable" is a property of the *declaration*, so it is a
diagnostic here rather than a run-time stop — §6.1's f) permits either. Binding
a variable that is already bound stays a run-time error, because only the
running program knows.

**Twenty-two mutations across both compilers and the runtime, all caught** —
and one of them found a bug ADR-0051 had introduced two records ago.

§6.4.5 d) made every string type compatible with every other and §6.4.6 pads
the shorter, so `'abc'` became a legal argument for a `packed array [1..8] of
char` value parameter. But a value parameter is copied **bytewise**: the callee
memcpy'd eight bytes from a four-byte global. Under ISO 7185 the lengths always
matched, so the copy was always right, and relaxing the compatibility quietly
turned it into an overread. It surfaced here because binding is the first
feature that passes a *padded* name around, and the mutation that removed the
trim was the one that did not die.

The lengths must therefore agree until there is somewhere to build the padding
— the same missing mechanism a variable-string value parameter needs, and now
the same message.

**`verify/` gained nothing**, for the sixth record running.

## What this does not do

**Only a file variable may be bound.** §6.7.5.6 allows binding any variable and
leaves the meaning implementation-defined; a file name is the only external
entity this compiler has a meaning for, so everything else is refused rather
than given one that means nothing.

**A variable-string may not be a value parameter**, and this feature is where
that surfaced: `procedure attach(nm: string(64))` would have to *convert* its
argument — §6.4.6 pads or refuses by length, and the actual may be a literal, a
fixed string, or a string of another capacity — and a conversion needs
somewhere to build the result that the caller can name. A `var` parameter and a
fixed-string value parameter both work, and the bare schema name `string` is
the general form once it may be passed by value.

**`binding(f).bound` is not written directly.** §6.8.6's function-accesses — a
selector applied to a function call — are a separate missing feature, so a
program says `b := binding(f)` first, exactly as §6.7.6.8's own example does.

**Program parameters are not bindable.** §6.12 binds them before the program
runs and §6.5.1 makes a bindable variable totally-undefined until bound, so a
program parameter that was also `bindable` would be two bindings arguing. The
standard resolves this by making program-parameters bindable *implicitly*;
here they keep ISO 7185's binding and `bindable` is for everything else.
