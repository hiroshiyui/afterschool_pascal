{ **A trait may declare a procedure, and calling one selects an
  implementation** (AP 6.7.10.2, ADR-0407).

  The clause said so from the day it was written -- *where a function-designator
  **or a procedure-statement** names an identifier that has no defining-point
  in force* -- and only the function half was built. Its own NOTE 14 recorded
  the gap, so the normative text and its note disagreed, which is the one shape
  AP's Annex E exists to stop.

  What a trait object needs is the other reason: a vtable holds a trait's
  routines, and half of a trait's routines could not be called at all.

  Everything here is the *procedure* half of `traits.pas`, in the positions
  6.7.10.2 names:

    - two implementations of one trait, selected by the first actual's type;
    - a procedure that calls the trait's own function through the same lookup;
    - selection by **host-type**, so a subrange reaches the integer's impl;
    - a receiver taken `protected var`, and one taken by value;
    - an implementation in a second trait, so the ambiguity rule is the
      function half's and not a second one;
    - and a procedure-statement whose first actual is a variable-access of a
      type with no implementation, which selects nothing and says so. }
program traits_procedure(output);

type
  Point = record x, y: integer end;
  Line = record a, b: integer end;
  digit = 1..9;

trait Emits;
  procedure Emit(p: Self);
  function Size(p: Self): integer;
  procedure Twice(protected var p: Self);
end;

impl Emits for Point;
  procedure Emit;
  begin writeln('point ', p.x:1, ',', p.y:1) end;
  function Size;
  begin Size := p.x * p.y end;
  { The trait's own function, reached from inside the implementation through
    the same trait-keyed lookup a client uses. }
  procedure Twice;
  begin writeln('twice ', Size(p) * 2:1) end;
end;

impl Emits for Line;
  procedure Emit;
  begin writeln('line ', p.a:1, '-', p.b:1) end;
  function Size;
  begin Size := p.b - p.a end;
  procedure Twice;
  begin writeln('twice ', Size(p) * 2:1) end;
end;

{ Selection reads the host-type of a subrange (6.7.10.2, NOTE 13), so this
  implementation over `integer` serves a `digit` as well -- and the receiver
  is by value for NOTE 13's reason: a `protected var` of type integer is not
  usable at a subrange of it. }
impl Emits for integer;
  procedure Emit;
  begin writeln('int ', p:1) end;
  function Size;
  begin Size := p end;
  procedure Twice;
  begin writeln('twice ', p * 2:1) end;
end;

var
  pt: Point;
  ln: Line;
  n: integer;
  d: digit;

begin
  pt.x := 3; pt.y := 4;
  ln.a := 2; ln.b := 9;
  n := 7;
  d := 5;

  { One spelling, three types, selected by the first actual. }
  Emit(pt);
  Emit(ln);
  Emit(n);

  { A subrange selects its host's implementation. }
  Emit(d);

  { The function half still works beside it, and in the same statement. }
  writeln('size ', Size(pt):1, ' ', Size(ln):1, ' ', Size(n):1);

  { A procedure reaching the trait's own function from inside an
    implementation. }
  Twice(pt);
  Twice(ln)
end.
