{ ISO/IEC 10206:1991 §6.8.7.4's error condition, which is the one thing a
  set-value can check that a bare set-constructor cannot.

  "The value of the set-constructor of a set-value shall be
  assignment-compatible with the type of the set-value." A constructor written
  as `[i]` does not know what it will be assigned to, so a member outside the
  destination's base type can only be caught at the store (ADR-0028). A
  set-value *names* its type, so the check belongs to the constructor — and
  fires here with no assignment anywhere in the statement. }
program trap_setvalue(output);
type digits = set of 0..9;
var i: integer;
begin
  i := 20;
  writeln('before');
  writeln(5 in digits[i])
end.
