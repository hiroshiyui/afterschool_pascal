# AP 6.4.2.6 -- int64, and the two halves of what it is: numeric where real is
# numeric, and not ordinal anywhere. 6.4.2.6.5 is the clause ADR-0136 settled
# after a probe of it stopped the compiler.
@afterschool:6.4.2.6.1
Feature: The type int64

  Scenario: a literal above maxint denotes a value of int64
    Given the Afterschool Pascal program
      """
      program p(output);
      var a: int64;
      begin a := 5000000000; writeln(a, ' ', maxint64) end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      5000000000 9223372036854775807
      """

  @afterschool:6.4.2.6.3
  Scenario: integer widens to int64 and int64 widens to real
    Given the Afterschool Pascal program
      """
      program p(output);
      var a: int64; i: integer; r: real;
      begin i := 3; a := i; r := a; writeln(a, ' ', r:6:1) end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      3    3.0
      """

  @afterschool:6.4.2.6.2
  Scenario: int64 is refused where an ordinal is wanted
    Given the Afterschool Pascal program
      """
      program p(output);
      var a: int64;
      begin a := 1; writeln(succ(a)) end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      'succ' needs an ordinal argument, found int64
      """

  @afterschool:6.4.2.6.4
  Scenario: trunc is the one narrowing back to integer
    Given the Afterschool Pascal program
      """
      program p(output);
      var a: int64; n: integer;
      begin a := 5; n := trunc(a); writeln(n) end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      5
      """

  @afterschool:6.4.2.6.5
  Scenario: a constant cannot have the type, and the diagnostic says which type
    Given the Afterschool Pascal program
      """
      program p(output);
      const c = 5000000000;
      begin end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      has type int64, and a constant cannot
      """

  @afterschool:6.4.2.6.6
  Scenario: read takes the longest prefix that is a number, at the wide width
    Given the Afterschool Pascal program
      """
      program p(output, input);
      var a: int64;
      begin read(a); writeln(a * 2) end.
      """
    Given the standard input
      """
      4000000000
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      8000000000
      """

  @afterschool:6.2.2
  Scenario: int64 is a required identifier and a program may shadow it
    Given the Afterschool Pascal program
      """
      program p(output);
      type int64 = char;
      var v: int64;
      begin v := 'x'; writeln(v) end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      x
      """
