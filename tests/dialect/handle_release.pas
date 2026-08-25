{ AP 6.4.12.5: release now, and answer what the closer answered (ADR-0206).

  **Every other release throws the result away**, and `runtime/pasrt.c` says
  why in as many words: a handle is released on the way out of a block, and
  there is no statement left to report to. `release(h)` is that statement.
  What a closer answers is not decoration -- `pclose` answers the child's
  wait status and `fclose` reports a flush that failed -- so the one thing a
  handle could not do was give a caller the answer to *did that work*.

  It is `take`'s shape with the position rule removed, and the difference is
  the reason there is no rule: what `take` yields is an owned value that has
  to land somewhere, and what this yields is an **integer**. Nothing is left
  unowned by writing it in the middle of an expression.

  The closer here is `fclose`, whose result is 0 or EOF -- so the file this
  program writes and then releases reports its own successful flush, which is
  a thing no program in this tree could ask before. }
program handle_release(output, fresh);

type
  Stream = handle external 'fclose';
  { A closer whose result is *information* rather than a formality: `pclose`
    waits for the child and answers its status. This is the whole reason the
    clause exists -- with `fclose` alone every release answers 0 and a
    processor that threw the result away would look correct. }
  Child = handle external 'pclose';

var
  fresh: bindable text;
  b: BindingType;
  name: string(255);
  s, other: Stream;
  kid: Child;
  code, i: integer;

function ExtFopen(path, mode: string): Stream; external 'fopen';
function ExtFputs(text: string; f: Stream): integer; external 'fputs';
function ExtPopen(command, mode: string): Child; external 'popen';

begin
  b := binding(fresh);
  name := b.name;

  { A stream that is written and then closed by hand.  `fclose` flushes, and
    0 is what it answers when the flush succeeded. }
  s := ExtFopen(name, 'w');
  writeln('opened:   ', s <> nil);
  i := ExtFputs('two lines' + chr(10) + 'of it' + chr(10), s);
  code := release(s);
  writeln('released: ', code:1, ', and empty afterwards: ', s = nil);

  { Releasing an empty variable answers 0 and is not an error -- the
    assignment of `nil` on an empty one is harmless, and this is that
    assignment with an answer. }
  code := release(s);
  writeln('again:    ', code:1, ', still empty: ', s = nil);

  { The variable may be opened again through the same name, exactly as after
    `s := nil` (ADR-0202). }
  s := ExtFopen(name, 'r');
  writeln('reopened: ', s <> nil);
  code := release(s);
  writeln('read end: ', code:1);

  { In an expression, which is the whole of what the missing position rule
    means: an integer needs no owner. }
  other := ExtFopen(name, 'r');
  writeln('in an expression: ', release(other) = 0);

  { **A closer that answers something.** `pclose` waits for the child and
    gives back its wait status, whose second byte is the exit code -- so a
    program learns what a command it ran had to say, which before this clause
    it could only do by having the shell print the code into the output
    stream behind a marker (ADR-0206). }
  kid := ExtPopen('exit 7', 'r');
  code := release(kid);
  writeln('child:    ', (code div 256) mod 256:1);

  kid := ExtPopen('exit 0', 'r');
  writeln('and zero: ', (release(kid) div 256) mod 256:1);

  { And the block's own release finds nothing left to do, which is what makes
    calling a closer by hand possible at all: 6.4.12.3's "at most once" is
    kept by the variable being empty rather than by anyone counting. }
  s := ExtFopen(name, 'r')
end.
