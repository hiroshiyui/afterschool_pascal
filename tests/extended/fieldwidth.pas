{ ISO/IEC 10206:1991 §6.10.3.1 moves the least field width from one to zero:
  "The value of TotalWidth shall be greater than or equal to zero ... The value
  of FracDigits shall be greater than or equal to zero." What zero *means* is
  then given per type, and it is not the same answer for all of them. }
program fieldwidth(output);
type str5 = packed array [1..5] of char;
var x: real; s: string(10); p: str5; w: integer;
begin
  { §6.10.3.6: "if TotalWidth = 0, no characters" — and "if 1 <= TotalWidth
    <= n, the first through TotalWidth-th characters", which is the truncation
    ISO 7185 §6.9.3.6 already asked for. }
  writeln('[', 'hello':0, ']');
  writeln('[', 'hello':3, ']');
  writeln('[', 'hello':5, ']');
  writeln('[', 'hello':8, ']');

  { §6.10.3.2: a char at width zero writes nothing either. A one-character
    literal is a char (ISO 7185 §6.4.3.2), which is why this is the char rule
    and not the string one. }
  writeln('[', 'a':0, ']');
  writeln('[', 'a':1, ']');
  writeln('[', 'a':3, ']');

  { §6.10.3.5 makes a Boolean "equivalent to writing the appropriate
    character-string 'True' or 'False' ... with a field-width parameter of
    TotalWidth" — so it is the string rule, truncation and all. }
  writeln('[', true:0, ']');
  writeln('[', true:2, ']');
  writeln('[', false:3, ']');
  writeln('[', true:6, ']');

  { §6.10.3.3 b): an integer at width zero is *not* nothing. Zero is always
    less than IntDigits + 1, so the sign and the digits are written and only
    the padding is gone. }
  writeln('[', 42:0, ']');
  writeln('[', -42:0, ']');
  writeln('[', 0:0, ']');

  { §6.10.3.4.2's representation ends with "the character '.', the next
    FracDigits digit-characters", and the '.' is unconditional — so a
    FracDigits of zero, which this standard made legal, still writes it. }
  x := 3.75;
  writeln('[', x:0:0, ']');
  writeln('[', x:8:0, ']');
  writeln('[', x:0:2, ']');
  writeln('[', x:9:2, ']');
  x := -3.75;
  writeln('[', x:0:0, ']');
  writeln('[', x:0:1, ']');

  { §6.10.3.4.1: ActWidth is TotalWidth or ExpDigits + 6, whichever is larger,
    and DecPlaces is ActWidth - ExpDigits - 5 — so a width chooses how many
    fraction digits the floating form shows, and a width of zero asks for the
    narrowest one there is. }
  x := 3.75;
  writeln('[', x:0, ']');
  writeln('[', x:12, ']');
  writeln('[', x:20, ']');

  { ExpDigits is implementation-defined, and here it is what the exponent
    needs — so a three-digit exponent leaves one fewer fraction digit in the
    same field. That is the only place the choice is observable. }
  writeln('[', maxreal:20, ']');
  writeln('[', epsreal:20, ']');

  { The width is an expression, not a literal, so the check is a run-time one
    and this is the shape a program actually meets. }
  w := 0;
  s := 'abc';
  writeln('[', s:w, ']');
  writeln('[', s:w + 2, ']');
  p := 'abcde';
  writeln('[', p:w, ']');
  writeln('[', p:w + 3, ']')
end.
