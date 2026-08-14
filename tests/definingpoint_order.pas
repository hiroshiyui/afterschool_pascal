{ ISO 7185 §6.2.2.9:

    The defining-point of an identifier or label shall precede all applied
    occurrences of that identifier or label contained by the program-block
    with one exception, namely that an identifier can have an applied
    occurrence in the type-identifier of the domain-type of any
    new-pointer-types contained by the type-definition-part containing the
    defining-point of the type-identifier.

  So a name used in a block may not then be declared in it. §6.2.2.8's NOTE is
  the same sentence from the other side: within the scope of a defining-point
  there are no applied occurrences of an identifier that cannot be
  distinguished from it and whose own defining-point is in an enclosing region.

  This compiler enforced the rule only where the name resolved to *nothing* --
  ADR-0069's `var v: t` before `type t`. Where it resolved to an enclosing
  declaration the earlier uses silently kept the outer meaning and the later
  declaration took effect from its own position, which is one name with two
  meanings in one block. Five of the BSI suite's DEVIANCE programs are that
  shape and this file is all five.

  **The legal shadowing matters as much as the violations**, and the two
  procedures below it come first. `user` reads the program's `size` and
  `small`; `shadower` then declares its own. That is not a violation and never
  was -- `user`'s body is not contained by `shadower`'s block -- so a rule
  written against *depth* rather than against the block would report it. Both
  are here because a check that fires on them is worse than no check.

  The exception is pinned separately, in tests/pointer_domain_shadow.pas: a
  pointer's domain may name a type defined later in its own
  type-definition-part, so that occurrence is not one the defining-point has
  to precede. It was this file's rule that first refused it. }
program DefiningPointOrder(output);
const size = 10;
type  small = 1..9;
var   i : integer;

{ Legal: an enclosing name applied in a block that does not redeclare it. }
procedure user;
var n : small;
begin
  n := 1;
  i := size
end;

{ Legal: the same names declared afresh in a block that had not used them.
  Nothing above is contained by this block. }
procedure shadower;
const size = 20;
type  small = 1..3;
var   n : small;
begin
  n := 1;
  i := size
end;

{ §6.3's constant, used and then redeclared. }
procedure clashConst;
const copy = size;
      size = 30;
begin
  i := copy
end;

{ §6.4.1's type, in what would otherwise be its own definition. }
procedure clashType;
type alias = small;
     small = 1..2;
var  v : alias;
begin
  v := 1
end;

procedure outerCall;
begin
  i := 1
end;

{ §6.6.1: the call in `caller` is an applied occurrence of the *program's*
  `outerCall`, and it is contained by `holder`'s block -- so `holder` may not
  then declare one. The applied occurrence is in a block that has already been
  left by the time the declaration is reached, which is why this cannot be
  answered by looking at the scope being declared into alone. }
procedure holder;
  procedure caller;
  begin
    outerCall
  end;
  procedure outerCall;
  begin
    i := 2
  end;
begin
  caller
end;

{ §6.6.3.1's formal-parameter-list is part of the block, so a type applied in
  it is applied in the block a later parameter is declared into. }
procedure params(a : small; small : integer);
begin
end;

begin
  user;
  shadower;
  clashConst;
  clashType;
  holder;
  params(1, 2)
end.
