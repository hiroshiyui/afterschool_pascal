{ AP 6.4.14.2 as amended (ADR-0320): an owned pointer's domain may be a schema
  when the type it produces holds nothing that must itself be released.

  The clause refused every schema domain and gave its reason -- releasing the
  variable means walking its type, and a schema-produced type's lengths are
  discriminants read from a descriptor a *frame* holds, which a heap variable
  has not got. The reason is about the **walk**, and a walk happens only where
  the variable holds a file, a handle or another owned pointer. Where it holds
  none, the release is the free that `dispose` already performs.

  This is the shape every growable container in `lib/` has -- a pointer to a
  schema whose discriminant is the capacity -- so it is the difference between
  `owned ^T` having one client and being usable by the library. }
program owned_schema(output);

type
  { The `IntVec` of lib/pasvector.pas, in miniature: one discriminant, one
    array sized by it, and nothing affine anywhere in it. }
  Vec(cap: integer) = record
    n: integer;
    a: array [1..cap] of integer
  end;
  OV  = owned ^Vec;
  Box = record v: OV end;
  Pair = record left, right: OV end;

  { The same thing with the schema named *later*. A domain whose name is not
    yet defined pends, and the condition has to be asked a second time where
    the pending list is drained -- two paths, and tests/dialect/owned_errors.pas
    is where each refuses. }
  LateOV  = owned ^LateVec;
  LateVec(cap: integer) = record m: integer; b: array [1..cap] of integer end;

  { And the domain may bind *type* discriminants, which AP 6.4.14.1's grammar
    said it could not until ADR-0320 and the processor had accepted all along:
    6.4.4.1 defines the domain-type for every pointer-type, and only the
    ordinal discriminants are left for `new` to choose. This is the shape
    PasContainer's `Vec(T, cap)` has, and so the one a growable *generic*
    container would be owned as. }
  Gen(T: type; cap: integer) = record n: integer; g: array [1..cap] of T end;
  OwnedInts = owned ^Gen(integer);

  { A domain that is not a record at all. Nothing in it can own anything, so
    its release is the deallocation and there is no field to continue at
    (ADR-0322). }
  Row  = array [1..4] of integer;
  ORow = owned ^Row;

  { And a record owning something of a *different* domain, which is what parts
    a chain from a containment: releasing an Outer walks into its `held` and
    recurses, because continuing there would be continuing at another type's
    release. }
  Inner  = owned ^InnerRec;
  InnerRec = record z: integer end;
  Outer  = owned ^OuterRec;
  OuterRec = record held: Inner; y: integer end;

{ A borrow of one, which is what an accessor takes now (ADR-0318): the caller
  keeps ownership and the routine cannot release it. }
function Total(protected var v: OV): integer;
var i, t: integer;
begin
  t := 0;
  for i := 1 to v^.n do t := t + v^.a[i];
  Total := t
end;

procedure Fill(protected var v: OV; from: integer);
var i: integer;
begin
  v^.n := v^.cap;
  for i := 1 to v^.cap do v^.a[i] := from + i
end;

{ Growth replaces the variable, which is the reason lib/'s vectors take `var`:
  a bigger tuple is a different variable, and the old one is released by the
  assignment (AP 6.4.14.3). }
procedure Grow(var v: OV; cap: integer);
var bigger: OV; i: integer;
begin
  new(bigger, cap);
  bigger^.n := v^.n;
  for i := 1 to v^.n do bigger^.a[i] := v^.a[i];
  v := take(bigger)
end;

procedure Run;
var v, w: OV; b: Box; p: Pair; late: LateOV; gi: OwnedInts;
    row: ORow; out_: Outer; i, t: integer;
begin
  new(v, 4);
  Fill(v, 10);
  writeln('cap    ', v^.cap:1);
  writeln('total  ', Total(v):1);

  { growth: the assignment releases the smaller variable }
  Grow(v, 8);
  writeln('grown  ', v^.cap:1, ' total ', Total(v):1);

  { a move empties the source }
  w := take(v);
  writeln('moved  ', v = nil, ' ', w^.cap:1);

  { a field of a record owns one, and the record's death releases it }
  new(b.v, 2);
  b.v^.n := 2; b.v^.a[1] := 3; b.v^.a[2] := 4;
  writeln('field  ', Total(b.v):1);

  { two of them in one record, released in the order the block leaves }
  new(p.left, 1); new(p.right, 1);
  p.left^.n := 1; p.left^.a[1] := 6;
  p.right^.n := 1; p.right^.a[1] := 9;
  writeln('pair   ', Total(p.left) + Total(p.right):1);

  { the domain resolved through the pending list }
  new(late, 3);
  late^.m := 3; late^.b[1] := 11;
  writeln('late   ', late^.cap:1, ' ', late^.b[1]:1);

  { a domain binding a type discriminant }
  new(gi, 3);
  gi^.n := 3; gi^.g[3] := 30;
  writeln('gen    ', gi^.cap:1, ' ', gi^.g[3]:1);

  { a domain that is not a record }
  new(row);
  row^[1] := 4; row^[4] := 9;
  writeln('row    ', row^[1] + row^[4]:1);

  { and a record owning a different domain, which recurses rather than loops }
  new(out_); new(out_^.held);
  out_^.y := 2; out_^.held^.z := 5;
  writeln('outer  ', out_^.y + out_^.held^.z:1);

  { A `with` on a record that owns nothing is not a borrow, so a call in its
    body has nothing to be refused against (AP 6.4.14.9): the open-with list
    carries a nil entry for such a statement and the question is asked of it. }
  with p do
    writeln('within ', Total(left):1);

  { comparison with nil is the only one 6.4.14.4 admits }
  writeln('nil    ', w = nil, ' ', w <> nil);

  { an explicit release, and everything else goes with the block }
  t := 0;
  for i := 1 to w^.n do t := t + 1;
  dispose(w);
  writeln('walked ', t:1, ', w empty: ', w = nil)
end;

begin
  Run
end.
