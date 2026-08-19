{ ADR-0128's `int64`: an integer twice as wide as this compiler's own.

  It exists for one reason, and the reason was found by a probe rather than by
  design (ADR-0125): on this target every length `read`, `write` and `recv`
  take is a `size_t` and every one of them *answers* an `ssize_t`. A language
  whose only integer is 32 bits can hand over a buffer and cannot be told how
  many bytes moved.

  The type is numeric and **not ordinal**, which is the decision the rest of it
  follows from -- see int64_types.pas for the thirteen positions that refuse it,
  every one of them through IsOrdinal and none through a rule of its own.
  Nothing this compiler holds is a value of the type, its own integers being 32
  bits, so a literal is carried as the *text* that was written all the way into
  the IR. That is what ADR-0025 already does with a real, arrived at again.

  What is exercised here: the literal, maxint64, the widening from integer, the
  five arithmetic operators with their overflow and division checks, the
  comparisons across the two widths, `trunc` as the only narrowing, abs and sqr,
  real division, and the type in a record, an array, a value parameter, a var
  parameter and a function result. }
program Int64Case(output);

type
  counters = record moved: int64; calls: integer end;

var
  a, b, c: int64;
  n: integer;
  r: counters;
  v: array [1..3] of int64;

{ a value parameter and a result, both of the wide type }
function twice(x: int64): int64;
begin
  twice := x + x
end;

{ a var parameter: the address of an i64 and nothing new about it }
procedure bump(var x: int64);
begin
  x := x + 1
end;

begin
  { a literal above maxint is where the type begins }
  a := 4000000000;
  b := 3;
  n := 7;
  writeln(a);
  writeln(maxint64);
  { leading zeros are a digit-sequence a program may write }
  writeln(00000000000000000000009223372036854775806);

  { the five operators, and the wider operand deciding }
  writeln(a + b, ' ', a - b, ' ', a * b);
  writeln(a div b, ' ', a mod b, ' ', -a);
  writeln(a + n, ' ', a div n, ' ', n * a);

  { comparisons, both widths on either side }
  c := a;
  writeln(a = c, ' ', a < b, ' ', b < n, ' ', n < a, ' ', a >= c);

  { real division widens both, and `/` is always real (6.7.2.2) }
  writeln(a / b:20:4);

  { abs and sqr keep the operand's type, which is 6.6.6.2's own words }
  writeln(abs(-a), ' ', sqr(b));

  { trunc is the only way back to integer, and it is checked }
  n := trunc(a div 4);
  writeln(n);

  { a field, a component, a parameter and a result }
  r.moved := a;
  r.calls := 1;
  v[1] := r.moved;
  v[2] := twice(v[1]);
  bump(v[2]);
  v[3] := twice(3);
  writeln(r.moved, ' ', v[1], ' ', v[2], ' ', v[3]);

  { a width applies as it does to any integer (6.10.3.1) }
  writeln(a:20);
  writeln(a:1)
end.
