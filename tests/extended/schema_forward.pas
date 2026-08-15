{ 6.2.2.9: a defining-point shall precede all applied occurrences of that
  identifier, with two exceptions -- the domain-type of a new-pointer-type,
  and an export-list. A record-section of a schema's body is neither, so a
  schema body may not name a schema defined after it.

  The body is resolved when a type is first *produced* from the schema, by
  which time the later definition exists, so nothing noticed. ADR-0107. }
program schema_forward(output);
type
  outer(n: integer) = record f: inner(n) end;
  inner(m: integer) = array [1..m] of integer;
var v: outer(2);
begin
  v.f[1] := 9;
  writeln(v.f[1]:1)
end.
