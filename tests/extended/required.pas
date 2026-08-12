{ Five required things ISO/IEC 10206:1991 adds that ISO 7185 has not, small
  enough that the cost is in writing each twice rather than in any design:

    §6.4.2.2 d)  maxchar — the largest value of char-type
    §6.7.5.7     halt    — "no further processing ... shall occur"
    §6.7.6.3     card(x) — the number of members of a set
    §6.7.6.4     succ(x, k) and pred(x, k)
    §6.8.3.4     ><      — the set symmetric difference

  All but `><` are required *identifiers* rather than word-symbols, so a valid
  ISO 7185 program may declare its own `halt` or `card` and `required_iso.pas`
  is one that does. `><` reserves nothing either: under ISO 7185 the two
  characters can only be `>` followed by `<`, which no expression admits, so
  the lexer decides and one diagnostic comes out instead of a cascade.

  `halt` is last, because everything after it is unreachable — which is the
  whole of what §6.7.5.7 says. }
program Required(output);
type
  colour = (red, green, blue);
  digits = set of 0..9;

var a, b: digits; c: colour; i: integer; ch: char;

begin
  { §6.8.3.4: the members of exactly one operand. One instruction — `xor` —
    for the same reason union, difference and intersection are (ADR-0028). }
  a := [1, 2, 3, 4];
  b := [3, 4, 5, 6];
  write('symdiff');
  for i := 0 to 9 do if i in (a >< b) then write(' ', i:1);
  writeln;
  write('assoc  ');
  for i := 0 to 9 do if i in ((a >< b) >< b) then write(' ', i:1);
  writeln;

  { §6.7.6.3: a population count over the 256-bit word every set is. The
    standard's "error if no such value of integer-type exists" cannot arise
    here — the answer is at most 256. }
  writeln('card   ', card(a):1, ' ', card(b):1, ' ', card(a * b):1,
          ' ', card([]):1, ' ', card(a >< b):1);

  { §6.4.2.2 d). A char is a byte here (ADR-0021), so this is 255. }
  writeln('maxchar ', ord(maxchar):1);

  { §6.7.6.4: "a value whose ordinal number is ord(x) + k". The step may be
    negative, and zero, and `pred(x, k)` is defined as `succ(x, -(k))` — so
    `pred(blue, 2)` and `succ(blue, -2)` are the same value. }
  c := succ(red, 2);   write('step   ', ord(c):1);
  c := succ(blue, -2); write(' ', ord(c):1);
  c := pred(blue, 2);  write(' ', ord(c):1);
  c := succ(green, 0); writeln(' ', ord(c):1);

  { ...and over the other ordinal types, where the ends are the type's own. }
  i := succ(10, 5);    write('other  ', i:1);
  ch := succ('a', 3);  write(' ', ch);
  ch := pred('z', 25); writeln(' ', ch);

  { The one-argument forms are `succ(x, 1)` and `succ(x, -1)`, unchanged. }
  writeln('one    ', ord(succ(red)):1, ' ', ord(pred(blue)):1);

  writeln('halting');
  halt;
  writeln('this line is not reached')
end.
