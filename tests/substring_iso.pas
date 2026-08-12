{ §6.5.6 is Extended Pascal's, and this is the program that says so.

  The base is a `packed array [1..8] of char` rather than a `string(n)`,
  because a `string` type is itself Extended Pascal — a program using one would
  die at the type and never reach the notation under test, which is the fault
  ADR-0054 found in `constexpr_iso.pas` and ADR-0056 met again. Everything here
  is a legal ISO 7185 program except the substring.

  ISO 7185 §6.5.3.2 gives an array one index-expression per subscript and no
  way to write two with a `..` between them, so the `..` is what has no
  production — and the diagnostic names it. }
program SubstringIso(output);
var f: packed array [1..8] of char;
begin
  f := 'abcdefgh';
  { Legal ISO 7185: one subscript, one character. }
  writeln(f[3]);
  { Not legal ISO 7185. }
  writeln(f[3..5])
end.
