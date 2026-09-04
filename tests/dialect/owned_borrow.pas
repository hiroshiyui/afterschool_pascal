{ The one second name an owned value has, and what it cannot do (ADR-0201).

  AP 6.4.14 refuses every copy of an owned pointer, so the language has no two
  names for one owned value -- almost. A `var` parameter bound to `o^` is a
  second name for what `o` owns, for the duration of the call. That is a
  **borrow**, and it is the half of Rust's aliasing model this language turns
  out to have had all along, arrived at from ISO 7185's own poverty rather than
  from a checker:

    - Pascal has no address-of operator. The alternative `@` of 6.1.9 is
      refused here (selfhost/torture.pas), and no other syntax yields the
      address of a variable.
    - `new` is the only thing that produces a pointer value.

  So no pointer can ever name what a `var` parameter refers to, and a borrow
  cannot outlive the call that made it. Nothing in the compiler *knows* this --
  it is unformable rather than checked, which is why `doc/sop.md` §7 carries it:
  a future feature adding a way to form such a value would take the property
  away in silence.

  The last block is the classic Pascal aliasing hazard applied to the new type:
  two `var` parameters bound to one variable, and a move between them. It is a
  self-move, it is safe, and the heap balances -- `take` empties the variable
  before the target's address is taken (ADR-0182), so the value goes straight
  back where it came from.

  **The owned variables are locals of `Run` and not variables of the program**,
  and that is AP 6.4.14.9 (ADR-0319) rather than a style. A variable of the
  outermost block can be named by every routine of the component, so a borrow
  of what it owns could be released by the very routine it was lent to; a local
  of `Run` can be named by `Run` and by anything declared inside it, and `Bump`
  and `Read` are declared beside it rather than in it. This file used to write
  them at program level and was the reason the rule was measured against the
  corpus. }
program owned_borrow(output);

type Node = record v: integer; next: ^Node end;
     Own = owned ^Node;

{ A borrow. The record is reached through a var parameter, so `n` and `o^` are
  one variable for as long as this runs -- and `o` still owns it. }
procedure Bump(var n: Node);
begin n.v := n.v + 1 end;

{ Two names for one owned *variable*, which is what a var parameter of the
  owned type is. The move between them is a self-move when the caller passes
  one variable twice. }
procedure MoveInto(var dst, src: Own);
begin dst := take(src) end;

{ A borrow may be passed on as a borrow: what it may not become is a value that
  outlives the call, and there is no way to write one. }
function Read(var n: Node): integer;
begin Read := n.v end;

{ Every owned variable in this file lives here: see the last paragraph of the
  heading. }
procedure Run;
var o, spare: Own;
    i: integer;
begin
  new(o);
  o^.v := 1;
  o^.next := nil;

  Bump(o^);
  Bump(o^);
  writeln('borrowed and bumped: ', o^.v:1);
  writeln('read through it:     ', Read(o^):1);

  { The borrow is not the owner: o still holds the value after the call, and
    the block below is what releases it. }
  writeln('owner still holds:   ', o <> nil);

  { Two var parameters, two distinct variables: an ordinary move. }
  MoveInto(spare, o);
  writeln('moved to spare:      ', spare^.v:1, ', o empty: ', o = nil);

  { Two var parameters, one variable: a self-move. `take` empties `spare` and
    the assignment puts the value back, so nothing is disposed and nothing is
    abandoned. }
  MoveInto(spare, spare);
  writeln('self-move kept it:   ', spare^.v:1, ', spare empty: ', spare = nil);

  { And it is still one value, not a copy: bumping through a borrow of it is
    visible through the owner. }
  for i := 1 to 3 do Bump(spare^);
  writeln('still one value:     ', spare^.v:1)
end;

begin
  Run
end.
