{ ISO 7185 §6.2.2.10: "Required identifiers that denote required values, types,
  procedures, and functions shall be used as if their defining-points have a
  region enclosing the program." So a program may declare its own `integer` or
  its own `ord`, and its declaration wins inside its scope.

  A required *function* already worked, because every lookup for a call
  consulted the scope first and fell back to the builtin only on nil. A
  required *type* did not: a type-denoter asked a name-keyed table before the
  scope, so `type integer = char` was accepted and then ignored -- `var v:
  integer` still meant the built-in type, and nothing said otherwise. That is
  the silent half of the bug ADR-0097 fixes; the loud half is §6.2.2.9, in
  tests/definingpoint_required.pas.

  The required identifiers are symbols in a scope enclosing the program now, so
  shadowing one is the ordinary rule and not a special case. }
program RequiredShadow(output);
type
  integer = char;

var
  v : integer;

{ A required function, shadowed by a declaration of the program's own. }
function ord(c : integer) : boolean;
begin
  ord := c = 'x'
end;

begin
  v := 'x';
  writeln(v);
  if ord(v) then writeln('shadowed')
end.
