{ AP 6.4's trait-declaration and AP 6.7's implementation-declaration
  (ADR-0338, ADR-0339, ADR-0340), exercised everywhere a program would put
  them -- which is what doc/sop.md 4a asks of a construct with a surface.

  Nothing here is reserved. `trait` and `impl` are recognised by *position*
  (ADR-0140): `trait` followed by an identifier, `impl` followed by an
  identifier and `for`. So the same program declares a type named `trait`, a
  field named `impl` and a variable of each, which the declarations below do.

  A receiver may not be called `self` -- 6.1.2 case-folds it against the type
  name `Self` -- so every receiver here is named for what it is (ADR-0340). }
program traits(output);

type
  { The two syntax words as ordinary identifiers, in the program that uses
    the construct. If either were reserved these four lines would not
    compile. }
  trait = 1..9;
  impl = record trait: integer; impl: char end;

  Point = record x, y: integer end;
  Line = record a, b: integer end;
  digit = 1..9;
  Str8 = string(8);

var
  traits: trait;
  impls: impl;

{ ------------------------------------------------------------ a trait ---- }

{ A trait declares more than one routine, and one of its routines may call
  another: inside an implementation the trait-keyed lookup is the same one a
  client uses, so `Alike` reaches this implementation's own `Rank`. }
trait Sortable;
  function Rank(p: Self; q: Self): integer;
  function Alike(p: Self; q: Self): boolean;
end;

{ ------------------------------------- two implementations of one trait -- }

{ 6.2.2's block scope holds neither `Rank` nor `Alike`: they are declared in
  the implementation's own scope and selected by the first actual's type
  (ADR-0340). That is what lets both of these stand in one block. }
impl Sortable for Point;
  function Rank;
  begin Rank := p.x - q.x end;
  function Alike;
  begin Alike := Rank(p, q) = 0 end;
end;

impl Sortable for Line;
  function Rank;
  begin Rank := p.a - q.a end;
  function Alike;
  begin Alike := p.a = q.a end;
end;

{ ------------------------------------------ a required type, and a subrange }

{ ADR-0018's rule said once more: impl lookup asks Base(), so this one serves
  every subrange of integer and `digit` needs none of its own. The receiver is
  a *value* parameter, which is what makes that reachable -- 6.6.3.3 would
  refuse a `digit` actual for a var parameter of type integer (ADR-0340). }
impl Sortable for integer;
  function Rank;
  begin Rank := p - q end;
  function Alike;
  begin Alike := p = q end;
end;

impl Sortable for char;
  function Rank;
  begin Rank := ord(p) - ord(q) end;
  function Alike;
  begin Alike := p = q end;
end;

impl Sortable for Str8;
  function Rank;
  begin Rank := length(p) - length(q) end;
  function Alike;
  begin Alike := p = q end;
end;

{ ------------------------------- an ordinary routine of the same spelling - }

{ 6.2.2.11's placement: the trait-keyed scope is consulted only after the
  ordinary lookup fails, so a program that declares its own `Nearer` goes on
  meaning what it meant. }
function Nearer(a, b: integer): integer;
begin
  if abs(a) < abs(b) then Nearer := a else Nearer := b
end;

{ ------------------------------- a bound on a routine's type parameter ---- }

{ AP 6.7.3.10.5's fifth alternative (ADR-0338), and the trait routine called
  from inside a generic body. Written where a category would be written, and
  the type argument may be written or inferred (ADR-0304). }
function Bigger(T: Sortable type; a, b: T): T;
begin
  if Rank(a, b) >= 0 then Bigger := a else Bigger := b
end;

{ A generic may carry a bound and a category at once, and one type parameter
  with neither: a bound is a property of the parameter, not of the routine. }
function Pick(T: Sortable type; U: ordinal type; V: type;
              a, b: T; k: U; ignored: V): T;
begin
  if ord(k) = 0 then Pick := a else Pick := Bigger(b, a)
end;

{ ------------------------ a bound on a schema's formal discriminant ------- }

{ The payoff (ADR-0338): the bound is written where the type is written down,
  so the client names the type once and every routine taking the schema is
  unchanged. The implementations above must stand *before* this, because
  6.2.2.9 makes written order the only correct one. }
type
  Box(K: Sortable; cap: integer) = record
    n: integer;
    items: array [1..cap] of K
  end;

  { Reached through a pointer domain, which is the shape a container needs
    and the one a record naming a single site named wrongly. }
  PtBox = ^Box(Point);
  { And through a plain application. }
  IntBox = Box(integer, 4);

function BoxTop(Ptr: type; b: Ptr): integer;
begin
  BoxTop := b^.n
end;

var
  pt, pu, pr: Point;
  ln, lm: Line;
  i, j: integer;
  d, e: digit;
  c: char;
  s, t: Str8;
  bp: PtBox;
  ib: IntBox;
  bw: Box(Line, 2);

begin
  { The syntax words, ordinary. }
  traits := 6;
  impls.trait := 8;
  impls.impl := 'z';
  writeln(traits:1, ' ', impls.trait:1, ' ', impls.impl);

  { Two implementations of one trait, selected by the argument's type. }
  pt.x := 5; pt.y := 1; pu.x := 3; pu.y := 1;
  ln.a := 2; ln.b := 0; lm.a := 9; lm.b := 0;
  writeln(Rank(pt, pu):1, ' ', Alike(pt, pu));
  writeln(Rank(ln, lm):1, ' ', Alike(ln, lm));

  { A required type, and a subrange answering through its host. }
  i := 10; j := 4; d := 7; e := 7; c := 'k';
  writeln(Rank(i, j):1, ' ', Alike(i, j));
  writeln(Rank(d, e):1, ' ', Alike(d, e));
  writeln(Rank(c, 'a'):1, ' ', Alike(c, c));
  s := 'abcd'; t := 'xy';
  writeln(Rank(s, t):1, ' ', Alike(s, s));

  { The ordinary routine of the same spelling still wins its own lookup. }
  writeln(Nearer(-3, 8):1);

  { The bound on a routine type parameter, written and inferred. }
  pr := Bigger(Point, pt, pu);
  writeln(pr.x:1, pr.y:1);
  pr := Bigger(pt, pu);
  writeln(pr.x:1, pr.y:1);
  writeln(Bigger(integer, 3, 9):1);
  writeln(Bigger(3, 9):1);
  writeln(Bigger(d, e):1);
  writeln(Pick(integer, boolean, real, 3, 9, false, 0.0):1);
  writeln(Pick(3, 9, true, 0.0):1);

  { The bound on a schema discriminant, through a pointer domain. }
  new(bp, 3);
  bp^.n := 3;
  bp^.items[1].x := 2; bp^.items[1].y := 5;
  bp^.items[2].x := 8; bp^.items[2].y := 5;
  writeln(Rank(bp^.items[2], bp^.items[1]):1);
  writeln(BoxTop(bp):1);
  dispose(bp);

  { And through a plain application, named and written out. }
  ib.n := 4;
  for i := 1 to 4 do ib.items[i] := i * i;
  writeln(Rank(ib.items[3], ib.items[2]):1);
  bw.n := 2;
  bw.items[1].a := 7; bw.items[2].a := 1;
  writeln(Rank(bw.items[1], bw.items[2]):1)
end.
