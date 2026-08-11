{ §6.4.6 d): if T1 and T2 are produced from the same schema but not with the
  same tuple, an assignment between them is a *dynamic-violation*. Where both
  tuples are known the compiler refuses the program; where they are not, this
  is what the comparison does when it fails. §6.1's f) 2) is the permission to
  report it during execution, and it terminates the program. }
program TrapSchemaAssign(output);
type vector(n: integer) = array [1..n] of integer;

var a: vector(3);
    b: vector(4);
    i: integer;

procedure copy(var dst: vector; var src: vector);
begin
  { One compiled body, and both tuples arrive with the actuals — so whether
    these are the same type is not a question this text can answer. }
  dst := src;
  writeln('copied ', src.n:1, ' into ', dst.n:1)
end;

begin
  for i := 1 to 3 do a[i] := i;
  for i := 1 to 4 do b[i] := 0;
  copy(a, a);
  copy(b, a)
end.
