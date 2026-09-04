{ AP 6.4.14.9 (ADR-0319): a borrow may be lent to a routine that cannot name
  what it borrows from. This file is the admitted half -- every shape here is
  one the rule must go on accepting, and between them they are how an owned
  structure is actually used. The refusals are owned_nonlocal_errors.pas. }
program owned_nonlocal(output);

type Own  = owned ^Node;
     Node = record v: integer; next: Own end;

{ A sibling. It is declared beside the block that owns the variable, not
  inside it, so no static link of its reaches that frame (ADR-0016). }
procedure Bump(var n: Node);
begin n.v := n.v + 1 end;

{ The traversal every owned chain has, and the case the rule turns on: a
  recursive call activates a frame of its own, so the callee's `o` is not the
  caller's, and a routine is not nested in itself. Refusing this would refuse
  PasList. }
function Len(protected var o: Own): integer;
begin
  if o = nil then Len := 0 else Len := 1 + Len(o^.next)
end;

{ Passing a borrow *on* to a sibling: the owner is a parameter of Hand, and
  Bump is not declared inside Hand. }
procedure Hand(protected var o: Own);
begin Bump(o^) end;

procedure Run;
var head: Own; i: integer;

  { Declared inside Run and so able to name Run's variables -- but it is
    handed no borrow of them, which is what the rule is about. }
  procedure Report(label_: char);
  begin writeln(label_, ' ', head^.v:1) end;

begin
  new(head); head^.v := 1;
  new(head^.next); head^.next^.v := 2;

  Bump(head^);                  { the owner is a local of Run, Bump a sibling }
  Hand(head);                   { and passed on through a parameter }
  writeln('bumped ', head^.v:1);
  writeln('len    ', Len(head):1);
  Report('r');

  { A `with` bound to what a local owns, and a call in its body that cannot
    reach that local. }
  with head^ do begin
    Bump(head^.next^);
    writeln('with   ', v:1, ' ', next^.v:1)
  end;

  for i := 1 to 2 do Bump(head^);
  writeln('final  ', head^.v:1)
end;

begin
  Run
end.
