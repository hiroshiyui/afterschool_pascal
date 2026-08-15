# ISO/IEC 10206:1991 §6.4.7 and §6.4.8 -- a schema, and the type a discriminated
# schema produces.
#
# §6.4.8 makes the identity rule the whole feature: one schema with one tuple is
# one type, however often it is written, and two tuples are two types. Both
# halves matter, and a scenario for only the first would be satisfied by an
# implementation that produced a fresh type every time.
#
# §6.4.6 d) makes a tuple mismatch a dynamic-violation, and §6.1 f) lets a
# processor report one either at preparation time or during execution -- so
# refusing `vector(3) := vector(4)` at compile time is conforming, and this
# suite asserts the refusal rather than when it happens.

@extended:6.4.7 @extended:6.4.8
Feature: Discriminated-schemata

  Scenario: one schema with one tuple is one type
    Given the Extended Pascal program
      """
      program p(output);
      type vector(len: integer) = array [1 .. len] of integer;
      var a: vector(3);
          b: vector(3);
      begin
        a[1] := 7;
        b := a;
        writeln(b[1] : 1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      7
      """

  Scenario: two tuples are two types
    Given the Extended Pascal program
      """
      program p(output);
      type vector(len: integer) = array [1 .. len] of integer;
      var a: vector(3);
          b: vector(4);
      begin
        a[1] := 7;
        b := a;
        writeln(b[1] : 1)
      end.
      """
    When it is compiled
    Then it is rejected

  Scenario: a discriminant is readable as a field of the variable
    Given the Extended Pascal program
      """
      program p(output);
      type vector(len: integer) = array [1 .. len] of integer;
      var a: vector(5);
      begin
        writeln(a.len : 1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      5
      """

  Scenario: one body serves every tuple through a schematic formal parameter
    Given the Extended Pascal program
      """
      program p(output);
      type vector(len: integer) = array [1 .. len] of integer;
      var a: vector(3);
          b: vector(5);

      procedure fill(var v: vector; with_: integer);
      var i: integer;
      begin
        for i := 1 to v.len do v[i] := with_
      end;

      begin
        fill(a, 1);
        fill(b, 2);
        writeln(a.len : 1, ' ', b.len : 1, ' ', a[3] : 1, ' ', b[5] : 1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      3 5 1 2
      """

  Scenario: an index outside the produced type's bounds is an error
    Given the Extended Pascal program
      """
      program p(output);
      type vector(len: integer) = array [1 .. len] of integer;
      var a: vector(3); i: integer;
      begin
        i := 4;
        a[i] := 1;
        writeln('compiled and ran')
      end.
      """
    When it is compiled and run
    Then it stops at run time

  Scenario: a schema is not available under ISO 7185
    Given the ISO 7185 program
      """
      program p(output);
      type vector(len: integer) = array [1 .. len] of integer;
      var a: vector(3);
      begin
        a[1] := 1;
        writeln(a[1] : 1)
      end.
      """
    When it is compiled
    Then it is rejected
