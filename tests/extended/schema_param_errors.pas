{ What a schematic formal parameter refuses. Sema accumulates, so one run
  reports all of these. }
program SchemaParamErrors(output);
type
  vector(n: integer) = array [1..n] of real;
  other(n: integer) = array [1..n] of real;
  { a discriminant may bound an array of the schema's type and nothing else:
    a field after a dynamically-bounded one would sit at an offset nothing
    can compute, and a set and a file are sized once }
  boxed(n: integer) = record a: array [1..n] of char end;
  sized(n: integer) = 1..n;
  { §6.4.7 lets a schema name itself only in the domain of a pointer, and a
    parameter form is not one }
  selfish(n: integer) = array [1..n] of selfish(n);
var
  v: vector(3);
  w: vector(4);
  o: other(3);
  r: real;
  i: integer;

procedure good(var a: vector);
begin
  a[1] := 0.0
end;

{ §6.7.3.3: one formal-parameter-section is one parameter-form, so the two
  actuals bring one tuple between them }
procedure pair(var a, b: vector);
begin
  a[1] := b[1]
end;

{ the type is the actual's, so nothing in the body may assume a length }
procedure guessing(var a: vector);
begin
  { §6.8.4 makes a schema-discriminant a primary: there is nowhere to store }
  a.n := 4;
  { and only a formal discriminant of the schema answers to a dot }
  r := a.bogus
end;

{ each of the three above, so that each is resolved. The bodies say nothing:
  a parameter whose form was refused has a placeholder type, and using it
  would report the placeholder rather than the mistake. }
procedure notarray(var b: boxed);
begin i := 1 end;

procedure notordinal(var s: sized);
begin i := 2 end;

procedure recursive(var s: selfish);
begin i := 3 end;

{ a parameter form that is a bare schema-name is congruous with another only
  when it is the same schema: the tuple is the actual's business, the schema
  is not }
procedure applies(procedure p(var a: vector));
begin
  p(v)
end;

procedure takesother(var a: other);
begin
  a[1] := 0.0
end;

begin
  { the actual has to be produced from the schema the formal names }
  good(r);
  good(o);
  { and it has to be a variable, in either passing mode }
  good(3.0);
  { §6.7.3.3 again: two arguments of one section, two different tuples }
  pair(v, w);
  pair(v, v);
  { congruity is decided on the schema }
  applies(takesother);
  applies(good);
  { a schema is still not a type outside a parameter form }
  i := 0
end.
