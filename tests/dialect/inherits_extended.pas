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

{ ADR-0128 adds a required type-identifier, and 6.1.3 makes every one of them
  shadowable -- so a program of the standard this mode contains may still spell
  a type of its own `int64`. Declared here rather than at the top so that the
  declaration and the use that proves it sit together. }
type int64 = 1..100;

function Shadowed(n: int64): int64;
begin
  Shadowed := n * n
end;

{ ADR-0173 adds two required function-identifiers, `argcount` and `argument`,
  and the same sentence covers them: a program of the contained standard may
  use either spelling for something of its own. Here `argument` is an integer
  variable and `argcount` a function of this program's -- the latter the
  sharper case, because the parser turns a bare `argcount` into a call, and a
  program that declares its own must still get its own. }
var argument: integer;

function argcount: integer;
begin
  argcount := argument * 2
end;

{ ADR-0174's handle-type is spelled `handle external '...'`, and neither word
  is reserved: `handle` is a type of this program's and `external` a variable
  of it, and a handle-type is only the three-token juxtaposition no program
  of the contained standard can write. }
type handle = 1..3;
var external: handle;

{ ADR-0175's defer-statement is `defer` followed by a token that begins a
  statement, which no program of the contained standard can write. `defer`
  itself is a procedure of this program's, and every position a conforming
  program may call it in -- bare before a terminator, and with arguments --
  still calls it. }
procedure defer;
begin
  writeln('defer of this program')
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

  { 6.1.3 makes every required identifier shadowable, so a required one the
    *dialect* adds takes no name away from a program written for the standard
    it contains. `int64` is ADR-0128's, and `Shadowed` below is a function
    whose formal is a type of that name declared in this program -- which is
    the whole of what containment means for a new required identifier.
    tests/extended/int64_is_free.pas is the same declaration under
    --std=extended, where the name was never required at all. }
  writeln('shadowed=', Shadowed(3));
  argument := 21;
  writeln('argcount of this program=', argcount:1);
  external := 3;
  writeln('handle of this program=', external:1);
  defer;
  if external = 3 then defer;

  writeln('the dialect accepts Extended Pascal')
end.
