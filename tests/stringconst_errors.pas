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
const
  ab   = 'ab';
  abc  = 'abc';
type
  pair = packed array [1..2] of char;
  { §6.4.2.4's case-constant and §6.4.3.2's index-type both want an ordinal,
    and a packed array of char is not one. This sat in a second type part
    below the procedures, so that its message would come out in source order
    with the statements — an order §6.2.1 has no grammar for, and one nothing
    checked until ADR-0072. Its diagnostic now leads the file instead. }
  bad = array [ab..abc] of integer;
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

begin
  { §6.8.2.2: the left side of an assignment is a variable-access. }
  ab := 'cd';

  { §6.6.3.3: an actual var parameter shall be a variable-access. The value
    form on the line after it is legal, and is pinned in stringconst.pas. }
  byref(ab);

  { §6.4.5 makes two char arrays of different length incompatible, and §6.4.6
    has no clause that reaches across the difference — there is no padding in
    this standard. ISO/IEC 10206:1991 §6.4.5 d) and §6.4.6 f) add both, and
    there the same call is legal and padded (ADR-0171); the message here is
    the one for two types that are simply not assignment-compatible. }
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

  { A subscript of a constant is refused twice over, and the two refusals are
    different rules. §6.7.1 admits a `[` only after a variable-access, so under
    ISO 7185 the subscript is not a sentence of the language at all — that is
    §6.8.8's constant-access, which the next standard adds. And even where it
    *is* one, it is not a variable: `isDesignator` asks the base, and the base
    is a constant. One rule answers for both forms rather than a second being
    written for components, which is why the second message is the same one a
    bare `ab := 'z'` gets. }
  ab[1] := 'z';

  { And the component is a char, so the whole constant is not one. }
  p[1] := ab
end.
