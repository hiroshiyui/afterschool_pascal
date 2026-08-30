{ PasTime. Every number here is one a reader can check against a calendar, and
  none of them is the current date: what the clock says is a property of the
  moment and not of the module, which is tests/dialect/lib_process.pas's rule
  for the same reason. The clock is touched once, and what is printed about it
  is a disjunction that is true whichever arm 6.7.5.8 took.

  The dates are chosen to be the ones that go wrong. 1900 is divisible by four
  and is not a leap year; 2000 is divisible by a hundred and is. The 29th of
  February exists in 2024 and not in 2023, and adding one day to the 28th
  therefore lands in two different months. Day 1 is the 1st of January of year
  1 and day 3652059 is the 31st of December of 9999, so the two constants are
  checked against the routine rather than believed. 719163 is the 1st of
  January 1970, which was a Thursday; 730120 is the 1st of January 2000, which
  was a Saturday; and 10957 is the number of days between them, which is the
  one number here that a reader is more likely to know than to compute. }
program lib_time(output);

import PasError;
       PasTime;

var
  s, u: StampResult;
  dn: DayResult;
  clock, broken: TimeStamp;
  w: WeekDay;

procedure showStamp(what: string; r: StampResult);
begin
  write(what, ': ');
  { `date` and `time` are safe on every successful result: each producer here
    either validated the fields or built them from a day number. }
  if r.ok then
    writeln(date(r.val), ' ', time(r.val), '  DateValid ', r.val.DateValid,
            ' TimeValid ', r.val.TimeValid)
  else
    writeln('failed, ', ErrorText(r.cause))
end;

procedure showDay(what: string; r: DayResult);
begin
  write(what, ': ');
  if r.ok then writeln(r.val:1) else writeln('failed, ', ErrorText(r.cause))
end;

procedure showText(what: string; r: TextResult);
begin
  write(what, ': ');
  if r.ok then writeln('[', r.val, ']')
  else writeln('failed, ', ErrorText(r.cause))
end;

{ A date's day number in one call, for the rows that are about the count and
  not about the stamp. }
function dayOf(y, m, d: integer) = r: DayResult;
var made: StampResult;
begin
  made := MakeStamp(y, m, d, 0, 0, 0);
  if not made.ok then r := made.cause else r := DayNumberOf(made.val)
end;

{ The stamp itself, for the rows that then do arithmetic on it. Its date is
  one this program wrote, so it is always valid where it is used below. }
function stampOf(y, m, d, h, mi, se: integer): TimeStamp;
var made: StampResult;
begin
  made := MakeStamp(y, m, d, h, mi, se);
  stampOf := made.val
end;

begin
  writeln('--- leap years');
  writeln('1900: ', IsLeapYear(1900), '   2000: ', IsLeapYear(2000));
  writeln('2023: ', IsLeapYear(2023), '   2024: ', IsLeapYear(2024));
  writeln('1: ', IsLeapYear(1), '   4: ', IsLeapYear(4));

  writeln('--- days in a month');
  writeln('February 2024: ', DaysInMonth(2024, 2):1,
          '  February 1900: ', DaysInMonth(1900, 2):1,
          '  February 2000: ', DaysInMonth(2000, 2):1);
  writeln('April: ', DaysInMonth(2024, 4):1,
          '  December: ', DaysInMonth(2024, 12):1,
          '  January: ', DaysInMonth(2024, 1):1);
  writeln('month 0: ', DaysInMonth(2024, 0):1,
          '  month 13: ', DaysInMonth(2024, 13):1);

  writeln('--- what is a date, and what is a time');
  writeln('2024-02-29: ', IsValidDate(2024, 2, 29),
          '   2023-02-29: ', IsValidDate(2023, 2, 29));
  writeln('0000-01-01: ', IsValidDate(0, 1, 1),
          '   10000-01-01: ', IsValidDate(10000, 1, 1));
  writeln('2024-13-01: ', IsValidDate(2024, 13, 1),
          '   2024-04-31: ', IsValidDate(2024, 4, 31));
  writeln('23:59:59: ', IsValidTime(23, 59, 59),
          '   24:00:00: ', IsValidTime(24, 0, 0),
          '   00:00:60: ', IsValidTime(0, 0, 60));

  writeln('--- a stamp from six numbers');
  showStamp('2024-02-29 13:05:09', MakeStamp(2024, 2, 29, 13, 5, 9));
  showStamp('2023-02-29 00:00:00', MakeStamp(2023, 2, 29, 0, 0, 0));
  showStamp('2024-01-01 24:00:00', MakeStamp(2024, 1, 1, 24, 0, 0));

  writeln('--- the day count, and its two ends');
  showDay('0001-01-01', dayOf(1, 1, 1));
  showDay('1970-01-01', dayOf(1970, 1, 1));
  showDay('2000-01-01', dayOf(2000, 1, 1));
  showDay('2000-03-01', dayOf(2000, 3, 1));
  showDay('9999-12-31', dayOf(9999, 12, 31));
  writeln('MinDayNumber is 0001-01-01: ',
          dayOf(1, 1, 1).val = MinDayNumber);
  writeln('MaxDayNumber is 9999-12-31: ',
          dayOf(9999, 12, 31).val = MaxDayNumber);

  writeln('--- and back again');
  showStamp('day 1', StampOfDayNumber(1));
  showStamp('day 719163', StampOfDayNumber(719163));
  showStamp('day 730180', StampOfDayNumber(730180));
  showStamp('day 3652059', StampOfDayNumber(MaxDayNumber));
  showStamp('day 0', StampOfDayNumber(0));
  showStamp('day 3652060', StampOfDayNumber(MaxDayNumber + 1));

  writeln('--- every day of a leap February round-trips');
  dn := dayOf(2024, 2, 1);
  s := StampOfDayNumber(dn.val + 28);
  showStamp('1 February plus 28', s);

  writeln('--- adding and subtracting days');
  showStamp('2024-02-28 + 1', AddDays(stampOf(2024, 2, 28, 12, 0, 0), 1));
  showStamp('2023-02-28 + 1', AddDays(stampOf(2023, 2, 28, 12, 0, 0), 1));
  showStamp('1900-02-28 + 1', AddDays(stampOf(1900, 2, 28, 12, 0, 0), 1));
  showStamp('2000-02-28 + 1', AddDays(stampOf(2000, 2, 28, 12, 0, 0), 1));
  showStamp('2024-12-31 + 1', AddDays(stampOf(2024, 12, 31, 23, 59, 59), 1));
  showStamp('2000-03-01 - 1', AddDays(stampOf(2000, 3, 1, 0, 0, 0), -1));
  showStamp('2024-01-01 + 366', AddDays(stampOf(2024, 1, 1, 0, 0, 0), 366));
  showStamp('9999-12-31 + 1', AddDays(stampOf(9999, 12, 31, 0, 0, 0), 1));
  showStamp('0001-01-01 - 1', AddDays(stampOf(1, 1, 1, 0, 0, 0), -1));
  showStamp('0001-01-01 - maxint',
            AddDays(stampOf(1, 1, 1, 0, 0, 0), -maxint));

  writeln('--- the difference between two dates');
  showDay('1970-01-01 to 2000-01-01',
          DaysBetween(stampOf(1970, 1, 1, 0, 0, 0),
                      stampOf(2000, 1, 1, 0, 0, 0)));
  showDay('2000-01-01 to 1970-01-01',
          DaysBetween(stampOf(2000, 1, 1, 0, 0, 0),
                      stampOf(1970, 1, 1, 0, 0, 0)));
  showDay('2024-01-01 to 2025-01-01',
          DaysBetween(stampOf(2024, 1, 1, 0, 0, 0),
                      stampOf(2025, 1, 1, 0, 0, 0)));
  showDay('2023-01-01 to 2024-01-01',
          DaysBetween(stampOf(2023, 1, 1, 0, 0, 0),
                      stampOf(2024, 1, 1, 0, 0, 0)));
  writeln('a day is a day whatever the hour: ',
          DaysBetween(stampOf(2024, 3, 1, 23, 0, 0),
                      stampOf(2024, 3, 2, 1, 0, 0)).val:1);

  writeln('--- which day of the week');
  writeln('day 1 (0001-01-01): ', WeekDayName(DayOfWeek(1)));
  writeln('day 719163 (1970-01-01): ', WeekDayName(DayOfWeek(719163)));
  writeln('day 730120 (2000-01-01): ', WeekDayName(DayOfWeek(730120)));
  writeln('day 730180 (2000-03-01): ', WeekDayName(DayOfWeek(730180)));
  writeln('day 3652059 (9999-12-31): ', WeekDayName(DayOfWeek(MaxDayNumber)));
  write('a week from day 1:');
  for w := dwMonday to dwSunday do
    write(' ', WeekDayName(DayOfWeek(ord(w) + 1)));
  writeln;
  { The cycle has no ends: day 0 is the day before day 1, whatever the
    calendar does with the years there. }
  writeln('day 0: ', WeekDayName(DayOfWeek(0)),
          '   day -6: ', WeekDayName(DayOfWeek(-6)));

  writeln('--- which day of the year');
  showDay('2024-03-01', DayOfYear(stampOf(2024, 3, 1, 0, 0, 0)));
  showDay('2023-03-01', DayOfYear(stampOf(2023, 3, 1, 0, 0, 0)));
  showDay('2024-01-01', DayOfYear(stampOf(2024, 1, 1, 0, 0, 0)));
  showDay('2024-12-31', DayOfYear(stampOf(2024, 12, 31, 0, 0, 0)));
  showDay('2023-12-31', DayOfYear(stampOf(2023, 12, 31, 0, 0, 0)));

  writeln('--- writing one, and reading it back');
  showText('2024-02-29 13:05:09', FormatStamp(stampOf(2024, 2, 29, 13, 5, 9)));
  showText('0001-01-01 00:00:00', FormatStamp(stampOf(1, 1, 1, 0, 0, 0)));
  showStamp('parse 2024-02-29T13:05:09', ParseStamp('2024-02-29T13:05:09'));
  showStamp('parse with a space', ParseStamp('2024-02-29 13:05:09'));
  showStamp('parse a date alone', ParseStamp('2024-02-29'));
  showStamp('parse a time alone', ParseStamp('13:05:09'));
  s := ParseStamp('2024-02-29T13:05:09');
  showText('round trip', FormatStamp(s.val));
  writeln('the round trip is exact: ',
          FormatStamp(s.val).val = '2024-02-29T13:05:09');

  writeln('--- what a parse refuses, and with which code');
  showStamp('2023-02-29', ParseStamp('2023-02-29'));
  showStamp('2024-13-01', ParseStamp('2024-13-01'));
  showStamp('2024-02-29T25:00:00', ParseStamp('2024-02-29T25:00:00'));
  showStamp('13:05:60', ParseStamp('13:05:60'));
  showStamp('2024/02/29', ParseStamp('2024/02/29'));
  showStamp('20xx-02-29', ParseStamp('20xx-02-29'));
  showStamp('2024-02-29X13:05:09', ParseStamp('2024-02-29X13:05:09'));
  showStamp('a leading space', ParseStamp(' 2024-02-29'));
  showStamp('the empty string', ParseStamp(''));
  showStamp('a zone designator', ParseStamp('2024-02-29T13:05:09Z'));

  writeln('--- an offset, which is all a zone is here');
  showStamp('13:05 at -60', Shift(stampOf(2024, 2, 29, 13, 5, 9), -60));
  showStamp('00:30 at -60', Shift(stampOf(2024, 2, 29, 0, 30, 0), -60));
  showStamp('23:30 at +60', Shift(stampOf(2024, 2, 29, 23, 30, 0), 60));
  showStamp('00:00 at +330', Shift(stampOf(2024, 3, 1, 0, 0, 0), 330));
  showStamp('back again', Shift(stampOf(2024, 2, 28, 18, 30, 0), 330));
  showStamp('at +0', Shift(stampOf(2024, 2, 29, 13, 5, 9), 0));
  showStamp('at +1440', Shift(stampOf(2024, 2, 29, 13, 5, 9), 1440));
  showStamp('at -1440', Shift(stampOf(2024, 2, 29, 13, 5, 9), -1440));
  showStamp('past the last day',
            Shift(stampOf(9999, 12, 31, 23, 59, 59), 60));

  writeln('--- a stamp that says its date means nothing');
  s := ParseStamp('13:05:09');
  showDay('day number of a time', DayNumberOf(s.val));
  showStamp('a day added to a time', AddDays(s.val, 1));
  showText('a time formatted whole', FormatStamp(s.val));
  showStamp('a time shifted', Shift(s.val, 60));
  u := ParseStamp('2024-02-29');
  showText('a date formatted whole', FormatStamp(u.val));
  showStamp('a date shifted', Shift(u.val, 60));
  showDay('a time to a date',
          DaysBetween(s.val, stampOf(2024, 1, 1, 0, 0, 0)));
  showDay('a date to a time',
          DaysBetween(stampOf(2024, 1, 1, 0, 0, 0), s.val));

  writeln('--- fields that are in their subranges and are still not a date');
  { 2 and 29 are values of the fields 1..12 and 1..31, so the store cannot
    refuse them; that 2023 has no 29th of February is the one part of
    6.7.6.9's error condition a subrange cannot express. `date(broken)` here
    would stop the program, which is why FormatStamp exists. }
  broken.DateValid := true;
  broken.TimeValid := true;
  broken.year := 2023;
  broken.month := 2;
  broken.day := 29;
  broken.hour := 0;
  broken.minute := 0;
  broken.second := 0;
  showDay('day number', DayNumberOf(broken));
  showText('formatted', FormatStamp(broken));
  showStamp('a day added', AddDays(broken, 1));
  showDay('day of the year', DayOfYear(broken));
  showStamp('shifted', Shift(broken, 60));
  broken.year := 10000;
  broken.month := 1;
  broken.day := 1;
  showDay('a year with no representation', DayNumberOf(broken));

  writeln('--- the clock, which is the one thing that cannot be printed');
  GetTimeStamp(clock);
  dn := DayNumberOf(clock);
  { True on a machine whose clock works and true on one whose clock does not:
    6.7.5.8 leaves exactly those two arms, and this module answers errAbsent
    for the second because the record says its date means nothing. }
  writeln('the clock is a day this module can count: ',
          (clock.DateValid and dn.ok
           and (dn.val >= MinDayNumber) and (dn.val <= MaxDayNumber))
          or ((not clock.DateValid) and (not dn.ok)
              and (dn.cause = errAbsent)))
end.
