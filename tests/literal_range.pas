program LiteralRange(output);
{ ISO 7185 6.4.2.2: the integer type is -maxint..maxint, so this literal has
  no value in the type -- it used to truncate silently to -2147483648. }
begin
  writeln(2147483648)
end.
