# ADR-0361: A subset of a format is a defect

Date: 2026-09-07

## Status

Accepted. Adds `tools/apconfig.pas` and installs it as `bin/apconfig`; replaces
45 lines of `awk` in `tools/pascalcc`. Adds nothing to the language.

## Context

ADR-0348 gave the driver a project file, and the driver is a shell script
(ADR-0009), so it read that file with `awk`: `[section]`, `key = "string"`,
`key = ["a", "b"]`, `#` to the end of the line, and nothing else. The subset
was declared in a comment and enforced by refusing everything outside it, which
is this script's rule everywhere — a driver that silently ignored an option
would make a harness look as though it had tested something it had not.

**A declared subset still accepts documents, and it read two kinds of them
wrongly.**

- It stripped from the first `#` to the end of the line *before* looking at
  anything, so a `#` inside a quoted string ended the value. `output =
  "build/demo#1"` built `build/demo`: a wrong answer, exit status 0, nothing
  written anywhere.
- It split an array on every comma, so `ldflags = ["-Wl,-rpath,/opt/lib"]` —
  one flag a person really writes, and exactly the shape ADR-0264 added the key
  for — was three malformed strings, and the file was rejected as invalid.

Neither is a limitation a user could have read off the comment: the comment
says what the subset *has*, and a person writing TOML against the specification
has no reason to look. The first is the worse of the two. It is the failure
mode this whole tree is written against, and no oracle here could have seen it
— every project in the corpus was written by the generator that also wrote the
reader.

ADR-0360 landed `lib/dialect/pastoml.pas` a day earlier and said in its Context
that this reader "is not replaced by this and will not be", naming the price: a
Pascal module cannot be called from a shell script "without a compiled helper
the driver would then have to find". That sentence was right about the
mechanism and wrong about the price. The driver already finds a compiled
program beside itself — `pascalc`, by three rules it has followed since
ADR-0244 — and finding a second one costs those same three rules again.

## Decision

**`tools/apconfig.pas` reads the project file, and `pascalcc` reads what it
writes.** It is a program in this language over `PasToml`, built by CMake with
the compiler the tree just produced and installed beside `pascalc` as
`bin/apconfig`.

**The protocol is `key=value`, one record per line, and the driver does not
`eval` it.** The old reader printed shell assignments for `eval`, which made
the quoting of somebody's build file into the driver's problem; a `read` and a
`case` cannot run anything at all. An array is its key repeated once per
element, in order. A key absent from the document produces no line.

**The schema lives in `apconfig` and is checked twice.** Ten keys, the same ten
ADR-0348 chose; a key outside them is an error naming the key, a value of the
wrong shape is an error naming the key, and the driver's `case` has a final arm
that refuses a key `apconfig` knows and it does not. Two halves of one list
that must agree, each of which says so out loud rather than dropping what it
does not recognise.

**A syntax error names a line and a column; a schema error names the key.** The
parser answers a byte position and `TomlPositionOf` converts it. A node carries
no position, so a schema error cannot name one — and the key is the more useful
half of that answer anyway.

**The whole document is read into one string, and one too large is refused.**
`TomlPositionOf` needs the bytes to count lines through, so they are held
rather than streamed; 64 KiB, and a larger file is told so rather than read as
a prefix, because a reader that quietly read a prefix would report a syntax
error at the cut.

**A value holding a line break is refused.** It would end a record early and
hand the driver a key it never asked about. A build file has no use for one,
and a reader that invented an escape would need a caller that understood it.

## Consequences

**The driver now needs a built artefact for `build`, `run` and `test`.** It
already needed one — `pascalc` — for every compilation, so this adds no
prerequisite a user did not have; what it adds is a second file in the release
archive and a second entry in `install-layout`'s list. `APCONFIG` overrides
where it is looked for, as `PASCALC` does.

**`tools/` is a source root now.** `warning-free`, `format-check` and
`variant-check` swept `selfhost/`, `lib/` and `lsp/`, which was every source in
this language that is not a test case until this one existed; `coverage.py`
names it beside `lsp/pasls.pas` for that file's reason, and `tools/apconfig.pas`
carries an `.importpath` sidecar so the sweep drives the resolver too.

**`PasToml` has a client that is not a test**, which is what ADR-0355 records as
the thing a library module is worth measuring by. It found nothing on the first
run, which is a fact about the module's own three cases rather than about this
one.

**What this does not do.** It does not make the driver a Pascal program. The
driver assembles command lines, re-invokes itself, traps for its temporary
directory and `exec`s — and `PasProcess.Run` is `system()`, so a Pascal driver
would build one command *string* and hand it to a shell, quoting every path
itself where the script today uses arrays and quotes nothing. That is a
regression in exactly the direction a driver must not regress, and closing it
means a real `spawn` with an argument vector in the runtime, which is a
different change with a different class. It also does not widen the project
schema: TOML now admits integers, booleans, dates, inline tables and arrays of
tables into the file, and every one of them is refused by the schema, because
what a key means is ADR-0348's decision and not this one's.

**The two claims that hold it.** `tests/checks/new_project.sh` §7 asserts the
`#` and the comma in both directions, and a refusal naming a line *and a
column*, which the line-at-a-time reader could not produce.
`tests/mutation/mutants/0361-a-hash-inside-a-quoted-value.mut` puts the
truncation back and
`0361-every-element-of-a-list.mut` drops every element after the first; each
kills `new-project` on a different assertion. The unknown-key claim has no
mutation of its own on purpose: it is enforced in both halves, so no
single-point mutation can reach it.
