{ AP 6.4.15.1's capacity as a member of the schema's *domain*, which is a
  different question from trap_text_capacity.pas beside it.

  That case is AP 6.4.15.5: a text value too long for the capacity it is stored
  into -- a fault in the data. This one is the capacity itself being outside
  what the schema admits -- a fault in the declaration.

  AP 6.4.15.1 gives `utf8` the required schema's shape and the same requirement
  ISO/IEC 10206:1991 §6.4.3.3.3 makes of `string`: the discriminant shall be
  greater than zero. So §6.4.8 reaches it unchanged, the dialect containing
  Extended Pascal:

    It shall be a dynamic-violation if the tuple is not in the domain of the
    schema.

  §3.1 permits a dynamic-violation to be left undetected "up to, but not
  beyond, execution of the declaration", and §5.1 f)'s NOTE 1 states that
  dynamic-violations "must be detected".

  This was the worse of the two kinds before ADR-0225. A `string(-1)` was at
  least reported at the first assignment by the capacity check that store
  makes; a `utf8(-1)` ran to completion and printed nothing wrong, because no
  store on the text path asks about the capacity's sign. Found by ADR-0224's
  audit.

  The legal call is first, so a check that fired too eagerly would fail here
  rather than at the trap. }
program TrapTextDomain(output);

procedure g(n: integer);
var x: utf8(n);
begin
  writeln('n=', n:2, ' cap=', x.capacity:2)
end;

begin
  g(4);
  g(0)
end.
