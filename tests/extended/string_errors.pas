{ What the string types refuse, and the clause each rule comes from. }
program StringErrors(output);
type line = packed array [1..4] of char;
var s: string(5);
    fixed: line;
    i: integer;
    r: real;
    z: string(0);
    b: boolean;
begin
  { §6.4.3.3.3: "Each tuple in the domain of the schema shall have one
    component that is a value of integer-type greater than zero", so a
    capacity of zero names no type. }
  s := 'ok';
  { §6.7.6.7's arguments are strings or chars, and its positions integers. }
  i := length(3);
  i := index(s, 4);
  i := length(s, s);
  s := substr(s, 1.5);
  s := trim(s, s);
  b := eq(s);
  b := lt(s, 7);
  { §6.10.3.1 lists what write accepts; a real is on it, a set is not. }
  { §6.8.3.6 gives `+` to strings and chars, and nothing else. }
  s := s + 3;
  r := s;
  { §6.4.3.3.3 NOTE 1 indexes a string by an *integer* — the index-domain is
    the value's 1..length, and no type names it. }
  b := s['a'] = 'x';
  { a string is not an ordinal, an integer or anything a case may select on }
  i := ord(s);
  writeln(i:1, b, r:3:1, fixed, z)
end.
