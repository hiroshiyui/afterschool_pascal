program OrdinalErrors(output);

{ The rules that make enumerations and subranges worth having are the ones
  that reject programs: two enumerations are never compatible, a case must
  cover its labels exactly once, and an enumeration has no external spelling. }

const
  half = 0.5;

type
  colour  = (red, green, blue);
  weekday = (mon, tue, wed);
  digit   = 1..9;
  empty   = 9..1;                { the upper bound is below the lower }
  mixed   = 1..'z';              { bounds of different types }
  notord  = half..half;          { a real is not an ordinal }
  clash   = (red, mauve);        { red already names a colour constant }

  bad = record
    a: integer;
    case tag: real of            { a tag must be ordinal }
      1: (b: integer)
  end;

  twice = record
    case kind: colour of
      red:   (x: integer);
      red:   (y: integer);       { red already selects a variant }
      green: (x: real)           { x is already a field }
  end;

var
  c: colour;
  w: weekday;
  d: digit;
  r: real;

begin
  c := mon;                      { a weekday is not a colour }
  w := succ(blue);               { still a colour }
  writeln(c);                    { an enumeration cannot be written }
  d := red;                      { a colour is not a digit }

  case r of                      { a real is not an ordinal }
    1: d := 1
  end;

  case c of
    red:   d := 1;
    green: d := 2;
    red:   d := 3;               { red appears twice }
    mon:   d := 4                { and mon is not a colour at all }
  end
end.
