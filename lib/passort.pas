{ PasSort -- sorting and searching, without generics.

  Neither standard has a sort, and neither has a way to write one over an
  arbitrary element type: schemata parameterise a type by a *value* and not by
  another type (ADR-0039), so `list of T` cannot be said. What both do have is
  procedural and functional parameters, whose value is a code-and-link pair
  (ADR-0030) -- and that is enough, because a sort does not need to know what it
  is sorting. It needs to compare two positions and exchange them.

  **The dialect can now say it, and this module still cannot.** AP 6.7.3.10's
  type parameter and AP 6.7.9's trait make `Sort(a)` over the elements
  themselves writable, and `PasSortX` is that module. This one stays Extended
  Pascal, which is what makes it portable to any processor of that standard,
  and `SortIndexed` goes on answering a question the generic one does not: a
  caller sorting several parallel arrays at once, or a file read into a
  buffer, has no single element to compare and needs the positions.

  So `SortIndexed` takes the *operations* rather than the data: `less(i, j)` and
  `swap(i, j)` over 1..n. The caller's two nested routines close over whatever
  the elements actually live in -- an array, several parallel arrays, a file
  read into a buffer -- and the sort never sees an element at all. That is the
  answer to "no generics" here, and it costs nothing this compiler does not
  already do.

  `SortInts` is the common case written out on top of it, so the ordinary caller
  does not build two closures to sort an array of integers.

  The algorithm is heapsort: O(n log n) with no auxiliary storage, no recursion
  and therefore no stack bound to argue about, and it needs no temporary of the
  element type -- which an interface offering only `swap` could not provide. }

module PasSort;

export PasSort = (IntVector, SortInts, SortIndexed, LowerBound);

{ A schematic formal takes its bounds from the actual (ADR-0040), so one
  compiled body serves every extent and `a.n` reads the discriminant. }
type IntVector(n: integer) = array [1..n] of integer;

{ Sort 1..n by exchanging, comparing through the caller's two routines. `less`
  must be a strict weak order over the positions -- irreflexive, and consistent
  for the duration of the call -- and `swap` must exchange whatever `less`
  compares. Neither is checked, and neither can be. }
procedure SortIndexed(n: integer;
                      function less(i, j: integer): boolean;
                      procedure swap(i, j: integer));

{ `a` sorted so that `less` holds between neighbours, where `less` compares two
  element *values* rather than two positions. }
procedure SortInts(var a: IntVector; function less(x, y: integer): boolean);

{ The first position in 1..n at which `atLeast` holds, or n + 1 when it holds
  nowhere -- C++'s lower_bound, and the shape every "where does this belong"
  question takes. `atLeast` must be false for a prefix of 1..n and true for the
  rest; a predicate that alternates gives an unspecified answer rather than a
  wrong one, there being no order for it to be wrong about.

  `n` must be below maxint, because "nowhere" is n + 1 and forming it is a trap
  at the top of the type (ADR-0014). No array can have maxint components, so
  this bites only a caller searching something other than one. }
function LowerBound(n: integer; function atLeast(i: integer): boolean): integer;

end;

procedure SortIndexed;
var start, last: integer;

  { Restore the heap property at `root`, over the heap occupying 1..limit.
    Iterative, so the depth of the heap is not a depth of the stack. }
  procedure SiftDown(root, limit: integer);
  var child: integer; going: boolean;
  begin
    going := true;
    { `root <= limit div 2` rather than `root * 2 <= limit`: this compiler traps
      on integer overflow (ADR-0014) and carries no `nsw`, so the product must
      not be formed before it is known to fit. }
    while going and then (root <= limit div 2) do begin
      child := root * 2;
      { The larger of the two children, so what rises is the larger. }
      if (child + 1 <= limit) and then less(child, child + 1) then
        child := child + 1;
      if less(root, child) then begin
        swap(root, child);
        root := child
      end
      else
        going := false
    end
  end;

begin
  { Build the heap bottom-up: every position past n div 2 is a leaf and already
    a heap of one. }
  for start := n div 2 downto 1 do
    SiftDown(start, n);
  { Then repeatedly move the largest to the end and shrink the heap. }
  for last := n downto 2 do begin
    swap(1, last);
    SiftDown(1, last - 1)
  end
end;

procedure SortInts;

  { The adapters that turn two positions into two values, closing over `a` and
    over the caller's `less` -- which is the whole reason SortIndexed can be
    written without knowing the element type. }
  function LessAt(i, j: integer): boolean;
  begin
    LessAt := less(a[i], a[j])
  end;

  procedure SwapAt(i, j: integer);
  var t: integer;
  begin
    t := a[i];
    a[i] := a[j];
    a[j] := t
  end;

begin
  SortIndexed(a.n, LessAt, SwapAt)
end;

function LowerBound;
var lo, hi, mid: integer;
begin
  { Binary search over the half-open range lo..hi, where the answer is always
    in it: lo = 1 and hi = n + 1 to begin with, and the invariant is that
    atLeast is false below lo and true at hi or beyond. }
  lo := 1;
  hi := n + 1;
  while lo < hi do begin
    { `lo + (hi - lo) div 2` rather than `(lo + hi) div 2`: the sum can leave
      the type where the difference cannot, and this compiler traps rather than
      wrapping. }
    mid := lo + (hi - lo) div 2;
    if atLeast(mid) then hi := mid else lo := mid + 1
  end;
  LowerBound := lo
end;

end.
