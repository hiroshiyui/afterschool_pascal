{ The ':' after an array-value-element's selector. A parser stops at its first
  error, so each of 6.8.7's grammatical insistences needs a file of its own. }
program structvalue_colon(output);
type vec = array [1..2] of integer;
var v: vec;
begin
  v := vec[1 10; 2: 20];
  writeln(v[1])
end.
