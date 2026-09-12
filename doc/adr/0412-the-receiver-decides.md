# ADR-0412: The receiver decides

## Status

Accepted.

## Context

ADR-0315 asked for a proof: rewrite a library module with methods and judge
the rest of the library from the result. ADR-0410 and ADR-0411 built the
construct — a method-designator, and an implementation that crosses a
program-component — and both were designed against probes and a corpus of
purpose-written cases.

`lib/dialect/pasjson.pas` is the first real client. It has two types with
routines, `JsonChars` and `JsonPtr`, and they have three names in common:
`Free`, `Len` and `At`. That is not an accident of naming — it is the whole
reason ADR-0315 wanted methods, since §6.11.2 puts every exported name into
one scope and two exported `Free`s cannot coexist. The rewrite is therefore
the first thing in this tree to ask the question the feature exists to
answer.

It did not compile, and the reasons were four defects, none of which any gate
here could have seen. Each needed two types in one translation with routines
of one name, or a receiver spelled in a way the purpose-written cases had not
used. `doc/sop.md` §4a's claim — that a library is the cheapest enumerator of
a feature's surface — held for the fourth time, and this is the largest
margin it has had.

## Decision

**In a method-designator, the receiver decides which routine is called, and a
name in scope does not shadow it** (AP 6.7.10.2, amended).

AP 6.7.10.2 identified a routine from the first actual-parameter's type only
where the identifier had *no defining-point in force*. That gate belongs to
the bare spelling, `Len(x)`, which has nothing but the scope to go on. A
method-designator supplies its receiver explicitly, so there is no second
reading for the scope to settle, and reading the scope first made
`v^.text.Free` inside `impl JsonPtr`'s own `Free` bind to `JsonPtr`'s —
refused on its argument type, one line after the routine it should have
called. NOTE 17's "`p.Shift(1)` and `Shift(p, 1)` denote the same call" is
narrowed by NOTE 10a accordingly: they denote the same call where the
identifier is free, and where it is not, the bare form means the routine in
scope and the dot form means the method.

Three further defects are fixed with it, and they are separate claims:

- **A parameterless method statement takes any receiver.** `b.Free` was a
  statement and `v^.text.Free` and `arr[1].Free` were `expected ':=' in an
  assignment`. Landed separately as `f3ae443`; AP 6.7.10.4 gained the
  sentence and NOTE 16a.
- **A method chain is a statement.** `a.M(x).N(y)` is one designator, and the
  qualified-name path consumed `a.M(x)` and left `.N(y)` belonging to
  nothing. The path now declines when a selector follows the argument list,
  which `CallThenSelector` answers from the token stream.
- **A designator's type is found in a variant part.** `QuietTypeOf` carried
  its own copy of `FindField` that walked the fixed field list only, so a
  field declared in a variant part answered no type. ApTypes already owns
  that question and descends into the variants; the copy is deleted rather
  than corrected.

And one that is not about methods at all, found because methods are not
exported:

- **§6.9.4 b) reaches a formal produced from a schema.** Passing a variable
  to a `var` formal whose type comes from a schema was neither recorded as a
  threat nor refused when the actual was protected. One missing call with two
  faces: `protected var s: string` could be handed to another routine's
  `var s: string` and written through there, with 6.5.1's protection defeated
  and no diagnostic; and ADR-0283's advice, which is supposed to be *exact*,
  was given for parameters that could not take the word. It survived because
  the advice is never given about an **exported** routine (ADR-0283) and every
  routine of that shape in this tree was exported — until a method, which is
  exported by nothing (AP 6.7.10.5).

## Consequences

`lib/dialect/pasjson.pas` exports 25 names where it exported 50. Twenty-four
routines became methods of `JsonChars` (8) and `JsonPtr` (16);
`JsonCharsAddLine` is `AddText`, `JsonIntegerOr` is `IntegerOr`, and
`JsonKindOf` is `Kind`. What stays exported is what has no receiver to be
selected from: the types, the three bounds, the seven constructors and the
two entry points.

**Chaining is what made the clients better rather than merely shorter.**
`JsonIntegerOr(JsonMember(p, 'line'), -1)` is `p.Member('line').IntegerOr(-1)`,
and the dominant idiom of an LSP server is exactly that shape: 540 call sites
across eleven sources, 332 of them in `lsp/pasls.pas`. A method-designator
may be the receiver of another, which AP 6.7.10.4 now says — it had always
worked and the clause had not admitted it, a function-designator being no
variable-access.

**What this does not do.** A `var` receiver still cannot be a chain's
non-initial link: `p.Grown.Move(1)` is refused because §6.6.3.3 wants a
variable-access for a variable parameter and a function-access is not one.
That is the language's own rule and not this construct's, and
`methods_errors.pas` pins it. A statement that begins with a *call* rather
than a name — `f(x).g(y);` — is still not parsed; the general designator path
starts from a name, and no client needed it.

**A statement's receiver is checked before its arguments**, which is new:
CheckCall and CheckStmt run `CheckExpr` on the first actual to learn the type
that selects, and mark it with ADR-0254's `nChecked` so `CheckArguments`
leaves it alone. The guard against it having been checked already was written
and removed: nothing reaches those two sites with a checked receiver, and a
branch no case takes is a branch this tree does not keep.

**Evidence.** Four mutations, each naming what it kills:

| mutation | case |
| --- | --- |
| `QuietTypeOf` walks the fixed fields again | `methods` (`unknown function 'len'`), `dyn_positions` (the owner-vs-owned hint degrades to `unknown procedure`) |
| `CheckCall` ignores the receiver type | `methods` (`argument 1 of 'len' is cell, but the value is link`), and nine library cases |
| the qualified-name path takes a chain | `methods`, `lsp-server` |
| the schema threat arm removed | `badsema-protected_schema` (both faces), `schema_param`, `lib_unicode`, `warning-free` |

`tests/extended/schema_param.warn` loses two lines and
`tests/dialect/lib_unicode.warn` is deleted. Both were advice that does not
compile, which is ADR-0283's own claim and ADR-0300's own defect shape; each
was checked by taking the advice and watching the compiler refuse it.

`lib-coverage`'s denominator moves 3563 → 3562 with `uncovered` unchanged at
386: statement coverage keys on the line, and re-indenting the module's
routines into implementation-declarations put two compound statements on one
line. No statement was lost, and the statement set corresponds one for one.

## Alternatives rejected

**Rename the methods so they do not collide** — `Release` on one type and
`Free` on the other. It compiles and it abandons the feature: ADR-0315's
claim is precisely that two types may each have a `Free`, and a library that
has to avoid the collision has gained nothing over the prefix it was trying
to drop.

**Let the scope win and require the bare spelling inside an implementation** —
`Into(v^.text, s)` rather than `v^.text.Into(s)`. That does not work either:
the bare form is 6.7.10.2's *gated* lookup, so the enclosing routine's name
shadows it there too, and there would be no spelling at all for the call.

**Make a function-designator a variable-access so chains need no rule.** It
would reach further than this — §6.6.3.3, §6.5.1 and §6.9.4 are all written
about variable-accesses — and it would make `p.Grown.Move(1)` legal, which
binds a `var` parameter to a value nothing owns.
