{ AP 6.9.3.11: what a deferred statement may not contain, and why. It is
  emitted twice -- where its sequence is completed, and in the block's runner
  -- so a label in one would be two labels with one number and a goto in one
  would leave a function that is not running (ADR-0175). Sema accumulates, so
  one file. }
program defer_errors(output);
label 1, 2;
var i: integer; r: record a: integer end;
begin
  defer goto 1;
  defer begin i := 1; goto 2 end;
  defer 1: i := 2;
  defer defer i := 3;
  defer if i = 1 then i := 0 else goto 2;
  defer while i > 0 do goto 2;
  defer repeat goto 2 until true;
  defer for i := 1 to 2 do goto 2;
  defer with r do begin a := 1; goto 2 end;
  defer case i of 1: goto 2; otherwise goto 2 end;
2:
  writeln(i)
end.
