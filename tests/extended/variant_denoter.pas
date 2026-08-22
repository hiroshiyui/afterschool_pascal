{ ISO/IEC 10206:1991 6.4.3.4: "A variant-denoter shall not contain a
  type-denoter denoting either a restricted-type or the bindability that is
  bindable or denoting a structured-type having any component whose
  type-denoter is not permissible as a type-denoter contained by a
  variant-denoter."

  Extended Pascal only. Neither `restricted` nor `bindable` is a word-symbol
  under ISO 7185, so there the rule has nothing to bite on -- and ISO 7185's
  own 6.4.3.3, which is this clause under the other numbering, carries no such
  sentence.

  This is a violation and not an error: Annex D's D.3 for 6.4.3.4 is the
  discriminant-selector rule and says nothing about a variant-denoter, so
  clause 5.1 e) obliges a processor to report it and refuse to activate the
  program.

  The restriction is on the *variant-denoter* and on nothing else, which is
  what `ok` below is here to hold: the same two types in a fixed part are
  legal and must draw no diagnostic. }
program variant_denoter(output);
type
  rint  = restricted integer;
  bint  = bindable integer;
  holds = record h: rint end;

  { Legal: a fixed part is not a variant-denoter. }
  ok = record
         a: rint;
         b: bint
       end;

  { A restricted-type, written straight into an arm. }
  bad1 = record
           case boolean of
             true:  (r: rint);
             false: (i: integer)
         end;

  { The bindability that is bindable. `bindable` is written on the definition
    rather than in the arm, because 6.4.1 makes a type-name hand on the
    bindability of its definition -- so the arm must be refused for a word it
    does not itself contain. }
  bad2 = record
           case boolean of
             true:  (b: bint);
             false: (i: integer)
         end;

  { The third limb: not the arm's own type-denoter but a component of it. }
  bad3 = record
           case boolean of
             true:  (h: holds);
             false: (i: integer)
         end;

  { The third limb again, reaching through a *variant part* rather than a
    fixed part. `nests` is refused in its own right by the rule above, and is
    then refused a second time as a component of bad4's arm -- one mistake
    reported twice, which is the shape ADR-0070 chose for the file rule and
    for the same reason: the record is still built, so the walk still answers
    about it, and a mistake reported twice is never a mistake missed. }
  nests = record
            case boolean of
              true:  (n: rint);
              false: (m: integer)
          end;

  bad4 = record
           case boolean of
             true:  (v: nests);
             false: (i: integer)
         end;

  { The recursion inside the recursion: the restricted field is in a variant
    part *of an arm* of `deep`, so finding it through bad5's arm means walking
    a nested variant-part and not merely a nested record. Nothing else in the
    corpus reaches that walk, which is how the coverage ratchet found it
    missing. }
  deep = record
           case boolean of
             true:  (p: integer;
                     case boolean of
                       true:  (q: rint);
                       false: (s: integer));
             false: (t: integer)
         end;

  bad5 = record
           case boolean of
             true:  (d: deep);
             false: (i: integer)
         end;

var good: ok; u: integer;

begin
  { 6.4.2.5 makes attribution between a restricted type and its underlying-type
    the associated value in each direction, and nothing else is possible: a
    restricted value cannot be written, so the read goes through `u`. }
  good.a := 1;
  u := good.a;
  writeln(u)
end.
