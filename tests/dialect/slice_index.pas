{ ADR-0125: a slice is indexed against the length it carries, and that is a
  different check from the one that made it. The callee cannot see where its
  slice came from -- its length is the only bound in scope -- which is exactly
  the property a C buffer-and-count pair cannot promise. }
program slice_index(output);

var a: array [1..8] of integer;

function At(var s: array of integer; k: integer): integer;
begin
  At := s[k]
end;

begin
  a[3] := 30;
  a[4] := 40;
  writeln('first   = ', At(a[3..5], 1):1);
  writeln('last    = ', At(a[3..5], 3):1);
  writeln('about to index one past the end of a slice:');
  writeln(At(a[3..5], 4):1)
end.
