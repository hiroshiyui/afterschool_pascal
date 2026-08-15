# ISO/IEC 10206:1991 §6.7.6.7 and §6.8.3.5 -- the two ways to compare strings,
# which are deliberately not the same comparison.
#
# The relational operators pad the shorter operand with spaces; the required
# functions EQ, LT and their family compare lengths as well. §6.7.6.7's NOTE 3
# says outright that LT(a, b) may be false while a < b is true, so a suite that
# checked only one of them would be satisfied by an implementation that had
# unified them -- which is the mistake the note exists to prevent.
#
# The padding rule is also what retired ISO 7185's requirement that string
# operands be of equal length, so the same program means different things under
# the two standards.

@extended:6.7.6.7 @extended:6.8.3.5
Feature: String comparison

  Scenario: the relational operators pad the shorter operand with spaces
    Given the Extended Pascal program
      """
      program p(output);
      var a, b: string(8);
      begin
        a := 'ab';
        b := 'ab  ';
        writeln(a = b)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      TRUE
      """

  Scenario: EQ compares the lengths too, so the same pair is unequal
    Given the Extended Pascal program
      """
      program p(output);
      var a, b: string(8);
      begin
        a := 'ab';
        b := 'ab  ';
        writeln(EQ(a, b))
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      FALSE
      """

  Scenario: a shorter string orders before a longer one that extends it
    Given the Extended Pascal program
      """
      program p(output);
      var a, b: string(8);
      begin
        a := 'ab';
        b := 'abc';
        writeln(a < b, ' ', LT(a, b))
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      TRUE TRUE
      """

@extended:6.4.3.3.2 @extended:6.7.6.7
Feature: Fixed-string-types and the string functions

  Scenario: length reports the value's length, not the capacity
    Given the Extended Pascal program
      """
      program p(output);
      var s: string(20);
      begin
        s := 'hello';
        writeln(length(s) : 1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      5
      """

  Scenario: substr of length zero is the null-string
    Given the Extended Pascal program
      """
      program p(output);
      var s: string(20);
      begin
        s := 'hello';
        writeln(length(substr(s, 3, 0)) : 1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      0
      """

  Scenario: a substring-variable with a lower bound above its upper is an error
    Given the Extended Pascal program
      """
      program p(output);
      var s: string(20); i, j: integer;
      begin
        s := 'hello';
        i := 3;
        j := 2;
        writeln(s[i .. j])
      end.
      """
    When it is compiled and run
    Then it stops at run time

  Scenario: assigning a value longer than the capacity is an error
    Given the Extended Pascal program
      """
      program p(output);
      var s: string(3);
      var t: string(10);
      begin
        t := 'abcdefg';
        s := t;
        writeln(s)
      end.
      """
    When it is compiled and run
    Then it stops at run time
