{ `char` is a byte with an ordinal of 0..255, which README and CLAUDE.md both
  state and nothing pinned: until this file, no test in the tree used a byte
  above 127 at all. That is exactly the half of the range where signedness
  decides the answer, because a `char` is an `i8` and 200 as a *signed* byte is
  -56.

  What makes the upper half work is that an ordinal is widened before it is
  compared: an unsigned ordinal is zero-extended, so an array subscript reaches
  its bounds check as 200 rather than as -56, and the signed predicate that
  check emits is then correct. The index rules in `verify/` quantify over an
  already-widened subscript and cannot see that step, so this file is what
  stands behind it: change the `zext` to a `sext` and the array line below
  traps.

  The bytes here are literal rather than `chr(...)`, because ISO 7185 has no
  constant-expression and `chr(200)` therefore cannot be a subrange bound. The
  file is Latin-1 for the same reason, and prints ordinals rather than
  characters so that its expected output stays ASCII. }
program HighChar(output);
var c, d: char;
    s: set of char;
    a: array ['È'..'Ò'] of integer;
    i: integer;
begin
  c := 'È';                 { 200 }
  d := 'a';                    { 97 }

  { 6.4.2.2: ord of a char is its ordinal, and the ordinals run to 255. }
  writeln('ord    ', ord(c):1, ' ', ord('ÿ'):1);

  { 6.7.2.5 orders chars by ordinal, so a byte above 127 is *greater* than one
     below it. A signed comparison would answer the other way round. }
  writeln('order  ', c > d, ' ', d < c);

  { 6.6.6.4: succ and pred move by one ordinal, and neither end of the type is
     near here, since succ runs out at 255. }
  writeln('succpr ', ord(succ(c)):1, ' ', ord(pred(c)):1);

  { 6.4.3.4: a set of char covers the whole 0..255 base type. }
  s := ['È'..'Ò'];
  writeln('inset  ', c in s, ' ', d in s, ' ', 'ÿ' in s);

  { 6.5.3.2: the subscript is checked against the index type's bounds. Both
     bounds are above 127 here, which is the case the widening exists for. }
  for i := 200 to 210 do
    a[chr(i)] := i * 2;
  writeln('array  ', a['È']:1, ' ', a['Ò']:1);

  { 6.6.6.4's chr and ord are inverses across the whole range. }
  writeln('chrord ', ord(chr(200)):1, ' ', ord(chr(255)):1);

  { 6.8.3.5: a case label is a constant of the selector's type. }
  case c of
    'È': writeln('case   hit');
    'Ò': writeln('case   wrong')
  end
end.
