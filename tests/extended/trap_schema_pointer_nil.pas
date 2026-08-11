{ ISO 7185 §6.6.5.3 makes disposing nil an error, and until a schema domain
  existed it was a harmless one: freeing nil does nothing. A variable created
  from a schema is preceded by its tuple, so `dispose` has to step back over
  the header first — and stepping back from nil would free an address that was
  never allocated. The check is here because the hazard is, not because
  `dispose` grew stricter everywhere. }
program TrapSchemaPointerNil(output);
type vector(n: integer) = array [1..n] of integer;
var p: ^vector;
begin
  new(p, 2);
  writeln('vector(', p^.n:1, ') exists');
  dispose(p);
  writeln('disposed once');
  dispose(p)
end.
