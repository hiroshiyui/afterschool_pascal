{ ISO/IEC 10206:1991 6.7.6.4 gives succ and pred a second argument:

    "succ(x,k) ... shall yield a value whose ordinal number is ord(x) + k, if
     such a value exists. It shall be an error if such a value does not exist."

  Annex D.65 names that error, so 3.1 lets a processor leave it undetected --
  but this one detects it, and detected it for a step of one only. The k form
  computed ord(x) + k in i32 and *then* asked whether the result was a value
  of the type, so at the top of the integer type the addition wrapped first
  and the range check found a comfortable negative number inside the bounds.
  succ(maxint) reported, because a step of one is compared before it steps.
  One clause, two spellings, two answers -- and the wrong one was silent.

  The sum is computed in i64 now, which is enough by construction: both
  operands are i32, so their sum needs at most 33 bits.

  Everything before the trap is the part that must not have changed. }
program succ_step_overflow(output);

type colour = (red, green, blue, indigo);

var i: integer;
    c: colour;

begin
  { The clause's own examples, and the ends of an enumeration. }
  c := green;
  writeln('succ(green,2) = ', ord(succ(c, 2)):1);
  writeln('pred(green,1) = ', ord(pred(c, 1)):1);
  writeln('succ(green,0) = ', ord(succ(c, 0)):1);
  writeln('pred(green,-2) = ', ord(pred(c, -2)):1);

  { A step that leaves the type by a wide margin was always reported: the sum
    does not wrap, so the range check saw it. }
  writeln('big steps still count: ', succ(1, 1000):1);

  { The boundary the one-ended path gets right. }
  i := maxint;
  writeln('succ(maxint-1,1) = ', succ(i - 1, 1):1);

  { And the one it got wrong: maxint + 2 is not a value of integer. Before
    this was fixed the line below printed -2147483647 and the program exited
    zero. }
  writeln('this must not print: ', succ(i, 2):1)
end.
