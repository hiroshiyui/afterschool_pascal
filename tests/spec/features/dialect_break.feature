# AP 6.7.5.10 and 6.7.5.11 -- the two loop-control procedures. Each scenario
# asks one sentence, and the continue ones are written so that entering the
# wrong place is a wrong answer or a program that does not terminate, rather
# than the same output by luck.
@afterschool:6.7.5.10
Feature: The break and continue procedures

  Scenario: a break terminates the repetitive-statement that contains it
    Given the Afterschool Pascal program
      """
      program p(output);
      var i: integer;
      begin
        i := 0;
        while true do begin
          i := i + 1;
          if i = 3 then break
        end;
        writeln(i:1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      3
      """

  @afterschool:6.7.5.10
  Scenario: it terminates the closest-containing one and no other
    Given the Afterschool Pascal program
      """
      program p(output);
      var i, j, n: integer;
      begin
        n := 0;
        for i := 1 to 3 do
          for j := 1 to 3 do begin
            if j = 2 then break;
            n := n + 1
          end;
        writeln(n:1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      3
      """

  @afterschool:6.7.5.10
  Scenario: a break needs a repetitive-statement of its own block
    Given the Afterschool Pascal program
      """
      program p(output);
      var i: integer;
      procedure q;
      begin
        break
      end;
      begin
        for i := 1 to 3 do q
      end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      must stand within a repetitive-statement
      """

  @afterschool:6.7.5.10
  Scenario: a for-statement left by a break is not completed, so its control-variable keeps its value
    Given the Afterschool Pascal program
      """
      program p(output);
      var i: integer;
      begin
        for i := 1 to 10 do
          if i = 4 then break;
        writeln(i:1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      4
      """

  @afterschool:6.7.5.10
  Scenario: a sequence left by a break is not completed, so what it armed waits for the activation
    Given the Afterschool Pascal program
      """
      program p(output);
      procedure q;
      var k: integer;
      begin
        for k := 1 to 3 do begin
          defer writeln('armed ', k:1);
          if k = 2 then break
        end;
        writeln('left the loop')
      end;
      begin
        q;
        writeln('returned')
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      armed 1
      left the loop
      armed 2
      returned
      """

  @afterschool:6.7.5.10
  Scenario: a program that declares its own break keeps it
    Given the Afterschool Pascal program
      """
      program p(output);
      var i, n: integer;
      procedure break;
      begin writeln('mine') end;
      begin
        n := 0;
        for i := 1 to 2 do begin
          break;
          n := n + 1
        end;
        writeln(n:1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      mine
      mine
      2
      """

  @afterschool:6.7.5.11
  Scenario: a continue in a while-statement re-evaluates the expression
    Given the Afterschool Pascal program
      """
      program p(output);
      var i, n: integer;
      begin
        i := 0;
        n := 0;
        while i < 10 do begin
          i := i + 1;
          if odd(i) then continue;
          n := n + i
        end;
        writeln(n:1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      30
      """

  @afterschool:6.7.5.11
  Scenario: a continue in a repeat-statement reaches the expression that follows the sequence
    Given the Afterschool Pascal program
      """
      program p(output);
      var i, n: integer;
      begin
        i := 0;
        n := 0;
        repeat
          i := i + 1;
          if i = 3 then continue;
          n := n + i
        until i = 5;
        writeln(n:1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      12
      """

  @afterschool:6.7.5.11
  Scenario: a continue in a for-statement reaches the final-value test and not the head
    Given the Afterschool Pascal program
      """
      program p(output);
      var i, n: integer;
      begin
        n := 0;
        for i := 1 to 5 do begin
          if i = 2 then continue;
          n := n + i
        end;
        writeln(n:1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      13
      """

  @afterschool:6.7.5.11
  Scenario: a continue in a for-statement over a set selects the next member
    Given the Afterschool Pascal program
      """
      program p(output);
      var c: char; s: set of char; n: integer;
      begin
        s := ['a', 'e', 'i'];
        n := 0;
        for c in s do begin
          if c = 'e' then continue;
          n := n + 1
        end;
        writeln(n:1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      2
      """

  @afterschool:6.7.5.11
  Scenario: neither takes an argument
    Given the Afterschool Pascal program
      """
      program p(output);
      var i: integer;
      begin
        for i := 1 to 3 do
          continue(i)
      end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      takes no argument
      """
