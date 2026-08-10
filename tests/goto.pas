program Jumps(output);
{ ISO 7185 6.1.6, 6.8.1 and 6.8.2.4: the label declaration part, a labelled
  statement, and `goto`. Only a goto within one block is implemented, which is
  what a program uses goto for anyway -- escaping a loop nest, and retrying
  from the top (ADR-0029). }

label 1, 2, 3, 4, 5, 6, 7;

var
  i, j, n, tries: integer;
  found: boolean;
  a: array [1..4, 1..4] of integer;

procedure Search(target: integer; var fi, fj: integer);
{ Each block has its own labels, so this `1` is not the `1` of the program. }
label 1;
var i, j: integer;
begin
  fi := 0;
  fj := 0;
  for i := 1 to 4 do
    for j := 1 to 4 do
      if i * j = target then begin
        fi := i;
        fj := j;
        goto 1
      end;
1:
end;

begin
  { a backward goto: the loop a `repeat` would otherwise be }
  n := 0;
  i := 0;
1:
  i := i + 1;
  n := n + i * i;
  if i < 6 then goto 1;
  writeln('sum of squares: ', n:1);

  { out of two nested loops at once, which is the case `break` cannot do }
  for i := 1 to 4 do
    for j := 1 to 4 do
      a[i, j] := i * 10 + j;
  found := false;
  for i := 1 to 4 do
    for j := 1 to 4 do
      if a[i, j] = 32 then begin
        found := true;
        goto 2
      end;
2:
  writeln('found ', found, ' at ', i:1, ',', j:1);

  { a forward goto over a whole statement }
  if n > 0 then goto 3;
  writeln('this line is skipped');
3:
  writeln('after the forward jump');

  { a goto out of a with, and out of a case arm }
  tries := 0;
4:
  tries := tries + 1;
  case tries of
    1: goto 4;
    2: goto 4;
    3: writeln('retried ', tries:1, ' times')
  end;

  { A label and its goto both nested inside the same statement -- the `next
    iteration` a Pascal program has no other way to write. The label is not at
    the top level of the block, so what makes this legal is that every
    statement containing it also contains the goto. }
  n := 0;
  for i := 1 to 6 do begin
    if (i = 2) or (i = 5) then goto 7;
    n := n + i;
7:
  end;
  writeln('skipping 2 and 5: ', n:1);

  { the labels of a nested block are its own }
  Search(12, i, j);
  writeln('search: ', i:1, ' ', j:1);
  Search(99, i, j);
  writeln('search: ', i:1, ' ', j:1);

  { A statement written after an unconditional goto is never executed -- and
    must not be emitted into the block the goto ends, or it would run. }
  goto 6;
  writeln('this never runs');
6:
  writeln('past the unconditional jump');

  { a label on the empty statement at the end of a block }
  if n > 0 then goto 5;
  writeln('also skipped');
5:
end.
