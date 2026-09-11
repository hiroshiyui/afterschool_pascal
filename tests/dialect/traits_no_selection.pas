{ What a trait-keyed call cannot select (ADR-0340, ADR-0407). The selecting
  type is read from the *designator* one step before CheckArguments, so a
  literal, an expression and a function result select nothing; and two traits
  declaring one spelling for one type select neither.

  **A procedure used to be in that list and is not** (ADR-0407): AP 6.7.10.2
  named a procedure-statement beside a function-designator from the day it was
  written and only the function half was built. So the procedure half of every
  limitation above is here now instead, which is the honest replacement for
  the struck line -- a case that only lost a claim would be a case asserting
  less than it did. }
program traits_no_selection(output);

type Point = record x: integer end;

trait Sortable;
  function Rank(p: Self; q: Self): integer;
  procedure Emit(p: Self);
end;

trait Ranked;
  function Rank(p: Self; q: Self): integer;
  procedure Emit(p: Self);
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
  procedure Emit;
  begin writeln(p.x + 1:1) end;
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
  { a procedure IS dispatched now, and by the same rule: `integer` has one
    implementation of `Emit`, so this resolves and this program's only
    remaining fault is the ones below }
  Emit(i);
  { a literal selects nothing here either -- the procedure half of the first
    three claims above }
  Emit(7);
  { two traits declaring one spelling for one type select neither, for a
    procedure as for a function }
  Emit(p);
  { and a trait's *function* is not a statement. Over `integer`, where only
    one trait implements `Rank`, so what is reported is this claim and not
    the ambiguity above masking it. }
  Rank(i, j);
  writeln(Rank(p, q):1)
end.
