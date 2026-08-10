{ `otherwise` under ISO 7185, where it is an ordinary identifier and not a
  word-symbol. Reading it as a case label fails somewhere unhelpful, so the
  parser says what it actually is. }
program p(output);
var i: integer;
begin
  case i of
    1: i := 1;
    otherwise i := 2
  end
end.
