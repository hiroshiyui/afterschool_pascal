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

  @afterschool:6.7.7.6.2
  Scenario: a record of admitted fields crosses as the address of the actual
    Given the Afterschool Pascal program
      """
      program p(output);
      type TS = record sec, nsec: int64 end;
      function tsget(var t: TS; base: integer): integer; external 'timespec_get';
      var t: TS;
      begin
        t.sec := -1; t.nsec := -1;
        writeln(tsget(t, 1) = 1, ' ', t.sec > 1700000000,
                ' ', (t.nsec >= 0) and (t.nsec < 1000000000))
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      TRUE TRUE TRUE
      """

  @afterschool:6.7.7.6.2
  Scenario: a field whose values a callee could step outside of is refused
    Given the Afterschool Pascal program
      """
      program p(output);
      type R = record ok: boolean end;
      procedure f(var r: R); external 'ext_f';
      begin end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      its field 'ok' is boolean
      """

  @afterschool:6.7.7.6.2
  Scenario: the refused field a nested record holds is the one named
    Given the Afterschool Pascal program
      """
      program p(output);
      type Inner = record n: 1..9 end;
           Outer = record head: integer; body: Inner end;
      procedure f(var r: Outer); external 'ext_f';
      begin end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      its field 'n' is
      """

  @afterschool:6.7.7.6.2
  Scenario: a variant part is refused
    Given the Afterschool Pascal program
      """
      program p(output);
      type Sel = 1..2;
           R = record case tag: Sel of 1: (a: integer); 2: (b: real) end;
      procedure f(var r: R); external 'ext_f';
      begin end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      a record that crosses has a fixed field-list
      """

  @afterschool:6.7.7.6.3
  Scenario: a record by value is refused and the diagnostic names the remedy
    Given the Afterschool Pascal program
      """
      program p(output);
      type R = record a, b: integer end;
      procedure f(r: R); external 'ext_f';
      begin end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      a record crosses as a 'var' parameter
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

  @afterschool:6.7.7.8
  Scenario: a record result crosses as an optional, and the diagnostic says so
    Given the Afterschool Pascal program
      """
      program p(output);
      type R = record a, b: integer end;
      function f: R; external 'ext_f';
      begin end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      write '?' before the record and the value is copied at the call
      """

  @afterschool:6.7.7.8
  Scenario: an optional of a record is copied where the call occurs
    Given the Afterschool Pascal program
      """
      program p(output);
      type Tm = record
             sec, min, hour, mday, mon, year, wday, yday, isdst: integer
           end;
           OptTm = ?Tm;
      function GmTime(var t: int64): OptTm; external 'gmtime';
      var when: int64; a, b: OptTm;
      begin
        when := 0;
        a := GmTime(when);
        when := 1000000000;
        b := GmTime(when);
        writeln(a^.year + 1900:1, ' ', b^.year + 1900:1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      1970 2001
      """

  @afterschool:6.7.7.8
  Scenario: the copy leaves the callee's storage behind, so a later call does not move it
    Given the Afterschool Pascal program
      """
      program p(output);
      type Tm = record
             sec, min, hour, mday, mon, year, wday, yday, isdst: integer
           end;
           OptTm = ?Tm;
      function GmTime(var t: int64): OptTm; external 'gmtime';
      var when: int64; held, other: OptTm;
      begin
        when := 0;
        held := GmTime(when);
        when := 1000000000;
        other := GmTime(when);
        writeln(held^.year + 1900:1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      1970
      """

  @afterschool:6.7.7.8
  Scenario: a field a C compiler would not lay out is refused in the result position too
    Given the Afterschool Pascal program
      """
      program p(output);
      type R = record ok: boolean end;
           OptR = ?R;
      function f: OptR; external 'ext_f';
      begin end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      is an optional of a record, but its field 'ok' is boolean
      """

  @afterschool:6.7.7.8
  Scenario: and a variant part is refused, an arm's storage being this compiler's own
    Given the Afterschool Pascal program
      """
      program p(output);
      type sel = 1..2;
           R = record head: integer; case tag: sel of 1: (a: integer); 2: (b: real) end;
           OptR = ?R;
      function f: OptR; external 'ext_f';
      begin end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      is an optional of a record with a variant part
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

  # AP 6.4.2.7 (ADR-0328). C's `long` and `size_t` are the target's width where
  # this language's two integer types are fixed, so a foreign declaration had
  # no way to name them: `strlen` declared `int64` answered 21474836485 on a
  # 32-bit target, whose low half is the length and whose high half is whatever
  # a register held.
  @afterschool:6.4.2.7.1
  Scenario: a C size_t crosses as csize
    Given the Afterschool Pascal program
      """
      program p(output);
      function strlen(s: string): csize; external 'strlen';
      var n: int64;
      begin n := strlen('hello'); writeln(trunc(n):1) end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      5
      """

  # They are required identifiers in the region enclosing the program, so
  # §6.1.3 lets any program take either spelling for its own -- `int64`'s route
  # exactly (ADR-0128).
  @afterschool:6.4.2.7.1
  Scenario: a program may declare its own clong
    Given the Afterschool Pascal program
      """
      program p(output);
      type clong = 1..10;
      var v: clong;
      begin v := 7; writeln(v:1) end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      7
      """

  # AP 6.4.2.7.2. The narrowing is two steps because `trunc` of an `integer` is
  # refused -- §6.7.6.3 requires a real, and tests/trunc_integer.pas pins that
  # from the validation suite's DEV158. Widening first is what makes one
  # spelling serve both targets.
  @afterschool:6.4.2.7.2
  Scenario: trunc of a csize directly is refused where csize is integer
    Given the Afterschool Pascal program
      """
      program p(output);
      var i: integer;
      begin i := 3; writeln(trunc(i):1) end.
      """
    When it is compiled
    Then it is rejected
