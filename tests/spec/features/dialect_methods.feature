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

  # 6.7.10.5 and 6.13: an implementation written in a module-block is selected
  # by 6.7.10.2 in a component that imports the module. It is the one place
  # where something a block writes is part of what a client may depend on, and
  # it follows from the selection rule rather than being granted: the routine
  # is identified from the *type*, and the type is exported.
  @afterschool:6.7.10.5
  @afterschool:6.13.2
  Scenario: a module's implementation reaches the component that imports it
    Given the program-component
      """
      module shapesm;
      export shaping = (circle, circleof);
      type circle = record r: integer end;
      function circleof(radius: integer): circle;
      end;
      function circleof; var t: circle; begin t.r := radius; circleof := t end;
      impl circle;
        function Area(protected var me: circle): integer;
        begin Area := 3 * me.r * me.r end;
        function Grown(protected var me: circle; by: integer): circle;
        var t: circle;
        begin t.r := me.r + by; Grown := t end;
      end;
      end.
      """
    Given the Afterschool Pascal program
      """
      program p(output);
      import shaping;
      var c: circle;
      begin
        c := circleof(2);
        writeln(c.Area:1, ' ', Area(c):1, ' ', c.Grown(3).r:1)
      end.
      """
    When it is compiled and run
    Then it prints
      """
      12 12 5
      """

  # 6.7.10.5 NOTE 20. A trait declared in one component, a type in another and
  # the implementation in a third is the arrangement a library is in, and the
  # selection still reads only the type.
  @afterschool:6.7.10.5
  Scenario: a trait, a type and an implementation in three components
    Given the program-component
      """
      module namingm;
      export naming = (naming_, tagbase);
      trait naming_;
        function Tag(protected var me: Self): integer;
      end;
      function tagbase: integer;
      end;
      function tagbase; begin tagbase := 100 end;
      end.
      """
    Given the program-component
      """
      module squarem;
      export squaring = (square, squareof);
      type square = record s: integer end;
      function squareof(side: integer): square;
      end;
      function squareof; var t: square; begin t.s := side; squareof := t end;
      end.
      """
    Given the Afterschool Pascal program
      """
      program p(output);
      import naming; squaring;
      impl naming_ for square;
        function Tag;
        begin Tag := tagbase + me.s end;
      end;
      var q: square;
      begin
        q := squareof(7);
        writeln(q.Tag:1)
      end.
      """
    When it is compiled and run
    Then it prints
      """
      107
      """
