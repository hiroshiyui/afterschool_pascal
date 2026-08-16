{ ISO 7185 §6.9.5: `page` performs an implicit `writeln(f)` "if f.L is not
  empty and if f.L.last is not the end-of-line component".

  `tests/page.pas` already pins that rule -- but every line it writes is made
  of a string or a character, and the runtime tracked "the line has something
  on it" in five write primitives out of six. `pas_write_real` was the one that
  did not, so a real was the one value that could be written and leave the line
  looking empty. `write(1.5); page` then wrote the form feed with no line
  terminator before it, and the 1.5 was stranded on the previous page.

  Nothing had ever looked: six programs in this corpus call `page`, and not one
  of them writes a real first. Every oracle agreed, and
  `doc/implementation-defined.md` E.30 asserted the rule the code did not keep
  -- which is ADR-0067 exactly, a claim no test names.

  So this is `page.pas` again with the one value that was missing, in all three
  of the forms that reach `pas_write_real`: the floating-point form, the same
  with a field width, and the fixed-point form. The width matters because
  §6.10.3.1 admits a TotalWidth of zero for some types, so "was anything
  written" cannot be answered by "was a write attempted".

  A form feed is not a printable character, so the file half of this test
  writes markers around it and the golden holds the byte itself. }
program page_after_real(output, f);
var f: text;
begin
  { The fixed-point form first, because its representation is exactly the
    characters written and the golden can be read by eye. }
  write(3.5:8:2);
  page(output);
  writeln('after a fixed-point real');

  { A field width does not change the answer: eight characters were written,
    so the line is not empty. }
  write(1.5:6:1);
  page(output);
  writeln('after a widened real');

  { And the floating-point form, which is where the default TotalWidth is this
    implementation's own choice (E.24) and is nineteen characters. }
  write(2.5);
  page(output);
  writeln('after a floating-point real');

  { After a writeln the line is empty again, so no blank line appears -- the
    same half of the rule page.pas checks for a string. }
  writeln(4.5:6:1);
  page(output);
  writeln('after a writeln');

  { Into a text file rather than output, and read back, so the implicit line
    terminator is an ordinary component and the line structure is visible. }
  rewrite(f);
  write(f, 5.5:6:1);
  page(f);
  write(f, 'z');
  writeln(f);
  reset(f);
  while not eof(f) do begin
    if eoln(f) then begin
      readln(f);
      writeln('[eoln]')
    end
    else begin
      if f^ = chr(12) then write('[ff]') else write(f^);
      get(f)
    end
  end;
  writeln('file done')
end.
