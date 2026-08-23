# AP 6.4.13 -- the fallible-type: the result record a module would otherwise
# write per payload type, with the field names fixed by the language. Each
# scenario asks one half of one clause.
@afterschool:6.4.13.1
Feature: Fallible-types

  Scenario: neither side may itself be fallible
    Given the Afterschool Pascal program
      """
      program p(output);
      type c = (e1, e2);
           r = integer ! c;
           n = r ! c;
      var q: n;
      begin writeln(q.ok) end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      neither side of '!' may itself be fallible
      """

  @afterschool:6.4.13.1
  Scenario: neither side may contain a file
    Given the Afterschool Pascal program
      """
      program p(output);
      type c = (e1, e2);
           r = text ! c;
      var q: r;
      begin writeln(q.ok) end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      neither side of '!' may contain a file or a handle
      """

  @afterschool:6.4.13.2
  Scenario: it is the record, and the tag says which arm was written
    Given the Afterschool Pascal program
      """
      program p(output);
      type c = (e1, e2);
           r = integer ! c;
      var q: r;
      begin
        q.val := 5;
        writeln(q.ok, ' ', q.val:1);
        q.cause := e2;
        writeln(q.ok, ' ', ord(q.cause):1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      TRUE 5
      FALSE 1
      """

  @afterschool:6.4.13.2
  Scenario: reading the arm the tag does not select is detected
    Given the Afterschool Pascal program
      """
      program p(output);
      type c = (e1, e2);
           r = integer ! c;
      var q: r;
      begin
        q.cause := e2;
        writeln(q.val:1)
      end.
      """
    When it is compiled and run
    Then it stops at run time
     And the run-time error includes
      """
      variant: the tag selects another arm
      """

  @afterschool:6.4.13.3
  Scenario: a value of either side may be assigned, and which one decides the outcome
    Given the Afterschool Pascal program
      """
      program p(output);
      type c = (e1, e2);
           r = integer ! c;
      var q: r;
      begin
        q := 9;
        writeln(q.ok, ' ', q.val:1);
        q := e2;
        writeln(q.ok, ' ', ord(q.cause):1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      TRUE 9
      FALSE 1
      """

  @afterschool:6.4.13.3
  Scenario: a value both sides admit names no outcome
    Given the Afterschool Pascal program
      """
      program p(output);
      type r = integer ! 1..5;
      var q: r;
      begin
        q := 3;
        writeln(q.ok)
      end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      admit this value, so the assignment does not say which outcome it means
      """

  @afterschool:6.4.13.3
  Scenario: nothing is assignable out of a fallible type
    Given the Afterschool Pascal program
      """
      program p(output);
      type c = (e1, e2);
           r = integer ! c;
      var q: r; i: integer;
      begin
        q := 1;
        i := q;
        writeln(i)
      end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      cannot assign r to a variable of type integer
      """

  @afterschool:6.4.13.4
  Scenario: the tag may be read and not assigned
    Given the Afterschool Pascal program
      """
      program p(output);
      type c = (e1, e2);
           r = integer ! c;
      var q: r; b: boolean;
      begin
        q := 1;
        b := q.ok;
        q.ok := false;
        writeln(b)
      end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      the tag of a fallible type says which outcome was written
      """
