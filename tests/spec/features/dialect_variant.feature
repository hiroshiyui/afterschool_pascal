# AP 6.4.3.4 -- the dialect detects the error ISO/IEC 10206:1991 6.5.3.3 makes
# it, and which both conformance modes conformingly leave undetected. The pair
# 6.4.3.4.1/6.4.3.4.2 is written as a pair: activating without checking, or
# checking without activating, each satisfies one half and neither is correct.
@afterschool:6.4.3.4.1
Feature: A variant tag that cannot lie

  Scenario: assigning to a field of a variant makes that variant active
    Given the Afterschool Pascal program
      """
      program p(output);
      type k = (ok, bad);
           r = record case tag: k of
                 ok:  (num: integer);
                 bad: (msg: string(8))
               end;
      var v: r;
      begin v.num := 42; writeln(ord(v.tag), ' ', v.num) end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      0 42
      """

  @afterschool:6.4.3.4.2
  Scenario: reading a field of an inactive variant stops the program
    Given the Afterschool Pascal program
      """
      program p(output);
      type k = (ok, bad);
           r = record case tag: k of
                 ok:  (num: integer);
                 bad: (msg: string(8))
               end;
      var v: r;
      begin v.num := 42; v.msg := 'no'; writeln(v.num) end.
      """
    When it is compiled and run
    Then it stops at run time
     And the run-time error includes
      """
      the tag selects another arm
      """

  @afterschool:6.4.3.4.3
  Scenario: an assignment sets every tag on the path to the field
    Given the Afterschool Pascal program
      """
      program p(output);
      type k = (one, two); j = (xx, yy);
           r = record case t1: k of
                 one: (a: integer);
                 two: (case t2: j of xx: (b: integer); yy: (c: char))
               end;
      var v: r;
      begin v.b := 7; writeln(ord(v.t1), ord(v.t2), ' ', v.b) end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      10 7
      """

  @afterschool:6.4.3.4.4
  Scenario: a variant with two labels is checked rather than activated
    Given the Afterschool Pascal program
      """
      program p(output);
      type k = (aa, bb, cc);
           r = record case tag: k of
                 aa, bb: (i: integer);
                 cc:     (c: char)
               end;
      var v: r;
      begin v.tag := cc; v.i := 1; writeln(v.i) end.
      """
    When it is compiled and run
    Then it stops at run time
     And the run-time error includes
      """
      the tag selects another arm
      """

  @afterschool:6.4.3.4.6
  Scenario: assigning the tag directly still selects the active variant
    Given the Afterschool Pascal program
      """
      program p(output);
      type k = (ok, bad);
           r = record case tag: k of
                 ok:  (num: integer);
                 bad: (msg: string(8))
               end;
      var v: r;
      begin v.tag := ok; v.num := 1; writeln(v.num) end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      1
      """

  @afterschool:5.3
  Scenario: the conformance modes leave the same error undetected
    Given the Extended Pascal program
      """
      program p(output);
      type k = (ok, bad);
           r = record case tag: k of
                 ok:  (num: integer);
                 bad: (msg: string(8))
               end;
      var v: r;
      begin v.num := 42; v.msg := 'no'; writeln(ord(v.tag)) end.
      """
    When it is compiled and run
    Then it exits successfully

  @afterschool:6.4.3.4.5
  Scenario: a variant part with no tag field is left unchecked, and that is the hole
    Given the Afterschool Pascal program
      """
      program p(output);
      type k = (ok, bad);
           r = record case k of
                 ok:  (num: integer);
                 bad: (c: char)
               end;
      var v: r;
      begin v.num := 65; writeln(v.c) end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      A
      """

  # AP 6.4.3.4's own opening carries a claim about the CONFORMANCE modes -- that
  # both leave §6.5.3.3's error undetected, conformingly -- and no subclause
  # repeats it. That sentence is what makes the dialect's detection an addition
  # rather than a correction, and it is exercisable by a program, which is why
  # the clause was re-triaged from `structural` to `testable` (ADR-0144).
  @afterschool:6.4.3.4
  Scenario: the conformance modes leave an inactive-variant read undetected
    Given the Extended Pascal program
      """
      program p(output);
      type Sel = (si, sr);
           Rec = record case k: Sel of si: (i: integer); sr: (r: real) end;
      var v: Rec;
      begin v.k := si; v.i := 7; writeln('no trap') end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      no trap
      """

  @afterschool:6.4.3.4
  Scenario: and the dialect detects it
    Given the Afterschool Pascal program
      """
      program p(output);
      type Sel = (si, sr);
           Rec = record case k: Sel of si: (i: integer); sr: (r: real) end;
      var v: Rec;
      begin v.k := si; v.i := 7; writeln(v.r) end.
      """
    When it is compiled and run
    Then it stops at run time
     And the run-time error includes
      """
      variant: the tag selects another arm
      """
