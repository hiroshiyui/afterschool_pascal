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
                       VecLen, VecCap, VecClear, VecReserve, VecFull,
                       MapInit, MapFree, MapPut, MapGet, MapHas, MapDelete,
                       MapCount, MapSlots, MapLiveAt, MapKeyAt,
                       StrHash, StrEq, Slot, Claimed);

const
  { The largest extent `new` is asked for, in **elements** -- an element's
    size is the caller's, this being a generic. A request above it is clamped
    rather than trapped, because a library that halts is a library that cannot
    be tested -- `PasVector`'s rule, kept, and `PasStrVec` states its own
    number in bytes because it knows its element.

    It was 1 000 000 and that was never measured against anything (ADR-0276).
    `JsonChars` is a `Vec(char)`, so the ceiling was a megabyte of document --
    and `selfhost/apfront.pas` is 992 056 bytes, which is 1 017 200 once it is
    a JSON string, so the language server could not open the largest source in
    the tree it was written for. Sixteen million is 15.7 times that message
    and 16 MB of `char`; a caller pushing sixteen million *records* is a
    runaway, and `VecFull` is how it finds out. }
  CapMax = 16000000;
  KeyMax = 63;

  { What `StrHash` reduces its running sum by. Not a capacity -- a caller's
    hash answers a number over the whole space and the map reduces it -- but a
    bound that keeps the shift-and-add from overflowing: this language traps
    integer overflow (ADR-0014) rather than wrapping, so a hash that let its
    accumulator run would stop the program on a long enough key. A prime, so
    that the reduction does not itself throw away the low bits the multiplier
    just mixed in. }
  HashSpread = 1000003;

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
  Map(K: type; V: type; cap: integer) = record
    count: integer;
    slots: array [1..cap] of record
      key: K;
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
procedure VecPush(Ptr: type; var v: Ptr; x: type of v^.a[1]);

{ Take the last element off. False when there was none. }
function VecPop(Ptr: type; var v: Ptr; var out: type of v^.a[1]): boolean;

{ The i'th element, 1-based. Out of range is the caller's error and traps,
  exactly as an array subscript does. }
function VecGet(Ptr: type; Elem: type; var v: Ptr; i: integer): Elem;

procedure VecSet(Ptr: type; var v: Ptr; i: integer; x: type of v^.a[1]);

function VecLen(Ptr: type; var v: Ptr): integer;

function VecCap(Ptr: type; var v: Ptr): integer;

{ Is this vector at `CapMax`, where a push has nowhere to go?

  Not `VecLen = VecCap`, which is true of an ordinary vector about to double
  and says nothing. This is the *ceiling*: `Claimed` clamps a request at
  CapMax, so a vector already that large cannot grow and `VecPush` into it
  does nothing. A caller whose input is someone else's -- a document buffer,
  a message body -- asks this and reports, rather than discovering the loss in
  what it reads back (ADR-0276). }
function VecFull(Ptr: type; var v: Ptr): boolean;

{ Length to nought. The storage is kept, so pushing again does not reallocate. }
procedure VecClear(Ptr: type; var v: Ptr);

{ Make room for at least `want` without changing the length. }
procedure VecReserve(Ptr: type; var v: Ptr; want: integer);

{ --- the map ------------------------------------------------------------- }

{ **The key is the program's own type**, and the hash and the equality travel
  with each operation as procedural parameters.

  `doc/roadmap.md` carried "a hash of anything but a string" as waiting on a
  *constraint* -- "a way to say that a key can be hashed and compared, and the
  dialect has none". It does not need one. §6.7.3.4 and §6.7.3.5 have admitted
  a procedural parameter since ISO 7185, `PasSort` has used exactly this shape
  since it was written to avoid ever seeing an element, and a formal
  procedural parameter may be handed on to another generic routine -- which is
  the whole of what a hash table's internals need. What a constraint would buy
  is not the capability but the two arguments, and that is an ergonomic
  question rather than an expressive one.

  It costs less than it reads, and two features that landed for other reasons
  are why. The key's type is written `type of m^.slots[1].key` (AP 6.4.9 as
  ADR-0215 widened it), so it is read off the map the caller handed over
  rather than named again -- which also makes the *hash's* own parameter type
  follow the map, so a hash for the wrong key type is refused by §6.7.3.6's
  congruence rather than accepted and misused. And AP 6.7.3.10.4 infers `Ptr`
  from `m` (ADR-0254), so `MapPut(m, 'k', 1, StrHash, StrEq)` names no type at
  all. The two that must still be written are `MapGet`'s and `MapKeyAt`'s
  element types, which stand only in a result -- §6.7.1 makes a result-type a
  type-name and not an actual.

  Binding `K` as an ordinary type parameter was tried first and is worth the
  sentence: inference then took `K` from the *actual key*, so `MapPut(m, 'k3',
  …)` bound it to the literal's own string type rather than to the map's, and
  every hash was refused as incongruent. The type-inquiry is not a
  convenience here -- it is what makes the key type the map's.

  `StrHash` and `StrEq` below are the ready-made pair for the commonest key. }
procedure MapInit(Ptr: type; var m: Ptr; want: integer);
procedure MapFree(Ptr: type; var m: Ptr);
procedure MapPut(Ptr: type; var m: Ptr;
                 key: type of m^.slots[1].key;
                 val: type of m^.slots[1].val;
                 function hash(k: type of m^.slots[1].key): integer;
                 function eq(a, b: type of m^.slots[1].key): boolean);
function MapGet(Ptr: type; Elem: type; var m: Ptr;
                key: type of m^.slots[1].key;
                whenAbsent: Elem;
                function hash(k: type of m^.slots[1].key): integer;
                function eq(a, b: type of m^.slots[1].key): boolean): Elem;
function MapHas(Ptr: type; var m: Ptr;
                key: type of m^.slots[1].key;
                function hash(k: type of m^.slots[1].key): integer;
                function eq(a, b: type of m^.slots[1].key): boolean): boolean;
function MapDelete(Ptr: type; var m: Ptr;
                   key: type of m^.slots[1].key;
                   function hash(k: type of m^.slots[1].key): integer;
                   function eq(a, b: type of m^.slots[1].key): boolean):
                   boolean;
function MapCount(Ptr: type; var m: Ptr): integer;

{ The slot walk, for a program that wants every pair. `MapSlots` is the
  capacity, `MapLiveAt` says whether a slot holds one, and `MapKeyAt` gives
  its key -- the value is `MapGet` of that key, since a generic function
  answering it would need the value type and a program walking has it. }
function MapSlots(Ptr: type; var m: Ptr): integer;
function MapLiveAt(Ptr: type; var m: Ptr; i: integer): boolean;
{ Meaningful only where `MapLiveAt` is true. A slot that has never held a pair
  has a key that was never written -- §6.5.1 makes it totally-undefined -- and
  there is nothing this routine could put there instead, an arbitrary key type
  having no empty value to clear it to. The string-keyed map used to clear the
  field to `''`, which made a dead slot's key merely misleading rather than
  undefined; the contract was the same then and is stated here now that it has
  to be. }
function MapKeyAt(Ptr: type; K: type; var m: Ptr; i: integer): K;

{ The hash and the equality for a string key, which is what a map is keyed by
  most of the time. Exported so that the commonest case is `MapPut(m, name, 1,
  StrHash, StrEq)` and not a pair of routines every client writes again.

  **The parameters are schematic, so the pair serves a map keyed at any
  capacity** (AP 6.7.3.6, ADR-0290). They were `MapKey` -- `string(63)` -- and
  6.7.3.6's congruity is exact, so a map keyed on anything else got the pair
  refused and its client wrote eight lines of its own. `lsp/pasls.pas` read
  that refusal as the *map's* bound and kept its documents in a linearly
  searched vector; the map has been generic over its key since ADR-0254 and
  the bound was never its. `MapKey` and `KeyMax` remain exported as a
  ready-made key type for a client that wants one, and are no longer a limit
  on anything. }
function StrHash(key: string): integer;
function StrEq(a, b: string): boolean;

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

{ A hash taken into 1..cap. A generic routine's body is translated where it is
  *instantiated* (ADR-0212), which for an imported module is the client -- and
  a module's own routines are internal to its object file, so a generic body
  calling one produces a call the client cannot link. Exporting is what gives
  it external linkage. The general rule is in `doc/sop.md` §7: a generic body
  may call only what its clients can reach. }
function Slot(h, cap: integer): integer;

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
  { `Claimed(want)` and not `want`, because a request above CapMax comes back
    clamped: asking `want > v^.cap` at the ceiling was true of every request,
    so a vector already that large reallocated and copied a million elements
    on **every** push and a 2 MB document never finished arriving. What is
    being asked is whether the vector would actually be bigger (ADR-0276). }
  if Claimed(want) > v^.cap then begin
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
  if v^.n = v^.cap then VecReserve(Ptr, v, v^.cap * 2);
  { `Claimed` clamps at CapMax, so a reserve at the ceiling hands back a
    vector of the same capacity and this element has nowhere to go. It used to
    be written anyway, and `v^.a[v^.n]` then indexed one past the array -- a
    **trap**, in a library whose policy where CapMax is declared is to clamp
    rather than halt. It cost the language server every document of a million
    bytes or more, and `selfhost/apfront.pas` is 992 056 (ADR-0276).

    A full vector now keeps what it has and `VecFull` is how a caller asks. }
  if v^.n < v^.cap then begin
    v^.n := v^.n + 1;
    v^.a[v^.n] := x
  end
end;

function VecFull;
begin
  { Both halves: a vector at the ceiling with room still in it accepts the
    next element like any other, and only one that is *also* at its own length
    has nowhere to put it. }
  VecFull := (v^.n >= v^.cap) and (v^.cap >= CapMax)
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
  odd so that every bit of a character reaches the sum. The reduction is
  `Slot`'s now, so this answers a number over the whole range rather than a
  slot: a caller's own hash is under no obligation to know the capacity, and
  one that reduced would have to be told it. }
function StrHash;
var h, i: integer;
begin
  h := 0;
  for i := 1 to length(key) do
    h := (h * 31 + ord(key[i])) mod HashSpread;
  StrHash := h
end;

function StrEq;
begin
  StrEq := a = b
end;

{ A hash taken into 1..cap. `mod` yields a non-negative result in this
  language whatever the sign of its left operand, which is what makes a
  caller's hash free to be any integer at all -- there is no `abs` here and
  none is needed, and `abs(-maxint - 1)` would overflow if there were. }
function Slot;
begin
  Slot := (h mod cap) + 1
end;

{ The slot this key occupies, or the first free one on its probe sequence.
  Zero when the table is full, which MapPut turns into a rehash. }
function FindSlot(Ptr: type; var m: Ptr;
                  key: type of m^.slots[1].key;
                  function hash(k: type of m^.slots[1].key): integer;
                  function eq(a, b: type of m^.slots[1].key): boolean):
                  integer;
var i, seen, found, freeAt: integer;
begin
  found := 0;
  { The first deleted slot passed, which is where an insertion goes if the key
    turns out not to be here -- reusing it is what keeps a table that is
    churned from filling up with tombstones. }
  freeAt := 0;
  seen := 0;
  i := Slot(hash(key), m^.cap);
  while (found = 0) and (seen < m^.cap) do begin
    if m^.slots[i].state = 0 then found := i
    else begin
      if (m^.slots[i].state = 1) and eq(m^.slots[i].key, key) then found := i
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
  { The state alone. There is nothing to clear the key to now that it is the
    program's own type -- an arbitrary type has no empty value -- and there
    never was a need: `state` is what says whether a slot holds a pair, and
    every read of a key is behind it. }
  for i := 1 to m^.cap do
    m^.slots[i].state := 0
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
    for i := 1 to fresh^.cap do
      fresh^.slots[i].state := 0;
    { A rehash drops the tombstones: only live slots are carried over, which
      is the other reason a table is grown rather than merely made larger.
      The caller's own hash and equality are handed on -- a formal procedural
      parameter may be another routine's actual (§6.7.3.4), which is what lets
      the whole of this table be generic over its key without the module ever
      seeing one. }
    for i := 1 to m^.cap do
      if m^.slots[i].state = 1 then begin
        slot := FindSlot(Ptr, fresh, m^.slots[i].key, hash, eq);
        fresh^.slots[slot].state := 1;
        fresh^.slots[slot].key := m^.slots[i].key;
        fresh^.slots[slot].val := m^.slots[i].val;
        fresh^.count := fresh^.count + 1
      end;
    dispose(m);
    m := fresh
  end;
  slot := FindSlot(Ptr, m, key, hash, eq);
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
  slot := FindSlot(Ptr, m, key, hash, eq);
  if slot = 0 then MapGet := whenAbsent
  else if m^.slots[slot].state <> 1 then MapGet := whenAbsent
  else MapGet := m^.slots[slot].val
end;

function MapHas;
var slot: integer;
begin
  slot := FindSlot(Ptr, m, key, hash, eq);
  if slot = 0 then MapHas := false
  else MapHas := m^.slots[slot].state = 1
end;

function MapDelete;
var slot: integer;
begin
  slot := FindSlot(Ptr, m, key, hash, eq);
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
