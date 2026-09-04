# AP §6.7.3.1.1 and §6.7.2.1 -- a discriminated-schema may be written where
# ISO/IEC 10206:1991 requires a name.
#
# §6.7.3.1 gives `parameter-form = type-name | schema-name | type-inquiry`, and
# §6.7.2 gives `result-type = type-name`. A discriminated-schema is in neither,
# so `procedure q(x: string(5))` and `function f: string(5)` are outside the
# grammar of that standard -- and this processor has accepted both since the
# fixed-capacity string formal existed (ADR-0171, ADR-0324).
#
# The scenarios that fail are what says the addition is a *type* and not a
# looser rule: the tuple is part of the type, so two tuples are two types
# wherever a type is compared.

@afterschool:6.7.3.1.1
@afterschool:6.7.2.1
Feature: A discriminated schema where a name is required

  Scenario: a value parameter names its own capacity
    Given the Afterschool Pascal program
      """
      program p(output);
      procedure Show(s: string(5));
      begin writeln(s.capacity:1, ' ', length(s):1, ' [', s, ']') end;
      begin Show('ab') end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      5 2 [ab]
      """

  Scenario: a variable parameter and a result-type take one too
    Given the Afterschool Pascal program
      """
      program p(output);
      var s: string(5);
      procedure Fill(var x: string(5));
      begin x := 'ab' end;
      function Grown: string(5);
      begin Grown := 'cd' end;
      begin Fill(s); writeln(s, Grown) end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      abcd
      """

  Scenario: any schema, not only string
    Given the Afterschool Pascal program
      """
      program p(output);
      type Box(n: integer) = record a: array [1..n] of integer end;
      var b: Box(3);
      procedure Put(var x: Box(3); v: integer);
      begin x.a[1] := v end;
      function Got(x: Box(3)): integer;
      begin Got := x.a[1] end;
      begin Put(b, 7); writeln(Got(b):1) end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      7
      """

  Scenario: the tuple is part of the type, so a variable parameter refuses another
    Given the Afterschool Pascal program
      """
      program p(output);
      var s: string(6);
      procedure Fill(var x: string(5));
      begin x := 'ab' end;
      begin Fill(s); writeln(s) end.
      """
    When it is compiled
    Then it is rejected

  Scenario: the discriminants are constant, the schema-name form being what varies
    Given the Afterschool Pascal program
      """
      program p(output);
      var k: integer;
      procedure Show(s: string(k));
      begin writeln(s) end;
      begin k := 5; Show('ab') end.
      """
    When it is compiled
    Then it is rejected

  Scenario: a type-inquiry is still not a result-type
    Given the Afterschool Pascal program
      """
      program p(output);
      var n: integer;
      function Twice: type of n;
      begin Twice := 2 end;
      begin n := 1; writeln(Twice:1) end.
      """
    When it is compiled
    Then it is rejected
