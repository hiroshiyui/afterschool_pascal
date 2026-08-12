{ D.103: "For write-parameters of the form e:TotalWidth:FracDigits, it is an
  error if the value of FracDigits is less than zero." A separate condition
  from D.102's, and a separate message. }
program trap_fracdigits(output);
var p: integer; x: real;
begin
  x := 1.5;
  p := 0;
  writeln('[', x:4:p, ']');
  p := -2;
  writeln('[', x:4:p, ']')
end.
