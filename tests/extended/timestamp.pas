{ ISO/IEC 10206:1991 §6.7.5.8's time procedure and §6.7.6.9's two time
  functions, over §6.4.3.4's required record-type TimeStamp.

  Almost nothing about `GetTimeStamp` can be printed: the clock moves, so a
  golden file can only assert what the standard promises whatever the hour is.
  What it promises is the *fields* — "either a value whose field DateValid
  represents the value true and whose fields day, month, and year represent
  the current date ... or a value whose field DateValid represents the value
  false and whose fields day, month, and year represent the date January 1,
  1" — so that disjunction is what is checked here.

  The two functions are then exercised on a stamp built by hand, because
  §6.7.6.9 makes them a function of the record and of nothing else. }
program timestamp(output);
var
  t: TimeStamp;
  ok: boolean;
begin
  GetTimeStamp(t);

  { Every field is in range whichever arm of §6.7.5.8's disjunction was taken:
    the invalid answers are 'January 1, 1' and midnight, which are in range
    too. The subranges 1..12 and 1..31 already trapped at the store if not,
    so this asserts what a subrange cannot — that the parts agree. }
  ok := (t.month >= 1) and (t.month <= 12) and
        (t.day >= 1) and (t.day <= 31) and
        (t.hour >= 0) and (t.hour <= 23) and
        (t.minute >= 0) and (t.minute <= 59) and
        (t.second >= 0) and (t.second <= 59);
  writeln('fields in range: ', ok);

  { The fallbacks the clause names, and the only thing that can be printed
    about the value without knowing the time. }
  if not t.DateValid then
    ok := (t.year = 1) and (t.month = 1) and (t.day = 1)
  else
    ok := t.year >= 1970;
  writeln('date agrees with DateValid: ', ok);
  if not t.TimeValid then
    ok := (t.hour = 0) and (t.minute = 0) and (t.second = 0)
  else
    ok := true;
  writeln('time agrees with TimeValid: ', ok);

  { §6.7.5.8 promises the fields GetTimeStamp writes *are* a date, and §6.7.6.9
    makes date(t) an error when they are not — so calling it on a stamp just
    filled from the clock must always succeed. The results are compared rather
    than printed, because the date is different every day; both comparisons are
    true of every value the fields can hold, so what is being tested is that
    the calls *complete*.

    What *this* case cannot test is whether the fields are the right date: no
    program knows what day it is except by asking the same clock, so a month
    numbered from zero, as C's tm_mon is, is a valid date eleven months of the
    year and passes everything here. That is why timestamp_fixed.pas exists —
    it fixes the instant through SOURCE_DATE_EPOCH and names every field, which
    is the oracle from outside the program that this file cannot be. }
  writeln('the clock gives a valid date: ', date(t) >= '0001-01-01');
  writeln('the clock gives a valid time: ', time(t) <= '23:59:59');

  { §6.7.6.9: "an implementation-defined representation of the calendar date
    denoted by the value of t". Here that is ISO 8601, fixed width, so the
    length is a constant the compiler knows and `date(t)` costs one call. }
  t.year := 2024;
  t.month := 2;
  t.day := 29;
  t.hour := 13;
  t.minute := 5;
  t.second := 9;
  writeln('date: [', date(t), ']');
  writeln('time: [', time(t), ']');
  writeln('lengths: ', length(date(t)), ' ', length(time(t)));

  { The result is the canonical-string-type, so it is a value like any other
    string: comparable, assignable, concatenable, and truncated by a width. }
  writeln('equal: ', date(t) = '2024-02-29');
  writeln('both: ', date(t) + ' ' + time(t));
  writeln('narrow: [', date(t):7, ']');
  writeln('wide: [', time(t):10, ']');

  { February the 29th is a valid calendar date in 2024 and not in 2023, which
    is the one part of §6.7.6.9's error condition a subrange cannot express —
    both 2 and 29 are values of their fields either way. 2023 is tested by
    tests/extended/trap_date.pas, since it stops the program. }
  t.year := 2000;
  writeln('leap century: ', date(t));
  t.year := 2024;
  t.month := 12;
  t.day := 31;
  writeln('year end: ', date(t));
  t.year := 1;
  t.month := 1;
  t.day := 1;
  t.hour := 0;
  t.minute := 0;
  t.second := 0;
  writeln('the fallback date: ', date(t), ' ', time(t))
end.
