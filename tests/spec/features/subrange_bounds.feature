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
