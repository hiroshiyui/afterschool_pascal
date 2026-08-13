{ What a `with` over a type produced from a schema refuses.

  §6.9.3.10 makes the with-element's field-identifiers *and* — where the type
  was produced from a schema — that schema's formal discriminants into
  defining-points for one region, the statement of the with-statement. §6.2.2.7
  allows a region only one defining-point per spelling, so a record whose field
  is named like a discriminant cannot be the element of a `with`.

  Outside a `with` the same record is legal: the field's defining-point is for
  the record-type and the discriminant's for the enclosing type-denoter, and
  §6.2.2.5 makes the inner one shadow the outer. So this is the with-statement's
  error and not the schema definition's, which is why the message names the
  statement's problem rather than the type's (ADR-0071).

  A discriminant introduced this way denotes a *value* — §6.9.3.10 says it
  "shall denote the value corresponding to the discriminant-identifier
  according to the tuple" — so it is not assignable, in any of the three shapes
  a produced type has. }
program withschema_errors(output);

type
  clash(n: integer) = record
                        n: integer;
                        a: array [1..n] of integer
                      end;
  { A field of a variant arm is a field-identifier like any other, so it
    collides in exactly the same way. The search is the one a field selection
    already makes, which walks every arm because §6.4.3.3 requires every field
    name in a record to be distinct, variants included. }
  armclash(k: integer) = record
                           case sel: boolean of
                             true: (k: integer);
                             false: (b: char)
                         end;
  pc = ^clash;
  vector(n: integer) = array [1..n] of integer;

var
  c: clash(3);
  ac: armclash(2);
  p: pc;
  v: vector(3);
  i: integer;

procedure generic(var g: vector);
begin
  { A schematic formal's discriminant is read from the descriptor the actual
    brought, and is no more assignable for arriving at run time. }
  with g do
    n := 1
end;

begin
  with c do
    writeln(n:1);
  with ac do
    writeln(k:1);
  new(p, 4);
  with p^ do
    writeln(n:1);
  dispose(p);

  { The three shapes, each refused the same way: a constant tuple, a heap
    variable, and — in `generic` above — a schematic formal. }
  with v do
    n := 9;

  { §6.9.3.10 admits a record-type or a type produced from a schema, and
    nothing else. }
  with i do
    writeln(i:1);

  generic(v)
end.
