program Sets(output);
{ ISO 7185 6.4.3.4, 6.7.1, 6.7.2.3 and 6.7.2.4: the set type, the set
  constructor, the three set operators and `in`. Every set here is the same
  256-bit word whatever its base type (ADR-0028), so what the cases below
  separate is the *base types*, which is where a wrong universe or a wrong
  member position would show. }

type
  colour = (red, green, blue, violet);
  palette = set of colour;
  letters = set of char;
  digit = 0..9;
  digits = set of digit;

var
  vowels, alpha, consonants, s: letters;
  p, q: palette;
  d: digits;
  c: char;
  i, n: integer;
  bits: set of boolean;

procedure Show(name: char; s: letters);
{ A set travels as a value parameter, so the callee's changes are its own. }
var c: char; n: integer;
begin
  n := 0;
  for c := 'a' to 'z' do
    if c in s then n := n + 1;
  writeln(name, ': ', n:1)
end;

procedure Grow(var s: letters);
begin
  s := s + ['!']
end;

begin
  vowels := ['a', 'e', 'i', 'o', 'u'];
  alpha := ['a'..'z'];
  consonants := alpha - vowels;

  writeln('member: ', 'a' in vowels, ' ', 'b' in vowels);
  writeln('union: ', (vowels + consonants) = alpha);
  writeln('intersection: ', (vowels * consonants) = []);
  writeln('difference: ', ('e' in consonants));
  writeln('subset: ', vowels <= alpha, ' ', alpha <= vowels);
  writeln('superset: ', alpha >= vowels, ' ', vowels >= alpha);
  writeln('equal: ', vowels = vowels, ' ', vowels = alpha);
  writeln('unequal: ', vowels <> alpha);
  Show('v', vowels);
  Show('c', consonants);

  { a value parameter is a copy: the caller's set is untouched }
  s := vowels;
  Show('s', s);
  Grow(s);
  writeln('grown: ', '!' in s, ' original: ', '!' in vowels);

  { an enumeration as the base type -- ordinals 0..3 rather than 97..122 }
  p := [red, blue];
  q := [green..violet];
  writeln('enum: ', red in p, green in p, blue in p, violet in p);
  writeln('enum range: ', red in q, green in q, blue in q, violet in q);
  writeln('enum union: ', (p + q) = [red..violet]);
  writeln('enum inter: ', (p * q) = [blue]);

  { a subrange base type, and the run-time bounds a constructor may have }
  d := [1, 3..5, 9];
  writeln('digits: ', 0 in d, 1 in d, 2 in d, 3 in d, 5 in d, 9 in d);
  i := 4;
  d := [i..i + 3];
  writeln('computed: ', 3 in d, 4 in d, 7 in d, 8 in d);
  { an empty range is empty, not everything }
  d := [i + 1..i - 1];
  writeln('empty range: ', d = [], ' ', 5 in d);

  { a value outside the *representation* is simply not a member, not a trap }
  i := 5000;
  writeln('far outside: ', i in d);
  i := -5000;
  writeln('negative: ', i in d);

  { boolean is an ordinal type like any other }
  bits := [true];
  writeln('bits: ', true in bits, ' ', false in bits);

  { [] is a value of every set type }
  s := [];
  p := [];
  writeln('empty: ', s = [], ' ', p = [], ' ', 'a' in s);

  { building a set in a loop, which is what a compiler actually does with one }
  s := [];
  for c := 'a' to 'z' do
    if not (c in vowels) then s := s + [c];
  writeln('built: ', s = consonants);

  n := 0;
  for i := 0 to 9 do
    if i in [2, 3, 5, 7] then n := n + i;
  writeln('primes under ten: ', n:1)
end.
