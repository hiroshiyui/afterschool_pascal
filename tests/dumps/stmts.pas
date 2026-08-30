{ ADR-0258: `--dump-stmts` writes where every statement begins and ends.

  One of each kind the parser builds, so the word for every arm is written
  down somewhere a reader can check it. The order is *completion* order --
  innermost first -- because the line is written where the parser finishes a
  statement, which is the one moment anything knows one is finished. }
program stmts(output);
label 9;
var i: integer; r: record a: integer end;
procedure p(x: integer);
begin
  x := x
end;
begin
  i := 0;
  p(1);
  if i = 0 then
    i := 1
  else
    ;
  while i < 3 do
    i := i + 1;
  repeat
    i := i - 1
  until i = 0;
  for i := 1 to 2 do
    write(i:1);
  with r do
    a := i;
  case i of
    0: writeln('zero');
    1: ;
    otherwise writeln('other')
  end;
  defer i := 9;
  read(i);
  goto 9;
9:
  writeln(i:1)
end.
