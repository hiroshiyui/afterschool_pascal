{ A schema's body may be any new-type, and 6.2.2.9's ordering is asked of the
  names inside whichever one it is -- so the walk that asks has to descend
  through a set's base type, a file's component and index, and a variant
  part's arms, not only through an array's element and a record's fields.

  Each body below names a type declared before it, which is what the rule
  requires; the point of the case is that the walk reaches them at all.
  ADR-0107. }
program schema_body_shapes(output);
type
  colour = (red, green, blue);
  small = 1 .. 9;
  bag(n: small) = set of colour;
  log(n: small) = file of small;
  seek(n: small) = file [small] of colour;
  { 6.4.2.5's restricted-type names its underlying type rather than
    holding a denoter, so the name to ask about is its own. }
  guard(n: small) = restricted colour;
  tagged(n: small) = record
    case k: colour of
      red: (r: small);
      green: (g: colour);
      blue: (b: small)
  end;
var
  b: bag(1);
  g: guard(1);
  t: tagged(1);
begin
  b := [red, blue];
  g := blue;
  t.k := green;
  t.g := blue;
  writeln(red in b, ' ', green in b, ' ', ord(t.g):1)
end.
