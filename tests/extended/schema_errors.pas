{ What schemata refuse. Sema accumulates, so one run reports all of these.

  Note that every faulty schema below is also *used*: a schema's body is
  resolved once per discriminant tuple and never otherwise, so a schema that
  nothing produces a type from is never looked at. That is a consequence of
  §6.4.7 rather than a shortcut -- the body has no meaning until a tuple gives
  its discriminants values -- but it does mean a test file has to spend a
  variable on each mistake it wants reported.

  The productions that report *twice* do so on purpose: a body is written in
  one place and its discriminants are chosen in another, and neither location
  alone says what to change. }
program SchemaErrors(output);
type
  vector(n: integer) = array [1..n] of real;
  grid(w, h: integer) = array [1..w, 1..h] of integer;
  { §6.4.8: a type produced from one schema is distinct from every type
    produced from *another* schema, whatever tuple either was given -- so
    these two are different types even though both are produced with (3) and
    both denote an array of three reals }
  alike(n: integer) = array [1..n] of real;
  { §6.4.7: the type of a discriminant is an *ordinal* type name }
  wrong(x: real) = array [1..3] of integer;
  { legal since ADR-0107: 6.4.2.3 puts these constants' defining-point in
    the block, so one declaration serves every production }
  enumerated(n: integer) = record c: (aa, bb) end;
  { §6.4.7 lets a schema name itself only in the domain of a pointer }
  selfish(n: integer) = array [1..n] of selfish(n);
  { a discriminant cannot be named twice }
  twice(d, d: integer) = array [1..d] of char;
  { NOTE 2(a): a tuple whose body has an empty subrange is not in the domain }
  hollow(n: integer) = array [1..n] of char;
  { §6.4.7's domain is the tuples *allowed* by the formal-discriminant-part,
    so a value outside the discriminant's own type is not one of them. It
    takes a discriminant whose type is narrower than integer to see this:
    a subrange is assignment-compatible with its host, so nothing but the
    range itself refuses 20 here. }
  small = 1..9;
  narrow(n: small) = array [1..n] of char;
var
  v: vector(3);
  w: vector(4);
  twin: alike(3);
  { a schema is not a type until its discriminants are given }
  bare: vector;
  { and the name has to be one }
  none: nosuch(1);
  { §6.4.8: the tuple is as long as the formal-discriminant-part }
  few: grid(2);
  many: vector(1, 2);
  { the values are constants of the discriminant's own type }
  wrongtype: vector('a');
  { each of the faulty schemata above, so that each is produced from }
  a: wrong(1.0);
  b: enumerated(2);
  c: selfish(2);
  d: twice(2, 2);
  e: hollow(0);
  f: narrow(20);
  n: integer;
  { §6.2.3.2 evaluates a discriminant-value when the block is entered, so a
    variable *is* allowed there (ADR-0041) -- but an ordinal one, and only in
    a variable declaration. A real is neither a constant nor an ordinal, and
    the message says the second because that is what is left to say. }
  r: real;
  later: vector(r);

begin
  { §6.4.8: one tuple, one type -- and a different tuple, a different type }
  v := w;
  v := twin;

  n := 3;

  { §6.8.4 makes a schema-discriminant a primary, not a variable-access }
  v.n := 4;

  { and only a formal discriminant of the schema answers to a dot }
  writeln(v.bogus:1, n:1)
end.
