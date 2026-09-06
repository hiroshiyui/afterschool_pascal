{ A component supplying a type and nothing about any trait. It exists so that
  the case importing it implements a trait of its own for a type it did not
  declare -- the second half of ADR-0338's orphan rule, and the only half
  that can be written today: a trait cannot yet be exported. }
module pointmod;

export pointmod = (Point, SetPoint);

type
  Point = record x, y: integer end;

procedure SetPoint(a, b: integer; var r: Point);

end;

procedure SetPoint;
begin
  r.x := a;
  r.y := b
end;

end.
