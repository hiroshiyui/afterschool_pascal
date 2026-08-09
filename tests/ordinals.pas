program Ordinals(output);

{ Enumerated types and subranges: they are ordinal types like char and
  integer, so they index arrays, drive for loops, answer ord/succ/pred, and
  select case arms — all through the same machinery. }

type
  colour  = (red, orange, yellow, green, blue);
  weekday = (mon, tue, wed, thu, fri);
  digit   = 1..9;
  letter  = 'a'..'e';
  warm    = red..yellow;          { a subrange of an enumeration }

var
  c: colour;
  d: digit;
  ch: letter;
  tally: array [colour] of integer;
  name: array [weekday] of packed array [1..3] of char;
  w: warm;
  n: integer;

function Heat(x: colour): integer;
begin
  { No `else` arm exists in ISO Pascal, so every value must be listed. }
  case x of
    red, orange: Heat := 2;
    yellow:      Heat := 1;
    green, blue: Heat := 0
  end
end;

begin
  { An enumeration is ordered by its declaration. }
  writeln('ord: ', ord(red), ord(orange), ord(yellow), ord(green), ord(blue));
  writeln('red < blue: ', red < blue, '  green > yellow: ', green > yellow);
  writeln('succ(red) = orange: ', succ(red) = orange);
  writeln('pred(blue) = green: ', pred(blue) = green);

  for c := red to blue do
    tally[c] := Heat(c) * 10;
  write('tally:');
  for c := red to blue do
    write(tally[c]:4);
  writeln;

  { An array indexed by an enumeration, holding strings. }
  name[mon] := 'Mon';
  name[tue] := 'Tue';
  name[wed] := 'Wed';
  name[thu] := 'Thu';
  name[fri] := 'Fri';
  write('week:');
  for c := red to blue do ;          { empty statement, just to be awkward }
  writeln(' ', name[mon], ' ', name[wed], ' ', name[fri]);

  { A subrange behaves as its host type in every expression. }
  d := 4;
  n := d * 2 + 1;
  writeln('digit: ', d, ' doubled+1 = ', n);
  d := 9;
  writeln('last digit: ', d);

  for ch := 'a' to 'e' do
    write(ch);
  writeln;

  { A subrange of an enumeration is still that enumeration. }
  w := orange;
  writeln('warm is a colour: ', w = orange, ' ', ord(w));

  { case on a char, and on an integer subrange. }
  for ch := 'a' to 'e' do
    case ch of
      'a', 'e': write('v');
      'b', 'c', 'd': write('.')
    end;
  writeln;

  for d := 1 to 5 do
    case d of
      1: write('one ');
      2: write('two ');
      3: write('three ');
      4, 5: write('many ')
    end;
  writeln
end.
