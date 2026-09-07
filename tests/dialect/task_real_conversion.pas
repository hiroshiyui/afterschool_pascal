{ 6.4.6 c)'s implicit integer-to-real conversion in the two positions AP
  6.9.3.12 and 6.9.3.13.1 added. Sema admitted an integer where a channel's
  component or a task's formal is real, and CodeGen stored the value at the
  *destination's* type -- so the module carried `store double %i32` and LLVM
  refused to assemble a program the front end had accepted (ADR-0365, an
  audit's finding). Neither a literal nor a variable worked.

  A real actual and a real value are sent here too, so a fix in the wrong
  direction fails as well. The task closes the channel, which is what ends
  the receive loop. }
program task_real_conversion(output);
type ch = channel [8] of real;
var c: ch; r: real; i: integer;

task Scale(x: real; o: ch);
var k: integer;
begin
  send(o, x * 2);
  k := release(o)
end;

begin
  i := 2;
  send(c, i);
  send(c, 3);
  send(c, 1.5);
  spawn Scale(3, c);
  while receive(c, r) do writeln(r:4:1)
end.
