{ A module in a directory named in Japanese, which is the shape that makes a
  *short* path into a *long* URI: every byte outside RFC 3986's unreserved set
  is percent-escaped, so 81 bytes of directory name become 243 characters of
  URI (ADR-0291).

  It is written this way rather than as a directory named at length because
  the two bounds are separate. `PathToUri` was the one that cut a URI at 255
  in silence, and reaching it needs the *URI* to be long; the path itself
  crosses `PasStrVec.ItemMax`, which is 255 for a different and still-good
  reason -- 40 821 dump lines whose longest is 62 characters. Keeping the path
  at 153 bytes tests the one without waiting on the other.

  This module only has to declare something worth going to. }
module Deep;

export Deep = (DeepAnswer);

function DeepAnswer: integer;

end;

function DeepAnswer;
begin
  DeepAnswer := 7
end;

end.
