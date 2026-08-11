{ ISO/IEC 10206:1991 §6.4.3.4 spells a variant-selector

      [ tag-field ':' ] tag-type | discriminant-identifier

  so a variant part inside a schema body may be selected by one of the
  schema's own discriminants. The selector is then not a field — the tuple
  already holds it, and §6.4.3.4 calls attributing another value to it a
  dynamic-violation — so the *layout* is a tagless `case T of` and nothing in
  codegen changes. What decides the variant is the tuple the type was produced
  with, which is what makes a discriminated union out of a schema. }
program VariantDisc(output);
type kind = (round, square, box);
     shape(k: kind) = record
       name: char;
       case k of
         round: (r: integer);
         square: (side: integer);
         box: (w, h: integer)
     end;
     sp = ^shape;

     { A nested variant part may be selected by a second discriminant, and a
       discriminant-selected one may sit inside a tag-selected arm. Neither is
       a special case: an arm's field-list is a field-list like any other. }
     both(a, b: kind) = record
       case a of
         round: (case b of
                   round: (x: integer);
                   square, box: (y: integer));
         square, box: (case t: kind of
                         round: (u: integer);
                         square, box: (v: integer))
     end;

var s: shape(round);
    q: shape(box);
    p: sp;
    e: both(round, square);
    f: both(square, round);
    which: kind;

{ A schematic formal takes any tuple, so one compiled body serves every
  variant: `v.k` reads the discriminant out of the descriptor and the case
  statement branches on it. This is the whole point of the feature — the tag
  travels with the type rather than in the record. }
procedure show(var v: shape);
begin
  write(v.name, ' ');
  case v.k of
    round: writeln('round ', v.r:1);
    square: writeln('square ', v.side:1);
    box: writeln('box ', v.w:1, 'x', v.h:1)
  end
end;

begin
  s.name := 's'; s.r := 7; show(s);
  q.name := 'q'; q.w := 2; q.h := 3; show(q);

  { §6.4.4's domain-type is a bare schema-name, so `new(p, box)` supplies the
    tuple (ADR-0043) — and the tuple is what selects the variant. The two
    readings of the argument list coincide here, which they can only because
    the domain says which one it is. }
  new(p, box);
  p^.name := 'p'; p^.w := 4; p^.h := 5; show(p^);
  dispose(p);

  { The discriminant need not be a constant: the variant a heap variable
    carries is chosen when `new` runs. }
  which := square;
  new(p, which);
  p^.name := 'n'; p^.side := 9; show(p^);
  dispose(p);

  { A nested selector, and one arm's variant part selected by a tag field of
    its own — the two forms side by side in one type. }
  e.y := 11;
  writeln('e ', e.y:1);
  f.t := round; f.u := 12;
  writeln('f ', ord(f.t):1, ' ', f.u:1);

  { §6.4.8: one schema with one tuple is one type, and the discriminants are
    readable as fields wherever the variable is. }
  writeln('kinds ', ord(s.k):1, ord(q.k):1, ord(e.a):1, ord(e.b):1)
end.
