{ ADR-0125 costs the lexis nothing, for the third time and by a third route.
  §6.4.3.2 spells an array-type `'array' '[' index-type ... ']' 'of'
  component-type`, so `array of T` -- with no brackets -- is a syntax error in
  ISO 7185 and in ISO/IEC 10206:1991 alike, and no program that compiled stops
  compiling.

  §6.7.3.1 is what actually reports it: a parameter-form is a type-name, a
  schema-name or a type-inquiry, and `array` begins none of the three. The
  reference front end says the same words for the same reason, so this file is
  *compared* by difftest rather than skipped -- where ADR-0121's `external`
  needed six lines in src/ because its spelling is a perfectly good
  identifier. }
program slice_refused(output);

procedure Total(protected var s: array of real);
begin
end;

begin
end.
