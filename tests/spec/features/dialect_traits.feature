# AP 6.4.7.2, 6.7.9 and 6.7.10: traits, implementations and the bound
# (ADR-0338, ADR-0339, ADR-0340, ADR-0341).
#
# Four records describe this construct and three of them were written before
# anyone had built it; each was corrected by the next. What these scenarios
# pin is the shape that survived: a trait that is a bound and not a type, an
# implementation that belongs to one translation, a selection made from the
# first argument's type, and a bound written where the client writes the type.
Feature: traits and implementations

  # 6.7.9 and 6.7.10. Neither word is reserved: the same program declares a
  # type named `trait` and a field named `impl`, which is the test AP 6.0.1
  # sets for every dialect spelling.
  @afterschool:6.7.9
  @afterschool:6.7.10
  Scenario: a trait is implemented for two types and neither word is reserved
    Given the Afterschool Pascal program
      """
      program p(output);
      type trait = 1..9;
           impl = record trait: integer end;
           point = record x: integer end;
           line = record a: integer end;
      trait Sortable;
        function Rank(u: Self; v: Self): integer;
      end;
      impl Sortable for point;
        function Rank;
        begin Rank := u.x - v.x end;
      end;
      impl Sortable for line;
        function Rank;
        begin Rank := u.a - v.a end;
      end;
      var t: trait; i: impl; p, q: point; m, n: line;
      begin
        t := 4; i.trait := 5;
        p.x := 9; q.x := 2; m.a := 1; n.a := 8;
        writeln(t:1, i.trait:1, ' ', Rank(p, q):1, ' ', Rank(m, n):1)
      end.
      """
    When it is compiled and run
    Then it prints
      """
      45 7 -7
      """

  # 6.7.9. A trait names no type: it stands as a bound and nowhere else.
  @afterschool:6.7.9
  Scenario: a trait in a type-denoter is refused
    Given the Afterschool Pascal program
      """
      program p(output);
      trait Sortable;
        function Rank(u: Self; v: Self): integer;
      end;
      var x: Sortable;
      begin end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      is a trait, so it names no type
      """

  # 6.7.9.1. Self stands as a whole parameter-form or result-type. Inside one
  # it is refused at the trait, because left to the implementation the message
  # arrives once per implementation and describes a parameter list the
  # implementer did not write.
  @afterschool:6.7.9.1
  Scenario: Self inside a parameter-form is refused at the trait
    Given the Afterschool Pascal program
      """
      program p(output);
      trait Bad;
        function Take(xs: array of Self): integer;
      end;
      begin end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      'self' may stand as a parameter's whole type or as a result type
      """

  # 6.7.9.1. And as a result type it is admitted, which is the other half.
  @afterschool:6.7.9.1
  Scenario: Self is a result type
    Given the Afterschool Pascal program
      """
      program p(output);
      type point = record x: integer end;
      trait Pick;
        function Larger(u: Self; v: Self): Self;
      end;
      impl Pick for point;
        function Larger;
        begin if u.x >= v.x then Larger := u else Larger := v end;
      end;
      var a, b: point;
      begin a.x := 3; b.x := 8; writeln(Larger(a, b).x:1) end.
      """
    When it is compiled and run
    Then it prints
      """
      8
      """

  # 6.7.9.2 and 6.7.10.2. A trait's routine names are not in the block's
  # scope, and the trait lookup is consulted only after the ordinary one. So a
  # program declaring its own routine of the name goes on meaning what it
  # meant -- and the trait's routine of that spelling becomes unreachable,
  # which is what "only after" costs.
  @afterschool:6.7.9.2
  @afterschool:6.7.10.2
  Scenario: an ordinary declaration of the name wins its own lookup
    Given the Afterschool Pascal program
      """
      program p(output);
      type point = record x: integer end;
      trait Sortable;
        function Rank(u: Self; v: Self): integer;
      end;
      impl Sortable for point;
        function Rank;
        begin Rank := u.x - v.x end;
      end;
      function Rank(a, b: integer): integer;
      begin Rank := a + b end;
      begin writeln(Rank(2, 3):1) end.
      """
    When it is compiled and run
    Then it prints
      """
      5
      """

  # 6.7.10.2, the other side of the same rule: with the ordinary declaration
  # in force the trait's routine cannot be reached by that spelling at all.
  @afterschool:6.7.10.2
  Scenario: an ordinary declaration hides the trait routine entirely
    Given the Afterschool Pascal program
      """
      program p(output);
      type point = record x: integer end;
      trait Sortable;
        function Rank(u: Self; v: Self): integer;
      end;
      impl Sortable for point;
        function Rank;
        begin Rank := u.x - v.x end;
      end;
      function Rank(a, b: integer): integer;
      begin Rank := a + b end;
      var s, t: point;
      begin s.x := 9; t.x := 4; writeln(Rank(s, t):1) end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      argument 1 of 'rank' is integer, but the value is point
      """

  # 6.7.10.2. Selection reads the host-type of a subrange, so one
  # implementation for integer serves every subrange of it.
  @afterschool:6.7.10.2
  Scenario: a subrange selects the implementation written for its host
    Given the Afterschool Pascal program
      """
      program p(output);
      trait Sortable;
        function Rank(u: Self; v: Self): integer;
      end;
      impl Sortable for integer;
        function Rank;
        begin Rank := u - v end;
      end;
      type digit = 1..9;
      var d: digit; n: integer;
      begin d := 8; n := 3; writeln(Rank(d, n):1) end.
      """
    When it is compiled and run
    Then it prints
      """
      5
      """

  # 6.7.10.2. And an implementation written for the subrange itself is refused
  # where it is written, because it could never be the one selected.
  @afterschool:6.7.10.2
  Scenario: an implementation for a subrange is refused
    Given the Afterschool Pascal program
      """
      program p(output);
      trait Sortable;
        function Rank(u: Self; v: Self): integer;
      end;
      type digit = 1..9;
      impl Sortable for digit;
        function Rank;
        begin Rank := u - v end;
      end;
      begin end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      a subrange takes its host's implementation
      """

  # 6.7.10.2. A first argument that is not a designator selects nothing, and
  # the message is the ordinary one for a name that denotes no routine.
  @afterschool:6.7.10.2
  Scenario: a literal first argument selects no implementation
    Given the Afterschool Pascal program
      """
      program p(output);
      trait Sortable;
        function Rank(u: Self; v: Self): integer;
      end;
      impl Sortable for integer;
        function Rank;
        begin Rank := u - v end;
      end;
      var n: integer;
      begin n := 1; writeln(Rank(7, n):1) end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      unknown function 'rank'
      """

  # 6.7.10. Every routine the trait declares is defined exactly once, and the
  # heading is written as a name alone.
  @afterschool:6.7.10
  Scenario: an implementation missing one of the trait's routines is refused
    Given the Afterschool Pascal program
      """
      program p(output);
      type point = record x: integer end;
      trait Sortable;
        function Rank(u: Self; v: Self): integer;
        function Same(u: Self; v: Self): boolean;
      end;
      impl Sortable for point;
        function Rank;
        begin Rank := u.x - v.x end;
      end;
      begin end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      does not define 'same'
      """

  # 6.7.10.1. An implementation is a fact about one translation: nested in a
  # procedure it would be selected from outside the procedure whose frames its
  # routines read.
  @afterschool:6.7.10.1
  Scenario: an implementation inside a procedure is refused
    Given the Afterschool Pascal program
      """
      program p(output);
      type point = record x: integer end;
      trait Sortable;
        function Rank(u: Self; v: Self): integer;
      end;
      procedure Q;
        impl Sortable for point;
          function Rank;
          begin Rank := u.x - v.x end;
        end;
      begin end;
      begin Q end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      cannot be written inside a procedure or a function
      """

  # 6.4.7.2. The payoff: the bound is written where the client writes the
  # type, so every routine over the schema is unchanged.
  @afterschool:6.4.7.2
  Scenario: a trait bounds a schema's type-valued discriminant
    Given the Afterschool Pascal program
      """
      program p(output);
      type point = record x: integer end;
      trait Sortable;
        function Rank(u: Self; v: Self): integer;
      end;
      impl Sortable for point;
        function Rank;
        begin Rank := u.x - v.x end;
      end;
      type Box(K: Sortable; cap: integer) = record
             items: array [1..cap] of K
           end;
           PBox = ^Box(point);
      var b: PBox;
      begin
        new(b, 2);
        b^.items[1].x := 7; b^.items[2].x := 2;
        writeln(Rank(b^.items[1], b^.items[2]):1);
        dispose(b)
      end.
      """
    When it is compiled and run
    Then it prints
      """
      5
      """

  # 6.4.7.2. And a type with no implementation is refused at the type-denoter
  # the program wrote, which is what a bound buys over a body's diagnostic.
  @afterschool:6.4.7.2
  Scenario: a type that does not implement the bound is refused where it is written
    Given the Afterschool Pascal program
      """
      program p(output);
      type line = record a: integer end;
      trait Sortable;
        function Rank(u: Self; v: Self): integer;
      end;
      type Box(K: Sortable; cap: integer) = record
             items: array [1..cap] of K
           end;
      var b: Box(line, 2);
      begin end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      it has no implementation of 'sortable'
      """

  # 6.7.3.10.5. The same bound on a routine's type parameter, written and
  # inferred, which is what serves a sort.
  @afterschool:6.7.3.10.5
  Scenario: a trait bounds a routine's type parameter
    Given the Afterschool Pascal program
      """
      program p(output);
      type point = record x: integer end;
      trait Sortable;
        function Rank(u: Self; v: Self): integer;
      end;
      impl Sortable for point;
        function Rank;
        begin Rank := u.x - v.x end;
      end;
      function Bigger(T: Sortable type; a, b: T): T;
      begin if Rank(a, b) >= 0 then Bigger := a else Bigger := b end;
      var s, t, r: point;
      begin
        s.x := 4; t.x := 6;
        r := Bigger(point, s, t);
        writeln(r.x:1);
        r := Bigger(s, t);
        writeln(r.x:1)
      end.
      """
    When it is compiled and run
    Then it prints
      """
      6
      6
      """

  # 6.7.9 NOTE 1. The four category spellings are identified in a bound
  # position by spelling alone (6.7.3.10.5), and a bound is the only position
  # a trait may stand in -- so a trait of one of those names could never be
  # applied. Refused where it is written, not at the activation, where the
  # message would be about a category the program never mentioned (ADR-0344).
  @afterschool:6.7.9
  Scenario: a trait named for a type-parameter category is refused
    Given the Afterschool Pascal program
      """
      program p(output);
      type point = record x: integer end;
      trait Ordered;
        function Before(u: Self; v: Self): boolean;
      end;
      impl Ordered for point;
        function Before;
        begin Before := u.x < v.x end;
      end;
      var s, t: point;
      begin
        s.x := 1; t.x := 2;
        writeln(Before(s, t))
      end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      a trait may not be named 'ordered'
      """
