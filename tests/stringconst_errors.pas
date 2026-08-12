{ What a string constant is not.

  ISO 7185 §6.5.1's variable-accesses are entire-variables, components and
  identified-variables — a constant-identifier is none of them. So a string
  constant has storage and is still not a variable, and every rule that asks
  for one refuses it through the message it already had. Nothing below needed
  a check written for string constants (ADR-0068).

  §6.4.2.1 is the other half: a string constant denotes a value of a
  structured type, so it cannot stand where an *ordinal* constant is required.

  Sema accumulates rather than bailing, so every message below comes from one
  run. }
program stringconst_errors(input, output);
type
  pair = packed array [1..2] of char;
const
  ab   = 'ab';
  abc  = 'abc';
var
  p: pair;
  i: integer;

procedure byval(s: pair);
begin
  writeln(s)
end;

procedure byref(var s: pair);
begin
  writeln(s)
end;

{ §6.4.2.4's case-constant and §6.4.3.2's index-type both want an ordinal, and
  a packed array of char is not one. The declarations are here rather than
  above so that the two messages come out in source order with the statements. }
type
  bad = array [ab..abc] of integer;

begin
  { §6.8.2.2: the left side of an assignment is a variable-access. }
  ab := 'cd';

  { §6.6.3.3: an actual var parameter shall be a variable-access. The value
    form on the line after it is legal, and is pinned in stringconst.pas. }
  byref(ab);

  { §6.4.6 makes a value parameter a copy rather than a padded one, so the
    lengths must agree — the same rule a literal of the wrong length meets. }
  byval(abc);

  { §6.9.1: a read-parameter is a variable-access too. }
  read(ab);

  { §6.8.3.5 compares values of one type; two lengths are two types. }
  if ab = abc then
    writeln('never');

  { §6.4.2.1: an ordinal type is required, and a string constant has none. }
  case i of
    ab: writeln('never')
  end;

  { A subscript of a constant is a legal *expression* — `stringconst.pas`
    writes one — and still not a variable, because `isDesignator` asks the
    base and the base is a constant. That is one rule answering for both
    forms rather than a second rule written for components. }
  ab[1] := 'z';

  { And the component is a char, so the whole constant is not one. }
  p[1] := ab
end.
