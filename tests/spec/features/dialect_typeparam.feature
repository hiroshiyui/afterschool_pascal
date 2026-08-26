# AP 6.7.3.10 -- a routine parameterised by a type. The spelling is a position
# (6.7.3.1 admits `type` only as the first word of a type-inquiry), so the
# dialect reserves nothing for it; the routine is translated once per distinct
# type it is activated with, which is 6.4.7's rule for a schema said for a
# routine.
Feature: A routine may be parameterised by a type

  @afterschool:6.7.3.10
  Scenario: one body serves two types
    Given the Afterschool Pascal program
      """
      program p(output);
      type Point = record x, y: integer end;
      procedure Swap(T: type; var a, b: T);
      var q: T;
      begin q := a; a := b; b := q end;
      var i, j: integer; u, v: Point;
      begin
        i := 3; j := 7; Swap(integer, i, j);
        u.x := 1; v.x := 8; Swap(Point, u, v);
        writeln(i:1, ' ', j:1, ' ', u.x:1, ' ', v.x:1)
      end.
      """
    When it is compiled and run
    Then it prints
      """
      7 3 8 1
      """

  @afterschool:6.7.3.10
  Scenario: a type parameter names a type for the body as well as the heading
    Given the Afterschool Pascal program
      """
      program p(output);
      procedure Sum(T: type; var a: T; var out: integer);
      var q: T;
      begin q := a; out := 1 end;
      var c: char; n: integer;
      begin c := 'x'; Sum(char, c, n); writeln(n:1) end.
      """
    When it is compiled and run
    Then it prints
      """
      1
      """

  @afterschool:6.7.3.10.1
  Scenario: the actual matching a type parameter must name a type
    Given the Afterschool Pascal program
      """
      program p(output);
      procedure P(T: type; var a: T);
      begin a := a end;
      var i: integer;
      begin P(i, i) end.
      """
    When it is compiled
    Then it is rejected
    And the diagnostic includes
      """
      must name a type
      """

  @afterschool:6.7.3.10.1
  Scenario: the type arguments must be there at all
    Given the Afterschool Pascal program
      """
      program p(output);
      procedure P(T: type; var a: T);
      begin a := a end;
      begin P end.
      """
    When it is compiled
    Then it is rejected
    And the diagnostic includes
      """
      needs a type here
      """

  @afterschool:6.7.3.10.2
  Scenario: a recursive generic activation reaches the routine being produced
    Given the Afterschool Pascal program
      """
      program p(output);
      function Depth(T: type; var a: T; n: integer): integer;
      begin
        if n <= 0 then Depth := 0 else Depth := 1 + Depth(T, a, n - 1)
      end;
      var i: integer;
      begin i := 0; writeln(Depth(integer, i, 4):1) end.
      """
    When it is compiled and run
    Then it prints
      """
      4
      """

  @afterschool:6.7.3.10.2
  Scenario: a generic nothing activates produces nothing, and is not checked
    Given the Afterschool Pascal program
      """
      program p(output);
      type Point = record x, y: integer end;
      procedure Never(T: type; var a: T);
      var q: Point;
      begin q.x := a.thisFieldDoesNotExist end;
      begin writeln('ok') end.
      """
    When it is compiled and run
    Then it prints
      """
      ok
      """

  @afterschool:6.7.3.10.3
  Scenario: a type parameter occupies no argument position
    Given the Afterschool Pascal program
      """
      program p(output);
      procedure P(T: type; var a: T);
      begin a := a end;
      var i: integer;
      begin P(integer) end.
      """
    When it is compiled
    Then it is rejected
    And the diagnostic includes
      """
      takes 1 argument(s), but 0 were given
      """
