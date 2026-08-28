# ISO/IEC 10206:1991 §6.8.2 opens every constant position from a *constant* to
# an expression, and restricts that expression only by requiring it to be
# nonvarying. §6.3.2's own example of a constant-definition-part then writes
# `third = unity/3.0` and cites §6.8.2 for it.
#
# This compiler refused every real-valued constant-expression until ADR-0227,
# because a real constant is carried as the text that was written and was never
# converted (ADR-0025). The refusal was a fact about the compiler recorded as
# though it were a restriction the standard permits; §5.1 c) admits
# restrictions, but ADR-0224's audit found this one had been written down twice
# with a reason that is not about §6.8.2 at all.
#
# ISO 7185 is untouched by all of this: §6.3 there admits a `constant` and not
# an expression, so no ISO 7185 program has a real-valued constant-expression
# to fold.

Feature: real-valued constant-expressions

  @extended:6.8.2
  Scenario: the standard's own example of a constant-definition-part
    Given the Extended Pascal program
      """
      program p(output);
      const unity = 1.0;
            third = unity/3.0;
      begin
        writeln(third:20)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
       3.3333333333333E-01
      """

  # §6.8.3.2 table 3 note (4): an integer operand of a real operation stands
  # for "a real-type approximation to its value", so `4 * arctan(1)` is a real
  # expression with two integer literals in it.
  @extended:6.8.2 @extended:6.7.6.2
  Scenario: a folded mathematical function is the value the program computes
    Given the Extended Pascal program
      """
      program p(output);
      const pi = 4 * arctan(1);
      var v: real;
      begin
        v := 4 * arctan(1.0);
        writeln(v = pi)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      TRUE
      """

  # §6.7.6.3's transfer functions yield integers, so what they needed was the
  # conversion alone and never a way to write a real back.
  @extended:6.8.2 @extended:6.7.6.3
  Scenario: trunc and round of a constant are constants
    Given the Extended Pascal program
      """
      program p(output);
      const cut = trunc(3.7);
            near = round(3.5);
      type small = 1..near;
      var x: small;
      begin
        x := cut;
        writeln(cut:1, ' ', near:1, ' ', x:1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      3 4 3
      """

  # §6.8.3.2 makes x/y an error if y is zero. Where the expression is constant
  # the fold has to ask before it divides — the emitted code traps on this, and
  # the compiler's own arithmetic is what performs the fold.
  @extended:6.8.2 @extended:6.8.3.2
  Scenario: an error in a constant-expression is a compile-time diagnostic
    Given the Extended Pascal program
      """
      program p(output);
      const bad = 1.0 / 0.0;
      begin
        writeln(bad)
      end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      division by zero in a constant expression
      """

  # "shall be an error if x is negative" — and the two exponentiating
  # operators exist so that a negative base has somewhere to go.
  @extended:6.8.2 @extended:6.8.3.2
  Scenario: a negative base of ** is refused where it is constant
    Given the Extended Pascal program
      """
      program p(output);
      const bad = (-2.0) ** 0.5;
      begin
        writeln(bad)
      end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      a negative base of '**' in a constant expression
      """

