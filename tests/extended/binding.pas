{ ISO/IEC 10206:1991 §6.7.5.6 and §6.7.6.8. Binding is what lets a program name
  a file *while it is running*, which ISO 7185 could not ask for at all: §6.10
  binds the program parameters before the program starts and gives it no other
  way to reach the outside.

  §6.4.3.4 gives the required type: "There shall be a record-type designated
  packed and denoted by the required type-identifier `BindingType`. For each of
  the required field-identifiers `name` and `bound`, there shall be an
  associated required field ... an implementation-defined variable-string-type
  and a type denoted by the type-denoter Boolean, respectively."

  That variable-string-type is why this feature waited for the string type
  (ADR-0051): there was nothing to give the field until §6.4.3.3 landed.

  §6.4.1's `bindable` is what makes a variable bindable at all, and §6.7.5.6
  makes binding one that is not a dynamic-violation. }
program Binding(output);
{ §6.4.1 makes bindability a property of the *type-denoter*, and a type-name
  denotes "the type, bindability and initial state" of its definition — so a
  named bindable type is what lets a *parameter* be bindable. `var t: text`
  never is, because a required type-identifier is not. }
type btext = bindable text;

var f: btext;
    g: btext;
    b: BindingType;
    c: char;
    n: integer;
    nm: string(64);
    { a *fixed*-string name, which §6.4.6 pads to its capacity — so what
      reaches `bind` ends in spaces, and a file name that does is never what
      was meant }
    padded: packed array [1..30] of char;

{ §6.7.6.8's own example, near enough: ask for the binding, change the name,
  bind, and ask again to see whether it took. NOTE 4 is the point of the second
  ask — "bind(f,b) does not set b.bound to true or false to reflect the success
  of the binding", so only `binding` can answer. }
{ The name travels as a `var` string: a *value* parameter of a string type
  would have to convert its argument — §6.4.6 pads or refuses by length, and a
  value parameter is copied bytewise — and there is nowhere yet to build the
  conversion (ADR-0052). }
procedure attach(var t: btext; var nm: string(64));
var v: BindingType;
begin
  v := binding(t);
  if v.bound then unbind(t);
  v.name := nm;
  bind(t, v);
  v := binding(t);
  writeln('bound ', v.bound, ' [', v.name, ']')
end;

procedure report(v: BindingType);
begin
  writeln('report ', v.bound, ' [', v.name, ']')
end;

begin
  { §6.7.6.8 NOTE 1: binding(f) is permitted even on a variable that is
    totally-undefined, which an unbound bindable one is (§6.5.1). }
  b := binding(f);
  writeln('start ', b.bound, ' [', b.name, ']');

  b.name := '/tmp/apascal_bind1.txt';
  bind(f, b);
  b := binding(f);
  writeln('bound ', b.bound, ' [', b.name, ']');

  { Once bound, the file behaves as any external file does — the binding is
    what `reset` and `rewrite` look up, in place of the command-line argument a
    program parameter would have had. }
  rewrite(f);
  writeln(f, 'hello from bind');
  writeln(f, 'second line');

  { §6.7.5.6: "If the attempt is successful, the variable shall become
    totally-undefined", so the name goes with it. }
  unbind(f);
  b := binding(f);
  writeln('after ', b.bound, ' [', b.name, ']');

  { NOTE 7: unbind is permitted on a variable that is not bound, and there is
    nothing to report when there was nothing to undo. }
  unbind(f);
  b := binding(f);
  writeln('again ', b.bound);

  { ...and binding it back reaches the same file. }
  b.name := '/tmp/apascal_bind1.txt';
  bind(f, b);
  reset(f);
  n := 0;
  while not eof(f) do begin
    while not eoln(f) do begin
      read(f, c);
      write(c)
    end;
    readln(f);
    writeln;
    n := n + 1
  end;
  writeln('lines ', n:1);

  { A second bindable variable, bound through a procedure. The name is built
    in a variable first, because a string value parameter is refused. }
  nm := '/tmp/apascal_bind2.txt';
  attach(g, nm);
  rewrite(g);
  writeln(g, 'other file');
  unbind(g);
  b := binding(g);
  writeln('g ', b.bound);

  { A name that arrived padded: `bind` trims the trailing spaces, and the file
    it opens is the one the program meant. }
  unbind(f);
  padded := '/tmp/apascal_bind3.txt';
  b.name := padded;
  writeln('padded ', length(b.name):1);
  bind(f, b);
  rewrite(f);
  writeln(f, 'third');
  unbind(f);
  b.name := padded;
  bind(f, b);
  reset(f);
  read(f, c); write(c); readln(f); writeln;

  { `binding(f)` denotes the hidden slot its result was built in, so it is a
    variable — which is what lets it be copied whole into another BindingType
    and passed as a value parameter. Selecting a *field* of it directly,
    `binding(f).bound`, was refused when this was written and is legal since
    ADR-0056 landed §6.8.6's function-accesses; it needed nothing of its own,
    because a call already yielded an address. This assigns first anyway, to
    keep pinning the whole-record copy. }
  b := binding(f);
  report(binding(f))
end.
