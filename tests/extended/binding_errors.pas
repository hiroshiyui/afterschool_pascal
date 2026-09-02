{ What binding refuses, and the clause each rule comes from.

  Fewer than there were. Until AP 6.5.1 (ADR-0299) this file also refused
  `bind` of a `text` variable, a `text` field and a `text` element for want of
  §6.4.1's word -- eight diagnostics, all of them ISO/IEC 10206:1991
  §6.7.5.6's dynamic-violation. Every file variable is bindable now, so those
  lines compile and live in tests/dialect/bind_anywhere.pas; what stays here
  is the arity, the argument types, and the one refusal the dialect keeps on
  purpose: a variable that is not a file. }
program BindingErrors(output);
type btext = bindable text;
var g: btext;
    n: integer;
    b: BindingType;
    s: string(5);
    { bindable integer is still a declaration the language accepts -- 6.9.3.9.1
      asks about it -- and still not something `bind` will take. }
    i: bindable integer;
    r: record log: btext; plain: text end;
    flat: array [1..3] of text;

begin
  { the first argument is a file variable and the second a BindingType }
  bind(n, b);
  bind(g, n);
  bind(g);
  unbind(g, b);
  n := binding(n);
  { AP 6.5.1: bindability is a property of a file variable and of nothing
    else, so §6.7.5.6's "otherwise" branch -- a non-file that says bindable --
    is refused by design, and the message says which design. }
  bind(i, b);
  unbind(i);
  b := binding(i);
  { A substring is nonbindable under §6.5.3.1 and is refused here for the
    simpler reason that it is not a file. }
  bind(s[1..2], b);
  { §6.4.3.4 gives BindingType exactly two required fields, and the dialect a
    third; `size` is none of them }
  n := b.size;
  { And the ones that are legal: the word where §6.4.1 puts it, and -- since
    AP 6.5.1 -- the same shapes without it. }
  b.name := '/tmp/binding_errors_log';
  bind(r.log, b);
  bind(r.plain, b);
  bind(flat[1], b);
  with r do writeln('log bound = ', binding(log).bound);
  unbind(r.log);
  unbind(r.plain);
  unbind(flat[1]);
  writeln(n:1, s)
end.
