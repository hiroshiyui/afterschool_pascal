# AP 6.4.4.1 -- a pointer domain that binds a schema's type discriminants and
# leaves its ordinal ones to `new`. The point of it is a *growable* container
# written once: the types decide the layout, which a pointer-type must know,
# and the ordinal discriminants decide the extent, which `new` may vary.
Feature: A pointer domain may bind type discriminants

  @afterschool:6.4.4.1
  Scenario: the ordinal discriminant is still supplied by new
    Given the Afterschool Pascal program
      """
      program p(output);
      type Vec(T: type; cap: integer) = record n: integer; a: array [1..cap] of T end;
           IV = ^Vec(integer);
      var a, b: IV;
      begin
        new(a, 4); new(b, 9);
        writeln(a^.cap:1, ' ', b^.cap:1);
        dispose(a); dispose(b)
      end.
      """
    When it is compiled and run
    Then it prints
      """
      4 9
      """

  @afterschool:6.4.4.1
  Scenario: one routine grows a container of any element type
    Given the Afterschool Pascal program
      """
      program p(output);
      type Point = record x, y: integer end;
           Vec(T: type; cap: integer) = record n: integer; a: array [1..cap] of T end;
           IV = ^Vec(integer);
           PV = ^Vec(Point);
      procedure Grow(Ptr: type; var v: Ptr; want: integer);
      var fresh: Ptr; i: integer;
      begin
        new(fresh, want);
        fresh^.n := v^.n;
        for i := 1 to v^.n do fresh^.a[i] := v^.a[i];
        dispose(v); v := fresh
      end;
      var a: IV; b: PV; q: Point;
      begin
        new(a, 1); a^.n := 1; a^.a[1] := 42; Grow(IV, a, 5);
        new(b, 1); b^.n := 1; q.x := 7; b^.a[1] := q; Grow(PV, b, 3);
        writeln(a^.a[1]:1, ' ', a^.cap:1, ' ', b^.a[1].x:1, ' ', b^.cap:1);
        dispose(a); dispose(b)
      end.
      """
    When it is compiled and run
    Then it prints
      """
      42 5 7 3
      """

  @afterschool:6.4.4.1
  Scenario: as many type-names as the schema has type discriminants
    Given the Afterschool Pascal program
      """
      program p(output);
      type Vec(T: type; cap: integer) = record n: integer; a: array [1..cap] of T end;
      var a: ^Vec(integer, char);
      begin end.
      """
    When it is compiled
    Then it is rejected
    And the diagnostic includes
      """
      fewer type discriminants than this domain names
      """

  @afterschool:6.4.4.1
  Scenario: each shall denote a type
    Given the Afterschool Pascal program
      """
      program p(output);
      type Vec(T: type; cap: integer) = record n: integer; a: array [1..cap] of T end;
      var a: ^Vec(3);
      begin end.
      """
    When it is compiled
    Then it is rejected
    And the diagnostic includes
      """
      must name a type
      """

  @afterschool:6.4.4.2
  Scenario: the same named type on both sides is one type
    Given the Afterschool Pascal program
      """
      program p(output);
      type Vec(T: type; cap: integer) = record n: integer; a: array [1..cap] of T end;
           IV = ^Vec(integer);
      var a, b: IV;
      begin new(a, 3); a^.n := 8; b := a; writeln(b^.n:1); dispose(b) end.
      """
    When it is compiled and run
    Then it prints
      """
      8
      """

  @afterschool:6.4.4.2
  Scenario: two separate denoters are two types, as 6.4.1 says
    Given the Afterschool Pascal program
      """
      program p(output);
      type Vec(T: type; cap: integer) = record n: integer; a: array [1..cap] of T end;
      var a: ^Vec(integer); b: ^Vec(integer);
      begin new(a, 3); b := a end.
      """
    When it is compiled
    Then it is rejected
    And the diagnostic includes
      """
      each type-denoter that is not a type name denote a type of its own
      """
