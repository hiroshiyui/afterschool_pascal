{ §6.4.8's dynamic-violation, for the required schema `string`.

  §6.4.3.3.3: "Each tuple in the domain of the schema shall have one component
  that is a value of integer-type greater than zero, and the component shall be
  designated the capacity of the variable-string-type produced from the schema
  with the tuple."

  So a capacity of zero or less is outside the schema's *domain*, and §6.4.8
  says what that is:

    It shall be a dynamic-violation if the tuple is not in the domain of the
    schema.

  A dynamic-violation is not an error and may not be left undetected. §3.1
  permits a processor to leave one undetected "up to, but not beyond, execution
  of the declaration, definition, or statement that exhibits" it, and §5.1 f)'s
  NOTE 1 is explicit: "Dynamic-violations, like all violations except errors,
  must be detected."

  Sema catches this where the tuple is a constant -- `var x: string(0)` is
  refused before the program runs. Where a discriminant brought it, nothing
  did: this program printed `cap= 0` and carried on, and the -1 case was
  reported only incidentally by a later assignment's capacity check, well past
  the declaration the clause names. Found by ADR-0224's audit; fixed by
  ADR-0225.

  The legal call is made first, so a check that fired too eagerly would fail
  here rather than at the trap. }
program TrapStringCapacity(output);

procedure g(n: integer);
var x: string(n);
begin
  x := 'hi';
  writeln('n=', n:2, ' cap=', x.capacity:2, ' [', x, ']')
end;

begin
  g(5);
  g(0)
end.
