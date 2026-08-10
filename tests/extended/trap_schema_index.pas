{ A subscript is checked against the bounds the *actual* brought, so the
  message names bounds the compiler never knew. It is built by the runtime for
  that reason, and says exactly what the message for a known array says. }
program TrapSchemaIndex(output);
type vector(n: integer) = array [1..n] of integer;
var short: vector(2);

procedure past(var v: vector);
begin
  v[1] := 1;
  writeln('the first element is fine');
  v[v.n + 1] := 2
end;

begin
  past(short)
end.
