{ A field width wider than the runtime's formatting buffer.

  ISO 7185 §6.9.3.1 and ISO/IEC 10206:1991 §6.10.3.1 bound TotalWidth from
  *below* -- it "shall be greater than zero" -- and say nothing about how
  large it may be. So a width is whatever the program wrote, and until
  ADR-0370 that cost nothing: every write primitive handed its width to
  `fprintf`, which sizes its own output.

  ADR-0370 replaced the `FILE *` with a destination that may be memory, and
  the formatting now goes through `vsnprintf` into a buffer of 256 bytes.
  That introduces a boundary no program could cross before, and this is the
  program that crosses it: `runtime-coverage` reported the wider path as a
  line nothing ran, which is the whole reason this case exists.

  It crosses it on **both** destinations. `writestr` is the one that grows a
  buffer of its own, so a wide field there exercises the formatter and the
  growth together; `write` to a text takes the other branch of the same
  emitter. The widths are over 256 and none is round, so a fencepost shows up
  as a wrong number instead of hiding in a wall of spaces -- which is also
  why what is compared is the *length* and one visible end. }
program write_wide_field(output);
var
  s: string(400);

procedure Report(what: string; padded: string);
begin
  writeln(what, ': ', Length(padded):3, ' ending ',
          padded[Length(padded) - 2 .. Length(padded)])
end;

begin
  { The formatter's own path, `%*lld` and `%*c`, on the memory destination. }
  writestr(s, 42:280);            Report('integer  ', s);
  writestr(s, 'x':301);           Report('char     ', s);
  { These pad through the emitter a byte at a time rather than through the
    formatter -- the same clause, the other route. }
  writestr(s, 'ab':299);          Report('string   ', s);
  writestr(s, true:270);          Report('boolean  ', s);
  { A real assembles its digits first and pads afterwards. }
  writestr(s, 1.5:290:2);         Report('real     ', s);

  { And the same widths onto a text, which is the branch that still reaches
    a stream. Only the ends are compared, for the reason above. }
  writeln('to a text:');
  writeln(42:280, '|');
  writeln('x':301, '|');
  writeln(1.5:290:2, '|')
end.
