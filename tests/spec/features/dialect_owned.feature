# AP 6.4.14 -- the owned-pointer-type: `owned ^T` identifies a variable created
# by `new` and disposes it when the pointer's own variable dies. It is what
# gives a created variable an owner: a variable identified by an ordinary
# pointer exists in no activation, so nothing releases what it holds unless the
# program says `dispose`.
#
# The release is observed rather than assumed. A stream inside the owned
# variable is buffered until fclose, so reading the file back says whether the
# closer ran, and opening one per iteration says whether the descriptor came
# back.
@afterschool:6.4.14.1
Feature: Owned-pointer-types

  Scenario: the denoter reserves nothing, so a program may still name a type owned
    Given the Afterschool Pascal program
      """
      program p(output);
      type owned = integer;
           node = record key: integer end;
           np = owned ^node;
      var x: owned; q: np;
      begin
        x := 7;
        new(q);
        q^.key := 3;
        writeln(x, ' ', q^.key)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      7 3
      """

  @afterschool:6.4.14.1
  Scenario: the domain may be a name defined later, so a type may own its own kind
    Given the Afterschool Pascal program
      """
      program p(output);
      type np = owned ^node;
           node = record key: integer; next: np end;
      var head: np;
      begin
        new(head);
        head^.key := 1;
        new(head^.next);
        head^.next^.key := 2;
        writeln(head^.key, ' ', head^.next^.key, ' ', head^.next^.next = nil)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      1 2 TRUE
      """

  @afterschool:6.4.14.2
  Scenario: the domain may not be a schema
    Given the Afterschool Pascal program
      """
      program p(output);
      type s(n: integer) = array [1..n] of integer;
           sp = owned ^s;
      var q: sp;
      begin new(q, 4) end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      the domain of an owned pointer cannot be the schema
      """

  @afterschool:6.4.14.2
  Scenario: an owned pointer may not be a field of a variant part
    Given the Afterschool Pascal program
      """
      program p(output);
      type node = record key: integer end;
           np = owned ^node;
           sel = 1..2;
           r = record case k: sel of 1: (a: np); 2: (b: integer) end;
      var v: r;
      begin v.k := 2 end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      an owned pointer cannot be a field of a variant part
      """

  @afterschool:6.4.14.3
  Scenario: an owned pointer has no copy, so it is no value parameter and no result
    Given the Afterschool Pascal program
      """
      program p(output);
      type node = record key: integer end;
           np = owned ^node;
      var a, b: np;
      function answer: np;
      begin end;
      procedure byvalue(n: np);
      begin end;
      begin a := b end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      a result may not be, or contain, an owned pointer
      """

  @afterschool:6.4.14.3
  Scenario: the block that owns the pointer releases what the variable holds
    Given the Afterschool Pascal program
      """
      program p(output);
      type f = handle external 'fclose';
           box = record s: f end;
           bp = owned ^box;
      function fo(path, mode: string): f; external 'fopen';
      function fp(t: string; h: f): integer; external 'fputs';
      var t: bindable text; b: BindingType; line: string(40); k: integer;
      procedure fill;
      var q: bp;
      begin
        new(q);
        q^.s := fo('spec_owned.tmp', 'w');
        k := fp('buffered', q^.s)
      end;
      begin
        fill;
        b := binding(t);
        b.name := 'spec_owned.tmp';
        bind(t, b);
        reset(t);
        readln(t, line);
        writeln(line);
        unbind(t)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      buffered
      """

  @afterschool:6.4.14.3
  Scenario: new over a non-empty owned pointer releases what it held
    Given the Afterschool Pascal program
      """
      program p(output);
      type f = handle external 'fclose';
           box = record s: f end;
           bp = owned ^box;
      function fo(path, mode: string): f; external 'fopen';
      function fp(t: string; h: f): integer; external 'fputs';
      var q: bp; t: bindable text; b: BindingType; line: string(40); k: integer;
      begin
        new(q);
        q^.s := fo('spec_owned2.tmp', 'w');
        k := fp('flushed by the second new', q^.s);
        { the second new is a release point: without it the first box is
          abandoned with its stream unclosed and the text still buffered }
        new(q);
        b := binding(t);
        b.name := 'spec_owned2.tmp';
        bind(t, b);
        reset(t);
        readln(t, line);
        writeln(line);
        unbind(t)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      flushed by the second new
      """

  @afterschool:6.4.14.3
  Scenario: the release reaches what the owned variable itself owns
    Given the Afterschool Pascal program
      """
      program p(output);
      type np = owned ^node;
           node = record key: integer; next: np end;
      var head: np; i: integer;
      procedure push(var n: np; k: integer);
      begin
        if n = nil then begin new(n); n^.key := k end
        else push(n^.next, k)
      end;
      function len(var n: np): integer;
      begin
        if n = nil then len := 0 else len := 1 + len(n^.next)
      end;
      begin
        for i := 1 to 5 do push(head, i);
        writeln(len(head));
        dispose(head);
        writeln(head = nil)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      5
      TRUE
      """

  @afterschool:6.4.14.4
  Scenario: an owned pointer compares with nil and with nothing else
    Given the Afterschool Pascal program
      """
      program p(output);
      type node = record key: integer end;
           np = owned ^node;
      var a, b: np;
      begin if a = b then writeln('same') end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      an owned pointer can only be compared with 'nil'
      """

  @afterschool:6.4.14.4
  Scenario: an owned pointer has no order
    Given the Afterschool Pascal program
      """
      program p(output);
      type node = record key: integer end;
           np = owned ^node;
      var a: np;
      begin if a < nil then writeln('less') end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      an owned pointer can only be compared with = and <>
      """

  @afterschool:6.4.14.5
  Scenario: two separately written denoters denote two types
    Given the Afterschool Pascal program
      """
      program p(output);
      type node = record key: integer end;
      var a: owned ^node;
      procedure lend(var n: owned ^node);
      begin end;
      begin lend(a) end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      6.4.1 makes each type-denoter that is not a type name denote a type of its own
      """

  @afterschool:6.4.14.5
  Scenario: one named type is what a program lends
    Given the Afterschool Pascal program
      """
      program p(output);
      type node = record key: integer end;
           np = owned ^node;
      var a: np;
      procedure lend(var n: np);
      begin
        if n = nil then writeln('empty') else writeln(n^.key)
      end;
      begin
        lend(a);
        new(a);
        a^.key := 9;
        lend(a)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      empty
      9
      """

  @afterschool:6.4.14.6
  Scenario: take is the move, so push-front and pop-front are writable
    Given the Afterschool Pascal program
      """
      program p(output);
      type np = owned ^node;
           node = record key: integer; next: np end;
      var l: np; i: integer;
      procedure pushfront(var n: np; k: integer);
      var fresh: np;
      begin
        new(fresh);
        fresh^.key := k;
        fresh^.next := take(n);
        n := take(fresh)
      end;
      procedure show(var n: np);
      begin
        if n <> nil then begin write(' ', n^.key:1); show(n^.next) end
      end;
      begin
        for i := 1 to 4 do pushfront(l, i);
        write('a:'); show(l); writeln;
        { pop-front, entire }
        l := take(l^.next);
        write('b:'); show(l); writeln
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      a: 4 3 2 1
      b: 3 2 1
      """

  @afterschool:6.4.14.6
  Scenario: the source is emptied and the target's old value released
    Given the Afterschool Pascal program
      """
      program p(output);
      type f = handle external 'fclose';
           node = record s: f end;
           np = owned ^node;
      function fo(path, mode: string): f; external 'fopen';
      function fp(t: string; h: f): integer; external 'fputs';
      var a, b: np; t: bindable text; bd: BindingType; line: string(40);
          k: integer;
      begin
        new(a);
        a^.s := fo('spec_take.tmp', 'w');
        k := fp('released when a was overwritten', a^.s);
        new(b);
        { a holds the stream and is the *target*: the move must release what
          a held before storing b's, or the stream is never closed and the
          text below is still in its buffer }
        a := take(b);
        writeln('b empty: ', b = nil);
        bd := binding(t);
        bd.name := 'spec_take.tmp';
        bind(t, bd);
        reset(t);
        readln(t, line);
        writeln(line);
        unbind(t)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      b empty: TRUE
      released when a was overwritten
      """

  @afterschool:6.4.14.6
  Scenario: a target reached through the source stops instead of making a cycle
    Given the Afterschool Pascal program
      """
      program p(output);
      type np = owned ^node;
           node = record key: integer; next: np end;
      var p: np;
      begin
        new(p);
        p^.next := take(p);
        writeln('unreachable')
      end.
      """
    When it is compiled and run
    Then it stops at run time
     And the run-time error includes
      """
      dereference of nil
      """

  @afterschool:6.4.14.6
  Scenario: take stands nowhere but that one position
    Given the Afterschool Pascal program
      """
      program p(output);
      type np = owned ^node;
           node = record key: integer end;
      var a: np;
      begin
        new(a);
        if take(a) = nil then writeln('empty')
      end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      'take' may stand only as the whole right side of an assignment
      """

  @afterschool:6.4.14.6
  Scenario: take of an empty variable is empty and is not an error
    Given the Afterschool Pascal program
      """
      program p(output);
      type np = owned ^node;
           node = record key: integer end;
      var a, b: np;
      begin
        b := take(a);
        writeln(a = nil, ' ', b = nil)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      TRUE TRUE
      """
