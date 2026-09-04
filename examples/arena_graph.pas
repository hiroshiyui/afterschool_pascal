{ A graph the owned pointer cannot hold: the arena-and-index shape.

  `owned ^Node` (ADR-0181) makes a variable the owner of what it identifies,
  and the safety that buys costs two things. A node has exactly one owner, so
  nothing may point *back* at it -- no parent link, no cursor, no second edge
  into a node -- and traversal is recursive, because a loop would need a second
  name for the current node and an owned pointer has no copy. The *release* was
  recursive for the same reason, until ADR-0322 made it a loop where a domain
  continues at a field of its own type: a chain of any length now costs one
  frame to release, and a tree still costs one per level (AP 6.4.14 NOTE 2).
  Both costs are one fact: an owned pointer describes a tree.

  A graph is not a tree. What is reached for here is an **arena** -- one block
  holding every node, the links being *indices* into it rather than pointers --
  and it needs nothing this language has not had since ADR-0039. An index is an
  integer: it may be copied, compared and stored twice, which is the whole of
  what the owned pointer refuses, and it cannot dangle, because nothing it
  names is separately freed. Ownership moves up to the block, where there is
  exactly one of it.

  **The arena owns itself**, which is the whole of its release: `owned ^Nodes`
  (AP 6.4.14) makes the variable holding it the owner, so leaving the block
  gives the storage back and there is nothing to write. That is a schema
  domain, which 6.4.14.2 refused outright until ADR-0320 narrowed it to the
  case its reason reaches -- releasing an owned variable means *walking* it,
  and a schema's extents are read from a descriptor the heap has not got, but
  a walk is needed only where the variable holds something whose release is
  more than giving the storage back. An arena of plain records holds nothing
  of the kind, so its release is the deallocation.

  What it costs is that **an index is unchecked in the way a pointer is not**:
  `g^.a[i]` traps on an i outside the arena because every subscript is
  bounds-checked (ADR-0017), but an index into the *wrong* arena is an integer
  like any other and nothing here can see it. That is the trade the shape
  makes, and it is the one an arena makes in any language.

  Nothing is imported. }
program arena_graph(output);

const
  None  = 0;         { the arena's nil -- an index no node and no arc has }
  Chain = 1000000;   { two calls to free, whatever this is }

type
  { Fixed-size, so the arena holds one dynamically-sized array and holds it
    last, which is all ADR-0045 permits. }
  NodeRec = record tag: char; first: integer end;   { first outgoing arc }
  ArcRec  = record dst, next: integer end;          { next arc from that node }

  Nodes(cap: integer) = record n: integer; a: array [1..cap] of NodeRec end;
  Arcs (cap: integer) = record n: integer; a: array [1..cap] of ArcRec  end;
  NodesPtr = owned ^Nodes;
  ArcsPtr  = owned ^Arcs;

var
  g: NodesPtr; e: ArcsPtr; i, k, steps: integer;

function AddNode(protected var g: NodesPtr; tag: char): integer;
begin
  g^.n := g^.n + 1;
  g^.a[g^.n].tag := tag;
  g^.a[g^.n].first := None;
  AddNode := g^.n
end;

{ Pushed onto the front of the source's list, so arcs come out newest first. }
procedure AddArc(protected var g: NodesPtr; protected var e: ArcsPtr;
                 src, dst: integer);
begin
  e^.n := e^.n + 1;
  e^.a[e^.n].dst := dst;
  e^.a[e^.n].next := g^.a[src].first;
  g^.a[src].first := e^.n
end;

{ A loop, not a recursion: `i` is a second name for a node and costs nothing,
  which is the sentence this whole file is about. }
function Length_(protected var g: NodesPtr; protected var e: ArcsPtr;
                 from: integer): integer;
var i, k, cnt: integer;
begin
  cnt := 0; i := from;
  while i <> None do begin
    cnt := cnt + 1;
    k := g^.a[i].first;
    if k = None then i := None else i := e^.a[k].dst
  end;
  Length_ := cnt
end;

begin
  { Four nodes and five arcs: b has two arcs into it and c has two out of it,
    and c -> a closes a cycle. Not one of the three is writable with an owner
    per node. }
  new(g, Chain);
  new(e, Chain);
  g^.n := 0; e^.n := 0;
  for i := 1 to 4 do k := AddNode(g, chr(ord('a') + i - 1));
  AddArc(g, e, 1, 2);            { a -> b }
  AddArc(g, e, 2, 3);            { b -> c }
  AddArc(g, e, 3, 4);            { c -> d, pushed first so it prints second }
  AddArc(g, e, 3, 1);            { c -> a, the back edge }
  AddArc(g, e, 4, 2);            { d -> b, the second arc into b }

  writeln('adjacency');
  for i := 1 to g^.n do begin
    write(g^.a[i].tag, ' ->');
    k := g^.a[i].first;
    while k <> None do begin
      write(' ', g^.a[e^.a[k].dst].tag);
      k := e^.a[k].next
    end;
    writeln
  end;

  write('around the cycle:');
  i := 1;
  for steps := 1 to 7 do begin
    write(' ', g^.a[i].tag);
    i := e^.a[g^.a[i].first].dst
  end;
  writeln;

  { And a million nodes, to say what the arena costs to release. They are made
    in one pass and linked as a path; walking it costs one frame, and releasing
    it is what leaving this block does -- two calls to free, whatever Chain is,
    because what the block owns is the two arenas and not the million nodes
    inside them. This was the length an owned *chain* could not release, and it
    is not any more (ADR-0322), so what separates the two shapes here is the
    *graph* above and not the path below: no arrangement of owners admits a
    cycle or a second edge into a node. Which is the point -- the arena moves
    the ownership up to where there is one of it, and the links inside are
    integers that own nothing. }
  g^.n := 0; e^.n := 0;
  k := AddNode(g, '.');
  for i := 2 to Chain do begin
    k := AddNode(g, '.');
    AddArc(g, e, i - 1, i)
  end;
  writeln('chain of ', Chain:1, ' walked: ', Length_(g, e, 1):1)
end.
