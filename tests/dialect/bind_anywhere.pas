{ Every file variable is bindable (AP 6.5.1, ADR-0299), and this is the program
  that says so in all four shapes ISO/IEC 10206:1991 §6.4.1 could not reach.

  §6.4.1 makes `bindable` part of the type-denoter of a declaration, and
  §6.7.5.6 makes `bind` of a file that does not possess it a
  dynamic-violation. So a `var f: text` formal was refused -- which is
  §6.7.6.8's own worked example, `procedure bindfile(var f: text)` -- and so
  were `p^` for `p: ^text`, a record's `text` field and an array's `text`
  element, each for want of one word its position could not always carry. The
  dialect makes the file-type the whole of the question: a designator whose
  type is a file is bindable, and the word is accepted and redundant.

  Each shape is bound to a name built from `fresh`, a program parameter the
  harness binds to a path in a directory of its own, written, read back and
  unbound. `ints` is a `file of integer`, which is here to say the rule is
  "a file" and not "a text". Nothing below says `bindable`. }
program bind_anywhere(output, fresh);

type
  entry = record log: text; count: integer end;
  shelf = array [1..2] of text;

var
  fresh: text;
  p: ^text;
  r: entry;
  a: shelf;
  ints: file of integer;
  b: BindingType;
  base: string(255);
  n: integer;

{ §6.7.6.8's example, as printed there but for the name it builds. }
procedure bindfile(var f: text; suffix: string);
begin
  b.name := base + suffix;
  bind(f, b)
end;

{ Write one line through whatever file variable arrived, and read it back
  through the same one -- so the parameter is bound, written, reset and read
  without the caller ever naming the file. }
procedure roundtrip(var f: text; suffix, what: string);
var line: string(80);
begin
  bindfile(f, suffix);
  rewrite(f);
  writeln(f, what);
  reset(f);
  readln(f, line);
  writeln(suffix, ': ', line, ' (bound=', binding(f).bound, ')');
  unbind(f);
  writeln(suffix, ': after unbind bound=', binding(f).bound)
end;

begin
  base := binding(fresh).name;
  { 1. a var parameter of type text -- the formal itself is the designator }
  roundtrip(fresh, '.param', 'through a parameter');
  { 2. an identified-variable, p: ^text with no word in the domain }
  new(p);
  roundtrip(p^, '.deref', 'through a pointer');
  dispose(p);
  { 3. a field, written as a selection and again through a with }
  roundtrip(r.log, '.field', 'through a field');
  with r do begin
    bindfile(log, '.with');
    rewrite(log);
    writeln(log, 'through a with');
    reset(log);
    writeln('.with: bound=', binding(log).bound);
    unbind(log)
  end;
  { 4. an element }
  roundtrip(a[2], '.elem', 'through an element');
  { and a file that is not a text }
  b.name := base + '.ints';
  bind(ints, b);
  rewrite(ints);
  write(ints, 42);
  reset(ints);
  read(ints, n);
  writeln('.ints: ', n:1, ' (bound=', binding(ints).bound, ')');
  unbind(ints)
end.
