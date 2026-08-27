# ISO/IEC 10206:1991 6.5.6 makes `s[i..i-1]` an error: "it shall be an error if
# ... the value of the first index-expression is greater than the value of the
# second". The dialect widens that condition by exactly one value, so a
# substring of no characters is admissible and a transposed pair is not.
#
# The clause's own capacity -- "one plus the value of the second
# index-expression minus the value of the first" -- is already 0 for the
# admitted case, so the arithmetic needed nothing; only the prohibition was
# removed (ADR-0219).
@afterschool:6.5.6
Feature: The empty substring

  @afterschool:6.5.6
  Scenario: a substring of no characters is not an error
    Given the Afterschool Pascal program
      """
      program p(output);
      var s: string(10);
      begin
        s := 'abcdef';
        writeln('[', s[3..2], ']')
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      []
      """

  # Both ends, because the check is one condition with three disjuncts and each
  # end is a different one: the near end has a second index of zero, and the far
  # end a first index one past the length.
  @afterschool:6.5.6
  Scenario: the empty substring is admitted at either end of the string
    Given the Afterschool Pascal program
      """
      program p(output);
      var s: string(10);
      begin
        s := 'abcdef';
        writeln('[', s[1..0], '][', s[7..6], ']')
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      [][]
      """

  # What makes the bound tight. Relaxing the condition to `hi < lo` rather than
  # `hi < lo - 1` admits this too, and every other scenario here still passes.
  @afterschool:6.5.6
  Scenario: a transposed pair of indices is still an error
    Given the Afterschool Pascal program
      """
      program p(output);
      var s: string(10);
      begin
        s := 'abcdef';
        writeln('[', s[4..2], ']')
      end.
      """
    When it is compiled and run
    Then it stops at run time
     And the run-time error includes
      """
      substring: [4..2] is not within a string of length 6
      """

  # The far end is one past the length and no further.
  @afterschool:6.5.6
  Scenario: a first index more than one past the length is still an error
    Given the Afterschool Pascal program
      """
      program p(output);
      var s: string(10);
      begin
        s := 'abcdef';
        writeln('[', s[8..7], ']')
      end.
      """
    When it is compiled and run
    Then it stops at run time
     And the run-time error includes
      """
      substring: [8..7] is not within a string of length 6
      """

  # Containment: the conformance mode reports the error 6.5.6 states, which is
  # why there is no Annex B row -- the construct is one Extended Pascal has and
  # what changes is when using it is an error.
  @afterschool:6.5.6
  Scenario: the conformance mode still reports the error 6.5.6 states
    Given the Extended Pascal program
      """
      program p(output);
      var s: string(10);
      begin
        s := 'abcdef';
        writeln('[', s[3..2], ']')
      end.
      """
    When it is compiled and run
    Then it stops at run time
     And the run-time error includes
      """
      substring: [3..2] is not within a string of length 6
      """

  # 6.8.8.4's substring-constant is folded rather than emitted, so the same rule
  # is written twice in the compiler and this is the other one. A length-zero
  # literal is 6.1.9's null-string and already has a type.
  @afterschool:6.5.6
  Scenario: a substring-constant may be empty
    Given the Afterschool Pascal program
      """
      program p(output);
      const g = 'hello';
            e = g[1..0];
      begin writeln('[', e, ']') end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      []
      """

  @afterschool:6.5.6
  Scenario: an empty substring-constant is refused by the conformance mode
    Given the Extended Pascal program
      """
      program p(output);
      const g = 'hello';
            e = g[1..0];
      begin writeln('[', e, ']') end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      the substring 1..0 is not within the string constant's 1..5
      """
