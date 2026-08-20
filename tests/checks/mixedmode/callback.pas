{ A module whose interface reaches a tagged variant record ONLY through the
  parameter list of a *procedural* parameter (ADR-0142).

  Its export list is one procedure. `Tagged` is not exported here, is not a
  field of anything exported, is not an array component or a pointer domain,
  and is not the type of any parameter of `ApplyR`. It is the type of a
  parameter of `Q`, which is a parameter of `ApplyR`. AP 6.13.1 says
  "reachable ... through a parameter", and it is reachable through two.

  ComputeModePortable asked each parameter about its own `stype` and stopped.
  A procedural parameter's own parameters live in *its* params list, and
  TypeCarriesTag has no arm for tyProc -- a procedure type is not a type a
  value is held in -- so this module reported portable, the link succeeded, and
  the program's guard ran against a tag this component never stored and
  *passed* the read. That is the one outcome ADR-0118's claim cannot survive. }
module Callback;

export Callback = (ApplyR);

import TagBase;

procedure ApplyR(procedure Q(var t: Tagged));

end;

procedure ApplyR;
var v: Tagged;
begin
  { the tag says the integer arm, and a real is stored there anyway -- which
    only a component without the dialect's write rule can do }
  v.k := isI;
  v.r := 3.14159;
  Q(v)
end;

end.
