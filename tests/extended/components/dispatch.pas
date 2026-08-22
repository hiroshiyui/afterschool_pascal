{ A module whose interface exports two procedures and a function, so a program
  importing it `qualified` has nothing but `dispatching.name` to call them by.

  It exists for tests/extended/procparam_qualified.pas, which passes those
  names as actual procedural and functional parameters. ISO/IEC 10206:1991
  6.7.3.4 asks for a *procedure-name* and 6.7.1 spells one as an optional
  interface qualifier and an identifier, so `dispatching.show` is a procedure-name
  and not an expression -- and under `qualified` it is the only one there is. }
module dispatch;

export dispatching = (show, bump, twice);

import StandardOutput;

procedure show(n: integer);
procedure bump(var n: integer);
function twice(n: integer): integer;
end;

procedure show;
begin writeln('show ', n:1) end;

procedure bump;
begin n := n + 1 end;

function twice;
begin twice := n * 2 end;

end.
