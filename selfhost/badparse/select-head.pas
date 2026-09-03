{ AP 6.9.3.15: an arm's head begins with the operation's identifier -- and the
  first arm cannot report it, `select` being told from a program's own name by
  the identifier after it, so this is a *second* arm. }
program selecthead(output);
type ints = channel [2] of integer;
var c: ints; n: integer;
begin
  select
    receive(c, n): writeln(n);
    3: writeln(n)
  end
end.
