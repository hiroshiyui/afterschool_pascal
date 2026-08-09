program Builtins(output);

var
  i: integer;
  x: real;

begin
  i := -5;
  writeln(abs(i), ' ', sqr(i));
  writeln(odd(i), ' ', odd(4));
  writeln(succ(i), ' ', pred(i));

  x := 2.0;
  writeln(sqrt(x):12:8);
  writeln(exp(ln(x)):12:8);
  writeln(trunc(2.75), ' ', round(2.75), ' ', round(-2.75));
  writeln(abs(-1.5):6:2);
  writeln(1.0E2:12:4);
  writeln(0.5)
end.
