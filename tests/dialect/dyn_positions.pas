{ **AP 6.7.11.1's two positions, and every position that is not one of them**
  (ADR-0409, and ADR-0408 which wrote this case when there were no positions
  at all).

  A trait object refers to storage it does not own, so the two positions are
  the two places the language can say who does: the domain of an owned
  pointer, which names the owner, and a `var` parameter, which is a borrow for
  the duration of the call (6.4.14.7, ADR-0201). Everything else would hold a
  value whose lifetime nothing states, and each line below is one of them.

  **Refusal by construction does not work here and this case is why it is a
  list.** Every type predicate answered false for a trait object and all of
  these compiled anyway, with a `protected` warning the only complaint: in
  each of these positions the default is to *permit*, so a predicate is what
  would have granted rather than what would have refused (ADR-0408).

  `dyn` reserves nothing (6.7.11, ADR-0140), which the declarations at the top
  prove: a type named `dyn`, a field named `dyn` and a variable of each all
  compile, exactly as `owned`'s and `trait`'s do in their own cases. If `dyn`
  were a word-symbol these lines would not parse. }
program dyn_positions(output);

type
  { The syntax word as an ordinary identifier, in the program that uses the
    construct. }
  dyn = 1..9;
  holder = record dyn: integer end;

  Point = record x, y: integer end;

trait Shape;
  procedure Draw(protected var s: Self);
  function Area(protected var s: Self): integer;
end;

impl Shape for Point;
  procedure Draw;
  begin writeln(s.x * s.y:1) end;
  function Area;
  begin Area := s.x * s.y end;
end;

{ a trait nothing implements. A trait object over it is a type, and a call
  through one selects nothing -- there is no implementation to read a
  signature from, so what is reported is that the name is unknown, which is
  the true statement about a program whose trait nothing implements. }
trait Unimplemented;
  procedure Ping(protected var s: Self);
end;

type
  { a named trait-object type: the one denoter position, and the spelling
    6.7.11.1 NOTE 3 requires before an owned pointer can name it }
  D = dyn Shape;
  { the domain of an owned pointer: 6.7.11.1 a), and accepted }
  Held = owned ^D;
  { a field }
  R = record f: dyn Shape end;
  { an array element }
  A = array [1..3] of dyn Shape;
  { the domain of a pointer that is *not* owned -- nothing else releases what
    a trait object refers to, and `new` through one would fill in no table }
  P = ^D;
  { a trait object over a trait nothing implements }
  U = dyn Unimplemented;
  { a file component and an optional's base, which are the two positions a
    reader reaches for after the first four }
  F = file of D;
  O = ?D;

var
  { a variable }
  v: dyn Shape;
  small: dyn;
  h: holder;

{ a value parameter: 6.7.11.1 b) is the *variable*-parameter-specification
  and the protected one, and not this }
procedure ByValue(x: D);
begin
  h.dyn := 1
end;

{ and the two that are permitted, which must compile }
procedure ByVar(var x: D);
begin
  Draw(x)
end;

procedure ByProtectedVar(protected var x: D);
begin
  Draw(x)
end;

procedure NoImpl(protected var u: U);
begin
  Ping(u)
end;

{ a move into a trait object whose trait-identifier denoted no trait. The
  denoter was reported above; this is the coercion asked to build a table for
  a trait that is not there, and it must decline rather than emit one. }
procedure IntoBad;
var b: BadHeld; pt: owned ^Point;
begin
  new(pt);
  b := take(pt)
end;

{ a function result }
function Result0: D;
begin
  h.dyn := 2
end;

{ the name must denote a trait, and `Point` is a type }
type Bad = dyn Point;
type BadHeld = owned ^Bad;

{ The two permitted positions, exercised rather than merely declared -- and
  in a block of their own, because a borrow of what a variable of the
  *outermost* block owns is refused by AP 6.4.14.7 whatever its type is
  (ADR-0201), so writing them up there would have reported that instead and
  this case would have asserted nothing about 6.7.11.1 b). }
procedure Permitted;
var keep: Held; pt: owned ^Point;
begin
  { `new` has no implementation to put in the table }
  new(keep);
  new(pt);
  pt^.x := 6;
  pt^.y := 7;
  keep := take(pt);
  { the owner named where the trait object was meant -- one character, and
    the message says which }
  Draw(keep);
  { the same mistake in a function-designator, which resolves a name by its
    own order and so needs its own arm }
  h.dyn := Area(keep);
  ByVar(keep^);
  ByProtectedVar(keep^);
  IntoBad
end;

begin
  small := 3;
  h.dyn := 4;
  Permitted;
  writeln(small:1, ' ', h.dyn:1)
end.
