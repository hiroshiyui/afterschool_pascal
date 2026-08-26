{ PasContainer: one growable vector and one string-keyed map, over whatever
  element type the program names (ADR-0209, ADR-0211, ADR-0212, ADR-0213).

  The point of the case is that one module body serves both element types and
  that the containers really grow: the vector is opened at 2 and pushed 8
  times, and the map is opened at 4 and given 10 pairs, so each reallocates
  more than once. Neither could be written generically before AP 6.4.4.1 --
  a growable container reallocates, and new(p, bigger) needs a pointer whose
  domain is the schema. }
program lib_container(output);

import PasContainer;

type Point = record x, y: integer end;
     IntVec = ^Vec(integer);
     PtVec  = ^Vec(Point);
     IntMap = ^Map(integer);
     PtMap  = ^Map(Point);

var v: IntVec; w: PtVec;
    m: IntMap; q: PtMap;
    i, got: integer; p: Point; ok: boolean;
begin
  VecInit(IntVec, v, 2);
  for i := 1 to 8 do VecPush(IntVec, v, i * i);
  writeln('vec int  len=', VecLen(IntVec, v):1,
          ' cap=', VecCap(IntVec, v):1,
          ' [3]=', VecGet(IntVec, integer, v, 3):1);
  ok := VecPop(IntVec, v, got);
  writeln('vec pop  ', got:1, ' len=', VecLen(IntVec, v):1);
  VecSet(IntVec, v, 1, 99);
  writeln('vec set  ', VecGet(IntVec, integer, v, 1):1);
  VecClear(IntVec, v);
  writeln('vec clr  len=', VecLen(IntVec, v):1);
  VecFree(IntVec, v);

  VecInit(PtVec, w, 1);
  for i := 1 to 5 do begin
    p.x := i; p.y := i * 10;
    VecPush(PtVec, w, p)
  end;
  p := VecGet(PtVec, Point, w, 4);
  writeln('vec rec  len=', VecLen(PtVec, w):1, ' [4]=', p.x:1, ',', p.y:1);
  VecFree(PtVec, w);

  MapInit(IntMap, m, 4);
  for i := 1 to 10 do
    MapPut(IntMap, m, 'k' + chr(ord('0') + i), i);
  writeln('map int  count=', MapCount(IntMap, m):1,
          ' k3=', MapGet(IntMap, integer, m, 'k3', -1):1,
          ' has k9=', MapHas(IntMap, m, 'k9'));
  ok := MapDelete(IntMap, m, 'k3');
  writeln('map del  ', ok, ' count=', MapCount(IntMap, m):1,
          ' k3=', MapGet(IntMap, integer, m, 'k3', -1):1);
  MapFree(IntMap, m);

  MapInit(PtMap, q, 4);
  p.x := 7; p.y := 8;
  MapPut(PtMap, q, 'origin', p);
  p.x := 0; p.y := 0;
  p := MapGet(PtMap, Point, q, 'origin', p);
  writeln('map rec  count=', MapCount(PtMap, q):1, ' x=', p.x:1, ',', p.y:1);
  MapFree(PtMap, q)
end.
