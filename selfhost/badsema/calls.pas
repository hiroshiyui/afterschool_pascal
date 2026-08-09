{ Argument lists, the required functions, and calls used as values. }
program calls(output);
type vec = array [1..3] of integer;
var i: integer; r: real; b: boolean; v: vec; c: char;
function f(x: integer): integer; begin f := x end;
procedure byref(var x: integer); begin x := 1 end;
procedure byval(x: vec); begin x[1] := 1 end;
procedure noargs; begin end;
begin
  i := f(1, 2);
  i := f;
  byref(1);
  byref(r);
  byval(i);
  i := noargs;
  noargs(1);
  i := nosuchfunction(1);
  i := abs(1, 2);
  i := abs(b);
  i := odd(r);
  i := ord(v);
  c := chr(r);
  i := succ(v);
  i := trunc(b);
  r := sqrt(b);
  b := eof(i, i);
  b := eof(i);
  write(i, r, b, c)
end.
