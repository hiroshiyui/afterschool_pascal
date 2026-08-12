{ Every diagnostic the time procedures add, and the two rules that are not
  new: §6.9.4 f) makes GetTimeStamp threaten its argument, so §6.5.1 refuses a
  protected one through the wording ADR-0046 already had; and a TimeStamp is a
  record like any other, so ADR-0017's name equivalence is what refuses an
  alike one. }
program timestamp_errors(output);
type alike = packed record
               DateValid, TimeValid: boolean;
               year: integer;
               month: 1..12;
               day: 1..31;
               hour: 0..23;
               minute: 0..59;
               second: 0..59
             end;
var t: TimeStamp; a: alike; i: integer;

procedure p(protected s: TimeStamp);
begin
  GetTimeStamp(s)
end;

begin
  GetTimeStamp;
  GetTimeStamp(t, t);
  GetTimeStamp(3);
  GetTimeStamp(i);
  GetTimeStamp(a);
  writeln(date);
  writeln(date(t, t));
  writeln(date(i));
  writeln(time(a));
  { A TimeStamp is not a string and its fields are not one either. }
  writeln(date(t) + 1);
  p(t)
end.
