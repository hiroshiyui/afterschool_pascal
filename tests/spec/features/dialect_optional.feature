# The optional type, AP 6.4.11. Each scenario is one requirement of that
# clause, and the pair 6.4.11.5/6.4.11.6 is written as a pair on purpose: a
# wrong implementation could satisfy either alone.
@afterschool:6.4.11.1
Feature: Optional types

  @afterschool:6.4.11.3
  Scenario: nil is the absent value and an ordinary value is not absent
    Given the Afterschool Pascal program
      """
      program p(output);
      type opti = ?integer;
      var v: opti;
      begin
        v := nil;
        if v = nil then writeln('absent');
        v := 42;
        if v <> nil then writeln('present')
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      absent
      present
      """

  @afterschool:6.4.11.5
  Scenario: reading the value of an absent optional stops the program
    Given the Afterschool Pascal program
      """
      program p(output);
      type opti = ?integer;
      var v: opti;
      begin v := nil; writeln(v^) end.
      """
    When it is compiled and run
    Then it stops at run time
     And the run-time error includes
      """
      this optional has no value
      """

  @afterschool:6.4.11.5
  Scenario: the check is not removed by a preceding test of the same variable
    Given the Afterschool Pascal program
      """
      program p(output);
      type opti = ?integer;
      var v: opti; n: integer;
      begin
        v := 7;
        if v <> nil then n := v^;
        writeln(n)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      7
      """

  @afterschool:6.4.11.6
  Scenario: nothing is assignment-compatible from an optional
    Given the Afterschool Pascal program
      """
      program p(output);
      type opti = ?integer;
      var v: opti; n: integer;
      begin v := 1; n := v end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      cannot assign opti to a variable of type integer
      """

  @afterschool:6.4.11.4
  Scenario: an optional compares with nil and with nothing else
    Given the Afterschool Pascal program
      """
      program p(output);
      type opti = ?integer;
      var a, b: opti;
      begin a := 1; b := 1; if a = b then writeln('equal') end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      an optional can only be compared with 'nil'
      """

  @afterschool:6.4.11.2
  Scenario: the component of an optional is not itself an optional
    Given the Afterschool Pascal program
      """
      program p(output);
      type opti = ?integer;
           oo = ?opti;
      var v: oo;
      begin v := nil end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      an optional cannot hold an optional
      """

  @afterschool:6.4.11.7
  Scenario: two separately written optional denoters are two types
    Given the Afterschool Pascal program
      """
      program p(output);
      var a: ?integer; b: ?integer;
      begin a := 1; b := a end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      cannot assign ?integer to a variable of type ?integer
      """
