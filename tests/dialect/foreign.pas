{ ADR-0121: a foreign function is a directive, and the boundary is two types
  wide. Every routine here is a real libc or libm one, and none of them is
  wrapped by anything in runtime/pasrt.c -- the point of the feature is that a
  program reaches code this compiler did not emit without a primitive being
  added for it first.

  tools/pascalcc already links libc and libm, so this needs no build change:
  ADR-0121 decision 6, and the reason the first increment has no -l surface. }
program foreign(output);

{ 6.1.4's directive position, the one `forward` occupies. The foreign name is
  a string-literal because this lexer case-folds identifiers and a linker
  matches a symbol exactly. }
function cbrt(x: real): real; external 'cbrt';
function log10(x: real): real; external 'log10';
function fmod(x, y: real): real; external 'fmod';

{ Two types in one signature, and the argument order is the C one. }
function ldexp(x: real; e: integer): real; external 'ldexp';

function abs32(i: integer): integer; external 'abs';
function toupper(c: integer): integer; external 'toupper';

{ A procedure: no result at all, which is the void row of the mapping. }
procedure srandom(seed: integer); external 'srandom';

{ Called from a nested block, where an ordinary call would pass the frame at
  level L-1 (ADR-0016). A foreign one passes no link, and this is what would
  fail if the emitter forgot which kind it was looking at. }
function shout(c: char): char;
  function up(k: integer): integer;
  begin
    up := toupper(k)
  end;
begin
  shout := chr(up(ord(c)))
end;

begin
  writeln('cbrt 27      = ', cbrt(27.0):0:1);
  writeln('log10 1000   = ', log10(1000.0):0:1);
  writeln('fmod 7 3     = ', fmod(7.0, 3.0):0:1);
  writeln('ldexp 3 4    = ', ldexp(3.0, 4):0:1);
  writeln('abs -17      = ', abs32(-17):1);
  writeln('toupper q    = ', chr(toupper(ord('q'))));
  writeln('nested       = ', shout('z'));
  { In an expression, not only as a whole statement. }
  writeln('mixed        = ', (abs32(-2) + trunc(cbrt(8.0))):1);
  srandom(1);
  writeln('void call ok')
end.
