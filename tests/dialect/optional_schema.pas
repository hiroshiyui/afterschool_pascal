{ A schema whose body holds an optional, reached through a *schematic formal
  parameter* -- which is the one path that asks `StaticThroughout` what an
  optional is.

  This case exists because ADR-0123 shipped without it and the compiler
  crashed. `StaticThroughout` enumerates every type kind and a seventeenth had
  been added; a Pascal case-statement with no matching label stops the program
  (ADR-0018), so the failure was a *compiler crash* rather than a wrong answer.
  No gate could see it -- a missing arm is not a statement, so line-coverage
  does not count it, and procedure-coverage asks only whether the procedure was
  entered. doc/sop.md §7 had named the hazard, and named the routine, before
  this happened.

  `tests/checks/kind_exhaustive.py` is the check that answers it in general.
  This is the case that answers it for the kind that got in. }
program optional_schema(output);

type
  Box(n: integer) = record
    { Not last, so DynamicTail walks it with StaticThroughout rather than
      recursing into it. }
    slot: ?integer;
    pad: array [1..n] of integer
  end;

var small: Box(2);
    large: Box(4);
    k: integer;

{ A var schematic formal: the descriptor arrives with the actual (ADR-0040),
  and the type is produced with no tuple at all -- which is what makes this the
  path that asks. }
procedure Fill(var b: Box; from: integer);
var i: integer;
begin
  b.slot := from;
  for i := 1 to b.n do
    b.pad[i] := from + i
end;

{ And a value one, which is the same production through a second call site. }
procedure Show(what: string(6); b: Box);
var i: integer;
begin
  write(what, ' n=', b.n:1, ' slot=');
  if b.slot = nil then write('(none)') else write(b.slot^:1);
  write(' pad=');
  for i := 1 to b.n do write(b.pad[i]:1, ' ');
  writeln
end;

begin
  Fill(small, 10);
  Fill(large, 20);
  Show('small ', small);
  Show('large ', large);

  { And absent, so the flag inside a schema production is written as well as
    read. }
  small.slot := nil;
  Show('small ', small);

  k := 0;
  for k := 1 to large.n do
    large.pad[k] := 0;
  Show('large ', large)
end.
