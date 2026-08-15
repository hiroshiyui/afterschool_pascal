{ 6.4.3.6: the index-type of a direct-access file is an ordinal type, because
  a position is counted in components and `real` names no position. }
program DirectFileIndex(output);
type f = file [real] of integer;
var g: f;
begin
end.
