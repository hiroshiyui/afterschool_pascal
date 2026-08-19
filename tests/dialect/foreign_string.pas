{ ADR-0122: an address may cross the boundary, and only as an argument, whose
  lifetime is the call. `string` in an `external` heading is not a schematic
  formal -- there is no descriptor to bind and no capacity to produce a
  variable for -- it names `const char *`, and what crosses is a
  NUL-terminated copy of the value in the string arena (ADR-0111).

  Every routine here is a real libc one and none is wrapped by anything in
  runtime/pasrt.c. }
program foreign_string(output);

function atoi(s: string): integer; external 'atoi';
function atof(s: string): real; external 'atof';

{ Two of them in one signature, which is the shape a comparison has. }
function strcmp(a, b: string): integer; external 'strcmp';

var v: string(12);
    n, k: integer;

function sign(k: integer): char;
begin
  if k < 0 then sign := '-'
  else if k > 0 then sign := '+'
  else sign := '0'
end;

begin
  { A literal, a variable, and a value with a capacity of its own. }
  writeln('atoi lit     = ', atoi('42'):1);
  v := '-17';
  writeln('atoi var     = ', atoi(v):1);
  writeln('atof         = ', atof('2.5'):0:2);

  { 6.4.3.3.1 gives the char-type "length 1 and capacity 1", so a char stands
    where a string does and crosses as a string of one character. }
  writeln('atoi char    = ', atoi('7'):1);

  { A concatenation: the actual is itself an arena value, so the statement
    holds two temporaries at once and must release both. }
  writeln('atoi concat  = ', atoi('1' + '2'):1);

  { A substring, whose type is a new fixed-string-type different from every
    named type -- and which crosses because what crosses is the value. }
  v := 'abc99xyz';
  writeln('atoi substr  = ', atoi(v[4..5]):1);

  writeln('strcmp eq    = ', sign(strcmp('abc', 'abc')));
  writeln('strcmp lt    = ', sign(strcmp('abc', 'abd')));
  writeln('strcmp gt    = ', sign(strcmp('b', 'a')));

  { In a loop, and enough of them that the arena must be released each time
    round: 40000 iterations take a 20-character concatenation and a 21-byte
    NUL-terminated copy of it, which is 1.6 MB through an arena of one. }
  n := 0;
  for k := 1 to 40000 do
    n := n + atoi('12 padding' + ' to twenty');
  writeln('loop ok      = ', n:1);

  { And again with the boundary copy as the *only* thing the statement
    allocates -- a variable's characters are where the variable is, so nothing
    else here bumps ADR-0111's counter and this is what says the copy must.
    100000 iterations of 13 bytes is 1.3 MB, and the statement above would
    hide the omission: a concatenation bumps the counter for its own reasons
    and the release then frees everything the statement took. }
  v := '7 padding s';
  n := 0;
  for k := 1 to 100000 do
    n := n + atoi(v);
  writeln('copy alone   = ', n:1)
end.
