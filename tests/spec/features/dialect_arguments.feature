# AP 6.7.6.10 -- argcount and argument(k), the command line as a list. The
# harness runs a program with no arguments, so what a scenario can see is the
# count at its floor, the error one past it, and the shadowing 6.1.3 grants.
@afterschool:6.7.6.10
Feature: Program-argument functions

  Scenario: argcount is the number of arguments, and a program run with none has zero
    Given the Afterschool Pascal program
      """
      program p(output);
      begin writeln(argcount:1) end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      0
      """

  Scenario: argument(k) outside 1..argcount is an error
    Given the Afterschool Pascal program
      """
      program p(output);
      begin writeln(argument(1)) end.
      """
    When it is compiled and run
    Then it stops at run time
     And the run-time error includes
      """
      argument 1 is not in 1..0
      """

  Scenario: a program's own declaration takes the spelling
    Given the Afterschool Pascal program
      """
      program p(output);
      var argcount: integer;
      function argument(k: integer): integer;
      begin argument := k + argcount end;
      begin argcount := 40; writeln(argument(2):1) end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      42
      """
