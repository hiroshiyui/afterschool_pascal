{ Reading past the end of a `file of T`. `eof` is the only thing that says a
  component is there, and `read(f, v)` is `v := f^; get(f)` -- so it is the
  buffer variable that traps first, exactly as it does on a text file. A
  partial component at the end counts as no component at all. }
program TrapTypedFile(output);
var
  f: file of integer;
  n: integer;
begin
  rewrite(f);
  write(f, 42);
  reset(f);
  read(f, n);
  writeln('read ', n:1);
  read(f, n);
  writeln('unreachable ', n:1)
end.
