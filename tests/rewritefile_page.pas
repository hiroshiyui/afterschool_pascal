{ The other half of `tests/rewriteoutput.pas`, and it answers the opposite way.

  §6.9.5's `page(f)` performs an implicit `writeln(f)` "if f.L is not empty and
  if f.L.last is not the end-of-line component", so the runtime carries one
  flag saying whether the file is at the start of a line. §6.6.5.2's `rewrite`
  discards the file — and for an *ordinary* file that empties it, so the flag
  must go back to saying "at the start of a line".

  On `output` it must not, and that is what rewriteoutput.pas pins: there is
  nothing to discard, the characters having left the program's reach when they
  were written, so a rewrite that cleared the flag would put a blank line into
  the middle of the output. One flag, two answers, decided by which file it is.

  Here the file is left mid-line, rewritten, and paged. The form feed must be
  the first character: a blank line before it is the bug. }
program RewriteFilePage(output);
var f: text; n: integer;

begin
  rewrite(f);
  write(f, 'x');   { left mid-line, and then discarded }
  rewrite(f);
  page(f);
  write(f, 'y');
  reset(f);
  n := 0;
  while not eof(f) do begin
    if eoln(f) then
      write('|')
    else if f^ = chr(12) then
      write('^')
    else
      write(f^);
    get(f);
    n := n + 1
  end;
  writeln;
  { The trailing `|` is §6.6.5.2's appended end-of-line — see
    tests/eoln_appended.pas — so three components, not two. }
  writeln('count ', n:1)
end.
