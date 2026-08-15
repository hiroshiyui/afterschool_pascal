{ 6.4.7: "Except for applied occurrences in the domain-type of a new-pointer-
  type, the schema-definition shall not contain an applied occurrence of that
  identifier." That is a rule about the *definition*, so it does not wait for
  a type to be produced -- this schema is never used and is still illegal.

  The check ran at production only, so an unused one was accepted. ADR-0107. }
program schema_selfref_unused(output);
type s(n: integer) = record f: array [1..n] of s(1) end;
begin
  writeln('compiled')
end.
