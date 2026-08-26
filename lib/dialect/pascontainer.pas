{ PasContainer -- one growable vector and one string-keyed map, over whatever
  element type the program names.

  This is the module that four monomorphic ones were four for. `PasVector`
  holds integers, `PasStrVec` strings, `PasMap` maps a string to an integer,
  and the way to have another element type was to copy a file. Here the
  element is a *type argument* and the storage is a schema, so the module is
  written once and the program says what is in it:

      type IntVec = ^Vec(integer);       -- one line per element type
      var v: IntVec;
      begin
        VecInit(IntVec, v, 8);
        VecPush(IntVec, integer, v, 42);  -- grows past 8 by itself
        ...
        VecFree(IntVec, v)
      end

  **Why a pointer and not a value.** A growable container has to reallocate,
  and `new(p, bigger)` needs a pointer whose domain is the schema -- which is
  AP 6.4.4.1's `^Vec(integer)`, the types bound where the layout is decided
  and the capacity left open for `new` to choose per variable (ADR-0213).
  Without that a generic container could be written at one fixed capacity and
  no other, which is not a container.

  **Why two type arguments and not one.** `VecPush(IntVec, integer, v, x)`
  names both the pointer type and the element type, and the second is
  redundant -- it is `IntVec`'s own element and the compiler knows it. What
  would remove it is `x: type of v^.a[1]`, and §6.4.9's type-inquiry accepts
  only a simple name in this processor. That is a conformance gap rather than
  a language limit and is in `doc/roadmap.md`; when it closes, the second
  argument goes and no caller changes shape otherwise.

  **What this does not replace.** `PasVector`, `PasStrVec` and `PasMap` are
  ordinary Extended Pascal and stay, because generics are the dialect's and a
  conforming program must still have a vector and a map. `PasList` stays too:
  its chain is `owned ^Node` and an owned pointer's domain may not be a schema
  (ADR-0181), so a generic chain would have to make the *program* declare the
  node and the list type -- three lines of its own, for a container that is
  worse at everything but `Push` (see that module's header).

  **What is missing, and it is one thing.** The map's key is `MapKey` and not
  a type argument, because a key must be hashed and compared and the dialect
  has no way to say that of a type. That is a constraint, and the roadmap
  carries it. }
module PasContainer;

export PasContainer = (Vec, Map, MapKey, KeyMax, CapMax,
                       VecInit, VecFree, VecPush, VecPop, VecGet, VecSet,
                       VecLen, VecCap, VecClear, VecReserve,
                       MapInit, MapFree, MapPut, MapGet, MapHas, MapDelete,
                       MapCount, MapSlots, MapLiveAt, MapKeyAt,
                       HashOf, Claimed);

const
  { The largest extent `new` is asked for. A request above it is clamped
    rather than trapped, because a library that halts is a library that
    cannot be tested -- `PasVector`'s rule, kept. }
  CapMax = 1000000;
  KeyMax = 63;

type
  MapKey = string(KeyMax);

  { `cap` is the discriminant, so it is readable as `v^.cap` and is not stored
    twice. The array is the last field because a field after a
    dynamically-sized one would sit at an offset nothing could compute
    (ADR-0045). }
  Vec(T: type; cap: integer) = record
    n: integer;
    a: array [1..cap] of T
  end;

  { Open addressing with linear probing, and the storage is one array of slots
    rather than three parallel ones -- ADR-0045 lets a record hold exactly one
    discriminant-bounded array and only as its last field, since a field after
    it would sit at an offset nothing can compute. `PasMap` is shaped this way
    for the same reason; here the slot's value field is the type argument, so
    the element record is written inline rather than named.

    `state` is 0 empty, 1 live, 2 deleted. A deleted slot must be walked
    *through* when probing and may be written *into* when inserting, which is
    the whole reason it is three values and not a boolean. }
  Map(V: type; cap: integer) = record
    count: integer;
    slots: array [1..cap] of record
      key: MapKey;
      val: V;
      state: integer
    end
  end;

{ --- the vector ---------------------------------------------------------- }

{ An empty vector with room for `cap`. `Ptr` is the program's own
  `^Vec(<element>)`; every routine below takes it, and that is what makes one
  body serve every element type. }
procedure VecInit(Ptr: type; var v: Ptr; cap: integer);

{ Release the storage and leave `v` nil. A nil `v` is harmless. }
procedure VecFree(Ptr: type; var v: Ptr);

{ Append, growing when full. }
procedure VecPush(Ptr: type; Elem: type; var v: Ptr; x: Elem);

{ Take the last element off. False when there was none. }
function VecPop(Ptr: type; Elem: type; var v: Ptr; var out: Elem): boolean;

{ The i'th element, 1-based. Out of range is the caller's error and traps,
  exactly as an array subscript does. }
function VecGet(Ptr: type; Elem: type; var v: Ptr; i: integer): Elem;

procedure VecSet(Ptr: type; Elem: type; var v: Ptr; i: integer; x: Elem);

function VecLen(Ptr: type; var v: Ptr): integer;

function VecCap(Ptr: type; var v: Ptr): integer;

{ Length to nought. The storage is kept, so pushing again does not reallocate. }
procedure VecClear(Ptr: type; var v: Ptr);

{ Make room for at least `want` without changing the length. }
procedure VecReserve(Ptr: type; Elem: type; var v: Ptr; want: integer);

{ --- the map ------------------------------------------------------------- }

procedure MapInit(Ptr: type; var m: Ptr; want: integer);
procedure MapFree(Ptr: type; var m: Ptr);
procedure MapPut(Ptr: type; Elem: type; var m: Ptr; key: MapKey; val: Elem);
function MapGet(Ptr: type; Elem: type; var m: Ptr; key: MapKey;
                whenAbsent: Elem): Elem;
function MapHas(Ptr: type; var m: Ptr; key: MapKey): boolean;
function MapDelete(Ptr: type; var m: Ptr; key: MapKey): boolean;
function MapCount(Ptr: type; var m: Ptr): integer;

{ The slot walk, for a program that wants every pair. `MapSlots` is the
  capacity, `MapLiveAt` says whether a slot holds one, and `MapKeyAt` gives
  its key -- the value is `MapGet` of that key, since a generic function
  answering it would need the value type and a program walking has it. }
function MapSlots(Ptr: type; var m: Ptr): integer;
function MapLiveAt(Ptr: type; var m: Ptr; i: integer): boolean;
function MapKeyAt(Ptr: type; var m: Ptr; i: integer): MapKey;

{ The two helpers below are exported, and **not because a caller wants
  them.** A generic routine's body is translated where it is *instantiated*
  (ADR-0212), which for an imported module is the client -- and a module's own
  routines are internal to its object file under a name that is this
  translation's own counter, so a generic body calling one produces a call the
  client cannot link. Exporting gives them the stable name 6.13 defines. The
  general rule is in `doc/sop.md` §7: **a generic body may call only what its
  clients can reach**, which for a module means an exported routine or another
  generic.

  The extent `new` is asked for, clamped rather than trapped: a library that
  halts is a library that cannot be tested (`PasVector`'s rule, kept). One is
  the floor, a capacity of nought having no slot to grow from. }
function Claimed(cap: integer): integer;

{ The key's slot, taken into 1..cap. A generic routine's body is translated where it is
  *instantiated* (ADR-0212), which for an imported module is the client -- and
  a module's own routines are internal to its object file, so a generic body
  calling one produces a call the client cannot link. Exporting is what gives
  it external linkage. The general rule is in `doc/sop.md` §7: a generic body
  may call only what its clients can reach. }
function HashOf(key: MapKey; cap: integer): integer;

end;

{ --- the vector ---------------------------------------------------------- }

function Claimed;
begin
  if cap < 1 then Claimed := 1
  else if cap > CapMax then Claimed := CapMax
  else Claimed := cap
end;

procedure VecInit;
begin
  new(v, Claimed(cap));
  v^.n := 0
end;

procedure VecFree;
begin
  if v <> nil then begin
    dispose(v);
    v := nil
  end
end;

{ The reallocation every other routine here rests on, and the one thing that
  could not be written before AP 6.4.4.1: `new` is asked for a capacity this
  body does not know the element type of. }
procedure VecReserve;
var fresh: Ptr; i: integer;
begin
  if want > v^.cap then begin
    new(fresh, Claimed(want));
    fresh^.n := v^.n;
    for i := 1 to v^.n do fresh^.a[i] := v^.a[i];
    dispose(v);
    v := fresh
  end
end;

procedure VecPush;
begin
  { Doubling, so `n` pushes cost O(n) altogether. }
  if v^.n = v^.cap then VecReserve(Ptr, Elem, v, v^.cap * 2);
  v^.n := v^.n + 1;
  v^.a[v^.n] := x
end;

function VecPop;
begin
  if v^.n = 0 then VecPop := false
  else begin
    out := v^.a[v^.n];
    v^.n := v^.n - 1;
    VecPop := true
  end
end;

function VecGet;
begin
  VecGet := v^.a[i]
end;

procedure VecSet;
begin
  v^.a[i] := x
end;

function VecLen;
begin
  VecLen := v^.n
end;

function VecCap;
begin
  VecCap := v^.cap
end;

procedure VecClear;
begin
  v^.n := 0
end;

{ --- the map ------------------------------------------------------------- }

{ A shift-and-add over the characters, `PasMap`'s unchanged. The multiplier is
  odd so that every bit of a character reaches the sum. }
function HashOf;
var h, i: integer;
begin
  h := 0;
  for i := 1 to length(key) do
    h := (h * 31 + ord(key[i])) mod cap;
  HashOf := h + 1
end;

{ The slot this key occupies, or the first free one on its probe sequence.
  Zero when the table is full, which MapPut turns into a rehash. }
function FindSlot(Ptr: type; var m: Ptr; key: MapKey): integer;
var i, seen, found, freeAt: integer;
begin
  found := 0;
  { The first deleted slot passed, which is where an insertion goes if the key
    turns out not to be here -- reusing it is what keeps a table that is
    churned from filling up with tombstones. }
  freeAt := 0;
  seen := 0;
  i := HashOf(key, m^.cap);
  while (found = 0) and (seen < m^.cap) do begin
    if m^.slots[i].state = 0 then found := i
    else begin
      if (m^.slots[i].state = 1) and (m^.slots[i].key = key) then found := i
      else if (m^.slots[i].state = 2) and (freeAt = 0) then freeAt := i;
      if found = 0 then begin
        i := i + 1;
        if i > m^.cap then i := 1;
        seen := seen + 1
      end
    end
  end;
  { An empty slot found with a tombstone behind it: insert into the tombstone,
    which is nearer the key's own hash. A live match is answered as found. }
  if (found <> 0) and (freeAt <> 0) then
    if m^.slots[found].state = 0 then found := freeAt;
  if (found = 0) and (freeAt <> 0) then found := freeAt;
  FindSlot := found
end;

procedure MapInit;
var i: integer;
begin
  new(m, Claimed(want));
  m^.count := 0;
  for i := 1 to m^.cap do begin
    m^.slots[i].state := 0;
    m^.slots[i].key := ''
  end
end;

procedure MapFree;
begin
  if m <> nil then begin
    dispose(m);
    m := nil
  end
end;

{ Grown at three quarters full, which keeps the probe sequences short. The
  rehash is a fresh table and a walk, for AP 6.4.4.1's reason again: `new` is
  asked for a capacity without knowing what the values are. }
procedure MapPut;
var fresh: Ptr; i, slot: integer;
begin
  if (m^.count + 1) * 4 > m^.cap * 3 then begin
    new(fresh, Claimed(m^.cap * 2));
    fresh^.count := 0;
    for i := 1 to fresh^.cap do begin
      fresh^.slots[i].state := 0;
      fresh^.slots[i].key := ''
    end;
    { A rehash drops the tombstones: only live slots are carried over, which
      is the other reason a table is grown rather than merely made larger. }
    for i := 1 to m^.cap do
      if m^.slots[i].state = 1 then begin
        slot := FindSlot(Ptr, fresh, m^.slots[i].key);
        fresh^.slots[slot].state := 1;
        fresh^.slots[slot].key := m^.slots[i].key;
        fresh^.slots[slot].val := m^.slots[i].val;
        fresh^.count := fresh^.count + 1
      end;
    dispose(m);
    m := fresh
  end;
  slot := FindSlot(Ptr, m, key);
  if slot <> 0 then begin
    if m^.slots[slot].state <> 1 then m^.count := m^.count + 1;
    m^.slots[slot].state := 1;
    m^.slots[slot].key := key;
    m^.slots[slot].val := val
  end
end;

function MapGet;
var slot: integer;
begin
  slot := FindSlot(Ptr, m, key);
  if slot = 0 then MapGet := whenAbsent
  else if m^.slots[slot].state <> 1 then MapGet := whenAbsent
  else MapGet := m^.slots[slot].val
end;

function MapHas;
var slot: integer;
begin
  slot := FindSlot(Ptr, m, key);
  if slot = 0 then MapHas := false
  else MapHas := m^.slots[slot].state = 1
end;

function MapDelete;
var slot: integer;
begin
  slot := FindSlot(Ptr, m, key);
  if slot = 0 then MapDelete := false
  else if m^.slots[slot].state <> 1 then MapDelete := false
  else begin
    { A tombstone rather than an empty slot, so a probe sequence running
      through here still reaches what is beyond it. }
    m^.slots[slot].state := 2;
    m^.count := m^.count - 1;
    MapDelete := true
  end
end;

function MapCount;
begin
  MapCount := m^.count
end;

function MapSlots;
begin
  MapSlots := m^.cap
end;

function MapLiveAt;
begin
  MapLiveAt := m^.slots[i].state = 1
end;

function MapKeyAt;
begin
  MapKeyAt := m^.slots[i].key
end;

end.
