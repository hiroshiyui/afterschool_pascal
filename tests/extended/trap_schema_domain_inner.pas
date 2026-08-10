{ The same rule as trap_schema_domain, one dimension in. §6.4.7 NOTE 2 is
  about the tuple, not about the outermost bound: a grid whose width is fine
  and whose height is empty produces no type either, so the check is made at
  every dimension a discriminant bounds. }
program TrapSchemaDomainInner(output);
type grid(w, h: integer) = array [1..w, 1..h] of integer;

procedure hold(a, b: integer);
var g: grid(a, b);
begin
  writeln('grid(', g.w:1, ', ', g.h:1, ') exists')
end;

begin
  hold(2, 2);
  hold(2, 0)
end.
