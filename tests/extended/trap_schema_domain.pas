{ §6.4.7 NOTE 2: a tuple that leaves an index range empty is not in the
  schema's domain, so it selects no type at all. Where the tuple is constant
  Sema says so; where it is not, the check is made where the tuple is — when
  the block is entered. }
program TrapSchemaDomain(output);
type vector(n: integer) = array [1..n] of integer;

procedure hold(m: integer);
var v: vector(m);
begin
  writeln('vector(', v.n:1, ') exists')
end;

begin
  hold(1);
  hold(0)
end.
