{ A program-parameter that does not possess a file-type.

  6.10 makes each program-parameter a variable of the program-block and then
  says only this about what it is bound to: the binding is implementation-
  dependent, "except if the variable possesses a file-type in which case the
  binding shall be implementation-defined". So a non-file program-parameter is
  a program the standard has, and nothing anywhere restricts the list to files.
  ISO/IEC 10206:1991 6.12 drops the distinction entirely and makes every
  program-parameter's binding implementation-defined.

  This compiler refused one outright, with a message asserting a rule neither
  standard contains, and no program in the corpus had ever written one -- so
  every oracle agreed, which is ADR-0067's lesson again.

  The binding chosen here is to no external entity: `n` below is an ordinary
  variable of the program-block, undefined until the program assigns it, which
  6.12's NOTE 2 ("not necessarily bound when the program is activated") is what
  makes an available answer.

  What this pins is the half of that choice a reader would not guess: a non-file
  program-parameter consumes no command-line argument, so the file parameters
  keep the positions they would have had without it. `n` stands between `f` and
  `g` here for exactly that reason -- the harness passes two writable paths, so
  a `g` that had been pushed to argument 3 would stop the program instead of
  printing. }
program progparam_nonfile(output, f, n, g);

var
  f, g: text;
  n: integer;
  line: packed array [1..3] of char;
  i: integer;

begin
  { The first and third parameters are the first and second arguments. }
  rewrite(f);
  writeln(f, 'one');
  rewrite(g);
  writeln(g, 'two');

  { And the second is nothing but a variable. }
  n := 41;
  n := n + 1;
  writeln('n is ', n:1);

  reset(f);
  for i := 1 to 3 do
    read(f, line[i]);
  writeln('f held ', line);

  reset(g);
  for i := 1 to 3 do
    read(g, line[i]);
  writeln('g held ', line)
end.
