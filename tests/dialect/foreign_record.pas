{ AP 6.7.7.6.2, ADR-0184: a `var` parameter of a record type, which crosses as
  the address of the actual's own storage -- one argument, exactly as a scalar
  `var` parameter's address is.

  What had to be decided was not the lowering but *which* records, and the
  answer is that this compiler already lays a record out the way C lays out a
  struct: each field rounded up to its own alignment, the widest field's
  alignment the record's, the total rounded to that. So the rule declines every
  field whose layout is this compiler's own invention and admits the rest.

  `pasx_record_probe` is the strong half of this case and it is deliberately in
  the runtime rather than here: the claim is that *two compilers agree about
  offsets*, and there is no way to check that from one side. The probe fills
  every field with a value no other field could hold, so a disagreement shows
  up as a wrong value rather than a plausible one -- and it asks the question
  on whatever target this tree was built for, which matters because LlSize and
  LlAlign answer with one number for every target (ADR-0028).

  `timespec_get` is the other half: a real struct, from ISO C11 rather than
  from POSIX, and `struct timespec` is a time_t beside a long on every target
  with a 64-bit word. Its values are not fixed, so what is printed is what can be
  asserted about them -- and that is enough to pin both offsets, because a
  swapped or misplaced pair puts a nanosecond count where the seconds go and
  the range test then fails. }
program foreign_record(output);

type
  { The probe's struct, field for field. The comments are the offsets C
    computes on an LP64 target; this compiler computes the same ones, which
    is the whole claim. }
  Probe = record
    a: int64;                        {  0 }
    b: integer;                      {  8 }
    c: char;                         { 12 }
    d: array [1..3] of char;         { 13 }
    e: real;                         { 16 -- realigns, so d has a tail hole }
    f: array [1..2] of int64;        { 24 }
    { `packed` is written here on purpose and changes nothing: this compiler
      ignores it (doc/implementation-defined.md, 6.6.5.4), so the fields land
      at C's *unpacked* offsets -- 40 and 44 -- and not at 40 and 41. It is
      therefore not a way to spell C's `__attribute__((packed))`, and this
      case is what says so. }
    g: packed record c: char; n: integer end   { 40, 44 }
  end;                               { 48 }

  { ISO C11 7.27.2.5. Two words, and on this target both are 64 bits. }
  TimeSpec = record
    sec: int64;
    nsec: int64
  end;

function RecordProbe(var p: Probe): int64; external 'pasx_record_probe';
function TimespecGet(var ts: TimeSpec; base: integer): integer;
  external 'timespec_get';

const timeUtc = 1;

var
  p: Probe;
  ts: TimeSpec;
  size: int64;
  n: integer;

{ Through a nested block, so the address the call passes is one the emitter
  walked the static chain for -- while the call itself passes no static link
  of its own. The same shape foreign_var.pas checks for a scalar. }
procedure viaNested;
  procedure inner;
  begin
    size := RecordProbe(p)
  end;
begin
  inner
end;

begin
  { --- every admitted field kind, filled from C --- }
  size := RecordProbe(p);
  writeln('size      = ', size:1);
  writeln('int64     = ', p.a:1);
  writeln('integer   = ', p.b:1);
  writeln('char      = ', p.c);
  writeln('char[]    = ', p.d[1], p.d[2], p.d[3]);
  writeln('real      = ', p.e:0:1);
  writeln('int64[]   = ', p.f[1]:1, ' ', p.f[2]:1);
  writeln('nested    = ', p.g.c, ' ', p.g.n:1);

  { The address is the actual's own storage, so a second call overwrites what
    the first left -- and the value is the same, which is what says the call
    is passing the same variable and not a copy. }
  p.a := 0;
  p.g.n := 0;
  viaNested;
  writeln('again     = ', p.a:1, ' ', p.g.n:1);

  { --- a real struct, and what can be asserted about a clock --- }
  ts.sec := -1;
  ts.nsec := -1;
  n := TimespecGet(ts, timeUtc);
  writeln('timespec  = ', n = timeUtc);
  { A misplaced pair puts a count below 10^9 into `sec`; every date since 2023
    is above it. }
  writeln('seconds   = ', ts.sec > 1700000000);
  writeln('nanos     = ', (ts.nsec >= 0) and (ts.nsec < 1000000000))
end.
