{ ISO 7185 §6.4.3.3: "The values denoted by all case-constants of a type that
  is required to be compatible with a given tag-type shall be distinct and the
  set thereof shall be equal to the set of values specified by the tag-type."

  One sentence, and it fails in two directions -- a case-constant that is not a
  value of the tag-type, and a value of the tag-type that no case-constant
  names. Distinctness was already checked; neither half of the equality was.

  ISO/IEC 10206:1991 §6.4.3.4 splits the sentence, and the split is exactly
  where the variant-part-completer goes: "the value denoted by each such
  case-constant shall be a member of the set of values determined by that type"
  is unconditional, while "each value possessed by the variant-type shall
  correspond to one and only one variant" is what an `otherwise` arm
  discharges. So a completer excuses the second and never the first -- it
  claims the values nothing names, not values the tag-type does not have.
  tests/extended/variant_otherwise.pas is the half where the completer makes a
  variant part complete. }
program VariantComplete(output);
type
  digit  = 0..3;
  colour = (pink, red, green, blue);

  { a case-constant outside the tag-type }
  toomany = record
    case c: digit of
      0: (a: integer);
      1: (b: integer);
      2: (d: integer);
      3: (e: integer);
      4: (f: integer)
  end;

  { and a value of the tag-type that nothing names }
  toofew = record
    case c: colour of
      pink: (p: integer);
      red:  (r: integer);
      blue: (b: integer)
  end;

var
  x: toomany;
  y: toofew;
begin
  x.c := 0;
  y.c := pink
end.
