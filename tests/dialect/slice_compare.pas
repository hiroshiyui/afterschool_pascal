{ ADR-0139: a slice is compatible with a slice, and that is not permission to
  compare one.

  AP 6.4.5 says two slices are compatible when their component types are the
  same type, and their lengths need not agree. That rule exists for *parameter
  passing*: one `array of T` formal has to accept `a[1..2]` and `a[1..99]` and
  a whole array, which is the entire reason the extent is not in the type.

  The relational operators ask compatibility too. So the permission leaked --
  ADR-0058's shape exactly, and the second time it has happened here: a
  restricted type and its underlying-type assign to each other, and `n = 3`
  rode in on that until 6.4.2.5's NOTE was written out at the comparison.

  What made this one worse than a wrong answer is where it stopped. Sema
  accepted `a[1..2] = a[3..4]`, so CodeGen was handed a comparison of two
  two-word descriptors, had no lowering for one, and emitted an `icmp` whose
  operand type was the descriptor and whose operands were the literal 0. That
  is not a diagnostic and not a wrong program: it is invalid IR, and the
  assembler reports it against a file the programmer never wrote. The same
  shape ADR-0121's foreign-reserved gate exists to prevent from the other
  direction, and a violation of the Sema-to-CodeGen contract, which says every
  fact CodeGen needs about the source program was established by Sema.

  Every component type reached it. `<` on two slices of real emitted an
  unsigned integer comparison, which is three wrong things in one instruction.

  6.8.3.5 gives an array no relational operators at all -- not equality, not
  order -- and a slice is an array's components with the extent taken out, so
  there was never anything for the dialect to extend. The one array-like thing
  that does compare is a string-type, and a slice is not one: `IsStringOrChar`
  answers no, which is why this needs its own branch rather than a condition on
  an existing one.

  No conformance-mode program can reach any of this, slices being dialect-only,
  which is why 618 cases were green over it. It was found by following the one
  case in tests/extended/ that dialect-containment reports as divergent. }
program SliceCompare(output);
var
  a: array [1..8] of integer;
  c: array [1..8] of char;
  x: array [1..8] of real;
  b: array [1..2] of integer;
begin
  { All six operators, because the leak was in the branch none of them
    reached rather than in any one of them. }
  writeln(a[1..2] =  a[3..4]);
  writeln(a[1..2] <> a[3..4]);
  writeln(a[1..2] <  a[3..4]);
  writeln(a[1..2] >  a[3..4]);
  writeln(a[1..2] <= a[3..4]);
  writeln(a[1..2] >= a[3..4]);

  { The component type is not what decides it. A slice of char is not a
    string-type -- it is unpacked and its extent is not in its type -- so the
    padded comparison 6.8.3.5 gives two strings does not apply to it either. }
  writeln(c[1..2] = c[3..4]);

  { and `<` on two of these emitted `icmp ult` on a real. }
  writeln(x[1..2] < x[3..4]);

  { One operand is enough: there is no type on the other side that would make
    the comparison mean something. }
  writeln(a[1..2] = b)
end.
