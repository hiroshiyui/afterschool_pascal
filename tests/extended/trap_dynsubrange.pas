{ The check ADR-0133 gave a dynamically bounded subrange, doing its work. The
  bounds come from the descriptor 6.2.3.8 b) filled rather than from the two
  numbers on the type, which is the whole of the fix -- before it the upper one
  read zero and a *legal* store trapped.

  The message names the bounds as values rather than naming the type, and has
  to: a bound evaluated at the block's commencement has no spelling in the
  source, the program having written an expression and not a name. That is the
  same trade `dynbounds_subscript.pas` shows for an array index, made by the
  runtime for the same reason -- so a char host reports ordinal numbers, which
  is what the array message does too. }
program TrapDynSubrange(output);
procedure p(m: integer);
var y: 1..m; k: integer;
begin
  y := m;
  writeln('stored ', y:1);
  k := m + 1;
  y := k;
  writeln('unreached')
end;
begin p(3) end.
