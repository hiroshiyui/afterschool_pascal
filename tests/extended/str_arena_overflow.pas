{ Two string temporaries live at once whose lengths sum past the runtime's
  string arena. a and b differ in every character, so `a + a = b + b` is false.

  The arena used to be a ring: the second concatenation wrapped to the start
  and was written over the first, both pointers reached the comparison as the
  same address, and the program printed `equal` for two values that differ
  everywhere -- with exit status 0 and nothing said. A limit is reported, never
  applied by wrapping (ADR-0110, ADR-0111). }
program strarenaoverflow(output);
type big = string(600000);
var a, b: big; i: integer;
begin
  a := 'x';
  b := 'z';
  { 2**18 characters each, then one more so that two of them do not fit. }
  for i := 1 to 18 do begin
    a := a + a;
    b := b + b
  end;
  a := a + 'y';
  b := b + 'y';
  if a + a = b + b then
    writeln('equal')
  else
    writeln('differ')
end.
