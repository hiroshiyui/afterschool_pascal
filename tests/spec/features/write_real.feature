# ISO/IEC 10206:1991 §6.10.3.4.1 and §6.10.3.4.2, and ISO 7185 §6.9.3.4.2 in
# the same words -- how a real is written, and specifically which way a
# halfway value goes.
#
# The clauses do not say "rounded" and leave it there. They prescribe
#
#     eWritten := abs(e);
#     eWritten := eWritten + 0.5 * 10.0 pow(-FracDigits);
#     eWritten := Truncate(eWritten, FracDigits)
#
# which is round-half-away-from-zero. A processor that hands the job to a C
# library gets round-half-to-even, and the two disagree at every exact halfway
# value -- which is a silent wrong answer, not a diagnostic.
#
# The sign is the other half, and it is conditioned on the value *after*
# rounding: "the character '-' if (e < 0.0) and (eWritten > 0.0)".

@extended:6.10.3.4.2 @extended:6.10.3.4.1
Feature: Writing a real value

  Scenario: an exact halfway value rounds away from zero, not to even
    Given the Extended Pascal program
      """
      program p(output);
      begin
        writeln(0.125:6:2);
        writeln(0.375:6:2)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
        0.13
        0.38
      """

  Scenario: a negative value that rounds away to nothing is written without a sign
    Given the Extended Pascal program
      """
      program p(output);
      begin
        writeln('[', -0.000001:0:2, ']')
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      [0.00]
      """

  Scenario: a fraction length of zero still writes the point
    Given the Extended Pascal program
      """
      program p(output);
      begin
        writeln('[', 2.5:4:0, ']')
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      [  3.]
      """

  Scenario: the floating-point form rounds the same way
    Given the Extended Pascal program
      """
      program p(output);
      begin
        writeln(1.25:8)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
       1.3E+00
      """
