{ AP 6.7.5.9 in a module. 6.11.4's module-initialization is the statement-part
  of the module-block, so an exit there terminates the activation of that block
  and nothing else -- the finalization is a separate activation and still runs
  (ADR-0177). }
module exit_counter(output);

export exit_counter = (Count);

var n: integer;

function Count: integer;

end;

function Count;
begin
  Count := n
end;

to begin do begin
  n := 1;
  defer writeln('module: initialization deferred, n = ', n:1);
  writeln('module: initialization body');
  exit;
  n := 99
end;

to end do begin
  writeln('module: finalization, n = ', n:1);
  exit;
  writeln('module: not reached')
end;

end.
