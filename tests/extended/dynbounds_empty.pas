{ ISO/IEC 10206:1991 6.4.7: a type is produced only for a tuple in the schema's
  domain, and 6.4.2.4's dynamic subrange carries the same requirement as a
  dynamic-violation branch -- `1..0` denotes no type at all. The bound is not
  known until the block is entered, so the check is made there, against the
  value the descriptor was filled with (ADR-0113).

  The message describes the array rather than naming a schema, because the
  program wrote none: the anonymous schema such a variable is given internally
  has no spelling for a message to use, and naming it would name something the
  source does not contain. }
program DynBoundsEmpty(output);
procedure p(m: integer);
var a: array [1..m] of integer;
begin
  a[1] := m;
  writeln('entered with ', m:1)
end;
begin
  p(3);          { in the domain }
  p(0)           { not in it, and the last thing this program does }
end.
