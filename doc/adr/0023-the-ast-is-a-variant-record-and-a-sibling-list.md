# 23. The AST is a variant record and a sibling list, and the parser port is checked the same way the lexer was

Date: 2026-08-10

## Status

Accepted

## Context

The second component of the stage-1 compiler, and the one ADR-0005 was written
for. That record forbade C++ RTTI in the AST on the grounds that the
Pascal-hosted compiler would have no `dynamic_cast` to lean on, and paid for a
tag plus `as<T>(n)` in every tree walk since. This is where the bill comes due
or the precaution turns out to have been unnecessary.

ADR-0022 settled how a ported component is checked: against the C++ one, not
against a golden file. What that record could not answer is how to compare a
component whose output is a *tree* rather than a stream, and what happens to
the parts of the C++ parser that have no Pascal equivalent — a vector, an
exception, a `std::string`.

## Decision

**The comparison is `pascalc --dump-ast` against `selfhost/parser.pas`**, over
every `.pas` in the tree, under `ctest` as `selfhost-parser`. `difftest.sh`
grew a mode argument and now drives both components; the lexer test is the same
test with `--tokens`.

The dump is taken **before Sema**, so it carries the shape of the tree, the
spellings the parser kept, and the positions it recorded, and nothing a later
stage fills in. A disagreement is therefore a disagreement about parsing. One
node per line, two spaces per level, and ` @line:col` **only where the tree
actually records a position** — a construct without one must not be given an
invented one, or the dump would be comparing a fiction.

Four things the language decided rather than we did:

**The `NK` tag becomes a variant record's tag, and `as<T>(n)` becomes the
`case` that reads it.** This is the whole of what ADR-0005 bought, and it
transferred with no cleverness at all. What ADR-0005 did *not* anticipate is
ISO 7185 §6.4.3.3: a record's field identifiers must be distinct across every
variant, so the arms cannot all call their operands `base` the way the C++
structs do. Hence the two-letter prefixes (`ixBase`, `fdBase`, `drBase`). It
is the one place the port is uglier than the original, and it is the standard's
choice, not a shortcut.

**`std::vector<ExprPtr>` becomes a sibling list.** Every node carries `next`,
and a list is a head pointer plus a tail for appending. A growable array would
be a second data structure to write and to get right, and every walker in the
compiler reads these strictly in order. The one place it shows is `with a, b do
S`: the C++ parser nests the records by walking its vector backwards, and a
sibling list has no backwards, so `NestWith` recurses to the end and builds the
same tree from the other end.

**The parser's one exception becomes a flag.** `ParseAbort` is the only
exception in the C++ codebase; Pascal has none, and this compiler does not
implement `goto`, so there is nothing to unwind with. `aborted` is tested by
every production and every loop instead. The cost is real and is spread over
the whole file — a `while` that forgets `and not aborted` is an infinite loop
rather than a wrong answer — and it is the strongest argument this port has
produced for keeping the C++ parser's habit of bailing at the *first* error.

**Reading a function's own name is a recursive call** (ISO 7185 §6.8.2.2), so a
node under construction cannot live in the result variable. `ParseRecordType`
builds into a local and assigns once at the end. Written the obvious way, only
some of it is caught: Sema rejects `new(Make)` because `new` needs a pointer
*variable*, but `Make^.a := 7` compiles, links, and recurses until the stack is
gone. That is the standard's own semantics rather than a defect — it is a call,
and it is a call with no base case — but it is worth knowing before writing
Sema, where a function returning a pointer will be the ordinary case.

**Expect's context phrase becomes an enumeration.** The C++ parser passes the
phrase itself; forty-odd padded literals would cost more than the `case` that
writes them, so the call site names the place and one procedure spells it.

## Consequences

The port has a second working component, checked by the same harness as the
first, and `selfhost/parser.pas` parses its own 1800 lines into a tree the C++
parser agrees with node for node.

**The error paths needed a corpus of their own.** The parser stops at its first
error, so one file can carry exactly one diagnostic — `torture.pas`, which
holds every lexical corner case at once, has no parser equivalent.
`selfhost/badparse/` is that equivalent spread over one file per message: 71 for
the diagnostics, and one per arm of the token-name table.

That directory exists because of a measurement, not a hunch. Before it, the
corpus produced **no parser diagnostic at all** — every error in it came from
the lexer — so the whole of `Expect`, all 43 context phrases and all 61
token-name arms were uncompared. Two rounds of counting were needed: after the
message files were added, the table was still only 20 arms of 61, and a
mutation that dropped the quotes from `'downto'` survived the suite. It is
caught now.

**Two phrases cannot be reached and are compared by inspection only.** The
empty context, whose every call site is reached only after the token was
already checked, and "between the bounds of a subrange", because
`LooksLikeSubrange` returns true only when the `..` is already there. Both are
noted here rather than left to look like coverage.

**The test is known to be able to fail.** Eleven mutations were applied to the
Pascal parser: dropping the nesting of `a[i, j]`, turning a leading `-` into
`+`, recording `downto` as `to`, ending the one-character-literal rule, moving
the depth bound by one, unspelling `forward`, inverting the bare `eof`/`eoln`
rule, rewording a context phrase, rewording a bespoke message, shifting an
error column by one, and the token-name quotes above. Ten were caught
immediately; the eleventh is what the token-name corpus was written for.

**ADR-0020's depth accounting had to be ported exactly.** The bound is on the
tree, so the spine-building loops count each iteration, and a port that counted
only recursion disagrees with the C++ parser on `tests/deep_chain.pas` — which
is how the mutation that moved the bound by one was caught.

**What is still not covered.** A real literal is carried as its source text and
not converted, for the reason ADR-0022 gives; `RealLit` gained a `text` field
on the C++ side so the two can be compared on it. The conversion now arrives
with Sema, which is the first stage that needs the value, and this is the
second record in a row to defer it — the next one either implements it or
explains why not. Identifiers and literals remain capped at 255 characters and
the token table at 30000 tokens; both are the fixed-buffer limits ADR-0012
predicted, and both fail loudly rather than silently.

## Notes for the port

As with the lexer, the program is written to be pasted into one source file.
`program Parse(output, source)`, `Tokenize`'s driver and everything under "the
dump" are the only parts that will not survive the merge; the node type, the
arena and the productions are what Sema will be written against.
