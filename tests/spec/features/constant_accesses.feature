# ISO/IEC 10206:1991 §6.8.8 -- a constant-access, which the standard opens by
# saying is not necessarily a constant: given `c = t[1:1; 2:2; 3:3]` and a
# variable `i`, "the constant-access, c[i], denotes a different value for each
# iteration of the loop."
#
# §6.8.8.1's own requirement is the one this suite had no scenario for, because
# the clause was triaged `structural` -- a heading that "states no requirement
# of its own" -- and it states this one:
#
#   "The value and type of a constant-access shall be the value and type,
#    respectively, either of the constant-name of the constant-access or of the
#    indexed-constant, field-designated-constant, or substring-constant of the
#    constant-access-component."
#
# §6.3's Examples exercise the scalar half -- `UnitDistance = Unit.r` and
# `column1 = BlankCard[1]` -- and that half was right. A name bound to a
# *structured* component read as all-zero, in silence.

@extended:6.8.8.1 @extended:6.8.8.2 @extended:6.8.8.3
Feature: A constant-access has the value and type of the component it selects

  Scenario: a name bound to an array component of a constant has that component's value
    Given the Extended Pascal program
      """
      program p(output);
      type inner = array [1..3] of integer;
           outer = array [1..2] of inner;
      const grid = outer[1: inner[1:1; 2:2; 3:3]; 2: inner[1:4; 2:5; 3:6]];
            row  = grid[2];
      var i: integer;
      begin
        for i := 1 to 3 do write(row[i]:1);
        writeln
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      456
      """

  Scenario: a name bound to a record component of a constant has that component's value
    Given the Extended Pascal program
      """
      program p(output);
      type rs     = record nm: string(8); n: integer end;
           holder = record a, b: rs end;
      const h = holder[a: rs[nm: 'one'; n: 1]; b: rs[nm: 'two'; n: 2]];
            second = h.b;
      begin
        writeln(second.nm, ' ', second.n:1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      two 2
      """

  Scenario: the type of such a name is the component's type and not the container's
    Given the Extended Pascal program
      """
      program p(output);
      type inner = array [1..3] of integer;
           outer = array [1..2] of inner;
           other = array [1..3] of integer;
      const grid = outer[1: inner[1:1; 2:2; 3:3]; 2: inner[1:4; 2:5; 3:6]];
            row  = grid[2];
      var o: other;
      begin
        o := row;
        writeln(o[1]:1)
      end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      cannot assign inner to a variable of type other
      """

  Scenario: an indexed-constant whose index is a variable is not a constant and denotes a component per iteration
    Given the Extended Pascal program
      """
      program p(output);
      type t = array [1..3] of integer;
      const c = t[1:1; 2:2; 3:3];
      var i: integer;
      begin
        for i := 1 to 3 do writeln(c[i]:1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      1
      2
      3
      """
