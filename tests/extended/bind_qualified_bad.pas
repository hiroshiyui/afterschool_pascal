{ The other side of tests/extended/bind_qualified.pas: the same module exports
  a file that is *not* bindable, and ISO/IEC 10206:1991 §6.7.5.6 refuses it
  through a qualified name exactly as it does through a bare one.

  Worth its own case because the two answers come from different arms — a
  qualified name denotes one symbol and has no base to select from, so it is
  neither the entire-variable arm nor the field arm — and because a check that
  answered "bindable" for every qualified name would leave this program
  compiling and `bind` attaching a name to a variable the standard says cannot
  hold one. }
program bind_qualified_bad(output);

import logging qualified;

var b: BindingType;

begin
  b.name := 'bind_qualified_bad.tmp';
  bind(logging.plainfile, b);
  unbind(logging.plainfile);
  writeln(binding(logging.plainfile).bound)
end.
