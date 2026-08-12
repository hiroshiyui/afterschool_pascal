{ §6.7.6.9 gives the result "an implementation-defined length", singular — one
  length for the implementation and not one per value. This one is ten
  characters of ISO 8601, so the year has four digits and a year outside
  1..9999 has no representation at all. Refusing it is the reading of "not a
  valid calendar date" that keeps the length fixed; see ADR-0065.

  `year` is an `integer` and not a subrange, so nothing earlier can refuse it:
  this is the one field of a TimeStamp whose type does not bound it. }
program trap_date_year(output);
var t: TimeStamp;
begin
  t.year := 9999;
  t.month := 12;
  t.day := 31;
  writeln('the last one: ', date(t));
  t.year := 10000;
  writeln('and past it: ', date(t))
end.
