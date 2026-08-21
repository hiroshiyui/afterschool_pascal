# ISO 7185 §6.2.2 and §6.2.3 -- scopes and activations.
#
# These are the most-cited clauses in this repository -- §6.2.2.9 alone is named
# 56 times -- and until ADR-0152 not one of them could be cited here at all.
# Every sub-clause of §6.2.2 and §6.2.3 in both standards is a bare number on a
# line of its own with the requirement under it, and the extractor that builds
# the clause inventory read only lines that carried a *title*. So 37 real
# clauses were absent from the inventory, absent from the triage, and absent
# from the work queue, and `spec-clause-traceability` answered "not a clause of
# that standard" about them.
#
# Each scenario below states a rule this compiler already implements and that an
# ADR already argued -- ADR-0097, ADR-0100, ADR-0101 -- as the clause states it
# rather than as the implementation happens to work.
#
# The §6.2.2.9 refusal is written inside one constant-definition-part on
# purpose. Writing it as a procedure that uses a constant declared after it is
# rejected too, and for the wrong reason: ISO 7185 fixes the order of the
# declaration parts, so that program fails the grammar before it reaches this
# clause. The diagnostic is asserted for the same reason.

@iso7185:6.2.2
Feature: Scopes and activations

  @iso7185:6.2.2.5
  Scenario: an inner declaration excludes the outer one from its own region
    Given the ISO 7185 program
      """
      program p(output);
      var x: integer;

      procedure inner;
      var x: integer;
      begin
        x := 2;
        writeln(x : 1)
      end;

      begin
        x := 1;
        inner;
        writeln(x : 1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      2
      1
      """

  @iso7185:6.2.2.9
  Scenario: a defining-point precedes every applied occurrence of its identifier
    Given the ISO 7185 program
      """
      program p(output);
      const a = b;
            b = 7;
      begin
        writeln(a : 1)
      end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      undeclared identifier 'b'
      """

  @iso7185:6.2.2.9
  Scenario: the one exception is a pointer domain in the same type-definition-part
    Given the ISO 7185 program
      """
      program p(output);
      type
        link = ^node;
        node = record value: integer; next: link end;
      var head: link;
      begin
        new(head);
        head^.value := 4;
        head^.next := nil;
        writeln(head^.value : 1);
        dispose(head)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      4
      """

  @iso7185:6.2.2.10
  Scenario: a required identifier is declared in a region enclosing the program, so a program may redeclare it
    Given the ISO 7185 program
      """
      program p(output);
      const maxint = 5;
      begin
        writeln(maxint : 1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      5
      """

  @iso7185:6.2.2.11
  Scenario: what an identifier denotes at its defining-point it denotes at every applied occurrence
    Given the ISO 7185 program
      """
      program p(output);
      var ord: array [1..3] of integer;
      begin
        ord[1] := 9;
        writeln(ord('a') : 1)
      end.
      """
    When it is compiled
    Then it is rejected

  @iso7185:6.2.3.5
  Scenario: each activation contains its own variables
    Given the ISO 7185 program
      """
      program p(output);

      procedure down(n: integer);
      var mine: integer;
      begin
        mine := n;
        if n > 0 then
          down(n - 1);
        writeln(mine : 1)
      end;

      begin
        down(3)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      0
      1
      2
      3
      """
