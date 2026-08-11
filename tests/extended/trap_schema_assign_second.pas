{ §6.4.8 keys a produced type's identity on the *whole* tuple, so every
  discriminant is compared and not merely the one an array bound happened to
  use. Here the first agrees and the second does not, which is the case a
  comparison that stopped after the first would let through — and a mutation
  that did exactly that survived a green suite until this file existed. }
program TrapSchemaAssignSecond(output);
type grid(rows, cols: integer) = array [1..rows, 1..cols] of integer;

var a: grid(2, 3);
    b: grid(2, 4);
    i, j: integer;

procedure copy(var dst: grid; var src: grid);
begin
  dst := src;
  writeln('copied ', src.rows:1, 'x', src.cols:1)
end;

begin
  for i := 1 to 2 do
    for j := 1 to 4 do begin
      if j <= 3 then a[i, j] := 0;
      b[i, j] := i * j
    end;
  copy(a, a);
  copy(a, b)
end.
