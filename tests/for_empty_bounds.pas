program ForEmptyBounds(output);
{ ISO 7185 6.8.3.9: the initial-value and the final-value "shall be
  assignment-compatible with the type possessed by the control-variable *if the
  statement of the for-statement is executed*". So a for-statement whose body
  never runs may name bounds that are not values of the control variable's type
  at all, and checking them eagerly turns a legal program into a run-time
  error.

  Both directions, because the entry test differs: `to` runs when from <= to,
  `downto` when from >= to.

  The BSI validation suite's CONF181 is the ascending case. Nothing in this
  corpus had written either one, which is why the compiler checked both bounds
  unconditionally and every oracle agreed with it. }
var
  i: 0..10;
  n: integer;
begin
  n := 0;
  for i := maxint to maxint - 1 do n := n + 1;
  writeln('to    ', n:1);

  n := 0;
  for i := -maxint downto -maxint + 1 do n := n + 1;
  writeln('downto ', n:1);

  { And one that does run, to show the bounds are still the loop's own. }
  n := 0;
  for i := 2 to 4 do n := n + i;
  writeln('sum   ', n:1)
end.
