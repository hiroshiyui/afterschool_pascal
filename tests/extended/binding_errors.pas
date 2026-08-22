{ What binding refuses, and the clause each rule comes from. }
program BindingErrors(output);
type btext = bindable text;
     plainarr = array [1..2] of text;
     eight = packed array [1..8] of char;
var f: text;
    g: btext;
    n: integer;
    b: BindingType;
    s: string(5);
    { 6.4.3.4 gives a field "the type, bindability, and initial state denoted
      by the type-denoter of the record-section", and 6.4.3.5 says the same of
      an array's component -- so `log` and every element of `pool` are
      bindable and `plain` and every element of `flat` are not. Bindability is
      a property of the *variable-access*, not of the entire-variable it
      selects from, and asking the entire-variable was wrong in both
      directions: it refused the two that are bindable and named the container
      while doing it. }
    r: record log: btext; plain: text end;
    pool: array [1..3] of btext;
    flat: array [1..3] of text;
    { A dereference is the one shape still answered without asking. 6.4.4 lets
      a domain-type carry a bindability, so `p^` here really is bindable and
      the accepted line below is the right answer -- but `q^[1]` is not, and it
      is accepted too, because a pointer's domain reaches Sema through the
      deferred-domain machinery and the denoter's bindability does not travel
      with it. doc/implementation-defined.md 6.1 carries that as a program
      accepted that the standard requires to be rejected; the diagnostic below
      is the one it *does* produce, for a designator with no name to write. }
    pb: ^btext;
    pf: ^plainarr;

{ legal since ADR-0115: the callee's prologue converts, so this contributes no
  diagnostic -- unlike `padded` below, which is copied and cannot be padded }
procedure takes(v: string(5));
begin
  writeln(v)
end;

{ §6.4.5 d) makes every string type compatible with every other and §6.4.6 pads
  the shorter — but a value parameter is *copied*, so a shorter actual would be
  read past its end. The padding needs somewhere to be built, which is the same
  thing the variable-string value parameter above needs (ADR-0052). }
procedure padded(v: eight);
begin
  writeln(v)
end;

begin
  { §6.7.5.6: "If the variable-access f possesses a file-type, it shall be a
    dynamic-violation if the variable does not possess the bindability that is
    bindable." §6.4.1's `bindable` is the only thing that gives it — and a
    required type-identifier such as `text` never does. }
  bind(f, b);
  unbind(f);
  b := binding(f);
  { the first argument is a file variable and the second a BindingType }
  bind(n, b);
  bind(g, n);
  bind(g);
  unbind(g, b);
  n := binding(n);
  { A field and a component that are *not* bindable, which is the same rule
    answering the other way. The name written is the field, and for an element
    it is the array -- which is the right name now that the question is asked
    of the component and not of the container. }
  bind(r.plain, b);
  bind(flat[1], b);
  unbind(r.plain);
  { A component of a dereference: no entire-variable to name, so the message
    has none to write. }
  new(pf);
  bind(pf^[1], b);
  { §6.4.3.4 gives BindingType exactly two required fields }
  n := b.size;
  padded('abc');
  { And the three that are legal and were refused. A `with` binding is a field
    of the record the with opened, so it answers as the written selection does. }
  b.name := '/tmp/binding_errors_log';
  bind(r.log, b);
  bind(pool[2], b);
  with r do writeln('log bound = ', binding(log).bound);
  writeln('pool bound = ', binding(pool[2]).bound);
  unbind(r.log);
  unbind(pool[2]);
  { 6.4.4's domain-type may denote a bindability, so this one is legal. }
  new(pb);
  b.name := '/tmp/binding_errors_pb';
  bind(pb^, b);
  writeln('pb bound = ', binding(pb^).bound);
  unbind(pb^);
  writeln(n:1, s)
end.
