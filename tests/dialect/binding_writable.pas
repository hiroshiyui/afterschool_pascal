{ AP 6.4.3.4's third field of BindingType (ADR-0240).

  ISO/IEC 10206:1991 §6.4.3.4 NOTE 7: *"A processor may provide additional
  fields as an extension."* This is one, and what it answers is the question
  the standard leaves a program no way to ask.

  §6.7.5.6's NOTE 2 makes `binding(f).bound` the test of a binding's success,
  and doc/implementation-defined.md E.16 makes it mean *the external entity
  exists* -- which is exactly right before `reset` and exactly wrong before
  `rewrite`. A file about to be created reports false and a file already
  written reports true, so the read side has a question and the write side had
  none: `rewrite` on a name that cannot be created stops the program, and no
  conforming program could find that out first.

  `writable` is that question. It is a probe and not a promise, precisely as
  `bound` is one: a disc that fills between the two statements still stops the
  program. What it covers is every failure the *path* can be blamed for -- a
  directory that is not there, a name below a file, a directory where a file
  was meant, no permission.

  `fresh` is a program parameter the harness binds to a path in a directory of
  its own, as tests/extended/bind_missing.pas uses it, so this case writes only
  there. **Nothing here depends on what an earlier run left behind**, which is
  the same care that case takes and for a sharper reason: this one is compiled
  and run twice by selfhost/irtest.sh, so a name created by the first run is a
  name the second finds already there. The absent name is therefore never
  created, and the one that is written is rewritten before it is asked about.

  The pairing is the point of the last column. A name the answer is TRUE for
  is then actually rewritten, so a false positive stops this program. }
program binding_writable(output, fresh);
var fresh: bindable text;
    f, g: bindable text;
    b: BindingType;
    base, dir, made: string(255);
    i: integer;

{ Report, and where the answer is yes, do it. }
procedure Ask(what: string(40); path: string(255); attempt: boolean);
begin
  b := binding(f);
  if b.bound then unbind(f);
  b.name := path;
  bind(f, b);
  b := binding(f);
  write(what, ': bound=', b.bound, ' writable=', b.writable);
  if not attempt then
    writeln(' -- not attempted')
  else if b.writable then begin
    rewrite(f);
    writeln(f, 'x');
    unbind(f);
    writeln(' -- written')
  end
  else
    writeln(' -- left alone')
end;

begin
  base := binding(fresh).name;
  { The directory the harness gave us, which is the name up to its last
    separator. Every path below is built from it. }
  i := length(base);
  while (i > 0) and (base[i] <> '/') do i := i - 1;
  dir := base[1..i - 1];
  made := base + '.writable.made';

  { Put the written name into a known state, so that what the answers below
    say does not depend on which run this is. }
  b := binding(f);
  b.name := made;
  bind(f, b);
  rewrite(f);
  unbind(f);

  { Nothing is at this name and its directory admits it, and this is the
    answer `bound` cannot give: false, because there is no entity, and
    writable, because there could be. Never written, for the reason above. }
  Ask('a name nothing is at', base + '.writable.never', false);

  { A file that is there is asked about itself rather than about its
    directory -- and the write that follows is what says the answer was not
    merely optimistic. }
  Ask('one that is there', made, true);

  { A directory passes the permission test -- that is permission to create
    entries *in* it -- and then stops the program at the open. }
  Ask('the directory itself', dir, true);

  { And a name whose parent is a file, which is the same false answer one
    level down. }
  Ask('below a file', made + '/deeper', true);

  { No such directory anywhere. }
  Ask('under a missing directory', '/no-such-directory-at-all/f.txt', true);

  { A variable bound to nothing has no external entity to report on, so it
    answers as `bound` does. A rewrite of it goes to a processor-supplied
    temporary and this field says nothing about that. }
  writeln('never bound: bound=', binding(g).bound,
          ' writable=', binding(g).writable)
end.
