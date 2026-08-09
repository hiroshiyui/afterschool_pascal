program TrapCase(output);

{ ISO 7185 §6.8.3.5 has no `else` arm: if the selector matches no label the
  program is in error. It stops rather than falling through the statement, so
  a case that has quietly stopped covering its type is found rather than
  silently skipped. }

var
  i: integer;

function Value(n: integer): integer;
begin
  Value := n * 2
end;

begin
  for i := 1 to 3 do
    case Value(i) of
      2: writeln('two');
      4: writeln('four');
      6: writeln('six')
    end;

  writeln('now a value no arm lists');
  case Value(4) of
    2: writeln('two');
    4: writeln('four');
    6: writeln('six')
  end;
  writeln('unreachable')
end.
