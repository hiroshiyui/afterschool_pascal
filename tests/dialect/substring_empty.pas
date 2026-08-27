{ AP 6.5.6 (ADR-0219): the empty substring.

  ISO/IEC 10206:1991 6.5.6 states three error conditions, and the third is
  "the value of the first index-expression is greater than the value of the
  second" -- so `s[i..i-1]` is an error and Extended Pascal has no way to write
  a substring of no characters. The capacity the same clause states,
  "one plus the value of the second index-expression minus the value of the
  first", is already zero for that case: the arithmetic admits it and only the
  prohibition does not.

  The dialect drops that prohibition and keeps the other two. What it does not
  drop is the transposed pair -- `s[4..2]` is still an error, which is
  substring_empty_trap.pas -- so the condition is `hi < lo - 1` rather than
  `hi < lo`, exactly one value wider.

  Two things in this tree already answered this question the other way, which
  is the whole argument (ADR-0219): 6.7.6.7's own `substr(s, i, 0)` yields the
  null-string, and ADR-0125's `a[i..i-1]` is the empty slice. `s[i..i-1]` was
  the only bracketed range left that could not be empty.

  Both ends and the middle are written out, because the check is one `if` with
  three disjuncts and each end is a different disjunct: `s[1..0]` has a second
  index of zero, and `s[7..6]` a first index past the length. }
program SubstringEmpty(output);

const g = 'hello';
      { 6.8.8.4's substring-constant, folded rather than emitted -- the
        compile-time half of the same rule, and a length-zero literal is
        6.1.9's null-string, which already has a type. }
      none = g[1..0];
      mid  = g[3..2];
      some = g[2..3];

var s: string(10); f: packed array [1..6] of char; i: integer;

begin
  writeln('const  [', none, '][', mid, '][', some, ']');

  s := 'abcdef';
  writeln('front  [', s[1..0], ']');
  writeln('middle [', s[3..2], ']');
  writeln('back   [', s[7..6], ']');
  writeln('some   [', s[2..4], ']');

  { The reason the feature was demanded: dropping the last character of a
    string whose length may be one. Without the empty substring this needs a
    length test at every such site, and two library modules wrote one. }
  for i := 1 to 3 do
    writeln('drop', i:1, '  [', s[1..i - 1], ']');

  { A fixed-string-type is a string-type too, and its length is its capacity
    (6.4.3.3.2 NOTE 2), so the far end is one past that. }
  f := 'abcdef';
  writeln('fixed  [', f[1..0], '][', f[7..6], '][', f[2..3], ']');

  { The length of what the substring denotes, rather than what it prints:
    6.5.6 gives it a new fixed-string-type of capacity hi - lo + 1, and the
    empty case is where that capacity is zero. }
  writeln('len    ', length(s[4..3]):1, ' ', length(s[4..6]):1)
end.
