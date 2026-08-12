{ ISO 7185 has no structured-value-constructor, so `pt[x: 1; y: 2]` is a
  subscript of something that is not an array — and the ':' is a syntax error
  before it is anything else. The gate is this file: with the --std test
  dropped from looksLikeStructuredValue, this program compiles. }
program structvalue_iso(output);
type
  pt = record x, y: integer end;
var p: pt;
begin
  p := pt[x: 1; y: 2];
  writeln(p.x)
end.
