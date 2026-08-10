{ ISO/IEC 10206:1991 §6.4.3.3: a variant-list may end with a
  variant-part-completer, `otherwise (field-list)` -- an arm with no labels,
  selected by every tag value the labelled arms leave.

  It is an arm like any other: one struct laid over the record's shared block
  (ADR-0018), so nothing about the layout, the field numbering or the field
  access changes. What it adds is that a tag value naming no label now selects
  something instead of nothing.

  Not a valid ISO 7185 program -- `otherwise` is an identifier there -- which
  is why it lives in tests/extended/. }
program VariantOtherwise(output);
type
  shape = (circle, square, triangle, hexagon, blob);
  figure = record
    name: packed array [1..8] of char;
    case kind: shape of
      circle: (radius: integer);
      square: (side: integer);
      { every other shape -- triangle, hexagon and blob -- lands here }
      otherwise (sides: integer;
                 { an arm's field-list is a field-list, so the completer may
                   carry a variant part of its own (ADR-0026) }
                 case regular: boolean of
                   true: (edge: integer);
                   otherwise (perimeter: integer))
  end;
  figptr = ^figure;

var
  f: figure;
  p: figptr;
  s: shape;

procedure Describe(var g: figure);
begin
  write(g.name, ' ');
  case g.kind of
    circle: writeln('radius ', g.radius:1);
    square: writeln('side ', g.side:1);
    otherwise
      write('sides ', g.sides:1);
      if g.regular then
        writeln(', edge ', g.edge:1)
      else
        writeln(', perimeter ', g.perimeter:1)
  end
end;

begin
  f.name := 'circle  ';
  f.kind := circle;
  f.radius := 7;
  Describe(f);

  f.name := 'square  ';
  f.kind := square;
  f.side := 4;
  Describe(f);

  { the completer's fields, through the same designators the labelled arms use }
  f.name := 'triangle';
  f.kind := triangle;
  f.sides := 3;
  f.regular := true;
  f.edge := 5;
  Describe(f);

  f.name := 'blob    ';
  f.kind := blob;
  f.sides := 11;
  f.regular := false;
  f.perimeter := 42;
  Describe(f);

  { §6.6.5.3's `new(p, c)` selects a variant by tag value, and a value no
    labelled arm claims selects the completer instead of being an error }
  new(p, square);
  p^.name := 'newsqr  ';
  p^.kind := square;
  p^.side := 2;
  Describe(p^);
  dispose(p, square);

  new(p, hexagon, false);
  p^.name := 'newhex  ';
  p^.kind := hexagon;
  p^.sides := 6;
  p^.regular := false;
  p^.perimeter := 60;
  Describe(p^);
  dispose(p, hexagon, false);

  s := blob;
  f.name := 'lastone ';
  f.kind := s;
  f.sides := 0;
  f.regular := true;
  f.edge := 0;
  Describe(f)
end.
