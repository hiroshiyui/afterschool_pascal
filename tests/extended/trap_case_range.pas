{ A case whose ranges cover nothing matching still traps: Extended Pascal
  changed what the switch tests, not what its default does. Without an
  otherwise-part the default is ISO 7185's error condition (ADR-0018), and a
  range reaches it the same way a single constant does. }
program TrapCaseRange(output);
var i: integer;
begin
  i := 500;
  writeln('before');
  case i of
    1..9: writeln('small');
    10..99: writeln('medium')
  end;
  writeln('unreachable')
end.
