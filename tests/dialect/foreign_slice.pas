program foreign_slice(output);

{ ADR-0129: a slice crosses the foreign boundary as the pair (ptr, i64) --
  the address of the first component and how many components there are, which
  is the argument shape `read`, `write`, `recv` and `send` all take.

  What the program never writes is the count. `PosixRead` has two parameters
  and `read(2)` has three: the length C receives is the one the compiler
  computed and checked against the array, so a buffer overrun is not something
  a caller can spell. }

function PosixRead(fd: integer; var buf: array of char): int64;
  external 'read';

var
  buf: array [1..64] of char;
  n: int64;
  i: integer;

begin
  for i := 1 to 64 do buf[i] := '.';

  { Five bytes of a longer line. The count crossed, so `read` stops at five --
    it is not told how big `buf` is and cannot be. }
  n := PosixRead(0, buf[1..5]);
  write('n=', n:1, ' [');
  for i := 1 to 10 do write(buf[i]);
  writeln(']');

  { The whole array is a slice of itself, and its length is its extent. }
  n := PosixRead(0, buf);
  write('n=', n:1, ' [');
  for i := 1 to 7 do write(buf[i]);
  writeln(']')
end.
