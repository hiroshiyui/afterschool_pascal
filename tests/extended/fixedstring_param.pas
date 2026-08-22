{ ISO/IEC 10206:1991 6.7.3.2: "If the parameter-form of the
  value-parameter-specification contains a type-name or a type-inquiry ... The
  value in the underlying-type of the type of each corresponding
  actual-parameter ... shall be assignment-compatible with the type possessed
  by the formal-parameters."

  Assignment-compatible, not equal. 6.4.5 d) makes every string-type
  compatible with every other, 6.4.6 f) makes a value assignment-compatible
  with a string-type of at least its length, and 6.4.6's last paragraph says
  what that means: "the canonical-string-type value shall be treated as a
  value of the fixed-string-type whose components in order of increasing index
  shall be the components of the canonical-string-type value in order of
  increasing index followed by zero or more spaces." 6.4.3.3.1's own NOTE
  spells out the consequence: "String-type values may be used as the
  actual-parameter corresponding to a value parameter possessing a
  string-type (see 6.7.3.2)."

  So a shorter actual is *padded*, exactly as `f := s` has always padded. This
  compiler refused it, and the reason it gave was a lowering rather than a
  rule -- a structured value parameter travels as an address (ADR-0017) and a
  shorter actual has none of the formal's shape, so there was nothing to hand
  over. There is now: the padded value is built at the call site in the string
  arena, whose lifetime is the statement (ADR-0111).

  What is *not* changed is the pair the compiler already handled -- an actual
  that is a char array of the formal's own length is still copied from its own
  address, so nothing that compiled before is lowered differently.

  ISO 7185 is untouched: it has no 6.4.5 d) and no string-type, so there `s`
  and `t` below would be two array types and neither assignment nor a call
  would be legal. }
program fixedstring_param(output);

type
  five  = packed array [1..5] of char;
  three = packed array [1..3] of char;

var
  v: string(10);
  t: three;
  f: five;
  i: integer;

procedure show(s: five);
begin writeln('[', s, ']') end;

{ 6.7.3.2's rule is about the *formal's* type, so it reaches a second
  parameter and a nested call the same way. }
procedure both(a: five; b: three);
begin writeln('[', a, '][', b, ']') end;

function echo(s: five): five;
begin echo := s end;

begin
  { a literal shorter than the capacity, and one exactly as long }
  show('abcde');
  show('abc');

  { 6.4.6's char paragraph: "the char-type value shall be treated as a value of
    the canonical-string-type with length 1", so a char pads to the capacity }
  show('a');

  { the null-string is all spaces }
  show('');

  { a variable-string variable, whose length is a run-time value }
  v := 'xy';
  show(v);
  v := 'abcdefghij';
  show(v[1..4]);

  { a fixed-string of a different length, which is the pair 6.4.5 d) makes
    compatible and name equivalence (ADR-0017) would not }
  t := 'pqr';
  show(t);

  { an expression that is no variable at all: 6.7.3.2 makes the actual an
    expression, and 6.8.3.6's concatenation yields the canonical-string-type }
  show(v[1..2] + 'zz');

  { the same actual for two formals of different capacity, and a call whose
    own result is a fixed string }
  both('hi', 'hi');
  show(echo('mn'));

  { in a loop, so the arena has to be released between statements rather than
    filling up (ADR-0111) }
  for i := 1 to 3 do show('q');

  { and the pair that was always legal, still copied from its own address }
  f := 'wxyz!';
  show(f)
end.
