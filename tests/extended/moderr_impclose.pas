{ 6.11.3's import-specification takes a bracketed import-list, so its ')' has
  a context of its own. }
module m(output);
export mi = (v);
var v: integer;
end;
end.

program p(output);
import mi (v;
begin end.
