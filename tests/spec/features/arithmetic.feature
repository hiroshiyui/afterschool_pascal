# ISO 7185 §6.7.2.2 -- the arithmetic operators, and the places Pascal's
# answers differ from the obvious lowering onto a machine instruction.
#
# Every scenario here is a rule that a C-shaped implementation gets wrong for
# free: `mod` is not a remainder, `/` is not integer division, a leading sign
# binds further left than it looks, and overflow is an error rather than a
# wrap. §6.7.2.2's error conditions are the last of those, and Annex D is what
# makes them errors a processor must be able to report.

@iso7185:6.7.2.2
Feature: Arithmetic operators

  Scenario: mod yields a non-negative result
    Given the ISO 7185 program
      """
      program p(output);
      var n: integer;
      begin
        n := -7;
        writeln(n mod 3 : 1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      2
      """

  Scenario: a divisor that is not positive is an error for mod
    Given the ISO 7185 program
      """
      program p(output);
      var n, j: integer;
      begin
        n := 7;
        j := -3;
        writeln(n mod j : 1)
      end.
      """
    When it is compiled and run
    Then it stops at run time
     And the run-time error includes
      """
      mod
      """

  Scenario: div truncates toward zero, which mod does not follow
    Given the ISO 7185 program
      """
      program p(output);
      var n: integer;
      begin
        n := -7;
        writeln(n div 2 : 1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      -3
      """

  Scenario: division by zero is an error
    Given the ISO 7185 program
      """
      program p(output);
      var n, z: integer;
      begin
        n := 7;
        z := 0;
        writeln(n div z : 1)
      end.
      """
    When it is compiled and run
    Then it stops at run time

  Scenario: a leading sign applies to the whole term
    Given the ISO 7185 program
      """
      program p(output);
      begin
        writeln(-7 mod 3 : 1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      -1
      """

  Scenario: the divide operator is real division whatever its operands
    Given the ISO 7185 program
      """
      program p(output);
      begin
        writeln(7 / 2 : 4 : 1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
       3.5
      """

  Scenario: integer overflow is an error rather than a wrap
    Given the ISO 7185 program
      """
      program p(output);
      var n: integer;
      begin
        n := maxint;
        n := n + 1;
        writeln(n : 1)
      end.
      """
    When it is compiled and run
    Then it stops at run time
