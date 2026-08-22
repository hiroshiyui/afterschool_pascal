# ISO/IEC 10206:1991 §6.4.1 -- an initial-state-specifier attaches to the
# *type-denoter*, and the production offers it after any of four bases:
#
#   type-denoter = [ 'bindable' ] ( type-name | new-type | type-inquiry
#                                   | discriminated-schema )
#                    [ initial-state-specifier ] .
#
# "If an initial-state-specifier occurs in a type-denoter, the type-denoter
# shall denote the initial state that is denoted by the initial-state-specifier"
# -- with no exception for which of the four bases it followed. §6.2.3.5 then
# creates each variable of the denoter in that state.
#
# The discriminated-schema is the base worth a scenario: a schema variable is
# resolved by a path of its own, because §6.2.3.2 lets its discriminants be
# variables, and that path is the one that can forget to ask for the state.
# Forgetting is not a diagnostic -- it leaves the variable totally-undefined and
# the program reads it.

@extended:6.4.1 @extended:6.2.3.5
Feature: An initial-state-specifier after a discriminated-schema

  Scenario: a global declared with an inline schema is created in its initial state
    Given the Extended Pascal program
      """
      program p(output);
      var t: string(4) value 'jk';
      begin
        writeln('[', t, ']', length(t):1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      [jk]2
      """

  Scenario: a local declared with an inline schema is created in its initial state
    Given the Extended Pascal program
      """
      program p(output);
      procedure q;
      var t: string(4) value 'jk';
      begin
        writeln('[', t, ']', length(t):1)
      end;
      begin
        q
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      [jk]2
      """

  Scenario: one denoter is one initial state, so a group of names shares it
    Given the Extended Pascal program
      """
      program p(output);
      var a, b: string(6) value 'shared';
      begin
        writeln(a, ' ', b)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      shared shared
      """

  Scenario: the value is still required to be assignment-compatible
    Given the Extended Pascal program
      """
      program p(output);
      var t: string(4) value 7;
      begin
        writeln(t)
      end.
      """
    When it is compiled
    Then it is rejected
