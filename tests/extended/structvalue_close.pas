{ The ']' that ends a structured value. The element list ends at the first
  thing that is not a ';' and not `otherwise`, so a missing separator is what
  reaches this message rather than a missing bracket. }
program structvalue_close(output);
type vec = array [1..2] of integer;
var v: vec;
begin
  v := vec[1: 10 2: 20];
  writeln(v[1])
end.
