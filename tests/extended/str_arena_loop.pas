{ Megabytes of string temporaries through a one-megabyte arena. Each value is
  dead when its statement finishes, so the space is reused -- which is the
  whole reason the arena can be exhausted at all rather than simply grown.
  Without the release CodeGen writes at the end of an allocating statement
  (ADR-0111) each loop below stops with `more string values are live at once
  than the string arena holds` long before it is done.

  One loop per producer. Three are separate lines in EmitString --
  concatenation, a char given an address so that it can stand where a string
  does (6.4.3.3.1), and the two time functions of 6.7.6.9 -- and the fourth is
  the padded actual a fixed-string value parameter takes (6.7.3.2, ADR-0171),
  which is built at the call rather than inside EmitString and bumps the same
  counter. Nothing about the clock is printed -- only the lengths, which
  6.7.6.9 makes properties of the implementation and not of the moment. }
program strarenaloop(output);
type sixty = packed array [1..60] of char;
var a: string(50); s: string(100); c: char; t: TimeStamp; i: integer;

procedure padded(p: sixty);
begin
  if i = 200000 then writeln(length(trim(p)):1)
end;

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
  writeln(length(s):1);

  for i := 1 to 200000 do            { sixty characters an iteration }
    padded('pad')
end.
