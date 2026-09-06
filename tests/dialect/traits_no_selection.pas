{ What a trait-keyed call cannot select (ADR-0340). The selecting type is read
  from the *designator* one step before CheckArguments, so a literal, an
  expression and a function result select nothing; a procedure is not yet
  dispatched at all; and two traits declaring one spelling for one type select
  neither. }
program traits_no_selection(output);

type Point = record x: integer end;

trait Sortable;
  function Rank(p: Self; q: Self): integer;
  procedure Emit(p: Self);
end;

trait Ranked;
  function Rank(p: Self; q: Self): integer;
end;

impl Sortable for integer;
  function Rank;
  begin Rank := p - q end;
  procedure Emit;
  begin writeln(p:1) end;
end;

impl Sortable for Point;
  function Rank;
  begin Rank := p.x - q.x end;
  procedure Emit;
  begin writeln(p.x:1) end;
end;

impl Ranked for Point;
  function Rank;
  begin Rank := q.x - p.x end;
end;

function Twice(n: integer): integer;
begin Twice := n + n end;

var i, j: integer; p, q: Point;
begin
  i := 7; j := 3;
  { a designator selects }
  writeln(Rank(i, j):1);
  { a literal, an expression and a function result do not }
  writeln(Rank(7, 3):1);
  writeln(Rank(i + 1, j):1);
  writeln(Rank(Twice(i), j):1);
  { a procedure is not dispatched }
  Emit(i);
  { and two traits over one type select neither }
  writeln(Rank(p, q):1)
end.
