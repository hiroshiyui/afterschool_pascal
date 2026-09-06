{ PasSortX -- sorting and searching over the element type itself (ADR-0344).

  `PasSort` is this module's ancestor and its header says the thing that has
  stopped being true: that this compiler "has no way to write one over an
  arbitrary element type". It had none when it was written. A schema
  parameterises a type by a *value* (ADR-0039), so `list of T` could not be
  said, and `SortIndexed` answers by taking the caller's `less(i, j)` and
  `swap(i, j)` and never seeing an element at all.

  Two features since have made the other answer writable. AP 6.7.3.10's type
  parameter lets a routine be generic over a type; AP 6.7.9's trait lets it
  say what it needs of that type. So the sort below takes the elements:

      impl Sortable for Point;              -- the client writes this once
        function Before;
        begin Before := p.x < q.x end;
      end;

      var ps: array [1..3] of Point;
      begin
        Sort(ps)                            -- and this is the whole call
      end

  **The trait is declared here and implemented by the client**, which is the
  only direction that works and is not a limitation (ADR-0341). 6.13 has a
  client translate against the interface alone, so an implementation written
  in this module's block would be invisible to every importer. What crosses is
  the trait; the routines below reach the client's implementation because
  AP 6.7.3.5 re-reads a generic's body in the translation that activates it,
  which is the client's.

  **`PasSort` stays and is not deprecated.** It is ordinary Extended Pascal
  and portable to any processor of that standard, where this module is
  dialect-only; and `SortIndexed` still answers a question this one does not,
  the caller sorting several parallel arrays at once, or a file read into a
  buffer, where there is no single element to compare. What has moved is the
  common case: sorting an array of something.

  **Why `SortWith` as well as `Sort`.** A type has at most one implementation
  of a trait in a program-component (AP 6.7.10), so the trait fixes *the*
  order of a type and a caller wanting another -- descending, or by a second
  field -- has nowhere to put it. `SortWith` takes the order as a procedural
  parameter and requires no implementation at all, which is `PasSort`'s
  bargain kept for the case that needs it.

  The algorithm is heapsort, for `PasSort`'s reasons: O(n log n), no auxiliary
  storage, and iterative, so the depth of the heap is not a depth of the
  stack. One thing is easier here than there. `SortIndexed` could not hold a
  temporary of the element type, an interface offering only `swap` having no
  way to make one, and this one can -- `var t: T` -- so the exchange is
  written out rather than delegated. }
module PasSortX;

export PasSortX = (Sortable, Sort, SortWith, IsSorted, LowerBoundOf);

{ What a sort needs of an element, and no more: a strict weak order.

  `Before` must be irreflexive -- `Before(x, x)` false -- transitive, and
  consistent for the duration of the call, and incomparability must be
  transitive as well, which is what "weak" adds and what lets equal elements
  exist. None of that is checked and none of it can be, exactly as
  `PasSort.SortIndexed` says of its `less`. A predicate that is not an order
  gives a permutation of the elements rather than a wrong answer.

  The receiver is a *value* parameter, which is a decision and not an
  oversight: impl selection follows `Base()` (ADR-0018, ADR-0340), so an
  implementation for `integer` serves every subrange of it -- and 6.6.3.3
  would refuse a `1..9` actual for a `var` parameter of type `integer`. A
  trait meant to serve subranges takes its receiver by value. }
trait Sortable;
  function Before(p: Self; q: Self): boolean;
end;

{ `a` sorted ascending by the element type's own implementation of `Sortable`.
  The type argument is inferred from `a` (AP 6.7.3.10.4), so no call here
  names a type. }
procedure Sort(T: Sortable type; var a: array of T);

{ `a` sorted so that `before` holds between neighbours, for a caller whose
  order is not the type's -- or whose element type implements nothing. }
procedure SortWith(T: type; var a: array of T;
                   function before(x, y: T): boolean);

{ Whether `a` is already in the order `Sortable` gives it. Cheap enough to
  call before sorting, and the postcondition of having done so. }
function IsSorted(T: Sortable type; protected var a: array of T): boolean;

{ The first position in 1..length(a) at which `x` could be inserted with the
  order preserved, or length(a) + 1 when `x` follows everything --
  C++'s lower_bound over the values rather than over `PasSort.LowerBound`'s
  positions. `a` must already be sorted; it is not checked.

  The answer is a position and not a found/not-found pair: `x` is present when
  the answer is within the array and `Before(a[answer], x)` is false and
  `Before(x, a[answer])` is false, which is what a strict weak order can say
  about equality and is all it can say. }
function LowerBoundOf(T: Sortable type; protected var a: array of T;
                      x: T): integer;

end;

procedure Sort;

  { The adapter that turns the trait into the procedural parameter
    `SortWith` takes -- `PasSort.SortInts`' shape, one level of abstraction
    up: there it closed over an array to turn positions into values, and here
    it closes over nothing and turns a trait-keyed selection into a value.
    The selection happens where this body is read, which is the client's
    translation, so `Before` is the client's. }
  function byTrait(x, y: T): boolean;
  begin
    byTrait := Before(x, y)
  end;

begin
  SortWith(a, byTrait)
end;

procedure SortWith;
{ `top` and `u` rather than `t` for the two element temporaries: 6.1.2 folds
  case, so a local named `t` *is* the type parameter `T` and the denoter after
  it resolves to a variable. The compiler says `unknown type 't'`, which is
  true and is not the first thing a reader thinks of -- it is ADR-0340's
  `self`/`Self` collision met a second time, one scope further in. }
var last: integer; top: T;

  { Restore the heap property at `root`, over the heap occupying 1..limit.
    Iterative, so the depth of the heap is not a depth of the stack. }
  procedure SiftDown(root, limit: integer);
  var child: integer; going: boolean; u: T;
  begin
    going := true;
    { `root <= limit div 2` rather than `root * 2 <= limit`: this compiler
      traps on integer overflow (ADR-0014) and carries no `nsw`, so the
      product must not be formed before it is known to fit. }
    while going and then (root <= limit div 2) do begin
      child := root * 2;
      { The larger of the two children, so what rises is the larger. }
      if (child + 1 <= limit) and then before(a[child], a[child + 1]) then
        child := child + 1;
      if before(a[root], a[child]) then begin
        u := a[root];
        a[root] := a[child];
        a[child] := u;
        root := child
      end
      else
        going := false
    end
  end;

begin
  { Build the heap bottom-up: every position past length(a) div 2 is a leaf
    and already a heap of one. }
  for last := length(a) div 2 downto 1 do
    SiftDown(last, length(a));
  { Then repeatedly move the largest to the end and shrink the heap. }
  for last := length(a) downto 2 do begin
    top := a[1];
    a[1] := a[last];
    a[last] := top;
    SiftDown(1, last - 1)
  end
end;

function IsSorted;
var k: integer; ok: boolean;
begin
  ok := true;
  k := 2;
  { `and then` rather than `and`: a[k] must not be read at length(a) + 1. }
  while ok and then (k <= length(a)) do begin
    if Before(a[k], a[k - 1]) then ok := false else k := k + 1
  end;
  IsSorted := ok
end;

function LowerBoundOf;
var lo, hi, mid: integer;
begin
  { Binary search over the half-open range lo..hi, where the answer is always
    in it: the invariant is that everything below lo is before `x` and nothing
    at hi or beyond is. }
  lo := 1;
  hi := length(a) + 1;
  while lo < hi do begin
    { `lo + (hi - lo) div 2` rather than `(lo + hi) div 2`: the sum can leave
      the type where the difference cannot, and this compiler traps rather
      than wrapping. }
    mid := lo + (hi - lo) div 2;
    if Before(a[mid], x) then lo := mid + 1 else hi := mid
  end;
  LowerBoundOf := lo
end;

end.
