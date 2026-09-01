# 285. The formatter is not ready to own the tree

Date: 2026-09-01

## Status

Accepted, 2026-09-01.

## Context

`doc/roadmap.md` carried one row after ADR-0284: **a `style:` gate for the
Pascal, of the kind `git clang-format` gives the C.** ADR-0279 had left the
question open in as many words — `format-check` proves the formatter
*preserves* a program, nothing says the output is well laid out, and **nothing
in this tree is formatted by it.**

This record is the attempt, made on a branch so the cost could be seen before
anything was decided.

## Decision

**The gate is declined, and the attempt is why it was worth making.**

### What a reformat costs

Formatting every tracked Pascal source rewrites **42 601 lines across 728
files**; only 52 files in the tree are already what the formatter would write.
Splitting the corpus the way its purpose splits it — the implementation
(`selfhost/`'s three components, `lib/`, `lsp/`) against the fixtures
(`tests/`, `selfhost/badparse/`, `selfhost/badsema/`, `torture.pas`, which are
data and several of which are deliberately ill-formed) — the implementation
alone is **36 files and 25 070 lines**, and it grows the source **6.8%**,
55 807 lines to 59 583.

Most of that is not defects. It is the formatter's opinions, and they are
opinions this tree does not share: every one-line `var i: integer;` becomes
two lines (818 of them), every one-line `begin … end` is expanded (558), a
blank line is inserted between adjacent routine headings that were written as
a group (210). None is wrong; all of them are *different*, and the difference
is 6.8% of a hand-maintained source.

### What the attempt found, which is the part worth keeping

**Five layout defects, and every one of them was invisible to every oracle
here**, because all five preserve the token stream: `format-check` is green on
all five, and `tests/dumps/format.pas` — the case whose own comment claims it
holds "every construct the layout rules know about" — held none of the five
shapes.

- **A blank line inside a parenthesised list dropped the rest of it to column
  zero.** `fmtCont` is cleared at a break "because what follows is a new
  statement, declaration or line of a block" — true outside parentheses and
  false inside them, where a blank line separates groups of one list that is
  still open. `lib/dialect/pasjson.pas`'s export-part is the shape.
- **A comment introducing an `else` was indented as part of the arm above
  it.** An own-line comment belongs to what follows; `else`, `otherwise`,
  `until` and `end` release an indent *after* the comment is written. In a
  tree this comment-dense it mis-indented the explanation of nearly every
  second branch, and it is the single defect that would have done most damage.
- **`^` was glued to whatever preceded it.** Right for §6.5.4's postfix
  dereference, `p^.next`; wrong for §6.4.4's prefix pointer-type, which came
  out `JsonChars =^Vec(char)`.
- **AP 6.4.13's `!` took a space on one side.** It is binary — `JsonPtr !
  ErrorCode` names two types — and it sat in the list of tokens nothing may
  precede, so it printed `JsonPtr! ErrorCode`.
- **§6.9.2.1's empty statement after a case-label lost its space**, printing
  `jsNull, jsTrue:;`, which reads as a typo rather than as a statement.

All five are fixed, and `tests/dumps/format.pas` now holds all five shapes.
**Fixing them did not shrink the reformat** — 24 490 lines to 25 070 — which
is the measurement that settles the question: the diff is not defects, it is
the house style, and the defects were a small part of a large disagreement.

## Consequences

- **Nothing in this tree is formatted by its own formatter, still**, and
  `doc/sop.md` §7 keeps that row. What changes is that the row now has a
  number against it and five fewer reasons.
- **The formatter is better by five rules**, independently of the gate, and
  those fixes are worth having on their own: `--format` and
  `textDocument/rangeFormatting` are offered to users, and a user's buffer is
  where the `=^` and the mis-indented comment would have landed.
- **`tests/dumps/format.pas` is the oracle that failed here**, and the lesson
  is its own comment: a case claiming to hold *every* construct is a claim
  nothing checks. Five shapes it did not hold were found by pointing the
  formatter at 36 real files, which is what a corpus does that a purpose-built
  case cannot.
- **The gate becomes cheap the day the layout is agreed.** What blocks it is
  not the mechanism — `format-check` already formats every source on every run
  and could compare instead of discard — but the absence of a decision about
  `var` on one line, blank lines between headings, and one-line bodies. That
  is a decision for whoever maintains this source and not for a record.

## Alternatives rejected

**Adopt the gate and take the 6.8%.** It rewrites 25 070 lines of a
hand-maintained source, damages `git blame` on every one of them permanently,
and encodes three layout opinions nobody chose. The tree would then be
formatted, and no more readable.

**Teach the formatter this tree's style first** — keep a one-line `var`, keep
adjacent headings together, keep a short `begin … end` on one line. Each is a
rule with a condition ("short" needs a width, "adjacent" needs a lookahead),
each is a new way for the formatter to be wrong, and the reason to write them
is to make a diff smaller rather than to make output better. Worth doing if
the gate is wanted; not worth doing to find out whether it is.

**Gate only the files that are already formatted**, growing the set over time.
It is the shape `line-coverage`'s ratchet has and it would work — but 52 files
of 780 is not a foothold, and 49 of those 52 are in `tests/`, where the
formatter's opinions do not matter because nobody reads them.
