{ The set form of the same obligation, and the half that could not be answered
  the same way.

  ISO/IEC 10206:1991 6.9.3.9.3's `for v in s` walks the base type's ordinals in
  a counter the program cannot name. The sequence form's limit needed no
  storage at all -- it is written once and read, so the value the expression
  produced serves -- but this counter is *stepped* on every iteration, so it
  has to live somewhere. It now lives in a frame slot, which is claimed once
  per activation, rather than in an alloca claimed wherever emission had
  reached.

  tests/for_nested_stack.pas is the sequence form and the two are separate
  files on purpose: one fix removed a store, the other moved one, and a single
  program exercising both would go green when only one of them was right.

  Read that file for why this needs -O0 and a bounded stack to be able to fail
  at all. The set here is deliberately not empty: a `for ... in []` finds no
  members and would still leak the counter, but a reader checking the answer
  wants to see the loop do something. }
program ForInNestedStack(output);
var
  c: 0..255;
  s: set of 0..255;
  n, k: integer;
begin
  s := [3, 7, 11];
  k := 0;
  n := 0;
  while n < 2000000 do
    begin
      for c in s do k := k + c;
      n := n + 1
    end;
  writeln('total ', k:1)
end.
