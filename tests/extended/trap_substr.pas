{ §6.7.6.7's `substr` carries three error conditions: "It shall be an error if
  the value of i is less than or equal to 0. It shall be an error if the value
  of j is less than 0. It shall be an error if the value of (i)+(j)-1 is
  greater than the length of the value of s."

  The third is the one a program meets by accident, and the length it is
  measured against is the *value's* — so a `string(20)` holding three
  characters has three, not twenty. }
program TrapSubstr(output);
var s: string(20);
begin
  s := 'abc';
  { j = 0 is legal and yields the null-string, and i = length+1 with j = 0 is
    the empty tail — both are inside the rule }
  writeln('[', substr(s, 1, 3), '][', substr(s, 2, 0), '][', substr(s, 4), ']');
  { ...and one character past the end is not }
  writeln('[', substr(s, 2, 3), ']');
  writeln('not reached')
end.
