# AP 6.9.3.11 -- the defer-statement: a statement armed where it is written
# and executed where the sequence it stands in is completed, or where the
# activation terminates. Each scenario asks one half of one clause; the
# ordering ones print, because the requirement *is* the order.
@afterschool:6.9.3.11.1
Feature: Defer-statements

  Scenario: an armed statement runs when its sequence is completed, after the statements that follow it
    Given the Afterschool Pascal program
      """
      program p(output);
      begin
        defer writeln('armed');
        writeln('body')
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      body
      armed
      """

  @afterschool:6.9.3.11.1
  Scenario: a defer-statement that is not executed arms nothing
    Given the Afterschool Pascal program
      """
      program p(output);
      var c: boolean;
      begin
        c := false;
        if c then defer writeln('armed');
        writeln('body')
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      body
      """

  @afterschool:6.9.3.11.2
  Scenario: several armed statements of one sequence run in the reverse of the order they are written
    Given the Afterschool Pascal program
      """
      program p(output);
      begin
        defer writeln('first');
        defer writeln('second');
        defer writeln('third')
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      third
      second
      first
      """

  @afterschool:6.9.3.11.2
  Scenario: a compound statement is a statement-sequence, so a loop body completes once per iteration
    Given the Afterschool Pascal program
      """
      program p(output);
      var i: integer;
      begin
        for i := 1 to 3 do begin
          defer writeln('end ', i:1);
          writeln('body ', i:1)
        end
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      body 1
      end 1
      body 2
      end 2
      body 3
      end 3
      """

  @afterschool:6.9.3.11.2
  Scenario: the statement is executed where it runs, not evaluated where it is armed
    Given the Afterschool Pascal program
      """
      program p(output);
      var n: integer;
      begin
        n := 1;
        defer writeln(n:1);
        n := 99
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      99
      """

  @afterschool:6.9.3.11.2
  Scenario: a goto leaving the block runs what each abandoned activation armed, innermost first
    Given the Afterschool Pascal program
      """
      program p(output);
      label 9;
      procedure inner;
      begin
        defer writeln('inner');
        goto 9
      end;
      procedure outer;
      begin
        defer writeln('outer');
        inner
      end;
      begin
        outer;
      9:
        writeln('arrived')
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      inner
      outer
      arrived
      """

  @afterschool:6.9.3.11.2
  Scenario: an armed statement runs before the block's files are closed
    Given the Afterschool Pascal program
      """
      program p(output);
      procedure w;
      var f: bindable text; b: BindingType;
      begin
        b := binding(f); b.name := 'spec_defer.tmp'; bind(f, b);
        rewrite(f);
        defer writeln(f, 'deferred');
        writeln(f, 'body')
      end;
      var t: bindable text; b: BindingType; s: string(40);
      begin
        w;
        b := binding(t); b.name := 'spec_defer.tmp'; bind(t, b);
        reset(t);
        while not eof(t) do begin readln(t, s); writeln('[', s, ']') end
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      [body]
      [deferred]
      """

  @afterschool:6.9.3.11.3
  Scenario: a deferred statement may not contain a goto-statement
    Given the Afterschool Pascal program
      """
      program p(output);
      label 1;
      begin
        defer goto 1;
      1:
        writeln('x')
      end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      a deferred statement may not contain a goto-statement
      """

  @afterschool:6.9.3.11.3
  Scenario: a deferred statement may not defer another
    Given the Afterschool Pascal program
      """
      program p(output);
      var i: integer;
      begin
        defer defer i := 1
      end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      a deferred statement may not defer another statement
      """

  @afterschool:6.9.3.11
  Scenario: a program of the contained standard keeps its own defer
    Given the Afterschool Pascal program
      """
      program p(output);
      procedure defer;
      begin writeln('called') end;
      begin
        defer;
        if true then defer else defer
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      called
      called
      """
