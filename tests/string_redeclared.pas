{ The other half of that: under ISO 7185 `string`, `length`, `trim` and the
  rest are ordinary identifiers, so a program may declare them — and this one
  does. It is the evidence that the feature reserves nothing, the same evidence
  `tests/complex_redeclared.pas` carries for the complex type. }
program StringRedeclared(output);
type string = packed array [1..3] of char;
var s: string;
function length(v: string): integer;
begin
  length := 3
end;
begin
  s := 'abc';
  writeln(s, ' ', length(s):1)
end.
