{ 6.4.6: a string value longer than the destination's capacity is an error, and
  a value parameter is a destination like any other. The conversion happens in
  the callee's prologue (ADR-0115), so this is the *same* check and the same
  message an assignment makes -- which is the point: a value parameter and an
  assignment must not disagree about 6.4.6.

  'before' is written first so that a run which never reached the call is
  distinguishable from one that trapped at it. }
program trap_strvalueparam(output);

type s5 = string(5);

var v: string(40);

function len(s: s5): integer;
begin
  len := length(s)
end;

begin
  v := 'far too long for five';
  writeln('before');
  writeln(len(v):1)
end.
