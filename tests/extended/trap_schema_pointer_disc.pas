{ A discriminant outside its own type is outside §6.4.7's domain. Storing it
  into the header is where the value enters the variable that holds it, so the
  check that guards every other such store makes this one too — and reports it
  in the words a subrange always uses. }
program TrapSchemaPointerDisc(output);
type small = 1..4;
     vector(n: small) = array [1..n] of integer;
var p: ^vector;
    k: integer;
begin
  k := 4;
  new(p, k);
  writeln('vector(', p^.n:1, ') exists');
  k := 9;
  new(p, k)
end.
