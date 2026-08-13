{ A `with` over a heap variable produced from a schema.

  §6.9.3.10's with-element may possess "a type produced from a schema", and
  each of the schema's formal discriminants is then a
  schema-discriminant-identifier for the region that is the statement. Where
  the variable is on the heap its tuple is a header in front of it (ADR-0043),
  and `v.d` finds that header by walking *down* the designator to the whole
  variable — which a bare `d` cannot do, there being no designator to walk. So
  the binding carries the tuple as well as the address: it becomes the
  descriptor ADR-0040 gives a schematic formal.

  The second half of this program is a bug that predates the `with` feature and
  that nothing had ever reached: a designator rooted at a `with` binding, whose
  bounds are the heap variable's. The walk to the whole variable stopped at the
  binding — there is no node standing for the record — so the header came back
  null and the compiler segfaulted building the bounds check. `with g^ do
  cells[r, c] := ...` is that program, and it was accepted and crashed before
  the discriminants were ever introduced (ADR-0071). }
program withheap(output);

type
  vec(n: integer) = array [1..n] of integer;
  pv = ^vec;
  grid(r, c: integer) = record
                          tag: integer;
                          cells: array [1..r, 1..c] of integer
                        end;
  pg = ^grid;

var
  p: pv;
  g: pg;
  i, j: integer;
  calls: integer;

{ §6.9.3.10: "the variable-access shall be accessed ... before the statement of
  the with-statement is executed", once — so the address the binding holds and
  the header the discriminants are read from must come from *one* evaluation.
  A function-access is the only with-element that can tell: `fetch^` is a
  variable (§6.5.1 makes what a pointer identifies one however the pointer was
  obtained), so it may head a `with`, and the counter says how often it ran. }
function fetch: pv;
begin
  calls := calls + 1;
  fetch := p
end;

{ The tuple is per *activation*, so a recursive procedure must see the header
  of the variable the invocation it is running in created — the same property
  `tests/nesting.pas` pins for an ordinary local. }
procedure descend(k: integer);
var q: pv;
begin
  new(q, k);
  q^[k] := k * 10;
  with q^ do
    begin
      write('depth   ', n:1, ':', q^[n]:1);
      if k > 1 then
        begin
          writeln;
          descend(k - 1)
        end
      else
        writeln
    end;
  { The header is read again after the recursion has returned and disposed of
    every deeper one, which is what says the descriptor was not shared. }
  with q^ do
    writeln('back    ', n:1);
  dispose(q)
end;

begin
  { An array on the heap: one discriminant, and the only thing the region
    introduces. }
  new(p, 4);
  for i := 1 to 4 do
    p^[i] := i * i;
  with p^ do
    writeln('array   ', n:1, ' ', p^[n]:1);
  calls := 0;
  with fetch^ do
    writeln('once    ', n:1, ' ', calls:1);
  dispose(p);

  { A record on the heap: two discriminants beside the fields, and a field
    whose own bounds are those discriminants. Every subscript below is checked
    against bounds read out of the header through the binding. }
  new(g, 2, 3);
  with g^ do
    begin
      tag := 5;
      for i := 1 to r do
        for j := 1 to c do
          cells[i, j] := i * 10 + j;
      writeln('record  ', tag:1, ' ', r:1, ' ', c:1);
      writeln('corner  ', cells[r, c]:1)
    end;
  writeln('outside ', g^.cells[2, 3]:1, ' ', g^.r:1);
  dispose(g);

  descend(3)
end.
