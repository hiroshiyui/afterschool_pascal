{ ISO 7185 §6.7.2.5 gives the relational operators only to strings of one
  length, and this compiler diagnoses a mismatch wherever both lengths are
  written in the program. Where one is a discriminant it is the same
  requirement, made where the values are — because a comparison over the wrong
  number of characters answers rather than failing, which is exactly how the
  defect this test guards went unnoticed. }
program TrapSchemaString(output);
type str(n: integer) = packed array [1..n] of char;

var short: str(3);
    long: str(5);

procedure order(var x: str; var y: str);
begin
  if x = y then writeln('equal') else writeln('unequal')
end;

begin
  order(short, short);
  order(short, long)
end.
