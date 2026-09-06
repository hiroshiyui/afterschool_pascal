{ --dump-symbols over a source declaring a trait and an implementation
  (ADR-0349).

  `symbols.pas` and `symbols_module.pas` beside this file predate the dialect's
  object model, so the walker that answers an editor's outline was never asked
  about a trait -- and it read one through the *procedure* arm of the node it
  found in the block's declaration list, which stopped the compiler. Every one
  of 888 cases was green: no case passed this flag over such a source, and the
  MCP `outline` tool answered with the line it had printed before it died.

  What this pins is the choice as well as the survival. A trait-declaration and
  an implementation-declaration are declarations of the block, and neither is
  an outline entry: a trait's routine names have no defining-point in the block
  containing it (AP 6.7.9.2) and an implementation's are reached only through
  the trait, so what a reader can jump to is the type. The routines *inside*
  an implementation are likewise absent. }
program symbols_traits(output);

type Point = record x, y: integer end;

trait Sortable;
  function Before(p: Self; q: Self): boolean;
end;

impl Sortable for Point;
  function Before;
  begin Before := p.x < q.x end;
end;

function Bigger(T: Sortable type; a, b: T): T;
begin
  if Before(a, b) then Bigger := b else Bigger := a
end;

var u, v: Point;

begin
  u.x := 1; v.x := 2;
  writeln(Bigger(u, v).x:1)
end.
