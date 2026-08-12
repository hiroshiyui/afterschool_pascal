{ The other arm of ISO/IEC 10206:1991 §6.7.5.8, which no other case reaches.

  The clause offers `GetTimeStamp` two answers: a value whose DateValid is true
  and whose fields are the current date, "or a value whose field DateValid
  represents the value false and whose fields day, month, and year represent
  the date `January 1, 1'". The second arm exists for a processor that cannot
  tell what day it is, and on a working machine the clock never fails — so
  `timestamp.pas` can only check the disjunction, and always checks it on the
  side that happened to be taken.

  Defining "current" from SOURCE_DATE_EPOCH (see ADR-0065) is what makes the
  other side reachable, and reachable deterministically. The number below is
  the largest a signed 64-bit count of seconds can hold: it parses, so it is
  not the ill-formed case `timestamp_badepoch.pas` covers, but no calendar can
  place it — a year some three hundred thousand million long does not fit the
  representation, and the conversion refuses it. The variable named an instant,
  the instant does not exist, and DateValid false is precisely what §6.7.5.8
  provides for.

  So this fixes every one of the eight fields on a path nothing else executes,
  including the fallback year, which is the field the clause names and the one
  a reader is most likely to think of as arbitrary. }
program timestamp_invalid(output);
var t: TimeStamp;
begin
  GetTimeStamp(t);

  { §6.7.5.8's second arm, field by field. The two valid-flags move together
    here because the one thing that can fail is the conversion, and it supplies
    neither the date nor the time. }
  writeln('DateValid: ', t.DateValid);
  writeln('TimeValid: ', t.TimeValid);
  writeln('year:      ', t.year:1);
  writeln('month:     ', t.month:1);
  writeln('day:       ', t.day:1);
  writeln('hour:      ', t.hour:1);
  writeln('minute:    ', t.minute:1);
  writeln('second:    ', t.second:1);

  { `January 1, 1' is a valid calendar date, so §6.7.6.9's two functions are
    defined on it and this is what they write. It is also the smallest date
    this representation can spell, which is why the year check in `pas_date`
    admits 1 rather than starting at 1970. }
  writeln('date:      ', date(t));
  writeln('time:      ', time(t))
end.
