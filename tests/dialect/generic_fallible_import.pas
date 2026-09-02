{ AP 6.7.3.10.4's inferred activation, reaching through a named production of
  a schema declared in another module (ADR-0297).

  `generic_fallible.pas` established that one `ValueOr` serves every
  `Fallible(T)`, and ADR-0254 that the type need not be written at the call.
  What neither asked is the shape a library has: the schema in one component,
  the productions named in a second, and a client importing the generic by
  `only` -- so the schema's *name* is not in scope where the call stands.
  ADR-0254 resolved that name at the call and said a generic whose schema the
  caller cannot see infers nothing; this case is the client that shape
  refused, and it compiles because the name is now resolved where the generic
  was declared. }
program generic_fallible_import(output);

import FallMod only (ValueOr);
       FallProd;

var
  none: Short;
  origin: Point;
  p: Point;

begin
  none := 'none';
  origin.x := 0; origin.y := 0;

  { A scalar, a string production and a record, each inferred. }
  writeln(ValueOr(AnInt(true), 0):1, ' ', ValueOr(AnInt(false), -1):1);
  writeln(ValueOr(AShort(true), none), ' ', ValueOr(AShort(false), 'none'));
  p := ValueOr(APoint(true), origin);
  write(p.x:1, ',', p.y:1, ' ');
  p := ValueOr(APoint(false), origin);
  writeln(p.x:1, ',', p.y:1)
end.
