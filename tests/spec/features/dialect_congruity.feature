# AP §6.7.3.6 -- a schematic string value formal may stand where the declared
# formal names a type produced from that schema.
#
# ISO/IEC 10206:1991 §6.7.3.6 a) 4) offers three ways two value-parameter-
# sections match and every one of them names both headings, so the mixed pair
# is in none. The cost of that was measured at a caller: `PasContainer`'s map
# is generic over its key type, its ready-made hash was not, and every client
# with a key of a different capacity wrote the pair again.
#
# The three scenarios that fail are the point. The rule is narrow on purpose
# and each edge is refused for a reason the acceptance rests on -- the
# direction, the schema and the passing mode.

@afterschool:6.7.3.6.1
@afterschool:6.7.3.6.2
@afterschool:6.7.3.6.3
Feature: Parameter list congruity for a schematic string formal

  Scenario: one schematic function serves two capacities
    Given the Afterschool Pascal program
      """
      program p(output);
      type Short = string(8);
           Long  = string(200);
      var s: Short; t: Long;
      function Len(x: string): integer;
      begin Len := length(x) end;
      function ViaShort(k: Short; function f(y: Short): integer): integer;
      begin ViaShort := f(k) end;
      function ViaLong(k: Long; function f(y: Long): integer): integer;
      begin ViaLong := f(k) end;
      begin
        s := 'abc';
        t := 'abcdefgh';
        writeln(ViaShort(s, Len):1, ' ', ViaLong(t, Len):1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      3 8
      """

  Scenario: the permission runs one way only
    Given the Afterschool Pascal program
      """
      program p(output);
      type Short = string(8);
      var s: Short;
      function Fixed(x: Short): integer;
      begin Fixed := length(x) end;
      function Via(k: Short; function f(y: string): integer): integer;
      begin Via := f(k) end;
      begin s := 'abc'; writeln(Via(s, Fixed):1) end.
      """
    When it is compiled
    Then it is rejected

  Scenario: no other schema is admitted
    Given the Afterschool Pascal program
      """
      program p(output);
      type Box(n: integer) = record a: array [1..n] of integer end;
           B5 = Box(5);
      var b: B5;
      function Gen(x: Box): integer;
      begin Gen := x.a[1] end;
      function Via(k: B5; function f(y: B5): integer): integer;
      begin Via := f(k) end;
      begin b.a[1] := 3; writeln(Via(b, Gen):1) end.
      """
    When it is compiled
    Then it is rejected

  Scenario: a variable parameter is not admitted
    Given the Afterschool Pascal program
      """
      program p(output);
      type Short = string(8);
      var s: Short;
      procedure Gen(var x: string);
      begin x := 'q' end;
      procedure Via(var k: Short; procedure f(var y: Short));
      begin f(k) end;
      begin s := 'abc'; Via(s, Gen); writeln(s) end.
      """
    When it is compiled
    Then it is rejected

  Scenario: congruity is contravariant one level in
    Given the Afterschool Pascal program
      """
      program p(output);
      type Short = string(8);
      function Len(x: string): integer;
      begin Len := length(x) end;
      function TakesFixed(function r(y: Short): integer): integer;
      begin TakesFixed := r('abcd') end;
      function Drive(function o(function i(x: string): integer): integer):
                     integer;
      begin Drive := o(Len) end;
      begin writeln(Drive(TakesFixed):1) end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      4
      """
