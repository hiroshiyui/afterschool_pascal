{ The other half of trap_filecomponent: `read(f, v)` is `v := f^`, so what
  comes *out* of a file enters a variable and is checked entering it. The file
  holds a perfectly good integer; the variable is what cannot hold it. }
program TrapFileSubrange(output);
var
  f: file of integer;
  small: 1..9;
begin
  rewrite(f);
  write(f, 4);
  write(f, 40);
  reset(f);
  read(f, small);
  writeln('read ', small:1);
  read(f, small);
  writeln('unreachable')
end.
