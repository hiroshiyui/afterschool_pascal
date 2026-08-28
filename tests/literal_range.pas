program LiteralRange(output);
{ 6.4.2.2: the integer types are -maxint..maxint and -maxint64..maxint64, so
  this literal has a value in neither -- and the message has to name the wider
  bound, that being the one actually exceeded. Until ADR-0232 the case was
  written one bound lower, because --std=iso7185 had no int64 to widen to. }
begin
  writeln(9223372036854775808)
end.
