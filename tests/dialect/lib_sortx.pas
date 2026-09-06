{ PasSortX: a sort over the element type itself, which is the client
  `doc/sop.md` 4a asks for -- traits landed with cases that declare and
  select an implementation, and this is the first program that uses one to
  get work done (ADR-0338 to ADR-0341, ADR-0344).

  The point of the case is that the trait is declared in the *module* and
  every implementation is written *here*. 6.13 has a client translate against
  the interface alone, so the module's body cannot hold one; it reaches these
  because AP 6.7.3.5 re-reads a generic's body in the translation that
  activates it, which is this one.

  Every position a program can put the construct in is exercised: a record, a
  string-type, `integer`, a subrange served by its host's implementation, a
  slice of an array, an array of one element and an array of none, and
  `SortWith` over a type that implements nothing at all. }
program lib_sortx(output);

import PasSortX;

type
  Point = record x, y: integer end;
  Name = string(8);
  digit = 1..9;
  { Nothing implements `Sortable` for this one, which is what `SortWith` is
    for. }
  Pair = record lo, hi: integer end;

{ ------------------------------------------- the client's implementations - }

impl Sortable for Point;
  function Before;
  begin Before := p.x < q.x end;
end;

impl Sortable for integer;
  function Before;
  begin Before := p < q end;
end;

impl Sortable for Name;
  function Before;
  begin Before := p < q end;
end;

{ An order that is not the type's, for `SortWith`. }
function After(x, y: integer): boolean;
begin
  After := y < x
end;

function ByHigh(x, y: Pair): boolean;
begin
  ByHigh := x.hi < y.hi
end;

var
  ps: array [1..4] of Point;
  xs: array [1..7] of integer;
  ns: array [1..3] of Name;
  ds: array [1..5] of digit;
  qs: array [1..3] of Pair;
  one: array [1..1] of integer;
  k: integer;

begin
  { A record, by the field its implementation compares. }
  ps[1].x := 7; ps[2].x := 4; ps[3].x := 6; ps[4].x := 1;
  Sort(ps);
  for k := 1 to 4 do write(ps[k].x:1, ' ');
  writeln;

  { `integer`, and the same array again in the caller's own order. }
  xs[1] := 5; xs[2] := 2; xs[3] := 9; xs[4] := 1;
  xs[5] := 3; xs[6] := 9; xs[7] := 4;
  writeln('sorted before: ', IsSorted(xs));
  Sort(xs);
  for k := 1 to 7 do write(xs[k]:1, ' ');
  writeln;
  writeln('sorted after: ', IsSorted(xs));

  { Where a value belongs, and what that says about whether it is there. }
  writeln(LowerBoundOf(xs, 1):1, ' ', LowerBoundOf(xs, 4):1, ' ',
          LowerBoundOf(xs, 6):1, ' ', LowerBoundOf(xs, 9):1, ' ',
          LowerBoundOf(xs, 10):1);

  SortWith(xs, After);
  for k := 1 to 7 do write(xs[k]:1, ' ');
  writeln;

  { A string-type. }
  ns[1] := 'pear'; ns[2] := 'apple'; ns[3] := 'fig';
  Sort(ns);
  for k := 1 to 3 do write(ns[k], ' ');
  writeln;

  { A subrange, served by its host's implementation and carrying none of its
    own (ADR-0018, ADR-0340). }
  ds[1] := 4; ds[2] := 9; ds[3] := 1; ds[4] := 7; ds[5] := 2;
  Sort(ds);
  for k := 1 to 5 do write(ds[k]:1, ' ');
  writeln;

  { A type that implements nothing: the order is the whole of what is needed. }
  qs[1].lo := 0; qs[1].hi := 8;
  qs[2].lo := 0; qs[2].hi := 3;
  qs[3].lo := 0; qs[3].hi := 5;
  SortWith(qs, ByHigh);
  for k := 1 to 3 do write(qs[k].hi:1, ' ');
  writeln;

  { A slice of an array: the middle three sorted and the ends left alone. }
  xs[1] := 5; xs[2] := 2; xs[3] := 9; xs[4] := 1;
  xs[5] := 3; xs[6] := 9; xs[7] := 4;
  Sort(xs[3..5]);
  for k := 1 to 7 do write(xs[k]:1, ' ');
  writeln;

  { One element and none: a heap of one is a heap, and a heap of none has no
    loop to enter. The empty one is a slice, an empty index-type being refused
    at the declaration (6.4.2.4). }
  one[1] := 42;
  Sort(one);
  writeln(one[1]:1, ' ', IsSorted(one));
  Sort(xs[3..2]);
  writeln(IsSorted(xs[3..2]), ' ', LowerBoundOf(xs[3..2], 3):1)
end.
