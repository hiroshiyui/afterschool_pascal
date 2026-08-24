{ AP 6.8.9's try in the dumps, which is where its husk is visible at all.

  A try is three things Sema wrote and the program did not -- the tag to test,
  the assignment to make where it is false, and the value to yield where it is
  true -- so --dump-ast shows a call of a required function with one argument
  and --dump-sema shows what that call was decided to mean. The two dumps of
  one `try` therefore do not have the same shape, which is `exit(e)`'s
  situation and for the same reason (ADR-0044, ADR-0178).

  The frame layout is the other half of what this pins: the binding the
  construct evaluates its operand into is a frame slot, named `try$n`, and a
  second try in the same block gets a second one. }
program try_dump(output);
type
  Reason = (bad, worse);
  Number = integer ! Reason;

function twice(n: integer): Number;
begin
  if n < 0 then twice := bad else twice := n * 2
end;

function both(a, b: integer): Number;
begin
  both := try(twice(a)) + try(twice(b))
end;

begin
  writeln(both(1, 2).ok)
end.
