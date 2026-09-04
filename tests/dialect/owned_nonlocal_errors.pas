{ AP 6.4.14.9 (ADR-0319): a borrow may not be lent to a routine that can name
  what it borrows from. Two ways a routine can -- the variable is one of the
  outermost block, or the routine is declared inside the block that declares
  it -- and two constructs that form a borrow, an actual-parameter and a
  with-element.

  This is what closed Annex C.12: ADR-0317 refused the two shapes one
  activation-point can be asked about and left the release reached through a
  further activation undetected, and this is that release, refused where the
  borrow is formed rather than where it is released. }
program owned_nonlocal_errors(output);

type Own  = owned ^Node;
     Node = record v: integer; next: Own end;

var g: Own;

{ Reaches g without being handed it. This is the body ADR-0317's record wrote
  out as the shape no local rule could see. }
procedure Kill(var n: Node);
begin dispose(g); n.v := 999 end;

procedure Free_; begin dispose(g) end;

{ Takes no borrow at all, and is refused all the same when it is called from
  inside a `with` that holds one: what matters is what it can reach. }
procedure Quiet; begin end;

{ Both rules reach this call: the owner is an argument, which is 6.4.14.7 a),
  and it is also a variable of the outermost block, which is 6.4.14.9. One
  mistake, one message, and the one written is the pairwise one -- naming the
  argument says more than naming the scope. }
procedure Both_(var o: Own; var n: Node);
begin dispose(o); n.v := 1 end;

procedure Outer;
var loc: Own;

  { Declared inside Outer, so its static link reaches Outer's frame and it can
    name loc. }
  procedure Inner(var n: Node);
  begin dispose(loc); n.v := 1 end;

begin
  new(loc);
  Inner(loc^)                    { the nested form }
end;

begin
  new(g);

  { the outermost-block form }
  Kill(g^);

  { and where the pairwise rule also applies, only it speaks }
  Both_(g, g^);

  { a `with` holds the borrow and the call reaches the owner }
  with g^ do begin
    Free_;
    v := 1
  end;

  { and the call need not touch it: Quiet is refused because it *could* }
  with g^ do
    Quiet;

  Outer
end.
