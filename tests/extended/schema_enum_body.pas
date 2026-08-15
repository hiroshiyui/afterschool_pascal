{ 6.4.2.3: "The occurrence of an identifier in the identifier-list of an
  enumerated-type shall constitute its defining-point for the region that is
  the block, module-heading, or module-block closest-containing the
  enumerated-type." The block -- not the production. So an enumerated type
  inside a schema's body declares its constants once, into the block, and
  every type produced from the schema shares them.

  This was refused, on the argument that each production would declare the
  constants again into a scope that dies with it. That is what the clause
  answers: there is one defining-point and it is the block's. ADR-0107. }
program schema_enum_body(output);
type
  t(n: integer) = record
    c: (red, green, blue);
    a: array [1..n] of integer
  end;
var
  two: t(2);
  three: t(3);
  { the constants are the block's, so a variable declared outside the
    schema may possess their type -- and redeclaring them here would be
    the ordinary already-declared error, which is the same fact }
  c: red..blue;
begin
  two.c := green;
  three.c := blue;
  two.a[2] := 20;
  three.a[3] := 30;
  { one defining-point, so one type: a constant written here is the same
    value the schema's field holds }
  writeln(ord(two.c):1, ' ', ord(three.c):1, ' ', ord(red):1);
  writeln(two.a[2]:1, ' ', three.a[3]:1);
  c := red;
  writeln(two.c = green, ' ', three.c > two.c, ' ', ord(c):1)
end.
