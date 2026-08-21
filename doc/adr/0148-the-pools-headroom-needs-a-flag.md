# ADR-0148: The pool's headroom needs a flag; the tokens' did not

Date: 2026-08-21

## Status

Accepted. Closes the `doc/sop.md` §7 row ADR-0126 opened, in the words that
row itself proposed. Does not supersede ADR-0126; that record is what the
token half is, and this one is what it could not reach.

## Context

`selfhost/compiler.pas` reads its input into two fixed arrays (ADR-0012): a
character pool for every identifier and literal, and a token table. Both are
sized for this compiler's own source, which is the largest Pascal in the tree.

Both have run out, and neither failed the way a limit is supposed to. The
failure is a **build**: the array that has to hold this source is the *seed's*,
so raising the constant in the source does not raise the one that matters, and
the only way out is an out-of-cycle reseed that rewrites 6 MB.

- **ADR-0095**, the pool, cleared at 74 characters over.
- **ADR-0126**, the tokens, found with **107** left of 140000 — 0.08%.

ADR-0095 closed with the sentence *nothing measures the headroom*, and that
sentence is why it happened a second time. ADR-0126 is the measurement, and it
measures **one of the two arrays**:

> `--dump-tokens` writes one line per token and a Pascal string-literal cannot
> contain a newline (§6.1.7), so the line count *is* the token count — exact,
> and it needs nothing of the compiler that is not already a documented flag.
> The string pool has no such answer: `PoolAdd` is called from Sema and from
> CodeGen as well as from the lexer — a type's alias name, a trap message — so
> no count taken over the token stream is its size, only a lower bound.

So the array that hit its ceiling **first** was the one the gate could say
nothing about, and the gate has been reporting headroom for two arrays while
measuring one since the day it was written. ADR-0126 wrote down what would
close it — *a `--dump-limits` reporting `poolLen` and `tokCount`* — and left it
as the move if the pool bit again. This is that move, taken before it does.

## Decision

**`--dump-limits`: compile as usual, then report each array's high-water mark
against its capacity.**

```
$ pascalc --std=extended --dump-limits selfhost/compiler.pas -o /dev/null
pool 491964 of 1000000
tokens 144756 of 300000
```

Four things about the flag are decisions rather than details.

### It is not a dump of a stage

The other four stop at the stage they name, which is the only way a stage can
be dumped for a program the next stage would reject. This one is the reverse:
the pool is filled by Sema and by CodeGen as well as by the lexer, so its
question has an answer only once everything has run. It therefore stops
nothing and **forces** everything, the way `--dump-all` does — otherwise
`--dump-tokens --dump-limits` would report the pool as the lexer alone had left
it and call that the answer.

It writes its report bare, with no `=== ` header. A header separates the three
sections of `--dump-all`; a flag that writes one report writes it unadorned.

### It is not a section of `--dump-all`

Those three sections are what `selfhost/difftest.sh` diffs against the
reference front end, which has no such arrays. A fourth section would be a
disagreement on every file in the corpus — 219 baseline entries to buy a
number, and the baseline being empty is what makes an entry mean anything.

For the same reason `dumping` excludes it: a diagnostic during a limits run is
for a person to read and keeps the `file:line:col:` form.

### It reports after a failed run too

An exhausted array *is* the error, so the numbers are what a reader wants
either way. The gate that consumes them has already failed on the exit status,
so nothing depends on this; a person reading *out of string space* and then the
two lines under it does.

### Two arrays, and that is an argued list

These two grow with the size of the source and creep toward their ceiling with
nothing announcing it. `maxImports` is bounded by the command line, `maxDepth`
and `maxBlockDepth` by nesting the parser refuses beyond, and `strMax` by one
identifier — each reports what happened, in the words of the thing that
happened, at the moment it happens. A headroom figure for those would measure
something nobody is approaching unawares.

## Consequences

**The pool is 50.8% free and nothing knew that.** The first measurement is
491964 of 1000000 for this compiler's own source under `--std=extended`, where
the lower bound available before was 442,625. The tokens are 144756 of 300000.
Both sit under the gate's 80% mark, which is the answer that was assumed and
had not been checked since the constant was last raised.

**`buffer-headroom` now checks the capacities as well as the counts.** They are
read twice — from the source, and from what the built compiler reports — and a
disagreement means `build/bin/pascalc` was built from another source and is
measuring headroom against a bound this tree no longer declares. That is the
one way the gate could have quietly answered about the wrong compiler, and it
is `doc/sop.md` §7's *a gate that holds both halves of its comparison cannot
fail* answered for this gate: half of the comparison now comes from the
compiler rather than from a regex over its source.

Two mutations, and the first is the one that could not have been made before:

- **`poolMax = 600000`**, which still builds and still compiles this source.
  All 627 cases pass and `buffer-headroom` alone fails, at 82.0% full. Under
  ADR-0126's gate that mutation was invisible — the pool was not measured at
  all.
- **Restore the constant and do not rebuild.** The gate reports the stale
  binary by name rather than measuring 491964 against a capacity the compiler
  it ran does not have.

### What it does not do

**One entry to the pool is still not loud.** `PoolPut` drops a character when
the pool is full rather than reporting, so the two names Sema builds rather
than reads — a function's result slot and a `with` binding — would come out
short, and a short name is a name that can collide. It is reachable only once
the pool is within a name's length of full, which is the state this flag exists
to report long before; the row is in `doc/sop.md` §7 rather than fixed, because
the fix is a diagnostic no program in the corpus can reach and the honest
alternative to a golden here is the headroom report itself.

**It is a watch on a bound, not a claim.** Like ADR-0126's half it fails in one
direction only: an array that gets *emptier* is not a failure. The two-sided
rule the other catalogues follow does not apply to a number that is allowed to
move.

### Rejected: a case in `tests/dumps/`

The obvious home for a new dump flag, and wrong for this one. The pool figure
moves whenever Sema or CodeGen interns something new, so the golden would be
regenerated for reasons that have nothing to do with what it asserts — and
regenerating a golden is a decision to be argued for, not a step. What
`buffer_headroom.py` asserts instead is stronger: the capacities the compiler
reports must equal the constants this tree declares, and the counts must sit
under the mark. `tests/checks/coverage.py` drives the flag the way that gate
does, so the procedure is entered by a case without a golden to keep.
