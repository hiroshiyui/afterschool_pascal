# 315. Methods and traits, without inheritance

Date: 2026-09-03

## Status

**Proposed**, 2026-09-03. **Nothing is implemented.** This is the first record
in this tree whose status is not *Accepted*, and the reason is that it was
asked for as a design: the shape is to be argued before any code exists. Read
it as a proposal with its costs measured, not as a decision taken.

Where it is agreed, it lands as three increments with a record apiece (see
*Staging*), and this record's status becomes *Superseded* by the first of them.

**No clause number is spelled here on purpose.** The clauses these constructs
would take do not exist, and `clause-citations` (ADR-0164) cannot tell a
proposal from a claim — it refused this record until the two numbers came out.
Where they would go is said by naming the clause they follow: the impl-declaration
after AP 6.7.8, the trait-type after AP 6.4.17. Writing the numbers down would
have meant an entry in `tests/checks/nonexistent_clauses.txt` that somebody has
to remember to remove on the day the clause is written, and the placement is
the only information the number carried.

## Context

**The library already pays for the absence of this, and the price is
countable.**

**139 of 486 exported names repeat their own module's noun** — `JsonMember`,
`StreamOpenWrite`, `NetListen`, `TlsConnect`, `MapPut`. That is not a style: it
is forced. §6.11.2 puts every imported name into one scope, so two modules may
not export one spelling, and ADR-0298's `export-unique` gate refuses a
collision outright. ADR-0306 renamed four example programs' worth of them
(`Listen` → `NetListen`, `List` → `ListDir`, `OpenWrite` →
`StreamOpenWrite`). **The prefix is a receiver, spelled by hand, at every
declaration and every call site.**

**Where the property belongs to a type, the caller carries it instead.** The
generic map takes it as two routines, on every call:

    MapPut(m, 'k', 1, StrHash, StrEq)
    MapGet(m, 'k', 0, StrHash, StrEq)

There are **14 routine-valued parameters** across `lib/passort.pas` and
`lib/dialect/pascontainer.pas`, and **30 call sites** threading `StrHash,
StrEq` through. Every one of them is answering *what is this type's hash* and
*when are two of them equal* — questions about the key type, asked of the
caller because there is nowhere on the type to put the answer. `PasSort` has
the same shape for ordering, and `pasmap.pas` gave up and hardcoded a hash for
a string.

ADR-0109's test for a feature is not "a standard has it" — none governs this
language — but *does a program someone would actually write today need it*.
Both measurements above are that test answered by this project's own library.

**Why Rust's model and not Object Pascal's.** The dialect family has classes:
Turbo Pascal, Delphi and Free Pascal all have `object`/`class` with
inheritance, virtual methods and constructors. That is the obvious borrowing
and it is the wrong one here, for four reasons that are all about what this
language already decided:

- **ADR-0017 makes structured types name-equivalent** — two are the same only
  when they are the same object. Inheritance needs a subtype relation, which is
  a second compatibility rule beside `Assignable`, and ADR-0058's sentence is
  that a permission granted in a shared predicate leaks to every caller.
  ADR-0146's gate exists because that has cost three times.
- **A virtual method table in the record changes every record's layout**, and
  `foreign-layout` (ADR-0185) exists to assert that a record declared here has
  the layout the C struct it claims to be has. Composition keeps that true by
  construction.
- **ADR-0201's aliasing rules are written for values, handles and owned
  pointers**, and the one second name the language admits is a `var` parameter
  for the duration of a call. Inheritance's `Self`-typed references are exactly
  the escaping alias it has never had. Traits need no such thing.
- **A constructor protocol is a second way for a variable to come into
  existence**, beside a declaration and `new`, and AP 6.4.12.2 spent a record
  deciding that a handle has exactly one.

Rust's model asks for none of that: a struct with fields, routines *implemented
for* a type, and traits for polymorphism. The record layout does not move, the
compatibility rule does not move, and nothing gains a second name.

## Decision (proposed)

### 1. `impl` gives a type its own routines — the clause after AP 6.7.8

    impl-declaration = 'impl' type-identifier ';' routine-declaration+ 'end' ';' .

    type Point = record x, y: integer end;

    impl Point;
      function Length(protected var self: Point): real;
      begin
        Length := sqrt(self.x * self.x + self.y * self.y)
      end;

      procedure Shift(var self: Point; dx, dy: integer);
      begin
        self.x := self.x + dx;
        self.y := self.y + dy
      end;
    end;

**The spelling reserves no word-symbol**, which is ADR-0140's requirement and
is `task`'s route exactly (ADR-0268). A declaration-part admits only `label`,
`const`, `type`, `var`, `procedure`, `function` and `begin`, every one of them
a word-symbol, so an identifier in that position is already a syntax error in
both standards and the dialect may spell what it likes with one. `impl;`,
`impl(x)` and `impl := 3` all stay what a program that declared `impl` meant.

### 2. The receiver is an ordinary first parameter, and this is a finding

Rust's three receiver forms map onto three parameter forms the language already
has, exactly:

| Rust | Afterschool Pascal | Clause |
| --- | --- | --- |
| `self` | a value parameter, `self: T` | §6.7.3.1 |
| `&self` | `protected var self: T` | §6.7.3.1, ADR-0046 |
| `&mut self` | `var self: T` | §6.7.3.1 |

Nothing is invented. `protected var` is a borrow that cannot be written
through and does not copy, which is what `&self` is; a `var` parameter is a
borrow that can, which is `&mut self`; a value parameter is a move-or-copy,
which is `self`. **`self` is not a keyword** — it is a parameter name, and a
program may call it anything. The first parameter's type being the impl's is
what makes the call form below mean what it means.

### 3. `x.M(a)` means `M(x, a)`, and the spelling is free

The parser cannot tell a method call from a field selection, and Sema can,
because it can look the name up — ADR-0044, ADR-0053, ADR-0066, ADR-0071 and
ADR-0087's recurring answer, met a seventh time.

**It is free because no field can be a routine.** There is no procedural
*type* in this language: §6.7.3.1's procedural parameter is the only place a
routine is a value (ADR-0030), and `record f: procedure (x: integer) end` is
refused with *expected a type, found 'procedure'*. So `x.f(a)` is meaningful
for no `f` today, and the position is available with nothing taken away. Had
the language ever had a procedural type in a record, this spelling would have
been spent.

A type may not have a field and a method of one name — refused where the impl
is checked, not at the call.

### 4. A method's name lives in its type's scope

Which is the answer to the 139 prefixes. `JsonMember`, `MapPut` and
`StreamWriteLine` become `doc.Member`, `m.Put` and `s.WriteLine`, and two
modules may each have a `Put` because neither name is in the scope §6.11.2
merges. **A method is not an exported name**; what a module exports is the
*type*, and its methods travel with it. `export-unique`'s denominator does not
change and its rule is untouched.

It also frees a required identifier's spelling: a method may be called `Length`
or `Read` without shadowing anything, the name being resolved in the type's
scope and never in the one enclosing the program (§6.2.2.10).

### 5. `trait` and `impl … for` — the clause after AP 6.4.17

    trait-declaration = 'trait' identifier ';' routine-heading+ 'end' ';' .

    trait Ord;
      function Compare(protected var self: Self;
                       protected var other: Self): integer;
    end;

    impl Ord for Point;
      function Compare;
      begin Compare := self.x - other.x end;
    end;

`Self` is the implementing type, bound in the trait's own scope — a
type-identifier, as a schema's discriminant is a constant identifier in its
(§6.4.7), and not a new kind of thing. `for` is a word-symbol used in a
position `impl` has already made the dialect's.

**Where an impl may be written is not a choice.** It must stand in the
program-component that declared the type, or the one that declared the trait.
Rust calls that the orphan rule and argues for it; here it falls out of
separate translation: ADR-0079 makes an interface a module-heading and *what is
not written there cannot be reached*, so an impl in a third component could not
be found by anyone. The rule needs no clause of its own beyond saying so.

### 6. Dispatch — static first, and dynamic only where ownership has an answer

**Static.** A type parameter may carry a bound, in the slot where `T: type`
stands today (ADR-0254, ADR-0304):

    procedure Sort(T: Ord; var v: Vec(T));
    procedure MapPut(K: Hash + Eq; V: type; var m: Map(K, V); key: K; val: V);

`T: type` remains the unconstrained form and `T: Ord` the constrained one, so
the position is unchanged and inference (ADR-0304's prefix rule) applies
unaltered. This is what retires the 14 routine-valued parameters and the 30
call sites.

**Dynamic.** `dyn Ord` is a type-denoter — two juxtaposed identifiers, a
syntax error today, so the spelling is available. Its value is **two words**,
the data's address and the vtable's, and that puts it in a company this
compiler already keeps: a procedural parameter's code-and-link pair (ADR-0030),
a schematic formal's address-and-discriminants (ADR-0040), a string's
pointer-and-length (ADR-0051), `complex`'s two doubles (ADR-0049), a variable
string value parameter (ADR-0115) and a slice's address-and-count (ADR-0125).
**Nothing that is two words may depend on how a struct is passed**, so a
`dyn T` travels as two arguments and the textual backend needs no opinion about
the C ABI.

What is *not* proposed is a `dyn T` anywhere the language cannot say who owns
the value. Permitted:

- `owned ^dyn Ord` — Rust's `Box<dyn Trait>`, and the existing owned-pointer
  machinery answers every question about it (ADR-0181, ADR-0182);
- a `var` or `protected var` parameter of a `dyn` type — a borrow for the
  duration of the call, which is the one second name ADR-0201 admits.

Refused, for now: a `dyn` variable, field or array element. Each would be a
reference outliving a call, and the language has no way to say how long. That
is the same boundary ADR-0201 drew and this record does not move it.

## Staging

Three increments, each landable and useful alone:

| Increment | What it adds | Why it can stand alone |
| --- | --- | --- |
| **A. Methods** | the impl-declaration, the receiver rule, `x.M(a)`, the type's own scope | Retires the 139 prefixes. No new representation, no new compatibility rule, no vtable — a method is an ordinary routine and CodeGen is untouched |
| **B. Traits, static** | the trait-type, `impl … for`, `Self`, and `T: Trait` bounds | Retires the 14 routine parameters and 30 call sites. Dispatch is resolved at instantiation, so still no vtable and still no new lowering |
| **C. `dyn`** | the trait object, as two words, in the two positions above | The only increment that adds a representation, a global the emitter must name, and an indirect call `verify/` has no rule for |

A is the prerequisite for B and B for C, and the ordering is also from cheapest
evidence to dearest: A can be proved by rewriting one library module against
it, B by rewriting `MapPut`'s call sites, and C needs a program that holds a
heterogeneous collection, which this tree does not yet have.

## What this does not do

**No inheritance, and that is the whole of the borrowing.** No base types, no
overriding, no `Self`-typed field, no protocol for construction. A type gains
routines and satisfies traits; it never *is* another type.

**No operator overloading.** `Ord` gives `Compare` and not `<`. The language
has no overloading anywhere, `export-unique` depends on it, and making
operators the exception would be a second dispatch mechanism beside the one
above.

**No automatic dereference.** Rust's `p.method()` on a `Box<T>` reaches
through; here it is `p^.M(a)`. The language has no implicit dereference and
this record does not add one — `nil` traps because a dereference is written
(ADR-0019).

**No impl for a type this component did not declare**, so no `impl integer`
and no adding a method to another module's type. §5 above says why it is not a
choice.

**No associated constants or associated types** in a trait, only routine
headings. Both are real and neither is needed by the two measurements in
*Context*.

**Nothing about concurrency changes.** A method is a routine, so AP 6.7.8.2's
rule — a task may name only its own variables — reaches a method exactly as it
reaches any other routine, with the same non-transitivity `doc/sop.md` §7
records.

## Alternatives rejected

**Object Pascal's `class`.** Argued in *Context*: it moves ADR-0017's
compatibility rule, every record's layout, and ADR-0201's aliasing model, and
each of those is load-bearing with a gate over it.

**Declaring a method by qualifying its name** — `procedure Point.Shift(...)`,
which is what Delphi and Free Pascal write and which needs no new spelling at
all, a procedure-heading taking an identifier and then `(` or `;` so a dot
there is free. Rejected because it cannot express `impl Trait for Type`: there
is nowhere in a qualified heading to say *which trait this satisfies*. Two
spellings for one thing is worse than one that covers both, and the block also
groups an impl's routines where a reader looks for them.

**A procedural type, so that a record could hold its methods** — the
hand-rolled vtable, which is how C does this. Rejected because it is the thing
that would have taken `x.M(a)` away, and because a record holding a routine and
a static link is a second name for the activation it closed over, which is
ADR-0030's reason for the pair being parameters only.

**A trait bound as a separate clause** (`procedure Sort(T: type) where T: Ord`)
rather than in the type parameter's own slot. Rejected as a second position for
one fact; `T: Ord` reads as the constraint it is and leaves ADR-0304's
inference untouched.

**Methods on a record only, rather than on any type the component declared.**
Rejected because the measurements in *Context* include `Vec`, `Map` and
`Stream`, which are a schema, a schema and a handle — the prefixes are not a
record's problem.

## Consequences, and the costs to expect

**A is nearly free and B is not.** A method is an ordinary routine with an
ordinary first parameter, so Sema gains a scope per type and a resolution rule,
and CodeGen gains nothing: `x.M(a)` emits the call `M` already emits. B needs
the bound checked at instantiation, which is where ADR-0254's machinery already
resolves a type argument, and a trait's headings compared against an impl's —
§6.6.3.6's congruity, which the compiler already computes.

**C is where the real cost is**, and it should be entered with that named. A
vtable is the first *global* the emitter would write per (type, trait) pair, so
`ReservedForeignName` gains a spelling to refuse and `foreign-reserved` will
say so on the first run (ADR-0144's own history). An indirect call through a
vtable is a lowering `verify/lowering.py` has no rule for. And the seed:
ADR-0085's constraint is that a feature must be expressible in what `seed/*.ll`
accepts or the seed is refreshed first — A and B emit nothing new, C emits a
new global form.

**The library rewrite is the evidence, and it is also the risk.** Retiring 139
prefixes means renaming 139 exported names, which is every call site in
`examples/`, `tests/dialect/` and `lsp/`. ADR-0306 renamed four and found that
the *rename* was the easy half. It should be staged per module, and the old
names cannot be kept as aliases, `export-unique` refusing two spellings of one
thing.

**One thing to watch that no gate will see.** `x.M(a)` resolving in the type's
scope means a reader can no longer find a routine's declaration by searching
for its name — `Put` will be declared in a dozen impls. `--dump-uses` already
answers *where is this name declared* with a defining-point (ADR-0239), and the
language server reads it, so the tooling is ready; a person with `grep` is not.
That is the cost of the feature working as intended, and it is worth writing
down before rather than after.
