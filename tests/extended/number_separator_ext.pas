{ ISO 7185 §6.1.8, and ISO/IEC 10206:1991 §6.1.10 in the same words: "There
  shall be at least one separator between any pair of consecutive tokens made
  up of identifiers, word-symbols, labels or unsigned-numbers." So `10div 2`
  is two tokens written as one and is not `10 div 2`.

  Only the decimal form needs the check. An extended-digit sequence is
  deliberately maximal and a letter *is* a digit there (ADR-0036), so `16#ffand`
  is one ill-formed number rather than a number and a word-symbol -- nothing
  but a non-letter can follow one.

  tests/number_separator.pas is the same file under the other
  standard, because the sentence is in both and the check is gated on neither.
  The legal forms below are what keep the check from being a ban on any letter
  after a digit. }
program NumberSeparatorExt(output);
var i : integer;
    r : real;
begin
  r := 1.5e3;                 { legal: the exponent is part of the number }
  i := 10 div 2;              { legal: the separator is there }
  i := 10div 2;
  writeln(i:1, r:6:1)
end.
