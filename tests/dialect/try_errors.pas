{ AP 6.8.9's five refusals. Two are about the operand, two about the block the
  try stands in, and one is the assignment the construct makes -- reported by
  the routine that reports it for `f := e` and for `exit(e)`, because there is
  one decision and not three (ADR-0178). }
program try_errors(output);

type
  Reason = (tooLong, notDigits);
  Number = integer ! Reason;
  Colour = (red, green);

var g: integer;

function ok(n: integer): Number;
begin ok := n end;

{ a) a cause has to be left somewhere, and only a function has a somewhere.
     The main-program-block and a module-block answer the same way. }
procedure noResult;
var k: integer;
begin
  k := try(ok(1))
end;

{ b) an operand that is not fallible has no cause to propagate and no value to
     yield, so there is nothing for the construct to mean. }
function notFallible: Number;
var k: integer;
begin
  k := try(g);
  notFallible := k
end;

{ c) one operand, because one cause is what leaves. }
function tooMany: Number;
var k: integer;
begin
  k := try(ok(1), ok(2));
  tooMany := k
end;

{ d) the cause is assignment-compatible with nothing this result can hold.
     Not a rule of its own: the try makes an assignment to the result, and
     this is what any unassignable result is told. }
function wrongResult: Colour;
var k: integer;
begin
  k := try(ok(1));
  wrongResult := red
end;

{ e) 6.9.3.11.3 reaches this construct too, for the exit-statement's reason:
     a deferred statement is emitted in the block's runner as well, and the
     runner is not the activation a try would leave. Asked of a count of
     enclosing defer-statements rather than by the walk that asks it of the
     exit-statement, because that walk sees statements and this is an
     expression. }
function deferred: Number;
var k: integer;
begin
  defer k := try(ok(1));
  deferred := 0
end;

begin
  g := 1;
  noResult;
  writeln(notFallible.val:1, tooMany.val:1, ord(wrongResult):1, deferred.val:1)
end.
