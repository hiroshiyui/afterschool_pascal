{ **AP 6.7.11's trait-object-type, in every position a program can write one**
  (ADR-0408, ADR-0315's increment C). The type exists, is spelled, is named by
  every dispatch in the compiler, and is **accepted nowhere** -- which is what
  AP 5.6's `[not yet implemented]` marker says of the clause and what this
  case says of the processor. It is the two halves of one statement, compared
  by `spec-clause-traceability` in both directions.

  Each line below is a position, and the diagnostic names the two positions
  6.7.11.1 will permit rather than only refusing. That is the point of writing
  it here: a person who writes `dyn` is a person who wants the feature, and
  what they need is where it will stand.

  `dyn` reserves nothing (6.7.11, ADR-0140), which the declarations at the top
  are here to prove: a type named `dyn`, a field named `dyn` and a value
  parameter named `dyn` all compile, exactly as `owned`'s and `trait`'s do in
  their own cases. If `dyn` were a word-symbol these four lines would not
  parse. }
program dyn_positions(output);

type
  { The syntax word as an ordinary identifier, in the program that uses the
    construct. }
  dyn = 1..9;
  holder = record dyn: integer end;

  Point = record x, y: integer end;

trait Shape;
  function Area(s: Self): integer;
end;

impl Shape for Point;
  function Area;
  begin Area := s.x * s.y end;
end;

type
  { a named trait-object type }
  D = dyn Shape;
  { a field }
  R = record f: dyn Shape end;
  { an array element }
  A = array [1..3] of dyn Shape;

var
  { a variable }
  v: dyn Shape;
  small: dyn;
  h: holder;

{ a variable parameter -- one of the two 6.7.11.1 will permit, and refused
  today like the rest, because the clause is marked and the processor accepts
  no occurrence at all }
procedure P(var x: dyn Shape);
begin
  h.dyn := 1
end;

{ the name must denote a trait, and `Point` is a type }
type Bad = dyn Point;

begin
  small := 3;
  h.dyn := 4;
  writeln(small:1, ' ', h.dyn:1)
end.
