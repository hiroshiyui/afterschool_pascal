{ A range of case constants under ISO 7185, where a label list holds single
  constants only. Reading `..` as the end of the label fails somewhere
  unhelpful, so the parser says what it actually is. }
program p(output);
var i: integer;
begin
  case i of
    1..5: i := 1;
    6: i := 2
  end
end.
