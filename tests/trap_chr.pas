program TrapChr(output);
{ ISO 7185 6.6.6.4: chr(i) is an error unless i is a character ordinal. }
var i: integer;
begin
  writeln('before');
  i := 300;
  writeln(chr(i));
  writeln('unreachable')
end.
