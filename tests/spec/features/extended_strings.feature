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
