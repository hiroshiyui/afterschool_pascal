program TrapSuccSubrange(output);
{ ISO 7185 6.6.6.4 gives succ "a result of the same type as that of the
  expression (see 6.7.1)", and the cross-reference is where the rule really is:
  6.7.1 says "any factor whose type is S, where S is a subrange of T, shall be
  treated as if it were of type T". So succ runs out at the *host's* end and
  not the subrange's -- succ of a 1..9 holding 9 is 10, and pred of one holding
  1 is 0. Neither is an error.

  What is an error is putting the result back, because 6.4.6's range check
  lives at the store and always did. That is the whole of the difference, and
  it is why this file both prints and traps.

  The earlier version of this test asserted the opposite rule, in a comment
  citing 6.6.6.4 without reading its cross-reference, and every oracle here
  agreed with it: the compiler and the golden said the same wrong thing. The
  BSI validation suite's CONF139 is what disagreed. }
var d: 1..9;
begin
  d := 9;
  writeln(succ(d));   { 10 -- an integer, not a value of 1..9 }
  d := 1;
  writeln(pred(d));   { 0 -- likewise, below the subrange's lower bound }
  d := 9;
  d := succ(d)        { and *this* is the error, at the store }
end.
