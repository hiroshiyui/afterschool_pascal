{ ISO/IEC 10206:1991 §6.8.7.4's set-value, refused under ISO 7185.

  The gate is worth a file of its own because the two languages disagree about
  what these tokens *are* rather than about whether a feature is allowed.
  Extended Pascal reads `digits[1, 3]` as a set-value; ISO 7185 has no such
  production, so the only reading left is a subscripted array — and `digits`
  names a type, which is where the complaint comes from.

  That makes this a real gate rather than a test that would pass whatever the
  compiler did: the same program compiles under --std=extended and is what
  tests/extended/setvalue.pas exercises. ADR-0054 and ADR-0056 each met a gate
  that could not distinguish anything, so this one says why it can. }
program setvalue_iso(output);
type digits = set of 0..9;
var s: digits;
begin
  s := digits[1, 3];
  writeln(1 in s)
end.
