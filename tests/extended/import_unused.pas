{ 6.2.3.6: a module that supplies the main-program-block is activated whether
  or not this component names anything of it.

  `silence` is imported and nothing of it is used -- `x` is never written. The
  two lines the module itself writes are what proves it was activated, and the
  program building at all is what proves it was declared: the defect this pins
  emitted a call to `@m.silent.fini` into a module that declared no such
  symbol, so `clang` refused the file and no executable existed to run.

  `counting` is imported *and* used, so the case holds both shapes at once and
  a fix that declared every module unconditionally would not be distinguishable
  from one that declared only the missing kind. }
program ImportUnused(output);

import silence; counting;

begin
  writeln('program: starting, tally = ', tally:1);
  bump(5);
  writeln('program: after bump, tally = ', tally:1)
end.
