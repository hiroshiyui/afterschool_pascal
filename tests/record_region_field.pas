{ ISO 7185 6.4.3.3 and 6.2.2.4, at every occurrence of a type-name inside a
  record other than the pointer domain -- which is the one occurrence that was
  enforced, and which tests/pointer_domain_field.pas pins.

  The clause does not name a production. A field-identifier's defining-point
  has "the region that is the record-type closest-containing the field-list",
  and the scope of a defining-point is the whole of its region "and all regions
  enclosed by that region", so *any* applied occurrence of that spelling
  anywhere inside the record denotes the field. A field is not a type, so
  wherever a type-name was wanted there is nothing to bind to (ADR-0112).

  Every occurrence here that names a real type must go unreported, which is why
  each record carries an `ok` field: the rule is a question about fields, not a
  ban on writing type-names inside a record.

  Two of the messages below are second ones about the same line -- an index
  type and a set base type each get a further complaint once the name has not
  resolved. Neither belongs to this rule: an unknown type in either position
  says exactly the same second thing today, because both fall back to `integer`
  to keep the tree checkable. }
program RecordRegionField(output);
const
  lim  = 2;
  size = 3;
type
  cell = integer;
  arm  = 1..2;

  { A field's own type-denoter, which is the plainest occurrence there is.
    `fred` is the field on the next line and not the type after the end -- the
    region is the record, not the text before the point, so a field declared
    *after* the occurrence still wins. }
  r1 = record
         a    : fred;
         fred : integer;
         ok1  : cell
       end;
  fred = integer;

  { An array's index-type and its component-type. }
  r2 = record
         b    : array [idx] of integer;
         c    : array [arm] of comp;
         idx  : arm;
         comp : integer;
         ok2  : array [arm] of cell
       end;
  idx  = arm;
  comp = integer;

  { A set's base-type and a file's component-type. }
  r3 = record
         d    : set of base;
         e    : file of item;
         base : arm;
         item : integer;
         ok3  : set of arm
       end;
  base = arm;
  item = integer;

  { A required type-identifier is an ordinary symbol in a region enclosing the
    program (6.2.2.10, ADR-0097), and a field's defining-point is nearer than
    that region -- so a field named `integer` takes the spelling inside its own
    record and nowhere else. }
  r4 = record
         f       : integer;
         integer : real
       end;

  { A *constant* occurrence, which none of the four above is. An array's bound
    and a subrange's bound are expressions, so they reach the name through the
    expression checker rather than through type-denoter resolution -- the same
    region and the same clause, and for a long time the one occurrence that
    went unasked. `size` is declared as a constant above and is still the field
    here; `lim` is not a field of this record and still names its constant,
    which is what says the rule is about fields and not about writing constant
    names inside a record (ADR-0134).

    Neither line carries a second message. A bound that did not fold usually
    draws "the bounds of a subrange must be ordinal constants" after it, and
    here the first message has already said why -- the same suppression an
    overflow in a bound gets. }
  r5 = record
         g    : array [1..size] of integer;
         h    : 1..size;
         size : integer;
         ok5  : array [1..lim] of integer
       end;
var
  x1: r1; x2: r2; x3: r3; x4: r4; x5: r5;
begin
  writeln('unreached ', x1.fred, x2.idx, x3.item, x4.f, x5.size)
end.
