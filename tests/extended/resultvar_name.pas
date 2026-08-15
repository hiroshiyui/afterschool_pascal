{ 6.7.2's result-variable-specification is `= identifier : type-name`, and the
  identifier is what a structured result is built through -- 6.8.2.2 making
  every *read* of the function identifier a recursive call, so without this
  name such a result could only ever be assigned whole. What follows the '='
  is therefore a name and nothing else. }
program ResultVarName(output);
function f = 3: integer;
begin
  f := 1
end;
begin
  writeln(f)
end.
