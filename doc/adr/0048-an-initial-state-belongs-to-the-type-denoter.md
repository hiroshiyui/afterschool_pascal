# 48. An initial state belongs to the type-denoter

Date: 2026-08-11

## Status

Accepted.

## Context

ISO/IEC 10206:1991 §6.4.1 and §6.6:

```
type-denoter            = [ 'bindable' ] ( type-name | new-type
                          | type-inquiry | discriminated-schema )
                          [ initial-state-specifier ] .
initial-state-specifier = 'value' component-value .
```

"The initial state specified by an initial-state-specifier shall be the state
bearing the value denoted by the component-value" (§6.6), and §6.2.3.5: "Each
variable contained by an activation of a block ... shall be created in its
initial state within the commencement of the activation."

## Decision

**The specifier belongs to the type-denoter, not to the declaration**, and this
record's title is the whole design. Three things follow from taking that
literally, and each is a place the obvious implementation would have differed.

**A type-name hands it on.** §6.4.1 makes a type-name denote "the type, the
bindability and the initial state" of its definition, so `type count = integer
value 1; var c: count` initialises `c`. The initial state is therefore recorded
on the *type symbol* as well as on the variable, and `initialStateOf` is the
one place that knows the difference. It is not on the `Type`: the types here are
shared singletons and name-equivalent objects (ADR-0017), and `integer value 1`
must not teach every integer in the program to be 1.

**It is attributed at every activation.** A recursive procedure's local is
created in its initial state on each call, not once — so this is a *prologue*,
not a static initialiser, and it sits beside the two prologues that were
already there (the dynamic-variable one of ADR-0041 and the file one of
ADR-0021).

**A record's fields may each carry one**, and then the record has an initial
state without one of its own being written. That makes the prologue a
recursion over fields rather than a store. It does not recurse into an array:
§6.4.3.2 forbids a component-type from carrying a specifier at all.

**Nonvarying is a question about what the expression reads, not about what the
compiler can fold.** §6.6 requires the component-value's expressions to be
nonvarying (§6.8.2), and the standard's own examples are `ord(red)` and
`polar(exp(1.0), pi)` — neither of which this compiler folds, and both of which
are perfectly good things for a block prologue to *compute*. So the test is
syntactic: literals, constants, operators over those, set constructors, and
required functions of nonvarying arguments. A user-declared function is not
one, because §6.8.2 does not make it so and its body may read anything. What
survives the test is emitted where it stands, which is why no new constant
representation was needed anywhere.

**The parser decides where the word may attach, and there was only one reading
that parses.** `set of 1..9 value [2]` has exactly one place the specifier can
go, and a recursive `parseTypeExpr` for the base type would have taken it. So
the three positions that may carry one — a variable declaration, a type
definition, a record field — call `parseTypeExpr`, and every nested denoter
calls `parseTypeDenoter` and stops before the word. That is what turns §6.6
NOTE 3's own example, `array [1..8] of char value '*'`, into the type error the
note says it is: the component stops at the word, the array takes it, and a
char is not an array.

## Consequences

**CodeGen gained a prologue walk and `emitStore` did the rest.** The store is
the one assignment already does, so a subrange initialised out of range traps
where it always would, a whole-record value is the memcpy it always was, and
neither backend needed a new path.

**`verify/` gained nothing**, for the fourth record running: the store is
assignment's, and assignment's rules are already proved.

**`value` is a *new* reserved word, and the bill came due immediately.**
`tests/extended/shortcircuit.pas` had a record field named `value` and stopped
compiling; the field is now `datum`. That is ADR-0033's whole reason for making
the standard a property of the source rather than a superset, and this is the
first place in the corpus where it cost something. `selfhost/compiler.pas` has
a field of that name too and is untouched, because it is ISO 7185.

**It also removes a check.** Unlike `type of` (ADR-0047), whose words are
reserved in both languages and which therefore needs an explicit refusal under
`--std=iso7185`, `value` is a word Extended Pascal *adds* — so under ISO 7185
the lexer yields an identifier and the token never appears. A `--std` test in
the parser here would be dead code, and one was written and then deleted when
the ISO 7185 test showed the message it produced was the ordinary
"expected ';', found identifier".

**Nineteen mutations across both compilers, all caught**, after two escaped and
were given tests: a *parameter* whose type is a record with per-field
specifiers, which is the only shape where "§6.2.3.5 excludes formal parameters"
can be seen failing, and a schema body carrying one.

The second of those turned a diagnostic into a deletion. §6.4.7 makes a schema
body a type-denoter, so the word parses there and needed refusing with a reason
of its own — and once it had one, the *generic* "an initial-state specifier
belongs to a variable, a type definition or a record field, not here" message
turned out to be unreachable. The parser is the whole position rule, so no
denoter can arrive in Sema carrying a value it may not have. Both compilers'
copies were deleted, the same way ADR-0047's side lookup was.

## What this does not do

**A component-value may only be an expression.** §6.8.7 also allows an
array-value (`[1..8: '*'; otherwise ' ']`) and a record-value (`[f1: 0; f2:
0.0]`), and both are refused here — they are the *structured-value-constructor*
feature, which §6.8.7 also makes usable in an ordinary expression, and which is
therefore its own record rather than half of this one. Simple types, subranges,
enumerations, sets, pointers and — through per-field specifiers — records all
work today.

**A field of a variant part may not have one.** §6.5.1 makes a variant's
initial state conditional on the selector's own initial state selecting it;
nothing here tracks that, so such a field is refused with its own message
rather than initialised into a variant that may not be the live one.

**`bindable` is not accepted**, and it is the other half of §6.4.1's
type-denoter. It waits for the binding feature.
