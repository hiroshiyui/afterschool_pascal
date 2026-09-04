{ A module owning something in its outermost block, and a routine of its own
  that releases it. It exists for AP 6.4.14.9's first answer (ADR-0319): a
  variable of the outermost block is nameable by every routine of its own
  component, and by every importer where the module exports it -- and the
  importer's compiler cannot see this body, so what it must go on is where the
  variable is declared and nothing else.

  It is the case that makes `v^.level = 0` load-bearing. Within one component
  the walk up the owner chain reaches the outermost block too, so the branch is
  a second way of saying the same thing; across a component boundary it is the
  only way, an imported routine's chain terminating in *its* module. Disabling
  the branch leaves this case's importer compiling clean. }
module ownkeeper;

export ownkeeper = (Node, Own, Held, Wipe);

type Node = record v: integer end;
     Own  = owned ^Node;

var Held: Own;

{ Names Held without being handed it, which is the whole point. }
procedure Wipe(var n: Node);

end;

procedure Wipe;
begin
  dispose(Held);
  n.v := 1
end;

to begin do begin
  new(Held);
  Held^.v := 7
end;

end.
