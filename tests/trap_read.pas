program TrapRead(input, output);

{ Reading a number that is not there is an error, not a zero. The test runs
  with no standard input, so `read` meets end-of-file immediately — the same
  path a malformed file takes, and the one a compiler reading its own source
  would hit on a truncated file. }

var n: integer;

begin
  writeln('before the read');
  read(n);
  writeln('unreachable ', n:1)
end.
