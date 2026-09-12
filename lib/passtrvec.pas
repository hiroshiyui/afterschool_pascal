{ PasStrVec -- a growable sequence of strings.

  PasVector's design, with one line changed: the element is a `string(255)`.
  That file said a caller needing another element type copies it and changes
  one line, and this is that copy, made because a sequence of strings -- the
  lines of a file, the pieces of a split, the names in a directory -- is what
  a program wants most often after a sequence of integers, and a container's
  element type is part of its layout (ADR-0116): a schema is parameterised by
  a value, never by a type, so there is no way to write this once.

  What is different from PasVector beyond the element is what strings invite:
  `IndexOf` finds one, `Sort` orders them -- by `<`, which on strings is
  §6.7.2.5's, character by character with the shorter padded -- `Join` makes
  one string of them, and `Split` does the reverse, growing the vector as it
  goes where PasText's `Split` fills a fixed-size `Parts`. Everything that may
  grow takes `var v: StrVecPtr`, because growth replaces the variable. }

module PasStrVec;

{ **What a client is given is the type, and the type carries its routines**
  (AP 6.7.10.5, ADR-0411). Six names are exported where nineteen were: the
  thirteen operations of a vector are `impl StrVecPtr` in the block below,
  and an implementation is selected from the *type* of the receiver rather
  than from a name in scope (AP 6.7.10.2), so none of them is an exported
  name and none can collide with another module's.

  That is what retired the `SVec` prefix, and the prefix was never about
  reading well: it was there so that a program could import this module and
  `PasVector` at once, §6.11.2 putting every exported name into one scope and
  two `VecPush`es being one name with two meanings. A method is reached
  through a receiver and never through that scope, so the question does not
  arise -- which is the same argument `PasJson` and `PasToml` make one
  container over.

  What stays exported is what has no receiver to be selected from: the two
  bounds, the three types, and `SVecNew`, which *answers* a vector rather
  than acting on one and so keeps its name.

  Two of the thirteen are not spelled as PasVector spells them. `SVecGet` is
  `At` and `SVecSet` is `Put`, which is what `PasJson` and `PasToml` call
  reading and writing one element; `Set` could not have been kept in any
  case, §6.1.2 reserving it as a word-symbol. }

export PasStrVec = (ItemMax, StrItem, StrVec, StrVecPtr, SCapMax, SVecNew);

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

{ Merge sort over a[lo..hi] with `tmp` as the scratch half, insertion sort
  once a run is short. Recursion depth is log n; the scratch vector is
  allocated once by `Sort` and freed there. }
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

impl StrVecPtr;

  { Release the storage and set `v` to nil. A nil `v` is harmless. }
  procedure Free(var v: StrVecPtr);
  begin
    if v <> nil then begin
      dispose(v);
      v := nil
    end
  end;

  { Append `s`, doubling the capacity when it is full. Silently does nothing
    once the vector is at SCapMax and full. }
  procedure Push(var v: StrVecPtr; s: StrItem);
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

  { Remove and return the last string; the null-string when there is none. }
  function Pop(var v: StrVecPtr): StrItem;
  begin
    if v^.n = 0 then
      Pop := ''
    else begin
      Pop := v^.a[v^.n];
      v^.n := v^.n - 1
    end
  end;

  { String `i`, for `i` in 1..`v.Len`. Above the capacity the array's own
    check traps; between the length and the capacity the value is whatever the
    storage last held, unchecked, as PasVector's is. }
  function At(v: StrVecPtr; i: integer): StrItem;
  begin
    At := v^.a[i]
  end;

  { Store `s` at `i`, under the same precondition. }
  procedure Put(v: StrVecPtr; i: integer; s: StrItem);
  begin
    v^.a[i] := s
  end;

  { The number of live strings. }
  function Len(v: StrVecPtr): integer;
  begin
    Len := v^.n
  end;

  { The number that fit before the next growth. }
  function Cap(v: StrVecPtr): integer;
  begin
    Cap := v^.cap
  end;

  { Forget every string without releasing the storage. }
  procedure Clear(var v: StrVecPtr);
  begin
    v^.n := 0
  end;

  { Grow so that at least `want` fit. Never shrinks. }
  procedure Reserve(var v: StrVecPtr; want: integer);
  begin
    if want > v^.cap then
      Claim(v, want, v^.n)
  end;

  { The position of the first string equal to `s`, or 0. Equality is
    §6.7.2.5's: `'ab' = 'ab  '` is true, the shorter being padded. }
  function IndexOf(v: StrVecPtr; s: StrItem): integer;
  var i, at: integer;
  begin
    at := 0;
    i := 1;
    while (at = 0) and (i <= v^.n) do begin
      if v^.a[i] = s then at := i;
      i := i + 1
    end;
    IndexOf := at
  end;

  { Order the strings ascending by `<`. Stable: equal strings keep their
    order. Insertion sort below a small size and merge sort above it, so the
    worst case is n log n and no recursion deeper than log n is used. }
  procedure Sort(var v: StrVecPtr);
  var tmp: StrVecPtr;
  begin
    if v^.n > 1 then begin
      new(tmp, v^.n);
      SortRange(v, tmp, 1, v^.n);
      dispose(tmp)
    end
  end;

  { The strings in order with `sep` between each pair, into `dest`, which may
    be a string of any capacity; what does not fit is dropped, and the result
    says how long the whole would have been, so `v.Join(...) > dest.capacity`
    is how a caller learns that. }
  function Join(v: StrVecPtr; sep: StrItem; var dest: string): integer;
  var i, k, total: integer;

    { append `s` to dest as far as it fits, counting all of it }
    procedure PutPiece(s: StrItem);
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
      if i > 1 then PutPiece(sep);
      PutPiece(v^.a[i])
    end;
    k := total;
    Join := k
  end;

  { Append to `v` the pieces of `s` between occurrences of `sep`, PasText's
    rule: n separators give n + 1 pieces, adjacent separators give empty ones,
    and an empty `s` gives one empty piece. The vector is not cleared first, so
    splitting several lines into one vector is a loop of these. }
  procedure Split(var v: StrVecPtr; s: StrItem; sep: char);
  var i: integer; piece: StrItem;
  begin
    piece := '';
    for i := 1 to length(s) do
      if s[i] = sep then begin
        v.Push(piece);
        piece := ''
      end
      else
        piece := piece + s[i];
    v.Push(piece)
  end;

end;

procedure SVecNew;
begin
  if cap < 1 then cap := 1;
  if cap > SCapMax then cap := SCapMax;
  new(v, cap);
  v^.n := 0
end;

end.
