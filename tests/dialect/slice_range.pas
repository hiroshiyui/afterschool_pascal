{ ADR-0125: `a[i..j]` is checked against the base's own bounds, where the
  designator is written -- which is the only place the base's extent is still
  known. The callee sees a length and no provenance. }
program slice_range(output);

var a: array [1..8] of integer;

function Count(protected var s: array of integer): integer;
begin
  Count := length(s)
end;

begin
  writeln('inside  = ', Count(a[3..5]):1);
  writeln('empty   = ', Count(a[4..3]):1);
  writeln('about to take a slice that leaves the array:');
  writeln(Count(a[3..9]):1)
end.
