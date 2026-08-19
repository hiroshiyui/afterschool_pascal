{ ADR-0125: a slice is a parameter form, and the pair travels as two words.

  `array of T` is a formal parameter's type and nothing else. §6.4.3.2 requires
  a bracketed index-type after `array`, so this spelling is a syntax error in
  both standards and the dialect has it for nothing -- the third time the lexis
  has cost nothing, after a directive (ADR-0121) and a character no standard
  admits (ADR-0123).

  What it is *for* is that the bounds travel with the pointer. Extended Pascal
  gives a string a substring (§6.7.6.7) and gives an array nothing, so a
  routine that wants part of one has to be handed the whole thing and two
  indices -- which puts the bounds outside anything that checks them. }
program slice(output);

type vector(n: integer) = array [1..n] of integer;

var a: array [1..8] of integer;
    z: array [0..4] of integer;      { a lower bound that is not 1 }
    v: vector(6);                    { an extent that arrives with the actual }
    i: integer;

{ A `var` slice: the callee writes through it, into the caller's array. }
procedure Fill(var s: array of integer; from: integer);
var k: integer;
begin
  for k := 1 to length(s) do
    s[k] := from + k
end;

{ §6.6.3.7's protected parameter (ADR-0046) is the read-only borrow, and needs
  nothing new: the threat rules already walk it. }
function Total(protected var s: array of integer): integer;
var k, t: integer;
begin
  t := 0;
  for k := 1 to length(s) do
    t := t + s[k];
  Total := t
end;

{ A slice of a slice, and one handed on to another routine. Neither re-checks
  anything: the range was checked where the designator was written, which is
  the only place the base's own extent was still known. }
function Tail(var s: array of integer): integer;
begin
  if length(s) <= 1 then Tail := 0
  else Tail := Total(s[2..length(s)])
end;

begin
  Fill(a, 0);
  writeln('whole    = ', Total(a):1);

  { A slice is indexed 1..length however far into the base it starts, which is
    what §6.7.6.7's substr does to a string and for the same reason: no type
    names its index-domain. }
  writeln('part     = ', Total(a[3..5]):1);
  writeln('one      = ', Total(a[4..4]):1);

  { The empty slice. §6.7.6.7 already lets `substr(s, i, 0)` yield the
    null-string, and a loop that consumes a slice down to nothing should not
    have to special-case its last step. }
  writeln('empty    = ', Total(a[4..3]):1);

  writeln('tail     = ', Tail(a):1);

  Fill(a[6..8], 100);
  writeln('written  = ', a[6]:1, ' ', a[7]:1, ' ', a[8]:1);

  { The designator uses the *base's* own index space, so `z[1..3]` of an array
    indexed 0..4 is its second, third and fourth components. }
  for i := 0 to 4 do z[i] := i * 10;
  writeln('offset   = ', Total(z):1, ' ', Total(z[1..3]):1);

  { And a schematic array, whose extent is a discriminant rather than a
    number -- DynLength answers both, so this needed nothing of its own. }
  Fill(v, 0);
  writeln('schema   = ', Total(v):1, ' ', Total(v[2..4]):1)
end.
