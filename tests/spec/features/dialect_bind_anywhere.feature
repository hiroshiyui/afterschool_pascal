# AP 6.5.1 -- every file variable is bindable.
#
# ISO/IEC 10206:1991 §6.4.1 puts `bindable` in a type-denoter, §6.5.1 gives a
# variable the bindability its denoter says, and §6.7.5.6 makes `bind` of a
# file without it a dynamic-violation. Four shapes could not always carry the
# word: a `var f: text` formal -- §6.7.6.8's own example `bindfile` -- a
# dereference of `^text`, a `text` field and a `text` element. The dialect
# makes the file-type the whole of the question (ADR-0299): a designator that
# denotes a file is bindable, the word is accepted and redundant on one, and
# bindability of anything else is what the standard says it is, with `bind`
# refusing it by design.
#
# The names below are relative, so each scenario writes in the directory the
# harness runs it in and nowhere else.

@afterschool:6.5.1
Feature: Every file variable is bindable

  # §6.7.6.8's worked example, word for word but for the body.
  Scenario: a var parameter of type text may be bound
    Given the Afterschool Pascal program
      """
      program p(output);
      var f: text; b: BindingType;
      procedure bindfile(var f: text);
      begin
        b.name := 'spec_6_5_1_param.tmp';
        bind(f, b)
      end;
      begin
        bindfile(f);
        rewrite(f);
        writeln(f, 'through a parameter');
        writeln(binding(f).bound);
        unbind(f)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      TRUE
      """

  Scenario: an identified-variable whose domain does not say bindable may be bound
    Given the Afterschool Pascal program
      """
      program p(output);
      var p: ^text; b: BindingType; line: string(40);
      begin
        new(p);
        b.name := 'spec_6_5_1_deref.tmp';
        bind(p^, b);
        rewrite(p^);
        writeln(p^, 'through a pointer');
        reset(p^);
        readln(p^, line);
        writeln(line, ' ', binding(p^).bound);
        unbind(p^);
        dispose(p)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      through a pointer TRUE
      """

  Scenario: a field and a component whose type-denoter does not say bindable may be bound
    Given the Afterschool Pascal program
      """
      program p(output);
      var r: record plain: text end;
          flat: array [1..2] of text;
          b: BindingType;
      begin
        b.name := 'spec_6_5_1_field.tmp';
        bind(r.plain, b);
        rewrite(r.plain);
        b.name := 'spec_6_5_1_elem.tmp';
        bind(flat[2], b);
        rewrite(flat[2]);
        writeln(binding(r.plain).bound, ' ', binding(flat[2]).bound);
        unbind(r.plain);
        unbind(flat[2])
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      TRUE TRUE
      """

  # A file that is not a text: the rule is a file-type and not the text-type.
  Scenario: a file of integer is bindable without the word
    Given the Afterschool Pascal program
      """
      program p(output);
      var g: file of integer; b: BindingType; n: integer;
      begin
        b.name := 'spec_6_5_1_ints.tmp';
        bind(g, b);
        rewrite(g);
        write(g, 42);
        reset(g);
        read(g, n);
        writeln(n:1);
        unbind(g)
      end.
      """
    When it is compiled and run
    Then it exits successfully
     And it prints
      """
      42
      """

  # The second paragraph: a non-file may say `bindable` and is refused by
  # `bind` on purpose, the message naming the reason.
  Scenario: a bindable variable that is not a file may not be bound
    Given the Afterschool Pascal program
      """
      program p(output);
      var i: bindable integer; b: BindingType;
      begin bind(i, b) end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      'bind' needs a file variable, found integer: only a file variable is bindable
      """

  # NOTE 4: a substring is nonbindable under §6.5.3.1 and is refused here for
  # not being a file, which is the same refusal.
  Scenario: a substring is refused as a non-file
    Given the Afterschool Pascal program
      """
      program p(output);
      var s: string(5); b: BindingType;
      begin bind(s[1..2], b) end.
      """
    When it is compiled
    Then it is rejected
     And the diagnostic includes
      """
      'bind' needs a file variable, found string
      """
