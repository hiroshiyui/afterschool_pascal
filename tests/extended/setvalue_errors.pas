{ What ISO/IEC 10206:1991 §6.8.7.4 refuses, and the one rule the syntax it
  shares with a subscript made it possible to break.

  Sema accumulates rather than bailing, so every message below is reported in
  one run. }
program setvalue_errors(output);
type
  digits  = set of 0..9;
  kinds   = (red, green, blue);
  colours = set of kinds;
  vec     = array [1..3] of integer;
var
  s: digits;
  c: colours;
  a: vec;
  str: string(10);
  ch: char;
  i: integer;
begin
  { §6.8.7.4: "The value of the set-constructor of a set-value shall be
    assignment-compatible with the type of the set-value." Set compatibility
    is structural and decided on the base type (ADR-0028), so a set of char
    is not a set of 0..9 however the members are written. }
  s := digits['a', 'b'];
  s := digits['a'..'c'];
  c := colours[1, 2];

  { A set-value is a set-*constructor* with a name in front of it, so it holds
    member-designators. The `selector: value` components of an array-value or
    a record-value are a different production, and a bracket carrying one is
    parsed as a structured value whatever the name denotes. }
  s := digits[1: 2];
  c := colours[red: 1; green: 2];

  { The members are still members: an ordinal type, and all of one type. Both
    messages come from the ordinary set-constructor, because a set-value *is*
    one — nothing was written twice to say so. }
  s := digits[1.5];
  s := digits[1, 'c'];

  { §6.5.6 gives a substring-variable one range and no list. The parser admits
    a comma after a range because a set-value's member-designators are a list,
    and this is the case that permission must not reach. }
  ch := str[1..3, 2];

  { A name that is not a set type is not a set-value, so these are the
    ordinary readings and the ordinary complaints: an array subscripted by the
    wrong type, and a type name where a value was wanted. }
  i := a['x'];
  s := vec[1, 2];
  writeln(s = digits[], c = colours[], ch, i:1)
end.
