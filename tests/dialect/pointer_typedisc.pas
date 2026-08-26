{ AP 6.4.4.1 (ADR-0213): a pointer domain may bind a schema's type
  discriminants and leave its ordinal ones to `new`.

  This is what a *growable* container written once needs. A schema with a type
  discriminant may not be a parameter-form and may not be a bare domain-type,
  so before this a generic routine could reach a container of fixed capacity
  and no other -- `new(p, larger)` was unwritable in a routine that does not
  know the element type. Here one Grow serves both. }
program pointer_typedisc(output);

type Point = record x, y: integer end;
     Vec(T: type; cap: integer) = record
       n: integer;
       a: array [1..cap] of T
     end;
     IVec = ^Vec(integer);
     PVec = ^Vec(Point);

{ One body, any element type: the *pointer* type is the type argument, and the
  capacity is the domain's open discriminant, read as `v^.cap`. }
procedure Grow(Ptr: type; var v: Ptr; want: integer);
var fresh: Ptr; i: integer;
begin
  new(fresh, want);
  fresh^.n := v^.n;
  for i := 1 to v^.n do fresh^.a[i] := v^.a[i];
  dispose(v);
  v := fresh
end;

procedure PushInt(var v: IVec; x: integer);
begin
  if v^.n = v^.cap then Grow(IVec, v, v^.cap * 2);
  v^.n := v^.n + 1;
  v^.a[v^.n] := x
end;

var a: IVec; b: PVec; i: integer; p: Point;
begin
  new(a, 2);
  a^.n := 0;
  { Six pushes into a capacity of two: it must grow twice. }
  for i := 1 to 6 do PushInt(a, i * 10);
  writeln('ints  n=', a^.n:1, ' cap=', a^.cap:1, ' last=', a^.a[6]:1);

  new(b, 1);
  b^.n := 1;
  p.x := 5; p.y := 6;
  b^.a[1] := p;
  Grow(PVec, b, 4);
  writeln('recs  n=', b^.n:1, ' cap=', b^.cap:1, ' x=', b^.a[1].x:1);

  { 6.4.4.2: the same named type on both sides is one type. }
  dispose(a);
  dispose(b)
end.
