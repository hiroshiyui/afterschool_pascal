{ ISO 7185 §6.9.5's page.

  "Page(f) shall cause an implementation-defined effect on the textfile f, such
  that subsequent text written to f will be on a new page if the textfile is
  printed on a suitable device, shall perform an implicit writeln(f) if f.L is
  not empty and if f.L.last is not the end-of-line component, and shall cause
  the buffer-variable f^ to become totally-undefined."

  So one part of it is the implementation's to choose — the effect, here the
  ASCII form feed, which is what a printer and every other Pascal mean by it —
  and the rest is fixed. The fixed part is the interesting one: the implicit
  writeln happens only when the current line has something on it, so `page`
  never writes a blank line before the separator and never leaves a partial
  line stranded on the previous page.

  A form feed is not a printable character, so this test writes markers around
  it and the golden file holds the byte itself. }
program page(output, f);
var f: text;
begin
  { The line is empty: page writes the separator alone. }
  page(output);
  writeln('first page');

  { The line has something on it, so an implicit writeln comes first — the
    'x' must not end up on the next page. }
  write('x');
  page(output);
  writeln('second page');

  { And after a writeln the line is empty again, so no blank line appears. }
  writeln('done');
  page(output);
  write('third page');
  writeln;

  { Without an argument the file is output, which §6.9.5 requires the program
    to name — this one does, in its header. }
  page;
  writeln('after the bare form');

  { Any text file, not only output. }
  rewrite(f);
  write(f, 'a');
  page(f);
  write(f, 'b');
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
