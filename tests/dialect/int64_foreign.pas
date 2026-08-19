{ The reason ADR-0128 exists, at the boundary it exists for.

  ADR-0121 admitted `integer` and `real` across the foreign boundary because
  they are the two `clang` passes with no parameter attribute. ADR-0125's
  closing probe found what that left out:

      declare i64 @read(i32, ptr, i64)
      declare i64 @write(i32, ptr, i64)
      declare i64 @recv(i32, ptr, i64, i32)

  every length a `size_t` and every result an `ssize_t`. A slice could have
  crossed with an i64 length, the compiler generating that word -- but the
  result could not be received, so shipping the buffer alone would have put a
  knowingly wrong ABI in the tree for a call that cannot say how many bytes it
  moved. `int64` is the half that answers.

  `llabs` and `imaxabs` are the two libc takes and answers in the type, so they
  are what a case can call without a file descriptor. The buffer itself does
  not cross yet -- that is the next increment, and it is unblocked rather than
  done. }
program Int64Foreign(output);

function llabs(x: int64): int64; external 'llabs';
function imaxabs(x: int64): int64; external 'imaxabs';
function labs(x: int64): int64; external 'labs';

var a: int64;
    n: integer;
begin
  a := -5000000000;
  writeln(llabs(a));
  writeln(imaxabs(a));
  writeln(labs(a));
  { an integer actual widens into an int64 formal, as it does anywhere else }
  n := -7;
  writeln(llabs(n));
  { and the result is a value of the wider type, so it may be narrowed only by
    asking }
  writeln(trunc(llabs(n)))
end.
