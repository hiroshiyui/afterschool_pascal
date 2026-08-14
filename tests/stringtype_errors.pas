{ ISO 7185 §6.4.3.2:

    Any type designated packed and denoted by an array-type having as its
    index-type a denotation of a subrange-type specifying a smallest value of
    1 and a largest value of greater than 1, and having as its component-type
    a denotation of the char-type, shall be designated a string-type.

  Four properties at once, and this compiler asked only two of them -- packed,
  and a component whose *base* is char. So it compared any packed char array
  by length alone, and §6.9.3.6 gives a whole-array write the same rule, so an
  array whose lower bound is not 1 was written rather than refused.

  The enum index is the one a lower-bound test alone does not catch: `colour`
  is (red, blue, yellow, green), so ord(blue) is 1 and the array's smallest
  *ordinal* is 1 while its smallest *value* is blue. The index-type has to be
  an integer one before its lower bound means anything, which is why that
  clause is not redundant with the one beside it.

  tests/extended/stringtype_capacity1.pas is the other half: ISO/IEC
  10206:1991 §6.4.3.3.2 drops the largest-value clause, so `packed array
  [1..1] of char` is a fixed-string-type there and is not a string-type here.
  That is the only one of the four that --std decides. }
program StringTypeErrors(output);

type
  alpha  = 'A'..'Z';
  colour = (red, blue, yellow, green);
  cl1    = blue..green;

var
  four     : packed array [1..4] of char;    { the one that is a string-type }
  zeroed   : packed array [0..3] of char;
  raised   : packed array [2..5] of char;
  lettered : packed array [1..4] of alpha;
  hued     : packed array [cl1] of char;
  one      : packed array [1..1] of char;

begin
  four := 'FOUR';                { legal, and must not be reported }
  zeroed := 'ZERO';
  raised := 'HIGH';
  lettered := 'FOUR';
  hued := 'HUE';
  one[1] := 'Z';                 { legal: a component, not the whole array }
  write(four);                   { legal: this one is a string-type }
  write(zeroed);
  write(one)
end.
