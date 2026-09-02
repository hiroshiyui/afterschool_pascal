{ The client of the module beside it. Opening this file and asking where
  `DeepAnswer` is declared makes the server hold one URI it was sent and build
  a second one itself, both longer than the 255 characters it used to hold
  (ADR-0291). }
program deepclient(output);

import Deep;

begin
  writeln(DeepAnswer)
end.
