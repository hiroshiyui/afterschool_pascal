{ 6.11.3's qualified name, and the two ways of writing one that is not.

  A qualifier is looked up as a *symbol* and has to be an interface: the
  parser cannot tell `m.f` from a field selection, so the name decides
  (ADR-0053). And a function reached that way is still a function -- writing
  it bare is 6.7.3's missing actual-parameter-list, not a parameterless
  call. }
program qualname(output);

import exporter;

var
  thing: integer;
  q: integer;
  { A qualified *type* name whose qualifier is a variable. }
  v: thing.sometype;

begin
  q := exporter.twice;
  thing := 0
end.
