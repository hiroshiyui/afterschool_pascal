{ AP 6.9.3.11: `halt` terminates every activation, and each runs what it
  armed -- innermost first, and before any file is closed, which is what lets
  the deferred statement below write to `output` at all. Its own case because
  it ends the program (ADR-0175). }
program defer_halt(output);

procedure deeper;
begin
  defer writeln('  deeper armed');
  writeln('  deeper body');
  halt(3)
end;

procedure outer;
begin
  defer writeln('  outer armed');
  deeper;
  writeln('  not reached')
end;

begin
  defer writeln('the program''s own, last of all');
  writeln('halting:');
  outer;
  writeln('not reached')
end.
