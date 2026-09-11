# AP 6.7.11: the trait-object-type (ADR-0408, ADR-0409).
#
# The clause was written one increment before the feature and carried AP 5.6's
# `[not yet implemented]` marker while the type existed and nothing accepted
# it -- the first and so far only use of that mechanism. These scenarios are
# what replaced the marker: each starts from a sentence of 6.7.11 and asks
# what the processor does about it.
Feature: trait objects

  # 6.7.11.3. Which implementation answers is decided where the value is used
  # and not where the call is translated, which is the whole of the difference
  # between this and a bound (6.7.3.10.5). The three elements below are of
  # three different types and one of them is not a record at all -- an
  # implementation for a scalar is passed the same way only because 6.7.11.1
  # b) makes the receiver a variable-parameter.
  @afterschool:6.7.11
  @afterschool:6.7.11.3
  Scenario: one collection holds values of three types and each answers for itself
    Given the Afterschool Pascal program
      """
      program p(output);
      trait Renders;
        function Area(protected var q: Self): integer;
      end;
      type shape = dyn Renders;
           circle = record r: integer end;
           square = record s: integer end;
      impl Renders for circle;
        function Area;
        begin Area := 3 * q.r * q.r end;
      end;
      impl Renders for square;
        function Area;
        begin Area := q.s * q.s end;
      end;
      impl Renders for integer;
        function Area;
        begin Area := q end;
      end;
      procedure Run;
      var bag: array [1..3] of owned ^shape;
          c: owned ^circle; t: owned ^square; n: owned ^integer; i: integer;
      begin
        new(c); c^.r := 2;
        new(t); t^.s := 5;
        new(n); n^ := 7;
        bag[1] := take(c); bag[2] := take(t); bag[3] := take(n);
        for i := 1 to 3 do write(' ', Area(bag[i]^):1);
        writeln
      end;
      begin Run end.
      """
    When it is compiled and run
    Then it prints
      """
       12 25 7
      """

  # 6.7.11.1. A trait object refers to storage it does not own, so the two
  # positions are the two places the language can say who does. A variable of
  # the type is neither.
  @afterschool:6.7.11.1
  Scenario: a variable of a trait-object-type is refused
    Given the Afterschool Pascal program
      """
      program p(output);
      trait Renders;
        procedure Draw(protected var q: Self);
      end;
      var v: dyn Renders;
      begin end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      stands only as the domain of an 'owned' pointer or as a 'var' parameter
      """

  # 6.7.11.2. The value may not be copied, and 6.7.11.1 secures that by
  # confining it: a value parameter would be a copy of storage whose size is
  # not known where the copy is made.
  @afterschool:6.7.11.2
  Scenario: a value parameter of a trait-object-type is refused
    Given the Afterschool Pascal program
      """
      program p(output);
      trait Renders;
        procedure Draw(protected var q: Self);
      end;
      type shape = dyn Renders;
      procedure Show(x: shape);
      begin end;
      begin end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      must be a 'var' parameter
      """

  # 6.7.11.2.1. Object safety, and it is reported at the trait-object-type --
  # where the program asks for the facility -- rather than at each use.
  @afterschool:6.7.11.2.1
  Scenario: a trait whose receiver is a value parameter has no trait object
    Given the Afterschool Pascal program
      """
      program p(output);
      trait Renders;
        procedure Draw(q: Self);
      end;
      type shape = dyn Renders;
      begin end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      has no trait object
      """

  # 6.7.11.2.1 again, for the other half of the sentence: `Self` standing
  # anywhere but that first parameter would need two trait objects to agree
  # about a type neither of them carries.
  @afterschool:6.7.11.2.1
  Scenario: a trait naming Self in a second parameter has no trait object
    Given the Afterschool Pascal program
      """
      program p(output);
      trait Ranks;
        function Rank(protected var q: Self; other: Self): integer;
      end;
      type ranked = dyn Ranks;
      begin end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      somewhere other than that first parameter
      """

  # 6.7.11.4. The move is where the implementation is attached, so `new` has
  # none to attach -- and the storage it would create is of the right shape,
  # which is why this is refused rather than left alone.
  @afterschool:6.7.11.4
  Scenario: new of an owned pointer to a trait object is refused
    Given the Afterschool Pascal program
      """
      program p(output);
      trait Renders;
        procedure Draw(protected var q: Self);
      end;
      type shape = dyn Renders;
      procedure Run;
      var k: owned ^shape;
      begin new(k) end;
      begin Run end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      it would have no implementation
      """

  # 6.7.11.4. The release is carried by the value, because behind a trait
  # object the domain is not known where the release stands. A concrete type
  # that owns something is therefore released exactly as it is anywhere else:
  # the stream inside this record is buffered until it is closed, so reading
  # the file back says whether the *concrete* release ran.
  @afterschool:6.7.11.4
  Scenario: releasing a trait object releases what the concrete type owns
    Given the Afterschool Pascal program
      """
      program p(output, scratch);
      trait Renders;
        procedure Draw(protected var q: Self);
      end;
      type shape = dyn Renders;
           stream = handle external 'fclose';
           logged = record out_: stream end;
      var scratch: bindable text; bnd: BindingType; line: string(40);
      function ExtFopen(path, mode: string): stream; external 'fopen';
      function ExtFputs(t: string; s: stream): integer; external 'fputs';
      impl Renders for logged;
        procedure Draw;
        begin writeln('drawn') end;
      end;
      procedure Drop;
      var d: owned ^shape; g: owned ^logged;
      begin
        new(g);
        g^.out_ := ExtFopen('spec_dyn.tmp', 'w');
        if ExtFputs('flushed by the carried release', g^.out_) >= 0 then
          d := take(g)
      end;
      begin
        Drop;
        bnd := binding(scratch);
        bnd.name := 'spec_dyn.tmp';
        bind(scratch, bnd);
        reset(scratch);
        readln(scratch, line);
        writeln(line);
        unbind(scratch)
      end.
      """
    When it is compiled and run
    Then it prints
      """
      flushed by the carried release
      """
