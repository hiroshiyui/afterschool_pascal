# AP 6.4.12 -- the handle-type: a foreign address this program owns, released
# by the routine the type names when the variable dies. The release is observed
# rather than assumed: fputs is buffered until fclose, so reading a file back
# says whether the closer ran.
@afterschool:6.4.12.1
Feature: Handle-types

  Scenario: a handle is empty at activation and after a null answer, and compares only with nil
    Given the Afterschool Pascal program
      """
      program p(output);
      type f = handle external 'fclose';
      function fo(path, mode: string): f; external 'fopen';
      var h: f;
      begin
        writeln(h = nil);
        h := fo('/nonexistent-apascal-dir/x', 'r');
        writeln(h = nil, ' ', h <> nil)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      TRUE
      TRUE FALSE
      """

  @afterschool:6.4.12.2
  Scenario: the one assignment releases what the variable held
    Given the Afterschool Pascal program
      """
      program p(output);
      type f = handle external 'fclose';
      function fo(path, mode: string): f; external 'fopen';
      function fp(s: string; h: f): integer; external 'fputs';
      var h: f; t: bindable text; b: BindingType; s: string(40); k: integer;
      begin
        h := fo('spec_handle.tmp', 'w');
        k := fp('first', h);
        h := fo('spec_handle_2.tmp', 'w');
        b := binding(t); b.name := 'spec_handle.tmp'; bind(t, b);
        reset(t); readln(t, s); writeln('[', s, ']')
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      [first]
      """

  @afterschool:6.4.12.3
  Scenario: the value is released when the block exits
    Given the Afterschool Pascal program
      """
      program p(output);
      type f = handle external 'fclose';
      function fo(path, mode: string): f; external 'fopen';
      function fp(s: string; h: f): integer; external 'fputs';
      var t: bindable text; b: BindingType; s: string(40);
      procedure w;
      var h: f; k: integer;
      begin h := fo('spec_handle_3.tmp', 'w'); k := fp('closed at exit', h) end;
      begin
        w;
        b := binding(t); b.name := 'spec_handle_3.tmp'; bind(t, b);
        reset(t); readln(t, s); writeln('[', s, ']')
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      [closed at exit]
      """

  @afterschool:6.4.12.4
  Scenario: an empty handle lent to a foreign routine is an error
    Given the Afterschool Pascal program
      """
      program p(output);
      type f = handle external 'fclose';
      function fg(h: f): integer; external 'fgetc';
      var h: f;
      begin writeln(fg(h)) end.
      """
    When it is compiled and run
    Then it stops at run time
     And the run-time error includes
      """
      the handle is empty
      """

  @afterschool:6.4.12.2
  Scenario: a handle has no copy
    Given the Afterschool Pascal program
      """
      program p(output);
      type f = handle external 'fclose';
      var a, b: f;
      begin a := b end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      a handle may be assigned only the result of an 'external' function
      """

  # 6.4.12.2's second form (ADR-0202). `nil` is not a value of the type -- it is
  # the empty state, which the same clause already admits on the right of `=` --
  # so what this assignment gives a program is the release, before the
  # variable's own lifetime ends. Two library modules closed a stream by opening
  # a path they knew would fail until it existed.
  @afterschool:6.4.12.2
  Scenario: a handle is released by assigning nil, and is empty afterwards
    Given the Afterschool Pascal program
      """
      program p(output);
      type f = handle external 'fclose';
      function fopen(path, mode: string): f; external 'fopen';
      var a: f;
      begin
        a := fopen('/dev/null', 'r');
        writeln(a <> nil);
        a := nil;
        writeln(a = nil)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      TRUE
      TRUE
      """

  # And it is the *empty state* and not a value, so nothing else may be assigned
  # -- the refusal above is unchanged, and a pointer is not admitted either.
  @afterschool:6.4.12.2
  Scenario: a handle takes nil and no other pointer value
    Given the Afterschool Pascal program
      """
      program p(output);
      type f = handle external 'fclose';
      var a: f; q: ^integer;
      begin q := nil; a := q end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      a handle may be assigned only the result of an 'external' function
      """
