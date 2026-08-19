{ One over maxint64. The check is made *during* the accumulation, so a value
  that would have wrapped is reported rather than silently becoming another
  one -- which is the whole difference between this and testing after the
  multiply (ADR-0134). }
program Int64ReadTooBig(input, output);
var a: int64;
begin
  read(a);
  writeln('unreached ', a)
end.
