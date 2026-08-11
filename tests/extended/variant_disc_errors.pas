{ What a discriminant-selected variant part refuses. §6.4.3.4 offers the
  tag-field to the tag-type form only, and §6.7.5.3 requires a tag-type of
  every variant part a tag value selects — so the two ways of naming a
  selector twice are both errors. }
program VariantDiscErrors(output);
type kind = (round, square);

     { §6.4.3.4's variant-selector is `[tag-field ':'] tag-type` *or* a
       discriminant-identifier: a field would be a second place to keep a
       value the tuple already fixes, and one the program could then assign. }
     named(k: kind) = record case t: k of round: (a: integer);
                                          square: (b: integer) end;

     { The labels are the discriminant's type, and a label of another type is
       the mismatch it always was — the tag being a discriminant changes
       nothing about what may label an arm. }
     wrong(n: integer) = record case n of round: (a: integer) end;

     shape(k: kind) = record case k of round: (r: integer);
                                       square: (s: integer) end;
     one = shape(round);
     op = ^one;

     { The refusal is per variant part and not per record: an outer part with a
       tag-type is selectable, and the one nested inside the arm it selects is
       not. `new` walks into the arm and asks again. }
     nest(k: kind) = record
       case t: boolean of
         true: (case k of round: (a: integer); square: (b: integer));
         false: (z: integer)
     end;
     nested = nest(square);
     np = ^nested;

     { Outside a schema body no name is a discriminant, so `case k of` is the
       tag-type form and `k` is simply not a type. }
     plain = record case k of round: (a: integer); square: (b: integer) end;

var p: op;
    m: np;
    n: named(round);
    w: wrong(1);
    q: plain;

begin
  { §6.7.5.3: the variant part corresponding to each case-constant "shall
    closest-contain a tag-type". This one contains a discriminant, and its
    variant was settled when `shape(round)` was produced. }
  new(p, round);
  dispose(p, round);

  { The first value is fine — `t` is a tag-type — and the second is not. }
  new(m, true, round)
end.
