program TrapBounds(output);

{ ISO 7185 §6.5.3.2 makes an index outside an array's bounds an error, so the
  program stops rather than reading whatever happens to be next in the frame.
  The index comes from a function so that no amount of optimisation can fold
  the check away. }

var
  a: array [1..5] of integer;
  i: integer;

function Wander(n: integer): integer;
begin
  Wander := n * 3
end;

begin
  for i := 1 to 5 do
    a[i] := i;

  writeln('a[3] = ', a[Wander(1)]);
  writeln('about to leave the array');
  writeln('a[6] = ', a[Wander(2)])
end.
