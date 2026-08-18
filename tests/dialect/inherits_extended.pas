{ The dialect contains Extended Pascal, and this is what says so.

  ADR-0117 decides that `--std=afterschool` is ISO/IEC 10206:1991 *plus*, where
  the first two modes are deliberately not nested. Today the "plus" is empty, so
  this mode accepts exactly Extended Pascal -- which makes this case the whole
  of the mode's behaviour and not a corner of it.

  It is also the case that would have caught the mistake ADR-0117 was written to
  prevent. `stdKind` gained a third value, and 38 sites asked
  `langStd = stdExtended`; had they been left as equality, every construct below
  would have been refused under this flag while nothing failed to compile and
  the other two corpora stayed green. So this file deliberately reaches a wide
  spread of the features those sites guard, one per paragraph, rather than
  testing one thing well:

    schemata and discriminants, `otherwise`, variable strings and the string
    operators, `**`, the complex type, constant expressions in a type, a
    value-parameter string, and selecting from a constant.

  The last is one of the two sites that were spelled `<>` rather than `=` --
  RefuseConstAccess -- so it is the arm that breaks in the *opposite* direction,
  and it is here for that reason. }
program InheritsExtended(output);

const
  Origin = 'afterschool';
  Limit = 4;

type
  { a schema: the extent arrives with the value }
  Vector(n: integer) = array [1..n] of integer;
  { a variable string, and a constant-expression bound }
  Name = string(Limit * 8);
  Colour = (red, green, blue);
  Point = record x, y: real end;

var
  v: Vector(Limit);
  s, t: Name;
  c: Colour;
  z: complex;
  i, total: integer;
  p: Point;

{ a string *value* parameter -- ADR-0115, and Extended Pascal's assignment
  compatibility for strings behind it }
function Shout(w: Name): Name;
var r: Name; k: integer;
begin
  r := '';
  for k := 1 to length(w) do
    if (w[k] >= 'a') and (w[k] <= 'z') then
      r := r + chr(ord(w[k]) - ord('a') + ord('A'))
    else
      r := r + w[k];
  Shout := r
end;

begin
  { schemata: the discriminant is readable and bounds the loop }
  total := 0;
  for i := 1 to v.n do begin
    v[i] := i * i;
    total := total + v[i]
  end;
  writeln('schema n=', v.n:1, ' total=', total:1);

  { strings: concatenation, length, substr and comparison }
  s := Origin;
  t := s + ' pascal';
  writeln('string "', t, '" length=', length(t):1);
  writeln('substr=', substr(t, 1, 5), ' trimmed="', trim('  x  '), '"');
  writeln('shout=', Shout(s));
  writeln('compare=', s < t);

  { `otherwise`: the arm that gives a case with no matching label something to
    do, instead of trapping }
  c := blue;
  case c of
    red:   writeln('case red');
    green: writeln('case green');
    otherwise writeln('case otherwise')
  end;

  { `**` and `pow`, the two Extended Pascal exponentiation operators. They are
    not spellings of one thing: `**` yields a real whatever its operands, and
    `pow` keeps an integer base integer, so both are written out with a format
    that shows which is which. }
  writeln('2**10=', 2 ** 10:8:1, ' 2 pow 10=', 2 pow 10:1);

  { complex, and the required functions over it }
  z := cmplx(3.0, 4.0);
  writeln('complex re=', re(z):3:1, ' im=', im(z):3:1, ' abs=', abs(z):3:1);

  { selecting from a constant -- RefuseConstAccess, the site spelled `<>` }
  p.x := 1.5;
  p.y := 2.5;
  writeln('record x=', p.x:3:1, ' y=', p.y:3:1);
  writeln('const char=', Origin[1]);

  writeln('the dialect accepts Extended Pascal')
end.
