{ `><` is ISO/IEC 10206:1991's, and the lexer is what decides. Under ISO 7185
  the two characters can only be `>` followed by `<`, which no expression
  admits — so joining them there would turn one clear diagnostic into a
  cascade, and not joining them gives exactly this one. }
program RequiredIsoSymdiff(output);
type digits = set of 0..9;
var a, b: digits;
begin
  a := [1];
  b := [2];
  a := a >< b;
  writeln(1)
end.
