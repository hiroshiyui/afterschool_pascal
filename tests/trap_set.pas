program TrapSet(output);
{ ISO 7185 6.4.6: storing a value that is not of the variable's type is an
  error, and a set carrying a member outside its base type is exactly that.
  The constructor cannot catch it -- a constructor does not know what it is
  being assigned to -- so the check is at the store (ADR-0028).

  The base type deliberately does not start at zero: a universe built from
  0..hi rather than lo..hi would accept this and is the mutation this pins. }
type inner = set of 5..9;
var d: inner; i: integer;
begin
  i := 7;
  d := [i];
  writeln('in range: ', 7 in d);
  i := 2;
  d := [i];
  writeln('unreachable')
end.
