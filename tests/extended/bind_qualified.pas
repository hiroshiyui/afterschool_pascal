{ ISO/IEC 10206:1991 §6.11.3's qualified name reaching a bindable variable.

  §6.7.5.6 asks whether "the variable-access f" possesses the bindability that
  is bindable, and a qualified name is a variable-access that denotes one
  symbol outright — there is no base to select from. That is what made it
  interesting: bindability used to be read off the *root* of a designator, and
  a qualified name has no root of that shape, so the question was never asked
  and every qualified variable would have answered the same way.

  Under `import ... qualified` this is the only spelling there is (§6.11.3),
  so a module that exports a bindable file cannot have it bound any other way.

  `fresh` is a program parameter the harness binds to a path in a directory of
  its own, and the name below is built from it -- so no answer here depends on
  what an earlier run left behind. It used to bind a fixed `bind_qualified.tmp`
  and report `bound = TRUE` for a file nothing had created yet, which passed
  only in a build tree where an earlier run had left one (ADR-0172, and
  bind_missing.pas's header for the same sentence). }
program bind_qualified(output, fresh);

import logging qualified;

var b: BindingType;
    fresh: bindable text;
    nm: string(255);

begin
  nm := binding(fresh).name + '.bind_qualified';
  b.name := nm;
  bind(logging.logfile, b);
  { E.16 (ADR-0172): `bound` asks whether the entity exists *now*, so it is
    asked after the `rewrite` that makes one -- which is the discipline
    bind_missing.pas's header states, and the only one that holds under
    irtest.sh, where every case in the corpus shares one scratch directory.
    That a name nothing is at answers FALSE is bind_missing.pas's business;
    what this case is about is the qualified name reaching the variable. }
  rewrite(logging.logfile);
  writeln('bound = ', binding(logging.logfile).bound);
  writeln('name  = ', binding(logging.logfile).name = nm);
  writeln(logging.logfile, 'a line through a qualified name');
  unbind(logging.logfile);
  writeln('after unbind = ', binding(logging.logfile).bound)
end.
