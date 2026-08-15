{ ISO/IEC 10206:1991 §6.4.7: a schema's body is a type-denoter, and nothing
  says it must be structured. So `counter(limit: integer) = integer` is a
  schema whose production is a *simple* type -- and §6.4.8 still makes each
  production a type of its own, distinct from `integer` and from every other
  tuple's.

  That distinctness is the whole point of this program. Simple types are shared
  singletons (ADR-0017), so writing the provenance onto the type `integer`
  resolved to would write it onto `integer` itself and make every integer in
  the program a `counter`. The compiler copies the singleton first, which is
  the one place a `Type` is duplicated rather than interned.

  No corpus program had a schema with a simple body -- every one produced an
  array or a record -- so that copy was made by nothing, in either the
  variable-declaration path or the schematic-parameter path. Found by
  tests/checks/coverage.py, which reported the copy unentered by all 497
  sources. }
program schema_simple_body(output);

type
  { One per shared singleton the copy has to handle. }
  counter(limit: integer) = integer;
  amount(places: integer) = real;
  flag(bits: integer) = boolean;
  letter(width: integer) = char;
  { A body that is *not* a singleton, for contrast: a subrange denoter builds a
    type of its own, so there is nothing to copy. }
  digit(base: integer) = 0 .. 9;

var
  c: counter(10);
  a: amount(2);
  f: flag(1);
  l: letter(1);
  d: digit(10);

{ The other path: a schematic formal resolves the body generically, with the
  discriminant bound to a symbol rather than a value (ADR-0040), and reaches
  the same copy by a different route. }
procedure show(var k: counter);
begin
  writeln('counter ', k : 1, ' of ', k.limit : 1)
end;

begin
  c := 5;
  a := 1.5;
  f := true;
  l := 'x';
  d := 7;
  show(c);
  { §6.4.7's discriminant is readable as a field of the variable, which is what
    makes the production a type and not an alias. }
  writeln(a : 4 : 1, ' ', f, ' ', l, ' ', d : 1, ' ', a.places : 1)
end.
