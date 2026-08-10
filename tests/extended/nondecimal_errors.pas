{ What an extended number may not be. The lexer accumulates rather than
  bailing, so one run reports all of them; the refusal under --std=iso7185,
  where `#` is not a character of the language at all, is in
  selfhost/torture.pas instead. }
program NonDecimalErrors(output);
const
  { the base is a value in 2..36 (§6.1.5), and neither end is inclusive of
    the nonsense outside it }
  tooSmall = 1#0;
  alsoSmall = 0#0;
  tooBig = 37#1;
  { the extended-digit-sequence may not be empty }
  nothing = 16#;
  { a digit must be a digit *of that base* }
  notHex = 16#fg;
  notBinary = 2#12;
  { the sequence is maximal, so a word-symbol running into one is part of it
    rather than the next token }
  runOn = 16#ffand;
  { and the value must still be one of the integer type (ISO 7185 §6.4.2.2) }
  tooLarge = 16#ffffffff;
begin
end.
