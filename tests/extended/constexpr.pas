{ ISO/IEC 10206:1991 §6.8.2: `constant-expression = expression`, where the
  expression "shall be nonvarying and shall not contain a discriminant-
  identifier". Nonvarying is defined negatively — it is an expression holding
  no variable-access, no non-static type-name, and no function the program
  declared, nor `eof`/`eoln`.

  ISO 7185 §6.3 admits a signed literal or a name and nothing else, so this is
  a change of language rather than an extension: everything here is refused
  under `--std=iso7185`, and `tests/constexpr_iso.pas` is that program.

  There is one place to fold and every constant position follows, because
  every one of them already went through the same two functions: a constant
  definition, a subrange bound, an array bound, a case label, a variant label,
  and a schema's discriminants. }
program ConstExpr(output);
const
  base   = 10;
  double = base * 2;              { arithmetic over a named constant }
  wrap   = (base + 5) div 3;      { div and parentheses }
  rem    = 17 mod base;           { §6.7.2.2's mod, non-negative }
  power  = 2 pow 10;              { §6.8.3.2: pow keeps its left operand's type }
  letter = chr(base * 6 + 5);     { a required function, folded exactly }
  code   = ord('A');
  size   = abs(-4) + sqr(3);
  bigger = base < double;         { a relational operator yields a boolean }
  both   = bigger and (rem = 7);
  next   = succ(letter);
  { A folded operator has to answer what the emitted one answers, and the two
    places that can disagree are the two where C's arithmetic differs from
    Pascal's. `mod` yields a non-negative result (§6.7.2.2), where C's `%`
    would give -1 here; `odd` is the low bit, where C's `x % 2 = 1` is false
    for every negative odd number. A leading sign binds to the whole term, so
    the negative operand has to arrive by name for `down mod 3` to be a mod of
    a negative rather than the negation of a mod. }
  down   = -7;
  modneg = down mod 3;            { 2, not -1 }
  oddneg = odd(down);             { true, not false }
  divneg = down div 3;            { -2: div truncates toward zero }
  { §6.8.2 c) allows the required functions other than eof and eoln, so the
    ordinal-valued ones fold; a real-valued one is refused, which
    tests/extended/constexpr_errors.pas shows. }

type
  { a subrange whose bounds are expressions, which ISO 7185 required to be
    constants }
  small  = 1 .. base div 2;
  shifted = base - 9 .. base + 1;
  colour = (red, green, blue);
  { an array bound, reached through the same subrange }
  row    = array [1 .. double div 4] of integer;

var
  s: small;
  t: shifted;
  r: row;
  i: integer;
  c: colour;

begin
  writeln('const  ', double:1, ' ', wrap:1, ' ', rem:1, ' ', power:1);
  writeln('funcs  ', letter, code:1, ' ', size:1, ' ', next);
  writeln('bool   ', bigger, ' ', both);
  writeln('signs  ', modneg:1, ' ', oddneg, ' ', divneg:1);

  s := base div 2;
  t := base + 1;
  writeln('range  ', s:1, ' ', t:1);

  for i := 1 to double div 4 do r[i] := i * i;
  writeln('array  ', r[1]:1, ' ', r[double div 4]:1);

  { §6.9.3.5's case labels, and §6.8.2 reaches them because they were already
    ordinal constants going through one evaluator }
  for i := 1 to 3 do
    case i of
      base - 9:        writeln('case   one');
      2 * 1:           writeln('case   two');
      base div 3 - 0:  writeln('case   three')
    end;

  c := blue;
  case c of
    red, green: writeln('enum   low');
    succ(green): writeln('enum   blue')
  end
end.
