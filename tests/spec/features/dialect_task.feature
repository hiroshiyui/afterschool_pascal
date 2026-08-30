# AP 6.4.16, 6.7.8 and 6.9.3.12-13: tasks and channels (ADR-0201, ADR-0268).
#
# ADR-0201 decided the shape of this construct four increments before it was
# built and declined to build it, and the shape is what these scenarios pin:
# share-nothing, a task owning or copying what it is given, a channel as the
# one thing two activations may name, and a join that bounds the lending.
Feature: tasks and channels

  # 6.9.3.12. The join is what makes the whole thing safe: the block does not
  # end until every task it started has.
  @afterschool:6.9.3.12
  @afterschool:6.9.3.12.1
  Scenario: a spawned task runs and the block waits for it
    Given the Afterschool Pascal program
      """
      program p(output);
      type ch = channel [4] of integer;
      task t(c: ch);
      begin send(c, 7) end;
      var c: ch; v: integer;
      begin
        spawn t(c);
        if receive(c, v) then writeln('got ', v:1)
      end.
      """
    When it is compiled and run
    Then it prints
      """
      got 7
      """

  # 6.9.3.13.2. Closing a channel is how a pool of workers is told there is no
  # more work: each drains what is left and then receive answers false.
  @afterschool:6.9.3.13.1
  @afterschool:6.9.3.13.2
  Scenario: a released channel drains and then reports the close
    Given the Afterschool Pascal program
      """
      program p(output);
      type ch = channel [8] of integer;
      task t(jobs, out: ch);
      var n, seen: integer;
      begin
        seen := 0;
        while receive(jobs, n) do seen := seen + n;
        send(out, seen)
      end;
      var jobs, out: ch; k, v: integer;
      begin
        spawn t(jobs, out);
        for k := 1 to 4 do send(jobs, k);
        k := release(jobs);
        if receive(out, v) then writeln('drained ', v:1)
      end.
      """
    When it is compiled and run
    Then it prints
      """
      drained 10
      """

  # 6.7.8.1. A value crosses by copy, so the spawning activation may change
  # its own the moment the statement is over.
  @afterschool:6.7.8.1
  Scenario: a value crosses into a task by copy
    Given the Afterschool Pascal program
      """
      program p(output);
      type ch = channel [4] of integer;
      task t(c: ch; n: integer);
      begin send(c, n) end;
      var c: ch; n, v: integer;
      begin
        n := 5;
        spawn t(c, n);
        n := 99;
        if receive(c, v) then writeln('copied ', v:1)
      end.
      """
    When it is compiled and run
    Then it prints
      """
      copied 5
      """

  # 6.7.8.1 again, and this is the refusal the clause exists for: a variable
  # parameter would be a second name for a variable of another activation,
  # running at the same time.
  @afterschool:6.7.8.1
  Scenario: a task may not take a variable parameter
    Given the Afterschool Pascal program
      """
      program p(output);
      task t(var n: integer);
      begin n := 1 end;
      begin writeln('unreached') end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      cannot be a variable parameter
      """

  # 6.4.16.3. What crosses is a value, and a value holding a reference is a
  # name for something the other side does not own.
  @afterschool:6.4.16.3
  Scenario: a channel may not carry a pointer
    Given the Afterschool Pascal program
      """
      program p(output);
      type node = record v: integer end;
           bad = channel [4] of ^node;
      var c: bad;
      begin writeln('unreached') end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      a channel cannot carry
      """

  # 6.7.8. A task is started by a spawn-statement and by nothing else, and a
  # procedure is not started by one. Two refusals, one rule.
  @afterschool:6.7.8
  Scenario: a task is not called
    Given the Afterschool Pascal program
      """
      program p(output);
      type ch = channel [4] of integer;
      task t(c: ch);
      begin send(c, 1) end;
      var c: ch;
      begin t(c) end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      is started by 'spawn' and not by being called
      """

  @afterschool:6.9.3.12
  Scenario: a procedure is not spawned
    Given the Afterschool Pascal program
      """
      program p(output);
      procedure q(n: integer);
      begin end;
      begin spawn q(1) end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      is not a task, and only a task may be spawned
      """

  # 6.4.16.1. The word is not reserved: a program that declares a type called
  # `channel` still means what it meant.
  @afterschool:6.4.16.1
  Scenario: channel is not a word-symbol
    Given the Afterschool Pascal program
      """
      program p(output);
      type channel = integer;
      var spawn, task, send, receive: channel;
      begin
        spawn := 1; task := 2; send := 3; receive := 4;
        writeln(spawn + task + send + receive:1)
      end.
      """
    When it is compiled and run
    Then it prints
      """
      10
      """

  # 6.4.16.2. A channel is a handle, so it is released when its block ends and
  # `release` releases it earlier -- and, unlike every other handle, it does
  # not start empty.
  @afterschool:6.4.16.2
  Scenario: a channel is not empty when its block begins
    Given the Afterschool Pascal program
      """
      program p(output);
      type ch = channel [2] of integer;
      var c: ch;
      begin
        if c <> nil then writeln('live')
      end.
      """
    When it is compiled and run
    Then it prints
      """
      live
      """

  # 6.7.8.2. The formals rule is not the whole rule: Pascal's scope rules let a
  # block name a variable of an enclosing one, and a program's variables
  # enclose every block in it. Two tasks incrementing one global is a race a
  # rule about parameters cannot see.
  @afterschool:6.7.8.2
  Scenario: a task may not name a variable of an enclosing block
    Given the Afterschool Pascal program
      """
      program p(output);
      type ch = channel [4] of integer;
      var c: ch; shared: integer;
      task t(c: ch);
      begin shared := shared + 1; send(c, shared) end;
      begin writeln('unreached') end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      a task may name only its own variables
      """

  # ...and what it may still name is everything that is not storage.
  @afterschool:6.7.8.2
  Scenario: a task may name constants, types and routines
    Given the Afterschool Pascal program
      """
      program p(output);
      const bump = 7;
      type ch = channel [4] of integer;
      function twice(n: integer): integer;
      begin twice := n * 2 end;
      task t(c: ch);
      var k: integer;
      begin k := twice(bump); send(c, k) end;
      var c: ch; v: integer;
      begin
        spawn t(c);
        if receive(c, v) then writeln('got ', v:1)
      end.
      """
    When it is compiled and run
    Then it prints
      """
      got 14
      """
