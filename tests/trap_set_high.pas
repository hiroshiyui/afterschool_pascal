program TrapSetHigh(output);
{ The other end of the same check as trap_set.pas: a member above the base
  type's last value, which a universe built from lo..255 would accept. Both
  halves of the mask are needed, so both halves are pinned. }
type inner = set of 5..9;
var d: inner; i: integer;
begin
  i := 5;
  d := [i, 9];
  writeln('in range: ', 5 in d, 9 in d);
  i := 30;
  d := [i];
  writeln('unreachable')
end.
