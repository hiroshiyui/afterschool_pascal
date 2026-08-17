{ ISO/IEC 10206:1991 6.6.3.2 with 6.4.6: a variable-string may be a value
  parameter, and the actual is converted to the formal's type on the way in.

  ADR-0052 refused this because "a conversion needs somewhere to build the
  result that the caller can name". The somewhere is the *callee's* slot, which
  is an ordinary frame field of the formal's type, so the prologue makes the
  same 6.4.6 store that `s := expr` makes -- and the pair the caller passes is
  ADR-0051's string value, a pointer and a length, which every string
  expression already produces. ADR-0115.

  What the corpus could not write before this and can now: a literal actual, an
  actual of a different capacity, and one function's result as another's
  argument. Each is a line below. }
program strvalueparam(output);

type
  s20 = string(20);
  s5 = string(5);
  eight = packed array [1..8] of char;

var
  wide: s20;
  narrow: s5;
  fixed: eight;

function len(s: s20): integer;
begin
  len := length(s)
end;

{ Value semantics, which is the thing a `var` parameter could not have given:
  the callee assigns to its own parameter and the caller must not see it. }
function clobber(s: s20): integer;
begin
  s := 'clobbered';
  clobber := length(s)
end;

function echo(s: s20): s20;
begin
  echo := s
end;

{ A string value parameter beside other parameters, so the argument *positions*
  are exercised rather than only the one-parameter case: it travels as two
  LLVM arguments, and a caller and a callee that disagreed about that would
  read the wrong operand for `k`. }
function tagged(k: integer; s: s20; j: integer): integer;
begin
  tagged := k * 100 + length(s) * 10 + j
end;

begin
  wide := 'hello';
  narrow := 'hi';
  fixed := 'abcdefgh';

  { The three the refusal made unwritable. }
  writeln(len('literal'):1);
  writeln(len(narrow):1);
  writeln(len(echo(wide)):1);

  { An actual of the same capacity, and one of a larger. }
  writeln(len(wide):1);

  { A fixed-string actual: 6.4.5 d) makes every string type compatible with
    every other, and the conversion is by *value*, so its eight characters
    arrive as a length of eight rather than being read past. }
  writeln(len(fixed):1);

  { The null string, and a value exactly at the formal's capacity. }
  writeln(len(''):1);
  writeln(len('12345678901234567890'):1);

  { Expressions that own no storage: a concatenation draws from the arena and a
    substring is a pointer into another string. Both are values, and neither is
    a variable, so both were unwritable here. }
  writeln(len(wide + ' world'):1);
  writeln(len(substr(wide, 2, 3)):1);

  { Value semantics: 9 inside, and `wide` still 5 afterwards. }
  writeln(clobber(wide):1);
  writeln(length(wide):1);

  { The parameter positions. }
  writeln(tagged(7, 'abc', 4):1);

  { A result handed straight to another call, twice over. }
  writeln('[', echo(echo('round trip')), ']')
end.
