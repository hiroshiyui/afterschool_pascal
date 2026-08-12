{ ISO/IEC 10206:1991 §6.7.6.9: "It shall be an error if the fields day, month,
  and year of t do not represent a valid calendar date."

  This is the part of that condition the field types cannot express. Both 2 and
  29 are values of `month` and `day` — 1..12 and 1..31 — so nothing traps at
  the stores; it is the *combination* with a non-leap year that has no such
  date, and only `date` is in a position to notice. }
program trap_date(output);
var t: TimeStamp;
begin
  t.year := 2024;
  t.month := 2;
  t.day := 29;
  writeln('a leap year: ', date(t));
  t.year := 2023;
  writeln('not a leap year: ', date(t))
end.
