# AP 6.4.7.1 -- a discriminant that names a type. Each scenario asks one
# sentence of the clause; the identity ones are the load-bearing pair, since
# 6.4.8's interning is the whole of what makes such a production a type rather
# than a fresh record each time.
@afterschool:6.4.7.1
Feature: Type-valued discriminants

  Scenario: a schema produces a container for each element type
    Given the Afterschool Pascal program
      """
      program p(output);
      type Vec(T: type) = record a: array [1..2] of T end;
           Point = record x, y: integer end;
      var vi: Vec(integer); vp: Vec(Point);
      begin
        vi.a[1] := 7;
        vp.a[1].x := 3;
        writeln(vi.a[1]:1, ' ', vp.a[1].x:1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      7 3
      """

  @afterschool:6.4.7.1
  Scenario: two productions naming one type are one type
    Given the Afterschool Pascal program
      """
      program p(output);
      type Vec(T: type) = record a: array [1..2] of T end;
      var x: Vec(integer); y: Vec(integer);
      begin
        x.a[1] := 5;
        y := x;
        writeln(y.a[1]:1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      5
      """

  @afterschool:6.4.7.1
  Scenario: two productions naming different types are different types
    Given the Afterschool Pascal program
      """
      program p(output);
      type Vec(T: type) = record a: array [1..2] of T end;
           Point = record x, y: integer end;
      var x: Vec(integer); y: Vec(Point);
      begin
        x := y
      end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      cannot assign vec(point) to a variable of type vec(integer)
      """

  @afterschool:6.4.7.1
  Scenario: a type discriminant may stand beside an ordinary one
    Given the Afterschool Pascal program
      """
      program p(output);
      type Vec(T: type; cap: integer) = record a: array [1..cap] of T end;
      var v: Vec(char, 3); k: integer;
      begin
        v.a[1] := 'a'; v.a[2] := 'b'; v.a[3] := 'c';
        for k := 1 to 3 do write(v.a[k]);
        writeln
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      abc
      """

  @afterschool:6.4.7.1
  Scenario: the actual discriminant for a type must be a type name
    Given the Afterschool Pascal program
      """
      program p(output);
      type Vec(T: type) = record a: array [1..2] of T end;
      var v: Vec(4);
      begin
        v.a[1] := 0
      end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      is a type, so a type name belongs here
      """

  @afterschool:6.4.7.1
  Scenario: such a schema may not be a parameter form
    Given the Afterschool Pascal program
      """
      program p(output);
      type Vec(T: type) = record a: array [1..2] of T end;
      procedure q(var v: Vec);
      begin end;
      begin
      end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      has a type discriminant, so a parameter of it must name the types
      """
