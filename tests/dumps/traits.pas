{ --dump-all over AP 6.4's trait-declaration and AP 6.7's
  implementation-declaration (ADR-0338): what the parser built for each -- a
  trait as a list of headings, an implementation as a list of routines under
  the trait and type it names -- and what Sema annotated it with. Both join
  the block's procedure chain, because 6.2.2.9 makes written order the only
  correct one, so they appear among `procs` in the order written and not in a
  part of their own.

  Every implementation here is for a type the program declared, and the call
  at the end is trait-keyed: the golden shows the routine it resolved to. }
program traits(output);

type point = record x: integer end;

trait ranked;
  function rank(p: Self; q: Self): integer;
end;

function plain(n: integer): integer;
begin plain := n end;

impl ranked for point;
  function rank;
  begin rank := p.x - q.x end;
end;

var a, b: point;
begin
  a.x := 3; b.x := 1;
  writeln(plain(rank(a, b)):1)
end.
