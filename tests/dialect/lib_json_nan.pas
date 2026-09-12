{ PasJson: a value the shortest-form search cannot spell must not stop the
  program, and the guard that was there could not fire.

  `ShortestReal` refused a value with no decimal representation by asking
  `(x <> x) or (abs(x) > maxreal)`. The second half answers for an infinity.
  The first is the usual spelling of *is this a NaN* and is not one here:
  `<>` on reals emits `fcmp one`, which is **ordered** not-equal and therefore
  false whenever an operand is unordered, so `nan <> nan` is FALSE and the
  guard was never taken. The scan below it then looked for the `E` in what
  `writestr` writes for a NaN, did not find one, and read one character past
  the end of the string -- an index out of bounds reported against a line of
  this library, from a program that had only asked for a number to be written.

  `not (x = x)` is the same question spelled so that this processor answers
  it: `=` emits `fcmp oeq`, which is false for a NaN, and negating it is true.

  Whether `<>` *ought* to be the negation of `=` for a value neither standard
  contemplates is a question about the compiler and not about this library;
  `doc/sop.md` §7 carries it. This case pins both answers, so that the day it
  is decided this file is what says so.

  The values are built rather than written: this language has no literal for
  either, and `doc/implementation-defined.md` §3 is where `1e308 * 10.0`
  yielding an infinity is recorded as breaking no rule -- §6.7.2.2 makes the
  accuracy of the real operations implementation-defined rather than making an
  unrepresentable result an error.

  What is deliberately **not** asserted is how either value is spelled. That is
  the host C library's `%E`, which no clause of either standard fixes, and a
  golden holding `NAN` would be asserting something about glibc. What is
  asserted is that the call returns. }
program lib_json_nan(output);

import PasError; PasText; PasJson;

var v: JsonPtr; out: JsonChars; s: string(64); e: ErrorCode; x, y: real;

begin
  x := 1.0e308;
  x := x * 10.0;
  y := x - x;

  { The two comparisons the fix turns on, and the one that already worked. }
  writeln('nan <> nan          = ', y <> y);
  writeln('not (nan = nan)     = ', not (y = y));
  writeln('abs(inf) > maxreal  = ', abs(x) > maxreal);
  writeln('abs(nan) > maxreal  = ', abs(y) > maxreal);

  { Rendering one. Before the fix this reached
    `array index out of bounds (1..21)` inside pasjson.pas. }
  out.Init;
  v := JsonNewNumber(y);
  v.Render(out);
  e := out.Into(s);
  writeln('nan rendered: returned=', out.Len > 0, ' code=', ord(e):1);
  v.Free;
  out.Free;

  { An infinity took the guard all along, and is here so that a change to the
    guard has to keep both halves. }
  out.Init;
  v := JsonNewNumber(x);
  v.Render(out);
  e := out.Into(s);
  writeln('inf rendered: returned=', out.Len > 0, ' code=', ord(e):1);
  v.Free;
  out.Free;

  { And the finite path, which is what moved to PasText and must still answer
    the shortest spelling rather than 6.10.3.4.1's default width. }
  writeln('RealToStr(0.75)     = ', RealToStr(0.75));
  writeln('RealToStr(1.0)      = ', RealToStr(1.0));
  writeln('RealToStr(-1.0E-7)  = ', RealToStr(-1.0E-7))
end.
