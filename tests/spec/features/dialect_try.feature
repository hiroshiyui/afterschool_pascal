# AP 6.8.9 -- the try-expression: propagation, which is the last thing error
# handling in this dialect did not have. Each scenario asks one sentence of the
# clause, and the ones about *leaving* print, because the requirement is what
# happened and in which order.
@afterschool:6.8.9.1
Feature: Try-expressions

  Scenario: try is a required function-identifier, and a program may shadow it
    Given the Afterschool Pascal program
      """
      program p(output);
      function try(n: integer): integer;
      begin
        try := n + 1
      end;
      begin
        writeln(try(41):1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      42
      """

  @afterschool:6.8.9.1
  Scenario: the parentheses are part of the spelling
    Given the Afterschool Pascal program
      """
      program p(output);
      type reason = (bad); number = integer ! reason;
      function mk(n: integer): number;
      begin mk := n end;
      function f: number;
      var k: integer;
      begin
        k := try mk(1);
        f := k
      end;
      begin
        writeln(f.ok)
      end.
      """
    When it is compiled
    Then it is rejected

  @afterschool:6.8.9.2
  Scenario: the operand shall be of a fallible-type
    Given the Afterschool Pascal program
      """
      program p(output);
      type reason = (bad); number = integer ! reason;
      var g: integer;
      function f: number;
      var k: integer;
      begin
        k := try(g);
        f := k
      end;
      begin
        g := 1;
        writeln(f.ok)
      end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      'try' needs a value of a fallible type, found integer
      """

  @afterschool:6.8.9.2
  Scenario: a try possesses the value-type of its operand
    Given the Afterschool Pascal program
      """
      program p(output);
      type reason = (bad); text8 = string(8) ! reason;
      function mk(s: string): text8;
      begin mk := s end;
      function f: text8;
      var w: string(8);
      begin
        w := try(mk('abc'));
        f := w + '!'
      end;
      begin
        writeln(f.val)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      abc!
      """

  @afterschool:6.8.9.3
  Scenario: a try may occur only within a function-block
    Given the Afterschool Pascal program
      """
      program p(output);
      type reason = (bad); number = integer ! reason;
      function mk(n: integer): number;
      begin mk := n end;
      procedure q;
      var k: integer;
      begin
        k := try(mk(1))
      end;
      begin
        q
      end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      only a function can 'try': the cause is left in the result, and this block has none
      """

  @afterschool:6.8.9.3
  Scenario: the cause shall be assignment-compatible with the result-type
    Given the Afterschool Pascal program
      """
      program p(output);
      type reason = (bad); colour = (red); number = integer ! reason;
      function mk(n: integer): number;
      begin mk := n end;
      function f: colour;
      var k: integer;
      begin
        k := try(mk(1));
        f := red
      end;
      begin
        writeln(ord(f):1)
      end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      cannot assign reason to a result of type colour
      """

  @afterschool:6.8.9.3
  Scenario: the result-type need not be fallible where it is the cause-type
    Given the Afterschool Pascal program
      """
      program p(output);
      type reason = (good, bad); number = integer ! reason;
      function mk(n: integer): number;
      begin
        if n < 0 then mk := bad else mk := n
      end;
      function why(n: integer): reason;
      var k: integer;
      begin
        k := try(mk(n));
        why := good
      end;
      begin
        writeln(ord(why(1)):1, ord(why(-1)):1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      01
      """

  @afterschool:6.8.9.4
  Scenario: an outcome is yielded and a cause leaves the function
    Given the Afterschool Pascal program
      """
      program p(output);
      type reason = (good, bad); number = integer ! reason;
      function mk(n: integer): number;
      begin
        if n < 0 then mk := bad else mk := n
      end;
      function twice(n: integer): number;
      begin
        writeln('entered');
        twice := try(mk(n)) * 2;
        writeln('reached the end')
      end;
      procedure show(r: number);
      begin
        if r.ok then writeln('value ', r.val:1)
        else writeln('cause ', ord(r.cause):1)
      end;
      begin
        show(twice(3));
        show(twice(-3))
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      entered
      reached the end
      value 6
      entered
      cause 1
      """

  @afterschool:6.8.9.4
  Scenario: the operand is evaluated once
    Given the Afterschool Pascal program
      """
      program p(output);
      type reason = (bad); number = integer ! reason;
      var calls: integer;
      function mk(n: integer): number;
      begin
        calls := calls + 1;
        mk := n
      end;
      function f: number;
      var k: integer;
      begin
        k := try(mk(7));
        f := k
      end;
      begin
        calls := 0;
        writeln(f.val:1, ' ', calls:1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      7 1
      """

  @afterschool:6.8.9.4
  Scenario: leaving by a try executes what the sequence armed and closes the block
    Given the Afterschool Pascal program
      """
      program p(output);
      type reason = (good, bad); number = integer ! reason;
      function mk(n: integer): number;
      begin
        if n < 0 then mk := bad else mk := n
      end;
      function f(n: integer): number;
      var k: integer;
      begin
        defer writeln('released');
        k := try(mk(n));
        writeln('tail');
        f := k
      end;
      begin
        if f(-1).ok then writeln('unexpected') else writeln('left')
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      released
      left
      """

  @afterschool:6.8.9.4
  Scenario: a try in a nested function terminates that one and no other
    Given the Afterschool Pascal program
      """
      program p(output);
      type reason = (good, bad); number = integer ! reason;
      function mk(n: integer): number;
      begin
        if n < 0 then mk := bad else mk := n
      end;
      function outer(n: integer): number;
        function inner(k: integer): number;
        begin
          inner := try(mk(k));
          writeln('inner tail')
        end;
      var r: number;
      begin
        r := inner(n);
        writeln('outer tail ', r.ok);
        outer := 5
      end;
      begin
        writeln(outer(-1).val:1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      outer tail FALSE
      5
      """

  @afterschool:6.8.9.5
  Scenario: a try discharges 6.7.2's assignment requirement
    Given the Afterschool Pascal program
      """
      program p(output);
      type reason = (good, bad); number = integer ! reason;
      function mk(n: integer): number;
      begin
        if n < 0 then mk := bad else mk := n
      end;
      function f(n: integer): number;
      var k: integer;
      begin
        k := try(mk(n));
        writeln('k = ', k:1)
      end;
      begin
        if f(-1).ok then writeln('unexpected') else writeln('left')
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      left
      """

  @afterschool:6.8.9.5
  Scenario: a deferred statement may not contain a try
    Given the Afterschool Pascal program
      """
      program p(output);
      type reason = (bad); number = integer ! reason;
      function mk(n: integer): number;
      begin mk := n end;
      function f: number;
      var k: integer;
      begin
        defer k := try(mk(1));
        f := 0
      end;
      begin
        writeln(f.ok)
      end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      a deferred statement may not contain a 'try'
      """
