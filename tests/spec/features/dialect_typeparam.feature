# AP 6.7.3.10 -- a routine parameterised by a type. The spelling is a position
# (6.7.3.1 admits `type` only as the first word of a type-inquiry), so the
# dialect reserves nothing for it; the routine is translated once per distinct
# type it is activated with, which is 6.4.7's rule for a schema said for a
# routine.
Feature: A routine may be parameterised by a type

  @afterschool:6.7.3.10
  Scenario: one body serves two types
    Given the Afterschool Pascal program
      """
      program p(output);
      type Point = record x, y: integer end;
      procedure Swap(T: type; var a, b: T);
      var q: T;
      begin q := a; a := b; b := q end;
      var i, j: integer; u, v: Point;
      begin
        i := 3; j := 7; Swap(integer, i, j);
        u.x := 1; v.x := 8; Swap(Point, u, v);
        writeln(i:1, ' ', j:1, ' ', u.x:1, ' ', v.x:1)
      end.
      """
    When it is compiled and run
    Then it prints
      """
      7 3 8 1
      """

  @afterschool:6.7.3.10
  Scenario: a type parameter names a type for the body as well as the heading
    Given the Afterschool Pascal program
      """
      program p(output);
      procedure Sum(T: type; var a: T; var out: integer);
      var q: T;
      begin q := a; out := 1 end;
      var c: char; n: integer;
      begin c := 'x'; Sum(char, c, n); writeln(n:1) end.
      """
    When it is compiled and run
    Then it prints
      """
      1
      """

  @afterschool:6.7.3.10.1
  Scenario: the actual matching a type parameter must name a type
    Given the Afterschool Pascal program
      """
      program p(output);
      procedure P(T: type; var a: T);
      begin a := a end;
      var i: integer;
      begin P(i, i) end.
      """
    When it is compiled
    Then it is rejected
    And the diagnostic includes
      """
      must name a type
      """

  @afterschool:6.7.3.10.1
  Scenario: the type arguments must be there at all
    Given the Afterschool Pascal program
      """
      program p(output);
      procedure P(T: type; var a: T);
      begin a := a end;
      begin P end.
      """
    When it is compiled
    Then it is rejected
    And the diagnostic includes
      """
      needs a type here
      """

  @afterschool:6.7.3.10.2
  Scenario: a recursive generic activation reaches the routine being produced
    Given the Afterschool Pascal program
      """
      program p(output);
      function Depth(T: type; var a: T; n: integer): integer;
      begin
        if n <= 0 then Depth := 0 else Depth := 1 + Depth(T, a, n - 1)
      end;
      var i: integer;
      begin i := 0; writeln(Depth(integer, i, 4):1) end.
      """
    When it is compiled and run
    Then it prints
      """
      4
      """

  @afterschool:6.7.3.10.2
  Scenario: a generic nothing activates produces nothing, and is not checked
    Given the Afterschool Pascal program
      """
      program p(output);
      type Point = record x, y: integer end;
      procedure Never(T: type; var a: T);
      var q: Point;
      begin q.x := a.thisFieldDoesNotExist end;
      begin writeln('ok') end.
      """
    When it is compiled and run
    Then it prints
      """
      ok
      """

  @afterschool:6.7.3.10.3
  Scenario: a type parameter occupies no argument position
    Given the Afterschool Pascal program
      """
      program p(output);
      procedure P(T: type; var a: T);
      begin a := a end;
      var i: integer;
      begin P(integer) end.
      """
    When it is compiled
    Then it is rejected
    And the diagnostic includes
      """
      takes 1 argument(s), but 0 were given
      """

  @afterschool:6.7.3.10.4
  Scenario: the types may be left out where an actual determines them
    Given the Afterschool Pascal program
      """
      program p(output);
      procedure Swap(T: type; var a, b: T);
      var held: T;
      begin held := a; a := b; b := held end;
      var i, j: integer;
      begin i := 1; j := 2; Swap(i, j); writeln(i:1, j:1) end.
      """
    When it is compiled and run
    Then it prints
      """
      21
      """

  @afterschool:6.7.3.10.4
  Scenario: the determining position may be inside a production
    Given the Afterschool Pascal program
      """
      program p(output);
      type Code = (failed);
           Fallible(T: type) = T ! Code;
      function ValueOr(T: type; res: Fallible(T); whenBad: T): T;
      begin if res.ok then ValueOr := res.val else ValueOr := whenBad end;
      var r: Fallible(integer);
      begin r := failed; writeln(ValueOr(r, 9):1) end.
      """
    When it is compiled and run
    Then it prints
      """
      9
      """

  @afterschool:6.7.3.10.4
  Scenario: an inferred activation and a written one are one instantiation
    Given the Afterschool Pascal program
      """
      program p(output);
      function Id(T: type; x: T): T;
      begin Id := x end;
      begin writeln(Id(integer, 3):1, Id(4):1) end.
      """
    When it is compiled and run
    Then it prints
      """
      34
      """

  @afterschool:6.7.3.10.4
  Scenario: a type parameter no actual determines is refused
    Given the Afterschool Pascal program
      """
      program p(output);
      function Pick(T: type; n: integer): T;
      var got: T;
      begin Pick := got end;
      begin writeln(Pick(3):1) end.
      """
    When it is compiled
    Then it is rejected
    And the diagnostic includes
      """
      nothing in this call says what
      """

  @afterschool:6.7.3.10.4
  Scenario: a later actual does not redetermine, and is judged as any other
    Given the Afterschool Pascal program
      """
      program p(output);
      procedure Swap(T: type; var a, b: T);
      var held: T;
      begin held := a; a := b; b := held end;
      var i: integer; c: char;
      begin Swap(i, c) end.
      """
    When it is compiled
    Then it is rejected
    And the diagnostic includes
      """
      but the argument is char
      """

  @afterschool:6.7.3.10.5
  Scenario: a category admits a type that answers for it
    Given the Afterschool Pascal program
      """
      program p(output);
      function Sum(Elem: numeric type; a, b: Elem): Elem;
      begin Sum := a + b end;
      begin writeln(Sum(2, 3):1, Sum(1.5, 2.5):4:1) end.
      """
    When it is compiled and run
    Then it prints
      """
      5 4.0
      """

  @afterschool:6.7.3.10.5
  Scenario: a category refuses the activation and not the body
    Given the Afterschool Pascal program
      """
      program p(output);
      type Point = record x, y: integer end;
      function Sum(Elem: numeric type; a, b: Elem): Elem;
      begin Sum := a + b end;
      var q: Point;
      begin q := Sum(Point, q, q) end.
      """
    When it is compiled
    Then it is rejected
    And the diagnostic includes
      """
      which is declared 'numeric type'
      """

  @afterschool:6.7.3.10.5
  Scenario: an inferred activation names the actual that determined the type
    Given the Afterschool Pascal program
      """
      program p(output);
      type Point = record x, y: integer end;
      function Larger(Elem: ordered type; a, b: Elem): Elem;
      begin if a > b then Larger := a else Larger := b end;
      var q: Point;
      begin q := Larger(q, q) end.
      """
    When it is compiled
    Then it is rejected
    And the diagnostic includes
      """
      argument 1 of this call is what determined it
      """

  @afterschool:6.7.3.10.5
  Scenario: the four category spellings are ordinary identifiers everywhere else
    Given the Afterschool Pascal program
      """
      program p(output);
      type ordinal = 1..9;
      var numeric: ordinal; ordered: char; equatable: boolean;
      function Span(Elem: ordinal type; lo, hi: Elem): integer;
      begin Span := ord(hi) - ord(lo) end;
      begin
        numeric := 4; ordered := 'z'; equatable := true;
        writeln(numeric:1, ordered, equatable, Span('a', 'c'):1)
      end.
      """
    When it is compiled and run
    Then it prints
      """
      4zTRUE2
      """

  @afterschool:6.7.3.10.5
  Scenario: a spelling that is not one of the four is refused as a category
    Given the Afterschool Pascal program
      """
      program p(output);
      function Sum(Elem: hashable type; a, b: Elem): Elem;
      begin Sum := a + b end;
      begin writeln(Sum(1, 2):1) end.
      """
    When it is compiled
    Then it is rejected
    And the diagnostic includes
      """
      is not a type-parameter category
      """

  @afterschool:6.7.3.10.4
  Scenario: an activation may write a prefix of its type arguments
    Given the Afterschool Pascal program
      """
      program p(output);
      type Row = array [1..3] of integer;
      function ItemAt(Elem: type; Cont: type; protected var v: Cont;
                      i: integer): Elem;
      begin ItemAt := v[i] end;
      var r: Row;
      begin r[2] := 7; writeln(ItemAt(integer, r, 2):1) end.
      """
    When it is compiled and run
    Then it prints
      """
      7
      """

  @afterschool:6.7.3.10.4
  Scenario: a written type argument is not redetermined by an actual
    Given the Afterschool Pascal program
      """
      program p(output);
      function Held(T: type; U: type; whenBad: T; n: U): T;
      begin Held := whenBad end;
      begin writeln(Held(real, 2, 65):6:2) end.
      """
    When it is compiled and run
    Then it prints
      """
        2.00
      """

  @afterschool:6.7.3.10.4
  Scenario: writing a prefix does not make the rest determinable
    Given the Afterschool Pascal program
      """
      program p(output);
      function Pair(T: type; U: type; n: integer): U;
      var got: U;
      begin Pair := got end;
      begin writeln(Pair(integer, 3):1) end.
      """
    When it is compiled
    Then it is rejected
    And the diagnostic includes
      """
      nothing in this call says what 'u' of 'pair' is
      """
