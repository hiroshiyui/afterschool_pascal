{ The mapping ISO/IEC 10206:1991 §6.7.5.8 actually specifies, tested against a
  date somebody chose rather than against the clock.

  `timestamp.pas` can only assert what is true of *every* moment, because it
  runs at whatever moment it runs at — and that turns out to be far weaker than
  it looks. A month taken straight from C's `tm_mon`, which counts from zero,
  names a different but perfectly real month eleven times out of twelve; a
  year, day, hour, minute or second off by one is the same. Every such error
  passes a range test, passes `date(t)`, and passes a golden file, because
  nothing in the program knows what the answer should have been.

  So this case fixes the answer. §6.7.5.8 makes the meaning of "current date"
  and "current time" implementation-defined, and this implementation defines
  them from SOURCE_DATE_EPOCH when it is set; `timestamp_fixed.epoch` sets it,
  and the harness exports it. The instant is 2001-02-03 04:05:06 UTC, chosen so
  that every field holds a different small number and no two of them can be
  swapped without the output changing.

  §6.4.3.4's field order is DateValid, TimeValid, year, month, day, hour,
  minute, second, and that order is what the code generator walks — so this is
  also the one test that would notice it being walked in any other. }
program timestamp_fixed(output);
var t: TimeStamp;
begin
  GetTimeStamp(t);
  writeln('DateValid: ', t.DateValid);
  writeln('TimeValid: ', t.TimeValid);
  writeln('year:      ', t.year:1);
  writeln('month:     ', t.month:1);
  writeln('day:       ', t.day:1);
  writeln('hour:      ', t.hour:1);
  writeln('minute:    ', t.minute:1);
  writeln('second:    ', t.second:1);

  { §6.7.6.9's two functions over the same known value, so the representation
    is pinned as well as the fields. }
  writeln('date:      ', date(t));
  writeln('time:      ', time(t));

  { A second call gives the same answer, because the instant is fixed — which
    is what makes the golden file possible and is worth asserting rather than
    assuming. }
  GetTimeStamp(t);
  writeln('again:     ', date(t), ' ', time(t))
end.
