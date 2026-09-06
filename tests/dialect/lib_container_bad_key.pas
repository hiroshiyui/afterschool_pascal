{ A map keyed at a type with no implementation of Key is refused where the
  map type is produced -- AP 6.4.7.2, ADR-0355 -- and refused *there*, not at
  the first MapPut: the bound is on the schema's discriminant, so the client
  writes the type down once and the check happens once.

  What follows the first line of the golden is not a claim but a record: the
  domain a failed binding leaves is the placeholder every error path here
  leaves, and each generic body instantiated against it then reports a fault
  of its own, located in the library. doc/sop.md section 7 carries the row;
  a fix that silences the cascade changes this golden and should. }
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
