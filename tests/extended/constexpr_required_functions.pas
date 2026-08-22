{ ISO/IEC 10206:1991 6.8.2. A constant-expression's expression "shall be
  nonvarying", and nonvarying is defined by what an expression must *not*
  contain:

    a) an applied occurrence of an identifier as a variable-identifier, a
       schema-discriminant, a bound-identifier, or a field-designator-
       identifier; or
    b) an applied occurrence of an identifier as a type-name that denotes a
       type that is not static; or
    c) an applied occurrence of an identifier as a function-identifier that has
       a defining-point contained by the program-block or that denotes one of
       the required functions eof or eoln.

  A required function's defining-point is in a region enclosing the program
  (6.2.2.10), not in the program-block, so c) reaches only `eof` and `eoln` --
  and NOTE 1 names the rest of the exclusions and says why: "the functions
  empty, position, and LastPosition cannot appear in constant-expressions
  because these functions require a variable as a parameter."

  So every other required function belongs here. This compiler accepted ISO
  7185's seven ordinal-valued ones and refused the Extended Pascal additions,
  which is what this case is about: `succ(x,k)` and `pred(x,k)` were refused
  because the folder walked one argument, and `length` because it had no arm.

  `index` was a third, and silently: nothing folded it and nothing said so, so
  6.3.2 -- the standard's own example of a constant-definition-part -- did not
  compile.

  Eight are still refused and that is a *restriction* rather than this rule --
  doc/implementation-defined.md 6 has it. A real constant is carried as the
  text that was written and is never converted to a number here, so trunc,
  round, sqrt, sin, cos, ln, exp and arctan would each need a conversion this
  compiler does not have, and the six real-valued ones a formatter besides.

  The last block is the payoff: a constant-expression is what an array bound
  and a subrange bound are, so refusing one refuses a declaration. }
program constexpr_required_functions(output);

type
  colour = (red, green, blue, indigo, violet);

const
  { 6.7.6.4's second argument, over each ordinal type it admits. }
  four      = succ(1, 3);
  seven     = pred(9, 2);
  ccc       = succ('a', 2);
  no        = pred(true, 1);
  hue       = succ(red, 3);

  { A step of zero, and a negative one -- 6.7.6.4's own examples include both,
    and pred(x,k) is defined as succ(x,-(k)) so the sign travels twice. }
  same      = succ(4, 0);
  backwards = succ(1, -3);
  forwards  = pred(red, -2);

  { The ends of the integer type, which the folder has to reach without
    overflowing its own arithmetic on the way (ADR-0014 makes that a trap, not
    a wrap). The guard has four cases -- the sign of the value against the sign
    of the step -- because with matching signs the difference against the
    nearer bound is what can be compared safely, and with opposite signs the
    sum is bounded by the larger operand and can simply be formed. All four are
    below: two here and two in the negatives beneath. }
  top       = succ(maxint, 0);
  nearlytop = pred(maxint, 1);

  { A negative value with a positive step, and with a negative one. }
  upfromneg = succ(-5, 3);
  downfromneg = pred(-5, 3);
  floor     = succ(-maxint, 0);

  { 6.7.6.7's length, of a string constant and of a char -- 6.4.3.3.1 gives
    the char-type "length 1 and capacity 1". }
  greeting  = 'hello';
  five      = length(greeting);
  one       = length('x');

  { 6.7.6.7's index, whose two arguments made it the other casualty of a
    two-argument arm written for succ and pred. Every branch of the clause:
    a null second operand answers 1 *before* a null first operand answers 0,
    so two null-strings answer 1; a match answers the least i; no match
    answers 0; and either operand may be a char, which 6.4.3.3.1 makes a
    string of length one. }
  hex_string = '0123456789ABCDEF';
  at_a      = index(hex_string, 'A');
  at_f      = index(hex_string, 'F');
  run       = index(hex_string, '89A');
  least     = index('abcabc', 'bc');
  absent    = index(hex_string, 'zz');
  empty2    = index(hex_string, '');
  both      = index('', '');
  none      = index('', 'a');
  chars     = index('a', 'a');

  { 6.3.2's own example of a constant-definition-part, written as the standard
    writes it. It is the reason this arm exists: a substring-constant whose
    bounds are index expressions is what the clause puts on the page, and this
    compiler refused the page. }
  hex_digits = hex_string[1..10];
  hex_alpha  = hex_string[index(hex_string,'A')..index(hex_string,'F')];

var
  { The point of all of it: a constant-expression is what a bound is. }
  buf: packed array [1..length(greeting)] of char;
  small: succ(0, 1)..pred(10, 4);
  i: integer;

begin
  writeln(four:1, ' ', seven:1, ' ', ccc, ' ', no, ' ', ord(hue):1);
  writeln(same:1, ' ', backwards:1, ' ', ord(forwards):1);
  writeln(top:1, ' ', nearlytop:1);
  writeln(upfromneg:1, ' ', downfromneg:1, ' ', floor:1);
  writeln(five:1, ' ', one:1);
  writeln(at_a:1, ' ', at_f:1, ' ', run:1, ' ', least:1, ' ', absent:1);
  writeln(empty2:1, ' ', both:1, ' ', none:1, ' ', chars:1);
  writeln('[', hex_digits, '] [', hex_alpha, ']');

  for i := 1 to length(greeting) do buf[i] := greeting[i];
  writeln('buf = ', buf);

  small := 6;
  writeln('small = ', small:1)
end.
