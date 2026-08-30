# 266. A type parameter may say what it needs

Date: 2026-08-30

## Status

Accepted, 2026-08-30. AP 6.7.3.10.5.

It closes the last open item of `doc/roadmap.md`'s *Generics have no
constraints*, which
[ADR-0254](0254-a-generic-activation-need-not-write-its-types.md) narrowed and
[ADR-0260](0260-a-map-is-keyed-by-whatever-a-program-names.md) narrowed again.

## Context

`doc/roadmap.md` has carried constraints since generics arrived, and two
records have since taken most of the case for them away.

ADR-0260 removed the client. The row said a generic map waited on "a way to
say that a key can be hashed and compared", and it did not: §6.7.3.4 has
admitted a procedural parameter since ISO 7185, so a hash and an equality
travel as arguments and `PasContainer`'s `Map` is keyed by whatever a program
names, with no constraint anywhere.

ADR-0259 made the remaining case better. AP 6.7.3.10.2 reads a generic's block
once per distinct type-argument-tuple, in the region and the source the
generic was *written* in (ADR-0210), so a body that adds its `T` values is
refused at the generic's own line, and until ADR-0259 nothing said which
activation had asked. It now does.

**So what is left is exactly one thing, and it is the diagnostic.** For a
generic `Add(T: type; a, b: T): T`, `tests/dialect/generic_errors.pas` gets:

    generic_errors.pas:21:16: error: operator '+' needs numeric operands, found point and point
    generic_errors.pas:21:7: error: cannot assign integer to a result of type point
    generic_errors.pas:57:9: error: this activation is what asked for that instantiation of 'add'

Three lines, two of them about a source the caller may never have opened, and
the one that names the call comes last. The reader is told what the *body* did
wrong and has to work out that the answer is *don't ask for that type*. A
generic imported from a module makes this sharper: the first two lines name a
file the program does not contain.

The requirement `Add` actually has is one sentence — **T must be a type `+`
accepts** — and there was no way to write it down.

## Decision

**A type parameter may carry a category, written before `type` in the
formal-parameter-list**, and the category is checked where the type argument
is bound:

```pascal
function Sum(Elem: numeric type; a, b: Elem): Elem;
procedure Sort(Elem: ordered type; var a: array of Elem);
function Span(Elem: ordinal type; lo, hi: Elem): integer;
function Alike(Elem: equatable type; a, b: Elem): boolean;
```

    generic_constraint_errors.pas:62:12: error: point cannot be the type argument
    for 'elem' of 'sum', which is declared 'numeric type': that admits integer,
    int64, real, complex, or a subrange of one

One line, at the call, naming the requirement. The block is never read for
that tuple.

**The spelling is inherited and reserves nothing** (ADR-0140). `T: type` is
already AP 6.7.3.10's position; a parameter-form is one type-identifier,
schema-name or type-inquiry, and what may follow one is `;` or `)` — so an
identifier followed by the word-symbol `type` is a juxtaposition no conforming
program can write. This is ADR-0184's shape rather than a new position: the
feature does not ask for a place, it asks for two more tokens in a place the
dialect holds. `numeric`, `ordinal`, `ordered` and `equatable` are recognised
by their spelling *between the colon and `type`* and are in no region at all —
not required identifiers, which §6.2.2.10 would have put in the scope
enclosing the program and charged every program that declares one the
shadowing rule to get back. `tests/dialect/generic_constraints.pas` declares a
type, a variable and a field of each of the four names in the same program
that constrains four type parameters with them.

**The parser commits on the shape and resolves the spelling afterwards**,
which is what makes the message about a category writable at all. `hashable
type` is not a syntax error about the semicolon that never came;
`selfhost/badparse/type-param-category.pas` is the case.

**The set is closed, and each category is a group of operators this language
already has.** Each is backed by a predicate, and two of them are new
predicates rather than an expression written at the call site, so
`predicate-kinds` watches them:

| Category | Predicate | Admits |
| --- | --- | --- |
| `numeric` | `IsArith` | integer, int64, real, complex, and a subrange of integer |
| `ordinal` | `IsOrdinal` | §6.4.2.2's ordinal-types, and no other |
| `ordered` | `IsOrdered` (new) | every ordinal, and int64, real, the string-types and `utf8` |
| `equatable` | `IsEquatable` (new) | every ordered type, and complex, a set, and a pointer that is not owned |

**`ordinal` does not admit `int64`**, and the brief this was written from said
it should. AP 6.4.2.6.2 is titled *It is numeric and it is not ordinal* and
says so in as many words, `IsOrdinal` answers accordingly, and a category
called `ordinal` that admitted a type the specification says is not one would
be a third opinion about the same question. `ordered` is where `int64`
belongs, and it is there.

**`equatable` is read off the comparison dispatch and not off `IsAffine`**,
and this is the other place the brief was declined. `not IsAffine` — refuse a
file, a handle, an owned pointer and anything holding one — is one call and is
wrong for the feature's own purpose: §6.8.3.5 gives a record and an array no
relational operators at all, so `Alike(Point, p, p)` would have been *accepted*
by the constraint and then refused inside the body, which is precisely the
diagnostic this record exists to move. `IsEquatable` therefore names the arms
`CheckBinary` names for `opEq`: an owned pointer, a handle and an optional
compare with `nil` and with nothing else, so none of them is equatable with
itself; a file, a slice, a restricted type, an array and a record have no
equality at all. Mutating it back to `not IsAffine` fails
`generic_constraint_errors` and `badsema-generics`, which is the measurement
rather than the argument.

**The check is at the instantiation, in both of AP 6.7.3.10's activation
forms**, and the two differ in what they can point at.

- A **written** type argument is pointed at directly: the actual that names
  the type is where the reader looks and there is nothing to say about how it
  was chosen.
- An **inferred** activation (AP 6.7.3.10.4) writes no type anywhere, so the
  position reported is the actual-parameter that *determined* the parameter,
  and the message ends `argument 1 of this call is what determined it`.
  `typeBinding` gains that position and that number, filled where `BindType`
  already records the type. The determining shape may be a bare type
  parameter, a schema production read against its tuple or a slice read
  through its component (AP 6.7.3.10.4 a) to c)), and
  `selfhost/badsema/generics.pas` exercises all three, because each is a
  different walk in `Determine` and each has to arrive at the same answer
  about where the type came from.

**It does not make a generic separately type-checked, and the clause says so.**
AP 6.7.3.10.2 is unchanged: the block is read once per distinct tuple, and a
body that misuses a type its category *does* admit is refused there exactly as
it was. A category is a filter on the activation, not a signature the body is
verified against. Saying this plainly matters because the construct looks like
the other language's, and the other language's does verify the body.

**`tcNone` admits everything**, so no call site is conditional and every
generic written before this clause means what it meant — ADR-0018's shape for
`CheckedForSubrange` said again. Making it admit nothing fails ten of the
eleven `generic_*` cases, which is the whole of the argument for putting the
answer in `SatisfiesCat` rather than in an `if` at each of the two call sites.

## Consequences

**CodeGen is untouched, and so is `verify/lowering.py`.** A category chooses
whether an instantiation happens; the instantiation it chooses is the one that
would have happened anyway, and the tuple, the cache and the emitted function
are byte for byte what they were. The feature is a refusal and never a
lowering.

**The AST dump now writes the parameter-form back.** `type-parameter numeric`
where a category was written and `type-parameter type` where none was, which
is exactly what the source spelled — and it is what makes `WriteCatName`'s
`tcNone` arm reachable, `SatisfiesCat` never reporting about one.
`tests/dumps/typeparam.pas` is the golden; nothing in that corpus reached a
generic heading before.

**`WriteCatAdmits` is a partial case-statement and takes an entry in
`tests/checks/partial_cases.txt`.** It is asked only where `SatisfiesCat` has
already said no, and `SatisfiesCat` never says no about `tcNone`, so the fifth
arm is unreachable and writing one would be an unreachable statement the
`line-coverage` ratchet would then carry for ever. The guard is named at the
entry, which is what that catalogue asks for.

**Two predicates joined `predicate_kinds.txt` and no row moved.** The kind
count is unchanged at 21, so the two new rows are the whole of the diff —
`IsOrdered 8 of 21` and `IsEquatable 11 of 21`. That is the cheap direction of
ADR-0194's gate: a predicate added without a row fails rather than passing
unseen, and a kind added later will now ask thirty-eight questions instead of
thirty-six.

**A schema's type-valued discriminant takes no category** (ADR-0209,
AP 6.4.7.1), and NOTE 12 of the clause says why rather than leaving it to be
found: a discriminant is written where a type-denoter is being *built* and not
where a routine is being activated, so there is no activation for a refusal to
be attributed to. `Vec(T: numeric type; cap: integer)` is a syntax error, and
deliberately.

**What it still does not give.** A category is one of four names and cannot be
a program's own predicate — a requirement outside the four is still
AP 6.7.3.10.2's business and its diagnostic is still the body's. Widening that
would be admitting a second type system, and nothing has asked. The four exist
because each is a group of operators the language already defines; a fifth
would need the same justification and none is in sight.

**And the roadmap row closes rather than narrows.** ADR-0254 said *inference
and constraints were one row and are now one row less*; this is the rest of
it. What the row was for turned out to be a diagnostic, and moving a
diagnostic is what landed.

## What it does not do

- It does not check the generic's body against the category. AP 6.7.3.10.2 is
  unchanged and NOTE 9 of the clause states the limit.
- It does not admit a user-written category, a conjunction of categories, or a
  category on a result type.
- It does not reach a schema's formal discriminants (AP 6.4.7.1).
- It does not change any emitted IR, any tuple, or any instantiation cache.

## Alternatives rejected

**A word-symbol, `constrained T: numeric`.** Reserving one would break
ADR-0140 for a feature that needs no position of its own: the two-token
juxtaposition `identifier type` is already unwritable in a parameter-form, so
there is nothing to buy.

**Required identifiers for the four names.** §6.2.2.10 puts a required
identifier in the region enclosing the program, which takes the spelling away
from every program that does not shadow it — for four common English words, to
buy nothing: the names are only ever read in one position, and a spelling
check there is what the position is for. `tests/dialect/generic_constraints.pas`
would have had to be written differently under this alternative, which is why
it declares all four as ordinary names.

**`equatable` as `not IsAffine`.** Measured and rejected above: it admits
records and arrays, which have no `=` at all, so the constraint would pass the
call and the body would fail — the exact shape the feature removes.

**Checking the body abstractly against the category.** That is a different
feature and a much larger one: it needs the body read once with `T` as an
opaque type admitting only the category's operators, which is a second type
system for the generic's block and a second set of diagnostics. AP 6.7.3.10.2
would have to be rewritten rather than left alone, and the per-tuple reading
would still be needed for everything the abstract reading could not decide.
Nothing has asked, and the diagnostic — which is all the roadmap row ever
wanted — is had without it.

**Reporting the constraint failure inside the generic, beside the operator
error.** That is what happens today and is the thing being replaced. The call
is where the mistake is: the body is correct for the types it was meant for.

## What fails without the change

Every claim above has a case, and each was checked by mutating the source:

| Mutation | Case that caught it |
| --- | --- |
| the written form's check removed | `generic_constraint_errors`, `badsema-generics` |
| the inferred form's check removed | `generic_constraint_errors`, `badsema-generics` |
| the `argument N` tail dropped | `generic_constraint_errors`, `badsema-generics`, `spec-dialect_typeparam` |
| the determining actual's position not recorded | `generic_constraint_errors`, `badsema-generics` |
| any spelling accepted as a category | `badparse-type-param-category`, `spec-dialect_typeparam` |
| `IsEquatable` weakened to `not IsAffine` | `generic_constraint_errors`, `badsema-generics`, `predicate-kinds`, `dump-predicates` |
| `IsOrdered` loses the string-types | `generic_constraints`, `predicate-kinds`, `dump-predicates` |
| the dump stops naming the category | `dump-typeparam` |
| `tcNone` stops admitting everything | ten of the eleven `generic_*` cases |
