{ What a schema domain does not excuse. §6.7.5.3's tuple form of `new` is told
  from §6.6.5.3's variant-selection form by the domain and nothing else, so
  each still refuses what the other allows. }
program SchemaPointerErrors(output);
type vector(n: integer) = array [1..n] of integer;
     vp = ^vector;
     tagged = record case k: boolean of true: (a: integer); false: (b: real) end;
     tp = ^tagged;
     plain = array [1..3] of integer;
     pp = ^plain;

var p: vp;
    t: tp;
    q: pp;
    r: real;

begin
  { A schema denotes a type only once its discriminants are given, so the
    one-argument form has nothing to allocate. }
  new(p);

  { The tuple is the schema's, so its length is the schema's. }
  new(p, 1, 2);

  { §6.7.5.3: each expression's type shall be compatible with the corresponding
    formal discriminant's. }
  new(p, r);

  { dispose removes a variable that already has its tuple; there is nothing to
    choose. This is where the two forms of `new` visibly part, because for a
    variant record dispose *does* take the list. }
  dispose(p, 3);

  { A variant record's domain still takes tag values and not discriminants,
    and a domain that is neither takes no list at all. }
  new(t, true);
  new(q, 3);

  { §6.4.5: two separately written pointer types are distinct however alike
    their domains are — a schema domain is no exception. }
  q := p
end.
