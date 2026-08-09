{ The statement rules. }
program statements(output);
type rec = record a: integer end;
var i: integer; r: real; v: rec; b: boolean;
procedure q(x: integer); begin write(x) end;
begin
  if i then i := 1;
  while i do i := 1;
  repeat i := 1 until i;
  for r := 1 to 2 do i := 1;
  for i := true to 2 do i := 1;
  q := 1;
  nosuchproc(1);
  i(1);
  with i do i := 1;
  q(i);
  write(b, v.a)
end.
