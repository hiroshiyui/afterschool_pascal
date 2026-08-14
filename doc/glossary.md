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
keyword tables in the Pascal source will read `'begin       '`.

**String type.** Under ISO 7185, `packed array [1..n] of char` and nothing
else. A string literal is given that type in Sema rather than one of its own, so
`write`, assignment, comparison and argument passing need no literal-shaped
special case (ADR-0017); a one-character literal is a `char`. Under
`--std=extended` §6.4.3.3 adds two more — a *variable-string* `string(n)` and
the *canonical-string-type* every value has on its way into one — and a literal
then belongs to all of them (ADR-0051).

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

**Standard (`--std`).** Which language a source is written in: `iso7185`, the
default, or `extended` for ISO/IEC 10206:1991. Not a feature switch — the two
are not nested, because Extended Pascal reserves word-symbols (`otherwise`,
`value`, `only`, …) that a valid ISO 7185 program may use as ordinary
identifiers, and `selfhost/compiler.pas` does. The directory a test lives in
says which language it is in, and the stage-1 compiler is told through a file
because ISO 7185 gives a program no other channel (ADR-0033).

**Schema.** ISO/IEC 10206:1991 §6.4.7's mapping from discriminant tuples to
types: `type vector(n: integer) = array [1..n] of real`. Not a type — nothing
possesses it and it has no values — so `SymKind::Schema` is a kind of its own,
and a schema keeps its *syntax* (`Symbol::schemaBody`) rather than a resolved
type, because it has none until a tuple arrives (ADR-0039).

**Discriminant.** One of a schema's formal parameters, and the value a produced
type was made with. `v.n` reads it, and where it is not a compile-time constant
it is a `SymKind::Disc` symbol with storage inside the descriptor of whatever
it belongs to (ADR-0040, ADR-0041).

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
nothing depends on how a struct is passed (ADR-0040).

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
program parameter that named itself (ADR-0052).

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
nothing (NOTE 6 permits that).

**Otherwise-part.** The default arm of a case statement, which ISO 7185 does
not have and ISO/IEC 10206:1991 does. It is *what the default block of the
switch holds*: without one that block traps, which is ISO 7185's rule that a
selector matching no label is an error (ADR-0018).

## The pipeline

**Stage.** One of Lexer → Parser → Sema → CodeGen → PassBuilder → TargetMachine
→ link. Each bails before the next if `Diagnostics::hasErrors()`.

**Sema.** Semantic analysis: scopes, name resolution, type rules, type-denoter
resolution, constant folding. Owns the type arena `types_`.

**Annotated tree.** The contract between Sema and CodeGen (ADR-0008): Sema
leaves every `Expr::type` non-null and every `VarRef::sym` resolved. CodeGen
therefore never inspects names, never re-derives types, and reports no
user-facing errors. On an error path Sema still assigns a placeholder type
rather than null, so codegen cannot crash on a half-checked tree.

**`ParseAbort`.** The only exception in the codebase, thrown when the parser
cannot make progress. Sema and the lexer instead accumulate into `Diagnostics`,
so one run reports many errors.

**`NK` / `as<T>()`.** The node-kind tag and the checked downcast that replace
C++ RTTI in the AST. Each node declares `static constexpr NK NodeKind`. Two
reasons: Debian's LLVM is built without RTTI, and the eventual Pascal-hosted
compiler has no `dynamic_cast` — a tag plus a variant record is what it will use
(ADR-0005).

**Textual IR.** `--emit-llvm`. Not a debugging aid but the backend that survives
the rewrite: a compiler written in Pascal cannot call LLVM's C++ API (ADR-0006).

**Runtime.** `runtime/pasrt.c`, linked as `libpasrt.a`. Holds anything not
expressible in IR — formatted output, `pas_runtime_error`, `pas_new`/
`pas_dispose`, `pas_str_compare`. In its formatting entry points `width < 0` and
`prec < 0` mean "not given" (ADR-0007).

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

**Lowering model (`lowering.py`).** A model of `codegen.cpp`, maintained with
it. A drifted model keeps passing and proves nothing — when a lowering changes,
the model changes in the same commit.

**`MUST_HOLD` / `KNOWN_GAP`.** A rule's expected verdict. A `KNOWN_GAP` that
starts holding *fails the build*, because it means the compiler was fixed and
the catalogue is now describing a compiler that no longer exists.

**Full vs bounded.** A rule proved at 32 bits holds for every machine integer;
a bounded rule is checked at narrower widths where the full query does not
solve. Twenty-five of the twenty-nine rules are full.

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
question, rather than either against a recorded expectation. `difftest.sh` did
that for this compiler and the C++ one it was ported from, diffing their dumps
over every Pascal source in the tree; a golden pins a port to whatever it did
the day it was written, where two implementations say "these two agree"
(ADR-0022 to ADR-0024).

**It no longer exists.** ADR-0085 retired stage 0, and with it the second
implementation. The term is kept here because most of this project's findings
are described in terms of it — "difftest caught it" appears throughout the
records — and because what it could catch and goldens cannot is the sharpest
thing to know about the oracles that remain.

**AST dump / Sema dump.** `--dump-ast` is the parse tree as one node per line,
taken *before Sema*, with `@line:col` printed only where the tree actually
records a position. `--dump-sema` is the same tree through the same walker,
plus what Sema alone knows: the frame layouts, the type of every expression,
the frame slot every name resolved to, and every record's field and variant
numbering. `--dump-all` writes both with the token stream, in three sections,
and is what the differential test compares. `src/astdump.cpp` is the
specification of the format and `selfhost/compiler.pas` reproduces it.

**Torture file.** `selfhost/torture.pas` — deliberately not a valid program,
carrying the lexical error paths and corner cases that valid test programs
never reach. It exists because real programs are valid by construction, so
without it the error paths would never be compared. `selfhost/badparse/` is the
parser's equivalent, and it is a *directory* because the parser stops at its
first error, so one file can carry only one message.

**Behavioural test (of a port).** What replaces a differential test when the
two implementations cannot produce comparable output. `selfhost/irtest.sh`
compiles every case in `tests/` with the Pascal compiler, links the IR with
`clang`, runs it, and compares against the *same* `.out`/`.err` the C++ compiler
is held to. LLVM's own printer is not a specification, so the assembler text of
two backends cannot be diffed; their programs' behaviour can (ADR-0025).

**Fixed point.** Stage 2 equals stage 3 — the compiler built by a
C++-built compiler and the compiler built by a Pascal-built one are the same.
Compared as IR rather than as binaries, because IR is what the Pascal compiler
emits. Checked by `selfhost/irtest.sh` under `ctest`, together with the golden
suite, because a compiler that reproduced itself and nothing else would pass the
comparison alone.

**Coverage gap.** A branch the corpus never reaches, which a differential test
cannot compare and will silently report as agreement. Found by mutating the
Pascal source and noticing nothing goes red — which is how the missing tab
(ADR-0022), the entirely uncompared parser diagnostics (ADR-0023), three Sema
rules (ADR-0024) and five code-generation rules (ADR-0025) were all discovered.
Count what the corpus reaches; do not assume it.

**Sibling list.** What a `std::vector<...Ptr>` in `ast.h` becomes in
`selfhost/compiler.pas`: every node carries `next`, and a list is a head pointer
plus a tail for appending. Cheaper than a growable array, and every walker
reads these strictly in order anyway (ADR-0023).

**Globbed at configure time.** Cases are registered by a `file(GLOB)` in
`CMakeLists.txt`, so adding a `.pas`/`.out` pair requires re-running `cmake`. A
green bar that never ran the new case is not a green bar.

## The bootstrap

**Stage 0 / 1 / 2 / 3.** The classic three-stage build. Stage 0 is the C++
compiler in this repository; stage 1 is what it produces from the Pascal source;
stages 2 and 3 are that source compiled by its own output, and must be
identical. They now are. See [roadmap.md](roadmap.md).

**Bootstrap constraint.** A design choice made to keep the C++ source
translatable into Pascal — no RTTI in the AST, textual IR as a supported output,
plain structs and explicit control flow over template or exception machinery.
Most of the odd-looking decisions here are one of these, and each ADR says what
it costs.
