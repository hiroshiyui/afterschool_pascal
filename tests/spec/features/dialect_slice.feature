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

  # AP 6.8.3.5 is a restriction that exists because AP 6.4.5 above is an
  # extension. The scenario immediately above makes two slices of different
  # lengths compatible so that one parameter accepts either; the relational
  # operators ask compatibility too, so without this clause the permission
  # granted there arrives here (ADR-0139). The two are neighbours on purpose.
  @afterschool:6.8.3.5
  Scenario: compatible is not comparable, and a slice has no relational operators
    Given the Afterschool Pascal program
      """
      program p(output);
      var v: array [1..8] of integer;
      begin writeln(v[1..2] = v[3..4]) end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      a slice cannot be compared
      """

  # The component type is not what decides it: a slice of char is unpacked and
  # its length is not in its type, so it is not a string-type and the padded
  # comparison two string-types get does not reach it.
  @afterschool:6.8.3.5
  Scenario: a slice of char is not a string, and does not compare as one
    Given the Afterschool Pascal program
      """
      program p(output);
      var c: array [1..8] of char;
      begin writeln(c[1..2] < c[3..4]) end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      6.8.3.5 gives an array no relational operators
      """

  # AP 6.4.6's own sentence, and not the cross-reference its triage row described
  # for a long time: *no value shall be assignment-compatible with a slice, and a
  # slice shall not be assignment-compatible with any type*. Both directions,
  # because a shared predicate that grants one grants the other -- ADR-0143's
  # defect was `Assignable` letting an array through a slice arm placed ahead of
  # it, so one array's contents were copied over another's and the program exited
  # 0. Found by the triage audit rather than by a gate (ADR-0200).
  @afterschool:6.4.6
  Scenario: a slice cannot be assigned to
    Given the Afterschool Pascal program
      """
      program p(output);
      var a: array [1..3] of integer;
      procedure q(var s: array of integer);
      var b: array [1..3] of integer;
      begin b[1] := 1; s := b end;
      begin a[1] := 1; q(a) end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      a slice cannot be assigned
      """

  @afterschool:6.4.6
  Scenario: a slice cannot be assigned from
    Given the Afterschool Pascal program
      """
      program p(output);
      var a: array [1..3] of integer;
      procedure q(var s: array of integer);
      var b: array [1..3] of integer;
      begin b := s; writeln(b[1]) end;
      begin a[1] := 1; q(a) end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      a slice cannot be assigned
      """
