{ ISO 7185 6.4.3.3 gives a field-identifier's defining-point "the region that
  is the record-type closest-containing the field-list", and 6.2.2.4 makes the
  scope of a defining-point the whole of its region "and all regions enclosed
  by that region". So inside a record type-denoter a name spelled like a field
  of that record -- or of any record it is written inside -- is an applied
  occurrence of the field-identifier, and 6.4.4's

    domain-type = type-identifier

  has nothing to bind to. The suite's DEV043 is the first record below.

  This is not 6.2.2.9's order rule and does not weaken its pointer-domain
  exception, which is about a defining-point not having to *precede* the
  domain and says nothing about which region an identifier belongs to.
  tests/pointer_domain_shadow.pas is that exception's test and stays green.

  Every pointer domain here that names a real type must go unreported, which
  is why `cell` is written in three places: the check is a question about
  fields, not a ban on pointers inside records. }
program PointerDomainField(output);
type
  cell = integer;
  arm  = 1..2;

  { DEV043: `fred` is the field two lines down, not the type after the end }
  rec = record
          ptr  : ^fred;
          fred : integer;
          ok1  : ^cell
        end;
  fred = rec;

  { All enclosing regions, not only the closest: `alpha` is a field of the
    outer record and the pointer that names it is written in the inner one. }
  nest = record
           alpha : integer;
           inner : record
                     beta : integer;
                     p    : ^alpha;
                     q    : ^beta;
                     ok2  : ^cell
                   end
         end;
  alpha = integer;
  beta  = char;

  { A variant arm's field-list is a field-list, and a tag-field is a field. }
  vrec = record
           case tag : arm of
             1 : (gamma : integer;
                  r     : ^gamma);
             2 : (s     : ^tag;
                  ok3   : ^cell)
         end;
  gamma = integer;
  tag   = integer;
var
  n: nest;
  v: vrec;
  w: rec;
begin
  writeln('unreached ', n.alpha, v.tag, w.fred)
end.
