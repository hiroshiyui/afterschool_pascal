{ Reads through the callback the module hands it. Under the dialect the read is
  guarded -- and the guard *passing* is exactly the failure, because the module
  was translated without the write rule that keeps the tag honest. }
program CallbackUser(output);
import TagBase; Callback;
procedure Q(var t: Tagged);
begin
  writeln('i = ', t.i:1)
end;
begin
  ApplyR(Q)
end.
