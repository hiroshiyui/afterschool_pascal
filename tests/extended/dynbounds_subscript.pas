{ A dynamically bounded array is bounds-checked like any other (ADR-0017): the
  bounds come from the descriptor rather than from the type, and the check is
  the same one. `m` is 3 here, so 4 is outside and the message says which
  bounds it was outside of -- built by the runtime, because only the running
  program knows them (ADR-0040). }
program DynBoundsSubscript(output);
procedure p(m: integer);
var a: array [1..m] of integer; i: integer;
begin
  for i := 1 to m do a[i] := i;
  writeln('filled ', a[m]:1);
  a[m + 1] := 0;
  writeln('unreached')
end;
begin p(3) end.
