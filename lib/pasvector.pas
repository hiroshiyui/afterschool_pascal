{ PasVector -- a growable sequence of integers.

  A schema gives an array whose extent is chosen at run time (ADR-0039), but it
  is chosen *once*: `var v: IntVector(n)` fixes n at the declaration and there
  is no way to say "the same variable, larger". Growth therefore needs the heap,
  where 6.7.5.3's `new(p, d)` produces the type from a tuple computed at the
  call -- so this module is built on a pointer to a schema rather than on a
  schema variable, and every routine that may grow takes `var v: VecPtr`
  because growth *replaces* the variable.

  That is the whole of the design. What is left is arithmetic that must not
  trap: integer overflow is an error here (ADR-0014), so doubling a capacity is
  written as a comparison against `maxint div 2` rather than as `cap * 2`, and
  a caller asking for more than `CapMax` is refused rather than wrapped.

  There are no generics, and unlike PasSort this module cannot work around that
  by phrasing itself over positions: a container *holds* elements, so it must
  name their type. `integer` is the one chosen. A caller needing another element
  type copies this file and changes one line, which is the honest answer here
  rather than a mechanism. }

module PasVector;

export PasVector = (IntVec, VecPtr, CapMax,
                    VecNew, VecFree, VecPush, VecPop, VecGet, VecSet,
                    VecLen, VecCap, VecClear, VecReserve, VecFill, VecSum);

const
  { The largest capacity that may be asked for. Bounded so that doubling and
    `4 * cap` bytes both stay inside the integer type; a caller wanting more
    than sixteen million integers wants a file, not this. }
  CapMax = 16777216;

type
  { `n` is the live length and `a` the storage; `cap` is the discriminant and
    so is readable as `v^.cap` without being stored twice. The array is the
    **last** field because a field after a dynamically-sized one would sit at
    an offset nothing could compute (ADR-0045). }
  IntVec(cap: integer) = record
    n: integer;
    a: array [1..cap] of integer
  end;
  VecPtr = ^IntVec;

{ An empty vector with room for `cap` elements. `cap` must be in 1..CapMax;
  outside that the vector is created with capacity 1 rather than trapping,
  because a library that halts is a library that cannot be tested. }
procedure VecNew(var v: VecPtr; cap: integer);

{ Release the storage and set `v` to nil. Passing a nil `v` is harmless. }
procedure VecFree(var v: VecPtr);

{ Append `x`, doubling the capacity when it is full. Silently does nothing once
  the vector is at CapMax and full -- the alternative is halting, and a caller
  who cares can compare VecLen before and after. }
procedure VecPush(var v: VecPtr; x: integer);

{ Remove and return the last element. The vector must not be empty; when it is,
  the result is 0 and the length stays 0. }
function VecPop(var v: VecPtr): integer;

{ Element `i`, for `i` in 1..VecLen(v). Outside that range the array's own
  bounds check traps for `i` above the *capacity*, and for `i` between the
  length and the capacity the value is whatever the storage last held --
  unchecked, exactly as PasSort's `less` is unchecked, and for the same reason:
  the check would cost every access and the precondition is the caller's. }
function VecGet(v: VecPtr; i: integer): integer;

{ Store `x` at `i`, under the same precondition as VecGet. }
procedure VecSet(v: VecPtr; i, x: integer);

{ The number of live elements. }
function VecLen(v: VecPtr): integer;

{ The number that fit before the next growth. }
function VecCap(v: VecPtr): integer;

{ Forget every element without releasing the storage. }
procedure VecClear(var v: VecPtr);

{ Grow so that at least `want` elements fit, if that is more than fits now.
  Never shrinks. A caller who knows the final size calls this once and no
  push after it reallocates. }
procedure VecReserve(var v: VecPtr; want: integer);

{ Set the length to `count` and every element to `x`. Grows if needed. }
procedure VecFill(var v: VecPtr; count, x: integer);

{ The sum of the elements. Traps on overflow, as any addition here does. }
function VecSum(v: VecPtr): integer;

end;

{ The one place storage is allocated, so the one place a capacity is clamped.
  Kept separate from VecNew because VecReserve needs it too and the clamp must
  be the same both times. }
procedure Claim(var v: VecPtr; cap, keep: integer);
var q: VecPtr; i: integer;
begin
  if cap < 1 then cap := 1;
  if cap > CapMax then cap := CapMax;
  new(q, cap);
  q^.n := keep;
  for i := 1 to keep do
    q^.a[i] := v^.a[i];
  dispose(v);
  v := q
end;

procedure VecNew;
begin
  if cap < 1 then cap := 1;
  if cap > CapMax then cap := CapMax;
  new(v, cap);
  v^.n := 0
end;

procedure VecFree;
begin
  if v <> nil then begin
    dispose(v);
    v := nil
  end
end;

procedure VecPush;
var want: integer;
begin
  if v^.n = v^.cap then begin
    { doubling, written so that the product is never formed above the type }
    if v^.cap > CapMax div 2 then want := CapMax
    else want := v^.cap * 2;
    if want > v^.cap then
      Claim(v, want, v^.n)
  end;
  if v^.n < v^.cap then begin
    v^.n := v^.n + 1;
    v^.a[v^.n] := x
  end
end;

procedure VecReserve;
begin
  if want > v^.cap then
    Claim(v, want, v^.n)
end;

function VecPop;
begin
  if v^.n = 0 then
    VecPop := 0
  else begin
    VecPop := v^.a[v^.n];
    v^.n := v^.n - 1
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

procedure VecFill;
var i: integer;
begin
  if count < 0 then count := 0;
  VecReserve(v, count);
  if count > v^.cap then count := v^.cap;
  for i := 1 to count do
    v^.a[i] := x;
  v^.n := count
end;

function VecSum;
var i, total: integer;
begin
  total := 0;
  for i := 1 to v^.n do
    total := total + v^.a[i];
  VecSum := total
end;

end.
