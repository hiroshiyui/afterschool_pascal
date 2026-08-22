# ISO/IEC 10206:1991 §6.7.6.7 and §6.8.3.5 -- the two ways to compare strings,
# which are deliberately not the same comparison.
#
# The relational operators pad the shorter operand with spaces; the required
# functions EQ, LT and their family compare lengths as well. §6.7.6.7's NOTE 3
# says outright that LT(a, b) may be false while a < b is true, so a suite that
# checked only one of them would be satisfied by an implementation that had
# unified them -- which is the mistake the note exists to prevent.
#
# The padding rule is also what retired ISO 7185's requirement that string
# operands be of equal length, so the same program means different things under
# the two standards.

@extended:6.7.6.7 @extended:6.8.3.5
Feature: String comparison

  Scenario: the relational operators pad the shorter operand with spaces
    Given the Extended Pascal program
      """
      program p(output);
      var a, b: string(8);
      begin
        a := 'ab';
        b := 'ab  ';
        writeln(a = b)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      TRUE
      """

  Scenario: EQ compares the lengths too, so the same pair is unequal
    Given the Extended Pascal program
      """
      program p(output);
      var a, b: string(8);
      begin
        a := 'ab';
        b := 'ab  ';
        writeln(EQ(a, b))
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      FALSE
      """

  Scenario: a shorter string orders before a longer one that extends it
    Given the Extended Pascal program
      """
      program p(output);
      var a, b: string(8);
      begin
        a := 'ab';
        b := 'abc';
        writeln(a < b, ' ', LT(a, b))
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      TRUE TRUE
      """

@extended:6.4.3.3.2 @extended:6.7.6.7
Feature: Fixed-string-types and the string functions

  Scenario: length reports the value's length, not the capacity
    Given the Extended Pascal program
      """
      program p(output);
      var s: string(20);
      begin
        s := 'hello';
        writeln(length(s) : 1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      5
      """

  Scenario: substr of length zero is the null-string
    Given the Extended Pascal program
      """
      program p(output);
      var s: string(20);
      begin
        s := 'hello';
        writeln(length(substr(s, 3, 0)) : 1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      0
      """

  Scenario: a substring-variable with a lower bound above its upper is an error
    Given the Extended Pascal program
      """
      program p(output);
      var s: string(20); i, j: integer;
      begin
        s := 'hello';
        i := 3;
        j := 2;
        writeln(s[i .. j])
      end.
      """
    When it is compiled and run
    Then it stops at run time

  Scenario: assigning a value longer than the capacity is an error
    Given the Extended Pascal program
      """
      program p(output);
      var s: string(3);
      var t: string(10);
      begin
        t := 'abcdefg';
        s := t;
        writeln(s)
      end.
      """
    When it is compiled and run
    Then it stops at run time

  # ISO/IEC 10206:1991 §6.7.3.2 gives the required schema `string` its own
  # paragraph when it names a **value** parameter, and it is not the rule every
  # other schema-name follows: the actual is an expression "having an
  # underlying-type that is a string-type or the char-type", not a variable
  # produced from the schema. §6.11.6's own Example 10 writes
  # `record event('event-module initialization')`, which this compiler refused.
  @extended:6.7.3.2
  Scenario: a string value parameter takes any string expression
    Given the Extended Pascal program
      """
      program p(output);
      const greeting = 'hello';
      var v: string(40);
      procedure show(s: string);
      begin writeln(s, ' ', length(s) : 1) end;
      begin
        show('a literal');
        show('x');
        show(greeting);
        show('two' + ' halves');
        v := 'a variable';
        show(v)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      a literal 9
      x 1
      hello 5
      two halves 10
      a variable 10
      """

  # The clause's other half: the formal possesses the type produced "with the
  # tuple having that length as its component" — the length of the *value*, so
  # a `string(40)` holding three characters produces a formal of capacity 3.
  # Observable only by overflowing it, since length() answers the same under
  # either reading.
  @extended:6.7.3.2
  Scenario: its capacity is the value's length, not the actual's capacity
    Given the Extended Pascal program
      """
      program p(output);
      var v: string(40);
      procedure show(s: string);
      begin
        writeln(length(s) : 1);
        s := 'abcdefghij'
      end;
      begin v := 'abc'; show(v) end.
      """
    When it is compiled and run
    Then it stops at run time
     And the run-time error includes
      """
      does not fit a capacity of 3
      """

  # And what it does not excuse: the actual still has to have one of the two
  # types the clause names.
  @extended:6.7.3.2
  Scenario: but the argument must still be a string or a char
    Given the Extended Pascal program
      """
      program p(output);
      procedure show(s: string);
      begin writeln(s) end;
      begin show(42) end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      must be a string or a char
      """

# ISO/IEC 10206:1991 §6.4.5 and §6.4.6 -- the char-type is a legal *destination*
# for a string value, which is easy to miss because the two clauses have to be
# read together. §6.4.5 d) makes a string-type and the char-type compatible in
# either order, and §6.4.6 f) then names both as T1: "T1 and T2 are compatible,
# T1 is a string-type or the char-type, and the length of the value of T2 is
# less than or equal to the capacity of T1".
#
# Reading only §6.4.6 f)'s "string-type" and forgetting "or the char-type" does
# not refuse the program -- Sema accepts it on §6.4.5 alone -- it miscompiles it.

@extended:6.4.5 @extended:6.4.6
Feature: A string value may be assigned to a char variable

  Scenario: a substring of length one is assigned to a char
    Given the Extended Pascal program
      """
      program p(output);
      var c: char; s: string(10);
      begin
        s := 'hello';
        c := s[2..2];
        writeln(c)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      e
      """

  Scenario: the null-string is padded with spaces to the capacity of the char
    Given the Extended Pascal program
      """
      program p(output);
      var c: char; s: string(4);
      begin
        s := '';
        c := s;
        writeln('[', c, ']')
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      [ ]
      """

  Scenario: a value longer than the capacity of one is an error
    Given the Extended Pascal program
      """
      program p(output);
      var c: char; s: string(10);
      begin
        s := 'hi';
        c := s;
        writeln(c)
      end.
      """
    When it is compiled and run
    Then it stops at run time

# §6.7.3.2 with §6.4.6 -- what a value parameter of a string-type accepts.
#
# This compiler refused a shorter actual and said why: "a value parameter is
# copied rather than padded". That is a sentence about a lowering and not about
# the language, and the clause says the opposite.

@extended:6.7.3.2 @extended:6.4.6
Feature: A string value parameter takes any assignment-compatible actual

  # §6.7.3.2: "If the parameter-form of the value-parameter-specification
  # contains a type-name or a type-inquiry ... The value in the underlying-type
  # of the type of each corresponding actual-parameter ... shall be
  # assignment-compatible with the type possessed by the formal-parameters."
  #
  # Assignment-compatible, not equal — and §6.4.6's last paragraph then says
  # what a canonical-string value assigned to a fixed-string-type is: "the
  # components of the canonical-string-type value in order of increasing index
  # followed by zero or more spaces". §6.4.3.3.1's NOTE draws the conclusion in
  # so many words: "String-type values may be used as the actual-parameter
  # corresponding to a value parameter possessing a string-type (see 6.7.3.2)."

  Scenario: a shorter string is padded to a fixed-string value parameter
    Given the Extended Pascal program
      """
      program p(output);
      type five = packed array [1..5] of char;
      procedure show(s: five);
      begin writeln('[', s, ']') end;
      begin
        show('abc')
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      [abc  ]
      """

  Scenario: a variable-string is a legal actual for a fixed-string value parameter
    Given the Extended Pascal program
      """
      program p(output);
      type five = packed array [1..5] of char;
      var v: string(10);
      procedure show(s: five);
      begin writeln('[', s, ']') end;
      begin
        v := 'xy';
        show(v)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      [xy   ]
      """

  # §6.4.6's error list, c): "it shall be an error if T1 and T2 are compatible,
  # T1 is a string-type or the char-type, and the length of the value of T2 is
  # greater than the capacity of T1." The same rule at a call as at an
  # assignment, and reported at run time because the actual's length is one.

  Scenario: an actual longer than the formal's capacity stops the program
    Given the Extended Pascal program
      """
      program p(output);
      type five = packed array [1..5] of char;
      var v: string(10);
      procedure show(s: five);
      begin writeln('unreachable') end;
      begin
        v := 'abcdefg';
        writeln('before');
        show(v)
      end.
      """
    When it is compiled and run
    Then it stops at run time
     And it prints
      """
      before
      """
