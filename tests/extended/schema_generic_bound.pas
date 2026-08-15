{ ISO/IEC 10206:1991 §6.4.7's schema is resolved twice over its life, and this
  message belongs to the second way.

  With a tuple — `vector(3)` — the discriminants are bound as ordinary
  constants and the body is resolved as any denoter is (ADR-0039). For a
  *schematic formal parameter* there is no tuple: one compiled body serves
  every length, so the body is resolved generically with the discriminants
  bound to symbols that will be read at run time (ADR-0040). A bound inside it
  is then restricted to what a descriptor can carry — an ordinal constant, or
  one of the schema's own discriminants — and a variable is neither.

  `g` is a variable of the enclosing block, which the ordinary rules would
  admit anywhere a value is wanted. It is refused here because the type has to
  mean the same thing for every actual parameter, and `g` does not. }
program SchemaGenericBound(output);
type
  s(n: integer) = record
                    a: array [1..n] of integer;
                    b: 1..g
                  end;
var
  g: integer;

{ The body is empty on purpose: a parameter whose type could not be produced
  makes every use of it a second complaint, and what this file is pinning is
  the first one. }
procedure takesAny(var x: s);
begin
end;

begin
end.
