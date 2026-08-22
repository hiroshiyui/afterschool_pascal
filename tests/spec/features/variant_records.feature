# ISO 7185 §6.4.3.3 -- a variant part's labels against its tag-type.
#
# The rule that surprises: the case-constants of a variant part are *exactly*
# the values of the tag-type, so `case tag: integer of 1: ...; 2: ...` is
# refused -- integer has other values and they would select no arm. It looks
# over-strict, which is why it was audited; the BSI suite settles it, DEV073
# having been reclassified from CONFORMANCE to DEVIANCE by DP7185.
#
# The conforming spellings are a tag-type that the labels cover exactly, or
# Extended Pascal's variant-part-completer.

@iso7185:6.4.3.3
Feature: Record-types

  Scenario: a tag-type whose values the labels cover exactly is accepted
    Given the ISO 7185 program
      """
      program p(output);
      type
        selector = 1 .. 2;
        shape = record
                  case tag: selector of
                    1: (side: integer);
                    2: (w, h: integer)
                end;
      var s: shape;
      begin
        s.tag := 1;
        s.side := 4;
        writeln(s.side : 1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      4
      """

  Scenario: a tag-type with values no label selects is refused
    Given the ISO 7185 program
      """
      program p(output);
      type shape = record
                     case tag: integer of
                       1: (side: integer);
                       2: (w, h: integer)
                   end;
      var s: shape;
      begin
        s.tag := 1;
        writeln('compiled')
      end.
      """
    When it is compiled
    Then it is rejected

  Scenario: a label outside the tag-type is refused
    Given the ISO 7185 program
      """
      program p(output);
      type
        selector = 1 .. 2;
        shape = record
                  case tag: selector of
                    1: (side: integer);
                    2: (w, h: integer);
                    3: (extra: integer)
                end;
      var s: shape;
      begin
        s.tag := 1;
        writeln('compiled')
      end.
      """
    When it is compiled
    Then it is rejected

  Scenario: the same value may not label two arms
    Given the ISO 7185 program
      """
      program p(output);
      type
        selector = 1 .. 2;
        shape = record
                  case tag: selector of
                    1: (side: integer);
                    1: (w: integer);
                    2: (h: integer)
                end;
      var s: shape;
      begin
        s.tag := 1;
        writeln('compiled')
      end.
      """
    When it is compiled
    Then it is rejected

@extended:6.4.3.4
Feature: Variant-parts under Extended Pascal

  Scenario: an otherwise-part discharges coverage
    Given the Extended Pascal program
      """
      program p(output);
      type shape = record
                     case tag: integer of
                       1:        (side: integer);
                       otherwise (other: integer)
                   end;
      var s: shape;
      begin
        s.tag := 7;
        s.other := 5;
        writeln(s.other : 1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      5
      """

  # "A variant-denoter shall not contain a type-denoter denoting either a
  # restricted-type or the bindability that is bindable or denoting a
  # structured-type having any component whose type-denoter is not permissible
  # as a type-denoter contained by a variant-denoter."
  #
  # Not an error and not a dynamic-violation: Annex D's D.3 for this clause is
  # the discriminant-selector rule and names nothing here, so clause 5.1 e)
  # obliges the processor to report it and refuse the activation.
  #
  # ISO 7185's counterpart clause is 6.4.3.3 and carries no such sentence, so
  # there is nothing to cite on that side -- and neither word-symbol exists
  # there in any case.

  Scenario: a restricted-type may not be a field of a variant part
    Given the Extended Pascal program
      """
      program p(output);
      type r = restricted integer;
           v = record
                 case boolean of
                   true:  (a: r);
                   false: (b: integer)
               end;
      var x: v;
      begin
        x.b := 1;
        writeln(x.b : 1)
      end.
      """
    When it is compiled
    Then it is rejected

  Scenario: the restriction reaches through a structured component
    Given the Extended Pascal program
      """
      program p(output);
      type r = restricted integer;
           h = record f: r end;
           v = record
                 case boolean of
                   true:  (a: h);
                   false: (b: integer)
               end;
      var x: v;
      begin
        x.b := 1;
        writeln(x.b : 1)
      end.
      """
    When it is compiled
    Then it is rejected

  Scenario: a bindable type-denoter may not be a field of a variant part
    Given the Extended Pascal program
      """
      program p(output);
      type v = record
                 case boolean of
                   true:  (a: bindable integer);
                   false: (b: integer)
               end;
      var x: v;
      begin
        x.b := 1;
        writeln(x.b : 1)
      end.
      """
    When it is compiled
    Then it is rejected

  Scenario: the restriction is on the variant-denoter and not on a fixed part
    Given the Extended Pascal program
      """
      program p(output);
      type r = restricted integer;
           v = record a: r; b: bindable integer end;
      var x: v; u: integer;
      begin
        x.a := 7;
        u := x.a;
        writeln(u : 1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      7
      """
