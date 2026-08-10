{ A component of a file is a variable of the component type, so a value
  entering one is checked exactly as a value entering any other variable is
  (ADR-0018). `write(f, e)` is `f^ := e`, and that assignment is where the
  check lives -- there is no separate rule for files. }
program TrapFileComponent(output);
var
  f: file of 1..9;
  n: integer;
begin
  rewrite(f);
  n := 4;
  write(f, n);
  writeln('wrote ', n:1);
  n := 40;
  write(f, n);
  writeln('unreachable')
end.
