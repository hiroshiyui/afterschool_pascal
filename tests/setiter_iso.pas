{ ISO 7185 §6.8.3.9's for-statement has one form, so `in` where the ':=' is
  expected is a syntax error before it is anything else. This file is the
  gate: with the --std test dropped from parseFor, it compiles. }
program setiter_iso(output);
var i: integer; s: set of 1..9;
begin
  s := [1, 2];
  for i in s do writeln(i)
end.
