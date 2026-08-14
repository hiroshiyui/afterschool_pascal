program TrapForBound(output);
{ The other half of tests/for_empty_bounds.pas, and the reason that one is not
  enough on its own: ISO 7185 6.8.3.9 excuses the bounds from being
  assignment-compatible only when the body is *not* executed. Here it is, so
  the final-value is checked and 20 is not a value of 0..10.

  Without this file, deleting the range check on a for-statement's bounds
  altogether passes the whole suite -- which is what it did when the check was
  moved under the loop's entry test. }
var i: 0..10;
begin
  for i := 0 to 20 do
    writeln(i:1)
end.
