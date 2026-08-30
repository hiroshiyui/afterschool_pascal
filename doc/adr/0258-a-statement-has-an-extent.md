# 258. A statement has an extent

Date: 2026-08-30

## Status

Accepted, 2026-08-30.

It closes the half [ADR-0253](0253-a-declaration-has-an-extent.md) left open
and named in its own closing paragraph:

> **What is still not recorded is a statement's extent.** A block knows where
> it ends; an `if` or a `while` does not, so selection expansion stops at the
> enclosing declaration and does not step outward through nested statements.
> No caller has asked, and the shape of the answer would be the same — a
> position taken where the parser finishes the construct.

## Context

Something asked. ADR-0253 gave `documentSymbol` a real `range`, which fixed
*expand selection to the enclosing declaration* — and left the whole inside of
a declaration flat. An editor expanding a selection from a cursor inside a loop
body jumped straight to the procedure.

**Two requests want it and neither was answered**: 3.17's `foldingRange`, which
is the gutter arrow beside every `begin`, and `selectionRange`, which is the
gesture ADR-0253 named. One caller — `lsp/pasls.pas` is the only reader of any
dump here — but two gestures a reader performs by hand, which is what makes it
a demand rather than an anecdote under ADR-0116.

## Decision

A node carries `endLine, endCol`, stamped by the parser for every statement,
and `--dump-stmts` reports them. The server answers `textDocument/foldingRange`
and `textDocument/selectionRange` from it.

**A token had to learn where it ends first, and this is the part that would
have been got wrong.** ADR-0253's convention is *the position of `tok[pos]`,
the token past the construct* — correct for a block, whose `end` is followed by
`;` or `.` immediately. After a *statement* the next token is `;`, `end`,
`else`, `until` or `otherwise`, routinely on a later line, and comments are not
tokens — so that position swallows everything a reader wrote after the
statement. A statement must end at its own last token.

And the token record could not say where that is. `len` is the length in the
string **pool**: zero for every token `AddSimple` builds, and different from the
source length for a literal — `'a''b'` is three pool characters and six source
ones. So `token` gains `endCol`, stamped in `AddToken` from the lexer's own
`col`, which is already one past the token because the lexer consumes before it
records. Both wrong answers are staged as mutations and both are caught, by
`dump-stmts` and by `lsp-server` independently.

**The parser reports, and no walker was written.** `StampEnd` writes the line
where it stamps it, which is the one moment anything knows a statement is
finished — ADR-0246's principle, and ADR-0230's argument against the
alternative: a hand-written walk over the AST's variant record can miss a node
kind in silence and no gate here can see that. The line is written during the
parse and interleaves with diagnostics on one stream, exactly as `--dump-uses`
does, and a reader takes the lines it recognises by their first word.

The order is therefore *completion* order, innermost first. It costs a caller
nothing: containment is decidable from the ranges, so the format carries no
depth — which is one field fewer than `--dump-symbols` needs and is the
difference between a tree a reader must rebuild and a set it can query.

**`--dump-stmts` stops after the parse**, so it needs no `--import` and answers
for a file that does not compile. That is not an economy: both gestures are
used *while a file is being typed into*, which is exactly when it does not
compile.

## Consequences

**Verified through Microsoft's `vscode-languageserver-protocol`**, as ADR-0236
required of everything here: both capabilities advertised, zero connection
errors, three folds and a four-link chain — the assignment, the compound it
stands in, the `while`, and the program's own compound. That fourth link is
what ADR-0253 could not give.

**Two quality decisions in the folding answer are worth naming.** Ranges are
deduplicated by the lines they cover, because `while c do begin … end` is two
foldable statements over exactly the same lines and offering both puts two
identical arrows in a reader's gutter. And only the constructs that *contain*
statements are offered: every multi-line statement has an extent, and a fold
over a two-line assignment is noise.

**Every session's golden moved**, because the `initialize` reply grew two
capabilities. They were patched at the byte level rather than regenerated, so
nothing else in any of them changed and the diff is reviewable.

**The ratchet went up by one and it is argued rather than absorbed.**
`PutStmtWord`'s `otherwise` is unreachable: every node kind `ParseStatement`
builds is named. It stays because ADR-0018 makes a case-statement with no
matching label *stop the program*, so the arm is what turns a statement kind
added tomorrow into the word `statement` rather than a halted compiler. That is
the one shape where an unreachable arm is worth its line, and the alternative —
dropping a real kind so the arm is reached — would make the output worse to
make a number smaller.

**What is still not recorded** is an *expression's* extent. The same trick does
not apply: the parser builds an expression bottom-up and does not stand past a
sub-expression when it finishes one the way it stands past a statement. Nothing
has asked, and the caller that would is `documentHighlight` — which does not
need it, being `--dump-uses` re-read for one symbol.
