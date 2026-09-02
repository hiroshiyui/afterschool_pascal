# Glossary

Terms this repository uses in a specific sense. Three kinds are mixed together
on purpose, because reading the code means holding all three at once: words ISO
7185 defines, words invented here for a design decision, and words borrowed from
LLVM that mean something narrower here than in general.

Where a term is governed by an architecture decision, the record is cited; where
it names a thing in the source, the file is.

## The language

**Ordinal type.** A type whose values are countable and ordered: `integer`,
`char`, `boolean`, an enumeration, or a subrange of any of those. Only an
ordinal type may index an array, drive a `for` loop, select a `case` arm, or
answer `ord`/`succ`/`pred`. Real is not ordinal, which is why `for x := 1.0`
is rejected rather than rounded.

**Enumerated type.** `(red, green, blue)` — a type that declares its own
constants into the enclosing scope. Two enumerated types are never compatible
however alike they look, so `assignable` requires identity for them
(ADR-0018).

**Subrange.** `lo..hi` over an ordinal *host* type. `Type::base()` returns the
host, and every predicate — `isInteger()`, `isChar()`, `isNumeric()` — answers
for the base. That is what let subranges reach arithmetic, `write`, indexing and
parameter passing with no edits: `1..9` *is* an integer everywhere except where
its bounds matter, and code needing the distinction asks `isSubrange()`.

**Host type.** The ordinal type a subrange is carved from. `1..9`'s host is
`integer`; `green..blue`'s host is the enumeration.

**Set type.** `set of T` for an ordinal T, whose values are the subsets of T's
(ISO 7185 §6.4.3.4). Every set here is one 256-bit word — a bit per possible
member — so T's values must lie in 0..255 and `set of integer` is refused. That
makes a set a *value*: it is neither structured nor a memory type, and is
assigned, compared and passed exactly as an integer is (ADR-0028).

**Set base type.** The T of a `set of T`. Set compatibility is decided on it
*structurally*, which is ISO 7185 §6.4.6's own departure from the name
equivalence §6.4.5 gives every other structured type — two separately written
`set of char` denoters are compatible, where two `array [1..3] of integer`
denoters are not.

**Empty set** (`[]`). A set with no base type, and a value of every set type —
the set-valued counterpart of `nil`. Unlike `nil` it is not an exception to
name equivalence, because §6.4.6 was already structural for sets.

**Memory type** (`isMemory()`). Anything whose value never occupies a register
and is reached through its address: arrays, records, and files. Distinct from
`isStructured()`, which is arrays and records only — that predicate is what
*grants a whole-variable copy*, and a file must never have one. Keeping the two
apart is what makes assignment, comparison and value parameters refuse files
without a special case at each site (ADR-0021).

**Packed.** ISO's request that a structured type be stored compactly. Here it
changes nothing about layout — it is honoured only where the standard makes it
*semantic*: `packed array [1..n] of char` is the string type, and two of them
compare and assign by length rather than by identity.

**`str` (the bootstrap string).** Not a language feature: the
`record len; ch: packed array [1..n] of char end` convention the stage-1 source
uses, since ISO has no string type (ADR-0012). Its one cost is that a literal
must be *padded* to a fixed width to be passed to a procedure, which is why the
keyword tables in the Pascal source read `'begin       '`. The compiler is
written in Extended Pascal now (ADR-0082), so it *could* spell one
`string(255)`, and in one place it must: `nameStr` is a file name, and
§6.4.3.4's `BindingType.name` is a variable-string, so everything reaching
`bind` is one (ADR-0052). Everything else is still the record.

**String type.** ISO 7185 has one, `packed array [1..n] of char`. A string
literal is given that type in Sema rather than one of its own, so `write`,
assignment, comparison and argument passing need no literal-shaped special case
(ADR-0017); a one-character literal is a `char`. ISO/IEC 10206:1991 §6.4.3.3
adds two more, and this language has all three — a *variable-string* `string(n)`
and the *canonical-string-type* every value has on its way into one — with a
literal belonging to all of them (ADR-0051).

**Designator.** The syntactic form that denotes a variable: a name, possibly
followed by subscripts, field selections and dereferences — `a[i].next^.value`.
In the AST it is a `VarRef` with `IndexExpr`, `FieldExpr` and `DerefExpr`
wrapped around it, and in codegen it is whatever `emitAddress` accepts.

**Type-denoter.** ISO's term for the syntax that *describes* a type, as opposed
to an identifier that names one. Represented by `TypeExpr`, deliberately not an
`Expr`. A declaration group shares one denoter, which is what makes
`a, b: array [1..3] of integer` the same type rather than two alike ones.

**Name equivalence.** ISO 7185 §6.4.5: two structured types are the same only
when one type identifier denotes both. Implemented as pointer identity —
`assignable` compares `Type *` with `==` — so two separately written
`array [1..3] of integer` are different types (ADR-0017).

**Region.** §6.2.2's unit of scope, and not the same thing as a block: a
record-type is one, an interface is one, and a with-statement over a schematic
type is one. What makes the word worth having is §6.2.2.4, which extends a
defining-point's scope over "that region and all regions enclosed by it" — so a
field-identifier's spelling denotes the *field* anywhere inside the record's
type-denoter, including places a type name would otherwise be looked up
(ADR-0098, ADR-0112), and the required identifiers live in a region enclosing
the program so that `type integer = char` can take effect (ADR-0097).

**Domain.** What a pointer points *at*. ISO writes it as a type *identifier*,
not a denoter, and allows it to name a type defined later in the same type part
— the language's only forward reference, and what makes a recursive type
possible (ADR-0019).

**Buffer variable.** `f^` — the component of a file the file is positioned at,
and one character of lookahead for a text file. ISO defines `get`, `put` and
`f^` as the primitives and *derives* `read` and `write` from them; this
compiler keeps that structure rather than providing only the derived forms,
because lookahead is what a lexer is written against (ADR-0021). It shares
`NK::Deref` with pointer dereference, and the two part on the base type. On a
`file of T` it is a whole T, allocated by the runtime so that its size and
alignment are T's, and it is a designator like any other — `f^.field` and
`f^[i]` index it (ADR-0031).

**Text file, and `file of T`.** ISO 7185 §6.4.3.5 makes `text` a required type
of its own, and it is *not* `file of char`: only a text has lines, so only a
text has `readln`, `writeln`, `eoln`, and an external representation of a
number to parse. Everything else about the two is identical, including the
component size, and one flag on the type says which is which. On a `file of T`,
`read` and `write` mean what §6.6.5.2 derives them to mean — `v := f^; get(f)`
and `f^ := e; put(f)` — so they carry one component of the file's own type and
take no field width (ADR-0031).

**Program parameter.** A name in `program P(...)`, which §6.10 requires the
block to declare as a variable. These are the program's only connection to
anything outside it: `input` and `output` are the standard streams, and this
compiler binds every other one that possesses a file-type to a command-line
argument in the order written — a choice the standard leaves open. A
program-parameter that is *not* a file is permitted too (§6.10 makes its
binding implementation-dependent rather than restricting the list to files),
and this compiler binds it to nothing: it is an ordinary variable of the
program block and takes no argument, so the file parameters keep the positions
they would have had without it.

**Internal (scratch) file.** A file variable that is *not* a program
parameter, so it has no external name: a temporary the program writes and reads
back within the run.

**Variant part.** The `case tag: T of` arm list at the end of a record. Modelled
as one block of shared storage with each arm a struct laid over it; the block's
element type carries the alignment (`[k x i64]`, not `[n x i8]`) or a `real`
inside a variant would be misaligned (ADR-0018).

**Label.** An unsigned integer of at most four digits (ISO 7185 §6.1.6) that a
block declares and that marks one of its statements. A label is a *number*, not
a name, so it lives in no scope: two blocks may each declare label 1 and each
means its own (ADR-0029).

**Non-local `goto`.** A goto to a label of an *enclosing* block, which leaves
the block rather than a statement and so abandons every activation between the
two. The target's activation record carries a jump record: its prologue arms it
and calls `_setjmp`, and the goto reaches it through the static chain. §6.8.1
allows it only to a label at the top level of that block's statement part —
the one place an activation that is still alive can be re-entered. The jump
closes the files of every block it abandons, which those blocks' own exits
would have done had they run (ADR-0032).

**Statement path.** The chain of statements containing a given one. §6.8.1 lets
a `goto` leave a structured statement but not enter one, and stated over paths
that rule is exactly "the label's path is a prefix of the goto's" — which
settles jumping out of a loop nest, into a loop, and between two sibling loops
with one comparison. A block's statement part is deliberately not on the path:
it is the outermost statement-sequence rather than a statement containing one,
which is what makes "at the top level of the block" mean "an empty path".

**Procedural / functional parameter.** A parameter that *is* a procedure or a
function (§6.6.3.1), written as a heading rather than as a type. There is no
procedure type in the type part, so no variable can have one and the heading is
the only place the type is spelled.

**Congruity.** ISO 7185 §6.6.3.6's relation between two parameter lists: the
same number of parameters, each pair passed the same way and of the same type,
and congruous again where a parameter is itself procedural. It stands in for
type identity, since a procedural parameter has no type to compare.

**Procedure value.** What a procedural parameter holds: the pair `{code, static
link}`, where the link is the frame of the block the procedure was *declared*
in. It occupies one frame slot but travels as two arguments, and never exists
as a single value (ADR-0030).

**Error condition.** ISO's term for a situation a conforming program must not
reach — integer overflow, a subscript outside its bounds, a value stored outside
a subrange, a set carrying a member outside its base type, a `case` matching no
label, a dereference of `nil`. This compiler
*traps*: it stops the program with a message rather than wrapping, reading past
the array, or producing an arbitrary value (ADR-0014, ADR-0015).

**Standard (`--std`).** *Historical.* Until ADR-0232 this named which of three
languages a source was written in: `iso7185`, `extended` for
ISO/IEC 10206:1991, or `afterschool` for the dialect. The first two were **not
nested**, because Extended Pascal reserves word-symbols (`otherwise`, `value`,
`only`, …) that a valid ISO 7185 program may use as ordinary identifiers. There
is one language now and no option, comment or sidecar that selects one; the
word survives only in these records and in `tools/pascalcc`, which accepts
`--std=` and ignores it so a version 2 build script still runs (ADR-0033,
ADR-0117, ADR-0232).

**Schema.** ISO/IEC 10206:1991 §6.4.7's mapping from discriminant tuples to
types: `type vector(n: integer) = array [1..n] of real`. Not a type — nothing
possesses it and it has no values — so `SymKind::Schema` is a kind of its own,
and a schema keeps its *syntax* (`Symbol::schemaBody`) rather than a resolved
type, because it has none until a tuple arrives (ADR-0039).

**Discriminant.** One of a schema's formal parameters, and the value a produced
type was made with. `v.n` reads it, and where it is not a compile-time constant
it is a `SymKind::Disc` symbol with storage inside the descriptor of whatever
it belongs to (ADR-0040, ADR-0041). Since ADR-0113 a **subrange bound** that is
not a constant becomes one too, so `var a: array [1..m] of real` is the
descriptor machinery with no schema written anywhere.

**Anonymous schema.** What a variable with such a bound is given: a schema
symbol with the discriminants its bounds became, **no name and no body**
(ADR-0113). Both absences are load-bearing. Nothing looks it up, the program
having written no name — and a name invented for it would be named in a
diagnostic about a program that does not contain it, which is ADR-0074's
mistake. Nothing produces a second type from it either, since the only type it
describes is that variable's, so there is no syntax to keep. The empty spelling
is what selects §6.4.7's domain message for an array rather than for a schema.

**Production.** The act of turning a schema and a tuple into a type, and the
type that results. §6.4.8 makes one tuple one type however many times it is
written, which is why productions are interned on (schema, tuple) — that intern
table is the one place a type's identity is decided by something other than the
denoter that built it.

**Generic type.** A type produced from a schema with the discriminants bound to
*symbols* rather than to values, so one compiled body serves every tuple. What a
schematic formal parameter has; `isGeneric()` asks.

**Descriptor.** What a schematic formal parameter's frame slot holds: the
address of the actual, then its tuple, one field per discriminant. Like a
procedure value it never exists as an LLVM aggregate — the parts are stored and
loaded through their own getelementptrs and travel as separate arguments, so
nothing depends on how a struct is passed (ADR-0040). A **variable** whose
type-denoter has a non-constant bound has one too, filled in when the block is
entered rather than by a caller (ADR-0113).

**Protected.** ISO/IEC 10206:1991 §6.7.3.1's parameter qualifier and §6.11.2's
export qualifier. A Sema-only flag: it says nothing about how the argument
travels — a protected `var` parameter is still an address — and CodeGen never
reads it. What it means is §6.5.1's rule about the *body*: no statement may
threaten a variable-access closest-containing the name (ADR-0046).

**Initial state.** §6.6's `value` specifier. It belongs to the *type-denoter*
(§6.4.1) and not to the declaration, which is why a type-name hands it on to
every variable of that type, and why it is recorded on the type *symbol* rather
than on the shared `Type` (ADR-0048).

**Type-inquiry.** §6.4.9's `type of x` — the type the named variable already
possesses, handed back rather than built again. Building an alike type would not
do: name equivalence would make the two unassignable (ADR-0047).

**Bindable / binding.** §6.4.1's `bindable` and §6.7.5.6's `bind`. The external
entity here is a *file name*, which is the one thing ISO 7185 could not express:
§6.10 binds the program parameters before the program starts. A bound file is a
program parameter that named itself (ADR-0052). Every file variable is bindable
in this dialect, the word or not (AP 6.5.1, ADR-0299); the word still matters
on a non-file, where `bind` refuses it by design.

**Complex.** §6.4.2.2 e) makes it a *simple* type, so it is a value — assigned
with a store, passed in a register, returned from a function — and none of the
by-address machinery applies. Represented as `<2 x double>` rather than a
struct, so nothing depends on how a struct is passed (ADR-0049).

**Interface.** ISO/IEC 10206:1991 §6.11.2's named set of constituents, which an
`export` part introduces and an `import` specification reaches. §6.2.2.2 makes
it a region that "shall not be a part of the program text", so it is a *table*
and not a scope: exporting a name changes nothing about how visible it is inside
the module (ADR-0053).

**Constituent.** One name an interface makes available. It carries the spelling
an importer writes — which either end may rename — and whether it is
`protected`, because that belongs to the export and not to the module's own
declaration of the variable.

**Supplies.** §6.2.2.13's relation: A supplies B when B imports an interface A
exports, transitively. It decides which modules are activated at all, and
§6.2.3.6 orders their commencements by it — an order this compiler gets for
free from the text, since §6.2.2.9 already puts a module-heading before
everything importing its interface.

**Module-parameter.** A name in `module m(...)`. `input` and `output` there are
§6.11.4.2's way to make the required text file accessible *in that module*;
every other spelling must be a variable the module declares, and is bound to
nothing (NOTE 6 permits that). That last clause is why this compiler's driver
is in its program-component and not in a module: `binding(argk).name` is
argument *k* only for a *program*-parameter (ADR-0081, ADR-0233).

**Program-component.** §6.13's unit of separate translation: a sequence of
module-declarations, at most one of which is the main-program-declaration. The
compiler is three of them — `selfhost/aptypes.pas`, `selfhost/apfront.pas`,
`selfhost/compiler.pas`, listed in dependency order by
`selfhost/compiler.components` — and a translation of one names the sources of
the ones before it with `--import`, there being no artefact for an interface
other than the module-heading itself (ADR-0079, ADR-0233).

**Otherwise-part.** The default arm of a case statement, which ISO 7185 does
not have and ISO/IEC 10206:1991 does. It is *what the default block of the
switch holds*: without one that block traps, which is ISO 7185's rule that a
selector matching no label is an error (ADR-0018).

**Completer.** ISO/IEC 10206:1991's name for the last, unlabelled arm of three
different constructs, each spelled `otherwise`: the **variant-part-completer**
(§6.4.3.3), the **case-statement-completer** (§6.9.3.5) and the
**array-value-completer** (§6.8.7.2). None of the three is a construct of its
own — the first is a variant whose case-constant-list is empty (ADR-0034), the
third is the component every element not written over gets, and it is filled in
*first* for that reason (ADR-0061). The variant one discharges §6.4.3.3's
requirement that the labels cover the tag-type and never the requirement that
no label fall outside it (ADR-0096). The case one has **no node**, so §6.8.1's
rule about where a `goto` may land — it is one of the three things holding a
statement-sequence — carries a flag rather than asking a node's kind
(ADR-0094).

## The dialect

Everything here is what this language has and no standard does. The
distinction used to be enforced by a mode — an extension reachable inside
`iso7185` or `extended` was a defect unless `doc/implementation-defined.md`
listed it — and ADR-0232 removed the modes, so what keeps it honest now is the
containment claim below and `tests/dialect/inherits_extended.pas`, which is the
program that says every Extended Pascal construct still means what the standard
says (ADR-0109, ADR-0117, ADR-0232).

**Dialect.** The language, and the one place a feature neither standard has may
land. It **contains** Extended Pascal, which was the whole of ADR-0117's
argument for adding it as a third mode rather than a fourth language: `stdKind`
was `(stdIso7185, stdExtended, stdAfterschool)` and the *order* was the
containment, so every site asking "does this mode have Extended Pascal?" asked
`HasExtended(s)`, which was `s >= stdExtended` at 40 sites. Writing
`langStd = stdExtended` instead switched Extended Pascal off for the dialect
while almost every case still passed, which is why the predicate existed.
ADR-0232 removed the type, the predicate and all 40 comparisons: there is
nothing left to get wrong, which is the strongest form the containment has
taken.
`tests/dialect/inherits_extended.pas` pins the containment (ADR-0117).

**`int64`.** A 64-bit integer, and a **numeric** type rather than an ordinal
one: it has no `succ`, indexes no array, and is the base type of no set. It is
carried as its source text all the way into the IR, as a real literal is, for
the same reason — this compiler's own integers are 32 bits, so it has no value
of the type to convert to and back from. `-maxint64..maxint64`, symmetric like
`integer`'s range and for the same reason (ADR-0128).

**Optional (`?T`).** A type whose values are those of T plus an absent one,
spelled `nil`. `o^` is the only way to a value and it **traps** when there is
none — a run-time check localised to where the source writes `^`, not a
flow-sensitive narrowing. What the type gives is that a T which is not
optional can never be absent. `^` is deliberately the spelling: it is the
dereference every other trap of this shape already uses (ADR-0123).

**Slice (`array of T`).** A view of part of an array: an **address and a
count**, travelling as two arguments. It is a formal parameter's type and
nothing else — never a variable's, never a component's — so the extent always
arrives with the actual and the bounds a callee checks against are the ones it
was handed. `a[i..j]` is §6.5.6's substring designator reused, so the parser
was untouched; only the base's type tells the two apart (ADR-0125).

**Foreign function (`external`).** A procedure or function whose body is code
this compiler did not emit, declared with a directive in the position `forward`
occupies — so it reserves no word-symbol in any mode. The foreign name is a
string literal and there is no default, this lexer case-folding identifiers
where a linker matches exactly (ADR-0121).

**Foreign boundary.** Which types may cross it, and it is narrow on purpose.
An argument may be an `integer`, a `real`, an `int64`, a `string` (as C's
`const char *`), or a **slice** — the pair `read`, `write`, `recv` and `send`
already take (ADR-0129). A result may be one of the scalars, or an *optional*
string, which is how a `char *` that may be null comes back: the copy is made
at the call site, so nothing the program holds is a foreign pointer
(ADR-0122, ADR-0123).

**`pas_` and `pasx_`.** Two surfaces of one runtime. `pas_` is what the
compiler emits calls to, and `ReservedForeignName` refuses the whole prefix as
a foreign name — LLVM rejects a redeclared global, so a collision would be an
error about a file nobody wrote. `pasx_` is what a Pascal program may bind to
with `external`, and it exists because C specifies `errno` as a *macro*: it has
no linker symbol at all, so reading it needs a routine (ADR-0131).

**Result record.** The dialect's error convention, and a variant record whose
tag cannot lie: `case ok: boolean of true: (payload); false: (code: ErrorCode)`.
A write to a field **activates** that variant and a read of an inactive one
traps, so a caller that ignores `ok` and reads the payload is stopped rather
than handed rubbish (ADR-0118, ADR-0120).

**Affine, and owned.** A type is *affine* when its values cannot be copied and
are released when the variable holding one ceases to exist. Three kinds are:
the file variable, which has been affine since ISO 7185 §6.4.6 a) without the
word being used (ADR-0151); the dialect's **handle**, a foreign address with
the routine that releases it written into the type (ADR-0174); and its **owned
pointer**, `owned ^T`, which owns the variable `new` created and disposes it
recursively (ADR-0181). `IsAffine` is the predicate `ContainsFile` asks, and it
is what refuses assignment, comparison, value parameters and function results
for all three at once. **`IsOwned` is a different question** — whether a value
travels by address — and an owned pointer is not in it, its value being one
word. The two were one name until ADR-0181 needed them apart.

**The library's two layers.** `lib/` holds the modules that are ordinary
ISO/IEC 10206:1991 and would compile under another Extended Pascal — eight of
them, and the layer that could exist before the dialect did. `lib/dialect/` holds the thirteen that need the
dialect, and they divide nine to three: nine **bindings**, each a module that
exports Pascal and keeps its `external` declarations to itself, and three that
need only the dialect's own features — `PasError`, `PasParse`, and `PasList`,
which is built on the owned pointer and needs no binding at all (ADR-0114,
ADR-0120, ADR-0181).

**Text-type (`utf8(n)`).** What a program holds when it means the *characters*
rather than the octets: a value whose bytes are well-formed UTF-8 in normal
form C, with a capacity in **bytes** and elements that are grapheme clusters.
It is a type **beside** ISO/IEC 10206:1991 §6.4.3.3's strings and not a
replacement for them — `char` stays one byte and `string(n)` stays bytes,
because widening `char` would stop `set of char` compiling and break the
dialect's containment of Extended Pascal (ADR-0189, AP 6.4.15).

**Element.** One extended grapheme cluster — what a *reader* calls a character.
It is what `length` counts over a text and what `for g in t` yields, and it is
not a `char`: a cluster is a sequence of scalar values of unbounded length, so
it has no ordinal and the type of an element of a text is a text (AP 6.4.15.3).
A family emoji joined by zero-width joiners is one element of eighteen bytes.

**Scalar value.** A Unicode code point that is not a surrogate — the unit
*under* an element. The language has no view of them on purpose, three
sequences living in one text and a type offering all three having to say at
every operation which it meant; `PasUnicode` is where a program that needs
them goes (ADR-0193).

**Normal form C.** The composed form of ISO/IEC 10646, and the invariant every
text value satisfies. Normalising where a value is **constructed** rather than
where two are compared is what makes `=` byte equality and canonical
equivalence at once: `é` written as one code point and `é` written as `e` and a
combining acute are one value (ADR-0189, AP 6.4.15.2).

**Canonical-text-type.** The type `+` yields over texts — a text with **no
capacity**, as ISO/IEC 10206:1991 §6.8.3.6's canonical-string-type is a string
with none. What a join produces must fit any target, so it carries no capacity
to exceed and the store is where the fit is checked (ADR-0192, AP 6.4.15.7).

**Representation, against rules.** A text and a variable-string are *the same
representation* — a length and that many bytes — and almost none of the same
rules. `IsStringRep` asks the first question and `IsVarString` the second, and
using one where the other was meant is a defect: it has been three times, none
of them a case-statement and so none of them visible to `kind-exhaustive`
(ADR-0191, ADR-0193, ADR-0194).

**Move (`take`).** The one value an assignment to an affine variable admits
besides `nil`: `take(v)` empties `v` and yields what it held, so at no moment
do two variables hold one value. **The source is emptied before the target's
address is taken**, which turns `p^.next := take(p)` from a cycle nothing owns
into a nil dereference. It was an owned pointer's alone and was over-broad by
one kind: a **handle** is one word as an owned pointer is, so both move, while
a file variable is several storage units the processor holds and has no value
to stop holding (ADR-0182, ADR-0267, AP 6.4.12.7, AP 6.4.14.6).

**Borrow.** The only second name an owned value has: a `var` parameter bound
to `o^` for the duration of a call. It **cannot escape**, and by construction
rather than by a check — Pascal has no address-of operator and `new` is the
only producer of a pointer, so no pointer can ever name it. Unformable rather
than forbidden, which is stronger and free, and *silent* if a future feature
takes it away (ADR-0201, `doc/sop.md` §7).

**Fallible type (`T ! E`).** A value or the reason there is none: the result
record `lib/dialect/` used to write per payload type, now written by the
compiler with the field names fixed. It needed no new type — an ordinary
record with a flag on it — so the copy, the layout and ADR-0118's trap came
free and CodeGen was not touched. Its value side may be **affine**, and the
two arms are then laid *beside* one another rather than over one another,
because a memcpy over a live handle is a double free (ADR-0176, ADR-0256,
AP 6.4.13).

**Propagation (`try`).** `try(x)` yields a fallible value's payload or leaves
the enclosing function with its cause. A **required identifier** and not a
position, which is the finding rather than the feature: a factor may be a
variable-access, so `try (x)`, `try [x]`, `try + x`, `try.f` and `try^` all
mean something to a program that declared `try`. The rule that works for a
statement does not transfer to an expression (ADR-0178, AP 6.8.9).

**Armed statement (`defer`).** A statement written where a resource is
acquired and executed when the statement-sequence it stands in is completed,
or when the activation terminates. Zig's unit rather than Go's — per
*sequence* and not per activation — because a per-activation defer runs a
loop's `dispose(p)` once, with the last `p` (ADR-0175, AP 6.9.3.11).

**Factory.** A function of this program whose result is a handle, or a
fallible value whose payload is one. The value is built directly in the
variable the caller assigns it to, so there is no moment at which two names
identify one resource, and a factory calling another passes the destination on
and holds nothing itself. It is the one item on `doc/roadmap.md` where *ask
whether the address can be retired at the call* does not apply: a factory's
whole point is that the callee's answer outlives the call (ADR-0255, ADR-0256,
AP 6.4.12.6).

**Type parameter.** A schema discriminant that names a **type** rather than a
value, so `Vec(T: type; cap: integer)` is a container written once and a
client writes one line per element type. §6.4.7 interns a production per
distinct tuple, which is what makes a named production the same type as the
schema applied again. A parameter **may say what it needs** (ADR-0266); what
is still absent is a generic *routine* over one, which is why `lib/passort.pas`
sorts by `less(i, j)` and `swap(i, j)` and never sees an element (ADR-0209,
ADR-0266).

**Type-inquiry (`type of`).** Names a whole **variable-access** and denotes
its type, so a generic reads an element type off the container it was handed
instead of the caller naming a type the argument already knows. The substring
is the one access it must refuse. §6.4.9's object is a variable-*name* and no
more, so the wider form is the dialect's and not a conformance gap — a
distinction this project got wrong for a day (ADR-0214, ADR-0215).

**Task.** A second thread of control, and the one sentence left of the
aliasing fork ADR-0201 withdrew. `spawn P(a, b)` starts one; it takes only
**transferable** values and channels (AP 6.7.8.1), may name only its own
variables (AP 6.7.8.2), and every task a block spawned is **joined** before
that block releases anything — which is what makes *a borrow cannot outlive
the call* true again. Share-nothing, so there is no shared mutable state for a
memory model to be about. **The compiler is one thread and must stay so**, the
seed compiling it (ADR-0268).

**Channel.** A bounded queue, `channel [n] of T`, and **it is a handle**: no
copy, released where a file closes, and the only thing besides a transferable
value that may cross into a task. `send` blocks when it is full and `receive`
when it is empty; closing it lets a receiver drain what is in flight before it
reports the close (ADR-0268, AP 6.4.16).

**Transferable.** What may cross into a task or through a channel: a value
this language can *copy*, which is every type but the affine ones and the
schematic ones whose bounds a receiver could not know. It is the predicate
that keeps a task share-nothing, and it is why a task cannot yet be **given**
a socket — the move exists (ADR-0267) and the argument block does not use it
(ADR-0268, AP 6.4.16.3).

**Warning.** A diagnostic that is not an error: same format, same stream, same
exit status, and **the only difference is `errorSeen`**. There are four. Three
guards govern each and every one was learned by it failing — written only when
`warnOn`, which every `--dump` flag clears; only when nothing has been
reported, since a name that did not resolve records no use; and only for
`curFile = mainFile`, or a component is warned about once per importer. A test
case is held to them by a `.warn` sidecar in both directions, and this tree's
own sources by `warning-free` (ADR-0272, ADR-0286).

**Trivia.** A comment, recorded as a **position** and never as text: which
token it precedes, and where it began and ended in the source. That is all a
formatter needs and it costs the token table nothing, the words being sliced
back out of the source by whoever wants them (ADR-0279).

## The pipeline

**Stage.** One of Tokenize → ParseProgram → RunSema → RunCodeGen, each guarded
by `errorSeen` so that a stage which failed has nothing for the next one to
read. It used to end `→ PassBuilder → TargetMachine → link`; those were the C++
back end's, and since ADR-0085 the compiler stops at the IR. Assembling and
linking are outside it entirely, because no standard Pascal program can start
another (ADR-0009).

**Sema.** Semantic analysis: scopes, name resolution, type rules, type-denoter
resolution, constant folding. Owns the type arena `types_`.

**Trivia.** What the lexer consumes and does not turn into a token — here,
§6.1.8's comments. The word is the compiler-tooling one and not Pascal's; a
standard has no name for this because a standard has no reason to keep it. What
is recorded is a **position and never text**: a start, an end, and the index of
the token the comment stands before. Whatever wants the characters re-reads the
source, which is also the only way to recover an identifier's spelling, the
pool holding the folded one (ADR-0279).

**Warning.** A diagnostic that does not fail the compilation — `WarnAt` beside
`ErrorAt`, same format, same stream, same exit status, and **the only
difference is that it does not set `errorSeen`** (ADR-0272). Not "a lesser
error": the category is *this compiles and is probably not what was meant*, and
it did not exist here until a compiler that had implemented two standards
completely still had no way to say so.

**Husk.** What a parser node becomes when Sema has decided the construct is
something else. Five constructs the parser cannot tell apart and Sema can,
because it can look the name up — a qualified name against a field selection, a
variant-selector against a tag-type, a set-value against a subscript, a
schema's second name, a redefined `write` — and in each the real operands are
*moved out* into a field of the node the parser built, which every later pass
reads first. The tree is not rewritten: `checkExpr` takes a raw pointer and
cannot replace the node its parent holds (ADR-0044, ADR-0053, ADR-0066,
ADR-0071, ADR-0087).

**Annotated tree.** The contract between Sema and CodeGen (ADR-0008): Sema
leaves every `Expr::type` non-null and every `VarRef::sym` resolved. CodeGen
therefore never inspects names, never re-derives types, and reports no
user-facing errors. On an error path Sema still assigns a placeholder type
rather than null, so codegen cannot crash on a half-checked tree.

**`ParseAbort` / `aborted`.** What a parser that cannot make progress does. It
was the C++ codebase's only exception; in this compiler it is a flag every
production and loop tests, Pascal having no exceptions (ADR-0023). Sema and the
lexer instead accumulate into `Diagnostics`, so one run reports many errors.

**`NK` / `as<T>()`.** The node-kind tag and the checked downcast that replace
C++ RTTI in the AST. Each node declares `static constexpr NK NodeKind`. Two
reasons, and only the first was ever about C++: Debian's LLVM is built without
RTTI, and a Pascal-hosted compiler has no `dynamic_cast`. It has one now, and a
tag plus a variant record is exactly what it uses, so the port needed nothing
redesigned (ADR-0005).

**Textual IR.** The compiler's product, not a mode of it: `pascalc` writes a
`.ll` and stops, so there is no flag asking for one. `pascalcc`'s `--emit-llvm`
(`-S`) is the *driver* stopping there instead of going on to assemble and link.
It was the backend that had to survive the rewrite, because a compiler written
in Pascal cannot call LLVM's C++ API (ADR-0006); since ADR-0085 it is the only
one, which is what lets `seed/*.ll` build the tree.

**Runtime.** `runtime/pasrt.c`, linked as `libpasrt.a`. Holds anything not
expressible in IR — formatted output, `pas_runtime_error`, `pas_new`/
`pas_dispose`, `pas_str_compare`. In its formatting entry points `width < 0` and
`prec < 0` mean "not given" (ADR-0007).

**String arena.** Where a string value with no variable to live in is put —
what `+` produces, a char standing where a string does, and `date`/`time`. It
is a **stack**, and the runtime cannot see when a value dies, so CodeGen is
what says: `@pas_str_at` is read in every prologue and stored back at the end
of any statement that took storage (ADR-0111). `pas_str_at` is the one datum
the generated code shares with `runtime/pasrt.c` by name rather than through a
call. It was a **ring** until then and wrapped in silence, writing one live
value over another; both ways of exhausting it are reported now, which is
ADR-0110's rule, and the size is in `doc/implementation-defined.md` §6.

## Activation records

**Frame.** A struct holding one activation's storage. Field 0 is the static
link; locals, value parameters, `var` parameters and the function result are the
remaining fields, and `Symbol::frameVars` is the layout codegen consumes
(ADR-0016). A procedure's is alloca'd in its entry block; a **level-0** block's
— the program's, and every module's — is a *global*, because it has exactly one
activation and a module's must outlive the function that fills it in
(ADR-0053).

**Static link.** The pointer to the *enclosing block's* frame, held at field 0
so intermediate hops can load it without knowing the struct type at that level.
Calling a procedure passes the frame of the block the procedure was *declared*
in — for a recursive call that is the caller's parent, not the caller, which is
the one place this is easy to get subtly wrong. A level-1 procedure's link is
dead since ADR-0053 — nothing walks to level 0 any more, because a level-0
frame is named directly — but the prologue still writes it, so it appears in
the IR and is simply never read.

**Level.** Lexical nesting depth. The program body is level 0.

**`addressOf` / `frameAt` / `frameOf`.** The single path to a variable's
address: `frameOf(block)` answers with a level-0 block's global or else walks
the static-link chain, and `addressOf(sym)` asks for the frame of the symbol's
*owner* and then indexes. All variable access goes through it, so there is still
no separate global path — asking the owner rather than the level is what lets a
module reach the program's `output` and the program reach a module's variable,
neither of which is on the other's static chain (ADR-0053). A `var` parameter's
slot holds a pointer, which `addressOf` dereferences.

**`emitAddress` / `emitLoad` / `emitCopy`.** The structured-type equivalent.
`emitAddress` is the single path to a designator's address; `emitLoad` reads
through it, except that an array or record has no register form, so a designator
of one yields its *address* and assignment becomes a memcpy.

**`resultVar`.** The frame slot a function's result lives in. Assigning to the
function's own name writes it; *reading* the name is a recursive call
(§6.8.2.2), so there is no way to read a result back.

**`with` binding.** A hidden frame slot of kind `VarParam` holding the record's
address, so the designator is evaluated once (§6.8.3.10) and the binding is
per-invocation. A bare name that is a field of an open `with` resolves to that
binding plus `VarRef::withField`.

**`checkedArith` / `checkedForSubrange`.** The two families of emitted check.
The first wraps integer `+ - *` and `sqr`, which therefore carry no `nsw`. The
second is applied where a value *enters* a variable — assignment, value
parameter, both `for` bounds — and is a no-op for every non-subrange type, so
call sites need no conditional.

## Verification

**Rule.** One entry in `verify/rules.py`: an ISO property, a model of the
lowering, and a Z3 query asking whether any input makes them disagree.

**Specification (`iso.py`).** A statement of what the standard *requires of the
result*, never a computation of it. Writing `iso.py` so it computes the answer
the way the compiler does would make every proof circular and the circularity
invisible.

**Lowering model (`lowering.py`).** A model of the code generator, which is in
`selfhost/compiler.pas` — the program-component, since ADR-0233; it was written
against `codegen.cpp`, which ADR-0085 retired — maintained with it.
A drifted model keeps passing and proves nothing,
so when a lowering changes the model changes in the same commit. Nothing reads
the two against each other any more, which is why `--crosscheck` and the
`trap_*.pas` goldens are the whole of what ties the model to the compiler.

**`MUST_HOLD` / `KNOWN_GAP`.** A rule's expected verdict. A `KNOWN_GAP` that
starts holding *fails the build*, because it means the compiler was fixed and
the catalogue is now describing a compiler that no longer exists.

**Full vs bounded.** A rule proved at 32 bits holds for every machine integer;
a bounded rule is checked at narrower widths where the full query does not
solve — a symbolic division or multiplication over 32 bits, or a symbolic shift
over the 256 bits of a set. Most of the catalogue is full; `README.md` carries
the count, which is one place for it to move rather than three.

**Symbolic bounds.** Quantifying over an array's or an enumeration's bounds
rather than writing sampled ones in, so a rule says something about *every*
array. This is what caught the generalisation an integer-only `succ` rule could
not have.

**Cross-check.** The half of `verify.py` that compiles and runs real Pascal at
the adversarial points, at both `-O0` and `-O2`. A proof about a model of the
compiler is only worth what keeps it tied to the compiler.

**Negative rule.** A rule stating why a check is *unnecessary* —
`negation-cannot-overflow`, `accepted-index-selects-the-right-element`. These
are the ones that pay: the index rule failed on first run and made Sema reject
arrays spanning more than `maxint` values.

**Tautological rule.** One whose ISO condition *is* the emitted test — "the nil
check fires exactly when the pointer is nil". Deliberately not written: it would
pass at once, prove nothing, and dilute what "no known gaps" means. Pointers get
the cross-check and an AddressSanitizer run instead (ADR-0019).

## Build and test

**Golden test.** `tests/name.pas` plus `name.out`, the expected stdout of a
program that must compile and exit 0 (ADR-0011). An optional `name.in` is fed
to its standard input; without one stdin is `/dev/null`, so a reading program
sees end-of-file rather than hanging. Two writable scratch paths are always
passed as arguments.

**Expected-failure test.** `tests/name.pas` plus `name.err`, the expected
stderr of a program that is *supposed* to fail — rejected at compile time, or
stopped by a runtime check. A non-zero exit is then required. Source paths are
rewritten to `<source>`, so diagnostics can be pinned without depending on where
the checkout lives.

**Differential test.** Comparing two independent implementations of the same
question, rather than either against a recorded expectation. The term is
**live again in a different shape**: `fpc-differential` (ADR-0234) runs Free
Pascal over every case in `tests/` and `tests/extended/` that has a golden and
compares the answers, which is two *processors* where the entry below is about
two *front ends*. What that buys and what it cannot reach — nothing in
`tests/dialect/`, nobody else implementing this language — is in ADR-0234 and
in `tests/checks/fpc_disagreements.txt`, which records for each disagreement
which clause decides it and which way. The rest of this entry is history.
`difftest.sh` did that for this compiler and the reference front end in `src/`,
diffing their dumps over every Pascal source in the tree; a golden pins a port
to whatever it did the day it was written, where two implementations say "these
two agree" (ADR-0022 to ADR-0024).

**It went twice.** ADR-0085 retired stage 0 and the second implementation with
it; ADR-0108 brought it back as a front end — lexer, parser and Sema, no code
generator — which is the half a dump can compare anyway; and ADR-0232 retired
it for good, `src/` having been frozen at a conformance surface that no longer
exists. It covered **tokens, AST and Sema** and never the code generator, and
it could not contradict a *reading*, one author writing both sides — which is
exactly what a second processor written by strangers *can* do, and what
ADR-0234 was taken for. What replaces it for the **front end** is still
nothing: a dump has no second writer, and `doc/sop.md` §7 calls that the
largest blind spot on the page.

**AST dump / Sema dump.** `--dump-ast` is the parse tree as one node per line,
taken *before Sema*, with `@line:col` printed only where the tree actually
records a position. `--dump-sema` is the same tree through the same walker,
plus what Sema alone knows: the frame layouts, the type of every expression,
the frame slot every name resolved to, and every record's field and variant
numbering. `--dump-all` writes both with the token stream, in three sections.
The format was a *specification* while two implementations wrote it, and
**which of them specified it reversed twice**: the C++ defined it while it was
the compiler being ported from; ADR-0085 made the Pascal compiler the product,
so ADR-0108's returning front end was brought into line with it; and ADR-0232
left one writer, which makes the format a debugging aid and its goldens the
only thing holding it. `tests/dumps/` is that corpus (ADR-0103).

**Torture file.** `selfhost/torture.pas` — deliberately not a valid program,
carrying the lexical error paths and corner cases that valid test programs
never reach. It exists because real programs are valid by construction, so
without it the error paths would never be compared. `selfhost/badparse/` is the
parser's equivalent, and it is a *directory* because the parser stops at its
first error, so one file can carry only one message.

**Behavioural test (of a port).** What replaces a differential test when the
two implementations cannot produce comparable output. `selfhost/irtest.sh`
compiles every case in `tests/` with the Pascal compiler, links the IR with
`clang`, runs it, and compares against the *same* `.out`/`.err` every other
harness is held to. LLVM's own printer is not a specification, so the assembler
text of two backends cannot be diffed; their programs' behaviour can
(ADR-0025). It is the whole of what covers the code generator, which the
differential test never compared.

**Fixed point.** Stage 2 equals stage 3 — the compiler built by the seed and
the compiler built by *that* one are the same. Compared as IR rather than as
binaries, because IR is what the compiler emits. Checked by
`selfhost/irtest.sh` under `ctest`, together with the golden suite, because a
compiler that reproduced itself and nothing else would pass the comparison
alone. What the claim rests on never depended on which compiler started the
chain, which is why replacing stage 0 with a committed seed cost it nothing
(ADR-0085) — and what it *cannot* see is a miscompilation of the compiler,
both stages coming from one binary. `llc-second-backend` is what closes that.

**Coverage gap.** A branch the corpus never reaches, which a differential test
cannot compare and will silently report as agreement. Found by mutating the
Pascal source and noticing nothing goes red — which is how the missing tab
(ADR-0022), the entirely uncompared parser diagnostics (ADR-0023), three Sema
rules (ADR-0024) and five code-generation rules (ADR-0025) were all discovered.
Count what the corpus reaches; do not assume it.

**Sibling list.** What a `std::vector<...Ptr>` in `ast.h` becomes in
`selfhost/aptypes.pas`: every node carries `next`, and a list is a head pointer
plus a tail for appending. Cheaper than a growable array, and every walker
reads these strictly in order anyway (ADR-0023).

**Globbed at configure time.** Cases are registered by a `file(GLOB)` in
`CMakeLists.txt`, so adding a `.pas`/`.out` pair requires re-running `cmake`. A
green bar that never ran the new case is not a green bar.

## The bootstrap

**Stage 0 / 1 / 2 / 3.** The classic three-stage build, and it is finished.
Stage 0 *was* the C++ compiler in this repository and is retired (ADR-0085);
what starts the chain now is the committed seed under `seed/`, a working
compiler in IR. Stage 1 is what the seed produces from the compiler's three
program-components and is `build/bin/pascalc`; stages 2 and 3 are those sources
compiled by its own output, and every module must be identical. They are.
See [history.md](history.md#the-three-stage-build).

**Seed.** The committed artefact stage 0 became — 6.6 MB of IR that nobody
reads and that builds the compiler, which is a supply-chain surface by
construction. Refreshed at release tags rather than per commit, and
`seed/README.md` is what a reader consults before trusting it.

**Bootstrap constraint.** A design choice made to keep the C++ source
translatable into Pascal — no RTTI in the AST, textual IR as a supported output,
plain structs and explicit control flow over template or exception machinery.
Most of the odd-looking decisions here are one of these, and each ADR says what
it costs. Two of the three now constrain nothing and are kept because they
explain the shape the compiler's own sources have; the textual IR one got
*more* load-bearing, not less.
