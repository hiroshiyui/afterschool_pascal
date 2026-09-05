{ AP 6.4.14.3's release over a domain that owns *two* of its own type.

  ADR-0322 made a chain cost one frame by continuing the release at a direct
  field whose type is an owned pointer to the domain, instead of recursing
  into it. It took the **first** such field, and said so: a record with two of
  them is a binary tree and whichever is chosen the other still recurses.

  What that left is a program whose survival depends on which of two
  identically typed fields was written first. These two are the same program:

      fresh^.l := take(head)      -- 400 000 nodes, released, exit 0
      fresh^.r := take(head)      -- 400 000 nodes, SIGSEGV, exit 139

  ADR-0333 threads the work list through the nodes being released, using the
  first self-owned field as the link and rescuing what it held. Every
  self-owned field of the domain is then taken out and pushed rather than
  recursed into, so the depth is bounded by nothing at all -- and the three
  shapes below are one frame each.

  Built by loops and not by recursion, for ADR-0322's reason: what is measured
  is the release alone. }
program owned_tree(output);

const Deep = 400000;

type Own  = owned ^Node;
     Leaf = record w: integer end;
     OLeaf = owned ^Leaf;
     { `tag` is an owned field of a *different* domain, so it is walked and
       never threaded: the work list is for what the release would otherwise
       recurse into at the same depth, and `tag`'s release is one level and
       stops. }
     Node = record v: integer; l, r: Own; tag: OLeaf end;

{ degenerate on the field the release used to continue at }
procedure Left;
var head, fresh: Own; i: integer;
begin
  for i := 1 to Deep do begin
    new(fresh);
    fresh^.v := i;
    fresh^.l := take(head);
    head := take(fresh)
  end;
  writeln('left  ', Deep:1, ', front ', head^.v:1)
end;

{ degenerate on the other one, which is the same program }
procedure Right;
var head, fresh: Own; i: integer;
begin
  for i := 1 to Deep do begin
    new(fresh);
    fresh^.v := i;
    fresh^.r := take(head);
    head := take(fresh)
  end;
  writeln('right ', Deep:1, ', front ', head^.v:1)
end;

{ and alternating, which no choice of one field could have helped: the release
  has to leave the walk it is on and come back to it }
procedure Zigzag;
var head, fresh: Own; i: integer;
begin
  for i := 1 to Deep do begin
    new(fresh);
    fresh^.v := i;
    if odd(i) then fresh^.l := take(head) else fresh^.r := take(head);
    head := take(fresh)
  end;
  writeln('zig   ', Deep:1, ', front ', head^.v:1)
end;

{ a shape rather than a depth: every node reachable, released once. Balanced,
  so it says nothing about the stack and everything about the walk. }
{ a var parameter and not a result: 6.4.14.3 refuses a function result that
  owns, there being no variable to release it }
procedure Build(var n: Own; d: integer);
var k: Own;
begin
  new(k);
  k^.v := d;
  new(k^.tag);
  k^.tag^.w := d;
  if d > 0 then begin
    Build(k^.l, d - 1);
    Build(k^.r, d - 1)
  end;
  n := take(k)
end;

procedure Balanced;
var t: Own; d: integer;
begin
  d := 12;
  Build(t, d);
  writeln('tree  ', d:1, ', root ', t^.v:1, ', left ', t^.l^.v:1,
          ', right ', t^.r^.v:1)
end;

begin
  Left;
  Right;
  Zigzag;
  Balanced;
  writeln('released')
end.
