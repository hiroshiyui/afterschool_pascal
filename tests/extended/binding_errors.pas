{ What binding refuses, and the clause each rule comes from. }
program BindingErrors(output);
type btext = bindable text;
     eight = packed array [1..8] of char;
var f: text;
    g: btext;
    n: integer;
    b: BindingType;
    s: string(5);

{ a value parameter of a variable-string type would have to convert its
  argument, and there is nowhere yet to build the conversion (ADR-0052) }
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
  { §6.4.3.4 gives BindingType exactly two required fields }
  n := b.size;
  padded('abc');
  writeln(n:1, s)
end.
