# AP 6.4.9 (ADR-0215): the dialect's type-inquiry-object is §6.5.1's whole
# variable-access, where ISO/IEC 10206:1991's is a name.
#
#   type-inquiry-object = variable-access .
#
# The reason is 6.7.3.5's type parameter. A routine parameterised by a type is
# handed the container and then handed the element type again, because nothing
# could read the second off the first. `type of v^.a[1]` reads it.
#
# What a conformance mode says about this is in type_inquiry.feature, which is
# the same construct from the other side.

@afterschool:6.4.9
Feature: A type-inquiry's object is a variable-access

  Scenario: an indexed-variable denotes the component type
    Given the Afterschool Pascal program
      """
      program p(output);
      type point = record x, y: integer end;
      var a: array [1..3] of point;
          b: type of a[1];
      begin
        a[2].x := 3; a[2].y := 4;
        b := a[2];
        writeln(b.x + b.y:1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      7
      """

  Scenario: a chain of selectors denotes the type at the end of it
    Given the Afterschool Pascal program
      """
      program p(output);
      type inner = record n: integer end;
           outer = record a: array [1..2] of inner end;
      var q: ^outer;
          b: type of q^.a[1].n;
      begin
        new(q);
        q^.a[1].n := 41;
        b := q^.a[1].n + 1;
        writeln(b:1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      42
      """

  Scenario: the object is not evaluated
    Given the Afterschool Pascal program
      """
      program p(output);
      var a: array [1..3] of integer;
          i: integer;

      function bump: integer;
      begin
        i := i + 1;
        bump := 1
      end;

      var b: type of a[bump];
      begin
        i := 0;
        b := 7;
        writeln(i:1, ' ', b:1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      0 7
      """

  Scenario: a parameter earlier in the same list may be selected
    Given the Afterschool Pascal program
      """
      program p(output);
      type point = record x, y: integer end;
      procedure show(var a: array of point; c: type of a[1]);
      begin
        writeln(c.x + c.y:1)
      end;
      var v: array [1..2] of point;
      begin
        v[1].x := 20; v[1].y := 22;
        show(v, v[1])
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      42
      """

  Scenario: an element of a slice has a type where the slice itself has none
    Given the Afterschool Pascal program
      """
      program p(output);
      procedure add(var s: array of integer; x: type of s[1]);
      begin
        writeln(s[1] + x:1)
      end;
      var t: array [1..4] of integer;
      begin
        t[1] := 40;
        add(t, 2)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      42
      """

  Scenario: a constant-access is not a variable-access
    Given the Afterschool Pascal program
      """
      program p(output);
      type arr = array [1..3] of integer;
      const c = arr[1: 10; 2: 20; 3: 30];
      var x: type of c[1];
      begin
        writeln(x:1)
      end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      'type of' names a variable-access, and this is not one
      """

  Scenario: a substring possesses a type no variable may have
    Given the Afterschool Pascal program
      """
      program p(output);
      var s: string(10);
          t: type of s[1..3];
      begin
        s := 'hello'; t := s[1..3]; writeln(t)
      end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      a substring possesses the canonical string-type
      """

  Scenario: the object may not name a parameter of another formal-parameter-list
    Given the Afterschool Pascal program
      """
      program p(output);
      type point = record x, y: integer end;
      procedure outer(k: point; procedure q(x: type of k.x));
      begin
      end;
      begin
      end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      is a parameter of another formal-parameter-list
      """

  Scenario: the parameter-form may not name the parameter it is the type of
    Given the Afterschool Pascal program
      """
      program p(output);
      type point = record x, y: integer end;
      procedure q(x: type of x.y);
      begin
      end;
      begin
      end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      names the very parameter it is the type of
      """
