{ Five things ISO/IEC 10206:1991's grammar admits and this compiler refused.

  All five were found the same way: by probing every production of Annex A with
  a compiled program, rather than by a test failing. None of them appeared
  anywhere in the corpus, so 396 files compared between two compilers, 43 SMT
  proofs and a closed bootstrap all agreed the compiler was finished. This
  program is the corpus entry that was missing (ADR-0071). }
module names(output);
  export named = (point, vector, low, high, origin);
  type
    point = record x, y: integer end;
    vector(n: integer) = array [1..n] of real;
  const
    low = 1;
    high = 4;
  var
    origin: point;
end;
  to begin do
    begin origin.x := 0; origin.y := 0 end;
end.

program sweepgaps(output);
import named;

type
  { §6.4.7's *first* alternative, `identifier '=' schema-name`. The clause
    makes the new identifier denote *the* schema rather than a copy of it, and
    §6.4.8 keys a produced type on (schema, tuple) — so `vec2(3)` and
    `vector(3)` are one type, which is what the assignment below proves. It is
    the same tokens as a type-definition naming a type, so the symbol decides. }
  vec2 = vector;
  qvec = named.vector;

  { §6.11.3's qualified name in the four type positions that read a bare
    identifier: a pointer's domain (§6.4.4), a restricted type (§6.4.2.5), a
    type-inquiry object (§6.4.9) and a subrange bound (§6.4.2.4). The last one
    was refused only as the *first* bound, because the scan that tells a
    subrange from a type name stopped at the `.`. }
  pp   = ^named.point;
  ps   = ^named.vector;
  rr   = restricted named.point;
  ti   = type of named.origin;
  span = named.low .. named.high;
  arr  = array [named.low..named.high] of integer;

  col = (red, green);
  { §6.4.3.4 writes the completer as `[ [ ';' ] variant-part-completer ]`, so
    the separator before `otherwise` is optional here as it is in a case
    statement. `tests/extended/otherwise_nosemi.pas` is the statement half. }
  rv = record
         k: integer;
         case t: col of
           red: (a: integer)
         otherwise (b: char)
       end;

var
  v: vector(3);
  w: vec2(3);
  q: qvec(3);
  p: pp;
  r: rr;
  o: ti;
  s: span;
  a: arr;
  rec: rv;
  c, d: char;
  str: string(9);
  i: integer;

{ §6.9.3.10: the with-element "shall possess either a type produced from a
  schema or a record-type", and each formal discriminant of the schema then
  becomes a schema-discriminant-identifier for the region that is the
  statement. Here the tuple arrives with the actual, so the discriminant is
  read from the descriptor rather than folded. }
procedure widths(var g: vector);
begin
  with g do
    writeln('param    ', n:1)
end;

begin
  { One schema under three names, so the values move between them. }
  for i := 1 to 3 do
    v[i] := i * 2.0;
  w := v;
  q := w;
  writeln('alias    ', q[2]:3:1);

  { The qualified type positions, exercised. }
  new(p);
  p^.x := 6; p^.y := 7;
  writeln('pointer  ', p^.x:1, p^.y:1);
  dispose(p);
  o.x := 8; o.y := 9;
  writeln('inquiry  ', o.x:1, o.y:1);
  s := named.high;
  a[named.low] := 5;
  writeln('subrange ', s:1, ' ', a[1]:1);
  { A restricted type has the underlying type's values and almost none of its
    operations (ADR-0058), so what it can do is assign to and from it — which
    is enough to show the qualified name resolved. }
  r := o;
  o := r;
  writeln('restrict ', o.x:1, o.y:1);

  { §6.8.3.6 table 7: the operands are "Char-type or the canonical-string-type"
    and the clause says "a and b", so *both* may be char. Every other pairing
    already worked, which is why this one was never met. }
  c := 'x'; d := 'y';
  str := c + d;
  writeln('concat   [', str, '] ', length(str):1);
  str := 'a' + 'b' + c;
  writeln('concat   [', str, '] ', length(str):1);

  { §6.8.7.3's field-list-value ends with an optional `;` that may follow a
    variant-part-value — the one of the production's three `[';']` positions
    that was missed. }
  rec := rv[k: 1; case t: red of [a: 2];];
  writeln('value    ', rec.k:1, rec.a:1);

  { A `with` over a type produced from a schema, in all three shapes: a
    constant tuple, a schematic formal parameter, and the required schema
    `string`, whose one discriminant is `capacity`. }
  with v do
    writeln('const    ', n:1);
  widths(v);
  str := 'hi';
  with str do
    writeln('string   ', capacity:1)
end.
