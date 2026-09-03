{ AP 6.9.3.15's select-statement through the dumps (ADR-0313).

  ADR-0103's lesson written down again: until a case *compares* what a dump
  writes, the walker that writes it is entered by nothing and no oracle knows
  whether it crashes -- and thirty-one walker procedures were in that state
  when the lesson was learned. The coverage sweep now runs `--dump-all` over
  every source in the corpus, so the arm below is *entered* by the behavioural
  cases; what it is not, without this file, is compared.

  All three arm forms are here, and so is the annotation: `--dump-all` walks
  the tree twice, once before Sema and once with `annotate`, so the second
  `select` line carries the number of channel arms and the first does not.
  What is printed is Sema's decision about each arm and not its spelling,
  which is the fact worth pinning -- a program's own `receive` would have been
  refused, so a printed `receive` is the required one. }
program dumpselect(output);

type Ints = channel [4] of integer;

var a, b: Ints;
    v, w: integer;
    ok: boolean;

begin
  select
    ok := receive(a, v): writeln(v:1);
    send(b, 1): writeln('sent');
    receive(b, w): writeln(w:1);
    after 10: writeln('idle')
  end;
  select
    receive(a, v): writeln(v:1)
  otherwise
    writeln('none')
  end
end.
