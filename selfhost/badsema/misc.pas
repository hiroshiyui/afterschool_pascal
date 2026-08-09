{ Function results, `with`, pointers and subscripts. }
program misc(output);
type rec = record a: integer; b: char end;
     link = ^rec;
     colour = (red, green);
var v: rec; p: link; i: integer; a: array [1..3] of integer;
function f: integer;
begin
  f := 'x';
  i := 1
end;
procedure noresult;
begin
  noresult := 1
end;
begin
  i := f;
  noresult;
  new(i);
  dispose(f);
  i := a[red];
  with f do i := 1;
  with v do
    for a := 1 to 2 do i := 1;
  case r of 1: i := 1 end;
  case i of red: i := 1 end;
  write(i, p = nil)
end.
