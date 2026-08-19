{ 6.2.3.8 b) at the one block that has no frame (ADR-0113).

  A subrange-bound that is not a constant is evaluated at the commencement of
  the activation of "the module-heading of the module, the module-block of the
  module, or the block" -- and the main-program-block is a block, so the offer
  is made there too. The program's variables are a global rather than a frame,
  there being exactly one activation of it, so the descriptor this fills has no
  frame register to be indexed from; the prologue wrote one anyway and the
  result was IR naming a value that does not exist.

  6.2.2.9 needs the defining-point to precede the applied occurrence, and
  declarations interleave by source position (ADR-0100), so a function declared
  ahead of the variable-declaration-part is what makes the bound well-defined
  here: at program level there are no value parameters to have been attributed
  by a), and any other bound would read an undefined variable. }
program DynBoundsProgram(output);

function width: integer;
begin
  width := 4
end;

var row: array [1..width] of integer;
    grid: array [1..width, 1..width] of integer;
    i, j: integer;

begin
  for i := 1 to 4 do
    row[i] := i * i;
  for i := 1 to 4 do
    for j := 1 to 4 do
      grid[i, j] := 10 * i + j;
  writeln(row[1]:1, ' ', row[4]:1);
  writeln(grid[1, 1]:1, ' ', grid[4, 4]:1)
end.
