# AP 6.7.5.9 -- the exit procedure: an early termination of one activation.
# Each scenario asks one sentence of the clause. The ones about what runs on
# the way out print, because the requirement *is* what happened and in which
# order.
@afterschool:6.7.5.9
Feature: The exit procedure

  Scenario: an exit terminates the activation of the block it stands in
    Given the Afterschool Pascal program
      """
      program p(output);
      procedure q;
      begin
        writeln('before');
        exit;
        writeln('after')
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
      before
      returned
      """

  @afterschool:6.7.5.9
  Scenario: the block is the one the statement is in, not an enclosing one
    Given the Afterschool Pascal program
      """
      program p(output);
      procedure outer;
        procedure inner;
        begin
          exit;
          writeln('inner tail')
        end;
      begin
        inner;
        writeln('outer tail')
      end;
      begin
        outer;
        writeln('program tail')
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      outer tail
      program tail
      """

  @afterschool:6.7.5.9
  Scenario: exit with a value assigns the result and discharges 6.7.2
    Given the Afterschool Pascal program
      """
      program p(output);
      function f(n: integer): integer;
      begin
        if n > 0 then exit(n * 2);
        exit(0)
      end;
      begin
        writeln(f(21):1, ' ', f(-1):1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      42 0
      """

  @afterschool:6.7.5.9
  Scenario: exit with a value writes a result variable named by a specification
    Given the Afterschool Pascal program
      """
      program p(output);
      function f(n: integer) = r: integer;
      begin
        exit(n + 1)
      end;
      begin
        writeln(f(41):1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      42
      """

  @afterschool:6.7.5.9
  Scenario: the value chooses the arm of a fallible result
    Given the Afterschool Pascal program
      """
      program p(output);
      type e = (bad);
           n = integer ! e;
      function f(ok: boolean): n;
      begin
        if ok then exit(7);
        exit(bad)
      end;
      var r: n;
      begin
        r := f(true);
        if r.ok then writeln('value ', r.val:1);
        r := f(false);
        if not r.ok then writeln('cause ', ord(r.cause):1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      value 7
      cause 0
      """

  @afterschool:6.7.5.9
  Scenario: only a function may exit with a value
    Given the Afterschool Pascal program
      """
      program p(output);
      procedure q;
      begin
        exit(1)
      end;
      begin
        q
      end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      only a function can 'exit' with a value
      """

  @afterschool:6.7.5.9
  Scenario: an armed statement runs on the way out
    Given the Afterschool Pascal program
      """
      program p(output);
      procedure q;
      begin
        defer writeln('armed');
        writeln('body');
        exit;
        writeln('after')
      end;
      begin
        q
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      body
      armed
      """

  @afterschool:6.7.5.9
  Scenario: a deferred statement may not contain an exit-statement
    Given the Afterschool Pascal program
      """
      program p(output);
      begin
        defer exit
      end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      a deferred statement may not contain an exit-statement
      """

  @afterschool:6.7.5.9
  Scenario: an exit from the main-program-block ends the program the ordinary way
    Given the Afterschool Pascal program
      """
      program p(output);
      var i: integer;
      begin
        for i := 1 to 3 do begin
          writeln(i:1);
          if i = 2 then exit
        end;
        writeln('not reached')
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      1
      2
      """

  @afterschool:6.7.5.9
  Scenario: a program of the contained standard keeps its own exit
    Given the Afterschool Pascal program
      """
      program p(output);
      var exit: integer;
      begin
        exit := 3;
        writeln(exit:1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      3
      """
