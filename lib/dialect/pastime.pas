{ PasTime -- arithmetic on a calendar date, and a form a date can be written
  in and read back from.

  doc/roadmap.md's row said what was missing and what it was missing from:
  6.4.3.4's TimeStamp is a required record-type, 6.7.5.8's GetTimeStamp fills
  one from the clock, and 6.7.6.9's `date` and `time` write two halves of it as
  text -- and that is the whole of the calendar either standard has. Nothing
  adds a day to a date, nothing says how many days lie between two, nothing
  reads a date back, and nothing shifts one into another zone.

  This module is those four, over the record the standard already has. It
  declares no type of its own for a date and it is deliberate: a second one
  would mean a conversion at every call from a program that had asked the
  clock, and TimeStamp already carries the eight numbers with six of them in
  subranges that refuse a thirteenth month at the store (ADR-0018).

  **A serial day number is what makes any of it possible.** A civil date is
  three numbers whose carrying rules are irregular -- twelve month lengths,
  one of which depends on the year, by a rule that depends on the century --
  so nothing can be added to it directly. Counting days from a fixed day turns
  every one of those questions into a subtraction. `DayNumberOf` and
  `StampOfDayNumber` are that count and its inverse, and every other routine
  here is written over them; a caller doing its own arithmetic should use them
  the same way.

  Day 1 is the 1st of January, year 1, in the proleptic Gregorian calendar,
  and day 3652059 is the 31st of December, 9999. Both ends are borrowed rather
  than chosen: 6.7.5.8 names 'January 1, 1' as the date a stamp carries when
  the clock could not supply one, and this processor's `date` writes four
  digits of year, so a year outside 1..9999 has no representation for
  `FormatStamp` to produce (D.36, D.37, and runtime/pasrt.c's own comment on
  the bound). A count that started anywhere else would put the fallback date at
  an arbitrary number and the two ends of the range at two more.

  **Nothing here reads the clock**, and that is why the module needs no C at
  all. GetTimeStamp is the one call that has to, it is in the language, and a
  routine here wrapping it would add nothing but a second name for it.

  **On zones, and why there is no local one.** `Shift` is the whole of what is
  offered: a stamp and a number of minutes, answering the same instant written
  as another offset's wall clock. What is *not* offered is the offset the
  machine is in, and the decision is worth reading before adding it.

  It cannot be had here. C's `localtime` answers a `struct tm`, and ADR-0185's
  fifth decision refuses a library module a foreign struct -- `struct tm` is
  ISO C's, so its first nine members are fixed, but glibc adds two more and a
  module declaring it would still be one platform's layout written where nobody
  can check it. So it would have to be a `pasx_` routine in
  runtime/pasrt_posix.c (ADR-0186), which is a cost the module could pay.

  The reason not to is that it would answer a number no oracle here can
  contradict. A local offset is a property of the machine and of the moment --
  it changes twice a year in half the world, by rules that change with politics
  -- so a test could print it only by asking the same routine, which is
  tests/dialect/lib_process.pas's rule about output that varies per run. And it
  would be a *worse* answer than the language already gives: GetTimeStamp
  already samples the clock in local time on this processor, so a program
  wanting the local wall clock has it, and what it lacked was arithmetic.

  What a zone *is*, beyond one offset, is a database of when the offsets
  changed, which no module can carry and no C call can hand over as a value.
  So an offset the caller states is not a poorer answer than a zone name would
  be; it is the honest form of the same answer, and the one a stored timestamp
  should have been written with in the first place.

  Like every module under lib/dialect/ it is dialect-only -- AP 6.4.13's
  fallible types are this dialect's and their safety is ADR-0118's
  authoritative tag, which no standard Pascal gives (ADR-0119, ADR-0120). It
  reaches outside the program for nothing, which puts it with `pascontainer`,
  `pasjson` and `paslsp` rather than with the modules that bind C. }

module PasTime;

export PasTime = (MinYear, MaxYear, MinDayNumber, MaxDayNumber, MaxOffset,
                  DayNumber, StampText, DayName,
                  { 6.11.2: an enumerated type's values are constants of their
                    own and are exported one by one -- the type name alone
                    carries none of them, which is why PasError lists all six
                    of its codes beside ErrorCode. }
                  WeekDay, dwMonday, dwTuesday, dwWednesday, dwThursday,
                  dwFriday, dwSaturday, dwSunday,
                  DayResult, StampResult, TextResult,
                  IsLeapYear, DaysInMonth, IsValidDate, IsValidTime,
                  MakeStamp, DayNumberOf, StampOfDayNumber,
                  AddDays, DaysBetween, DayOfWeek, WeekDayName, DayOfYear,
                  Shift, FormatStamp, ParseStamp);

{ 6.11.1 puts the import-part inside the module-block, after the export-part. }
import PasError;

const
  { The years a stamp can be written in, and therefore the years this module
    will build one in. Not a choice: 6.7.6.9 makes `date`'s representation
    implementation-defined and this one is four digits of year, so 10000 and 0
    have nowhere to go. The calendar has no year 0 either way. }
  MinYear = 1;
  MaxYear = 9999;

  { The two ends of MinYear..MaxYear as day numbers, so a caller can bound a
    loop or a subtraction without building a stamp to ask. Written out rather
    than computed because a constant-expression cannot call a function, and
    checked against the routine in tests/dialect/lib_time.pas rather than
    trusted. }
  MinDayNumber = 1;
  MaxDayNumber = 3652059;

  { The largest offset from UTC that can be written as hh:mm, which is the
    bound `Shift` accepts in either direction. Real offsets run from -12:00 to
    +14:00 and no rule says they must, so the limit taken here is the one the
    notation imposes rather than the one the world currently uses. }
  MaxOffset = 1439;

  { Minutes in a day, the modulus every time-of-day carry is taken over. }
  MinutesPerDay = 1440;

type
  { A count of days, day 1 being the 1st of January, year 1. An integer and
    not a type of its own: a caller subtracts two of them, which is the whole
    point of having it, and a distinct type would refuse that. }
  DayNumber = integer;

  { What `FormatStamp` writes and `ParseStamp` reads: nineteen characters,
    `YYYY-MM-DDThh:mm:ss`. Fixed width, so the length is a constant and a
    caller can declare a field for one. }
  StampText = string(19);

  { Long enough for 'Wednesday'. }
  DayName = string(9);

  { The days of the week, Monday first, because that is the order
    ISO 8601 numbers them in and because DayOfWeek is a remainder and a
    remainder has to start somewhere -- day 1 of this count, the 1st of
    January of year 1, was a Monday, so Monday first is also the arithmetic's
    own answer and needs no adjustment. }
  WeekDay = (dwMonday, dwTuesday, dwWednesday, dwThursday, dwFriday,
             dwSaturday, dwSunday);

  { ADR-0120's shape, written by the language since AP 6.4.13 (ADR-0176): the
    tag is `ok`, the value `val` and the reason `cause` in every module here,
    and reading the wrong one stops the program rather than answering storage
    (ADR-0118).

    Three payloads and no more: what a routine here answers is a day count, a
    stamp, or the text of one. }
  DayResult = Fallible(DayNumber);
  StampResult = Fallible(TimeStamp);
  TextResult = Fallible(StampText);

{ --- questions about the calendar, which cannot fail ---------------------- }

{ Whether `year` has a 29th of February, by the Gregorian rule: every fourth
  year, except every hundredth, except every four-hundredth.

  Answered for any integer, including years outside MinYear..MaxYear and
  negative ones, because the rule is arithmetic and has no opinion about the
  range -- a caller checking a year before building a stamp should not have to
  build one first. Whether such a year can be *written* is IsValidDate's
  question and not this one. }
function IsLeapYear(year: integer): boolean;

{ How many days `month` has in `year`, and **0 for a month outside 1..12**.

  0 is an answer no month has, so it cannot be mistaken for one, and it is
  what lets this routine take plain integers: a caller holding a month from a
  TimeStamp has the subrange 1..12 behind it and can never see the 0, while a
  caller holding a number it has not checked gets an answer rather than the
  trap a subrange parameter would have given it. That is the same reading
  PasFS takes of a bound it can check, one step further: the check is here
  because the caller's number came from outside. }
function DaysInMonth(year, month: integer): integer;

{ Whether the three numbers name a day of the calendar this module can write:
  the year within MinYear..MaxYear, the month within 1..12, and the day within
  the length of that month in that year.

  This is 6.7.6.9's error condition for `date` asked as a question instead. The
  clause makes an invalid date an *error*, which stops the program; a library
  may not do that to a caller holding a number it has not checked, so every
  routine here that would have reached it asks this first. }
function IsValidDate(year, month, day: integer): boolean;

{ Whether the three numbers name a time of day: 0..23, 0..59 and 0..59.

  A leap second is not one. 6.4.3.4 gives the `second` field the subrange
  0..59 and NOTE 5 leaves a processor free to report leap seconds in a field
  of its own, which this one has not got -- so 60 is refused here for the same
  reason the runtime clamps it there. }
function IsValidTime(hour, minute, second: integer): boolean;

{ --- the two conversions everything else is written over ------------------ }

{ A stamp from six numbers, or the reason they are not a date and a time.

  `errRange` for anything IsValidDate or IsValidTime refuses. It is a range
  and not a syntax failure because the numbers arrived as numbers: nothing was
  misread, the values are simply not a day.

  Both DateValid and TimeValid are true in the answer. A caller wanting one
  half is asking for a stamp the clock could not supply, which is what
  ParseStamp produces from a string carrying only one half. }
function MakeStamp(year, month, day, hour, minute, second: integer)
  = r: StampResult;

{ The day number of a stamp's date -- the count of days from the 1st of
  January, year 1, that day being 1.

  `errAbsent` when DateValid is false, because 6.7.5.8 then says the three
  date fields are 'January 1, 1' *whatever the date is*, so the record is
  telling this routine that its date means nothing; answering 1 would be
  reading storage the clause disclaims. `errRange` when the fields are not a
  calendar date, which for a stamp is a year outside MinYear..MaxYear or a
  29th of February in a year that has none -- the subranges 1..12 and 1..31
  have already refused everything else at the store.

  The time of day is not read and does not matter. Two stamps of the same date
  have the same day number whatever hour they carry, which is what makes
  DaysBetween count days and not fractions of one. }
function DayNumberOf(t: TimeStamp) = r: DayResult;

{ The date a day number names, at midnight, with TimeValid false.

  `errRange` outside MinDayNumber..MaxDayNumber. The flags are 6.7.5.8's own
  distinction used for what it says: the date is known and the time is not,
  so the stamp carries midnight and says so, exactly as a stamp from a clock
  with no time does. A caller with a time to put in it assigns the three
  fields, or uses AddDays, which keeps the ones it was given. }
function StampOfDayNumber(n: DayNumber) = r: StampResult;

{ --- arithmetic ----------------------------------------------------------- }

{ `t` moved `days` days, forward for a positive count and backward for a
  negative one. One routine for both directions because it is one operation:
  a separate SubtractDays would be a second name for a negation, and a caller
  computing an interval has a signed number already.

  The time of day, and both validity flags, are the ones `t` carried: adding a
  day to a stamp does not make its time known or unknown. `errRange` where the
  answer would leave MinYear..MaxYear, checked against the day count before
  the addition rather than after, since forming a sum above maxint would trap
  (ADR-0014). `errAbsent` where `t` has no date, from DayNumberOf. }
function AddDays(t: TimeStamp; days: integer) = r: StampResult;

{ How many days from `fromStamp` to `toStamp` -- negative when `toStamp` is
  the earlier. The difference of the two day numbers, so the times of day are
  not read and a partial day counts for nothing: from 23:00 on Monday to 01:00
  on Tuesday is one day, which is the answer a calendar gives and not the one
  a clock does.

  The cause of whichever operand has no day number, `fromStamp` first. }
function DaysBetween(fromStamp, toStamp: TimeStamp) = r: DayResult;

{ Which day of the week a day number falls on.

  Total, and for every value of the type rather than only for
  MinDayNumber..MaxDayNumber: the week has no ends, and the seven-day cycle
  extends through day 0 and past MaxDayNumber whatever the calendar does with
  the years there. That is worth the two extra remainders it costs -- see the
  implementation, where the obvious `(n - 1) mod 7` is what those remainders
  replace, because n - 1 at the bottom of the integer type would trap. }
function DayOfWeek(n: DayNumber): WeekDay;

{ The English name of a day, capitalised. Here rather than left to the caller
  because a case-statement over an enumeration is the one thing this dialect
  will not let go wrong quietly -- a value with no arm stops the program
  (ADR-0018) -- so the seven names are written once where adding an eighth day
  would be caught. }
function WeekDayName(w: WeekDay): DayName;

{ Which day of its own year a stamp falls on: 1 for the 1st of January, 365 or
  366 for the 31st of December.

  The same cause DayNumberOf would have given, for the same stamp. }
function DayOfYear(t: TimeStamp) = r: DayResult;

{ --- offsets -------------------------------------------------------------- }

{ The instant `t` names, written as the wall clock of a place `minutes` east
  of the one `t` was written for. A negative count is west.

  `errRange` for an offset outside -MaxOffset..MaxOffset. `errAbsent` unless
  **both** flags are true, which is the one place this module insists on the
  time as well as the date: a shift crosses midnight, and a stamp with no date
  has nowhere to put the day it crossed into.

  This is the whole of the zone handling here, and the module header says why
  there is no local offset to pass it. }
function Shift(t: TimeStamp; minutes: integer) = r: StampResult;

{ --- text ----------------------------------------------------------------- }

{ A stamp as `YYYY-MM-DDThh:mm:ss` -- ISO 8601's combined form, which is the
  one thing 6.7.6.9 does not write: `date` gives the first ten characters and
  `time` the last eight, and nothing joins them.

  It answers a result rather than the text because **`date(t)` stops the
  program** on a stamp whose fields are not a calendar date, and a library may
  not do that to its caller. `errRange` is that condition reported instead;
  `errAbsent` where either flag is false, since a combined form would be
  claiming a half the record says it has not got.

  The two halves are `date(t)` and `time(t)` themselves, after the check, so
  the spelling here and the spelling the required functions produce cannot
  come to differ. What is added is the `T`, which ISO 8601 requires and which
  ParseStamp reads back. No zone designator is written: the type has no field
  to hold an offset, so one written here would be a claim the stamp does not
  carry. }
function FormatStamp(t: TimeStamp) = r: TextResult;

{ A stamp read back from one of three forms, and the flags say which was
  given:

      YYYY-MM-DD            DateValid, midnight, TimeValid false
      hh:mm:ss              TimeValid, 'January 1, 1', DateValid false
      YYYY-MM-DDThh:mm:ss   both

  The third accepts a space where the `T` is, which RFC 3339 section 5.6
  permits for a form meant to be read by people; `FormatStamp` writes only the
  `T`, so a round trip is exact either way.

  `errSyntax` for anything that is not one of the three, which includes a
  surrounding space, a sign, a fractional second and a zone designator. A zone
  is refused rather than ignored, and that is the decision worth reading: this
  module has no field to put an offset in, so accepting `+01:00` would mean
  discarding it, and a time silently moved by an hour is a worse answer than a
  refusal. A caller holding an offset calls Shift with it.

  `errRange` for a well-formed string whose numbers are not a date or a time
  -- the 29th of February in an ordinary year, the 25th hour -- which is the
  distinction PasError draws between the two codes and the reason the set is
  worth having. }
function ParseStamp(s: string) = r: StampResult;

end;

{ The formula, and its inverse, in the one place each. Not exported: what a
  caller wants is the pair of routines above, which know about the flags, the
  range and the codes; these two know about nothing but the arithmetic and are
  correct only for arguments those routines have already checked.

  Both are the standard Julian-day conversions with the epoch moved. They work
  by shifting the year to start in March, which puts the short month at the
  end where its irregular length stops interrupting the count, and by folding
  the four-, hundred- and four-hundred-year cycles into one division each.
  1721425 is the Julian day number of the day before the 1st of January of
  year 1, so subtracting it makes that day 1. }
function RataDie(year, month, day: integer): DayNumber;
var shifted, yy, mm: integer;
begin
  { 1 for January and February, which belong to the previous shifted year }
  shifted := (14 - month) div 12;
  yy := year + 4800 - shifted;
  mm := month + 12 * shifted - 3;
  RataDie := day + (153 * mm + 2) div 5 + 365 * yy
             + yy div 4 - yy div 100 + yy div 400 - 32045 - 1721425
end;

procedure CivilOf(n: DayNumber; var year, month, day: integer);
var a, b, c, d, e, m: integer;
begin
  a := n + 1721425 + 32044;
  b := (4 * a + 3) div 146097;                  { four-hundred-year cycles }
  c := a - (146097 * b) div 4;
  d := (4 * c + 3) div 1461;                    { four-year cycles }
  e := c - (1461 * d) div 4;
  m := (5 * e + 2) div 153;                     { the shifted month, 0..11 }
  day := e - (153 * m + 2) div 5 + 1;
  { m is 10 for January and 11 for February, the two that were shifted }
  month := m + 3 - 12 * (m div 10);
  year := 100 * b + d - 4800 + m div 10
end;

{ `count` decimal digits of `s` from `at`, as a number. False where any of them
  is not a digit, and the caller has already made sure the positions exist --
  every call below is guarded by the length of the whole string, which is what
  makes the three forms distinguishable before any character is looked at. }
function Digits(s: string; at, count: integer; var v: integer): boolean;
var i, acc: integer; good: boolean;
begin
  acc := 0;
  good := true;
  for i := at to at + count - 1 do
    if (s[i] >= '0') and (s[i] <= '9') then
      acc := acc * 10 + (ord(s[i]) - ord('0'))
    else
      good := false;
  v := acc;
  Digits := good
end;

function IsLeapYear;
begin
  IsLeapYear := (year mod 4 = 0)
                and ((year mod 100 <> 0) or (year mod 400 = 0))
end;

function DaysInMonth;
begin
  if (month < 1) or (month > 12) then
    DaysInMonth := 0
  else if month = 2 then begin
    if IsLeapYear(year) then DaysInMonth := 29 else DaysInMonth := 28
  end
  else if (month = 4) or (month = 6) or (month = 9) or (month = 11) then
    DaysInMonth := 30
  else
    DaysInMonth := 31
end;

function IsValidDate;
begin
  { The month is not tested here and does not need to be: DaysInMonth answers
    0 for a month outside 1..12, and no day is both at least 1 and at most 0.
    That is the whole reason that routine has an answer for an impossible
    month rather than a trap. }
  IsValidDate := (year >= MinYear) and (year <= MaxYear)
                 and (day >= 1) and (day <= DaysInMonth(year, month))
end;

function IsValidTime;
begin
  IsValidTime := (hour >= 0) and (hour <= 23)
                 and (minute >= 0) and (minute <= 59)
                 and (second >= 0) and (second <= 59)
end;

function MakeStamp;
var t: TimeStamp;
begin
  if not IsValidDate(year, month, day) then
    r := errRange
  else if not IsValidTime(hour, minute, second) then
    r := errRange
  else begin
    t.DateValid := true;
    t.TimeValid := true;
    t.year := year;
    t.month := month;
    t.day := day;
    t.hour := hour;
    t.minute := minute;
    t.second := second;
    { One assignment decides the outcome: the write to the field is what sets
      the tag (ADR-0118), so there is no r.ok to forget and none to disagree
      with the payload. }
    r := t
  end
end;

function DayNumberOf;
begin
  if not t.DateValid then
    r := errAbsent
  else if not IsValidDate(t.year, t.month, t.day) then
    r := errRange
  else
    r := RataDie(t.year, t.month, t.day)
end;

function StampOfDayNumber;
var t: TimeStamp; y, m, d: integer;
begin
  if (n < MinDayNumber) or (n > MaxDayNumber) then
    r := errRange
  else begin
    CivilOf(n, y, m, d);
    t.DateValid := true;
    t.TimeValid := false;
    t.year := y;
    t.month := m;
    t.day := d;
    t.hour := 0;
    t.minute := 0;
    t.second := 0;
    r := t
  end
end;

function AddDays;
var dn: DayResult; t2: TimeStamp; y, m, d: integer;
begin
  dn := DayNumberOf(t);
  if not dn.ok then
    r := dn.cause
  { Written as two subtractions rather than as a sum compared with the bounds:
    a day number is at most MaxDayNumber and `days` may be any integer, so
    forming dn.val + days first could overflow and trap (ADR-0014). Both
    differences here are between values of the day range and cannot. }
  else if (days > MaxDayNumber - dn.val) or (days < MinDayNumber - dn.val) then
    r := errRange
  else begin
    CivilOf(dn.val + days, y, m, d);
    { the whole stamp, so the time of day and both flags survive the move }
    t2 := t;
    t2.year := y;
    t2.month := m;
    t2.day := d;
    r := t2
  end
end;

function DaysBetween;
var a, b: DayResult;
begin
  a := DayNumberOf(fromStamp);
  b := DayNumberOf(toStamp);
  if not a.ok then
    r := a.cause
  else if not b.ok then
    r := b.cause
  else
    { both are within MinDayNumber..MaxDayNumber, so the difference is too }
    r := b.val - a.val
end;

function DayOfWeek;
begin
  { `(n - 1) mod 7` says it more plainly and is wrong at one value: n at the
    bottom of the integer type makes n - 1 outside it, which traps. Taking the
    remainder first keeps every intermediate in 0..12. `mod` here yields a
    non-negative result whatever the sign of its left operand, which is what
    makes one expression serve day 0 and day -1 as well as the calendar's. }
  DayOfWeek := succ(dwMonday, ((n mod 7) + 6) mod 7)
end;

function WeekDayName;
begin
  case w of
    dwMonday:    WeekDayName := 'Monday';
    dwTuesday:   WeekDayName := 'Tuesday';
    dwWednesday: WeekDayName := 'Wednesday';
    dwThursday:  WeekDayName := 'Thursday';
    dwFriday:    WeekDayName := 'Friday';
    dwSaturday:  WeekDayName := 'Saturday';
    dwSunday:    WeekDayName := 'Sunday'
  end
end;

function DayOfYear;
var dn: DayResult;
begin
  dn := DayNumberOf(t);
  if not dn.ok then
    r := dn.cause
  else
    r := dn.val - RataDie(t.year, 1, 1) + 1
end;

function Shift;
var total, carry: integer; moved: StampResult; t2: TimeStamp;
begin
  if (minutes < -MaxOffset) or (minutes > MaxOffset) then
    r := errRange
  else if not (t.DateValid and t.TimeValid) then
    r := errAbsent
  else begin
    total := t.hour * 60 + t.minute + minutes;
    { Floor division, spelled out. `div` truncates toward zero and `mod` is
      non-negative, so subtracting the remainder before dividing is what turns
      the pair into the floor and the modulus -- and it is exact rather than a
      correction, because the remainder is by definition what the floor leaves.
      With an offset bounded by MaxOffset the carry is -1, 0 or 1. }
    carry := (total - (total mod MinutesPerDay)) div MinutesPerDay;
    total := total mod MinutesPerDay;
    moved := AddDays(t, carry);
    if not moved.ok then
      r := moved.cause
    else begin
      t2 := moved.val;
      t2.hour := total div 60;
      t2.minute := total mod 60;
      r := t2
    end
  end
end;

function FormatStamp;
begin
  if not (t.DateValid and t.TimeValid) then
    r := errAbsent
  else if not IsValidDate(t.year, t.month, t.day) then
    r := errRange
  else
    { after the check, and only after it: `date` treats an invalid date as
      6.7.6.9's error and stops the program }
    r := date(t) + 'T' + time(t)
end;

function ParseStamp;
var n, y, mo, d, h, mi, se: integer; sep: char;
    hasDate, hasTime, bad: boolean; t: TimeStamp;
begin
  n := length(s);
  hasDate := false;
  hasTime := false;
  bad := false;
  { 6.7.5.8's fallbacks, so a half that was not given is the one the clause
    names rather than whatever the frame held }
  y := 1; mo := 1; d := 1;
  h := 0; mi := 0; se := 0;

  { The length picks the form before a character is read, which is what lets
    every position below be indexed without a further guard. }
  if (n = 10) or (n = 19) then begin
    hasDate := true;
    if not (Digits(s, 1, 4, y) and (s[5] = '-') and Digits(s, 6, 2, mo)
            and (s[8] = '-') and Digits(s, 9, 2, d)) then
      bad := true
  end;
  if n = 8 then begin
    hasTime := true;
    if not (Digits(s, 1, 2, h) and (s[3] = ':') and Digits(s, 4, 2, mi)
            and (s[6] = ':') and Digits(s, 7, 2, se)) then
      bad := true
  end
  else if n = 19 then begin
    hasTime := true;
    sep := s[11];
    if not ((sep = 'T') or (sep = ' ')) then bad := true;
    if not (Digits(s, 12, 2, h) and (s[14] = ':') and Digits(s, 15, 2, mi)
            and (s[17] = ':') and Digits(s, 18, 2, se)) then
      bad := true
  end;
  if not (hasDate or hasTime) then bad := true;

  if bad then
    r := errSyntax
  else if hasDate and not IsValidDate(y, mo, d) then
    r := errRange
  else if hasTime and not IsValidTime(h, mi, se) then
    r := errRange
  else begin
    t.DateValid := hasDate;
    t.TimeValid := hasTime;
    t.year := y;
    t.month := mo;
    t.day := d;
    t.hour := h;
    t.minute := mi;
    t.second := se;
    r := t
  end
end;

end.
