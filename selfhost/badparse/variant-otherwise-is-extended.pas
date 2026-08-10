{ The variant-part-completer under ISO 7185, where `otherwise` is an ordinary
  identifier. It is told from a variant labelled with a constant of that name
  by what follows: '(' rather than ':' or ','. }
program p(output);
type
  r = record
    case tag: integer of
      1: (a: integer);
      otherwise (b: char)
  end;
var v: r;
begin
  v.tag := 1
end.
