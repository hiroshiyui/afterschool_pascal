{ A module a program imports and never names anything of.

  It exists for one case: 6.2.3.6 activates every module that supplies the
  main-program-block, whether or not the importing component reaches any of its
  entities. Until the fix that landed with this file, the only thing that
  registered an imported module for declaration was the path that names its
  activation record -- which runs when something of the module's is *accessed*.
  A module imported and not used was therefore called and never declared, and
  the emitted IR referred to a symbol it had not mentioned. The assembler
  rejected the module and the program did not build at all.

  Both parts here write, so the golden says the activation happened rather than
  merely that the program linked. `x` is exported to give the interface
  something to carry; the importing case does not use it, which is the point. }
module silent;

export silence = (x);

import StandardOutput;

const
  x = 7;

{ 6.11.1: the module-heading ends here; what follows is the module-block, which
  declares nothing of its own and is only the two activation parts. }
end;

to begin do
  writeln('silent: commenced');

to end do
  writeln('silent: finalized');

end.
