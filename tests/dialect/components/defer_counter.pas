{ AP 6.9.3.11 in a module. 6.11.4's module-initialization is the statement-part
  of the module-block, so a defer-statement there is armed in that sequence and
  runs when it is completed -- which 6.2.3.6 puts before the main-program-block
  commences. The finalization shares the frame and the same epilogue
  (ADR-0175). }
module defer_counter(output);

export defer_counter = (Count);

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
  n := 5;
  writeln('module: initialization body, n = ', n:1)
end;

to end do
  writeln('module: finalization, n = ', n:1);

end.
