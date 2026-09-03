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
  { A call the compiler could not resolve leaves a placeholder type behind,
    and a message must not name it (ADR-0306). Each of these three reports
    the call and stops: a second line saying "cannot assign integer to a
    variable of type vec" would name a type nothing here holds. The target is
    `v` and not `i` on purpose -- an integer target is what hid this, the
    placeholder being an integer. }
  v := nosuchfunction(2);
  v := noargs(2);
  v := i(2);
  write(i, r, b, c)
end.
