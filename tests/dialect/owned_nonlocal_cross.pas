{ AP 6.4.14.9 (ADR-0319) across a program-component boundary. The owner is a
  variable of the imported module's outermost block and the callee is that
  module's own routine, so it can name the owner -- and this compilation cannot
  see its body. That is why the clause asks about the *declaration* and not
  about what the routine does: a summary of what an imported routine releases
  is what §6.13.2's module-heading has no room to carry (ADR-0317). }
program owned_nonlocal_cross(output);

import ownkeeper;

begin
  Wipe(Held^)
end.
