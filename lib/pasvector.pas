{ PasVector -- a growable sequence of integers.

  A schema gives an array whose extent is chosen at run time (ADR-0039), but it
  is chosen *once*: `var v: IntVector(n)` fixes n at the declaration and there
  is no way to say "the same variable, larger". Growth therefore needs the heap,
  where 6.7.5.3's `new(p, d)` produces the type from a tuple computed at the
  call -- so this module is built on a pointer to a schema rather than on a
  schema variable, and every routine that may grow takes `var v: IVecPtr`
  because growth *replaces* the variable.

  That is the whole of the design. What is left is arithmetic that must not
  trap: integer overflow is an error here (ADR-0014), so doubling a capacity is
  written as a comparison against `maxint div 2` rather than as `cap * 2`, and
  a caller asking for more than `IVecCapMax` is refused rather than wrapped.

  There are no generics, and unlike PasSort this module cannot work around that
  by phrasing itself over positions: a container *holds* elements, so it must
  name their type. `integer` is the one chosen. A caller needing another element
  type copies this file and changes one line, which is the honest answer here
  rather than a mechanism. }

module PasVector;

export PasVector = (IntVec, IVecPtr, IVecCapMax,
                    IVecNew, IVecFree, IVecPush, IVecPop, IVecGet, IVecSet,
                    IVecLen, IVecCap, IVecClear, IVecReserve, IVecFill, IVecSum);

const
  { The largest capacity that may be asked for. Bounded so that doubling and
    `4 * cap` bytes both stay inside the integer type; a caller wanting more
    than sixteen million integers wants a file, not this. }
  IVecCapMax = 16777216;

type
  { `n` is the live length and `a` the storage; `cap` is the discriminant and
    so is readable as `v^.cap` without being stored twice. The array is the
    **last** field because a field after a dynamically-sized one would sit at
    an offset nothing could compute (ADR-0045). }
  IntVec(cap: integer) = record
    n: integer;
    a: array [1..cap] of integer
  end;
  IVecPtr = ^IntVec;

{ An empty vector with room for `cap` elements. `cap` must be in 1..IVecCapMax;
  outside that the vector is created with capacity 1 rather than trapping,
  because a library that halts is a library that cannot be tested. }
procedure IVecNew(var v: IVecPtr; cap: integer);

{ Release the storage and set `v` to nil. Passing a nil `v` is harmless. }
procedure IVecFree(var v: IVecPtr);

{ Append `x`, doubling the capacity when it is full. Silently does nothing once
  the vector is at IVecCapMax and full -- the alternative is halting, and a caller
  who cares can compare IVecLen before and after. }
procedure IVecPush(var v: IVecPtr; x: integer);

{ Remove and return the last element. The vector must not be empty; when it is,
  the result is 0 and the length stays 0. }
function IVecPop(var v: IVecPtr): integer;

{ Element `i`, for `i` in 1..IVecLen(v). Outside that range the array's own
  bounds check traps for `i` above the *capacity*, and for `i` between the
  length and the capacity the value is whatever the storage last held --
  unchecked, exactly as PasSort's `less` is unchecked, and for the same reason:
  the check would cost every access and the precondition is the caller's. }
function IVecGet(v: IVecPtr; i: integer): integer;

{ Store `x` at `i`, under the same precondition as IVecGet. }
procedure IVecSet(v: IVecPtr; i, x: integer);

{ The number of live elements. }
function IVecLen(v: IVecPtr): integer;

{ The number that fit before the next growth. }
function IVecCap(v: IVecPtr): integer;

{ Forget every element without releasing the storage. }
procedure IVecClear(var v: IVecPtr);

{ Grow so that at least `want` elements fit, if that is more than fits now.
  Never shrinks. A caller who knows the final size calls this once and no
  push after it reallocates. }
procedure IVecReserve(var v: IVecPtr; want: integer);

{ Set the length to `count` and every element to `x`. Grows if needed. }
procedure IVecFill(var v: IVecPtr; count, x: integer);

{ The sum of the elements. Traps on overflow, as any addition here does. }
function IVecSum(v: IVecPtr): integer;

end;

{ The one place storage is allocated, so the one place a capacity is clamped.
  Kept separate from IVecNew because IVecReserve needs it too and the clamp must
  be the same both times. }
procedure Claim(var v: IVecPtr; cap, keep: integer);
var q: IVecPtr; i: integer;
begin
  if cap < 1 then cap := 1;
  if cap > IVecCapMax then cap := IVecCapMax;
  new(q, cap);
  q^.n := keep;
  for i := 1 to keep do
    q^.a[i] := v^.a[i];
  dispose(v);
  v := q
end;

procedure IVecNew;
begin
  if cap < 1 then cap := 1;
  if cap > IVecCapMax then cap := IVecCapMax;
  new(v, cap);
  v^.n := 0
end;

procedure IVecFree;
begin
  if v <> nil then begin
    dispose(v);
    v := nil
  end
end;

procedure IVecPush;
var want: integer;
begin
  if v^.n = v^.cap then begin
    { doubling, written so that the product is never formed above the type }
    if v^.cap > IVecCapMax div 2 then want := IVecCapMax
    else want := v^.cap * 2;
    if want > v^.cap then
      Claim(v, want, v^.n)
  end;
  if v^.n < v^.cap then begin
    v^.n := v^.n + 1;
    v^.a[v^.n] := x
  end
end;

procedure IVecReserve;
begin
  if want > v^.cap then
    Claim(v, want, v^.n)
end;

function IVecPop;
begin
  if v^.n = 0 then
    IVecPop := 0
  else begin
    IVecPop := v^.a[v^.n];
    v^.n := v^.n - 1
  end
end;

function IVecGet;
begin
  IVecGet := v^.a[i]
end;

procedure IVecSet;
begin
  v^.a[i] := x
end;

function IVecLen;
begin
  IVecLen := v^.n
end;

function IVecCap;
begin
  IVecCap := v^.cap
end;

procedure IVecClear;
begin
  v^.n := 0
end;

procedure IVecFill;
var i: integer;
begin
  if count < 0 then count := 0;
  IVecReserve(v, count);
  if count > v^.cap then count := v^.cap;
  for i := 1 to count do
    v^.a[i] := x;
  v^.n := count
end;

function IVecSum;
var i, total: integer;
begin
  total := 0;
  for i := 1 to v^.n do
    total := total + v^.a[i];
  IVecSum := total
end;

end.
