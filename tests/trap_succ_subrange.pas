program TrapSuccSubrange(output);
{ ISO 7185 6.6.6.4: succ runs out at the end of the *type*, and for a subrange
  that is the subrange's own upper bound rather than its host's. tests/trap_succ
  uses an integer, where the two coincide; here they do not. }
var d: 1..9;
begin
  d := 9;
  writeln(succ(d))
end.
