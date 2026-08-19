{ ADR-0123: reading an optional that has no value stops the program.

  It is spelled `^` and it traps, which is the same shape 6.4.4's pointer
  already has (ADR-0019) -- a value that may not be there, and a check at the
  moment it is asked for. What the *type* adds is that nothing else can be
  absent, so this is the only place the check is needed. }
program optional_absent(output);

type OptInt = ?integer;
var i: OptInt;

begin
  i := 7;
  writeln('present = ', i^:1);
  i := nil;
  { Reading through it on the left of an assignment is the same question, and
    is checked in the same place: EmitAddress is where `^` is lowered, and an
    assignment target goes through it too. }
  writeln('about to read an absent optional:');
  i^ := 1;
  writeln('not reached')
end.
