program TrapDiv(output);
{ A zero divisor is an error; so is a quotient with no representable value. }
var i, j: integer;
begin
  i := 10; j := 0;
  writeln(i div j)
end.
