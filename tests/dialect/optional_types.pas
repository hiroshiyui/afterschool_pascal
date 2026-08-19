{ ADR-0123, in the direction that refuses. Sema accumulates, so one file
  carries every refusal that is not a parse error.

  Most of it is refusal *by construction* and not by an enumerated list: an
  optional is not a numeric type, not a string type and not an ordinal one, so
  arithmetic, comparison and `write` each turn it down through the diagnostic
  they already had. Only four rules are written out below, and each is one no
  existing rule could have stated. }
program optional_types(output);

type
  OptInt = ?integer;
  { An optional of an optional: one flag answers for a value, and two answer
    for each other. }
  Twice = ?OptInt;
  { And of a file, which is never a value at all (ADR-0021), so there is
    nothing for the flag to say is missing. }
  OptFile = ?text;
  Name = string(8);

var a, b: OptInt;
    n: integer;
    f: text;

{ ADR-0122 refused every result that is an address; ADR-0123 lifts that for an
  optional of a string with a *capacity*, which is what the copy needs. These
  are the three shapes that still do not answer. }
function fplain(x: integer): Name; external 'f1';
function fopt(x: integer): OptInt; external 'f2';
function ffile(x: integer): OptFile; external 'f3';

begin
  { An optional does not answer for its T, in either direction. That is the
    whole guarantee: a plain integer can never be absent. }
  n := a;
  a := 'x';

  { It compares with nil and with nothing else, and only for equality. }
  if a = b then writeln('?');
  if a < nil then writeln('?');

  { And it is none of the things an operator wants. }
  n := a + 1;
  writeln(a);
  writeln(n:1, f = f, fplain(1), fopt(1) = nil, ffile(1) = nil)
end.
