{ ISO/IEC 10206:1991 §6.4.2.2 e): "The required type-identifier `complex` shall
  denote the complex-type. The complex-type shall be a **simple-type**."

  Simple is the word that decides everything here. A complex value is assigned,
  passed and returned as a *value* — none of the by-address machinery structured
  types need (ADR-0017) applies to it, exactly as for a set (ADR-0028). It is
  represented as a two-element vector of doubles, which is the one shape that is
  both a single LLVM value and free of any opinion about how a struct is passed.

  `complex` is a required *identifier*, not a word-symbol: a valid ISO 7185
  program may define a type of that name, so nothing about this feature is
  lexical and the refusal under `--std=iso7185` happens where the name is
  resolved. }
program Complex(output);
const twopi = 6.2831853071795864769;
      halfpi = 1.5707963267948966192;

type tag2 = packed array [1..2] of char;
     { A record holding a complex is where the *size* of the type is asked
       for rather than its layout: an indexed access lets LLVM compute the
       stride from the element type, but a whole-variable copy and `new` need
       the number of bytes, and only those two ask. }
     hold = record c: complex; tag: integer end;
var z, w: complex;
    r: real;
    i: integer;
    zs: array [1..3] of complex;
    p, q: hold;
    hp: ^hold;

{ §6.4.2.2 makes complex a simple type, and §6.6.2 lets a function return any
  simple type — so this needs no var parameter, unlike a record. }
function twice(a: complex): complex;
begin
  twice := a + a
end;

procedure show(name: tag2; a: complex);
begin
  writeln(name, ' ', re(a):6:3, ' ', im(a):6:3)
end;

begin
  { §6.7.6.3: `cmplx(x, y)` and `polar(r, t)` are the only way to *write* a
    complex value — the standard gives the type no literal at all. }
  z := cmplx(3.0, 4.0);
  show('z ', z);

  { §6.7.6.2: `re`, `im` and `arg` yield a real; `abs` of a complex is its
    magnitude and so a real too — the two places table 2's result kind does not
    follow its operand. }
  writeln('abs   ', abs(z):6:3);
  writeln('arg   ', arg(cmplx(0.0, 1.0)):6:3);

  { §6.8.3.2 table 3: `+ - * /` accept a complex, and the result is complex if
    either operand is. (3+4i)(0+1i) = -4+3i. }
  show('* ', z * cmplx(0.0, 1.0));
  show('- ', z - cmplx(1.0, 1.0));
  { (3+4i)/(1+1i) = (7+1i)/2 }
  show('/ ', z / cmplx(1.0, 1.0));

  { §6.4.6 c): "an implicit integer-to-complex conversion or real-to-complex
    conversion, respectively, shall be performed" — so an integer or a real may
    stand wherever a complex is wanted, in an operand, in an assignment, and as
    an argument. }
  show('+i', z + 1);
  show('+r', z + 0.5);
  w := 2;
  show('w ', w);
  show('t ', twice(3.0));

  { §6.8.3.5 table 6: only `=` and `<>`. The four ordering operators take "any
    simple-type except complex-type", there being no order on the complex
    numbers to give them. }
  writeln(z = cmplx(3.0, 4.0), ' ', z <> cmplx(3.0, 4.0), ' ',
          z = 3, ' ', cmplx(2.0, 0.0) = 2);

  { §6.7.6.2: sqrt, exp, ln, sin, cos and arctan of a complex give a complex,
    and the principal values are C99's own — arg in (-pi, pi], and sqrt with a
    non-negative real part. sqrt(-4) is 2i, which is exactly the case a real
    sqrt makes an error. }
  show('q ', sqrt(cmplx(-4.0, 0.0)));
  show('e ', exp(cmplx(0.0, 0.0)));
  show('l ', ln(cmplx(1.0, 0.0)));
  show('s ', sin(cmplx(0.0, 0.0)));
  { cos(0+0i) has an imaginary part of *negative* zero, and `P` below a real
    part of one. Neither is written with a minus: 6.10.3.4.2 writes the sign
    "if (e < 0.0) and (eWritten > 0.0)", and -0.0 < 0.0 is false -- as is the
    second condition, so a tiny negative that rounds away is unsigned for the
    same reason. C's printf writes the sign bit instead, which is where the
    `-0.000` these two lines used to show came from (ADR-0169). }
  show('c ', cos(cmplx(0.0, 0.0)));
  show('a ', arctan(cmplx(0.0, 0.0)));

  { `sqr` keeps its operand's type: (2i)² = -4. }
  show('r ', sqr(cmplx(0.0, 2.0)));

  { §6.8.3.2 table 3 gives `**` and `pow` a complex *left* operand, and the
    right one is never complex — a real for `**`, an integer for `pow`. i² = -1
    and i³ = -i. }
  show('p ', cmplx(0.0, 1.0) ** 2.0);
  show('P ', cmplx(0.0, 1.0) pow 3);
  { the standard's two special cases, which are what keep the definition total
    where ln(0) is not }
  show('z0', cmplx(0.0, 0.0) ** 2.0);
  show('y0', cmplx(3.0, 4.0) ** 0.0);

  { A complex is a value, so it is a component and a field like any other. }
  for i := 1 to 3 do zs[i] := cmplx(i * 1.0, -i * 1.0);
  show('1 ', zs[1]);
  show('3 ', zs[3]);
  p.c := zs[2];
  p.tag := 7;
  show('f ', p.c);
  writeln('tag ', p.tag:1);

  { polar(r, t) has magnitude r and argument t, so polar(1, 2pi) is 1 — and
    the magnitude alone cannot tell the two parts apart, so this also builds
    one at a quarter turn, where the real part is 0 and the imaginary one is
    the whole magnitude. }
  w := polar(1.0, twopi);
  writeln('pol ', abs(w):6:3);
  show('pq', polar(2.0, halfpi));

  { A whole-variable copy of a record holding a complex, which is the one
    place the type's *size* is used rather than its layout. }
  q := p;
  { the tag is read *before* it is overwritten, so the copy is what put it
    there — a copy one field short would leave whatever the frame held }
  show('cp', q.c);
  writeln('tags ', p.tag:1, q.tag:1);
  q.tag := 9;
  writeln('then ', p.tag:1, q.tag:1);

  { ...and `new`, which asks the same question of the domain type. }
  new(hp);
  hp^.c := cmplx(5.0, -6.0);
  hp^.tag := 1;
  show('hp', hp^.c);
  dispose(hp);

  r := re(z) + im(z);
  writeln('sum ', r:6:3)
end.
