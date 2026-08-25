{ AP Annex B: `utf8` is a required *schema* identifier of the dialect
  (AP 6.4.15.1, ADR-0189), which 6.2.2.10 puts in a scope enclosing the
  program -- so under a conformance mode it is simply not there and a program
  using it is using an undeclared name.

  ADR-0140's second shape, exactly as `int64` is: no word-symbol is reserved,
  no diagnostic mentions the dialect, and a conforming program may declare its
  own `utf8` and keep it. tests/dialect/inherits_extended.pas is where that is
  witnessed for a program that does.

  Written as a schema application rather than a bare name because that is how
  a program uses it, and because the parser reaching the discriminant is part
  of what the refusal has to survive. }
program utf8_refused_iso(output);
var t: utf8(16);
begin
end.
