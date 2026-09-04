{ AP 6.4.14.8 (ADR-0318): a protected variable parameter of an owned-pointer
  type is the language's second borrow form -- a name for what a variable owns
  that may be read through and through which nothing may be released.

  Every position below is one a program would put such a parameter in, and the
  point of the file is that each compiles: the refusals are
  owned_protected_errors.pas. }
program owned_protected(output);

type Own  = owned ^Node;
     Node = record v: integer; next: Own end;
     Box  = record p: Own end;
     Held = record o: Own end;
     Ord  = ^Held;

{ Read through the borrow, and compare it with nil (AP 6.4.14.4). }
function Peek(protected var o: Own): integer;
begin
  if o = nil then Peek := -1 else Peek := o^.v
end;

{ Recursion through it. `o^.next` is a component of the *identified* variable
  and not of o, so passing it on threatens nothing of o -- which is what makes
  a protected owned pointer usable at all, AP 6.4.14's NOTE 1 giving recursion
  through a var parameter as the whole of how an owned chain is traversed. }
function Len(protected var o: Own): integer;
begin
  if o = nil then Len := 0 else Len := 1 + Len(o^.next)
end;

{ Handed on to another protected parameter -- 6.9.4 b) threatens an actual only
  where the formal is not itself protected, which is the base case that makes
  the word usable. }
function Sum(protected var o: Own): integer;
begin
  if o = nil then Sum := 0 else Sum := Peek(o) + Sum(o^.next)
end;

{ A record that owns one. 6.4.1 asks the question of the whole type, so Box is
  protectable exactly because its field is. }
function BoxPeek(protected var b: Box): integer;
begin BoxPeek := Peek(b.p) end;

{ What AP 6.4.14.7 a) refuses when the owner is unprotected, admitted here: the
  first actual is the owner and the second is a borrow of what it owns, and no
  release of the owner can occur in the call. }
procedure Bump(protected var o: Own; var n: Node);
begin n.v := n.v + Peek(o) end;

{ Contents are not ownership. A field of the identified variable may be
  written through a protected borrow and through a `with` on one: AP 6.4.14.8
  refuses a release and says nothing about a store, which is the whole
  difference between it and a constant-access (§6.9.3.10). }
procedure Set1(protected var o: Own);
begin o^.v := o^.v + 1 end;

procedure Set2(protected var o: Own);
begin with o^ do v := v + 1 end;

var head: Own; b: Box; op: Ord;
begin
  new(head); head^.v := 1;
  new(head^.next); head^.next^.v := 2;
  writeln('peek ', Peek(head):1);
  writeln('len  ', Len(head):1);
  writeln('sum  ', Sum(head):1);
  new(b.p); b.p^.v := 9;
  writeln('box  ', BoxPeek(b):1);
  Bump(head, head^);
  writeln('bump ', head^.v:1);
  Set1(head); Set2(head);
  writeln('set  ', head^.v:1);
  { An owned pointer under an *ordinary* one. The path from the designator to a
    variable crosses a dereference that is not owned, so it reaches no owner at
    all and no protection can be in force: whoever holds the ordinary pointer
    was never lent anything. This is the arm that answers nothing, and it is
    here because it is the only shape that takes it. }
  new(op); new(op^.o); op^.o^.v := 5;
  writeln('ord  ', op^.o^.v:1);
  dispose(op^.o);
  dispose(op)
end.
