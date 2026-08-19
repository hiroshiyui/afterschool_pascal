{ ADR-0122's other admitted address: a `var` parameter of one of the two
  scalar types, which crosses as the actual's own storage. `int *` and
  `double *`, the two out-parameter shapes libm uses.

  The lifetime is the call for the same reason as a string argument's: the
  actual is a variable of the caller's, and it outlives the statement that
  wrote the call. Nothing checks that the callee does not keep the address --
  doc/sop.md §7 carries that, as it carries every other thing an FFI without a
  header parser cannot see. }
program foreign_var(output);

{ C's `double modf(double, double *iptr)` -- the fraction is the result and
  the integral part is written through the pointer. }
function modf(x: real; var ip: real): real; external 'modf';

{ C's `double frexp(double, int *exp)` -- the two admitted types in one
  signature, and the pointer is the integer one. }
function frexp(x: real; var e: integer): real; external 'frexp';

var f, ip: real;
    e: integer;

{ Through a nested block, so the argument is an address the emitter has to
  walk the static chain for -- while the call itself passes no link. }
procedure split(x: real);
  procedure inner;
  begin
    f := modf(x, ip)
  end;
begin
  inner
end;

begin
  f := modf(3.75, ip);
  writeln('modf 3.75    = ', f:0:2, ' ', ip:0:1);

  f := frexp(48.0, e);
  writeln('frexp 48     = ', f:0:2, ' ', e:1);

  { The actual is written by the callee and read afterwards, which is the
    whole of what a var parameter is for. }
  ip := 0.0;
  split(-2.25);
  writeln('nested       = ', f:0:2, ' ', ip:0:1);

  { A component of an array is a variable too, and its address is computed. }
  f := modf(9.5, ip);
  writeln('again        = ', f:0:2, ' ', ip:0:1)
end.
