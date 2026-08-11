{ The destination's tuple is written in the program and the source's is not,
  which is still §6.4.6 d): "produced from the same schema, but not with the
  same tuple" says nothing about which side the compiler happens to know. A
  version that took the run-time path only when the *destination* was generic
  survived a green suite until this file existed — it would copy a vector of
  any length into this one, with the destination's length. }
program TrapSchemaAssignKnown(output);
type vector(n: integer) = array [1..n] of integer;

var three: vector(3);
    four: vector(4);
    i: integer;

procedure take(var v: vector);
var mine: vector(3);
begin
  mine := v;
  writeln('took ', v.n:1, ' into ', mine.n:1)
end;

begin
  for i := 1 to 3 do three[i] := i;
  for i := 1 to 4 do four[i] := i * 100;
  take(three);
  take(four)
end.
