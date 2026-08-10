{ §6.4.7's domain is also the tuples the formal-discriminant-part allows, so a
  discriminant outside its own type is outside the domain. The store into the
  descriptor is where the value enters a variable, so it is the check that
  guards every other such store that says so — the same message a subrange
  gives anywhere else. }
program TrapSchemaDisc(output);
type small = 1..9;
     narrow(n: small) = packed array [1..n] of char;

procedure hold(m: integer);
var w: narrow(m);
begin
  w[1] := 'x';
  writeln('narrow(', w.n:1, ') exists')
end;

begin
  hold(4);
  hold(20)
end.
