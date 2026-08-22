{ ISO/IEC 10206:1991 §6.11.3's qualified name reaching a bindable variable.

  §6.7.5.6 asks whether "the variable-access f" possesses the bindability that
  is bindable, and a qualified name is a variable-access that denotes one
  symbol outright — there is no base to select from. That is what made it
  interesting: bindability used to be read off the *root* of a designator, and
  a qualified name has no root of that shape, so the question was never asked
  and every qualified variable would have answered the same way.

  Under `import ... qualified` this is the only spelling there is (§6.11.3),
  so a module that exports a bindable file cannot have it bound any other way. }
program bind_qualified(output);

import logging qualified;

var b: BindingType;

begin
  b.name := 'bind_qualified.tmp';
  bind(logging.logfile, b);
  writeln('bound = ', binding(logging.logfile).bound);
  writeln('name  = ', binding(logging.logfile).name);
  rewrite(logging.logfile);
  writeln(logging.logfile, 'a line through a qualified name');
  unbind(logging.logfile);
  writeln('after unbind = ', binding(logging.logfile).bound)
end.
