{ AP 6.7.7.8, ADR-0187: a foreign function may answer an optional of a record.
  Null is the absent value; any other address is a *copy*, made where the call
  occurs, into storage the caller owns.

  This is 6.7.7.8's existing rule for `?string(n)` applied to a second type, and
  the two halves of the claim are already settled elsewhere. Which records may
  cross is 6.7.7.6.2's question and `foreign_record.pas` is what answers it --
  that this compiler lays a record out the way C lays out a struct, checked
  against a C compiler by `foreign-layout`. What is new here is only the
  direction: the bytes are the callee's, and the program never holds them.

  So the thing this case has to prove is that the copy is a copy.
  `pasx_record_answer` answers the address of one static object that every call
  overwrites -- the shape `readdir` and `gmtime` have -- and the case calls it
  twice and then reads the *first* value back. An aliasing view would answer
  2000; a copy answers 1000.

  `gmtime` is the other half, and it is a real one: ISO C 7.27.3.3, answering
  the address of storage it owns, and a null for a time it cannot represent.
  Its `struct tm` has two members after the nine this record declares -- glibc
  adds `tm_gmtoff` and `tm_zone` -- so the record is a *prefix*, which is what
  6.7.7.8's NOTE 4 is about: the copy is as long as the record declared here
  and not as long as the struct. It reads the nine and stops. The values pin
  the offsets on their own, a misplaced field putting a day count where the
  year goes. }
program foreign_optional_record(output);

type
  { The struct `pasx_record_answer` fills, field for field -- the same one
    foreign_record.pas passes in the other direction, so the layout claim is
    stated once and used twice. }
  Probe = record
    a: int64;                        {  0 }
    b: integer;                      {  8 }
    c: char;                         { 12 }
    d: array [1..3] of char;         { 13 }
    e: real;                         { 16 }
    f: array [1..2] of int64;        { 24 }
    g: record c: char; n: integer end   { 40, 44 }
  end;                               { 48 }

  OptProbe = ?Probe;

  { ISO C 7.27.1's first nine members, in order. No @cstruct annotation: this
    is deliberately not the whole struct, and `foreign-layout` compares a
    field-list against the *whole* one -- which is right, a partial claim being
    one a C compiler cannot check. What checks this one is the calendar. }
  Tm = record
    sec, min, hour, mday, mon, year, wday, yday, isdst: integer
  end;

  OptTm = ?Tm;

function RecordAnswer(n: integer): OptProbe; external 'pasx_record_answer';

{ `const time_t *`, which is a `var` parameter of the width time_t has -- 64
  bits on every target this tree is built for, as foreign_record.pas's
  `struct timespec` already assumes. }
function GmTime(var t: int64): OptTm; external 'gmtime';

var
  first, second, none: OptProbe;
  plain: Probe;
  held: array [1..2] of OptProbe;
  k: integer;
  when: int64;
  cal: OptTm;

{ Through a nested block, so the frame slot the call site writes its copy into
  is one the emitter walked the static chain to reach -- while the call itself
  passes no static link. The same shape foreign_record.pas checks for a `var`
  parameter. }
procedure viaNested;
  procedure inner;
  begin
    second := RecordAnswer(2)
  end;
begin
  inner
end;

begin
  first := RecordAnswer(1);
  writeln('present   = ', first <> nil);
  writeln('int64     = ', first^.a:1);
  writeln('integer   = ', first^.b:1);
  writeln('char      = ', first^.c);
  writeln('char[]    = ', first^.d[1], first^.d[2], first^.d[3]);
  writeln('real      = ', first^.e:0:1);
  writeln('int64[]   = ', first^.f[1]:1, ' ', first^.f[2]:1);
  writeln('nested    = ', first^.g.c, ' ', first^.g.n:1);

  { The whole of it: a second call overwrites the callee's storage, and the
    first answer is unmoved because it was never that storage. }
  viaNested;
  writeln('second    = ', second^.a:1);
  writeln('first     = ', first^.a:1);

  { The payload is an ordinary record once it is here: it copies out by
    whole-variable assignment and its fields are designators like any others. }
  plain := first^;
  plain.b := 7;
  writeln('copied    = ', plain.a:1, ' ', plain.b:1, ' ', first^.b:1);

  { And the optional is an ordinary value: it goes into an array component,
    which is a store of the flag and the payload together. }
  held[1] := first;
  held[2] := RecordAnswer(3);
  for k := 1 to 2 do writeln('held[', k:1, ']   = ', held[k]^.a:1);

  { Null is a value of the type and not a failure -- `readdir` at the end of a
    directory is the case the optional exists for. }
  none := RecordAnswer(0);
  writeln('absent    = ', none = nil);

  { --- a real one, and a prefix of its struct --- }
  when := 0;
  cal := GmTime(when);
  writeln('epoch     = ', cal^.year + 1900:1, '-', cal^.mon + 1:1,
          '-', cal^.mday:1, ' ', cal^.hour:1, ':', cal^.min:1,
          ':', cal^.sec:1);
  { The last two of the nine, so the copy is shown to reach the end of what was
    declared and not merely the start. 1 January 1970 was a Thursday. }
  writeln('weekday   = ', cal^.wday:1, ' yearday = ', cal^.yday:1);
  when := 1000000000;
  cal := GmTime(when);
  writeln('gigasecond= ', cal^.year + 1900:1, '-', cal^.mon + 1:1,
          '-', cal^.mday:1)
end.
