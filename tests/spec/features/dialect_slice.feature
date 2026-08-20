# Slice parameters, AP 6.7.3.9. The bounds requirement has two halves that a
# wrong implementation could satisfy one of -- the check where a slice is taken
# and the check where one is indexed are different checks against different
# bounds -- so both are written.
@afterschool:6.7.3.9.1
Feature: Slice parameters

  @afterschool:6.7.3.9.4
  Scenario: a slice is indexed from 1 whatever the bounds of the array it views
    Given the Afterschool Pascal program
      """
      program p(output);
      procedure Show(protected var a: array of integer);
      begin writeln(a[1], ' ', length(a)) end;
      var v: array [10..14] of integer; i: integer;
      begin
        for i := 10 to 14 do v[i] := i;
        Show(v[12..14])
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      12 3
      """

  @afterschool:6.7.3.9.5
  Scenario: taking a slice outside the array's own bounds stops the program
    Given the Afterschool Pascal program
      """
      program p(output);
      procedure Show(protected var a: array of integer);
      begin writeln(length(a)) end;
      var v: array [1..5] of integer;
      begin Show(v[2..9]) end.
      """
    When it is compiled and run
    Then it stops at run time
     And the run-time error includes
      """
      is not within a sequence of 5 components
      """

  @afterschool:6.7.3.9.5
  Scenario: an empty slice is not an error
    Given the Afterschool Pascal program
      """
      program p(output);
      function L(protected var a: array of integer): integer;
      begin L := length(a) end;
      var v: array [1..5] of integer;
      begin writeln(L(v[3..2])) end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      0
      """

  @afterschool:6.5.3.2
  Scenario: indexing a slice is checked against the slice's own length
    Given the Afterschool Pascal program
      """
      program p(output);
      procedure Show(protected var a: array of integer);
      begin writeln(a[9]) end;
      var v: array [1..5] of integer;
      begin Show(v[2..4]) end.
      """
    When it is compiled and run
    Then it stops at run time
     And the run-time error includes
      """
      array index out of bounds (1..3)
      """

  @afterschool:6.7.3.9.2
  Scenario: a slice may not be the type of anything but a formal parameter
    Given the Afterschool Pascal program
      """
      program p(output);
      type reals = array of real;
      begin end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      'array of' is a parameter form and not a type
      """

  @afterschool:6.7.3.9.3
  Scenario: a slice is never a value parameter
    Given the Afterschool Pascal program
      """
      program p(output);
      procedure f(a: array of integer);
      begin end;
      begin end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      a slice must be a var parameter
      """

  @afterschool:6.7.6
  Scenario: a slice of a slice is itself an actual, and length follows it
    Given the Afterschool Pascal program
      """
      program p(output);
      procedure inner(protected var a: array of integer);
      begin writeln(length(a), ' ', a[1]) end;
      procedure outer(protected var a: array of integer);
      begin inner(a[2..3]) end;
      var v: array [1..5] of integer; i: integer;
      begin
        for i := 1 to 5 do v[i] := i * 10;
        outer(v)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      2 20
      """

  @afterschool:6.4.5
  Scenario: two slices are compatible when their components are, whatever their lengths
    Given the Afterschool Pascal program
      """
      program p(output);
      function Sum(protected var a: array of integer): integer;
      var i, t: integer;
      begin t := 0; for i := 1 to length(a) do t := t + a[i]; Sum := t end;
      var v: array [1..5] of integer; w: array [1..2] of integer; i: integer;
      begin
        for i := 1 to 5 do v[i] := i;
        for i := 1 to 2 do w[i] := 10;
        writeln(Sum(v), ' ', Sum(w), ' ', Sum(v[2..3]))
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      15 20 5
      """
