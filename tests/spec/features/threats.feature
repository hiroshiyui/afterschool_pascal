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
#
# b) is the entry with two consumers, and a conformant array parameter reached
# neither of them: "S contains V in an actual-parameter that is an actual
# variable parameter corresponding to a formal variable parameter that is not
# protected". §6.7.3.7.3 calls a variable conformant array's actual exactly
# that -- "Each actual-parameter corresponding to a formal variable parameter
# shall be a variable-access" -- and §6.5.1's own cross-reference names
# §6.7.3.7.1 as one of the three places a protected variable-identifier comes
# from, that clause letting the specification itself say `protected`.
#
# The value form is not on the list and must not be: §6.7.3.7.2 attributes the
# expression's value to a variable of the activation, so the actual is read and
# never written.

@extended:6.9.4 @extended:6.7.2 @extended:6.5.1
@extended:6.7.3.7.1 @extended:6.7.3.7.2 @extended:6.7.3.7.3
Feature: What threatens a variable, and what reads the answer

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

  Scenario: a protected variable is refused where a variable conformant array formal is not protected
    Given the Extended Pascal program
      """
      program p(output);
      type triple = array [1..3] of integer;
      procedure writes(var a: array [lo..hi: integer] of integer);
      begin a[lo] := 0 end;
      procedure hands(protected var v: triple);
      begin writes(v) end;
      var g: triple;
      begin g[1] := 1; hands(g) end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      is a protected parameter, so it cannot be passed to the var parameter
      """

  Scenario: a protected variable may be handed to a conformant array formal that is protected too
    Given the Extended Pascal program
      """
      program p(output);
      type triple = array [1..3] of integer;
      procedure shows(protected var a: array [lo..hi: integer] of integer);
      begin writeln(a[lo]:1) end;
      procedure hands(protected var v: triple);
      begin shows(v) end;
      var g: triple;
      begin g[1] := 7; hands(g) end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      7
      """

  Scenario: a result variable filled through a variable conformant array is accepted
    Given the Extended Pascal program
      """
      program p(output);
      type triple = array [1..3] of integer;
      procedure fill(var a: array [lo..hi: integer] of integer);
      var i: integer;
      begin for i := lo to hi do a[i] := i * 10 end;
      function ramp = res: triple;
      begin fill(res) end;
      var r: triple;
      begin r := ramp; writeln(r[2]:1) end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      20
      """

  Scenario: a result variable only handed to a value conformant array is still refused
    Given the Extended Pascal program
      """
      program p(output);
      type triple = array [1..3] of integer;
      var n: integer;
      procedure total(a: array [lo..hi: integer] of integer);
      begin n := a[lo] end;
      function copied = res: triple;
      begin total(res) end;
      begin
      end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      never writes to its result variable
      """
