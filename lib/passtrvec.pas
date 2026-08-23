{ PasStrVec -- a growable sequence of strings.

  PasVector's design, with one line changed: the element is a `string(255)`.
  That file said a caller needing another element type copies it and changes
  one line, and this is that copy, made because a sequence of strings -- the
  lines of a file, the pieces of a split, the names in a directory -- is what
  a program wants most often after a sequence of integers, and a container's
  element type is part of its layout (ADR-0116): a schema is parameterised by
  a value, never by a type, so there is no way to write this once.

  The names are prefixed `SVec` rather than `Vec` so that a program may
  import both modules; §6.11 gives every exported name the importing block,
  and two `VecPush`es would be one name with two meanings.

  What is different from PasVector beyond the element is what strings invite:
  `SVecIndexOf` finds one, `SVecSort` orders them -- by `<`, which on
  strings is §6.7.2.5's, character by character with the shorter padded --
  `SVecJoin` makes one string of them, and `SVecSplit` does the reverse,
  growing the vector as it goes where PasText's `Split` fills a fixed-size
  `Parts`. Everything that may grow takes `var v: StrVecPtr`, because growth
  replaces the variable. }

module PasStrVec;

export PasStrVec = (ItemMax, StrItem, StrVec, StrVecPtr, SCapMax,
                    SVecNew, SVecFree, SVecPush, SVecPop, SVecGet, SVecSet,
                    SVecLen, SVecCap, SVecClear, SVecReserve,
                    SVecIndexOf, SVecSort, SVecJoin, SVecSplit);

const
  ItemMax = 255;
  { The largest capacity that may be asked for. An element is ItemMax + 4
    bytes, so this is about a quarter of a gigabyte; a caller wanting more
    lines than that wants a file, not this. }
  SCapMax = 1048576;

type
  StrItem = string(ItemMax);
  { `n` is the live length and `a` the storage; `cap` is the discriminant and
    readable as `v^.cap`. The array is last for ADR-0045's reason. }
  StrVec(cap: integer) = record
    n: integer;
    a: array [1..cap] of StrItem
  end;
  StrVecPtr = ^StrVec;

{ An empty vector with room for `cap` strings; `cap` outside 1..SCapMax is
  clamped rather than refused, PasVector's policy. }
procedure SVecNew(var v: StrVecPtr; cap: integer);

{ Release the storage and set `v` to nil. A nil `v` is harmless. }
procedure SVecFree(var v: StrVecPtr);

{ Append `s`, doubling the capacity when it is full. Silently does nothing
  once the vector is at SCapMax and full. }
procedure SVecPush(var v: StrVecPtr; s: StrItem);

{ Remove and return the last string; the null-string when there is none. }
function SVecPop(var v: StrVecPtr): StrItem;

{ String `i`, for `i` in 1..SVecLen(v). Above the capacity the array's own
  check traps; between the length and the capacity the value is whatever the
  storage last held, unchecked, as PasVector's is. }
function SVecGet(v: StrVecPtr; i: integer): StrItem;

{ Store `s` at `i`, under the same precondition. }
procedure SVecSet(v: StrVecPtr; i: integer; s: StrItem);

{ The number of live strings. }
function SVecLen(v: StrVecPtr): integer;

{ The number that fit before the next growth. }
function SVecCap(v: StrVecPtr): integer;

{ Forget every string without releasing the storage. }
procedure SVecClear(var v: StrVecPtr);

{ Grow so that at least `want` fit. Never shrinks. }
procedure SVecReserve(var v: StrVecPtr; want: integer);

{ The position of the first string equal to `s`, or 0. Equality is
  §6.7.2.5's: `'ab' = 'ab  '` is true, the shorter being padded. }
function SVecIndexOf(v: StrVecPtr; s: StrItem): integer;

{ Order the strings ascending by `<`. Stable: equal strings keep their
  order. Insertion sort below a small size and merge sort above it, so the
  worst case is n log n and no recursion deeper than log n is used. }
procedure SVecSort(var v: StrVecPtr);

{ The strings in order with `sep` between each pair, into `dest`, which may
  be a string of any capacity; what does not fit is dropped, and the result
  says how long the whole would have been, so `SVecJoin(...) > dest.capacity`
  is how a caller learns that. }
function SVecJoin(v: StrVecPtr; sep: StrItem; var dest: string): integer;

{ Append to `v` the pieces of `s` between occurrences of `sep`, PasText's
  rule: n separators give n + 1 pieces, adjacent separators give empty ones,
  and an empty `s` gives one empty piece. The vector is not cleared first, so
  splitting several lines into one vector is a loop of these. }
procedure SVecSplit(var v: StrVecPtr; s: StrItem; sep: char);

end;

{ The one place storage is allocated, so the one place a capacity is clamped. }
procedure Claim(var v: StrVecPtr; cap, keep: integer);
var q: StrVecPtr; i: integer;
begin
  if cap < 1 then cap := 1;
  if cap > SCapMax then cap := SCapMax;
  new(q, cap);
  q^.n := keep;
  for i := 1 to keep do
    q^.a[i] := v^.a[i];
  dispose(v);
  v := q
end;

procedure SVecNew;
begin
  if cap < 1 then cap := 1;
  if cap > SCapMax then cap := SCapMax;
  new(v, cap);
  v^.n := 0
end;

procedure SVecFree;
begin
  if v <> nil then begin
    dispose(v);
    v := nil
  end
end;

procedure SVecPush;
var want: integer;
begin
  if v^.n = v^.cap then begin
    if v^.cap > SCapMax div 2 then want := SCapMax
    else want := v^.cap * 2;
    if want > v^.cap then
      Claim(v, want, v^.n)
  end;
  if v^.n < v^.cap then begin
    v^.n := v^.n + 1;
    v^.a[v^.n] := s
  end
end;

function SVecPop;
begin
  if v^.n = 0 then
    SVecPop := ''
  else begin
    SVecPop := v^.a[v^.n];
    v^.n := v^.n - 1
  end
end;

function SVecGet;
begin
  SVecGet := v^.a[i]
end;

procedure SVecSet;
begin
  v^.a[i] := s
end;

function SVecLen;
begin
  SVecLen := v^.n
end;

function SVecCap;
begin
  SVecCap := v^.cap
end;

procedure SVecClear;
begin
  v^.n := 0
end;

procedure SVecReserve;
begin
  if want > v^.cap then
    Claim(v, want, v^.n)
end;

function SVecIndexOf;
var i, at: integer;
begin
  at := 0;
  i := 1;
  while (at = 0) and (i <= v^.n) do begin
    if v^.a[i] = s then at := i;
    i := i + 1
  end;
  SVecIndexOf := at
end;

{ Merge sort over a[lo..hi] with `tmp` as the scratch half, insertion sort
  once a run is short. Recursion depth is log n; the scratch vector is
  allocated once by SVecSort and freed there. }
procedure SortRange(v, tmp: StrVecPtr; lo, hi: integer);
var mid, i, j, k: integer; x: StrItem;
begin
  if hi - lo < 8 then begin
    for i := lo + 1 to hi do begin
      x := v^.a[i];
      j := i - 1;
      while (j >= lo) and (v^.a[j] > x) do begin
        v^.a[j + 1] := v^.a[j];
        j := j - 1
      end;
      v^.a[j + 1] := x
    end
  end
  else begin
    mid := lo + (hi - lo) div 2;
    SortRange(v, tmp, lo, mid);
    SortRange(v, tmp, mid + 1, hi);
    { merge, taking from the left on equality so that the sort is stable }
    i := lo;
    j := mid + 1;
    k := lo;
    while (i <= mid) and (j <= hi) do begin
      if v^.a[j] < v^.a[i] then begin
        tmp^.a[k] := v^.a[j];
        j := j + 1
      end
      else begin
        tmp^.a[k] := v^.a[i];
        i := i + 1
      end;
      k := k + 1
    end;
    while i <= mid do begin
      tmp^.a[k] := v^.a[i];
      i := i + 1;
      k := k + 1
    end;
    while j <= hi do begin
      tmp^.a[k] := v^.a[j];
      j := j + 1;
      k := k + 1
    end;
    for k := lo to hi do
      v^.a[k] := tmp^.a[k]
  end
end;

procedure SVecSort;
var tmp: StrVecPtr;
begin
  if v^.n > 1 then begin
    new(tmp, v^.n);
    SortRange(v, tmp, 1, v^.n);
    dispose(tmp)
  end
end;

function SVecJoin;
var i, k, total: integer;

  { append `s` to dest as far as it fits, counting all of it }
  procedure Put(s: StrItem);
  var c: integer;
  begin
    for c := 1 to length(s) do begin
      total := total + 1;
      if total <= dest.capacity then
        dest := dest + s[c]
    end
  end;

begin
  dest := '';
  total := 0;
  for i := 1 to v^.n do begin
    if i > 1 then Put(sep);
    Put(v^.a[i])
  end;
  k := total;
  SVecJoin := k
end;

procedure SVecSplit;
var i: integer; piece: StrItem;
begin
  piece := '';
  for i := 1 to length(s) do
    if s[i] = sep then begin
      SVecPush(v, piece);
      piece := ''
    end
    else
      piece := piece + s[i];
  SVecPush(v, piece)
end;

end.
