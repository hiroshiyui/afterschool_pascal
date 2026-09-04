{ A linked list that frees itself: the owned pointer and `take`.

  In Turbo Pascal a list is `^Node` pointers and every node you forget to
  Dispose is leaked. Here `owned ^Node` (ADR-0181) makes the variable that
  holds a node its owner: when the variable dies -- at the end of its block,
  or on `dispose` -- the node and everything it owns is disposed with it.
  The price is that an owned pointer has no copy. `take(p)` (ADR-0182)
  moves what p holds and leaves p empty, and it is the only way to hand a
  node on; a list is therefore walked by recursion, since a loop would need
  a second pointer to the current node. Nothing is imported. }
program owned_list(output);

type
  List = owned ^Node;
  Node = record key: integer; next: List end;

var
  head: List;
  seeds: string(16);
  k: integer;

{ Sorted insertion. }
procedure Insert(var l: List; key: integer);
var fresh: List;
begin
  if (l = nil) or (key <= l^.key) then begin
    new(fresh);
    fresh^.key := key;
    fresh^.next := take(l);      { the rest of the list hangs off the new node }
    l := take(fresh)             { and the new node becomes the front }
  end
  else
    Insert(l^.next, key)
end;

procedure Show(protected var l: List);
begin
  if l <> nil then begin
    write(' ', l^.key:1);
    Show(l^.next)
  end
end;

{ Pop the front: `l` stops holding its first node, which is disposed -- but
  that node's `next` was moved out first, so exactly one node goes. }
procedure PopFront(var l: List);
begin
  if l <> nil then l := take(l^.next)
end;

begin
  seeds := '5391746';
  for k := 1 to length(seeds) do
    Insert(head, ord(seeds[k]) - ord('0'));
  write('sorted:'); Show(head); writeln;
  PopFront(head);
  write('popped:'); Show(head); writeln;
  { The early release. Without this line the block's end does the same. }
  dispose(head);
  writeln('empty: ', head = nil)
end.
