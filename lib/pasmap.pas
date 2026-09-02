{ PasMap -- a dictionary from a short string to an integer.

  This is the module that found the defect ADR-0018's trapping case-statement
  had been hiding: a table is `array [1..cap] of record key: string(k); ... end`
  inside a schema, and until Sema's StaticThroughout grew a tyString arm no such
  type could be allocated at all. Nothing in the corpus had written a string
  inside a schema domain, so every oracle agreed it worked.

  Open addressing with linear probing, and tombstones for deletion. The
  alternative -- a chain of pointers per bucket -- costs an allocation per
  entry and buys nothing here, where the values are integers and the keys are
  bounded.

  Two pieces of arithmetic are written the way they are because integer
  overflow traps (ADR-0014):

  - the hash accumulates modulo `HashMod` at every character rather than at the
    end, so the product never approaches maxint however long the key;
  - the load-factor test is `live * 4 >= cap * 3` with `cap` bounded by
    `SMapCapMax`, so neither side can overflow.

  As with PasVector there are no generics, so the value type is `integer` and
  a caller wanting another copies the file. The *key* type is fixed for a
  second reason: it is a component of the slot record, so its capacity is part
  of the table's layout and cannot come from the caller. }

module PasMap;

export PasMap = (SMapKey, SMapKeyMax, SMapCapMax, StrMap, SMapPtr,
                 SMapNew, SMapFree, SMapPut, SMapGet, SMapHas, SMapDelete,
                 SMapCount, SMapSlots, SMapLiveAt, SMapKeyAt, SMapValAt);

const
  { A key longer than this is refused by 6.4.6's string store, which is a trap
    rather than a truncation -- so a caller passing arbitrary text should trim
    it to SMapKeyMax first. Stated here because it is the one way to make this
    module halt a program. }
  SMapKeyMax = 32;
  { Slots, not entries: the table never exceeds three-quarters full. }
  SMapCapMax = 4194304;
  { The hash is taken modulo this before the table size, so the accumulation
    stays far below maxint whatever the key. Prime, and about 2^20. }
  HashMod = 1048573;

type
  SMapKey = string(SMapKeyMax);

  { `state` is 0 empty, 1 live, 2 deleted. A deleted slot must be walked
    *through* when probing and may be written *into* when inserting, which is
    the whole reason it is three values and not a boolean. }
  Slot = record
    key: SMapKey;
    val: integer;
    state: integer
  end;

  StrMap(cap: integer) = record
    live: integer;
    filled: integer;
    slots: array [1..cap] of Slot
  end;
  SMapPtr = ^StrMap;

{ An empty map with at least `want` slots, rounded up to at least 8. }
procedure SMapNew(var m: SMapPtr; want: integer);

{ Release the storage and set `m` to nil. A nil `m` is harmless. }
procedure SMapFree(var m: SMapPtr);

{ Associate `val` with `key`, replacing any previous association. Grows when
  the table passes three-quarters full. }
procedure SMapPut(var m: SMapPtr; key: SMapKey; val: integer);

{ The value associated with `key`, or `whenAbsent` when there is none. There is
  no out-of-band integer to reserve for "missing", so the caller supplies one --
  or asks SMapHas, which is the unambiguous question. }
function SMapGet(m: SMapPtr; key: SMapKey; whenAbsent: integer): integer;

{ Whether `key` has an association. }
function SMapHas(m: SMapPtr; key: SMapKey): boolean;

{ Remove `key`'s association if it has one. Answers whether it did. }
function SMapDelete(m: SMapPtr; key: SMapKey): boolean;

{ The number of live associations. }
function SMapCount(m: SMapPtr): integer;

{ The number of slots, which is the bound for the iteration below. Iteration is
  phrased over slot positions rather than as a cursor because a cursor would be
  state this module would have to own; the caller walks 1..SMapSlots and asks
  SMapLiveAt at each. The order is the table's and not the insertion order. }
function SMapSlots(m: SMapPtr): integer;

{ Whether slot `i` holds a live association. }
function SMapLiveAt(m: SMapPtr; i: integer): boolean;

{ The key in slot `i`. Meaningful only where SMapLiveAt answers true. }
function SMapKeyAt(m: SMapPtr; i: integer): SMapKey;

{ The value in slot `i`. Meaningful only where SMapLiveAt answers true. }
function SMapValAt(m: SMapPtr; i: integer): integer;

end;

{ 1..cap, from the key. Accumulated modulo HashMod so the product is never
  formed near the top of the type. }
function HashOf(key: SMapKey; cap: integer): integer;
var i, h: integer;
begin
  h := 0;
  for i := 1 to length(key) do
    h := (h * 31 + ord(key[i])) mod HashMod;
  HashOf := (h mod cap) + 1
end;

{ The slot `key` occupies, or 0 when it occupies none. Walks through deleted
  slots and stops at an empty one; bounded by `cap` steps so a table with no
  empty slot left cannot loop forever. }
function FindSlot(m: SMapPtr; key: SMapKey): integer;
var at, steps, found: integer;
begin
  found := 0;
  at := HashOf(key, m^.cap);
  steps := 0;
  while (steps < m^.cap) and (found = 0) and (m^.slots[at].state <> 0) do begin
    if (m^.slots[at].state = 1) and (m^.slots[at].key = key) then
      found := at
    else begin
      at := at + 1;
      if at > m^.cap then at := 1;
      steps := steps + 1
    end
  end;
  FindSlot := found
end;

{ Insert into a table known to have room, without growing and without looking
  for a duplicate: the caller has already established there is none. Used by
  Rehash, where every key is distinct by construction. }
procedure PlaceFresh(m: SMapPtr; key: SMapKey; val: integer);
var at: integer;
begin
  at := HashOf(key, m^.cap);
  while m^.slots[at].state = 1 do begin
    at := at + 1;
    if at > m^.cap then at := 1
  end;
  m^.slots[at].key := key;
  m^.slots[at].val := val;
  m^.slots[at].state := 1
end;

{ Move every live association into a table of `cap` slots. Tombstones do not
  survive, which is what makes a table of many deletions recover its speed. }
procedure Rehash(var m: SMapPtr; cap: integer);
var q: SMapPtr; i: integer;
begin
  if cap > SMapCapMax then cap := SMapCapMax;
  new(q, cap);
  q^.live := 0;
  q^.filled := 0;
  for i := 1 to cap do
    q^.slots[i].state := 0;
  for i := 1 to m^.cap do
    if m^.slots[i].state = 1 then
      PlaceFresh(q, m^.slots[i].key, m^.slots[i].val);
  q^.live := m^.live;
  q^.filled := m^.live;
  dispose(m);
  m := q
end;

procedure SMapNew;
var i, cap: integer;
begin
  cap := 8;
  while (cap < want) and (cap < SMapCapMax div 2) do
    cap := cap * 2;
  if cap > SMapCapMax then cap := SMapCapMax;
  new(m, cap);
  m^.live := 0;
  m^.filled := 0;
  for i := 1 to cap do
    m^.slots[i].state := 0
end;

procedure SMapFree;
begin
  if m <> nil then begin
    dispose(m);
    m := nil
  end
end;

procedure SMapPut;
var at, steps: integer; placed: boolean;
begin
  { grow first, so the insert below always has an empty slot to stop at }
  if (m^.filled * 4 >= m^.cap * 3) and (m^.cap < SMapCapMax) then
    Rehash(m, m^.cap * 2);

  at := FindSlot(m, key);
  if at <> 0 then
    m^.slots[at].val := val
  else begin
    at := HashOf(key, m^.cap);
    steps := 0;
    placed := false;
    while (steps <= m^.cap) and not placed do begin
      if m^.slots[at].state <> 1 then begin
        { an empty slot adds to `filled`; reusing a tombstone does not }
        if m^.slots[at].state = 0 then
          m^.filled := m^.filled + 1;
        m^.slots[at].key := key;
        m^.slots[at].val := val;
        m^.slots[at].state := 1;
        m^.live := m^.live + 1;
        placed := true
      end
      else begin
        at := at + 1;
        if at > m^.cap then at := 1;
        steps := steps + 1
      end
    end
  end
end;

function SMapGet;
var at: integer;
begin
  at := FindSlot(m, key);
  if at = 0 then SMapGet := whenAbsent
  else SMapGet := m^.slots[at].val
end;

function SMapHas;
begin
  SMapHas := FindSlot(m, key) <> 0
end;

function SMapDelete;
var at: integer;
begin
  at := FindSlot(m, key);
  if at = 0 then
    SMapDelete := false
  else begin
    { 2 and not 0: a probe that started before this slot must still walk
      through it to reach what follows }
    m^.slots[at].state := 2;
    m^.live := m^.live - 1;
    SMapDelete := true
  end
end;

function SMapCount;
begin
  SMapCount := m^.live
end;

function SMapSlots;
begin
  SMapSlots := m^.cap
end;

function SMapLiveAt;
begin
  SMapLiveAt := m^.slots[i].state = 1
end;

function SMapKeyAt;
begin
  SMapKeyAt := m^.slots[i].key
end;

function SMapValAt;
begin
  SMapValAt := m^.slots[i].val
end;

end.
