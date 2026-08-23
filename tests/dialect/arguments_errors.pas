{ AP 6.7.6.10's two arities, the one type, and a bare argcount on the left
  of an assignment -- a call, not a variable, whatever the parser thought.
  Sema accumulates, so the four are one file. }
program arguments_errors(output);
var s: string(8); n: integer;
begin
  n := argcount(1);
  s := argument;
  s := argument(1, 2);
  s := argument('one');
  argcount := 3;
  writeln(n, s)
end.
