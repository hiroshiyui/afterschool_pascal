{ The '[' that opens the selected variant's field-list-value. }
program structvalue_open(output);
type
  kinds = (circle, box);
  shape = record case kind: kinds of circle: (r: real); box: (w: integer) end;
var s: shape;
begin
  s := shape[case kind: box of w: 1];
  writeln(s.w)
end.
