{ 6.8.7's structured-value-constructor, and three complaints it can make that
  no other program in this corpus had written.

  6.8.7.2: a component-value has to be assignment-compatible with the
  component -- an array of integer takes no char.

  6.8.7.3: "A tag-field-identifier in a variant-part-value shall be the
  field-identifier associated with the selector." A *tagless* variant part has
  no such identifier, so naming one is an error rather than a redundancy --
  6.4.3.4 making the tag-field optional is exactly what creates the case.

  6.8.7.3 again: a record-value's elements are named by field-identifiers, so
  a selector that is not a name has nothing to select. The message says what
  is missing rather than what was found, because what was found is anything at
  all. }
program StructValueVariantErrors(output);
type
  sel     = 1..2;
  tagless = record x: integer; case sel of 1: (a: integer); 2: (d: char) end;
  v       = array [1..2] of integer;
  rr      = record f, g: integer end;
var
  t1: tagless;
  z:  v;
  w:  rr;
begin
  z  := v[1: 'x'; 2: 2];
  t1 := tagless[x: 1; case tg: 1 of [a: 1]];
  w  := rr[1: 2; g: 3];
  writeln(z[2], t1.x, w.g)
end.
