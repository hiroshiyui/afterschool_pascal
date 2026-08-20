{ ISO/IEC 10206:1991 6.7.5.3: `new(p, c1, ..., cn)` sets each selector.

  The clause says the initial state of the selector of the variant
  corresponding with the case-constant ci "shall be the state bearing the value
  associated with the variant corresponding to the value denoted by ci", and
  its NOTE 1 draws the consequence out: "any corresponding tag-field is also
  attributed the value of the case-constant".

  ISO 7185 DOES NOT REQUIRE THIS, which is why this case lives here. Its
  6.6.5.3 says the created variable "shall be totally-undefined" and "shall
  have nested variants that correspond to the case-constants" -- a statement
  about which variants exist, not about the tag. So under --std=iso7185 the tag
  is left alone, conformingly, and only the two standards that have the
  sentence store it.

  It was not implemented. pcSelect was read to size the allocation and for
  nothing else, so `new(p, green)` reserved the right storage and left the tag
  reading `red`: a conforming program given a wrong answer, and under the
  dialect ADR-0118's guard then trapped on a read of the very variant the
  program had asked for.

  THE MULTI-LABEL ARM IS WHY THE VALUE IS KEPT SEPARATELY. pcSelect holds arm
  *indices*, because that is what the path into the layout needs; `1, 2: (p)`
  is one arm, and `new(m, 2)` must store 2 rather than the arm's first label.
  A fix deriving the value from the arm would print 1 here and pass every other
  line of this file.

  Found by a specification audit. }
program NewSelectors(output);
type
  Col = (red, green);
  Simple = record
    case k: Col of
      red:   (i: integer);
      green: (gr: integer)
    end;

  Outer = (oa, ob);
  Inner = (ia, ib);
  Nested = record
    case k: Outer of
      oa: (x: integer);
      ob: (case k2: Inner of
             ia: (y: integer);
             ib: (z: real))
    end;

  Three = 1..3;
  Multi = record
    case m: Three of
      1, 2: (p: integer);
      3:    (q: char)
    end;

var s: ^Simple; n: ^Nested; m: ^Multi;
begin
  { the second variant, so a tag left at its initial zero would read as the
    first and the case statement below would take the wrong arm }
  new(s, green);
  writeln('simple tag = ', ord(s^.k):1);
  case s^.k of
    red:   writeln('red');
    green: writeln('green')
  end;

  { every level of the nesting, outermost first, as the clause requires }
  new(n, ob, ib);
  writeln('outer = ', ord(n^.k):1, ', inner = ', ord(n^.k2):1);

  { and the second label of a two-label arm }
  new(m, 2);
  writeln('multi tag = ', m^.m:1);

  dispose(s); dispose(n); dispose(m)
end.
