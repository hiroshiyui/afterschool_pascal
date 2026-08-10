{ The diagnostics of set types, set constructors and the set operators
  (ISO 7185 6.4.3.4, 6.7.1, 6.7.2.3, 6.7.2.4, 6.7.2.5). Sema accumulates, so
  one file carries all of them. }
program sets(output);
type
  colour = (red, green, blue);
  wide = set of integer;          { a base type too big for the universe }
  fractional = set of real;       { a base type that is not ordinal at all }
  chars = set of char;
  hues = set of colour;
var
  c: chars;
  h: hues;
  n: integer;
  b: boolean;
  r: real;
  f: text;
  p: ^integer;
function badresult: chars;        { 6.6.2: not a simple type or a pointer }
begin
end;
begin
  { a constructor whose members disagree with each other }
  c := ['a', 1];
  c := [red, blue];
  { a member that is not ordinal at all }
  c := [r];
  { a constructor of the wrong base type for its target }
  c := [1, 2];
  h := ['a'];
  { `in` wants a set on the right and an ordinal on the left }
  b := 'a' in n;
  b := r in c;
  b := c in c;
  { and the two sides must agree }
  b := 'a' in h;
  { sets have no ordering }
  b := c < c;
  b := c > c;
  { but they do have inclusion and equality }
  b := c <= c;
  b := c >= c;
  b := c = c;
  { the set operators want two compatible sets }
  c := c + h;
  c := c - n;
  { and a set is none of the things a pointer or a file is. The order these
    two are tried in is part of the contract: a pointer against a set has to
    report the same thing on both sides. }
  b := p = c;
  b := c = f
end.
