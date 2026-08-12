{ D.102: "For write-parameters of the form e:TotalWidth or of the form
  e:TotalWidth:FracDigits, it is an error if the value of TotalWidth is less
  than zero." Extended Pascal moved the bound from one to zero; it did not
  remove it. }
program trap_fieldwidth(output);
var w: integer;
begin
  w := 0;
  writeln('[', 7:w, ']');
  w := -1;
  writeln('[', 7:w, ']')
end.
