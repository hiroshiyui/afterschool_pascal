{ §6.7.5.3: it shall be a dynamic-violation if the tuple is not in the domain
  of the schema. The tuple `new` is given is not a constant, so this is the
  same check §6.4.7 NOTE 2 makes when a block is entered — asked of the header
  being built rather than of a descriptor, and made *before* the size it would
  otherwise decide. }
program TrapSchemaPointer(output);
type vector(n: integer) = array [1..n] of integer;
var p: ^vector;
    k: integer;
begin
  k := 1;
  new(p, k);
  writeln('vector(', p^.n:1, ') exists');
  k := 0;
  new(p, k)
end.
