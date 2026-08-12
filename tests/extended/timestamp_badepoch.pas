{ The other half of this implementation's definition of "current".

  ISO/IEC 10206:1991 §6.7.5.8 leaves the meaning of the current date and time
  to the implementation, and this one reads them from SOURCE_DATE_EPOCH when
  that variable holds an integer. `timestamp_fixed.pas` is the case where it
  does; this is the case where it does not.

  A word that is not a number has no instant to name, so the definition falls
  back to the system clock. What makes the case worth writing is that C's
  `strtoll` answers 0 for a string it cannot parse at all — so an
  implementation that converts without asking whether the conversion consumed
  the whole word does not fall back, it silently claims the epoch itself, and
  every run of every program on the machine is then dated the 1st of January
  1970. That is a wrong answer rather than a refused one, which is the kind
  this corpus is least likely to notice.

  `timestamp_badepoch.epoch` holds such a word, and the assertion below is
  simply that the year is not 1970: the real clock is the only other thing it
  could have come from. The pair of tests pins the definition in both
  directions — `timestamp_fixed.pas` says a well-formed epoch is obeyed, and
  this one says an ill-formed one is ignored. }
program timestamp_badepoch(output);
var t: TimeStamp;
begin
  GetTimeStamp(t);
  writeln('valid: ', t.DateValid);
  writeln('the malformed epoch was ignored: ', t.year > 1970)
end.
