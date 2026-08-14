{ ISO 7185 §6.5.4: "A pointer-variable shall be a variable-access that denotes
  a variable possessing a pointer-type." §6.5.1's variable-accesses are an
  entire-variable, a component-variable, an identified-variable and a
  buffer-variable -- a function-designator is none of them, and §6.8.2.2 makes
  a read of a function identifier a recursive activation, so `f^` would
  dereference a value rather than a variable.

  ISO/IEC 10206:1991 §6.8.6.4's function-identified-variable is exactly this
  and is legal there (ADR-0056). That record gates it in the *parser*, which
  works only because a call written with arguments is what makes the parser
  build a call node at all. A parameterless function is a bare identifier,
  indistinguishable from a variable until Sema resolves it -- so this is the
  shape the parser's gate cannot reach, and the one BSI's DEV110 writes. }
program FuncDerefIso(output);
type link = ^integer;
var g : link;
    n : integer;

function f : link;
begin
  f := g
end;

begin
  new(g);
  g^ := 9;
  n := f^;            { §6.5.4: f is not a variable-access }
  writeln(n:1)
end.
