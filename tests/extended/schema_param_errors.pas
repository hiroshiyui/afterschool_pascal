{ What a schematic formal parameter refuses. Sema accumulates, so one run
  reports all of these. }
program SchemaParamErrors(output);
type
  vector(n: integer) = array [1..n] of real;
  other(n: integer) = array [1..n] of real;
  { a discriminant may bound an array, and a record may hold one *last*
    (ADR-0045) -- but only last, because a field after a dynamically-sized one
    would sit at an offset nothing can compute. A variant part is refused for
    the same reason: its shared block is laid after the fixed fields. And a set
    and a file are each sized once, so neither may be dynamic at all }
  boxed(n: integer) = record a: array [1..n] of char; b: integer end;
  tagged(n: integer) = record a: array [1..n] of char;
                              case k: boolean of true: (x: integer);
                                                 false: (y: integer) end;
  { two dynamic fields: the last one may be dynamic, and this says *only* the
    last one may be. `boxed` above cannot say it — a static field after the
    dynamic one already fails the "is the last field dynamic" question, so the
    rule about the fields before it is never reached }
  two(n: integer) = record a: array [1..n] of char;
                           b: array [1..n] of char end;
  { and the same with a *tagless* variant part, which is the one that needs
    saying: a tag field is an ordinary field and lands after the dynamic one,
    so the rule about fields already covers `tagged`. Without a tag there is no
    field at all — only the shared block, which the field rule never sees }
  untagged(n: integer) = record a: array [1..n] of char;
                                case boolean of true: (x: integer);
                                                false: (y: integer) end;
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

procedure twodynamic(var b: two);
begin i := 5 end;

procedure hasvariant(var b: tagged);
begin i := 3 end;

procedure hasbareariant(var b: untagged);
begin i := 4 end;

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
