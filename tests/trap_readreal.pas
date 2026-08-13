{ §6.1.5 gives a real no form beginning with the point: `unsigned-real =
  digit-sequence '.' fractional-part [ 'e' scale-factor ]`, so `.5` has no
  prefix that is a signed-number, s is empty, and §6.9.1 d) makes that an
  error.

  This one is worth a file of its own rather than a line in `readlongest.pas`,
  because it is the direction a reader is likely to get wrong: a point with
  digits on the *right* looks like a number and a point with digits on the
  *left* looks like one too, and neither is. `1.` is pinned there, where it is
  not an error — the 1 is a number and the point is simply not part of it —
  and `.5` is pinned here, where there is no number to be had. }
program TrapReadReal(input, output);
var r: real;
begin
  writeln('before');
  read(r);
  writeln(r:1:1)
end.
