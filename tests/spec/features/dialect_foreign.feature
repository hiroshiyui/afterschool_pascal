# AP 6.7.7 -- external-declarations. The clause ISO/IEC 10206:1991 6.1.4's NOTE
# anticipates by name, and the one place this dialect departs from advice that
# NOTE gives: it recommends enforcing type compatibility across the boundary,
# and AP Annex C.1 records that this processor cannot.
@afterschool:6.7.7.1
Feature: Foreign functions

  @afterschool:6.7.7.3
  Scenario: a foreign function is called through the name it was given
    Given the Afterschool Pascal program
      """
      program p(output);
      function labs(x: integer): integer; external 'abs';
      begin writeln(labs(-3)) end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      3
      """

  @afterschool:6.7.7.4
  Scenario: the admitted types are exact, so a subrange does not answer for its host
    Given the Afterschool Pascal program
      """
      program p(output);
      type small = 1..9;
      function f(x: small): integer; external 'abs';
      begin writeln(f(3)) end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      only 'integer', 'int64', 'real' and 'string' cross the boundary
      """

  @afterschool:6.7.7.5
  Scenario: a NUL inside a string crossing the boundary stops the program
    Given the Afterschool Pascal program
      """
      program p(output);
      function pstrlen(s: string): integer; external 'strlen';
      var v: string(8);
      begin v := 'ab'; v[2] := chr(0); writeln(pstrlen(v)) end.
      """
    When it is compiled and run
    Then it stops at run time
     And the run-time error includes
      """
      contains a NUL character
      """

  @afterschool:6.7.7.5
  Scenario: the string formal carries no capacity
    Given the Afterschool Pascal program
      """
      program p(output);
      function f(s: string(20)): integer; external 'strlen';
      begin end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      the formal is spelled 'string' and the size is the actual's
      """

  @afterschool:6.7.7.6
  Scenario: a var parameter crosses as the address of the actual
    Given the Afterschool Pascal program
      """
      program p(output);
      function frexp(x: real; var e: integer): real; external 'frexp';
      var e: integer; m: real;
      begin m := frexp(8.0, e); writeln(m:4:2, ' ', e) end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      0.50 4
      """

  @afterschool:6.7.7.8
  Scenario: a bare string result is refused and the diagnostic names the remedy
    Given the Afterschool Pascal program
      """
      program p(output);
      type T = string(64);
      function getenv(n: string): T; external 'getenv';
      begin end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      write '?' before the type
      """

  @afterschool:6.7.7.10
  Scenario: a foreign name the compiler emits for itself is refused
    Given the Afterschool Pascal program
      """
      program p(output);
      function m: integer; external 'main';
      begin writeln(m) end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      is one this compiler emits for something of its own
      """

  @afterschool:6.7.7.11
  Scenario: one linker symbol is named by one external declaration
    Given the Afterschool Pascal program
      """
      program p(output);
      function a1(x: integer): integer; external 'abs';
      function a2(x: integer): integer; external 'abs';
      begin writeln(a1(-1), a2(-2)) end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      one linker symbol may be named by one 'external' declaration
      """

  @afterschool:6.7.7.11
  Scenario: a foreign name is a character-string and is not case-folded
    Given the Afterschool Pascal program
      """
      program p(output);
      function lower(x: integer): integer; external 'abs';
      function upper(x: integer): integer; external 'ABS';
      begin writeln(lower(-7):1) end.
      """
    When it is compiled and run
    Then it prints
      """
      7
      """

  @afterschool:5.3
  Scenario: the directive is refused under a conformance mode, naming the mode that has it
    Given the Extended Pascal program
      """
      program p(output);
      function cbrt(x: real): real; external 'cbrt';
      begin end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      compile with --std=afterschool
      """

  @afterschool:6.7.7.2
  Scenario: the foreign name is required and is never derived from the identifier
    Given the Afterschool Pascal program
      """
      program p(output);
      function cbrt(x: real): real; external;
      begin end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      expected the foreign name, as a string literal, after 'external'
      """

  @afterschool:6.7.7.7
  Scenario: a slice crosses as the address and the count, from one formal
    Given the Afterschool Pascal program
      """
      program p(output);
      function PosixWrite(fd: integer; var b: array of char): int64;
        external 'write';
      var buf: array [1..3] of char; n: int64;
      begin
        buf[1] := 'h'; buf[2] := 'i'; buf[3] := chr(10);
        n := PosixWrite(1, buf)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      hi
      """

  @afterschool:6.7.7.9
  Scenario: a procedural parameter does not cross, the static link having no image
    Given the Afterschool Pascal program
      """
      program p(output);
      function qsortlike(procedure cmp): integer; external 'abs';
      begin end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      cannot be a procedure or a function
      """
