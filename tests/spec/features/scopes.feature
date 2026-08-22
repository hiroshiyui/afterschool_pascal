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

  @iso7185:6.2.2.1
  Scenario: every identifier the program-block contains has a defining-point
    Given the ISO 7185 program
      """
      program p(output);
      begin
        writeln(undeclared : 1)
      end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      undeclared identifier 'undeclared'
      """

  @iso7185:6.2.2.4
  Scenario: a scope is its region and every region that region encloses
    Given the ISO 7185 program
      """
      program p(output);
      var outer: integer;

      procedure middle;

        procedure inner;
        begin
          outer := outer + 1
        end;

      begin
        inner;
        inner
      end;

      begin
        outer := 1;
        middle;
        writeln(outer : 1)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      3
      """

  @iso7185:6.2.2.6
  Scenario: a field-specifier is excluded from the enclosing scopes
    Given the ISO 7185 program
      """
      program p(output);
      type holder = record thing: char end;
      var thing: integer;
          r: holder;
      begin
        thing := 7;
        r.thing := 'z';
        writeln(thing : 1, ' ', r.thing)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      7 z
      """

  @iso7185:6.2.2.7
  Scenario: one spelling has one defining-point for one region
    Given the ISO 7185 program
      """
      program p(output);
      var twice: integer;
          twice: char;
      begin
        twice := 1
      end.
      """
    When it is compiled
    Then it is rejected

  @iso7185:6.2.2.8
  Scenario: no occurrence outside a scope is an applied occurrence of it
    Given the ISO 7185 program
      """
      program p(output);

      procedure keeps;
      var hidden: integer;
      begin
        hidden := 1
      end;

      begin
        keeps;
        writeln(hidden : 1)
      end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      undeclared identifier 'hidden'
      """

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

  # §6.2.2.7 is the rule that a spelling has one defining-point per region, and
  # the formal-parameter-list is a region two separate clauses put a
  # defining-point into: §6.7.3.1 makes a parameter a parameter-identifier for
  # it, and §6.7.2 makes a result-variable-specification's identifier a
  # function-result-identifier for it. Nothing here had ever asked what happens
  # when they collide, and the answer was that the program was accepted and
  # quietly meant something else -- the result variable won inside the block, so
  # the body's assignment wrote the result and the parameter became unreadable.
  #
  # Not an Annex D error, so §5.1 e) is what requires the refusal.
  @extended:6.2.2.7
  Scenario: a result variable may not be spelled like a parameter
    Given the Extended Pascal program
      """
      program p(output);
      function f(n: integer) = n: integer;
      begin n := -1 end;
      begin writeln(f(10) : 1) end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      already a parameter of it
      """

  # §6.7.3.7.1 puts a bound-identifier's defining-point in the same region, so
  # the rule reaches a conformant array's bounds and not only its parameters.
  @extended:6.2.2.7
  Scenario: nor like a bound-identifier of a conformant array
    Given the Extended Pascal program
      """
      program p(output);
      function f(a: array [lo..hi: integer] of integer) = hi: integer;
      begin hi := 1 end;
      var w: array [1..3] of integer;
      begin writeln(f(w) : 1) end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      already a parameter of it
      """

  # And the shape that must keep working: a result variable whose spelling is
  # its own is the ordinary case, and the parameter is readable throughout.
  @extended:6.2.2.7
  Scenario: a result variable with a spelling of its own is unaffected
    Given the Extended Pascal program
      """
      program p(output);
      function f(n: integer) = total: integer;
      begin total := n * 2 end;
      begin writeln(f(10) : 1) end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      20
      """

  # §6.7.5.6 and §6.7.6.8 ask whether "the variable-access f" possesses the
  # bindability that is bindable, and §6.4.3.4 gives a field "the type,
  # bindability, and initial state denoted by the type-denoter of the
  # record-section" — the same sentence §6.4.3.5 uses for an array's component.
  # So bindability belongs to the variable-access and not to the entire-variable
  # it selects from, and asking the entire-variable was wrong in both
  # directions: it refused a bindable field and a bindable element, and named
  # the container while doing it.
  @extended:6.7.5.6
  Scenario: a bindable field and a bindable component may be bound
    Given the Extended Pascal program
      """
      program p(output);
      type bt = bindable text;
      var r: record log: bt end;
          pool: array [1..2] of bt;
          b: BindingType;
      begin
        b.name := 'spec_bind_field.tmp';
        bind(r.log, b);
        bind(pool[2], b);
        writeln(binding(r.log).bound, ' ', binding(pool[2]).bound);
        unbind(r.log);
        unbind(pool[2])
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      TRUE TRUE
      """

  # And the same rule answering the other way, which is what says the question
  # is being asked of the component rather than assumed.
  @extended:6.7.5.6
  Scenario: a field whose type-denoter does not say bindable may not
    Given the Extended Pascal program
      """
      program p(output);
      var r: record plain: text end;
          b: BindingType;
      begin bind(r.plain, b) end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      'plain' is not bindable
      """
