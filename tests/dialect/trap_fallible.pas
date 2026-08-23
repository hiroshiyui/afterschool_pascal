{ AP 6.4.13 with ADR-0118: the tag is what says which outcome was written, so
  reading the other arm stops the program. This is the property the type
  exists for, and it is the same trap tests/dialect/trap_result_unchecked.pas
  pins for the record a module writes by hand -- what changed is that the
  language writes the record now (ADR-0176).

  Not a diagnostic and it could not be: nothing is wrong with this source, and
  whether the read is legal depends on what the function answered. }
program TrapFallible(output);

type
  Code = (none_, syntax);
  IntResult = integer ! Code;

var r: IntResult;

function Parse(s: string(16)): IntResult;
begin
  if s = '1' then Parse := 1 else Parse := syntax
end;

begin
  r := Parse('not a number');
  writeln('the tag says: ', r.ok);
  writeln('the cause is readable: ', ord(r.cause):1);
  writeln('about to read val on a failed result:');
  writeln('val = ', r.val:1)
end.
