{ What a discriminant that is not a constant still refuses. §6.2.3.8 b) puts
  every actual-discriminant-part "closest-contained by ... the block" in that
  block's commencement, so a variable's may be one (§6.2.3.2, ADR-0113) and so
  may a type-definition's (ADR-0127). What is refused is every position the
  clause does *not* reach -- a schema body, an array's component, a record's
  field -- because the type produced there is not sized by this activation. }
program SchemaDynamicErrors(output);
type
  vector(n: integer) = array [1..n] of integer;
  boxed(n: integer) = record a: array [1..n] of char; b: integer end;
  { a schema body is resolved when a type is produced from it, which happens in
    the variable declaration that produces it -- but the type it produces is
    the program's and not that variable's, so a discriminant written *inside*
    the body is a constant even there }
  nested(m: integer) = array [1..m] of vector(k);
var
  k: integer;
  r: real;
  { a discriminant is evaluated on entry, and an ordinal is what a bound can
    be made of }
  bad: vector(r);
  { the variable's own name is in scope by the time its type is written, and
    it is exactly the thing that does not exist yet }
  self: vector(self);
  { §6.4.7's rule about where a discriminant may reach is the same one a
    parameter form is under: a record may hold a dynamically-bounded array
    last, and this one holds a field after it (ADR-0045) }
  box: boxed(k);
  { the body above, so that it is produced from }
  deep: nested(2);
  { a component is not a variable: the array's own element type is fixed when
    the array type is, and a dynamic one would have no stride }
  many: array [1..3] of vector(k);
  { and neither is a field }
  rec: record inner: vector(k) end;

{ a type-definition *is* closest-contained by the block, so `type later =
  vector(k)` is legal here now (ADR-0127) and tests/extended/dynbounds_type.pas
  is where it runs. What is left in this file is the rule that outlives it: a
  discriminant is an *ordinal* expression however it is evaluated, and a real
  is not one }
procedure defined;
type later = vector(r);
var v: later;
begin
  { the body says nothing about v: a variable whose type was refused has a
    placeholder, and using it would report the placeholder rather than the
    mistake }
  k := 2
end;

begin
  k := 1;
  r := 1.0;
  defined
end.
