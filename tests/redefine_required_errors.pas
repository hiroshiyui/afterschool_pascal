{ What a program that declares one of the six may not then write.

  ISO 7185 §6.8.2.3 gives a procedure-statement an actual-parameter-list *or*
  one of the four read/write parameter lists, and says the identifier of a
  statement containing a write-parameter-list "shall denote the required
  procedure write". So a field width and a declared `write` cannot both be in
  the same statement: the widths are the one thing that tells the two lists
  apart, and once the name is the program's the list is the ordinary one.

  The rest is what any call is held to. Nothing here is a rule of its own --
  that is the finding worth keeping, because it is what says the reading was
  chosen by the symbol and then handed to the code that checks every other
  call (ADR-0087). }
program RedefineRequiredErrors(output);
var i: integer;
    readln: integer;

procedure write(var a: integer);
begin
  a := a + 2
end;

function read(a: integer): integer;
begin
  read := a
end;

begin
  i := 0;
  { §6.8.2.3: an actual-parameter-list has no field widths. }
  write(i:4);
  { The arity and the passing mode are the ordinary rules for a call. }
  write;
  write(i, i);
  write(4);
  { §6.6.4.1 does not make a function a procedure. }
  read(i);
  { A variable is not a procedure either. }
  readln;
  writeln(i:1)
end.
