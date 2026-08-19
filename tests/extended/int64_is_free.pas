{ ADR-0128's `int64` is the dialect's and does not leak (ADR-0117).

  A required type-identifier is a symbol in a scope enclosing the program
  (6.2.2.10, ADR-0097), so declaring one takes a name away from every program
  that does not shadow it -- and the dialect must not take a name away from
  Extended Pascal, which has its own specification and stays exactly what it
  is. Under this standard `int64` is an ordinary identifier and this program
  is what says so: it declares a type of that name, a variable of that name,
  and a function of that name, and none of the three is remarkable.

  The other half is 6.1.3, which makes a required identifier shadowable: the
  same program compiles under --std=afterschool as well, where `int64` *is*
  required and the declaration below hides it. tests/dialect/int64.pas is
  where the type is used; this file is about the spelling. }
program Int64IsFree(output);
type int64 = 1..100;
var  x: int64;

function twice(n: integer): integer;
begin
  twice := n + n
end;

begin
  x := 40;
  writeln(twice(x))
end.
