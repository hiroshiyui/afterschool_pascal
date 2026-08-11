{ §6.7.5.2's pre-assertion on all three seeks is
  `0 <= ord(n)-ord(a) <= length(f)`. The upper end is not a mistake: seeking to
  exactly one past the last component is the *append* position, and refusing it
  would leave SeekWrite unable to add anything to a file. Two past it is an
  error, and this is the program that says so. }
program TrapSeek(output, f);
var f: file [1..100] of integer;
    i: integer;
begin
  rewrite(f);
  for i := 1 to 3 do begin f^ := i; put(f) end;
  { one past the last component: legal, and where an append starts }
  seekwrite(f, 4);
  writeln('append ok');
  { two past it: there is no such position }
  seekread(f, 5);
  writeln('not reached')
end.
