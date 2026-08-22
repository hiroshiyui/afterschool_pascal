# ISO/IEC 10206:1991 §6.4.2.4 -- a subrange-bound is an *expression*, which is
# the one word separating this clause from ISO 7185's `subrange-type = constant
# '..' constant`. §6.2.3.8 b) says when such an expression is evaluated: in the
# commencement of the activation, for each bound "closest-contained by ... the
# block".
#
# The scenarios below are the clause read as requirements rather than as a
# lowering. What makes them worth writing separately from `tests/extended/` is
# that three of the four were true of no compiler this project shipped until
# ADR-0133, and each was refused or wrong for a different reason: the bound was
# accepted only where an array's subscript check would read it.

@extended:6.4.2.4
Feature: Subrange bounds are expressions

  @extended:6.2.3.8
  Scenario: a bound may be a value parameter of the enclosing block
    Given the Extended Pascal program
      """
      program p(output);
      procedure q(m: integer);
      var x: 1..m;
      begin
        x := m;
        writeln(x : 1)
      end;
      begin q(3) end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      3
      """

  Scenario: a value outside such a subrange is an error
    Given the Extended Pascal program
      """
      program p(output);
      procedure q(m: integer);
      var x: 1..m; k: integer;
      begin
        k := m + 1;
        x := k;
        writeln(x : 1)
      end;
      begin q(3) end.
      """
    When it is compiled and run
    Then it stops at run time
     And the run-time error includes
      """
      value out of range (1..3)
      """

  Scenario: the bound is evaluated once, at the commencement of the activation
    Given the Extended Pascal program
      """
      program p(output);
      var calls: integer;
      function bound: integer;
      begin
        calls := calls + 1;
        bound := 3
      end;
      procedure q;
      type t = 1..bound;
      var x, y: t;
      begin
        x := 1; y := 3;
        writeln(calls : 1, x : 1, y : 1)
      end;
      begin
        calls := 0;
        q;
        q
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      113
      213
      """

  Scenario: the first bound may not exceed the second
    Given the Extended Pascal program
      """
      program p(output);
      procedure q(m: integer);
      var x: 2..m;
      begin
        writeln('unreached', x : 1)
      end;
      begin q(1) end.
      """
    When it is compiled and run
    Then it stops at run time

  Scenario: ISO 7185 admits no such bound
    Given the ISO 7185 program
      """
      program p(output);
      procedure q(m: integer);
      var x: 1..m;
      begin
        writeln(x : 1)
      end;
      begin q(3) end.
      """
    When it is compiled
    Then it is rejected

  # ISO/IEC 10206:1991 §6.8.2 defines a constant-expression by what it must not
  # contain, and the exclusion for required functions is narrow: clause c)
  # reaches only a function "that has a defining-point contained by the
  # program-block" or "eof or eoln". §6.2.2.10 puts every required identifier
  # in a region *enclosing* the program, so no required function is caught by
  # the first half, and NOTE 1 names the only others — empty, position and
  # LastPosition — and gives the reason: they need a variable as a parameter.
  #
  # So the Extended Pascal additions belong in a constant-expression, and this
  # compiler refused two of them: `succ(x,k)` and `pred(x,k)`, because the
  # folder walked a single argument, and `length`, which had no arm at all.
  # A constant-expression is what a bound is, so the refusal reached
  # declarations and not only constant-definitions.
  @extended:6.8.2
  Scenario: a required function with a second argument is nonvarying
    Given the Extended Pascal program
      """
      program p(output);
      const k = succ(1, 3);
            j = pred(9, 2);
      var small: succ(0, 1)..pred(10, 4);
      begin
        small := 6;
        writeln(k : 1, ' ', j : 1, ' ', small : 1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      4 7 6
      """

  # §6.7.6.7's length of a string constant, used where §6.4.3.2 wants a
  # constant-expression: an array's index-type.
  @extended:6.8.2
  Scenario: length of a string constant is a bound
    Given the Extended Pascal program
      """
      program p(output);
      const greeting = 'hello';
      var buf: packed array [1..length(greeting)] of char;
          i: integer;
      begin
        for i := 1 to length(greeting) do buf[i] := greeting[i];
        writeln(buf)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      hello
      """

  # The other half, and it is a restriction of this processor rather than of
  # the clause: a real constant is carried as the text that was written and is
  # never converted to a number, so `trunc` in a constant-expression would need
  # a conversion that does not exist here. §6.8.2 permits it; this says so
  # rather than reporting the expression as not constant, which would be a
  # complaint about the program. doc/implementation-defined.md §6 records it.
  @extended:6.8.2
  Scenario: a real-argument required function is a documented restriction
    Given the Extended Pascal program
      """
      program p(output);
      const cut = trunc(3.7);
      begin writeln(cut : 1) end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      a real constant is carried as the text that was written
      """
