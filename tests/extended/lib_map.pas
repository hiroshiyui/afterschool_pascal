{ PasMap. The interesting cases are the ones open addressing gets wrong when
  the probe is written carelessly, so each is here on purpose:

  - a key that is *replaced* must not add a second association;
  - a deleted slot must be walked **through** by a probe that started before
    it, or a key inserted after a collision becomes unreachable the moment its
    neighbour is deleted;
  - a deleted slot must be *reused* by a later insert, or a table that is
    filled and emptied repeatedly grows without bound;
  - growth must carry every live association across and drop the tombstones.

  What is deliberately *not* pinned is the order iteration produces. It is the
  table's order, which is the hash's, and a golden that encoded it would fail
  the day the hash changed for a reason that has nothing to do with the caller.
  So the walk below sums rather than prints. }
program lib_map(output);

import PasMap;

var
  m: MapPtr;
  i, seen, total: integer;
  k: MapKey;
  hit: boolean;

begin
  MapNew(m, 8);
  writeln('empty count=', MapCount(m):1);

  { a literal actual for a string value parameter, which ADR-0115 is what made
    legal -- before it every key here needed a named variable }
  MapPut(m, 'alpha', 1);
  MapPut(m, 'beta', 2);
  MapPut(m, 'gamma', 3);
  writeln('count=', MapCount(m):1);
  writeln('alpha=', MapGet(m, 'alpha', -1):1,
          ' beta=', MapGet(m, 'beta', -1):1,
          ' gamma=', MapGet(m, 'gamma', -1):1);
  writeln('absent=', MapGet(m, 'delta', -1):1,
          ' has=', MapHas(m, 'delta'));

  { replacing must not add }
  MapPut(m, 'beta', 20);
  writeln('replaced beta=', MapGet(m, 'beta', -1):1,
          ' count=', MapCount(m):1);

  { delete, and the neighbours must stay reachable }
  hit := MapDelete(m, 'beta');
  writeln('deleted=', hit, ' count=', MapCount(m):1,
          ' has beta=', MapHas(m, 'beta'));
  writeln('alpha still=', MapGet(m, 'alpha', -1):1,
          ' gamma still=', MapGet(m, 'gamma', -1):1);

  { deleting what is not there answers false and changes nothing }
  hit := MapDelete(m, 'beta');
  writeln('second delete=', hit, ' count=', MapCount(m):1);

  { and the slot is reusable }
  MapPut(m, 'delta', 4);
  writeln('after reuse count=', MapCount(m):1,
          ' delta=', MapGet(m, 'delta', -1):1);

  MapFree(m);

  { growth: 8 slots to hold 200 associations, so several rehashes, and every
    one of them must carry the whole table }
  MapNew(m, 8);
  for i := 1 to 200 do begin
    writestr(k, 'key', i:1);
    MapPut(m, k, i * 3)
  end;
  writeln('grown count=', MapCount(m):1, ' slots>=', MapSlots(m) >= 200);

  seen := 0;
  for i := 1 to 200 do begin
    writestr(k, 'key', i:1);
    if MapGet(m, k, -1) = i * 3 then seen := seen + 1
  end;
  writeln('retrieved=', seen:1);

  { iteration reaches every live association exactly once, which the sum says
    without depending on the order }
  total := 0;
  seen := 0;
  for i := 1 to MapSlots(m) do
    if MapLiveAt(m, i) then begin
      seen := seen + 1;
      total := total + MapValAt(m, i)
    end;
  writeln('walked=', seen:1, ' total=', total:1);

  { 3 * (1 + ... + 200) }
  writeln('expected=', 3 * (200 * 201) div 2:1);

  { a key found by iteration is a key the map still has }
  hit := true;
  for i := 1 to MapSlots(m) do
    if MapLiveAt(m, i) then
      if not MapHas(m, MapKeyAt(m, i)) then hit := false;
  writeln('every walked key present=', hit);

  { delete half, and the rest must survive }
  for i := 1 to 200 do
    if i mod 2 = 0 then begin
      writestr(k, 'key', i:1);
      hit := MapDelete(m, k)
    end;
  writeln('after deleting evens count=', MapCount(m):1);
  seen := 0;
  for i := 1 to 200 do begin
    writestr(k, 'key', i:1);
    if MapHas(m, k) then seen := seen + 1
  end;
  writeln('odds still present=', seen:1);

  MapFree(m);
  writeln('done')
end.
