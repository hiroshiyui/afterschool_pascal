{ §6.7.5.6: bind(f, b) "shall attempt to bind the accessed variable to an
  entity that is external to the program and that is designated by b. The
  binding shall be implementation-defined." NOTE 2 then gives binding(f) as
  the way "to test the success of binding a variable to an external entity" —
  so a binding that is not to anything is the standard's own design, and the
  test for it is binding(f).bound.

  This processor's binding (doc/implementation-defined.md E.16): the variable
  is bound to an external entity when the entity exists, asked whenever
  `binding` is called. So a name nothing is at answers false; the same
  variable answers true once rewrite has created the file. The only way a
  conforming program had to learn that a file was missing was the stop at
  reset — "cannot open for reading" — which no program can recover from. Now
  it can ask first.

  What is deliberately kept: a program that does not ask and resets anyway
  still stops with the same message, at the end of this one. A name nothing
  is at does not turn the variable into a scratch file, because reading
  nothing where a file was named is the one outcome worse than stopping.

  `fresh` is a program parameter the harness binds to a path in a directory
  of its own; the names below are built from it so that the case writes only
  there. The absent name is never created, so its answers do not depend on
  what an earlier run or an earlier case left behind; the created name is
  rewritten before it is asked about, for the same reason. }
program bind_missing(output, fresh);
var f: bindable text; fresh: bindable text; b: BindingType; s: string(40);
    absent, made: string(255);
begin
  absent := binding(fresh).name + '.bind_missing.absent';
  made := binding(fresh).name + '.bind_missing.made';

  b := binding(f);
  b.name := absent;
  bind(f, b);
  writeln('nothing there: bound=', binding(f).bound);

  { not bound to anything, so binding it again is not the dynamic-violation
    trap_bind_twice.pas pins }
  bind(f, b);
  writeln('bound again: bound=', binding(f).bound);
  unbind(f);

  { the name is kept whatever the answer, so rewrite creates the file -- and
    the same variable is then bound }
  b.name := made;
  bind(f, b);
  rewrite(f);
  writeln(f, 'written');
  writeln('after rewrite: bound=', binding(f).bound,
          ' same name=', binding(f).name = made);

  reset(f);
  readln(f, s);
  writeln('read back: ', s);
  unbind(f);
  writeln('after unbind: bound=', binding(f).bound);

  { a program parameter's binding is unchanged by this: output answers as
    unbound, E.19 }
  writeln('output: bound=', binding(output).bound);

  { an unchecked reset of a name nothing is at stops, as it always did -- a
    fixed name here, because the stop names it and a golden has to hold it }
  b.name := '/nonexistent-apascal-dir/bind_missing.txt';
  bind(f, b);
  if not binding(f).bound then writeln('unbound, and resetting anyway');
  reset(f);
  writeln('not reached')
end.
