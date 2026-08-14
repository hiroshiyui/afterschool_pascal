{ ISO/IEC 10206:1991 §6.4.7 lets a schema name itself inside a pointer domain,
  which is the one place §6.4.7's own prohibition does not reach -- without it
  the production would recurse forever. That domain pends while the schema's
  body is being resolved, and the pend was drained only at the end of a
  type-definition-part.

  Here the schema is used by a *variable* declaration, so nothing drained the
  list and `v.next` was left with a null domain: `new` reported that it needed
  a pointer variable and six cascade errors followed. Adding an unrelated type
  definition after the var part made the very same program compile, which is
  what identified the drain rather than the schema as the fault. }
program SchemaSelfPointerVar(output);
type node(n: integer) = record next: ^node; a: array [1..n] of integer end;
var v: node(3);
begin
  new(v.next, 2);
  v.next^.a[1] := 5;
  writeln(v.next^.a[1]:1)
end.
