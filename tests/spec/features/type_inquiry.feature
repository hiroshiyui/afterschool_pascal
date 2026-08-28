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
# each outside *that* clause. That is easy to state and was got wrong here in
# prose -- `doc/roadmap.md` carried an entry calling the refusals a conformance
# gap, when they were the conformance (ADR-0214). No oracle could contradict
# it: the compiler was right, both front ends agreed, the citation named a real
# clause, and all eleven corpus uses of `type of` name a simple variable, so
# none of them decides between the two readings.
#
# **This language admits the whole variable-access** (AP 6.4.9, ADR-0215), and
# dialect_typeinquiry.feature is where that is stated. What is left here is the
# clause's own reading of what a *variable-name* is, which every rule written
# against 6.4.9 still rests on -- the three refusals that stood beside it went
# with ADR-0232, there being no mode left to refuse anything.

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

