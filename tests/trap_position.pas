program TrapPosition(output);

{ ADR-0293: a trap names the position of the construct that trapped, and the
  construct is the *subscript* and not the statement or the line. Two
  subscripts stand on one line and the second is the one out of range, so a
  position taken from the statement, the designator or the line's first
  subscript is a different column -- which is what makes this case fail for a
  wrong column and not only for a missing one. }

var
  a: array [1..3] of integer;
  i, j, x: integer;

begin
  a[1] := 10; a[2] := 20; a[3] := 30;
  i := 2; j := 4;
  writeln('before');
  x := a[i] + a[j];
  writeln(x)
end.
