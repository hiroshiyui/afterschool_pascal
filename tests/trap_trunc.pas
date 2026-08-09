program TrapTrunc(output);
{ ISO 7185 6.6.6.2: trunc(x) is an error when the result is not a value of
  the integer type. It used to be a bare fptosi, which is poison out of range. }
var x: real;
begin
  writeln(trunc(2.75));
  x := 1.0E18;
  writeln(trunc(x))
end.
