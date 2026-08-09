program FilesScratch(output);

{ A file variable that is not a program parameter has no external name: it is
  a scratch file, written and read back within the run. Together with the
  buffer variable and put, this is the whole of ISO 7185's file model with no
  operating system visible in the source. }

type
  word8 = packed array [1..8] of char;

var
  i, n: integer;
  c: char;

{ Local files belong to the block that declares them, so each call gets its
  own — and each is closed when the call returns, which is what stops a loop
  like the one below from running out of file descriptors. }
function Reversed(s: word8): char;
var
  t: text;
  k: integer;
  last: char;
begin
  rewrite(t);
  for k := 1 to 8 do begin
    t^ := s[k]; { assign the buffer variable... }
    put(t)      { ...and append what it holds }
  end;
  reset(t);
  last := ' ';
  while not eof(t) do begin
    read(t, c);
    if c <> ' ' then
      last := c
  end;
  Reversed := last
end;

begin
  writeln('last letters: ', Reversed('red     '), Reversed('green   '),
          Reversed('blue    '));

  { Three thousand scratch files in sequence. Each is closed by the exit of
    the block that declared it — if it were not, this would exhaust the
    descriptor table long before finishing. }
  n := 0;
  for i := 1 to 3000 do
    if Reversed('x       ') = 'x' then
      n := n + 1;
  writeln('scratch files opened and closed: ', n:1)
end.
