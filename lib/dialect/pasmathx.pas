{ PasMathX -- the mathematics neither standard has, reached by ADR-0121's
  foreign-function interface.

  This module is the first user of `external`, and it is here to hold one
  claim still: **a binding module exports Pascal and keeps the directive to
  itself.** The `external` declarations below are ordinary local ones -- they
  are not exported and cannot be, because an exported constituent's linkage
  name is composed from the interface and the constituent spelling (6.13) and
  a foreign name is whatever the program wrote. So what crosses the interface
  is a Pascal routine with Pascal's rules, and what crosses the link is C.

  It is **dialect-only**: `external` is admitted by this dialect alone
  (ADR-0117's containment), so no standard Pascal would compile it. lib/'s
  other modules stay Extended Pascal and stay portable to one; the outward-facing
  half of the library will not, and that is stated in ADR-0121 rather than
  discovered.

  Where a routine can fail it answers ADR-0120's result shape rather than
  halting or returning a sentinel: `ln` of a number that is not positive is an
  *error* in 6.7.2.2 and stops the program (ADR-0077), and a library may not
  do that (ADR-0116). The tag is set by writing the payload, so no line here
  says `r.ok := ...` and none can forget to.

  Only `integer` and `real` cross the boundary in this increment, which is why
  everything below is arithmetic: a string, a pointer or an out-parameter
  needs the increment after this one (ADR-0121). }

module PasMathX;

export PasMathX = (RealResult, RealOr, Cbrt, Log10, Log2, FMod);

{ 6.11.1 puts the import-part inside the module-block, after the export-part. }
import PasError;

type
  { ADR-0120's shape over a real, and since AP 6.4.13 a *type* rather than a
    convention: `T ! E` is the record every module used to declare, with the
    field names fixed -- `ok`, `val`, `cause` (ADR-0176). }
  RealResult = real ! ErrorCode;

{ The value, or the caller's own answer where there is none. The alternative
  to checking, for a caller that has a sensible default and does not want to
  branch -- reading `r.val` without asking traps, which is the whole point. }
function RealOr(r: RealResult; whenBad: real): real;

{ The real cube root. Total: every real has one, including a negative one,
  which is what makes this a plain function rather than a result. `x ** (1/3)`
  is not the same routine -- 6.7.2.2's exponentiation of a negative base by a
  non-integer is an error. }
function Cbrt(x: real): real;

{ Logarithms to bases the standards do not offer. `ln` is required and these
  are not, and dividing by `ln(10)` loses accuracy the library routine keeps.
  Not positive is errRange, for the same reason 6.7.2.2 makes it an error. }
function Log10(x: real) = r: RealResult;
function Log2(x: real) = r: RealResult;

{ The remainder of x/y, with the sign of x -- C's `fmod`, which is not `mod`:
  6.7.2.2's `mod` is over integers, yields a non-negative result and requires
  a positive divisor. A zero divisor is errRange. }
function FMod(x, y: real) = r: RealResult;

end;

{ ---- the boundary. Nothing below this line is exported. ---- }

{ 6.1.4's directive position, the one `forward` occupies. Each name is written
  out because this lexer case-folds identifiers and a linker matches a symbol
  exactly, so the Pascal spelling and the foreign one are different things and
  are kept apart on purpose -- `ExtLog10` is this module's, `log10` is libm's. }
function ExtCbrt(x: real): real; external 'cbrt';
function ExtLog10(x: real): real; external 'log10';
function ExtLog2(x: real): real; external 'log2';
function ExtFMod(x, y: real): real; external 'fmod';

function RealOr;
begin
  if r.ok then RealOr := r.val else RealOr := whenBad
end;

function Cbrt;
begin
  Cbrt := ExtCbrt(x)
end;

function Log10;
begin
  if x > 0.0 then r := ExtLog10(x) else r := errRange
end;

function Log2;
begin
  if x > 0.0 then r := ExtLog2(x) else r := errRange
end;

function FMod;
begin
  if y = 0.0 then r := errRange else r := ExtFMod(x, y)
end;

end.
