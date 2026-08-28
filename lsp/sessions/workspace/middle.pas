{ The middle of the workspace, and the shape that needs the walk.

  There is no `middle.components` beside this file. The sidecar that names it
  is `client.components`, one directory entry along, and what the server must
  take from it is the entries *before* this one -- `base.pas` and nothing
  else. Opening this file with no resolution at all reports `no interface
  named 'base' has been exported` and then every name that came from it. }
module Middle;

export Middle = (Doubled);

import Base;

function Doubled: integer;

end;

function Doubled;
begin
  Doubled := Answer * 2
end;

end.
