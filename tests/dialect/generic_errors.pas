{ AP 6.7.3.5's refusals. Sema accumulates, so every one of these is reported
  in a single run (ADR-0024). }
program generic_errors(output);

type Point = record x, y: integer end;
     Box = record w, h: integer end;

procedure P(T: type; var a: T);
begin a := a end;

function F(T: type; x: T): integer;
begin F := 1 end;

{ A body that is wrong for the type it was given. AP 6.7.3.10.2 checks the
  body once per tuple, in the source the generic was *written* in, so the
  diagnostic lands on the line below -- and until ADR-0259 nothing said which
  activation asked for that translation. With AP 6.7.3.10.4's inferred form
  the activation names no type at all, so a reader had nothing to work back
  from. }
function Add(T: type; a, b: T): T;
begin Add := a + b end;

var i: integer; pt: Point; b: Box;
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

  i := F(Point, i);

  { Three activations of one generic and **two** attributions, which is
    AP 6.7.3.10.2 working rather than a gap: the body is checked once per
    distinct tuple, so the activation named is the one that *produced* the
    tuple. The second line below repeats the first's tuple, finds the
    instantiation in the cache, and is silent -- there is nothing new to
    report and a second copy of the same two errors would be noise. The third
    names a different type, so it is a different tuple, a different
    translation, and an attribution of its own.

    The third is also the inferred form (AP 6.7.3.10.4), which is the one that
    had nothing at all to point at before: it names no type, so a reader
    working backwards from an error inside the generic had only the generic. }
  pt := Add(Point, pt, pt);
  pt := Add(pt, pt);
  b := Add(b, b)
end.
