program TrapRange(output);

{ ISO 7185 §6.4.6 makes it an error to store a value outside a subrange's
  bounds. The value comes from a function so the check cannot be folded away. }

type
  digit = 1..9;

var
  d: digit;
  i: integer;

function Given(n: integer): integer;
begin
  Given := n * 5
end;

begin
  for i := 1 to 9 do
    d := i;
  writeln('d = ', d);

  d := Given(1);
  writeln('d = ', d);

  writeln('about to leave the subrange');
  d := Given(2);
  writeln('unreachable: ', d)
end.
