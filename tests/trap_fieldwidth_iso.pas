{ ISO 7185 §6.9.3.1: "The values of TotalWidth and FracDigits shall be greater
  than or equal to one; it shall be an error if either value is less than one."
  That is the whole of what ISO/IEC 10206:1991 §6.10.3.1 changed, so this is
  the gate: a width of zero is legal there and an error here, and the two
  compilers must disagree about the same program in the same way. }
program trap_fieldwidth_iso(output);
var w: integer;
begin
  w := 1;
  writeln('[', 7:w, ']');
  w := 0;
  writeln('[', 7:w, ']')
end.
