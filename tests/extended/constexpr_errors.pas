{ What ISO/IEC 10206:1991 §6.8.2 refuses, and what this compiler declines to
  fold. Sema accumulates, so one run reports all of them.

  The distinction worth seeing here is between an expression that is *not
  constant* — which the context describes in its own words — and one that is
  constant and *wrong*, which only the folder can describe. Each is reported
  once, never both. }
program ConstExprErrors(output);
var v: integer;

const
  { §6.7.2.2 makes an integer overflow an error, and one the compiler can see
    is a diagnostic rather than a trap: the value would otherwise reach a type
    declaration as a wrapped number. }
  over   = maxint * 2;
  grown  = maxint + 1;
  shrunk = -maxint - 2;
  zero   = 1 div 0;
  neg    = 5 mod 0;
  { §6.6.6.4: chr, succ and pred run out at the ends of their own type. }
  wide   = chr(300);
  past   = succ(maxint);
  under  = pred(-maxint);
  { §6.8.3.2: pow is repeated multiplication, so a negative exponent has
    nothing to repeat, and the accumulator overflows like any other product. }
  backwards = 2 pow -1;
  huge      = 2 pow 40;
  { A real constant is carried as the text that was written and never
    converted, so there is nothing to fold with. }
  real1  = 1.5 * 2.0;
  real2  = 7 / 2;
  { The same restriction reached through a call rather than an operator.
    6.8.2 leaves every required function except eof, eoln, empty, position and
    LastPosition nonvarying, so these are legal constant-expressions that this
    processor cannot evaluate -- trunc and round because the argument would
    have to be converted, sqrt because the result would have to be written
    back as text as well. They say which, rather than reporting the expression
    as not constant, because those are different complaints and only one of
    them is about the program. }
  cut    = trunc(3.7);
  near   = round(3.5);
  root   = sqrt(4.0);
  { 6.7.6.4's two-argument forms run out at the same ends, and each direction
    has to be reported without the folder overflowing on the way to deciding
    (ADR-0014 makes the compiler's own arithmetic trap). }
  overstep  = succ(maxint, 2);
  understep = pred(-maxint, 2);

type
  { the same refusals reached through a subrange bound rather than a
    constant definition }
  bad = 1 .. maxint * 3;

  { A bound may now be a whole expression, so telling a subrange from a type
    name means scanning ahead for a `..` — and only one at bracket depth zero
    ends the search. A schema production is the one name-led denoter with
    brackets in it, and a set constructor is the one way a `..` gets inside
    them. This is an error either way; what it pins is *which* error, because
    a scan that stopped at the first `..` would read `vec([1` as a subrange
    bound and turn the file's accumulated Sema errors into one parse abort. }
  vec(cap: integer) = array [1 .. cap] of integer;
  bracketed = vec([1 .. 3]);

{ §6.8.2 a): an expression containing a variable-access is not nonvarying.
  The folder has nothing to say about it — it is simply not constant — so the
  context's own words are what is reported, and only those. The variable has
  to belong to an *enclosing* block to be in scope at all: a constant
  definition is folded before its own block's variables exist. }
procedure inner;
const varying = v + 1;
begin end;


begin
  { ...and through a case label }
  case v of
    maxint + 5: writeln('unreachable')
  end

end.
