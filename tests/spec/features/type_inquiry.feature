# ISO/IEC 10206:1991 §6.4.9 -- the type-inquiry, `type of x`, and the one
# question about it this suite had no scenario for: *what may follow `of`*.
#
#   type-inquiry        = 'type' 'of' type-inquiry-object .
#   type-inquiry-object = variable-name | parameter-identifier .
#
# and §6.5.1's first alternative is a name and not an access:
#
#   variable-name = [ imported-interface-identifier '.' ] variable-identifier .
#
# So an indexed-variable, an identified-variable and a field-designator are
# each outside the clause. That is easy to state and was got wrong here in
# prose -- `doc/roadmap.md` carried an entry calling these refusals a
# conformance gap, when they are the conformance (ADR-0214). No oracle could
# contradict it: the compiler was right, both front ends agreed, the citation
# named a real clause, and all eleven corpus uses of `type of` name a simple
# variable, so none of them decides between the two readings.
#
# These scenarios are what decides between them, attached to the clause.

@extended:6.4.9
Feature: A type-inquiry's object is a variable-name or a parameter-identifier

  Scenario: a name is admitted, and denotes the type that name already possesses
    Given the Extended Pascal program
      """
      program p(output);
      type point = record x, y: integer end;
      var a: point;
          b: type of a;
      begin
        a.x := 3; a.y := 4;
        b := a;
        writeln(b.x + b.y:1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      7
      """

  Scenario: a parameter of the closest-containing formal-parameter-list is admitted
    Given the Extended Pascal program
      """
      program p(output);
      type point = record x, y: integer end;
      procedure show(var a: point; b: type of a);
      begin
        writeln(a.x + b.y:1)
      end;
      var v, w: point;
      begin
        v.x := 10; v.y := 20; w.x := 30; w.y := 40;
        show(v, w)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      50
      """

  Scenario: an indexed-variable is not a variable-name
    Given the Extended Pascal program
      """
      program p(output);
      var a: array [1..3] of integer;
          b: type of a[1];
      begin
        a[1] := 1; b := a[1]; writeln(b:1)
      end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      'type of' names a whole variable, not a component of one
      """

  Scenario: an identified-variable is not a variable-name
    Given the Extended Pascal program
      """
      program p(output);
      var q: ^integer;
          b: type of q^;
      begin
        new(q); q^ := 1; b := q^; writeln(b:1)
      end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      'type of' names a whole variable, not a component of one
      """

  Scenario: a field-designator is not a variable-name, though it is spelled like a qualified one
    Given the Extended Pascal program
      """
      program p(output);
      type point = record x, y: integer end;
      var a: point;
          b: type of a.x;
      begin
        a.x := 1; b := a.x; writeln(b:1)
      end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      'type of' names a whole variable, not a component of one
      """
