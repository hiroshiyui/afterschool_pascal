{ The document a person opens. It names no component and never could: the
  module it imports is resolved by ADR-0244's search, from the directory the
  `.importpath` sidecar beside this file names. Without that sidecar reaching
  the compiler, every line below is a diagnostic about a name that is there. }
program asks(output);
import Greeting;
begin
  writeln(Answer:1)
end.
