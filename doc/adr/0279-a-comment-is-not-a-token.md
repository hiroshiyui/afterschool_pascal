# 279. A comment is not a token, and now it is not lost either

Date: 2026-08-31

## Status

Accepted, 2026-08-31.

The last paragraph of the consequences below names `textDocument/formatting` as
not built. **ADR-0280 built it**, in the same session.

## Context

`doc/roadmap.md`'s "What would make this easier to work on" opened with the
largest gap by developer-time: **there is no formatter.** `.clang-format`
covers the four C files; nothing covers the 40 821 lines of Pascal that are
the compiler, the 10 507 in the library modules, or the 779 tracked corpus
sources.

That chapter also said where the hard half already was. ADR-0258 makes the
parser report where every statement begins and ends and ADR-0253 does the same
for every declaration, so the *structure* a printer needs is emitted already.
What was missing is **trivia**: the lexer consumes a comment and never makes it
a token, which is why three separate records here say *a comment is not a
token*. A formatter needs the tokens **and** the comments between them, and
that is the whole of the work.

The cost the chapter named was ADR-0126's. The corpus holds 1 881 326
characters of commentary against the 449 278 the string pool has free, so
interning one would cost this compiler its own translation.

## Decision

Three pieces, and the first is the one the roadmap asked for.

**The lexer records where each comment was, and only when something asked.**
`keepTrivia` is false on an ordinary compile, and that is the design rather
than an optimisation: a comment is needed by nothing that compiles, so a
translation nobody asked trivia of writes no table, checks no bound, and
cannot fail for a reason it could not fail for before. `--format`,
`--dump-trivia` and `--dump-limits` set it — the last because measuring the
bound is the whole of what that flag is for.

**What is recorded is a position and never text.** The record is the opening
delimiter, one past the closing one, and the index of the token the comment
precedes; 20 000 of them, against the 1 423 in the largest source here. There
is no arena. Whatever wants the characters reads the source a second time
through a cursor — which is also the *only* way to recover an identifier's
text, the pool holding the folded spelling and a formatter that lowercased
every name in a program being worse than no formatter.

**`--dump-trivia` writes them**, `trivia <line> <col> <endline> <endcol>
<before> <text>`, with newlines folded to spaces because a dump is one record
to a line. It stops after the *lexer*, one stage earlier than any other dump
that stops: a comment is lexical and nothing after the scanner has ever seen
one. A last line says whether the trivia is complete, which is not decoration
— see the refusal below.

**`--format` writes the source back out.** It works from the token stream and
not from the tree: a printer over the AST would have to write out every
type-denoter and every expression form the language has and would lose
whatever the parser normalises away, where a printer over the tokens decides
only what goes *between* two of them. What that costs is that structure has to
be recovered from the tokens, which is two stacks and a dozen word-symbols
rather than sixty node kinds.

Three things in it were arrived at by getting them wrong first.

- **A control stack, not a counter.** The single-statement indent a `then`, a
  `do` or an `else` opens is released by exactly one `else` — its own `then`'s
  — and `else if c then begin` opens none at all, so no arithmetic on a depth
  finds the right one. And a `;` releases the indents of *its own* block and
  no further: the `;` after a case-statement's first arm does not end the
  `for` the case-statement is the body of, which is why each opener frame
  records the control stack as it stood when it opened.
- **A routine's own tokens stand one level out from a heading declared inside
  it.** `procedure walk;` and its `var`, `begin` and `end` are at the same
  indent; a nested `procedure note;` is one deeper, and *its* `var`, `begin`
  and `end` are at that. That is Pascal's nested-procedure layout and it is
  not a nesting indent, so it is a number of its own. Knowing when to raise it
  means knowing whether a heading has a block, and three declarations look
  exactly like one and are not: §6.6.1's `forward`, ADR-0121's `external`, and
  §6.11.1's heading in a module's export-part.
- **A comment moves with the code it belongs to.** Its first line goes where
  the layout puts it and every line after that keeps the shape it was written
  with, shifted by however far the opening delimiter moved. Nothing is
  reflowed — a comment is prose and this has no business rewrapping it.

The margin is 79 and is enforced only where a space already stands: no token is
split and no comment is reflowed.

**A refusal, not a short file.** A source with more comments than the table
holds has trivia that is *incomplete*, and printing a file with a comment
silently missing from it would be the worst thing this feature could do. So
`--format` reports and writes nothing. That is ADR-0012's rule about a full
buffer applied where the buffer is optional: the compilation is unaffected,
and what fails is the request.

## Consequences

**`format-check` makes three claims over every tracked source, and the first
is the whole semantic one.** The token stream must be unchanged but for
positions — and that is not a sample of what could go wrong, because the parser
sees the token stream and nothing else, so two sources with the same token
stream compile to the same program by construction. The comments must be
unchanged word for word and still stand before the same tokens, which is the
only claim that can catch a dropped or reordered comment, the token stream
being unmoved by one. And formatting the output again must return it byte for
byte, which is the claim about the *rules* rather than about a run of them: a
layout that depended on where the input happened to break its lines would pass
the first two and fail this.

**774 of the 783 sources pass all three**; the nine the lexer rejects have no
token stream to preserve. Three mutations were made and each is killed by the
claim that should: gluing every pair of tokens fails the first, dropping a
source's last comment fails the second, and measuring the margin from the
input's own columns fails the third.

**What none of the three says is that the output is well laid out.** There is
no oracle for that, and `tests/dumps/format.pas` is the substitute — one file
written deliberately badly, whose golden is the only place in this tree that
asserts a style. **Nothing here is applied to the repository.** The tree has no
agreed Pascal style and this does not create one.

The cost the roadmap warned about did not arrive, because the arena it warned
about was not built: the pool is untouched and the one new bound is a count of
comments, reported by `--dump-limits` and watched by `buffer-headroom`, which
now reads three arrays instead of two. The third differs from the first two in
what a full one *means* — the pool and the token table failing is a compilation
failing, and this failing is a formatter refusing.

**Every decision the formatter writes is taken both ways by the corpus**, which
took adding `--format` and `--dump-trivia` to the coverage sweep — the same
sentence ADR-0274 wrote about `--coverage`, met again: the harness that drives
this flag is `format_check.py`, so without the sweep every layout rule would
report as unreached while an oracle reached them all. `FmtToken`, which is the
whole of the layout, ends at **0 of 180 directions never taken**. Eleven
directions in the new code are dead and nine survive: three are the trivia
bound, which `fuzz` reaches and the corpus cannot, exactly as `too many tokens`
was left by ADR-0275; the rest are defensive bounds and a scan over a token
stream the parser has not yet seen. `branch_coverage.txt` goes from 852 to 861
over 212 more decisions.

The one visible wart is a comment already at the margin that moves right: it is
shifted, not reflowed, so it can end a character or two past 79. That is the
price of not rewrapping prose and it is worth it.

What is *not* built is the language server's `textDocument/formatting` and
`rangeFormatting`, which the roadmap names as the first of three things this
would pay for. The compiler half is what a server would call, and it is here.
