{ AP 6.4.14.7 through a qualified name (§6.11.3).

  `tests/dialect/owned_borrow_errors.pas` asks the rule of variables the
  program declares; this asks it of one a module holds, which is the only way
  the walk to the entire-variable ends at a field-designator carrying a
  qualifier rather than at a name. The rule is about the variable and not
  about how it is spelled, so the answer must be the same. }
program owned_borrow_qualified(output);

import OwnedHeld;

begin
  new(OwnedHeld.Held);
  with OwnedHeld.Held^ do
    dispose(OwnedHeld.Held)
end.
