{ ISO 7185 §6.4.4: `domain-type = type-identifier`. §6.2.2.9's only exception
  lets that identifier be defined later in the *same* type-definition-part, so
  a domain naming a type nothing ever defines has no exception to stand on.

  ADR-0019 records the pending domain when the name is not yet known, and
  ResolvePendingPointers has always had this diagnostic -- it was simply never
  reached for a domain written outside a type-definition-part, because the
  drain fired only when a run of type definitions ended. A program with no
  type part at all therefore kept its unknown domain in silence, and one whose
  var part was followed by an unrelated procedure with a type part reported it
  there, against the wrong block.

  tests/extended/schema_selfpointer_var.pas is the other half: the same leak
  refused a *legal* program until an unrelated type definition was added. }
program PointerDomainMissing(output);
var p : ^rekord;
begin
  p := nil
end.
