# 284. The printer already knows where it is

Date: 2026-09-01

## Status

Accepted, 2026-09-01.

## Context

ADR-0280 gave the language server `textDocument/formatting`, and
`doc/roadmap.md` recorded what was left of the formatter's three intended
payoffs:

> `textDocument/rangeFormatting` needs a formatter that can be asked about
> *part* of a file, which means telling the token-stream printer where to start
> its indent — a question about the enclosing structure that only a parse can
> answer.

**That is wrong, and the reason it is wrong is the shape of the thing.**
`FormatSource` is one loop over the token stream (ADR-0279), and every piece of
enclosing structure it needs — the block depth, the routine nesting, the
control stack, whether a heading has a block — is a counter it *accumulates* as
it walks. A parse would be one way to learn the depth at line *L*. Walking to
line *L* is another, and the walker is already written.

So the roadmap's row met this chapter's own lesson a second time: **a row
saying a feature is blocked is a row nobody has tried**, and trying is cheap.

## Decision

`pascalc --format --range=L:H` prints lines *L* to *H* with the layout they
have in the whole file. The implementation is **a gate on the sink**:

- `FmtPut` and `FmtNewline` suppress the *write* when the walk is outside the
  range, and update `fmtCol` and `fmtNL` regardless. Every other piece of state
  is untouched, so on arrival at line *L* the printer stands exactly where the
  whole-file format stands.
- Turning the sink on fakes exactly one thing: the newline that would have
  ended the previous line. That line is outside the range, and so is the blank
  line the layout may want before the range's first token — a range handed to
  an editor must be the lines it asked for, and one opening with a blank would
  replace four lines with five.
- Turning it off finishes the line first. Without that the last line of a range
  has no newline and two ranges pasted together run into each other.

`textDocument/rangeFormatting` follows, with `documentRangeFormattingProvider`
beside the capability ADR-0280 added. The client's range is a *position* pair
and the formatter's unit is a line, so the selection is widened to the whole of
every line it touches, and the reply's own range is whole lines too. A range
ending at character 0 does not reach into that line: selecting three whole
lines sends end 3:0 and gets three lines back, not four.

### What the gate can claim, and what it cannot

The claim that would be strongest is that a partition of a file into ranges
concatenates to the whole-file format. **It is false, and measuring it is what
showed why.** A boundary inside a construct forces a line break there:
`function TermSize(fd: integer; var rows: integer; var cols: integer):
ErrorCode;` wraps before `ErrorCode` when formatted whole, and before
`var cols` when the range ends between them. That is inherent to formatting
part of a file and every language server does it.

What survives is the claim that matters and it is `format-check`'s first one
restricted to a range: **the token stream must be the input's tokens on those
lines, in that order.** The parser sees the token stream and nothing else, so
a range that preserves it cannot change the program it is pasted into.
`format-check` now makes that claim over two ranges per source from a fixed
seed — ADR-0275's rule, so the suite carries a regression corpus and not a
search — which is 623 sources as this is written.

Layout is pinned separately by `tests/dumps/format_range.pas`, because the two
are independent: a mutation that discards the accumulated indent leaves every
token in place and `format-check` green.

### A defect the gate found in the formatter

`and then` and `or else` are one token each (ADR-0038) and the printer supplied
their text with a bare `write`, adjusting `fmtCol` by hand — the one thing
ADR-0279's record says it fixed once already, for the same reason. With the
sink always on this is invisible: the bytes and the column are identical either
way. With a sink that can be closed it printed those two word-symbols outside
the range, `and thenand then  end;`. They go through `FmtWord` now.

## Consequences

- **A range is formatted as a range**, not as a slice of the whole file. A
  boundary inside a construct gives a break the whole file would not have.
  That is documented rather than fixed; fixing it means snapping the range
  outward to construct boundaries, which *is* the parse question the roadmap
  named, for a gain no editor asks for.
- **A bad `--range` is refused rather than widened** — `pascalc: --range wants
  L:H, two line numbers with H at least L`, exit 1. Silently formatting the
  whole document where a fragment was asked for is the answer that gets
  diagnosed as an editor fault.
- **`tests/dumps/name.flags` may now hold more than one flag.** It was
  `tr -d '[:space:]'` into a single argument, and the failure was the readable
  kind: `unknown option --format--range=22:24`.
- **The coverage corpus sweeps `--range` twice**, once well-formed and once
  refused, for the reason every other sweep entry there gives: the flag is
  driven by a case on every run, so without it the gating would report
  unreached while an oracle reached it.
- **Five branch directions in `ParseRange` are in the ratchet rather than in a
  case.** They are the individual conditions of one validity test — a letter in
  the span, a second colon, a zero, the ends reversed — and each needs its own
  malformed command line to reach. All four produce the same message, which
  `tests/dumps/range_refused.pas` pins. Four more goldens asserting one string
  is not evidence.

## Alternatives rejected

**Tell the printer a starting depth, computed from a parse.** The roadmap's
design. It needs a second implementation of the depth rules — the parse would
have to agree with the printer about routine nesting, the control stack and the
`fmtLift` a nested heading takes — and two implementations of one rule is
ADR-0111's objection and ADR-0230's. The walk has one.

**Format the whole file and slice the output.** It needs a map from input
tokens to output lines, which nothing keeps, and it costs the same walk this
does.

**Return a diff rather than one edit per range.** ADR-0280 rejected it for the
whole document and the reason holds here: nothing in the formatter's output
says which part of the input any part came from.
