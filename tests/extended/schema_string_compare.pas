{ ISO 7185 §6.7.2.5 gave the relational operators only to strings of one
  length, and this compiler diagnosed a mismatch wherever both lengths were
  written and trapped where one was a discriminant. ISO/IEC 10206:1991 §6.8.3.5
  retires that: "the relational-operators effectively extend the shorter value
  with trailing spaces to the length of the longer value", so two strings of
  different lengths compare rather than failing (ADR-0051).

  What the trap protected has not gone away. The defect it was written for was
  a *length* computed from placeholder bounds — arithmetic on a discriminant
  that yields a plausible number — and a padded comparison needs both lengths
  to be right just as much as an equal-length one did. The evidence simply
  moved from a program that stops to a program that answers. }
program SchemaStringCompare(output);
type str(n: integer) = packed array [1..n] of char;

var short: str(3);
    long: str(5);

procedure order(var x: str; var y: str);
begin
  if x = y then writeln('equal') else writeln('unequal')
end;

begin
  short := 'abc';
  long := 'abc  ';
  { the same characters, and the shorter padded to the longer: equal }
  order(short, long);
  order(short, short);
  long := 'abcde';
  { now they differ where the padding is, so the answer changes — which is
    what says the comparison read five characters and not three }
  order(short, long);
  writeln(short = 'abc  ', ' ', short = 'abcde', ' ', long > short)
end.
