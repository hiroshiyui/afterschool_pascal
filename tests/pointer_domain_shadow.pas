{ ISO 7185 §6.2.2.9 states one exception to "the defining-point shall precede
  all applied occurrences":

    an identifier can have an applied occurrence in the type-identifier of the
    domain-type of any new-pointer-types contained by the type-definition-part
    containing the defining-point of the type-identifier

  So a pointer's domain binds to the type-identifier defined in *its own*
  type-definition-part -- and an enclosing type of the same spelling does not
  settle the question, because the inner one may still be defined further down.
  This compiler resolved such a name where it stood, so `p` below pointed at
  the program's `node` (an integer) and `ptr^ := true` was a type error.

  The suite's CONF027 is the program that found it. Both directions are here:
  the domain that must wait, and one that must *not* -- `outer` is defined
  nowhere in this type part, so it means what the program says it means. }
program PointerDomainShadow(output);
type
  node  = integer;
  outer = char;

procedure inner;
type
  p     = ^node;     { the `node` two lines down, not the program's }
  q     = ^outer;    { nothing here defines `outer`, so the program's }
  node  = boolean;
var
  b: p;
  c: q;
begin
  new(b);
  b^ := true;
  new(c);
  c^ := 'y';
  writeln('inner ', b^, ' ', c^)
end;

begin
  inner
end.
