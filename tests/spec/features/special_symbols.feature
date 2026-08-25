# §6.1.2 -- the special-symbols.
#
# The clause was filed `testable` with its own title as the reason, which is
# not an argument, and the triage audit that swept the other direction found it
# among the six testable rows whose prose never says `shall` (ADR-0204). It
# survived that sweep on the same ground the earlier audit kept §6.7.2.1 and
# §6.8.3.1 on: the clause is not a container, it carries the **production**,
# and that production is where several tokens are given as tokens and appear
# nowhere else. A clause that carries the token list can be cited by a program
# that uses the tokens.
#
# The word-symbols are a production of this clause too, and they are exercised
# by every other scenario in this suite; what these two pin is the punctuation.
Feature: Special symbols

  @iso7185:6.1.2
  Scenario: every special-symbol of ISO 7185 in one program
    Given the ISO 7185 program
      """
      program p(output);
      type r = record f: integer end;
      var a: array [1..3] of integer;
          s: set of 1..9;
          v: r;
          q: ^r;
          i: integer;
      begin
        a[1] := 1; a[2] := 2; a[3] := 3;
        v.f := a[1] + a[2] * a[3] - 1;
        s := [1..3];
        new(q); q^.f := v.f;
        i := 7 div 2;
        writeln((q^.f = 6) and (v.f <> 7) and (i <= 3) and (i >= 3),
                ' ', 6.0 / 3.0 : 3 : 1, ' ', 2 in s);
        dispose(q)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      TRUE 2.0 TRUE
      """

  # The two ISO/IEC 10206:1991 adds that a program can reach in one
  # translation unit. `=>` is the third and it is the renaming clause of an
  # export- or import-list (§6.11.2), which needs a second program-component --
  # something this harness cannot ask for, and the gap doc/sop.md §7 records
  # for 6.11 and 6.13.1.
  @extended:6.1.2
  Scenario: the exponentiating and symmetric-difference symbols
    Given the Extended Pascal program
      """
      program p(output);
      var s: set of 1..9;
      begin
        s := [1, 2] >< [2, 3];
        writeln(2 ** 3 : 3 : 1, ' ', 1 in s, ' ', 2 in s, ' ', 3 in s)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      8.0 TRUE FALSE TRUE
      """
