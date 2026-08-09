program Arith(output);

const
  Ten = 10;

var
  a, b: integer;
  x: real;
  c: char;
  ok: boolean;

begin
  a := Ten * 4 + 2;
  b := a div 5;
  writeln(a);          { 42 }
  writeln(b);          { 8 }
  writeln(a mod 5);    { 2 }
  writeln(-7 mod 3);   { -1: a leading sign applies to the whole term }
  writeln((-7) mod 3); { 2: ISO mod always yields a non-negative result }
  writeln(a / 4:8:3);  { real division }

  x := 1;
  x := x / 3;
  writeln(x:10:6);

  c := 'P';
  writeln(c);
  writeln(ord(c));
  writeln(chr(ord(c) + 1));

  ok := (a > b) and (b > 0);
  writeln(ok);
  writeln(not ok);
  writeln(a:6, b:6);
  writeln(maxint)
end.
