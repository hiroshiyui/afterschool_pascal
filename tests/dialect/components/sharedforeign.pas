{ A module that binds a C function *privately* and exports a generic whose
  body calls it. Both halves of ADR-0263 need it: a client that binds the same
  symbol under a name of its own, and a client whose instantiation of `Doubled`
  brings this module's declaration into the client's own module. }
module SharedForeign;

export SharedForeign = (Doubled);

{ Translated in whichever component names the types (AP 6.7.3.10.2,
  ADR-0212), so the call to `strlen` below is emitted *there* and the client's
  module carries a `declare` for it. }
function Doubled(T: type; x: T): integer;

end;

{ Not exported, and not reachable by a client -- which is the point. Until
  ADR-0263 a client could not bind `strlen` at all, because this heading had
  already claimed it for the whole compilation and the diagnostic named
  `extstrlen`, a routine the client cannot see and did not write. }
function ExtStrlen(s: string): csize; external 'strlen';

function Doubled;
{ `csize` is `int64` on an LP64 target and `integer` on i386 (AP 6.4.2.7), so
  the narrowing is written in two steps: widen to `int64`, which is the
  identity on the first and §6.4.6 c)'s widening on the second, then narrow
  with `trunc`. Writing `trunc` on the result directly is one line and is
  refused wherever `csize` is already `integer` (ADR-0328). }
var n: int64;
begin
  n := ExtStrlen('ab');
  Doubled := trunc(n) * 2
end;

end.
