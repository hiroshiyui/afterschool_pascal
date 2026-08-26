{ AP 6.7.3.10 across ISO/IEC 10206:1991 6.13 (ADR-0212). The generic is
  declared in a separately translated component and instantiated here, for
  types this program declares and that component never heard of -- which is
  what makes the instantiation *this* translation's to emit. }
program generic_import(output);

import GenericMod;

type Point = record x, y: integer end;

function FirstBigger(i, j: integer): boolean;
begin FirstBigger := i < j end;

var i, j: integer;
    p, r: Point;
    ip: Pair(integer);
    pp: Pair(Point);
begin
  i := 3; j := 7;
  Swap(integer, i, j);
  writeln('ints    ', i:1, ' ', j:1);

  p.x := 1; p.y := 2; r.x := 8; r.y := 9;
  Swap(Point, p, r);
  writeln('records ', p.x:1, ',', p.y:1, ' ', r.x:1, ',', r.y:1);

  { The same T again reaches the translation already made for it. }
  Swap(integer, i, j);
  writeln('again   ', i:1, ' ', j:1);

  MakePair(integer, ip, 10, 20);
  writeln('pair    ', ip.a:1, ' ', ip.b:1);

  MakePair(Point, pp, p, r);
  writeln('pairrec ', pp.a.x:1, ' ', pp.b.x:1);

  writeln('fn      ', Largest(integer, ip, FirstBigger):1)
end.
