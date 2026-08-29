# 244. An import that names no file

Date: 2026-08-29

## Status

Accepted, 2026-08-29.

It closes `README.md`'s standing gap — *there is no install location and no
resolution by name* — which [ADR-0238](0238-the-server-reads-the-build-description.md)
recorded as **sharper for having been worked around**: the language server
reads `.components` to find a file's imports, and said in as many words that
doing so does not close the gap, because a module says `import PasError;` in
its own source and nothing here turned that into a file.

## Context

`--import <file>` is how a program-block's other components reach a
translation, and it is a *path*. Three consequences followed and only the first
was ever written down.

A program outside this checkout names paths into it. `import PasError;` is
what the source says and `--import ../../lib/dialect/paserror.pas` is what the
command line has to say, once per component, in dependency order, with the
order worked out by whoever is typing. `lsp/pasls.pas` needs ten of them.

There was no install location. `tools/pascalcc` looked for the compiler at
`$root/build/bin/pascalc` and for the runtime at `$root/build/lib`, where
`$root` is the parent of the script's own directory — which is a checkout and
nothing else. An installed copy at `/usr/local/bin` would look for its compiler
in `/usr/local/build/bin`.

And every harness here drove the compiler *out of the build tree*, with
`PASCALC` and `AFTERSCHOOL_PASCAL_RUNTIME` saying which tree. That is exactly
the configuration an installed copy does not have, so "install it somewhere and
put it on `PATH`" was a claim no oracle in this repository made or could make.

The shape to aim at is not new. Turbo Pascal wrote a unit name in the source
and looked for the file on a list of directories a user configured, and no
Pascal since has done anything materially different.

## Decision

**An `import` naming an interface no `--import` supplied is looked for on a
search path**, and the compiler is what looks.

    <directory>/<interface name>.pas

folded as §6.1.2 folds every identifier, in three places and in this order:

1. **the directory the source being translated is in**, always and first;
2. each `--import-path <directory>`, in the order written;
3. each entry of **`AFTERSCHOOL_PASCAL_PATH`**, directories separated by `:`.

The first is what makes a checkout compile with no configuration — a program
and its modules written in one directory find each other. The third is what
makes an installed library reachable from anywhere without a flag, and is why
this compiler now reads an environment variable at all. The second sits between
them so a caller can override an installed module with one of its own, which is
the only reason it exists.

Eight things were decided rather than assumed.

**The compiler resolves, not the driver.** `tools/pascalcc` is a shell script,
and working out what a source imports there would mean reading Pascal outside
the compiler — the mistake [ADR-0229](0229-the-compiler-reports-its-own-dispatch.md),
[ADR-0230](0230-the-if-chain-half-moves-to-the-compiler.md) and
[ADR-0239](0239-the-compiler-answers-a-tools-question.md) each moved something
off, and a worse one in a shell script than in Python. Resolution is also
*transitive*, which means reading module headings recursively, and the compiler
is what reads module headings.

**The compiler reads `getenv`, and that is the one foreign name it binds.** A
program-parameter is a file (§6.5.1), so a compiler that must be told its
library path on every command line has not been installed anywhere. The
alternative was to have `pascalcc` translate the variable into flags, which
keeps the compiler pure and makes `pascalc` alone useless the moment it is
installed — and `pascalc` alone is what every harness here drives.

**The file is named after the interface, not the module.** An import writes an
interface name and nothing else, and §6.11.1 lets `module counter` export
`counting`. Nothing here opens a directory and reads headings to find out what
a file declares: the compiler would then be parsing every Pascal source in
every directory on the path to answer one question. So a module exporting an
interface under another name is reachable by `--import` and not by the search
path, and `tests/extended/components/counter.pas` is that case, left as it is
to keep the two roads honest.

**A name the search does not find is not an error.** It falls through and Sema
reports an interface nothing supplies, which is the diagnostic a program that
meant to pass `--import` wants to see, and it names the interface rather than a
file nobody wrote. This is also what keeps `import StandardOutput` — a required
interface and not a file — costing one failed lookup and no complaint.

**Post-order, and the recursion is the whole of the ordering.** §6.2.3.6
commences a supplying module before the one importing it, and Sema hands
CodeGen the module list in the order the activations must happen. So reading a
component parses its file, resolves what *that* file imports, reads those
first, and appends its own modules after them. `tests/extended/import_by_name.pas`
is a chain of three and its golden is written by two `to begin do` parts.

**Resolution had to move after the parse, and `ParseComponent` is the price.**
What a source imports is knowable only once it has been parsed, so a component
is now read *after* the answer about the main source is already sitting in the
parser's globals — and a bare `ParseProgram` would overwrite the program's own
heading, parameters and block with a module file's nils. `ParseComponent` saves
them in locals and puts them back, which also makes it nest: a component read
for another component's sake restores that one's answer in turn.

**`--dump-imports` is the other half, and it is a decision and not a
convenience.** Resolution gives the compiler an *interface*; something still
has to translate that file and link the result. The compiler writes the
components it read, one to a line in activation order, behind the word
`component` — in its own words, as `--dump-symbols` writes Pascal's words and
not LSP's numbers. `tools/pascalcc` is the caller, the second one after
`lsp/pasls.pas`, and the flag is the whole of the interface between the two
halves of this compiler.

**And the install layout is `pascalcc`'s to know.** It looks for `pascalc`
beside itself before it looks in a build tree, does the same for `libpasrt.a`,
and adds `<prefix>/lib/afterschool` and its `dialect` subdirectory to the
search path **only when `AFTERSCHOOL_PASCAL_PATH` says nothing** — a user who
sets that variable is describing their whole search path, and appending to it
would make an installed module shadow one of theirs by a rule they never wrote.
The compiler is *not* looked for on `PATH`: a `pascalcc` and a `pascalc` from
different releases would then be paired by whatever order a user's `PATH`
happens to have, and the pairing is the one thing that script is.

The library installs as **source**, because there is no compiled interface
artefact in this language and §6.11.1 is why: a module-heading *is* the
interface, written in Pascal. What is owed for having no second artefact to
keep in step is that every program translates the library modules it uses.

## Consequences

**`install-layout` is a new gate and it is the first oracle here that runs an
installed compiler.** It installs to a prefix, empties the environment of every
variable that could point back at the build tree, puts the prefix's `bin` on
`PATH`, and compiles a program importing two library modules from a third
directory. Four claims fail separately: the layout, `pascalc` found beside
`pascalcc`, `libpasrt.a` found the same way, and the library on the search
path. Two mutations were made and each was caught by the part it should be —
dropping the installed library gives four `no interface named` diagnostics, and
dropping the beside-itself lookup names `<prefix>/build/bin/pascalc`.

**It also asks the question the convention rests on**, once per module. The
search is `<directory>/<interface name>.pas` and nothing opens a file to find
out what it declares, so *a library module's file is named after the interface
it exports* is load-bearing and was checked by nothing at all: a module
renamed, or one exporting an interface under another name, would simply stop
being resolvable and every case in this tree would still pass. So the gate
compiles one program per installed module — `import <name>;` and an empty body,
25 of them — and it has to **compile** rather than merely resolve, because
resolving finds a file with the right name and only Sema knows whether that
file declares the interface. Renaming `PasMap`'s export is a mutation no other
part of this gate sees, `greet.pas` importing two other modules; this half
names it.

**Two new sidecars, read the same way by three harnesses.**
`name.importpath` names directories, one per line, relative to the case's own
directory; `name.importenv` holds the value of `AFTERSCHOOL_PASCAL_PATH`, with
`<dir>` standing for that directory. They are separate because they are
different claims — a flag is what one command line says and a variable is what
a machine was configured with, and only the second can hold an empty entry or a
trailing separator. `tests/run_test.sh`, `selfhost/irtest.sh` and
`tests/checks/coverage.py` all read them, and the third had to grow a per-job
*environment* to do it, which is a shape it did not have.

`tests/extended/import_by_name.pas` pins the flag and the transitivity;
`tests/extended/import_by_env.pas` pins the variable, and its sidecar carries
an empty entry and a trailing separator on purpose. `tests/dumps/imports.pas`
and `tests/dumps/dumpimports.pas` are `--dump-imports` in both directions, and
they resolve through the *source's own directory* — no flag and no variable, so
they are the zero-configuration case written down. The dumps harness had to
learn to rewrite the case's directory to `<dir>/`, which `tests/run_test.sh`
already did to a diagnostic: `--dump-imports` is the first dump that answers
with a path.

**Two statements are uncovered and the ratchet was regenerated for them.** The
`maxImports` report in `ReadImportsIn` fires when a *resolved* chain runs past
32 components, and no case here has 33 program-components. It is the same class
as the ten argument-error statements `parseargs` has carried in that file all
along.

**What this does not do.** There is still no compiled interface artefact and
no dependency freshness check: nothing notices that an object is older than the
heading it was built against, which §2.5 of `doc/implementation-defined.md`
already recorded and which resolution makes easier to meet, since the objects
are now built per program by `pascalcc` and thrown away. And the search reads
no directory: a file whose name is not its interface's is invisible to it, by
construction and not by omission.
