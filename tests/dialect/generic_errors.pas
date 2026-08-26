{ AP 6.7.3.5's refusals. Sema accumulates, so every one of these is reported
  in a single run (ADR-0024). }
program generic_errors(output);

type Point = record x, y: integer end;

procedure P(T: type; var a: T);
begin a := a end;

function F(T: type; x: T): integer;
begin F := 1 end;

var i: integer; pt: Point;
begin
  { An actual in a type parameter's position must name a type. A variable of
    the right type is still not a type. }
  P(i, i);

  { Nor is an expression, and nor is a constant. }
  P(1 + 1, i);

  { The argument list ends before the type parameter is given anything. }
  P;

  { The type is given and the value is not: an ordinary argument-count error,
    reported against the instantiation, which has one formal and not two. }
  P(integer);

  { And the value must match the type the call chose, not some other
    instantiation's. }
  P(integer, pt);

  i := F(Point, i)
end.
