# ISO 7185 §6.6.6.4, and the cross-reference that decides what it means.
#
# This is the clause this compiler had wrong in *both* directions for a long
# time, with every oracle agreeing: the compiler trapped where it should not,
# and a test asserted the wrong rule in a comment citing §6.6.6.4 without
# following its cross-reference. The BSI suite's CONF139 is what disagreed.
#
# §6.6.6.4 gives succ a result of "the same type as that of the expression (see
# 6.7.1)", and §6.7.1 is where the rule actually lives: a factor whose type is
# a subrange of T is treated as if it were of type T. So succ of a 1..9 holding
# 9 is 10 -- an integer, not an error -- and what may fail is *storing* it back.
#
# Written as two scenarios because one rule alone cannot distinguish a correct
# implementation from either wrong one.

@iso7185:6.6.6.4 @iso7185:6.7.1
Feature: Ordinal functions

  Scenario: succ of a subrange is computed in the host type, and does not stop there
    Given the ISO 7185 program
      """
      program p(output);
      var d: 1 .. 9;
      begin
        d := 9;
        writeln(succ(d) : 1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      10
      """

  Scenario: pred of a subrange likewise passes below its own lower bound
    Given the ISO 7185 program
      """
      program p(output);
      var d: 1 .. 9;
      begin
        d := 1;
        writeln(pred(d) : 1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      0
      """

  Scenario: storing the result back into the subrange is what fails
    Given the ISO 7185 program
      """
      program p(output);
      var d: 1 .. 9;
      begin
        d := 9;
        d := succ(d);
        writeln(d : 1)
      end.
      """
    When it is compiled and run
    Then it stops at run time

  Scenario: an enumeration does end at its last constant
    Given the ISO 7185 program
      """
      program p(output);
      type colour = (red, green, blue);
      var c: colour;
      begin
        c := blue;
        c := succ(c);
        writeln(ord(c) : 1)
      end.
      """
    When it is compiled and run
    Then it stops at run time

  Scenario: chr outside the character set is an error
    Given the ISO 7185 program
      """
      program p(output);
      var c: char;
      begin
        c := chr(300);
        writeln(c)
      end.
      """
    When it is compiled and run
    Then it stops at run time
