# §6.8.3.5 in ISO 7185 and §6.9.3.5 in ISO/IEC 10206:1991 -- the same construct
# under two standards that differ in exactly one way: the later one has an
# otherwise-part and the earlier one has nothing to put in its place.
#
# So a selector matching no label is an error in ISO 7185 and is the completer's
# business in Extended Pascal, and the two scenarios below are the same program
# with two different verdicts. That is the shape this suite exists to make
# visible -- a rule that depends on which language the source is written in.

@iso7185:6.8.3.5
Feature: Case-statements

  Scenario: a selector matching no case-constant is an error
    Given the ISO 7185 program
      """
      program p(output);
      var i: integer;
      begin
        i := 7;
        case i of
          1: writeln('one');
          2: writeln('two')
        end
      end.
      """
    When it is compiled and run
    Then it stops at run time

  Scenario: a matched arm runs and the others do not
    Given the ISO 7185 program
      """
      program p(output);
      var i: integer;
      begin
        i := 2;
        case i of
          1: writeln('one');
          2: writeln('two');
          3: writeln('three')
        end
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      two
      """

  Scenario: the same constant may not label two arms
    Given the ISO 7185 program
      """
      program p(output);
      var i: integer;
      begin
        i := 1;
        case i of
          1: writeln('one');
          1: writeln('again')
        end
      end.
      """
    When it is compiled
    Then it is rejected

@extended:6.9.3.5
Feature: Case-statements with an otherwise-part

  Scenario: the otherwise-part takes the values no label selects
    Given the Extended Pascal program
      """
      program p(output);
      var i: integer;
      begin
        i := 7;
        case i of
          1: writeln('one');
          2: writeln('two');
          otherwise writeln('many')
        end
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      many
      """

  Scenario: the semicolon before otherwise is optional
    Given the Extended Pascal program
      """
      program p(output);
      var i: integer;
      begin
        i := 1;
        case i of
          1: writeln('one')
          otherwise writeln('many')
        end
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      one
      """

  Scenario: a case-constant may be a range
    Given the Extended Pascal program
      """
      program p(output);
      var i: integer;
      begin
        i := 5;
        case i of
          1 .. 3: writeln('low');
          4 .. 9: writeln('high')
        end
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      high
      """

  Scenario: otherwise is an ordinary identifier under ISO 7185
    Given the ISO 7185 program
      """
      program p(output);
      var otherwise: integer;
      begin
        otherwise := 3;
        writeln(otherwise : 1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      3
      """
