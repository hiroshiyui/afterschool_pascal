{ AP 6.7.5.9's four refusals. Each is a rule about the *result* or about where
  an exit-statement may stand -- there is nothing to refuse about a bare
  `exit`, which every block admits. }
program exit_errors(output);

type rec = record a: integer end;
var v: rec;

{ a) a procedure has no result for a value to go to, and neither has the
     main-program-block or a module }
procedure noResult;
begin
  exit(1)
end;

{ b) the value is assignment-compatible with nothing the result can hold. The
     message is the one `f := e` gives, because it is the same routine
     deciding: an exit with a value *is* an assignment to the result. }
function wrongType: integer;
begin
  wrongType := 0;
  exit(v)
end;

{ c) one result, so at most one argument }
function tooMany: integer;
begin
  tooMany := 0;
  exit(1, 2)
end;

{ d) 6.9.3.11.3's fourth item, and the goto-statement's reason rather than a
     new one: a deferred statement is emitted in the block's runner as well as
     where its sequence completes, and the runner is not the activation an
     exit would terminate. }
procedure deferred;
begin
  defer exit;
  writeln('unreachable')
end;

begin
  noResult;
  writeln(wrongType:1, tooMany:1);
  deferred
end.
