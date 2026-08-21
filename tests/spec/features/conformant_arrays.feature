# ISO 7185 §6.6.3.7 and §6.6.3.8 -- the conformant array parameter, which is
# the whole of what separates a level 1 processor from a level 0 one. Clause
# 5.1 a) makes §6.6.3.6 e), §6.6.3.7 and §6.6.3.8 the entire difference between
# the two levels, so these scenarios are the level claim itself rather than an
# ordinary feature.
#
# They exist because a clause triage audit found all five of §6.6.3.7's and
# §6.6.3.8's rows -- and their five Extended Pascal counterparts at §6.7.3.x --
# still filed `not-implemented, this processor is level 0`, citing a document
# whose first line says level 1. The clauses were outside the coverage
# denominator and off the work queue, and a scenario citing one *failed* the
# traceability gate, so the author who wrote what should have been here was
# punished for it. Nothing about the compiler was wrong; the machinery between
# the standard and the gate was.
#
# What each scenario states is the requirement, not the lowering: one compiled
# body serves every extent, the bound identifiers denote the actual's own
# bounds, and the abbreviated multi-index form means what the nested one means.

@iso7185:6.6.3.7 @iso7185:6.6.3.7.1
Feature: Conformant array parameters

  Scenario: one body serves actuals of different extents
    Given the ISO 7185 program
      """
      program p(output);
      var a: array [1..3] of integer;
          b: array [1..5] of integer;
          i: integer;
      function total(var v: array [u..w: integer] of integer): integer;
      var k, s: integer;
      begin
        s := 0;
        for k := u to w do s := s + v[k];
        total := s
      end;
      begin
        for i := 1 to 3 do a[i] := i;
        for i := 1 to 5 do b[i] := i;
        writeln(total(a):1, ' ', total(b):1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      6 15
      """

  @iso7185:6.6.3.7.3
  Scenario: the bound identifiers denote the actual parameter's own bounds
    Given the ISO 7185 program
      """
      program p(output);
      var a: array [4..9] of char;
          i: integer;
      procedure show(var v: array [u..w: integer] of char);
      begin
        writeln(u:1, ' ', w:1)
      end;
      begin
        for i := 4 to 9 do a[i] := 'x';
        show(a)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      4 9
      """

  @iso7185:6.6.3.7.2
  Scenario: a value conformant array is the callee's own copy
    Given the ISO 7185 program
      """
      program p(output);
      var a: array [1..3] of integer;
          i: integer;
      procedure clobber(v: array [u..w: integer] of integer);
      var k: integer;
      begin
        for k := u to w do v[k] := 0
      end;
      begin
        for i := 1 to 3 do a[i] := i;
        clobber(a);
        writeln(a[1]:1, a[2]:1, a[3]:1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      123
      """

  Scenario: the abbreviated multi-index form means what the nested form means
    Given the ISO 7185 program
      """
      program p(output);
      var m: array [1..2, 1..3] of integer;
          i, j: integer;
      function sum2(var v: array [a..b: integer; c..d: integer] of integer)
               : integer;
      var r, k, s: integer;
      begin
        s := 0;
        for r := a to b do
          for k := c to d do s := s + v[r, k];
        sum2 := s
      end;
      begin
        for i := 1 to 2 do
          for j := 1 to 3 do m[i, j] := i * j;
        writeln(sum2(m):1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      18
      """

  @iso7185:6.6.3.8
  Scenario: an actual whose index-type is not conformable is rejected
    Given the ISO 7185 program
      """
      program p(output);
      var a: array ['a'..'e'] of integer;
      procedure take(var v: array [u..w: integer] of integer);
      begin
      end;
      begin
        take(a)
      end.
      """
    When it is compiled
    Then it is rejected
