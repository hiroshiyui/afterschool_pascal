{ §6.7.5.1's `extend` on the standard output, which is not an error: the file
  is already positioned after its last component, so "position it there" is
  where it is. The line state has to survive it for the reason
  `tests/rewriteoutput.pas` gives about `rewrite` — §6.9.5's `page` is what
  makes the difference visible, and without it a wrong answer prints the same
  characters as a right one. }
program ExtendOutput(output);
begin
  write('before');
  extend(output);
  page(output);
  writeln('after')
end.
