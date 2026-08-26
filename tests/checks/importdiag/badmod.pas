{ A module that does not translate on its own. The error is in the
  implementation of Thing, at a line number `client.pas` does not have -- which
  is what makes the misattribution visible rather than merely wrong. }
module BadMod;

export BadMod = (Thing);

procedure Thing;

end;

procedure Thing;
var q: integer;
begin
  q := 'not an integer'
end;

end.
