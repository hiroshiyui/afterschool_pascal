{ ISO/IEC 10206:1991 6.7.5.5 writes writestr's destination where a
  write-parameter goes, and since ADR-0087 the parser leaves it in the list --
  a parser with no scope cannot tell `writestr` the required procedure from one
  a program declared, so what the name denotes is Sema's to settle and moving
  the string out of the list is part of that.

  A write-parameter may carry a field width. This one may not: it is written
  *to*, not written, so a width would be describing a value that is never
  formatted. The check existed from the moment the list became an ordinary
  write-parameter-list and nothing had ever written the program that reaches
  it. }
program WriteStrWidth(output);
var s: string(20);
begin
  writestr(s:5, 'x');
  writeln(s)
end.
