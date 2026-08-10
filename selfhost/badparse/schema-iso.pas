{ a schema-definition is an Extended Pascal feature; under ISO 7185 the '('
  after the type name is refused rather than being read as something else }
program p;
type v(n: integer) = array [1..n] of real;
begin end.
