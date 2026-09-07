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

  # 6.4.16.4. The release a *program* writes closes the channel, whichever
  # variable holds it -- which is what makes a pipeline of stages, each
  # closing the one downstream of it, terminate. Before this clause the call
  # dropped the task's reference and left the channel open, and every
  # activation downstream waited for ever (ADR-0295 finding 1, ADR-0302).
  @afterschool:6.4.16.4
  Scenario: a task closes the channel it was handed
    Given the Afterschool Pascal program
      """
      program p(output);
      type ch = channel [4] of integer;
      task t(c: ch);
      var i, k: integer;
      begin
        for i := 1 to 3 do send(c, i);
        k := release(c)
      end;
      var c: ch; v: integer;
      begin
        spawn t(c);
        while receive(c, v) do writeln('got ', v:1);
        writeln('closed')
      end.
      """
    When it is compiled and run
    Then it prints
      """
      got 1
      got 2
      got 3
      closed
      """

  # 6.4.16.4 NOTE 4. The two spellings of the program's own release are one
  # operation, so `c := nil` closes exactly as `release(c)` does.
  @afterschool:6.4.16.4
  Scenario: assigning nil to a channel closes it too
    Given the Afterschool Pascal program
      """
      program p(output);
      type ch = channel [4] of integer;
      task t(c: ch);
      begin send(c, 9); c := nil end;
      var c: ch; v: integer;
      begin
        spawn t(c);
        while receive(c, v) do writeln('got ', v:1);
        writeln('closed')
      end.
      """
    When it is compiled and run
    Then it prints
      """
      got 9
      closed
      """

  # 6.7.8.1 and 6.4.14.6's second position. A handle that is not a channel is
  # moved into the task: the spawning variable is emptied before the
  # activation commences, so at no moment do two activations hold one handle.
  @afterschool:6.7.8.1
  @afterschool:6.4.14.6
  Scenario: a handle is moved into a task
    Given the Afterschool Pascal program
      """
      program p(output);
      type f = handle external 'fclose';
           ch = channel [2] of integer;
      function ExtFopen(path, mode: string): f; external 'fopen';
      function ExtFputs(text: string; s: f): integer; external 'fputs';
      task t(s: f; c: ch);
      begin send(c, ExtFputs('x', s)) end;
      var s: f; c: ch; v: integer;
      begin
        s := ExtFopen('/dev/null', 'w');
        spawn t(take(s), c);
        writeln('source emptied: ', s = nil);
        if receive(c, v) then writeln('the task wrote: ', v >= 0)
      end.
      """
    When it is compiled and run
    Then it prints
      """
      source emptied: TRUE
      the task wrote: TRUE
      """

  # 6.7.8.1 again: the spelling is required and not inferred, so a reader of
  # the spawn-statement can see that the variable beside it is empty.
  @afterschool:6.7.8.1
  Scenario: a handle given to a task without take is refused
    Given the Afterschool Pascal program
      """
      program p(output);
      type f = handle external 'fclose';
      function ExtFopen(path, mode: string): f; external 'fopen';
      task t(s: f);
      begin end;
      var s: f;
      begin
        s := ExtFopen('/dev/null', 'w');
        spawn t(s)
      end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      must be written 'take' of a variable of that type
      """

  # 6.4.16.3 NOTE 2. A fixed-capacity string is a length beside a buffer, both
  # in the value, so it is transferable and what the reader gets shares
  # nothing with what the sender sent (ADR-0302).
  @afterschool:6.4.16.3
  Scenario: a channel carries a string
    Given the Afterschool Pascal program
      """
      program p(output);
      type ch = channel [4] of string(16);
      task t(c: ch);
      var s: string(16); k: integer;
      begin
        s := 'alpha';
        send(c, s);
        s := 'beta';
        send(c, s);
        k := release(c)
      end;
      var c: ch; s: string(16);
      begin
        spawn t(c);
        while receive(c, s) do writeln(length(s):1, ' ', s)
      end.
      """
    When it is compiled and run
    Then it prints
      """
      5 alpha
      4 beta
      """

  # AP 6.7.8.2 says "in that task-declaration or in a block within it", and
  # the first implementation compared a variable's owner with the task
  # itself. A helper declared inside a task owns its own parameter and its
  # own local, and both are the task's storage (ADR-0365).
  @afterschool:6.7.8.2
  Scenario: a routine declared inside a task names its own variables
    Given the Afterschool Pascal program
      """
      program p(output);
      type ch = channel [2] of integer;
      var c: ch; v: integer;
      task t(out: ch; n: integer);
      var acc, k: integer;
        procedure add(k: integer);
        var tmp: integer;
        begin tmp := k * n; acc := acc + tmp end;
      begin
        acc := 0; add(2); add(3);
        send(out, acc); k := release(out)
      end;
      begin
        spawn t(c, 10);
        while receive(c, v) do writeln(v:1)
      end.
      """
    When it is compiled and run
    Then it prints
      """
      50
      """

  # Every write-parameter-list without a file-variable names output, so a
  # task that may write may spell the variable it writes.
  @afterschool:6.7.8.2
  Scenario: a task may name the required variable output
    Given the Afterschool Pascal program
      """
      program p(output);
      task t(n: integer);
      begin writeln(output, 'n=', n:1) end;
      begin spawn t(4) end.
      """
    When it is compiled and run
    Then it prints
      """
      n=4
      """

  # A task declared inside a task is checked first; the outer body after it
  # is still the outer task's block and still under the rule.
  @afterschool:6.7.8.2
  Scenario: an inner task does not lift the rule from the outer task
    Given the Afterschool Pascal program
      """
      program p(output);
      var g: integer;
      task outer;
        task inner;
        begin end;
      begin
        spawn inner;
        g := g + 1
      end;
      begin g := 0; spawn outer; writeln(g) end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      a task may name only its own variables
      """

  # "It shall not have a directive": forward is one.
  @afterschool:6.7.8
  Scenario: a task-declaration takes no forward directive
    Given the Afterschool Pascal program
      """
      program p(output);
      task a; forward;
      task a;
      begin end;
      begin spawn a end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      it cannot be 'forward'
      """

  # Readings an adversarial audit confirmed (ADR-0365), each written for the
  # requirement the reader attacked rather than for the behaviour that
  # passed.
  @afterschool:6.4.12.5
  Scenario: release of an empty channel variable yields zero and is not an error
    Given the Afterschool Pascal program
      """
      program p(output);
      var c: channel [1] of integer; r: integer;
      begin
        r := release(c); writeln(r:1, ' ', c = nil);
        r := release(c); writeln(r:1, ' ', c = nil)
      end.
      """
    When it is compiled and run
    Then it prints
      """
      0 TRUE
      0 TRUE
      """

  @afterschool:6.4.16.4
  Scenario: the end of a block closes a channel moved into it, and a task formal's end does not
    Given the Afterschool Pascal program
      """
      program p(output);
      type ch = channel [2] of integer;
      var c: ch; v: integer;
      task consumer(inp: ch);
      var x: integer;
      begin
        while receive(inp, x) do writeln('got ', x:1);
        writeln('consumer saw close')
      end;
      procedure holder;
      var e: ch;
      begin e := take(c); send(e, 1) end;
      begin
        spawn consumer(c);
        holder
      end.
      """
    When it is compiled and run
    Then it prints
      """
      got 1
      consumer saw close
      """

  @afterschool:6.9.3.12
  Scenario: a spawn's actual parameters are copied before the activation commences
    Given the Afterschool Pascal program
      """
      program p(output);
      type ch = channel [2] of integer;
      var c: ch; n, v: integer;
      task t(out: ch; k: integer);
      var r: integer;
      begin send(out, k); r := release(out) end;
      begin
        n := 1;
        spawn t(c, n);
        n := 2;
        while receive(c, v) do writeln(v:1)
      end.
      """
    When it is compiled and run
    Then it prints
      """
      1
      """

  # AP 6.9.3.12.1: "before any variable of that block is released", and its
  # NOTE 2 names the block's deferred statements. A defer of the block's own
  # statement-part runs at 6.9.3.11.2 a)'s completion of that sequence, so
  # the join has to precede it (ADR-0365).
  @afterschool:6.9.3.12.1
  Scenario: the join precedes a deferred statement of the block
    Given the Afterschool Pascal program
      """
      program p(output);
      type ch = channel [4] of integer;
      var c: ch;
      task slow(o: ch);
      var i, s, k, r: integer;
      begin
        for k := 1 to 3 do begin
          s := 0;
          for i := 1 to 3000000 do s := (s + i) mod 7;
          send(o, s)
        end;
        r := release(o)
      end;
      begin
        defer writeln('deferred');
        defer c := nil;
        spawn slow(c);
        writeln('body done')
      end.
      """
    When it is compiled and run
    Then it prints
      """
      body done
      deferred
      """

  # 6.4.6 c)'s implicit conversion, in the position AP 6.9.3.13.1 added.
  @afterschool:6.9.3.13.1
  Scenario: an integer expression is sent on a channel of real
    Given the Afterschool Pascal program
      """
      program p(output);
      type ch = channel [4] of real;
      var c: ch; r: real; i: integer;
      begin
        i := 2;
        send(c, i);
        send(c, 3);
        if receive(c, r) then writeln(r:4:1);
        if receive(c, r) then writeln(r:4:1)
      end.
      """
    When it is compiled and run
    Then it prints
      """
       2.0
       3.0
      """

  # And in the position AP 6.9.3.12 added, where the ordinary rule for a
  # procedure-statement's actual applies.
  @afterschool:6.9.3.12
  Scenario: an integer actual is passed to a real formal of a task
    Given the Afterschool Pascal program
      """
      program p(output);
      type ch = channel [4] of real;
      var c: ch; r: real;
      task scale(x: real; o: ch);
      var k: integer;
      begin send(o, x * 2); k := release(o) end;
      begin
        spawn scale(3, c);
        while receive(c, r) do writeln(r:4:1)
      end.
      """
    When it is compiled and run
    Then it prints
      """
       6.0
      """
