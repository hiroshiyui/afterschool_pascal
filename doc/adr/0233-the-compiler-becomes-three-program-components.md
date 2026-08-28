# 233. The compiler becomes three program-components

Date: 2026-08-28

## Status

Proposed. It is the only record in this tree that is not Accepted, which is
deliberate: ADR-0001 asks for the record *while the alternatives are still
live*, and the expensive half of this change is a decision about
`seed/pascalc.ll` that cannot be taken back once a release ships it. Nothing
below is implemented.

It supersedes no record. It **narrows ADR-0024**, which made the compiler one
source file because neither standard had an include mechanism — a reason that
stopped being true at ADR-0053 and has been an unpaid debt since.

## Context

`selfhost/compiler.pas` is 36 104 lines and is the whole compiler. ADR-0024
decided that in the bootstrap, when it was forced: there was no include
mechanism, so a second file would have needed its own copy of everything below
it, and by Sema that would have been three copies of the lexer. ADR-0053 gave
the language modules and separate translation and ADR-0079 gave it §6.13's
program-components, so the constraint has not existed for a long time.
`doc/roadmap.md` has carried the split as an open proposal across two releases
and version 3 did not take it.

The roadmap gives two reasons for wanting it. **One of them is false**, and
finding that out is most of what this record is for.

### What the split would buy: one blind-spot row, closed by construction

`doc/sop.md` §7 records that **nothing links a component on its own and checks
the result**. Every harness here compiles a *program*, and a §6.13 component is
only ever one input to that — so a component that assembles to a valid but
incomplete module passes the compiler, passes LLVM's parser, and fails in the
linker, in a different command, about a name no source spells.

That is not hypothetical. It is exactly how AP 6.7.3.10's instantiation bodies
came to be emitted in one of `RunCodeGen`'s two arms (ADR-0212, ADR-0216): the
loop naming their frame types was shared and the loop emitting their bodies was
not, so a module-only translation was internally consistent and missing a
function. What caught it was a `.components` case that happened to write that
combination — and the row's sharpest sentence is why it took so long: *the
corpus had a program importing a generic and a module declaring one, and no
module importing one.*

The row closes when the combinations stop depending on somebody thinking of
them. If the compiler's own build is a chain of components, then **every build**
translates a module on its own, translates a module that imports another, and
links the result. The build becomes the test, and it runs on every commit rather
than when a case is written.

### What the split would *not* buy: the fixed buffers

The roadmap says the one-file constraint is an unpaid debt whose interest is
`poolMax` and `tokMax`, sized so the compiler can hold its own source, and that
"components make the problem structural instead of watched". **Measured, that is
wrong.**

`--import` re-tokenises the entire imported file. A module of 2 011 lines whose
interface is four lines costs

| | tokens | pool |
| --- | --- | --- |
| compiled on its own | 12 043 | 54 578 |
| read as an `--import` | 12 065 | 12 640 |

The token array pays for the whole file either way. So the unit that imports the
rest pays for the whole tree again, plus its own, and the peak is unchanged;
across a build the total re-tokenisation rises with the number of components
rather than falling.

**And it cannot be fixed by making the import read only the interface**, which
is the obvious answer. AP 6.7.3.10 produces an instantiation in the translation
that *named the types*, so for an imported module that is the client — the
client needs the generic's body, not its interface. `doc/sop.md` §7 carries both
halves of this already (*a generic instantiated by two translations is
translated into both*, and *a generic body may call only what its clients can
reach*). An interface-only import is a change to how generics are translated,
not a change to the reader.

The headroom the roadmap treats as pressing is also not pressing:

```
pool   693850 of 1000000     30.6% free
tokens 171968 of  300000     42.7% free
```

`buffer-headroom` (ADR-0126, ADR-0148) is doing its job. The two historical
overflows were at smaller constants. Nothing here is close.

### What the shape of the file already decided

Two facts settle the design question the roadmap left open — *what is the split
along?*

**Pascal makes the answer readable off the source.** A call to a
later-defined routine requires a `forward`, so the forward declarations are the
*complete* list of back-edges in source order. There are 66, and **all 66 are
inside one stage**. The longest reaches 13 646 lines and is Sema calling itself
(`CheckBlock`, forward at 9291, defined at 22937). Nothing forwards from CodeGen
into Sema or from Sema into the parser. The file order is therefore already a
topological order of lexer → parser/AST → types → Sema → CodeGen, and has been
all along.

**Sema is the knot and must not be cut.** It is roughly 16 000 of the 36 104
lines and holds 38 of the 66 forwards. Any split that tries to divide it is a
different and much larger change.

### Two things that constrain the cut

**The driver cannot move out of the program.** The compiler reads its command
line through §6.7.6.8's `binding(argk).name` over declared program-parameters
(ADR-0081). A module may declare a bindable module-parameter — the compiler
accepts it — and it is bound to nothing, which §6.11.1's NOTE 6 permits.
Probed end to end, one argument passed:

```
program sees: [HELLO-ARG]
module  sees: []
```

So `ParseArgs`, `Compile` and everything that reads an argument stay in the
program-block.

**Everything else is expressible.** A module can export a mutable variable and a
mutually recursive pointer-and-record pair, be translated separately, and be
linked by naming both `.ll` files to `clang` — probed, because the compiler's
179 top-level globals and its AST type are what a cut has to carry across an
interface, and a cut that could not carry them would not be worth designing.

## Decision

**Split `selfhost/compiler.pas` into three program-components, not five, and
take the split for the linking reason alone.**

```
ApTypes    the shared data: token kinds, the AST's node kinds and its variant
           record, the type and symbol records, and the routines that are
           already shared between Sema and CodeGen because a second copy would
           drift (WriteTypeName, WriteOrdinalName).      — imports nothing

ApFront    lexer, parser, Sema.                          — imports ApTypes

pascalc    CodeGen and the driver.                       — imports both
```

Three, because three is the smallest number that makes **every build** exercise
the shapes §7's row is about: a module translated alone (`ApTypes`), a module
that imports another (`ApFront`), and a program that imports both. Two would
give the first and the third and not the second, which is the one the corpus was
missing when ADR-0212's defect got through. Five would divide Sema, and Sema is
the knot.

The cut follows the DAG the 66 forwards already prove is there. No forward
crosses a proposed boundary, so no mutual recursion has to be broken to make it
legal — which is the whole reason this is a three-day change and not a
three-month one.

**`seed/pascalc.ll` becomes three files.** This is the irreversible half and the
reason the record exists before the work. The seed is a *working compiler in
IR*; if the compiler is three translation units, the seed is three modules, and
CMake links them. Linking them into one file first with `llvm-link` is rejected
below.

**The buffer constants stay where they are, and `buffer-headroom` keeps
watching them.** This change does not lower the peak and the record should not
be read as having addressed it.

## Consequences

- **`doc/sop.md` §7's linking row closes by construction**, for the combinations
  the compiler's own structure uses. It does not close for combinations the
  compiler does not use — a module exporting a schema, a generic across a
  component boundary — and the row narrows rather than going.
- **Four harnesses and CMake learn a build order**: `seed/refresh.sh`,
  `selfhost/irtest.sh`, `selfhost/producttest.sh` and `seed/ddc.sh`. Each
  currently names one source and one artefact.
- **`seed/README.md`'s provenance story covers three artefacts**, including the
  target lock. Stale there is worse than stale anywhere else, because it is what
  a reader consults before trusting a binary.
- **The 179 globals in one var-part are partitioned**, and the ones more than one
  component touches become exported module variables. This is the bulk of the
  mechanical work and the place a mistake is silent: a global assigned to the
  wrong component still compiles.
- **Translation gets slower**, by the re-tokenisation measured above. Say so in
  the commit rather than discovering it in CI.
- **A new failure mode arrives**: a component translated against a stale
  interface. It is a link error today and stays one; what changes is that the
  build can produce it.
- **ADR-0024's "one source file" sentence stops being true**, and it is quoted
  in `CLAUDE.md`, `doc/developer-guide.md` and `doc/glossary.md`. All three move
  with the change.
- **`--dump-*` and the goldens are unaffected**: the dumps are per translation
  unit and `tests/dumps/` compiles single files.

## Alternatives rejected

**Do nothing.** Defensible until this record, because the roadmap's stated
motivation was the buffers and that motivation is false. What is left is one
blind-spot row, and it is one that has already cost a real defect. Rejected on
that, and only that.

**Five components — lexer, parser, types, Sema, CodeGen.** The obvious cut, and
the one the roadmap sketches. It buys nothing the three-way cut does not: the
row closes at three. It costs two more artefacts in the seed, two more edges in
every harness's build order, and it puts a boundary either side of Sema without
dividing it, so the largest file stays the largest file. Reconsider only if a
second reason appears.

**Split Sema.** Rejected for now. 38 of the 66 forwards are inside it and one
reaches 13 646 lines; every one of those is a back-edge a boundary would have to
break, which means either a mutual-import (which §6.13 does not have) or a
redesign of how scopes, type resolution and constant folding call each other.
That is a different record.

**Keep one seed by linking the three modules with `llvm-link`.** Tempting: the
seed stays one artefact and `seed/README.md` barely changes. Rejected because
ADR-0085's claim is that the documented build needs **nothing of LLVM's** beyond
`clang` as an assembler and linker, and `llvm-link` is a second LLVM tool in the
one path that must work on a machine with no LLVM installed. Narrowing that
claim to save a file in `seed/` is the wrong trade, and it is the same shape as
the end-banner temptation `doc/sop.md` §7 row 41 warns about — making a
constraint smaller so a change fits inside it.

**Make `--import` read only the interface, and keep one file.** This is the
change the buffer argument actually wants, and it is unavailable: AP 6.7.3.10
instantiates a generic in the client's translation, so the client needs bodies.
It becomes available only alongside a linkage scheme for instantiations shared
across translations — which `doc/sop.md` §7 already registers as a decision
rather than an oversight. If that record is ever written, this one should be
re-read: with interface-only imports, five components would cost less than three
do now.
