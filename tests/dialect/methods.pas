{ **AP 6.7.10's inherent implementation and AP 6.7.10.4's method-designator**
  (ADR-0410, ADR-0315's increment A): `impl T;` gives a type routines of its
  own, and `x.M(a)` is a second spelling for the call `M(x, a)` already made.

  **Neither is a new mechanism.** 6.7.10.2 has selected a routine from its
  first actual's type since traits landed (ADR-0340); an inherent
  implementation is an implementation with no trait, and a method-designator
  moves the receiver from in front of the dot to the head of the argument
  list. So the two spellings below are one call, and both are exercised
  throughout for exactly that reason -- a case asserting only the new one
  would not say they meet.

  **What it buys is measurable and is what motivated it** (ADR-0315): §6.11.2
  puts every imported name into one scope, so two modules may not export one
  spelling, and 139 of 486 exported names in this library repeat their own
  module's noun to get around it. A method is not an exported name -- what a
  module exports is the *type* -- so `Point` and `Counter` below may each have
  a `Shift` and a `Len`, and neither is in the scope that would refuse them.

  `impl` reserves nothing, which the declarations at the top prove: a type
  named `impl`, a field named `impl` and a variable of it all compile. }
program methods(output);

type
  { the syntax word as an ordinary identifier, in the program that uses the
    construct }
  impl = 1..9;
  holder = record impl: integer end;

  Point = record x, y: integer end;
  Counter = record n: integer end;
  Line = record a, b: integer end;

var
  small: impl;
  h: holder;

{ ------------------------------------------------ a type's own routines -- }

impl Point;
  { a parameterless method: the receiver and nothing else. Pascal has no empty
    argument list, so this is written `p.Len` and the tokens are a field
    selection's -- which is what makes it Sema's to decide. }
  function Len(protected var self: Point): integer;
  begin Len := self.x * self.x + self.y * self.y end;

  { `Self` is bound here exactly as it is in a trait implementation, so a
    receiver may be written either way and this one is the other way. The
    receiver may not then be *named* `self`: §6.1.2 folds case, so the name
    and the bound type are one identifier, and methods_errors.pas holds that
    refusal. }
  procedure Shift(var me: Self; dx, dy: integer);
  begin me.x := me.x + dx; me.y := me.y + dy end;

  { a method returning a value of the type, so that a method may be selected
    on what a method returned. §6.7.2's result-variable-specification is what
    names the result here: assigning to a *field* of a record-typed function
    result is refused by this processor whether or not a method is involved,
    and that is a limitation of its own and older than this construct. }
  function Doubled(protected var self: Point) = r: Point;
  begin r.x := self.x * 2; r.y := self.y * 2 end;

  { a method with an argument *and* a result, so that the expression form
    with a simple receiver has something to be written on. That shape has its
    own path -- a simple name is 6.11.3's qualified call and a parameterless
    one is a field selection, so the three spellings reach three places. }
  function Scaled(protected var self: Point; by: integer): integer;
  begin Scaled := by * (self.x + self.y) end;

  { **A receiver taken by value, which is what makes chaining possible.**
    §6.6.3.3 wants a variable-access for a variable parameter and a method
    result is a function-access, so `p.Doubled.Len` is refused -- Len taking
    `protected var`. That is the language's own rule and not one this
    construct invented, and the answer is the receiver form ADR-0315 names
    first: a value parameter, which is a copy and needs no variable.
    methods_errors.pas holds the refusal. }
  function Sum(self: Point): integer;
  begin Sum := self.x + self.y end;
end;

{ The same two spellings on a second type. Under §6.11.2 these would be
  `PointShift` and `CounterShift`; here neither name is in a scope that could
  collide. }
impl Counter;
  procedure Shift(var self: Counter; by: integer);
  begin self.n := self.n + by end;
  function Len(protected var self: Counter): integer;
  begin Len := self.n end;
end;

{ **A type that is not a record**, which ADR-0315 settled deliberately: the
  names this feature retires belong to a schema, a schema and a handle as
  often as to a record, so an implementation is written for a type and not
  for a record. Chained below as well as called directly, because a receiver
  that is not a record reaches the selection by a path of its own. }
impl integer;
  function Twice(protected var self: integer): integer;
  begin Twice := self * 2 end;
  { by value, so that it may be chained onto what Twice returned }
  function Plus(self: integer; by: integer): integer;
  begin Plus := self + by end;
end;

{ ------------------------------- a trait implemented for the same type -- }

{ A method and a trait routine are selected by one rule, so a type may have
  both and `p.Show` reaches the trait's. What it may not have is two routines
  of one spelling, which methods_errors.pas holds. }
trait Shows;
  procedure Show(protected var p: Self);
end;

impl Shows for Point;
  procedure Show;
  begin writeln('point ', p.x:1, ',', p.y:1) end;
end;

impl Shows for Line;
  procedure Show;
  begin writeln('line ', p.a:1, ',', p.b:1) end;
end;

{ --------------------------------------------------- every receiver form }

procedure Receivers;
var p: Point; q: ^Point; arr: array [1..2] of Point;
    box: record inner: Point end;
begin
  p.x := 3; p.y := 4;
  new(q); q^.x := 1; q^.y := 2;
  arr[1].x := 5; arr[1].y := 6;
  box.inner.x := 7; box.inner.y := 8;
  { a simple name is 6.11.3's qualified form and Sema tells the two apart;
    every other receiver is a complete variable-access and the parser can }
  writeln(p.Len:1, ' ', q^.Len:1, ' ', arr[1].Len:1, ' ', box.inner.Len:1);
  q^.Shift(10, 10);
  arr[1].Shift(10, 10);
  box.inner.Shift(10, 10);
  writeln(q^.Len:1, ' ', arr[1].Len:1, ' ', box.inner.Len:1);
  dispose(q)
end;

{ ------------------------------------------------------ one call, two ways }

procedure BothSpellings;
var p: Point; c: Counter; k: integer;
begin
  p.x := 3; p.y := 4;
  c.n := 10;
  { the method-designator and the call it denotes, of the same routine }
  writeln(p.Len:1, ' ', Len(p):1);
  p.Shift(1, 1);
  Shift(p, 1, 1);
  writeln(p.Len:1, ' ', Len(p):1);
  { and on the other type, where the spellings are the same and the routines
    are not }
  c.Shift(5);
  Shift(c, 5);
  writeln(c.Len:1, ' ', Len(c):1);
  { a method whose result is of the type, selected on and selected from --
    the field by an ordinary selection, and the routine by one that takes its
    receiver by value }
  writeln(p.Doubled.x:1, ' ', p.Doubled.Sum:1);
  { and the expression form with a simple receiver and an argument, which is
    neither of the two above }
  k := p.Scaled(3);
  writeln(k:1, ' ', Scaled(p, 3):1, ' ', p.Doubled.Sum:1);
  { and on a type that is not a record, chained, so that the receiver of the
    outer call is a method result of a scalar type }
  k := 5;
  writeln(k.Twice:1, ' ', k.Plus(1):1, ' ', k.Twice.Plus(1):1)
end;

{ **A method may be foreign** (ADR-0121's directive in AP 6.7.10's routine
  position, pinned by ADR-0411). Nothing had to admit it -- an implementation
  declares its routines the way any block does, and `external` is a directive
  that stands where a body would -- and nothing had asked, so this is the
  case that says which way it went. It is the one method shape that keeps a
  *foreign* linkage name: what is on the other side was translated by a C
  compiler, which knows nothing of the type, and the receiver reaches it as
  the address a `var` parameter already travels as (ADR-0122). }
type CStr = record bytes: packed array [1..8] of char end;

impl CStr;
  function Len(protected var me: CStr): csize; external 'strlen';
end;

procedure Foreign_;
var s: CStr; i: integer;
begin
  for i := 1 to 8 do s.bytes[i] := chr(0);
  s.bytes[1] := 'a'; s.bytes[2] := 'b'; s.bytes[3] := 'c';
  writeln('strlen ', s.Len:1, ' ', Len(s):1)
end;

{ **A parameterless method statement whose receiver is not a bare name.**
  AP 6.7.10.4 says a *variable-access* followed by `.` and an identifier that
  is no field of its type denotes that call, and every spelling of a
  variable-access has to reach it: the receiver here is a field selection, a
  subscript and a dereference, none of which is the simple name the other
  cases in this file use. The parser read the whole designator and then
  demanded `:=`, so `box.p.Show` was `expected ':=' in an assignment` -- a
  message about an assignment nobody wrote, for a statement the
  specification admits. A method *with* arguments was never affected, the
  chain ending in a call the statement could be remade from; what had no
  reading was the chain ending in the husk. }
procedure DeepReceivers;
type Holder = record p: Point end;
var box: Holder; arr: array [1..2] of Point; q: ^Point;
begin
  box.p.x := 5; box.p.y := 6;
  arr[1].x := 7; arr[1].y := 8;
  new(q); q^.x := 9; q^.y := 10;
  box.p.Show;
  arr[1].Show;
  q^.Show;
  dispose(q)
end;

procedure TraitsToo;
var p: Point; l: Line;
begin
  p.x := 1; p.y := 2;
  l.a := 3; l.b := 4;
  { a trait's routine reached by the same spelling, and by its own }
  p.Show;
  l.Show;
  Show(p)
end;

begin
  small := 3;
  h.impl := 4;
  writeln(small:1, ' ', h.impl:1);
  Receivers;
  BothSpellings;
  Foreign_;
  TraitsToo;
  DeepReceivers
end.
