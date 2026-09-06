{ A map keyed at a type with no implementation of Key is refused where the
  map type is produced -- AP 6.4.7.2, ADR-0355 -- and refused *there*, not at
  the first MapPut: the bound is on the schema's discriminant, so the client
  writes the type down once and the check happens once.

  And it is refused in one line. The domain a failed binding leaves is the
  placeholder every error path here leaves, and until ADR-0356 each generic
  body instantiated against it reported a fault of its own, located in the
  library -- seven lines for this one MapInit. The type now carries the
  refusal and no body is checked against it; the golden claims one line. }
program LibContainerBadKey(output);
import PasContainer;
type
  WordText = string(20);
  WordMap = ^Map(WordText, integer);   { 15:18 -- no impl Key for WordText }
var
  m: WordMap;
begin
  MapInit(WordMap, m, 8)
end.
