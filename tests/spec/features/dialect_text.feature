# AP 6.4.15 -- the text-type. What a program holds when it means the characters
# rather than the octets (ADR-0189, ADR-0191).
#
# The scenarios below are ordered as the clause is, and the one that matters is
# "two spellings of one character are one value": everything else in the model
# is arranged to make that true cheaply.
@afterschool:6.4.15
Feature: Text

  @afterschool:6.4.15.1
  Scenario: the discriminant is a capacity in bytes, not in elements
    Given the Afterschool Pascal program
      """
      program p(output);
      var t: utf8(64);
      begin writeln(t.capacity) end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      64
      """

  @afterschool:6.4.15.1
  Scenario: utf8 is a required identifier and a program may declare its own
    Given the Afterschool Pascal program
      """
      program p(output);
      var utf8: integer;
      begin utf8 := 7; writeln(utf8) end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      7
      """

  @afterschool:6.4.15.2
  Scenario: a value is normalised where it is constructed
    Given the Afterschool Pascal program
      """
      program p(output);
      var t: utf8(64); s: string(64);
      begin
        t := 'héllo';
        s := t;
        writeln(length(s))
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      6
      """

  @afterschool:6.4.15.2
  Scenario: bytes that are not well-formed UTF-8 stop the program
    Given the Afterschool Pascal program
      """
      program p(output);
      var t: utf8(16); s: string(16);
      begin
        s := 'ab';
        s[2] := chr(128);
        t := s;
        writeln(length(t))
      end.
      """
    When it is compiled and run
    Then it stops at run time
     And the run-time error includes
      """
      not well-formed UTF-8
      """

  @afterschool:6.4.15.3
  Scenario: an element is an extended grapheme cluster, not a code point
    Given the Afterschool Pascal program
      """
      program p(output);
      var t: utf8(64);
      begin
        t := '한';
        writeln(length(t))
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      1
      """

  @afterschool:6.4.15.4
  Scenario: one schema with one tuple is one type
    Given the Afterschool Pascal program
      """
      program p(output);
      type Short = utf8(32);
      var a: Short; b: utf8(32);
      begin a := 'x'; b := a; writeln(length(b)) end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      1
      """

  @afterschool:6.4.15.5
  Scenario: a value that does not fit the capacity stops the program
    Given the Afterschool Pascal program
      """
      program p(output);
      var small: utf8(4); wide: utf8(64);
      begin
        wide := 'abcdefgh';
        small := wide;
        writeln(length(small))
      end.
      """
    When it is compiled and run
    Then it stops at run time
     And the run-time error includes
      """
      does not fit the capacity
      """

  @afterschool:6.4.15.6
  Scenario: two spellings of one character compare equal
    Given the Afterschool Pascal program
      """
      program p(output);
      var a, b: utf8(64);
      begin
        a := 'héllo';
        b := 'héllo';
        writeln(a = b)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      TRUE
      """

  @afterschool:6.4.15.6
  Scenario: a text and a string are not comparable
    Given the Afterschool Pascal program
      """
      program p(output);
      var t: utf8(16); s: string(16);
      begin if t = s then writeln('no') end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      a text and a string cannot be compared
      """

  @afterschool:6.4.15.8
  Scenario: length counts elements where the capacity counts bytes
    Given the Afterschool Pascal program
      """
      program p(output);
      var t: utf8(64); s: string(64);
      begin
        t := 'héllo';
        s := t;
        writeln(length(t), ' ', length(s))
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      5 6
      """

  @afterschool:6.4.15.9
  Scenario: a text has no integer index
    Given the Afterschool Pascal program
      """
      program p(output);
      var t: utf8(16); c: char;
      begin c := t[1]; writeln(c) end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      cannot subscript a value of type utf8(16)
      """

  @afterschool:6.4.15.10
  Scenario: a field width pads to a count of elements
    Given the Afterschool Pascal program
      """
      program p(output);
      var t: utf8(64);
      begin
        t := 'héllo';
        writeln('|', t:8, '|')
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      |   héllo|
      """

  @afterschool:6.4.15.11
  Scenario: a text is not a read-parameter
    Given the Afterschool Pascal program
      """
      program p(input, output);
      var t: utf8(16);
      begin read(t) end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      cannot be read
      """

  @afterschool:6.4.15.7
  Scenario: joining composes across the join, so it is not a byte concatenation
    Given the Afterschool Pascal program
      """
      program p(output);
      var a, b: utf8(64); s: string(64);
      begin
        a := 'he';
        b := '́llo';
        s := a + b;
        writeln(length(s), ' ', a + b = 'héllo')
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      6 TRUE
      """

  @afterschool:6.4.15.7
  Scenario: a string is not an operand of a text concatenation
    Given the Afterschool Pascal program
      """
      program p(output);
      var t: utf8(16); s: string(16);
      begin t := t + s end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      a text can be joined only to a text or to a literal
      """

  @afterschool:6.4.15.9
  Scenario: iteration yields elements, and rejoining them gives the original
    Given the Afterschool Pascal program
      """
      program p(output);
      var t, g, back: utf8(64); n: integer;
      begin
        t := 'héllo';
        n := 0;
        back := '';
        for g in t do
          begin n := n + 1; back := back + g end;
        writeln(n, ' ', back = t)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      5 TRUE
      """

  @afterschool:6.4.15.9
  Scenario: the control variable of an iteration over a text is a text
    Given the Afterschool Pascal program
      """
      program p(output);
      var t: utf8(16); c: char;
      begin for c in t do writeln(c) end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      must be a text
      """
