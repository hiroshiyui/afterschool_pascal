{ AP 6.7.3.10.5's four categories (ADR-0266), each accepted for a type that
  answers for it -- and each of the four spellings still an ordinary
  identifier everywhere else, which is what makes the feature cost a program
  nothing.

  The categories are spelled by *position* and are in no scope (ADR-0140):
  `numeric`, `ordinal`, `ordered` and `equatable` are recognised between a
  formal parameter's colon and the word-symbol `type`, and nowhere at all in
  6.2.2's regions. So a program may go on declaring a type, a variable and a
  field of each of those names, which the declarations below do, in the same
  program that constrains four type parameters with them. }
program generic_constraints(output);

type
  { The category words as ordinary type-identifiers. If any of the four were
    reserved -- or were a required identifier in the region enclosing the
    program -- these three lines would not compile. }
  numeric = 1..9;
  ordinal = (alpha, beta, gamma);
  ordered = record equatable: integer end;

  Colour = (red, green, blue);
  Word4 = packed array [1..4] of char;

var
  { And as ordinary variable-identifiers, in the same program. }
  ordinary: numeric;
  equatable: ordinal;
  holder: ordered;

{ ---------------------------------------------------------------- numeric }

{ `+` is what the body uses, so `numeric` is what the heading demands.
  AP 6.7.3.10.5 checks that at the activation; the body is still checked once
  per tuple, exactly as AP 6.7.3.10.2 says, and a constraint moves the
  diagnostic rather than making the generic separately type-checked. }
function Sum(Elem: numeric type; a, b: Elem): Elem;
begin
  Sum := a + b
end;

{ ---------------------------------------------------------------- ordinal }

function Span(Elem: ordinal type; lo, hi: Elem): integer;
begin
  Span := ord(hi) - ord(lo)
end;

{ ---------------------------------------------------------------- ordered }

function Larger(Elem: ordered type; a, b: Elem): Elem;
begin
  if a > b then Larger := a else Larger := b
end;

{ -------------------------------------------------------------- equatable }

function Alike(Elem: equatable type; a, b: Elem): boolean;
begin
  Alike := a = b
end;

{ A category is a property of a *type parameter* and not of the routine, so a
  generic may carry one of each -- and one with no category at all, which is
  every generic written before this clause and is still admitted unchanged. }
function Tally(Key: equatable type; Count: numeric type; Any: type;
               k1, k2: Key; c: Count; ignored: Any): Count;
begin
  if k1 = k2 then Tally := c + c else Tally := c
end;

var
  i: integer;
  r: real;
  sub: numeric;
  z: complex;
  w: Word4;
  s: string(8);
  t: utf8(16);
  p, q: ^integer;
  st, su: set of Colour;

begin
  ordinary := 4;
  equatable := beta;
  holder.equatable := 17;
  writeln(ordinary:1, ' ', ord(equatable):1, ' ', holder.equatable:1);

  { numeric: the four kinds it admits, one call each -- integer, real,
    complex, and a subrange of integer, the last being the one that answers
    through Base() rather than being a kind of its own. }
  i := Sum(integer, 20, 22);
  writeln(i:1);
  r := Sum(1.5, 2.25);
  writeln(r:5:2);
  sub := Sum(numeric, 3, 4);
  writeln(sub:1);
  z := Sum(cmplx(1.0, 2.0), cmplx(3.0, 4.0));
  writeln(re(z):3:1, ' ', im(z):3:1);

  { ordinal: an enumerated type, char, boolean and a subrange. }
  writeln(Span(red, blue):1);
  writeln(Span('a', 'z'):1);
  writeln(Span(false, true):1);
  writeln(Span(numeric, 2, 7):1);

  { ordered: an ordinal, real, and the three string representations 6.8.3.5
    and AP 6.4.15.6 give the ordering operators. }
  writeln(Larger(green, red) = green);
  writeln(Larger(2.5, 1.5):3:1);
  w := 'beta';
  writeln(Larger(w, 'alfa'));
  s := 'yes';
  writeln(Larger(s, 'no '));
  t := 'zebra';
  writeln(Larger(t, 'aardvark') = 'zebra');

  { equatable: an ordinal, a real, a complex, a set, a pointer and a string.
    A record is not among them and neither is an array: 6.8.3.5 gives a
    structured type no relational operators, which is what the category is
    read off. }
  writeln(Alike(red, red));
  writeln(Alike(1.5, 1.5));
  writeln(Alike(cmplx(1.0, 0.0), cmplx(1.0, 0.0)));
  st := [red, blue];
  su := [blue, red];
  writeln(Alike(st, su));
  new(p);
  q := p;
  writeln(Alike(p, q));
  dispose(p);
  writeln(Alike(w, 'beta'));

  { Three type parameters, two of them constrained and one not. }
  writeln(Tally('x', 'x', 5, red):1);
  writeln(Tally('x', 'y', 5, red):1)
end.
