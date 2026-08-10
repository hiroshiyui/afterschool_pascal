program TrapSetMember(output);
{ A member outside 0..255 has no bit in the representation at all, so the
  constructor traps on its own -- a different error from trap_set.pas, which is
  about the *target's* base type. The target here spans the whole universe, so
  the store check is elided and this is the constructor's own check firing. }
var s: set of 0..255; i: integer;
begin
  i := 200;
  s := [i];
  writeln('in range: ', 200 in s);
  i := 300;
  s := [i];
  writeln('unreachable')
end.
