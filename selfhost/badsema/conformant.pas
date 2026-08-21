{ ISO 7185 6.6.3.7 and 6.6.3.8's refusals. Sema accumulates, so they share a
  file the way every other badsema case does. }
program p(output);
type
  rec = record f: text end;
  vecr = array [1..3] of rec;
  vec = array [1..3] of integer;
  other = array [4..6] of integer;
var
  x: vec;
  y: other;
  r: vecr;

{ 6.6.3.7: the index type is an ordinal-type-identifier }
procedure notordinal(var a: array [u..v: real] of integer);
begin end;

{ 6.6.3.7.2: "The fixed-component-type of a value conformant array shall be one
  that is permitted as the component-type of a file-type." }
procedure withfile(a: array [u..v: integer] of rec);
begin end;

{ 6.6.3.7.1: every actual of one specification possesses the same type }
procedure twonames(var a, b: array [u..v: integer] of integer);
begin end;

{ 6.6.3.7.2's last requirement, and its NOTE: the auxiliary variable's size
  has to be known where the copy is made }
procedure byvalue(a: array [u..v: integer] of integer);
begin end;

procedure handson(var a: array [u..v: integer] of integer);
begin byvalue(a) end;

{ 6.6.3.7.3: the actual of a *variable* conformant array is a variable-access,
  and 6.5.1's four do not include a parenthesised expression }
procedure needsvar(var a: array [u..v: integer] of integer);
begin end;

{ 6.6.3.8's four statements, each refused by its own program below }
procedure wantschar(var a: array [u..v: integer] of char);
begin end;

begin
  twonames(x, y);
  handson(x);
  needsvar(3);
  needsvar((x));
  wantschar(x)
end.
