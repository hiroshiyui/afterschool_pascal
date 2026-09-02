program TrapPositionCall(output);

{ ADR-0293's other class: a trap raised *inside* a runtime routine, which
  knows nothing about the source. The emitter stores the position before the
  call and clears it after, and the operand of this `**` is a function whose
  body makes runtime calls of its own -- so the position reported has to be
  the operator's, not the last thing Half's writeln stored and not nothing.
  0 ** y with y <= 0 is 6.8.3.2's error, raised by pas_pow_real. }

var z: real;

function Half(x: real): real;
begin
  writeln('half of ', x:1:1);
  Half := x / 2
end;

begin
  z := Half(0.0) ** (-1.0);
  writeln(z)
end.
