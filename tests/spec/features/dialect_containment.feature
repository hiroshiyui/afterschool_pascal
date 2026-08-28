# AP 6.0.1 -- the property every other clause is an addition to. It is a claim
# about every Extended Pascal program, and a scenario can only witness it, so
# what is written here is the shape of witness that would fail loudly: a
# program using several of the standard's own features and meaning what the
# standard says. tests/dialect/inherits_extended.pas is the larger witness.
@afterschool:6.0.1
Feature: The dialect contains Extended Pascal

  Scenario: an Extended Pascal program means the same under the dialect
    Given the Afterschool Pascal program
      """
      program p(output);
      type vec(n: integer) = array [1..n] of integer;
           colour = (red, green, blue);
      var v: vec(3); s: string(8); c: colour; i: integer;
      begin
        for i := 1 to 3 do v[i] := i * i;
        s := 'ab' + 'cd';
        c := succ(red);
        case c of
          green: writeln(v[3], ' ', s, ' green');
          otherwise writeln('wrong')
        end
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      9 abcd green
      """

  # AP 6.0.2 says there is nothing to select, and this is that stated as a
  # program: the source below is the one above, offered under a different
  # label, and the labels are all this suite has left of the modes -- run.py
  # records which one a scenario used and passes no flag for it, because there
  # is none to pass (ADR-0232). Two labels, one compiler, one answer.
  @afterschool:6.0.2
  Scenario: the same source under another label means exactly the same thing
    Given the Extended Pascal program
      """
      program p(output);
      type vec(n: integer) = array [1..n] of integer;
           colour = (red, green, blue);
      var v: vec(3); s: string(8); c: colour; i: integer;
      begin
        for i := 1 to 3 do v[i] := i * i;
        s := 'ab' + 'cd';
        c := succ(red);
        case c of
          green: writeln(v[3], ' ', s, ' green');
          otherwise writeln('wrong')
        end
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      9 abcd green
      """

  # 6.1.2's second paragraph is the requirement the whole containment rests on,
  # and this is it stated as a program: every word the dialect introduced is
  # still a name a program may take. `?` has no identifier form and is covered
  # by the scenario above. tests/checks/reserved_words.py used to ask the same
  # question of all 45 word-symbols at once -- which a scenario cannot -- by
  # requiring the dialect's table to equal Extended Pascal's; ADR-0232 left one
  # table and nothing to compare it against, so the requirement now stands on
  # this scenario and on the review.
  @afterschool:6.1.2
  Scenario: the dialect adds no word-symbol, so its own spellings stay available
    Given the Afterschool Pascal program
      """
      program p(output);
      var external, int64, maxint64: integer;
      function optional(slice: integer): integer;
      begin optional := slice + external + int64 + maxint64 end;
      begin
        external := 1; int64 := 10; maxint64 := 100;
        writeln(optional(2))
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      113
      """

  @afterschool:6.1.4
  Scenario: external is not a word-symbol, so a program may still use the name
    Given the Afterschool Pascal program
      """
      program p(output);
      var external: integer;
      begin external := 5; writeln(external) end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      5
      """

  # The requirement 6.5.6 states is the *exclusion*: a string-type is sliced as
  # a substring and not as a slice. It is not a special case but the containment
  # itself -- a packed array of char is a string-type AND an array with an
  # integer index-type, so the slice reading would take s[1..3] away from every
  # conforming program that writes one. The first draft of the clause omitted
  # this and said the opposite of what the processor does (Annex E.6).
  @afterschool:6.5.6
  Scenario: a substring of a string-type is still a substring under the dialect
    Given the Afterschool Pascal program
      """
      program p(output);
      var s: packed array [1..6] of char; t: string(10);
      begin
        s := 'abcdef';
        t := s[2..4];
        writeln(t)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      bcd
      """

  # ...and the mirror, which is what makes the first mean something: the same
  # designator over an array that is *not* a string-type yields a slice, and a
  # slice is not a value any variable can be assigned.
  @afterschool:6.5.6
  Scenario: the same designator over a non-string array yields a slice
    Given the Afterschool Pascal program
      """
      program p(output);
      var c: array [1..6] of char; t: string(10);
      begin t := c[2..4] end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      a slice cannot be assigned
      """

