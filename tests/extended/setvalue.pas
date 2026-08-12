{ ISO/IEC 10206:1991 §6.8.7.4's set-value: the third form of §6.8.7.1's
  structured-value-constructor, and the one that is not a constructor at all.

    structured-value-constructor = array-type-name array-value
                                 | record-type-name record-value
                                 | set-type-name set-value .
    set-value = set-constructor .

  So `digits[1, 3]` is the ordinary set-constructor `[1, 3]` with a type name
  in front of it, and what the name adds is a *type*. A bare set-constructor
  infers its type from its members and the empty one has no type at all
  (ADR-0028), which is why `[]` needs whatever it is compared or assigned to
  in order to mean anything. A set-value never does.

  The tokens are exactly those of a subscripted array — `sieve[2, 3]` and
  `a[2, 3]` cannot be told apart by a parser — so which one this is gets
  decided in Sema, by asking what the name at the root denotes (ADR-0066).
  That is why this file also subscripts an array on purpose: the two readings
  share a syntax and both have to keep working. }
program setvalue(output);
type
  digits  = set of 0..9;
  letters = set of 'a'..'z';
  kinds   = (red, green, blue);
  colours = set of kinds;
  label8  = packed array [1..8] of char;
var
  s: digits;
  L: letters;
  c: colours;
  a: array [1..5] of integer;
  i: integer;
  { §6.6's initial-state-specifier takes a nonvarying expression, and a
    set-value built out of constants is one — the same answer the bare
    constructor gives, since it is the same constructor. }
  init: digits value digits[1, 3..4];

procedure show(t: digits; what: label8);
var k: integer;
begin
  write(what, ':');
  for k := 0 to 9 do
    if k in t then write(' ', k:1);
  writeln
end;

begin
  { The null-set-value. `[]` is the one set-constructor with no type of its
    own; naming the type is the whole point, and it is also the only spelling
    of a set-value that reaches the parser as a structured value, an empty
    bracket being something a subscript list may never be. }
  s := digits[];
  show(s, 'empty   ');

  { Members, ranges, and both at once. A range and a comma in one bracket is
    the shape that made the parser's substring rule too strict to reuse
    unchanged — §6.5.6 gives a substring one range and no list. }
  s := digits[1, 3, 5];
  show(s, 'members ');
  s := digits[2..4];
  show(s, 'range   ');
  s := digits[1..3, 5, 7..8];
  show(s, 'mixed   ');
  show(init, 'initial ');

  { A member-designator is an expression, so it may be anything — including a
    subscript, which is the construct this one shares its syntax with. }
  for i := 1 to 5 do a[i] := i;
  s := digits[a[2], a[4]..a[5]];
  show(s, 'computed');

  { An ordinary subscript is unaffected, which is the regression this feature
    most needs pinned. }
  writeln('subscript: ', a[2]:1, ' ', a[5]:1);

  { The type is the *named* one, not one inferred from the members, so a
    set-value is a value of that type wherever a value of it may go: an
    operand, an argument, the right of an assignment. }
  s := digits[1] + digits[2..3];
  show(s, 'union   ');
  s := digits[1..5] * digits[4..9];
  show(s, 'meet    ');
  writeln('in: ', 3 in digits[1..4], ' ', 9 in digits[1..4]);
  writeln('equal: ', digits[1, 2] = digits[1..2]);
  writeln('subset: ', digits[2] <= digits[1..3]);

  { Any set type, not just one over integers. }
  L := letters['a', 'c'..'e'];
  writeln('letters: ', 'd' in L, ' ', 'b' in L);
  c := colours[red, blue];
  writeln('enums: ', blue in c, ' ', green in c);

  { §6.8.7.1: the type of the constructor is the type its type-name denotes,
    and set compatibility is structural on the base type (ADR-0028) — so a
    set-value of one set type serves for another over the same base. }
  s := digits[1..9] - digits[5];
  show(s, 'less    ')
end.
