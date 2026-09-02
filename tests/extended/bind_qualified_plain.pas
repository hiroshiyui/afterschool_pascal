{ The other side of tests/extended/bind_qualified.pas: the same module exports
  a file whose declaration does *not* say `bindable`, reached through
  ISO/IEC 10206:1991 §6.11.3's qualified name.

  This was `bind_qualified_bad.pas`, and the standard's answer: §6.7.5.6 makes
  binding a nonbindable file a dynamic-violation, and a qualified name has to
  answer that from one symbol rather than from a base. AP 6.5.1 (ADR-0299)
  makes every file variable bindable, so the same program is now accepted and
  the case pins the *other* claim the qualified arm has to get right -- that a
  qualified name denoting a file answers as a file, with no base to ask.

  `fresh` is a program parameter the harness binds to a path in a directory of
  its own, and the name is built from it for bind_qualified.pas's reason. }
program bind_qualified_plain(output, fresh);

import logging qualified;

var b: BindingType;
    fresh: text;
    nm: string(255);

begin
  nm := binding(fresh).name + '.bind_qualified_plain';
  b.name := nm;
  bind(logging.plainfile, b);
  rewrite(logging.plainfile);
  writeln('bound = ', binding(logging.plainfile).bound);
  writeln('name  = ', binding(logging.plainfile).name = nm);
  writeln(logging.plainfile, 'a line through a qualified name, no word');
  unbind(logging.plainfile);
  writeln('after unbind = ', binding(logging.plainfile).bound)
end.
