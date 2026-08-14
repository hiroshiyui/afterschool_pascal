{ ISO 7185 §6.2.2.10: required identifiers "shall be used as if their
  defining-points have a region enclosing the program", and §6.6.4.1 is the
  procedures' half of that. So a program may declare its own `write`, and the
  one it declared is what its statements activate.

  Every other required procedure already had this -- they are not symbols, and
  a name that resolves to nothing is what means "the required one". The
  read/write family did not, because the parser has to recognise those six
  words to parse the field widths of §6.8.2.3's write-parameter-list, and so
  it decided the question before there was a scope to ask it (ADR-0087).

  The first statement is the BSI Pascal Validation Suite's CONF116, which is
  where this came from: `write(i)` with an integer variable is a legal write
  *and* a legal call of the procedure below, and only the declaration says
  which. Before the fix this program printed 0 and reported nothing. }
program RedefineRequired(output);
var i: integer;

{ Declared in the program-block, so the required `write` is hidden for the
  whole of it -- the enclosing region §6.2.2.10 puts the required one in is
  outside this, not between this and a nested block. There is deliberately no
  `write` statement anywhere below. }
procedure write(var a: integer);
begin
  a := a + 2
end;

{ Shadowing one of the six leaves the other five alone, and a required name
  may be a variable as easily as a procedure -- `read := 5` is an assignment,
  which is a statement no parameter list begins. }
procedure reading;
var read: integer;
begin
  read := 5;
  writeln('read    ', read:1)
end;

{ §6.6.3.7 forbids an actual parameter that denotes a required procedure --
  there is nothing to pass, `write` taking a variable number of arguments of
  types no parameter list can spell. The one above is not that procedure, so
  it is passed like any other. Nothing was written to make this work: the
  refusal was always reached only when the name resolved to nothing. }
procedure applying;
var n: integer;

  procedure apply(procedure p(var x: integer); var v: integer);
  begin
    p(v)
  end;

begin
  n := 4;
  apply(write, n);
  writeln('applied ', n:1)
end;

{ The read half of the first statement, and the harder one: `readln` written
  alone is a complete statement under §6.9.2 *and* a complete call of the
  procedure below, so neither the name nor the tokens after it decide -- only
  the declaration does. `read(n)` is the same question with an argument list.
  Nothing is read from `input`, which this program does not list. }
procedure taking;
var n: integer;

  procedure read(var a: integer);
  begin
    a := 9
  end;

  procedure readln;
  begin
    writeln('readln  called')
  end;

begin
  n := 0;
  read(n);
  readln;
  writeln('taking  ', n:1)
end;

{ A redefined `writeln` writes nothing, so what this pins is an absence: the
  required one would have ended a line here, and the golden has no blank. It
  also shows the declaration need not be the program-block's. }
procedure quiet;
  procedure writeln;
  begin
  end;
begin
  writeln;
  writeln
end;

{ `writeln` is not declared anywhere enclosing this, so here the word still
  means §6.9.4's required procedure -- with the file and the field width that
  make its parameter list a writeln-parameter-list rather than an
  actual-parameter-list. }
procedure required;
begin
  writeln(output, 'required ', 7:1)
end;

begin
  i := 0;
  write(i);
  write(i);
  writeln('write   ', i:1);
  reading;
  applying;
  taking;
  quiet;
  required
end.
