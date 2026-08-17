{ Megabytes of string temporaries through a one-megabyte arena. Each value is
  dead when its statement finishes, so the space is reused -- which is the
  whole reason the arena can be exhausted at all rather than simply grown.
  Without the release CodeGen writes at the end of an allocating statement
  (ADR-0111) each loop below stops with `more string values are live at once
  than the string arena holds` long before it is done.

  One loop per producer, because the arena has exactly three and each is a
  separate line in EmitString: concatenation, a char given an address so that
  it can stand where a string does (6.4.3.3.1), and the two time functions of
  6.7.6.9. Nothing about the clock is printed -- only the lengths, which
  6.7.6.9 makes properties of the implementation and not of the moment. }
program strarenaloop(output);
var a: string(50); s: string(100); c: char; t: TimeStamp; i: integer;
begin
  a := 'abcdefghij';
  for i := 1 to 200000 do            { 20 characters an iteration }
    s := a + a;
  writeln(s);

  c := 'q';
  for i := 1 to 2000000 do           { one character an iteration }
    s := c;
  writeln(s);

  GetTimeStamp(t);
  for i := 1 to 200000 do            { ten characters, then eight }
    s := date(t);
  writeln(length(s):1);
  for i := 1 to 200000 do
    s := time(t);
  writeln(length(s):1)
end.
