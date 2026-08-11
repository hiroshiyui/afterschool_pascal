{ A schema may produce a `packed array [1..n] of char`, which is a string type
  — and a string type has operators and a `write` of its own. Both read a
  *length*, and until this test existed both read it from Type::length(), which
  is `hi - lo + 1` on bounds that are discriminants rather than numbers. That
  is arithmetic on placeholders: a number, and so not visibly wrong. Every
  comparison here answered `true` and every write printed nothing. }
program SchemaString(output);
type str(n: integer) = packed array [1..n] of char;

var short: str(3);
    long: str(5);

procedure show(var s: str);
begin
  writeln('[', s, '] length ', s.n:1)
end;

{ Two sections, so the two may have different lengths — one section is one
  parameter-form and §6.7.3.3 requires one tuple across it. }
procedure order(var x: str; var y: str);
begin
  if x = y then writeln('=')
  else if x < y then writeln('<')
  else writeln('>')
end;

{ One length is a discriminant and the other is written in the program. This
  is the only shape that distinguishes "Sema cannot compare the lengths" from
  "Sema compares them and they happen to agree": two schematic strings both
  measure `hi - lo + 1` on placeholders, which is 0 for both, so a version that
  kept the compile-time test passes them and rejects only this. }
procedure against(var s: str);
begin
  if s = 'abc' then writeln('is abc') else writeln('not abc')
end;

{ A length computed on entry (§6.2.3.2), written and compared against a
  literal of the same length. }
procedure entry(m: integer);
var s: str(3);
begin
  s := 'abc';
  write('entry ', m:1, ': ');
  show(s)
end;

var a, b: str(3);

begin
  short := 'abc';
  long := 'abcde';
  show(short);
  show(long);

  a := 'abc';
  b := 'abd';
  order(a, b);
  order(b, a);
  order(a, a);

  against(a);
  against(b);

  { A width applies to a string the same way it does to any other written
    value, and the length it pads to is the one just computed. }
  writeln('[', short:6, ']');
  writeln('[', short:1, ']');

  entry(1)
end.
