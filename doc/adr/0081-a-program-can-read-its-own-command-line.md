# 81. A program can read its own command line

Date: 2026-08-14

## Status

Accepted.

## Context

`selfhost/compiler.pas` takes four *files* and no flags. ADR-0033 explained why
— ISO 7185 gives a program no access to its command line beyond its
program-parameters, and those are files, so the standard to compile for arrives
as a file holding one word — and ADR-0079 met the same constraint a third time
with §6.13's components, concatenated into a fifth parameter.

`doc/roadmap.md` had drawn the general conclusion: a driver written in Pascal is
impossible, so "write Pascal directly" needs a shell script around the compiler.

That conclusion was wrong, and had been for as long as ISO/IEC 10206:1991 was
supported. Two clauses say so:

- **§6.5.1**: "The variable-identifier shall possess the bindability denoted by
  the type-denoter, **unless the variable-identifier is a program-parameter or a
  module-parameter, in which case the variable-identifier shall possess the
  bindability that is bindable**."
- **§6.7.6.8 NOTE 2**: the value `binding` returns "can also be used to
  **determine the result of any binding of program-parameters prior to
  activation of the main program** (see 6.12)".

Together: every program-parameter is bindable without saying so, and `binding`
is how a program inspects the binding §6.12 made for it. `binding(p).name` *is*
`argv[n]`.

Neither was implemented, in either compiler. Sema refused `binding(a)` on an
undecorated program-parameter with "'a' is not bindable"; the runtime answered
`bound = false` and an empty name for one that was decorated. Every oracle
agreed, because **no program in the corpus had ever asked a program-parameter
about its binding** — ADR-0067's shape, for the seventh time.

ADR-0074 is the sharper part of the history: it quotes §6.5.1's sentence, and
quotes it to settle a *different* question (whether a program-parameter must
possess a file-type). The clause was read, used, and its other half not noticed.

## Decision

**A program-parameter is bindable because it is one.** `bindProgramParameters`
sets it under `--std=extended`, before the file/non-file split, so a non-file
parameter is bindable too — §6.5.1 conditions nothing on the type. The
module-parameter half is set where §6.11.1's check already walks them.

**`binding` reports the binding made before activation.** One function in the
runtime answers all three questions (`bound`, `name`, the length), in the order
`pas_external` already resolved them: a binding the program made wins, then the
command-line argument, then nothing.

**`unbind` clears the binding §6.12 made.** §6.7.5.6's "the variable shall
become totally-undefined" has to include a binding the program did not make, or
`bound` stays true with nothing behind it. This was a real defect rather than a
consequence: `pas_bind` sets `binding = PAS_BIND_ARG` to mean "bound to a name",
so the constant has two senses that only `bound_name` tells apart, and `unbind`
freed the name while leaving the constant — after which the new code read
`argv[0]`. `tests/extended/required_identifiers.pas` failed on the first run,
which is the one time an existing golden has caught a bug in a change made to
fix a different one.

**`input` and `output` answer as unbound**, which is a choice §6.7.6.8 leaves
open by making the value implementation-defined. They *are* bound to an external
entity, but to one with no pathname, and a made-up name would be one `bind`
could not reproduce. Stated in `doc/implementation-defined.md` under E.19 rather
than left to be discovered.

## Consequences

**A Pascal program can now read its command line**, which is the whole point:

```pascal
program P(output, a, b, c);
var a, b, c: text; bnd: BindingType;
begin
  bnd := binding(a);            { bnd.name is argv[1] }
  writeln(binding(c).bound)     { false when only two arguments were given }
end.
```

This is what makes a self-hosted driver possible. It does not make one exist —
`selfhost/compiler.pas` is an ISO 7185 source and cannot call `binding` at all,
so taking flags means compiling it as Extended Pascal first. Exactly two
identifiers in it collide with that language's word-symbols (`value`, 134 uses,
and `bindable`, 2), which is the size of that job and not this one's.

**It found a second bug, in a feature four ADRs old.** §6.4.3.4 gives
`BindingType.name` "an implementation-defined variable-string-type", and
ADR-0052 built one directly with `newType(TypeKind::String)` rather than through
§6.4.3.3.3's schema. §6.4.8 makes one schema with one tuple **one type** however
often it is written, so that field's type and the `string(255)` a program writes
were two types that printed identically — and `procedure p(var s: string)`
refused `binding(f).name` with "must be produced from schema 'string', but the
argument is string(255)".

`Sema::stringOfCapacity` is now the only way such a type is made, and the schema
is declared before `BindingType` so the field can be a production from it. This
is ADR-0074's diagnostic problem — two types that print alike — arriving as a
real one, and it was invisible for the same reason everything else here was: no
program had passed a `BindingType`'s field to a schematic formal.

**`verify/` gains nothing**, and for ADR-0079's reason rather than the usual
one: there is no arithmetic here. What changed is which facts a name carries.

### What this does not do

**It does not make `binding` work on a non-file variable.** §6.7.6.8's "if the
variable-access f possesses a file-type … otherwise, the variable shall possess
the bindability that is bindable" admits any bindable variable, and this
compiler requires a file. The symbol is now marked bindable for a non-file
program-parameter, so only the `binding`/`bind`/`unbind` type test stands
between here and that; it is left because `BindingType` describes a file and
what the other answer would *mean* is not settled by the clause.

**It does not give the program `argv[0]`.** §6.12 binds the parameters, and the
program's own name is not one of them. A program that wants it has nowhere to
ask.

**It does not check that an argument names a file that exists.** `binding(p)`
reports the argument as given; whether it can be opened is still decided at
`reset`, as E.34 says.
