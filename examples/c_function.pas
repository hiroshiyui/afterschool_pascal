{ Calling C functions from the C library, with no wrapper and no build step.

  `external 'name'` after a heading binds the C symbol (ADR-0121). Only
  exact types cross: `integer` is C's int, `csize` is a size_t, `real` is a
  double, and a `string` parameter arrives as a NUL-terminated `const
  char *`. libc and libm are already linked. Nothing checks the signature
  against the header, so the declaration is a claim you are making. }
program c_function(output);

function strlen(s: string): csize; external 'strlen';
function atoi(s: string): integer; external 'atoi';
function toupper(c: integer): integer; external 'toupper';
function cbrt(x: real): real; external 'cbrt';
{ A `var` parameter of `real` crosses as the address C's `double *` wants. }
function modf(x: real; var whole: real): real; external 'modf';

var
  whole, frac: real;
  k: integer;
  shout: string(32);

begin
  writeln('strlen("hello")  = ', strlen('hello'):1);
  writeln('atoi(" 42abc")   = ', atoi(' 42abc'):1);
  writeln('cbrt(27.0)       = ', cbrt(27.0):0:3);
  frac := modf(3.75, whole);
  writeln('modf(3.75)       = ', whole:0:2, ' and ', frac:0:2);
  shout := 'pascal';
  for k := 1 to length(shout) do
    shout[k] := chr(toupper(ord(shout[k])));
  writeln('toupper, by char = ', shout)
end.
