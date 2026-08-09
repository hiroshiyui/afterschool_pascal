program TrapOverflow(output);
{ ISO 7185 6.7.2.2: arithmetic overflow is an error, not a wrap. }
var i: integer;
begin
  i := 46341;
  writeln(sqr(i))
end.
