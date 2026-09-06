# ADR-0348: A project is a convenience over a file

Date: 2026-09-06

## Status

Accepted. Adds `new-project`/`new`, `build`, `run` and `test` to
`tools/pascalcc`, the `afterschool-pascal.toml` format, the `new-project` gate
and one `producttest` check. ADR-0244 is not superseded — this is built on its
guarantee rather than around it.

## Context

A person who has just unpacked the release archive has `pascalc`, a library
reachable by name, and no answer to *where do I put things*. Every row in
`doc/roadmap.md`'s *Getting it and learning it* was about what surrounds the
compiler once you are already using it — a binary, examples, a tour — and none
was about the first ten minutes. It was asked for on 2026-09-06.

**The obvious objection is the one that had to be answered first.**
`doc/tour.md` has a section titled *there is no manifest and no build order to
maintain*: `import greet;` finds `greet.pas` in the importing source's own
directory (ADR-0244), transitively and post-order, with nothing declared
anywhere. That is a real property and a generator that wrote a module list
would take it away — adding back exactly what the design removed, in the file
a new user reads first.

**But it is narrower than "no config file".** The property is that the *import
graph* is inferred. What is not inferred, and what a person has to carry in
their head today, is: which source is the program when a directory holds
several, what the executable should be called, the optimisation level, the
target, extra import paths for vendored code, and — the sharp one — the
**link flags**. A program using `PasTls` must know to set
`AFTERSCHOOL_PASCAL_LDFLAGS=-lssl -lcrypto` (ADR-0264) and nothing tells it so.
Those are facts about a project that no amount of looking at the sources
recovers.

## Decision

**`afterschool-pascal.toml` carries what the compiler cannot infer, and lists
no modules.** Ten keys in three sections: `project.name`, `project.version`;
`build.program`, `build.output`, `build.opt`, `build.target`,
`build.import-path`, `build.cflags`, `build.ldflags`; and `test.expected`.
There is no `[dependencies]` and no source list, and that absence is the
feature.

**Four subcommands, recognised as the *first* argument and nowhere else.**
`new-project <name>` (alias `new`) writes the skeleton; `build`, `run` and
`test` read the file. Position is what makes them spellable without taking a
name away — a source is `something.pas` and an object is `something.o`, so a
bare word in first position is a shape no existing invocation has, and
`pascalcc build.pas` still compiles that file. It is ADR-0140's rule for a
command line.

**The skeleton is `src/`, `test/`, `build/` and four files**, and each earns
itself: `src/` is where the import search already looks, so the generated
`greet.pas` is imported by name with no path and no declaration — the layout
*teaches* the property rather than contradicting it; `test/` holds the golden
`test` compares against; `build/` is where artefacts go and is the only thing
in `.gitignore` that matters.

**The reader is a strict subset and refuses what it does not understand**,
naming the line: `[section]`, `key = "string"`, `key = ["a", "b"]`, `#`
comments, nothing else. No integers, no booleans, no nesting. An unknown key
is an error rather than a silent no-op, because that is this driver's rule
everywhere else — *everything it does not pass on it refuses* — and because a
misspelled key in a build file is otherwise found by the build being quietly
wrong.

**Each subcommand assembles a command line this script already accepted**, so
anything a project does a person can do by hand and see how. That is what
makes the title true.

## Consequences

**`test/` means something, which is why `test` exists.** A generated directory
nothing reads is decoration, and a generated `afterschool-pascal.toml` nothing
reads would be worse — so the generator and the three readers landed together
rather than the skeleton first.

**`tests/checks/new_project.sh` is a harness and had to be.** Every case in the
corpus is one `.pas` compiled where it sits; what this asserts is a directory
the driver wrote, a config it read back, and three subcommands that only mean
anything together — the argument `long-path`, `bare-source-name` and
`stale-component` are each harnesses for. It checks that the generated program
**runs**, not merely compiles: the generated module was wrong on the first
attempt, ending `end.` where a module's routine ends `end;`, which reading the
generator did not catch and one run did.

**`producttest` gained a check the flag check could not make.** It derives
documented flags from the *argument loop*, and the subcommands are a separate
dispatch before it — so a new one would have been undocumented and unasked,
which is the defect that check exists for, one dispatch over. The new one
derives its list from the dispatch's own arms, so a fifth subcommand moves it
without it being edited.

**The link-flag key is proved in both directions.** `-lm` links and
`-lnosuchlibraryanywhere` must not, because a config key nothing acts on is the
same decoration as a directory nothing reads.

## What this does not do

**It does not make `pascalcc` a build system.** There is no dependency
resolution, no incremental build, no lock file and no registry. `build`
recompiles the program every time, which for a project small enough to want a
skeleton is a second or two, and the day that stops being true is the day to
argue for more rather than now.

**It does not touch how imports resolve.** ADR-0244 is unchanged, and
`import-path` in the config is the flag the driver already had.

**It does not put any of this in `pascalc`.** A compiler that writes
directories is a different tool, and ADR-0009's split — the compiler emits IR
and stops, the driver is the seam — is what makes the driver the right home.

**It does not generate a library or a module-only project.** One shape,
because one shape is what was asked for and a second would be a guess.

## Alternatives rejected

**A flat directory with no config at all.** It was the first proposal and it is
what the tour already teaches: `pascalcc hello.pas -o hello` with modules
beside it. It stays the thing a project is a convenience *over*, and it was
rejected as the skeleton because it answers nothing about link flags, which is
where a real program first gets stuck.

**A `[dependencies]` or a source list.** The whole objection above, and the one
thing this format may not grow without a record superseding this one.

**A separate `apnew` binary, or a Pascal program.** A generator written in the
dialect is the more interesting artefact for a self-hosting project, and
`PasFS` has `MakeDirectory` and `WriteAllText` to build it from. It is rejected
for now because `build`, `run` and `test` must live in the driver regardless —
the driver is what compiles — and splitting the four across two programs would
put the config reader in both.

**JSON, or `.ini`, or a Pascal source as the config.** TOML was asked for; it
is also the format whose minimal subset is smallest to parse strictly, which is
what let the reader refuse a misspelling by line number in thirty lines of awk.
