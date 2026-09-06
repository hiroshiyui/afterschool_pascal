{ PasContainer: the map's key capacity is the program's, and 63 is not a bound
  (ADR-0290, ADR-0310).

  `MapKey` is `string(63)` and is exported as a ready-made key type for a
  program that wants one. It has been mistaken for a limit twice -- once by
  `lsp/pasls.pas`, which kept its documents in a linearly searched vector for
  that reason (ADR-0290), and once by ADR-0295's sixth finding, which read
  `examples/word_freq.pas`'s guard as the map's bound. This case is what says
  otherwise: three maps keyed at three capacities, none of them 63, holding
  keys 63 is far too small for, and every one of them served by the module's
  own `StrHash`/`StrEq` -- which is the half that was ever a bound, and stopped
  being one when AP 6.7.3.6 made the pair schematic. Since ADR-0355 the pair is
  reached through `impl Key for <the key type>` rather than passed at every
  call, and this case's golden did not change, which is the point.

  It also reads the key's **capacity** off the map itself. §6.4.3.3.3 gives a
  string schema a `capacity` discriminant, so a program that must guard a key
  it cannot bound writes the guard against that rather than against a number
  copied out of a type definition -- and nothing in this case spells 200
  twice. }
program lib_container_key(output);

import PasContainer;

const
  Wide = 200;

type
  WideKey = string(Wide);
  NarrowKey = string(8);

{ Three key types, three implementations, and that is the rule rather than a
  cost of this case: a type has at most one implementation of a trait in a
  program-component (AP 6.7.10), and `string(200)`, `string(8)` and
  `string(63)` are three types (ADR-0355). Each is two lines because the
  module's `StrHash`/`StrEq` are schematic and serve any capacity (ADR-0290)
  -- what they no longer do is travel through every call. The implementations
  stand *before* the map types below because 6.2.2.9 makes written order the
  only correct one, and AP 6.4.7.2 checks the bound where the type is produced. }
impl Key for WideKey;
  function Hash;
  begin Hash := StrHash(k) end;
  function Same;
  begin Same := StrEq(a, b) end;
end;

impl Key for NarrowKey;
  function Hash;
  begin Hash := StrHash(k) end;
  function Same;
  begin Same := StrEq(a, b) end;
end;

impl Key for MapKey;
  function Hash;
  begin Hash := StrHash(k) end;
  function Same;
  begin Same := StrEq(a, b) end;
end;

type
  WideMap = ^Map(WideKey, integer);
  NarrowMap = ^Map(NarrowKey, integer);
  ReadyMap = ^Map(MapKey, integer);

var
  wm: WideMap;
  nm: NarrowMap;
  rm: ReadyMap;
  long, other: WideKey;
  i: integer;

{ A key of `n` times 'ab', so that two long keys sharing a 63-character prefix
  are still two keys: a library that clamped to `KeyMax` would make these one. }
function Repeated(n: integer; tail: char): WideKey;
var s: WideKey; k: integer;
begin
  s := '';
  for k := 1 to n do s := s + 'ab';
  Repeated := s + tail
end;

begin
  long := Repeated(65, 'x');
  other := Repeated(65, 'y');

  MapInit(wm, 4);
  MapPut(wm, long, 11);
  MapPut(wm, other, 22);
  { And enough more to make the table rehash with keys this long in it. }
  for i := 1 to 12 do
    MapPut(wm, Repeated(i + 40, 'z'), i);

  writeln('wide  cap=', wm^.slots[1].key.capacity:1,
          ' len=', length(long):1,
          ' get=', MapGet(wm, long, 0):1,
          ' other=', MapGet(wm, other, 0):1,
          ' count=', MapCount(wm):1);
  writeln('wide  has=', MapHas(wm, long),
          ' absent=', MapHas(wm, Repeated(65, 'q')),
          ' deleted=', MapDelete(wm, other),
          ' count=', MapCount(wm):1);

  { The key that came back out of a slot is the whole key and not a prefix. }
  for i := 1 to MapSlots(wm) do
    if MapLiveAt(wm, i) then
      if MapKeyAt(WideKey, wm, i) = long then
        writeln('wide  found at length ',
                length(MapKeyAt(WideKey, wm, i)):1);

  { Below 63 as well: the pair is congruent with any capacity, not with 63 or
    more. }
  MapInit(nm, 4);
  MapPut(nm, 'abcdefgh', 7);
  writeln('narrow cap=', nm^.slots[1].key.capacity:1,
          ' get=', MapGet(nm, 'abcdefgh', 0):1);

  { And the ready-made type still works, which is all it ever claimed. }
  MapInit(rm, 4);
  MapPut(rm, 'ready', 3);
  writeln('ready  cap=', rm^.slots[1].key.capacity:1,
          ' keymax=', KeyMax:1,
          ' get=', MapGet(rm, 'ready', 0):1);

  MapFree(rm);
  MapFree(nm);
  MapFree(wm)
end.
