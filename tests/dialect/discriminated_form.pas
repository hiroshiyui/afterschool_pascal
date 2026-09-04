{ AP 6.7.3.1.1 and 6.7.2.1: a discriminated-schema where ISO/IEC 10206:1991
  requires a name.

  §6.7.3.1 gives `parameter-form = type-name | schema-name | type-inquiry` and
  §6.7.2 gives `result-type = type-name`, so `procedure q(x: string(5))` and
  `function f: string(5)` are outside that standard's grammar. This processor
  has accepted both since the fixed-capacity string formal existed; ADR-0171
  found it and left it as an extension admitted inside a conformance mode, and
  ADR-0232 removed the modes, so ADR-0324 is the clause that was left to write.

  What the addition denotes is a **type** -- the one the schema and that tuple
  produce -- so every rule stated over types answers here without being told
  about the spelling. `tests/spec/features/dialect_discriminated_form.feature`
  takes the four positions and the refusals; this takes the three the clause
  reaches that a scenario does not: a section of two names, a procedural
  parameter's own heading, and a user schema in a result-type.

  The type-name spelling is still available and means the same thing, which is
  the whole claim: `Cap5` and `string(5)` below are one type, and a var
  parameter written either way takes a variable declared the other. }
program discriminated_form(output);

type
  Cap5 = string(5);
  Box(n: integer) = record a: array [1..n] of integer end;

var
  s: Cap5; t: string(5); b: Box(3);

{ One formal-parameter-section, two names -- §6.7.3.1's identifier-list, and
  the parameter-form is written once for both. }
procedure Pair(x, y: string(5));
begin
  writeln('pair ', x.capacity:1, ' [', x, '][', y, ']')
end;

{ A var parameter of the discriminated form, given a variable declared with
  the type-name. §6.7.3.3 requires the actual to possess the formal's type,
  and it does: one schema and one tuple is one type however it is written. }
procedure Fill(var x: string(5); c: char);
begin
  x := c + c
end;

{ The form inside a procedural parameter's own heading, which is where
  §6.7.3.6's congruity compares two parameter-forms. `Fill` is congruous to
  this because both denote the type `string(5)` produces. }
procedure Apply(procedure f(var z: Cap5; c: char); c: char);
begin
  Fill(t, c);
  f(s, c)
end;

{ 6.7.2.1, with a schema that is not `string`. }
function Made(v: integer): Box(3);
var r: Box(3);
begin
  r.a[1] := v; r.a[2] := v * 2; r.a[3] := v * 3;
  Made := r
end;

function Widest: string(5);
begin
  Widest := 'abcde'
end;

begin
  Pair('a', 'bc');
  Apply(Fill, 'z');
  writeln('fill [', s, '][', t, ']');
  b := Made(2);
  writeln('made ', b.a[1]:1, b.a[2]:1, b.a[3]:1);
  writeln('result ', Widest.capacity:1, ' [', Widest, ']')
end.
