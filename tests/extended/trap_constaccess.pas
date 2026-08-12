{ ISO/IEC 10206:1991 D.88 at run time.

  §6.8.8.1's NOTE makes a constant-access a run-time read when its index is a
  variable, so an index outside the array is an error the program meets rather
  than one the compiler reports. It is the check ADR-0017 already emitted for
  every subscript — a constant-access is a designator's spine with a constant
  at the bottom of it (ADR-0069) — which is why this program needed no code
  written for it, and why it is here: nothing else in the corpus reaches D.88
  through a constant. }
program trap_constaccess(output);
type
  vec = array [1..4] of integer;
const
  squares = vec[1: 1; 2: 4; 3: 9; 4: 16];
var
  i: integer;
begin
  { In range, so the constant's storage really was filled. }
  for i := 1 to 4 do
    write(squares[i]:1, ' ');
  writeln;
  i := 7;
  writeln(squares[i]:1)
end.
