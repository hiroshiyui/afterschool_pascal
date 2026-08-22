# ISO/IEC 10206:1991 §6.9.4 -- what it means for a statement to threaten a
# variable-access -- and §6.7.2, the one rule that reads the answer:
# a function-block shall contain "at least one statement threatening" its
# result variable.
#
# §6.9.4's list has ten entries, and e) is the one that is easy to leave out
# because `new` does not look like a write: "S is a procedure-statement that
# specifies activation of the required procedure new, and V is the
# variable-access p". §6.7.5.3 is the same fact stated the other way -- new
# "shall attribute to p" the identifying-value of the created variable.
#
# Leaving it out has a consequence with no workaround: a constructor's result
# is a pointer, so there is nothing to assign it *but* new.

@extended:6.9.4 @extended:6.7.2
Feature: The procedure new threatens its pointer variable

  Scenario: a function whose result is allocated rather than assigned is accepted
    Given the Extended Pascal program
      """
      program p(output);
      type link = ^node;
           node = record value_: integer end;
      function make(v: integer) = res: link;
      begin
        new(res);
        res^.value_ := v
      end;
      var q: link;
      begin
        q := make(42);
        writeln(q^.value_:1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      42
      """

  Scenario: a function that writes to its result variable in no way at all is still refused
    Given the Extended Pascal program
      """
      program p(output);
      type link = ^node;
           node = record value_: integer end;
      function make(v: integer) = res: link;
      var other: link;
      begin
        new(other);
        other^.value_ := v
      end;
      begin
      end.
      """
    When it is compiled
    Then it is rejected
