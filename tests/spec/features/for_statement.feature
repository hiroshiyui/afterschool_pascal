# ISO 7185 §6.8.3.9 -- the for-statement.
#
# Three of its requirements are ones this compiler got wrong or nearly wrong,
# and each is written here as the standard states it rather than as the
# implementation happens to work. That direction is the point of this suite:
# the scenario is derived from the clause, and the compiler either satisfies it
# or does not.

@iso7185:6.8.3.9
Feature: For-statements

  Scenario: the limit is evaluated once, before the loop begins
    Given the ISO 7185 program
      """
      program p(output);
      var i, n, calls: integer;

      function limit: integer;
      begin
        calls := calls + 1;
        limit := n
      end;

      begin
        n := 3;
        calls := 0;
        for i := 1 to limit do
          n := 1;
        writeln(calls : 1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      1
      """

  Scenario: the bounds are checked only if the statement is executed
    Given the ISO 7185 program
      """
      program p(output);
      var i: 0 .. 10;
      begin
        for i := maxint to maxint - 1 do
          writeln('never');
        writeln('empty')
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      empty
      """

  Scenario: a bound outside the control variable's type is an error when the loop runs
    Given the ISO 7185 program
      """
      program p(output);
      var i: 0 .. 10;
      begin
        for i := 1 to 11 do
          writeln(i : 1)
      end.
      """
    When it is compiled and run
    Then it stops at run time

  Scenario: the control variable is declared in the block containing the statement
    Given the ISO 7185 program
      """
      program p(output);
      var i: integer;

      procedure q;
      begin
        for i := 1 to 3 do
          writeln(i : 1)
      end;

      begin
        q
      end.
      """
    When it is compiled
    Then it is rejected

  Scenario: the statement of the loop may not threaten the control variable
    Given the ISO 7185 program
      """
      program p(output);
      var i: integer;
      begin
        for i := 1 to 3 do
          i := i + 1
      end.
      """
    When it is compiled
    Then it is rejected

  Scenario: the final value cannot overflow the loop out of its type
    Given the ISO 7185 program
      """
      program p(output);
      var i: integer; n: integer;
      begin
        n := 0;
        for i := maxint - 2 to maxint do
          n := n + 1;
        writeln(n : 1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      3
      """
