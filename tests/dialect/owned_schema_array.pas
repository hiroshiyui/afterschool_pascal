{ A schema whose dynamically-bounded array holds an owned pointer, on the heap.

  AP 6.4.14's release walks a variable and releases everything owned inside it,
  and the walk over an array emits a loop because the length may be a
  discriminant's (ADR-0040). It asked `DynLength` for that length with an
  **empty** header, which is right for every declared variable -- `var q: A(3)`
  produces a type whose bounds are constants, so nothing is read from a tuple
  -- and wrong for a heap one, whose tuple is in front of the block. The
  compiler emitted

      %v24 = getelementptr i32, ptr , i32 0

  with no operand at all, which clang refuses; so this program did not build,
  and the only shape that reaches it is a container of owned pointers
  (ADR-0329).

  What it pins is that one `dispose` releases the container **and every owned
  element in it**: the balance below is 7 and 7. `new` is `calloc`, so the
  slots this program never assigns are nil and the walk steps over them --
  which is what `uninit` shows, and is why the loop may run over a capacity
  rather than over a length. }
program owned_schema_array(output);

type
  Node = record v: integer end;
  Own  = owned ^Node;
  Vec(cap: integer) = record n: integer; a: array [1..cap] of Own end;
  VecPtr = ^Vec;

var q: VecPtr; i, sum: integer;

begin
  { six of the eight slots used, so the walk meets both a live pointer and an
    empty one }
  new(q, 8);
  q^.n := 6;
  for i := 1 to q^.n do begin
    new(q^.a[i]);
    q^.a[i]^.v := i * i
  end;
  sum := 0;
  for i := 1 to q^.n do sum := sum + q^.a[i]^.v;
  writeln('sum ', sum:1);
  writeln('cap ', q^.cap:1);

  { one dispose, seven blocks given back }
  dispose(q);
  writeln('disposed')
end.
