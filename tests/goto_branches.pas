{ ISO 7185 §6.8.1 admits a label in a goto three ways, and no more:

    a) the labelled statement contains the goto;
    b) the labelled statement is a statement of a statement-sequence
       containing the goto;
    c) the labelled statement is a statement of the statement-sequence of the
       compound-statement of the statement-part of a block containing the goto.

  Only a compound-statement and a repeat-statement hold a statement-*sequence*.
  A branch of an if, a loop body, a with body and a case arm are each a single
  statement, so a label inside one of those is reachable only from within it,
  which is a).

  The prefix test ADR-0029 built implements "a goto may leave a structured
  statement but not enter one", which is b) and c) together -- and it answers
  yes for two labels at the same depth in *different* branches, because the
  chain has the if-statement on it either way. That is the shape BSI's DEV190
  writes, and the case-arm jump below is the same rule in the other construct.

  The legal jumps come first, and they are what stops this being a ban on
  jumping into anything: leaving a branch outwards, and jumping within one
  compound statement, are both still fine. }
program GotoBranches(output);
label 1, 2, 3, 4;
var i : integer;
begin
  i := 0;

  { Legal, c): the label is a statement of the block's own sequence, so a goto
    anywhere inside may leave outwards to it. }
  if i = 0 then
    goto 3;
3:

  { Legal, b): both are statements of one compound statement's sequence. }
  if i = 0 then
  begin
    goto 4;
4:  i := i + 1
  end;

  { §6.8.1: neither branch of an if is a statement-sequence. }
  if i = 0 then
1:  i := 1
  else
    goto 1;

  { and the same rule in a case statement's arms }
  case i of
    0: goto 2;
    1: begin
2:      i := 2
       end
  end;
  writeln(i:1)
end.
