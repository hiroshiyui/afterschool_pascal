program TrapSucc(output);
{ ISO 7185 6.6.6.4: succ(x) is an error when x has no successor. }
var i: integer;
begin
  i := maxint;
  writeln(succ(i))
end.
