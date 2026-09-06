{ PasContainer: one growable vector and one map, over whatever element type
  *and whatever key type* the program names (ADR-0209, ADR-0211, ADR-0212,
  ADR-0213, ADR-0260).

  The point of the case is that one module body serves both element types and
  that the containers really grow: the vector is opened at 2 and pushed 8
  times, and the map is opened at 4 and given 10 pairs, so each reallocates
  more than once. Neither could be written generically before AP 6.4.4.1 --
  a growable container reallocates, and new(p, bigger) needs a pointer whose
  domain is the schema. }
program lib_container(output);

import PasContainer;

type Point = record x, y: integer end;
     Short = string(8);
     IntVec = ^Vec(integer);
     PtVec  = ^Vec(Point);

{ A key type's hash and its equality, which is all a map needs of it -- and
  what the roadmap called a *constraint* the dialect had none of. It has one
  now: `Key` is the trait the map's discriminant is bound by (AP 6.4.7.2,
  ADR-0355), and an implementation is written once per key type where a pair
  of procedural parameters used to be written at every call. The module cannot
  supply one for `MapKey` itself (ADR-0341), so even the ready-made key gets
  its two lines here.

  **The reduction is not decoration.** This language traps integer overflow
  rather than wrapping it (ADR-0014), so the usual `k * <large odd number>` a
  hash is written with in C stops the program on the first key big enough --
  `999 * 2654435` is past `maxint`, which is how this comment came to be
  written. A hash here reduces as it goes, exactly as `PasContainer`'s own
  `StrHash` does. }
impl Key for MapKey;
  function Hash;
  begin Hash := StrHash(k) end;
  function Same;
  begin Same := StrEq(a, b) end;
end;

impl Key for integer;
  function Hash;
  begin Hash := (k mod 100003) * 31 mod 1000003 end;
  function Same;
  begin Same := a = b end;
end;

{ A record has no equality of its own -- §6.4.6 refuses `=` between two
  records -- so this is not a convenience but the only way such a key could
  work at all. }
impl Key for Point;
  function Hash;
  begin Hash := k.x * 31 + k.y end;
  function Same;
  begin Same := (a.x = b.x) and (a.y = b.y) end;
end;

{ The map types come after the implementations: AP 6.4.7.2 checks the bound
  where the type is produced, and 6.2.2.9 makes written order the only order.
  The key is a type argument (ADR-0260): the first two are keyed by a string
  as they always were, and `NumMap` is what the roadmap's "a hash of anything
  but a string" row wanted. }
type IntMap = ^Map(MapKey, integer);
     PtMap  = ^Map(MapKey, Point);
     NumMap = ^Map(integer, Short);
     PtKeyed = ^Map(Point, integer);

var v: IntVec; w: PtVec;
    m: IntMap; q: PtMap; nm: NumMap; pk: PtKeyed;
    i, got: integer; p: Point; ok: boolean;
begin
  VecInit(IntVec, v, 2);
  for i := 1 to 8 do VecPush(IntVec, v, i * i);
  writeln('vec int  len=', VecLen(IntVec, v):1,
          ' cap=', VecCap(IntVec, v):1,
          ' [3]=', VecGet(integer, v, 3):1);
  ok := VecPop(IntVec, v, got);
  writeln('vec pop  ', got:1, ' len=', VecLen(IntVec, v):1);
  VecSet(IntVec, v, 1, 99);
  writeln('vec set  ', VecGet(integer, v, 1):1);
  VecClear(IntVec, v);
  writeln('vec clr  len=', VecLen(IntVec, v):1);
  VecFree(IntVec, v);

  VecInit(PtVec, w, 1);
  for i := 1 to 5 do begin
    p.x := i; p.y := i * 10;
    VecPush(PtVec, w, p)
  end;
  p := VecGet(Point, w, 4);
  writeln('vec rec  len=', VecLen(PtVec, w):1, ' [4]=', p.x:1, ',', p.y:1);
  VecFree(PtVec, w);

  MapInit(IntMap, m, 4);
  for i := 1 to 10 do
      { Neither type argument is written: AP 6.7.3.10.4 takes `Ptr` from `m` and
      `K` from the key (ADR-0254), which is what keeps a key-generic map from
      costing a reader anything at the commonest call. }
    MapPut(m, 'k' + chr(ord('0') + i), i);
  writeln('map int  count=', MapCount(IntMap, m):1,
          ' k3=', MapGet(IntMap, integer, m, 'k3', -1):1,
          ' has k9=', MapHas(m, 'k9'));
  ok := MapDelete(m, 'k3');
  writeln('map del  ', ok, ' count=', MapCount(IntMap, m):1,
          ' k3=', MapGet(IntMap, integer, m, 'k3', -1):1);
  MapFree(IntMap, m);

  MapInit(PtMap, q, 4);
  p.x := 7; p.y := 8;
  MapPut(q, 'origin', p);
  p.x := 0; p.y := 0;
  p := MapGet(PtMap, Point, q, 'origin', p);
  writeln('map rec  count=', MapCount(PtMap, q):1, ' x=', p.x:1, ',', p.y:1);
  MapFree(PtMap, q);

  { **Keyed by an integer**, which is the row this closes. The hash and the
    equality are the program's own, in `impl Key for integer` above -- and
    they serve every subrange of integer too, an implementation being looked
    up through Base() (ADR-0340). }
  MapInit(NumMap, nm, 4);
  for i := 1 to 6 do
    MapPut(nm, i * 100, 'n' + chr(ord('0') + i));
  writeln('map by int  count=', MapCount(NumMap, nm):1,
          ' 300=', MapGet(NumMap, Short, nm, 300, '-'),
          ' has 999=', MapHas(nm, 999));
  MapFree(NumMap, nm);

  { And by a record, which has no ordering and no equality of its own until a
    program supplies one -- the case a string key could never stand in for. }
  MapInit(PtKeyed, pk, 4);
  p.x := 3; p.y := 4;
  MapPut(pk, p, 34);
  p.x := 5; p.y := 6;
  MapPut(pk, p, 56);
  writeln('map by rec  count=', MapCount(PtKeyed, pk):1,
          ' 5,6=', MapGet(PtKeyed, integer, pk, p, -1):1);
  p.x := 3; p.y := 4;
  writeln('            3,4=', MapGet(PtKeyed, integer, pk, p, -1):1);
  MapFree(PtKeyed, pk)
end.
