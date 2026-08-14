{ ISO/IEC 10206:1991 §6.7.5.5's `readstr` and `writestr` are required
  *identifiers*, so §6.2.2.10 makes them shadowable exactly as ISO 7185's four
  are -- which is what retired ADR-0060's stated deviation, the one that said
  "under the extended standard the two names are not usable for anything
  else".

  It costs more here than for the other four, and the reason is the parameter
  list rather than the name. §6.7.5.5 writes it as `'(' string-variable ','
  write-parameter, ... ')'`, and a parser that requires that comma has already
  decided the statement is a writestr. So the list is parsed as an ordinary
  write-parameter-list and Sema moves the string out of it, once the name has
  been looked up and the required procedure is what it denotes (ADR-0087).

  The declarations are nested rather than the program-block's, so both
  readings appear in one program: §6.2.2.10 puts the required ones in a region
  enclosing the program, which a nested block hides and the program-block does
  not reach into. }
program RedefineStringTransfer(output);
type s8 = string(8);
var t: s8; a, b: integer;

procedure shadowed;
var n: integer;

  procedure writestr(x, y: integer);
  begin
    writeln('writestr ', x + y:1)
  end;

  { In an expression, so it was never the parser's to decide: a name with an
    argument list is a call there whatever the name is. This is the half that
    always worked, kept beside the half that did not. }
  function readstr(k: integer): integer;
  begin
    readstr := k * 3
  end;

begin
  writestr(1, 2);
  n := readstr(5);
  writeln('readstr  ', n:1)
end;

begin
  { Nothing hides them here, so both words mean §6.7.5.5's procedures -- and
    the writestr carries a field width, which no actual-parameter-list has. }
  writestr(t, 4:3);
  writeln('required ', t, '.');
  readstr('12 34', a, b);
  writeln('required ', a:1, ' ', b:1);
  shadowed
end.
