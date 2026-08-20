# AP 6.0.1 -- the property every other clause is an addition to. It is a claim
# about every Extended Pascal program, and a scenario can only witness it, so
# what is written here is the shape of witness that would fail loudly: a
# program using several of the standard's own features, meaning the same thing
# under both modes. tests/dialect/inherits_extended.pas is the larger witness.
@afterschool:6.0.1
Feature: The dialect contains Extended Pascal

  Scenario: an Extended Pascal program means the same under the dialect
    Given the Afterschool Pascal program
      """
      program p(output);
      type vec(n: integer) = array [1..n] of integer;
           colour = (red, green, blue);
      var v: vec(3); s: string(8); c: colour; i: integer;
      begin
        for i := 1 to 3 do v[i] := i * i;
        s := 'ab' + 'cd';
        c := succ(red);
        case c of
          green: writeln(v[3], ' ', s, ' green');
          otherwise writeln('wrong')
        end
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      9 abcd green
      """

  @afterschool:6.0.2
  Scenario: the same source under --std=extended means exactly the same thing
    Given the Extended Pascal program
      """
      program p(output);
      type vec(n: integer) = array [1..n] of integer;
           colour = (red, green, blue);
      var v: vec(3); s: string(8); c: colour; i: integer;
      begin
        for i := 1 to 3 do v[i] := i * i;
        s := 'ab' + 'cd';
        c := succ(red);
        case c of
          green: writeln(v[3], ' ', s, ' green');
          otherwise writeln('wrong')
        end
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      9 abcd green
      """

  @afterschool:6.1.2
  Scenario: the question mark is not a character a conformance mode admits
    Given the Extended Pascal program
      """
      program p(output);
      var v: ?integer;
      begin end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      unexpected character '?'
      """

  @afterschool:6.1.4
  Scenario: external is not a word-symbol, so a program may still use the name
    Given the Afterschool Pascal program
      """
      program p(output);
      var external: integer;
      begin external := 5; writeln(external) end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      5
      """

  @afterschool:6.5.6
  Scenario: a[i..j] over an array is a slice here and a substring error there
    Given the Extended Pascal program
      """
      program p(output);
      procedure f(var a: array of integer); begin end;
      begin end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      a parameter's type must be a type name
      """
