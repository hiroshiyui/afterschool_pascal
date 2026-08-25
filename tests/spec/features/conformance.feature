# Clause 5.1 -- what a processor complying with the standard must do about a
# program that does not comply with it.
#
# This clause was filed `structural` with the reason "states what a processor
# or a program is, not what either does", and that is exactly backwards: 5.1
# is six lettered requirements about what a processor *does*, and two of them
# are the general rule behind every rejection and every trap this compiler
# makes. They are stated in no other clause -- 6.4.6 says what
# assignment-compatibility is, and 5.1 e) is why a program that lacks it does
# not run.
#
# The two halves are separate because the standard separates them. A violation
# that is not designated an error must be reported *before* execution and
# execution prevented; a violation that is designated an error may be treated
# in one of three ways, and this processor takes the third for all but the
# errors doc/implementation-defined.md 3 lists under the first.
#
# 5.2 is the other half of clause 5 and stays structural: it requires of a
# *program*, and a processor cannot be tested against a program's conformance.
Feature: Conformance

  @iso7185:5.1
  Scenario: a violation is reported and the program-block is not executed
    Given the ISO 7185 program
      """
      program p(output);
      var i: integer;
      begin i := 'a'; writeln('this must not run') end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      cannot assign char to a variable of type integer
      """

  @iso7185:5.1
  Scenario: an error is reported and the program stops
    Given the ISO 7185 program
      """
      program p(output);
      var s: 1..10; i: integer;
      begin i := 20; s := i; writeln(s) end.
      """
    When it is compiled and run
    Then it stops at run time
     And the run-time error includes
      """
      value out of range (1..10)
      """

  @extended:5.1
  Scenario: a violation is reported and the program-block is not activated
    Given the Extended Pascal program
      """
      program p(output);
      var i: integer;
      begin i := 'a'; writeln('this must not run') end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      cannot assign char to a variable of type integer
      """

  @extended:5.1
  Scenario: a dynamic-violation is reported and the program stops
    Given the Extended Pascal program
      """
      program p(output);
      var s: 1..10; i: integer;
      begin i := 20; s := i; writeln(s) end.
      """
    When it is compiled and run
    Then it stops at run time
     And the run-time error includes
      """
      value out of range (1..10)
      """
