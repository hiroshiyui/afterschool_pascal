{ `rewrite(output)` and `reset(input)` are the two of the six that are not
  errors, and this is the half of that pair the corpus had never written.

  §6.6.5.2 makes `rewrite(f)` discard the file and put it into the generating
  mode, which is what `output` is already in and has nothing to discard: the
  characters already written are gone from the program's reach the moment they
  are written. So doing nothing is the whole of the effect available, and
  "nothing" here has to include the line state — §6.9.5's `page` performs an
  implicit `writeln` only "if f.L is not empty", and a rewrite that reset that
  flag would put a blank line into the middle of this program's output.

  The `page` is what makes the claim observable. Without it a rewrite that
  quietly cleared the flag would print exactly what a correct one prints. }
program RewriteOutput(output);
begin
  write('before');
  rewrite(output);
  page(output);
  writeln('after');
  { And again with nothing written since the page, where `page` must *not*
    add a line — the file is at the start of one. }
  rewrite(output);
  page(output);
  writeln('done')
end.
