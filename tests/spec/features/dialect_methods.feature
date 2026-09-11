# AP 6.7.10 and 6.7.10.4: an inherent implementation and the
# method-designator (ADR-0410, ADR-0315's increment A).
#
# What these pin is that `x.M(a)` is not a second mechanism. 6.7.10.2 has
# selected a routine from its first actual's type since traits landed, and a
# method-designator moves the receiver from in front of the dot to the head of
# the argument list -- so the two spellings denote one call, and the first
# scenario asserts exactly that by writing both.
Feature: methods

  # 6.7.10.4 NOTE 17. Neither spelling is the definition of the other.
  @afterschool:6.7.10
  @afterschool:6.7.10.4
  Scenario: a method-designator and the call it denotes are one call
    Given the Afterschool Pascal program
      """
      program p(output);
      type point = record x, y: integer end;
      impl point;
        function Len(protected var self: point): integer;
        begin Len := self.x + self.y end;
        procedure Shift(var self: point; by: integer);
        begin self.x := self.x + by end;
      end;
      var q: point;
      begin
        q.x := 1; q.y := 2;
        q.Shift(10);
        Shift(q, 10);
        writeln(q.Len:1, ' ', Len(q):1)
      end.
      """
    When it is compiled and run
    Then it prints
      """
      23 23
      """

  # 6.7.10.4 NOTE 17 again, and the reason the feature exists: a method is not
  # an exported name, so two types may each have one of a spelling §6.11.2
  # would refuse to two exported names.
  @afterschool:6.7.10.4
  Scenario: two types each have a routine of one spelling
    Given the Afterschool Pascal program
      """
      program p(output);
      type point = record x: integer end;
           counter = record n: integer end;
      impl point;
        function Amount(protected var self: point): integer;
        begin Amount := self.x * 2 end;
      end;
      impl counter;
        function Amount(protected var self: counter): integer;
        begin Amount := self.n + 1 end;
      end;
      var q: point; c: counter;
      begin
        q.x := 5; c.n := 5;
        writeln(q.Amount:1, ' ', c.Amount:1)
      end.
      """
    When it is compiled and run
    Then it prints
      """
      10 6
      """

  # 6.7.10.4 NOTE 19. The receiver reaches the compiler two ways: a simple
  # name is §6.11.3's qualified form and Sema tells them apart, and every
  # other variable-access is complete before the `(` and the parser can.
  @afterschool:6.7.10.4
  Scenario: the receiver may be any variable-access
    Given the Afterschool Pascal program
      """
      program p(output);
      type point = record x: integer end;
      impl point;
        function Amount(protected var self: point): integer;
        begin Amount := self.x end;
      end;
      procedure Run;
      var q: point; r: ^point; a: array [1..2] of point;
          b: record inner: point end;
      begin
        q.x := 1;
        new(r); r^.x := 2;
        a[1].x := 3;
        b.inner.x := 4;
        writeln(q.Amount:1, r^.Amount:1, a[1].Amount:1, b.inner.Amount:1);
        dispose(r)
      end;
      begin Run end.
      """
    When it is compiled and run
    Then it prints
      """
      1234
      """

  # 6.7.10's last requirement, which is what keeps 6.7.10.4's selection a
  # question with one answer.
  @afterschool:6.7.10
  Scenario: a field and a routine of one spelling are refused
    Given the Afterschool Pascal program
      """
      program p(output);
      type point = record Len: integer end;
      impl point;
        function Len(protected var self: point): integer;
        begin Len := 0 end;
      end;
      begin end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      would name two things
      """

  # 6.7.10: an inherent routine writes its own heading, there being no trait
  # to have given it one.
  @afterschool:6.7.10
  Scenario: an inherent routine that writes only its name is refused
    Given the Afterschool Pascal program
      """
      program p(output);
      type point = record x: integer end;
      impl point;
        procedure Reset;
        begin end;
      end;
      begin end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      needs its parameters here
      """
