{ D.96: "it is an error if any value that is a member of the value of the
  set-expression of a set-member-iteration ... is assignment-compatibility-
  erroneous with respect to the type possessed by the control-variable".

  §6.9.3.9.3 makes the *members* assignment-compatible rather than the set, so
  a control variable narrower than the base type is legal — and this is where
  the rule bites, at the store, through the check every other store makes. }
program trap_setiter(output);
var c: 'a'..'e'; cs: set of char;
begin
  cs := ['a', 'z'];
  for c in cs do writeln(c)
end.
