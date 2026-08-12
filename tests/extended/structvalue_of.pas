{ The 'of' after a variant-part-value's constant-tag-value. }
program structvalue_of(output);
type
  kinds = (circle, box);
  shape = record case kind: kinds of circle: (r: real); box: (w: integer) end;
var s: shape;
begin
  s := shape[case kind: box [w: 1]];
  writeln(s.w)
end.
