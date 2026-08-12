{ ISO 7185 §6.6.2's function-heading has no result-variable-specification, so
  `= r` between the parameters and the result type is a syntax error and the
  parser stops there. Its own file, because a parse error would hide every
  Sema refusal in tests/funcresult_iso.pas — a negative test that mixes two
  passes only ever exercises the earlier one. }
program FuncResultIsoVar(output);
function f = r: integer;
begin r := 1 end;
begin writeln(f:1) end.
