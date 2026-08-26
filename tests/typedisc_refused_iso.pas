{ Annex B of doc/afterschool-pascal-spec.md: AP 6.4.7's type-valued
  discriminant is spelled with the word-symbol `type` standing where 6.4.7
  requires an ordinal-type-name -- a position no conforming program can have
  written, since `type` is reserved in both standards and a type-identifier
  is not (ADR-0140, ADR-0209). So both conformance modes stop in the parser,
  where the type of a discriminant was meant to be. }
program typedisc_refused_iso(output);
type Vec(T: type) = record a: array [1..4] of T end;
var v: Vec(integer);
begin
  v.a[1] := 0
end.
