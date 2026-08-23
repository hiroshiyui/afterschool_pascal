{ AP 6.7.6.10: argcount and argument(k), the program's command line as a
  list. Neither standard gives a program its arguments except through §6.12's
  binding of program-parameters, which this compiler reads back through
  binding(p).name (ADR-0081) -- a way that costs one file variable per
  argument and cannot count them without one more. These two are required
  identifiers of the dialect: §6.1.3 makes them shadowable, and a program
  that declares its own `argument` keeps it, which the nested function below
  shows.

  The harness runs every program with two arguments, paths in a directory of
  its own, so what is printed is the count, each argument's length being
  positive, and its last five characters -- never the path. }
program arguments(output);

var k: integer; s: string(255);

procedure shadowed;
  { a program's own declaration takes the spelling, §6.1.3 }
  function argument(k: integer): integer;
  begin argument := k * 10 end;
begin
  writeln('shadowed: ', argument(2):1)
end;

begin
  writeln('argcount = ', argcount:1);
  for k := 1 to argcount do begin
    s := argument(k);
    writeln(k:1, ': length > 0 = ', length(s) > 0, ', ends with ',
            s[length(s) - 4..length(s)])
  end;
  { a value of the canonical-string-type: usable where any string is }
  writeln('joined: ', length(argument(1) + '/' + argument(2)) > 1);
  writeln('equal to itself: ', argument(1) = argument(1));
  shadowed
end.
