{ --dump-sema, which walks the same tree with annotation on.

  The frame layouts, the type of every expression and the slot every name
  resolved to are what this flag adds over --dump-ast -- so this program is
  deliberately about *resolution*: a nested procedure reaching an enclosing
  local, which is what makes a static link and a frame index visible. }
program frames(output);
var outer: integer;

procedure p(k: integer);
var local: integer;

  procedure q;
  begin
    local := outer + k
  end;

begin
  local := 0;
  q;
  writeln(local : 1)
end;

begin
  outer := 4;
  p(2)
end.
