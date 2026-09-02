program TrapInModule(output);
import TrapMod;

{ ADR-0293: the trap below happens in components/trapmod.pas, and the message
  says so -- the position is the module's own, not this program's call. }

begin
  writeln(Third(2));
  writeln(Third(5))
end.
