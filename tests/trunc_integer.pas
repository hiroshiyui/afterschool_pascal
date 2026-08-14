{ ISO 7185 §6.6.6.3 spells both transfer functions the same way: "From the
  expression x that shall be of real-type, this function shall return a result
  of integer-type". An integer is not one, and there is nothing for either
  function to do to it.

  This compiler accepted an integer and widened it, which is a permissive
  deviation nothing in the corpus wrote. The suite's DEV158 is the program that
  did. ISO/IEC 10206:1991 §6.7.6.3 uses the same words, so the rule is the same
  under both standards.

  The real forms are here too: a rule that rejected them would pass a test
  written only from the wrong half. }
program TruncInteger(output);
var i: integer; x: real;
begin
  x := 3.5;
  writeln(trunc(x):1, ' ', round(x):1);
  i := 1001;
  writeln(trunc(i):1);
  writeln(round(i + 1):1)
end.
